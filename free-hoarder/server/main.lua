--[[
    Server Main - free-hoarder
    Player lifecycle events
]]

-------------------------------------------------------------------------------
-- PLAYER EVENTS
-------------------------------------------------------------------------------

-- QBX/QBCore player loaded
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local source = source
    print('[free-hoarder] Player loaded (QBCore):', source)
    InitializePlayerState(source)
    
    SetTimeout(2000, function()
        if GetPlayerPed(source) ~= 0 then
            ScanAndEquipAllBags(source)
        end
    end)
end)

-- ox_inventory player loaded
AddEventHandler('ox_inventory:playerLoaded', function(playerId)
    local source = playerId
    print('[free-hoarder] Player loaded (ox_inventory):', source)
    
    if not EquippedBags[source] then
        InitializePlayerState(source)
    end
    
    SetTimeout(2000, function()
        if GetPlayerPed(source) ~= 0 then
            ScanAndEquipAllBags(source)
        end
    end)
end)

-- Player dropped
AddEventHandler('playerDropped', function()
    local source = source
    CleanupPlayerState(source)
    
    -- Clear state bags
    if ClearPlayerState then
        ClearPlayerState(source)
    end
end)

-- Resource start - scan online players
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    print('[free-hoarder] Resource started')
    Wait(2000)
    
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local source = tonumber(playerId)
        if source and GetPlayerPed(source) ~= 0 then
            print('[free-hoarder] Initializing player:', source)
            InitializePlayerState(source)
            SetTimeout(500, function()
                ScanAndEquipAllBags(source)
            end)
        end
    end
end)

-- Resource stop - clear props
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    for source in pairs(EquippedBags) do
        TriggerClientEvent('free_hoarder:clearAllProps', source)
    end
end)

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------


    return CalculateTotalBonusCapacity(source)
end)

    local bags = EquippedBags[source]
    if not bags or not bags[slotName] then return false end
    
    local bagName = bags[slotName].bagName
    bags[slotName] = nil
    
    UpdatePlayerCapacity(source)
    TriggerClientEvent('free_hoarder:bagUnequipped', source, slotName)
    
    return true
end)

-------------------------------------------------------------------------------
-- BAG CONTAINER EVENTS
-------------------------------------------------------------------------------

-- Open bag container (from client menu)
RegisterNetEvent('free_hoarder:openBagContainer', function(slotName, containerId)
    local source = source
    
    -- Validate the request
    local bags = EquippedBags[source]
    if not bags then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'No bags equipped' })
        return
    end
    
    -- If slotName provided, use that bag's container
    if slotName and bags[slotName] then
        containerId = bags[slotName].containerId
    end
    
    -- If containerId provided, verify it belongs to this player
    if containerId then
        local valid = false
        for _, bagData in pairs(bags) do
            if bagData.containerId == containerId then
                valid = true
                break
            end
        end
        
        if not valid then
            TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Invalid bag' })
            return
        end
    else
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Could not find bag' })
        return
    end
    
    -- Open the bag's inventory
    print('[free-hoarder] Opening container:', containerId, 'for player', source)
    exports.ox_inventory:forceOpenInventory(source, 'stash', containerId)
end)

-------------------------------------------------------------------------------
-- WEAPON RESTRICTION EVENTS
-------------------------------------------------------------------------------

