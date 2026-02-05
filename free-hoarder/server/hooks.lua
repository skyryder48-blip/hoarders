--[[
    Server Hooks - free-hoarder
    
    SIMPLE BEHAVIOR:
    - Bag enters inventory → auto attach prop + add capacity
    - Bag leaves inventory → auto remove prop + reduce capacity
    - NO BLOCKING - players can freely drop, trade, sell bags
]]

local ox_inventory = exports.ox_inventory

-------------------------------------------------------------------------------
-- HELPER: Get player source from inventory ID
-------------------------------------------------------------------------------

local function GetPlayerFromInventory(invId)
    if not invId then return nil end
    
    if type(invId) == 'number' then
        if GetPlayerPed(invId) ~= 0 then
            return invId
        end
        return nil
    end
    
    if type(invId) == 'string' then
        local source = tonumber(invId:match('player%-(%d+)'))
        if source and GetPlayerPed(source) ~= 0 then
            return source
        end
    end
    
    return nil
end

-------------------------------------------------------------------------------
-- HOOKS
-------------------------------------------------------------------------------

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(100)
    end
    Wait(1000)
    
    print('[free-hoarder] Registering hooks...')
    
    ---------------------------------------------------------------------------
    -- HOOK: When items move between inventories
    ---------------------------------------------------------------------------
    ox_inventory:registerHook('swapItems', function(payload)
        local item = payload.fromSlot
        if not item then return true end
        
        -- Only care about bags
        if not IsBagItem(item.name) then return true end
        
        local fromPlayer = GetPlayerFromInventory(payload.fromInventory)
        local toPlayer = GetPlayerFromInventory(payload.toInventory)
        
        -- Bag leaving a player
        if fromPlayer and fromPlayer ~= toPlayer then
            SetTimeout(100, function()
                AutoUnequipBag(fromPlayer, item.name)
            end)
        end
        
        -- Bag entering a player - validate job restriction first
        if toPlayer and toPlayer ~= fromPlayer then
            local bagConfig = GetBagConfig(item.name)
            if bagConfig and bagConfig.jobRestriction then
                -- Check job restriction
                local allowed, errorMsg = ValidateJobRestriction(toPlayer, bagConfig)
                if not allowed then
                    TriggerClientEvent('ox_lib:notify', toPlayer, {
                        type = 'error',
                        description = errorMsg or 'You cannot use this bag'
                    })
                    return false  -- Block the transfer
                end
            end
            
            SetTimeout(200, function()
                AutoEquipBag(toPlayer, item.name)
            end)
        end
        
        return true -- ALLOW if passed checks
    end, {})
    
    ---------------------------------------------------------------------------
    -- HOOK: When items are created (giveitem, etc)
    ---------------------------------------------------------------------------
    ox_inventory:registerHook('createItem', function(payload)
        if not payload.item then return true end
        if not IsBagItem(payload.item.name) then return true end
        
        local targetPlayer = GetPlayerFromInventory(payload.inventoryId)
        if targetPlayer then
            SetTimeout(200, function()
                AutoEquipBag(targetPlayer, payload.item.name)
            end)
        end
        
        return true
    end, {})
    
    ---------------------------------------------------------------------------
    -- HOOK: Prevent bags from being placed inside bags (bag-in-bag exploit)
    ---------------------------------------------------------------------------
    ox_inventory:registerHook('swapItems', function(payload)
        if payload.toType ~= 'container' then return true end
        
        local itemName = payload.fromSlot and payload.fromSlot.name
        if not itemName then return true end
        
        -- Check if item being moved is a bag
        if IsBagItem(itemName) then
            if payload.source then
                TriggerClientEvent('ox_lib:notify', payload.source, {
                    type = 'error',
                    description = 'Cannot put bags inside other bags'
                })
            end
            return false
        end
        
        return true
    end, {})
    
    ---------------------------------------------------------------------------
    -- HOOK: Validate items entering bag containers (weapon restrictions)
    -- Triggers on ANY item swap to check if destination is a bag stash
    ---------------------------------------------------------------------------
    ox_inventory:registerHook('swapItems', function(payload)
        local itemName = payload.fromSlot and payload.fromSlot.name
        if not itemName then return true end
        
        -- Debug: Log ALL swap attempts to see what's happening
        print('[free-hoarder] swapItems hook - Item:', itemName, 
              'toType:', payload.toType or 'nil',
              'toInventory:', payload.toInventory or 'nil')
        
        -- Check if destination inventory is one of our bag stashes
        -- It could be type 'stash', 'container', or just have our bag name in the ID
        local toInv = payload.toInventory
        if not toInv then return true end
        
        -- Convert to string if needed
        local toInvStr = type(toInv) == 'string' and toInv or tostring(toInv)
        
        -- Check if this is a bag container by looking for bag names in the inventory ID
        local containerName = GetBagNameFromContainer(toInvStr)
        if not containerName then 
            -- Not a bag container, allow
            return true 
        end
        
        print('[free-hoarder] Item entering bag container! Item:', itemName, 'Bag:', containerName)
        
        local bagConfig = GetBagConfig(containerName)
        if not bagConfig then 
            print('[free-hoarder] No config for bag:', containerName)
            return true 
        end
        
        print('[free-hoarder] Bag type:', bagConfig.type, 'Validating item:', itemName)
        
        -- Validate item restrictions
        local allowed, reason = ValidateItemForBag(itemName, bagConfig)
        
        print('[free-hoarder] Validation result - Allowed:', tostring(allowed), 'Reason:', reason or 'none')
        
        if not allowed then
            if payload.source then
                TriggerClientEvent('ox_lib:notify', payload.source, {
                    type = 'error',
                    description = reason or 'This item cannot go in this bag'
                })
            end
            return false
        end
        
        -- Item is allowed - schedule capacity recalculation after transfer
        local playerSource = payload.source or GetPlayerFromContainer(toInvStr)
        if playerSource then
            SetTimeout(100, function()
                OnBagContentsChanged(playerSource)
            end)
        end
        
        return true
    end, {})
    
    ---------------------------------------------------------------------------
    -- HOOK: Recalculate capacity when items LEAVE bag containers
    ---------------------------------------------------------------------------
    ox_inventory:registerHook('swapItems', function(payload)
        local fromInv = payload.fromInventory
        if not fromInv then return true end
        
        local fromInvStr = type(fromInv) == 'string' and fromInv or tostring(fromInv)
        
        -- Check if source is a bag container
        local containerName = GetBagNameFromContainer(fromInvStr)
        if containerName then
            -- Item leaving a bag - schedule capacity recalculation
            local playerSource = payload.source or GetPlayerFromContainer(fromInvStr)
            if playerSource then
                SetTimeout(100, function()
                    OnBagContentsChanged(playerSource)
                end)
            end
        end
        
        return true
    end, {})
    
    print('[free-hoarder] Hooks registered')
end)

-------------------------------------------------------------------------------
-- HELPER: Get bag name from container ID
-------------------------------------------------------------------------------

function GetBagNameFromContainer(containerId)
    if not containerId then return nil end
    if type(containerId) ~= 'string' then return nil end
    
    for bagName in pairs(Config.Bags) do
        if containerId:find(bagName) then
            return bagName
        end
    end
    
    return nil
end

---Get player source from container ID (format: bagName_source_timestamp)
---@param containerId string
---@return number|nil
function GetPlayerFromContainer(containerId)
    if not containerId or type(containerId) ~= 'string' then return nil end
    
    -- Container ID format: hoarder_backpack_sm_1_123456
    -- We need to extract the player ID which comes after the bag name
    for bagName in pairs(Config.Bags) do
        if containerId:find(bagName) then
            -- Pattern: bagName_playerId_timestamp
            local pattern = bagName .. '_(%d+)_'
            local playerId = containerId:match(pattern)
            if playerId then
                return tonumber(playerId)
            end
        end
    end
    
    return nil
end
