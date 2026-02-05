--[[
    Server Admin Commands - free-hoarder
    Administrative commands for managing bags and debugging
]]

-------------------------------------------------------------------------------
-- PERMISSION CHECK
-------------------------------------------------------------------------------

local function HasAdminPermission(source)
    -- Check for ace permission
    if IsPlayerAceAllowed(source, 'free-hoarder.admin') then
        return true
    end
    
    -- Check for common admin aces
    if IsPlayerAceAllowed(source, 'command') then
        return true
    end
    
    -- Check QBCore admin (if available)
    local QBCore = exports['qb-core']:GetCoreObject()
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            local permission = QBCore.Functions.HasPermission(source, 'admin')
            if permission then return true end
        end
    end
    
    return false
end

-- Export for other server files
_G.HasAdminPermission = HasAdminPermission

-------------------------------------------------------------------------------
-- ADMIN PERMISSION CALLBACK
-- Used by client debug command to verify permission
-------------------------------------------------------------------------------

lib.callback.register('free_hoarder:checkAdminPermission', function(source)
    return HasAdminPermission(source)
end)

local function NotifyError(source, message)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Error',
        description = message,
        type = 'error'
    })
end

local function NotifySuccess(source, message)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Success',
        description = message,
        type = 'success'
    })
end

-------------------------------------------------------------------------------
-- COMMANDS
-------------------------------------------------------------------------------

-- Give a bag to a player
RegisterCommand('hoarder_give', function(source, args)
    if source > 0 and not HasAdminPermission(source) then
        NotifyError(source, 'No permission')
        return
    end
    
    local targetId = tonumber(args[1])
    local bagName = args[2]
    
    if not targetId or not bagName then
        print('Usage: /hoarder_give [player_id] [bag_name]')
        if source > 0 then
            NotifyError(source, 'Usage: /hoarder_give [player_id] [bag_name]')
        end
        return
    end
    
    -- Validate bag exists in config
    local bagConfig = GetBagConfig(bagName)
    if not bagConfig then
        local msg = 'Unknown bag: ' .. bagName
        print(msg)
        if source > 0 then NotifyError(source, msg) end
        return
    end
    
    -- Check target player exists
    if GetPlayerPed(targetId) == 0 then
        local msg = 'Player not found: ' .. targetId
        print(msg)
        if source > 0 then NotifyError(source, msg) end
        return
    end
    
    -- Give the bag
    local success = exports.ox_inventory:AddItem(targetId, bagName, 1)
    
    if success then
        local msg = ('Gave %s to player %d'):format(bagName, targetId)
        print('[free-hoarder] ' .. msg)
        if source > 0 then 
            NotifySuccess(source, msg)
            if LogAdminAction then
                LogAdminAction(source, 'Give Bag', targetId, bagName)
            end
        end
    else
        local msg = 'Failed to give bag (inventory full?)'
        print('[free-hoarder] ' .. msg)
        if source > 0 then NotifyError(source, msg) end
    end
end, false)

-- Force unequip all bags from a player
RegisterCommand('hoarder_clearall', function(source, args)
    if source > 0 and not HasAdminPermission(source) then
        NotifyError(source, 'No permission')
        return
    end
    
    local targetId = tonumber(args[1]) or source
    
    if GetPlayerPed(targetId) == 0 then
        local msg = 'Player not found: ' .. targetId
        print(msg)
        if source > 0 then NotifyError(source, msg) end
        return
    end
    
    local bags = EquippedBags[targetId]
    if not bags or next(bags) == nil then
        local msg = 'Player has no equipped bags'
        print(msg)
        if source > 0 then NotifyError(source, msg) end
        return
    end
    
    local count = 0
    for slotName, _ in pairs(bags) do
        count = count + 1
    end
    
    -- Clear all equipped bags
    EquippedBags[targetId] = {}
    UpdatePlayerCapacity(targetId)
    
    -- Notify client
    TriggerClientEvent('free_hoarder:clearAllBags', targetId)
    
    -- Sync state bags
    if SyncPlayerBagsToStateBag then
        SyncPlayerBagsToStateBag(targetId)
    end
    
    local msg = ('Cleared %d bag(s) from player %d'):format(count, targetId)
    print('[free-hoarder] ' .. msg)
    if source > 0 then 
        NotifySuccess(source, msg)
        if LogAdminAction then
            LogAdminAction(source, 'Clear All Bags', targetId, count .. ' bags')
        end
    end
end, false)

