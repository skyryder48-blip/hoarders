--[[
    Server Validation - free-hoarder
    Server-side capacity validation and quick drop support
]]

-------------------------------------------------------------------------------
-- CAPACITY VALIDATION
-- Prevents exploits by validating inventory changes server-side
-------------------------------------------------------------------------------

---Get actual max weight for a player including bag bonuses
---@param source number
---@return number maxWeight
local function GetActualMaxWeight(source)
    local baseWeight = Config and Config.BaseWeight or 26500
    local bonusWeight, _ = CalculateTotalBonusCapacity(source)
    return baseWeight + bonusWeight
end

---Validate that a player isn't exceeding their actual capacity
---@param source number
---@return boolean valid
---@return string|nil errorMsg
function ValidatePlayerCapacity(source)
    local inventory = exports.ox_inventory:GetInventory(source, false)
    if not inventory then
        return true, nil  -- Can't validate without inventory
    end
    
    local currentWeight = inventory.weight or 0
    local actualMax = GetActualMaxWeight(source)
    
    if currentWeight > actualMax then
        return false, ('Over capacity: %dg / %dg'):format(currentWeight, actualMax)
    end
    
    return true, nil
end

---Hook into inventory changes to validate capacity
---Called from hooks.lua after item additions
---@param source number
---@param itemName string
---@param count number
---@return boolean allow
function OnItemAdded(source, itemName, count)
    -- Skip validation if disabled
    if Config and Config.CapacityValidation and not Config.CapacityValidation.enabled then
        return true
    end
    
    local valid, errorMsg = ValidatePlayerCapacity(source)
    
    if not valid then
        -- Log suspicious activity
        if LogSuspiciousActivity then
            LogSuspiciousActivity(source, 'Capacity Exploit Attempt', {
                item = itemName,
                count = count,
                error = errorMsg
            })
        end
        
        print(('[free-hoarder] Capacity validation failed for player %d: %s'):format(source, errorMsg))
        return false
    end
    
    return true
end

-------------------------------------------------------------------------------
-- QUICK DROP CALLBACK
-- Drops the first occupied inventory slot
-------------------------------------------------------------------------------

lib.callback.register('free_hoarder:dropFirstInventorySlot', function(source)
    local inventory = exports.ox_inventory:GetInventoryItems(source)
    
    if not inventory then
        return false
    end
    
    -- Find first occupied slot (numerically sorted)
    local firstSlot = nil
    local firstItem = nil
    
    for slot, item in pairs(inventory) do
        if type(slot) == 'number' then
            if not firstSlot or slot < firstSlot then
                firstSlot = slot
                firstItem = item
            end
        end
    end
    
    if not firstSlot or not firstItem then
        return false  -- Inventory empty
    end
    
    -- Get player position
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)
    
    -- Drop position slightly in front of player
    local dropCoords = vector3(
        coords.x - math.sin(rad) * 0.8,
        coords.y + math.cos(rad) * 0.8,
        coords.z - 0.3
    )
    
    local itemName = firstItem.name
    local itemCount = firstItem.count or 1
    local itemMetadata = firstItem.metadata
    
    -- Check if this is a bag - if so, handle special unequip logic
    local bagConfig = GetBagConfig(itemName)
    if bagConfig then
        -- Find which slot this bag is in
        local bags = EquippedBags[source]
        if bags then
            for slotName, bagData in pairs(bags) do
                if bagData.bagName == itemName then
                    -- Check containerId match if possible
                    if not itemMetadata or not itemMetadata.containerId or 
                       itemMetadata.containerId == bagData.containerId then
                        -- Unequip the bag first
                        bags[slotName] = nil
                        UpdatePlayerCapacity(source)
                        TriggerClientEvent('free_hoarder:bagUnequipped', source, slotName)
                        if SyncPlayerBagsToStateBag then
                            SyncPlayerBagsToStateBag(source)
                        end
                        break
                    end
                end
            end
        end
    end
    
    -- Remove item from inventory
    local removed = exports.ox_inventory:RemoveItem(source, itemName, itemCount, itemMetadata, firstSlot)
    
    if not removed then
        return false
    end
    
    -- Create ground drop
    local success, dropId = pcall(function()
        return exports.ox_inventory:CustomDrop(
            'Dropped Item',
            {{ itemName, itemCount, itemMetadata }},
            dropCoords,
            1,
            50000
        )
    end)
    
    if not success or not dropId then
        -- Failed to create drop, return item
        exports.ox_inventory:AddItem(source, itemName, itemCount, itemMetadata)
        return false
    end
    
    -- Log if it's a bag
    if bagConfig and LogBagDropped then
        LogBagDropped(source, itemName, dropCoords, 'Quick Drop')
    end
    
    return true
