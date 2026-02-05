--[[
    Server Drops - free-hoarder
    Handles force-dropping excess items when player goes over capacity
]]

local ox_inventory = exports.ox_inventory

-------------------------------------------------------------------------------
-- OVER-CAPACITY HANDLING
-------------------------------------------------------------------------------

---Handle player going over capacity
---@param source number
---@param excessWeight number Weight over capacity in grams
RegisterNetEvent('free_hoarder:handleOverCapacity', function(source, excessWeight)
    if type(source) ~= 'number' then
        source = source
    end
    
    if not source or source <= 0 then return end
    if not excessWeight or excessWeight <= 0 then return end
    
    print('[free-hoarder] Handling over-capacity for player', source, '- excess:', excessWeight)
    
    local items = ox_inventory:GetInventoryItems(source)
    if not items then return end
    
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    
    local toDrop = {}
    local droppedWeight = 0
    local droppedItems = {}
    
    -- Sort items by slot (LIFO)
    local sortedSlots = {}
    for slot in pairs(items) do
        table.insert(sortedSlots, slot)
    end
    table.sort(sortedSlots, function(a, b) return a > b end)
    
    for _, slot in ipairs(sortedSlots) do
        local item = items[slot]
        
        if item and droppedWeight < excessWeight then
            -- Skip essential items
            local isEssential = Config.Drops and Config.Drops.essentialItems and Config.Drops.essentialItems[item.name]
            
            -- Skip bags (don't force-drop bags)
            local isBag = IsBagItem(item.name)
            
            if not isEssential and not isBag then
                local itemWeight = item.weight or 0
                local dropCount = item.count
                local weightPerItem = itemWeight / math.max(item.count, 1)
                
                -- Partial drop if needed
                if droppedWeight + itemWeight > excessWeight and item.count > 1 then
                    local neededWeight = excessWeight - droppedWeight
                    dropCount = math.ceil(neededWeight / weightPerItem)
                    dropCount = math.min(dropCount, item.count)
                end
                
                table.insert(toDrop, {
                    name = item.name,
                    count = dropCount,
                    metadata = item.metadata,
                    slot = slot
                })
                
                droppedWeight = droppedWeight + (weightPerItem * dropCount)
                table.insert(droppedItems, ('%dx %s'):format(dropCount, item.label or item.name))
            end
        end
    end
    
    -- Execute drops
    if #toDrop > 0 then
        local dropItems = {}
        
        for _, dropData in ipairs(toDrop) do
            local success = ox_inventory:RemoveItem(source, dropData.name, dropData.count, dropData.metadata, dropData.slot)
            if success then
                table.insert(dropItems, { dropData.name, dropData.count, dropData.metadata })
            end
        end
        
        if #dropItems > 0 then
            local maxSlots = Config.Drops and Config.Drops.maxDropSlots or 10
            local despawn = Config.Drops and Config.Drops.despawnTime or 300
            
            ox_inventory:CustomDrop('Dropped Items', dropItems, coords, maxSlots, despawn * 1000)
        end
        
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'warning',
            title = 'Over Capacity',
            description = ('Dropped: %s'):format(table.concat(droppedItems, ', ')),
            duration = 5000
        })
    end
end)

-------------------------------------------------------------------------------
-- CLIENT REQUEST
-------------------------------------------------------------------------------

RegisterNetEvent('free_hoarder:requestDropExcess', function()
    local source = source
    
    -- Calculate weight from inventory items (GetPlayerWeight is client-side only)
    local currentWeight = 0
    local inventory = exports.ox_inventory:GetInventory(source, false)
    if inventory and inventory.weight then
        currentWeight = inventory.weight
    end
    
    local maxWeight = Config.BaseWeight or 26500
    -- Add bonus from bags
    local bonusWeight = CalculateTotalBonusCapacity and CalculateTotalBonusCapacity(source) or 0
    maxWeight = maxWeight + bonusWeight
    
    if currentWeight > maxWeight then
        TriggerEvent('free_hoarder:handleOverCapacity', source, currentWeight - maxWeight)
    end
end)