-- Inspect a player's equipped bags
RegisterCommand('hoarder_inspect', function(source, args)
    if source > 0 and not HasAdminPermission(source) then
        NotifyError(source, 'No permission')
        return
    end
    
    local targetId = tonumber(args[1]) or source
    
    if GetPlayerPed(targetId) == 0 then
        local msg = 'Player not found: ' .. targetId
        print(msg)
        if source > 0 then NotifyError(source, msg) end
        return
    end
    
    local playerName = GetPlayerName(targetId) or 'Unknown'
    print(('=== Bag Inspection: %s (ID: %d) ==='):format(playerName, targetId))
    
    local bags = EquippedBags[targetId] or {}
    local totalWeight = 0
    local totalSlots = 0
    
    if next(bags) == nil then
        print('  No bags equipped')
    else
        for slotName, bagData in pairs(bags) do
            local config = GetBagConfig(bagData.bagName)
            local weight = config and config.capacity and config.capacity.weight or 0
            local slots = config and config.capacity and config.capacity.slots or 0
            totalWeight = totalWeight + weight
            totalSlots = totalSlots + slots
            
            print(('  [%s] %s'):format(slotName, bagData.bagName))
            print(('    - Container: %s'):format(bagData.containerId or 'N/A'))
            print(('    - Capacity: +%dg / +%d slots'):format(weight, slots))
            if bagData.durability then
                print(('    - Durability: %d%%'):format(bagData.durability))
            end
        end
    end
    
    print(('  Total Bonus: +%dg / +%d slots'):format(totalWeight, totalSlots))
    print('===================================')
    
    if source > 0 then
        NotifySuccess(source, ('Inspection logged to console for player %d'):format(targetId))
    end
end, false)

-- Cleanup orphaned container stashes
RegisterCommand('hoarder_cleanup', function(source, args)
    if source > 0 and not HasAdminPermission(source) then
        NotifyError(source, 'No permission')
        return
    end
    
    print('[free-hoarder] Starting orphan cleanup...')
    print('[free-hoarder] Note: This requires manual database cleanup for ox_inventory stashes')
    print('[free-hoarder] Orphaned stashes have IDs starting with "bag_" that no item references')
    
    -- We can't automatically clean ox_inventory stashes without knowing the database schema
    -- This command just provides guidance
    
    local msg = 'Cleanup guidance logged to console. Manual DB cleanup required.'
    print('[free-hoarder] ' .. msg)
    if source > 0 then 
        NotifySuccess(source, msg)
        if LogAdminAction then
            LogAdminAction(source, 'Cleanup Request', nil, 'Manual cleanup required')
        end
    end
end, false)

-- List all configured bags
RegisterCommand('hoarder_bags', function(source, args)
    if source > 0 and not HasAdminPermission(source) then
        NotifyError(source, 'No permission')
        return
    end
    
    print('=== Configured Bags ===')
    for bagName, config in pairs(Config.Bags) do
        local weight = config.capacity and config.capacity.weight or 0
        local slots = config.capacity and config.capacity.slots or 0
        local jobReq = config.jobRestriction and table.concat(config.jobRestriction, ', ') or 'None'
        print(('  %s (%s)'):format(bagName, config.type))
        print(('    - Label: %s'):format(config.label))
        print(('    - Capacity: +%dg / +%d slots'):format(weight, slots))
        print(('    - Job Restriction: %s'):format(jobReq))
        if config.durability then
            print(('    - Max Durability: %d'):format(config.durability.maxUses or 0))
        end
    end
    print('=======================')
    
    if source > 0 then
        NotifySuccess(source, 'Bag list logged to console')
    end
end, false)

-- Set bag durability for a player
RegisterCommand('hoarder_setdurability', function(source, args)
    if source > 0 and not HasAdminPermission(source) then
        NotifyError(source, 'No permission')
        return
    end
    
    local targetId = tonumber(args[1])
    local slotName = args[2]
    local durability = tonumber(args[3])
    
    if not targetId or not slotName or not durability then
        print('Usage: /hoarder_setdurability [player_id] [slot_name] [durability%]')
        if source > 0 then
            NotifyError(source, 'Usage: /hoarder_setdurability [player_id] [slot] [durability%]')
        end
        return
    end
    
    local bags = EquippedBags[targetId]
    if not bags or not bags[slotName] then
        local msg = 'No bag in slot ' .. slotName
        print(msg)
        if source > 0 then NotifyError(source, msg) end
        return
    end
    
    bags[slotName].durability = math.max(0, math.min(100, durability))
    
    local msg = ('Set durability to %d%% for slot %s'):format(durability, slotName)
    print('[free-hoarder] ' .. msg)
    if source > 0 then 
        NotifySuccess(source, msg)
        if LogAdminAction then
            LogAdminAction(source, 'Set Durability', targetId, slotName .. ' = ' .. durability .. '%')
        end
    end
end, false)

-- Repair all bags for a player
RegisterCommand('hoarder_repair', function(source, args)
    if source > 0 and not HasAdminPermission(source) then
        NotifyError(source, 'No permission')
        return
    end
    
    local targetId = tonumber(args[1]) or source
    
    local bags = EquippedBags[targetId]
    if not bags or next(bags) == nil then
        local msg = 'Player has no equipped bags'
        print(msg)
        if source > 0 then NotifyError(source, msg) end
        return
    end
    
    local count = 0
    for slotName, bagData in pairs(bags) do
        if bagData.durability and bagData.durability < 100 then
            bagData.durability = 100
            count = count + 1
        end
    end
    
    local msg = ('Repaired %d bag(s) for player %d'):format(count, targetId)
    print('[free-hoarder] ' .. msg)
    if source > 0 then 
        NotifySuccess(source, msg)
        if LogAdminAction then
            LogAdminAction(source, 'Repair Bags', targetId, count .. ' bags')
        end
    end
end, false)

-------------------------------------------------------------------------------
-- CLIENT EVENT FOR CLEAR ALL
-------------------------------------------------------------------------------

-- Client should handle this to remove all props
-- RegisterNetEvent handled in client/main.lua