-- Player drew weapon - drop bag to ground as pickup
RegisterNetEvent('free_hoarder:dropBagToGround', function(slotName, bagItemName)
    local source = source
    
    if not slotName or not bagItemName then return end
    if not EquippedBags[source] then return end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData then 
        print('[free-hoarder] No bag in slot', slotName, 'for player', source)
        return 
    end
    
    print('[free-hoarder] Dropping bag to ground:', bagItemName, 'from slot:', slotName)
    
    -- Get player position for drop
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    
    -- Find the bag item in player inventory to get its slot and metadata
    local inventory = exports.ox_inventory:GetInventoryItems(source)
    local itemSlot = nil
    local itemMetadata = nil
    
    if inventory then
        for slot, item in pairs(inventory) do
            if item.name == bagItemName then
                -- Check if this is the right bag (match containerId if possible)
                if item.metadata and item.metadata.containerId == bagData.containerId then
                    itemSlot = slot
                    itemMetadata = item.metadata or {}
                    break
                elseif not itemSlot then
                    -- Fallback to first matching item
                    itemSlot = slot
                    itemMetadata = item.metadata or {}
                end
            end
        end
    end
    
    if not itemSlot then
        print('[free-hoarder] Could not find bag item in inventory:', bagItemName)
        return
    end
    
    -- Remove from equipped bags first
    EquippedBags[source][slotName] = nil
    
    -- Update capacity
    UpdatePlayerCapacity(source)
    
    -- Notify client to remove prop
    TriggerClientEvent('free_hoarder:bagUnequipped', source, slotName)
    
    -- Sync state bags
    if SyncPlayerBagsToStateBag then
        SyncPlayerBagsToStateBag(source)
    end
    
    -- Calculate drop position slightly in front of player
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)
    local dropCoords = vector3(
        coords.x - math.sin(rad) * 0.5,
        coords.y + math.cos(rad) * 0.5,
        coords.z - 0.3
    )
    
    -- Remove the specific item from player inventory FIRST
    local removed = exports.ox_inventory:RemoveItem(source, bagItemName, 1, itemMetadata, itemSlot)
    
    if removed then
        print('[free-hoarder] Removed bag from player inventory, slot:', itemSlot)
        
        -- Create ground drop using ox_inventory
        local success, dropId = pcall(function()
            return exports.ox_inventory:CustomDrop(
                'Dropped Bag',
                {{ bagItemName, 1, itemMetadata }},
                dropCoords,
                1,
                50000
            )
        end)
        
        if success and dropId then
            print('[free-hoarder] Created ground drop:', dropId, 'at', dropCoords)
        else
            -- If drop creation failed, give item back to player
            print('[free-hoarder] Failed to create ground drop, returning item to player')
            exports.ox_inventory:AddItem(source, bagItemName, 1, itemMetadata)
        end
    else
        print('[free-hoarder] Failed to remove bag from inventory')
        -- Re-add to equipped bags since removal failed
        EquippedBags[source][slotName] = bagData
        UpdatePlayerCapacity(source)
        if SyncPlayerBagsToStateBag then
            SyncPlayerBagsToStateBag(source)
        end
    end
end)

-- Legacy event for simple unequip (without ground drop)
RegisterNetEvent('free_hoarder:unequipBagForWeapon', function(slotName)
    local source = source
    
    if not slotName then return end
    if not EquippedBags[source] then return end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData then return end
    
    print('[free-hoarder] Unequipping bag from', slotName, 'for player', source)
    
    -- Remove from equipped bags
    EquippedBags[source][slotName] = nil
    
    -- Update capacity
    UpdatePlayerCapacity(source)
    
    -- Notify client
    TriggerClientEvent('free_hoarder:bagUnequipped', source, slotName)
    
    -- Sync state bags
    if SyncPlayerBagsToStateBag then
        SyncPlayerBagsToStateBag(source)
    end
end)

-------------------------------------------------------------------------------
-- DEBUG COMMANDS
-------------------------------------------------------------------------------

RegisterCommand('hoarder_debug', function(source)
    local bags = EquippedBags[source] or {}
    print('[free-hoarder] Equipped bags for player', source, ':')
    for slot, data in pairs(bags) do
        print('  -', slot, ':', data.bagName)
    end
    
    local bonus, slots = CalculateTotalBonusCapacity(source)
    print('  Bonus capacity:', bonus, 'g /', slots, 'slots')
end, false)

RegisterCommand('hoarder_scan', function(source)
    print('[free-hoarder] Rescanning inventory for player', source)
    ScanAndEquipAllBags(source)
end, false)