end)

-------------------------------------------------------------------------------
-- THROW BAG EVENT
-- Creates drop at specified target location
-------------------------------------------------------------------------------

RegisterNetEvent('free_hoarder:throwBagToGround', function(slotName, bagItemName, targetCoords)
    local source = source
    
    if not slotName or not bagItemName or not targetCoords then return end
    if not EquippedBags[source] then return end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData then return end
    
    -- Validate throw distance (prevent teleport exploits)
    local ped = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(ped)
    local distance = #(playerCoords - targetCoords)
    
    local maxThrowDistance = Config and Config.Throwing and Config.Throwing.maxDistance or 10.0
    
    if distance > maxThrowDistance then
        print(('[free-hoarder] Player %d attempted to throw bag too far: %.2fm'):format(source, distance))
        targetCoords = playerCoords + (targetCoords - playerCoords) / distance * maxThrowDistance
    end
    
    -- Find the bag item in player inventory
    local inventory = exports.ox_inventory:GetInventoryItems(source)
    local itemSlot = nil
    local itemMetadata = nil
    
    if inventory then
        for slot, item in pairs(inventory) do
            if item.name == bagItemName then
                if item.metadata and item.metadata.containerId == bagData.containerId then
                    itemSlot = slot
                    itemMetadata = item.metadata or {}
                    break
                elseif not itemSlot then
                    itemSlot = slot
                    itemMetadata = item.metadata or {}
                end
            end
        end
    end
    
    if not itemSlot then
        print('[free-hoarder] Could not find bag item for throw:', bagItemName)
        return
    end
    
    -- Remove from equipped bags
    EquippedBags[source][slotName] = nil
    UpdatePlayerCapacity(source)
    TriggerClientEvent('free_hoarder:bagUnequipped', source, slotName)
    
    if SyncPlayerBagsToStateBag then
        SyncPlayerBagsToStateBag(source)
    end
    
    -- Remove from inventory
    local removed = exports.ox_inventory:RemoveItem(source, bagItemName, 1, itemMetadata, itemSlot)
    
    if removed then
        -- Create drop at target location
        local success, dropId = pcall(function()
            return exports.ox_inventory:CustomDrop(
                'Thrown Bag',
                {{ bagItemName, 1, itemMetadata }},
                targetCoords,
                1,
                50000
            )
        end)
        
        if success and dropId then
            print(('[free-hoarder] Player %d threw bag to %.2f, %.2f, %.2f'):format(
                source, targetCoords.x, targetCoords.y, targetCoords.z))
            
            if LogBagDropped then
                LogBagDropped(source, bagItemName, targetCoords, 'Thrown')
            end
        else
            -- Failed, return item
            exports.ox_inventory:AddItem(source, bagItemName, 1, itemMetadata)
        end
    else
        -- Failed to remove, re-add to equipped
        EquippedBags[source][slotName] = bagData
        UpdatePlayerCapacity(source)
        if SyncPlayerBagsToStateBag then
            SyncPlayerBagsToStateBag(source)
        end
    end
end)

-------------------------------------------------------------------------------
-- JOB VALIDATION
-- Check if player has required job for a bag
-------------------------------------------------------------------------------

---Check if player can use a job-restricted bag
---@param source number
---@param bagConfig table
---@return boolean allowed
---@return string|nil errorMsg
function ValidateJobRestriction(source, bagConfig)
    if not bagConfig.jobRestriction then
        return true, nil
    end
    
    -- Get player job
    local playerJob = nil
    
    -- Try QBCore
    local QBCore = exports['qb-core']:GetCoreObject()
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            playerJob = Player.PlayerData.job and Player.PlayerData.job.name
        end
    end
    
    -- Try ESX
    if not playerJob then
        local success, ESX = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if success and ESX then
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer then
                playerJob = xPlayer.job and xPlayer.job.name
            end
        end
    end
    
    if not playerJob then
        -- Can't determine job, allow by default
        return true, nil
    end
    
    -- Check if player job is in allowed list
    for _, allowedJob in ipairs(bagConfig.jobRestriction) do
        if playerJob == allowedJob then
            return true, nil
        end
    end
    
    return false, ('Requires job: %s'):format(table.concat(bagConfig.jobRestriction, ', '))
end
