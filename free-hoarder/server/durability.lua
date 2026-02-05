--[[
    Server Durability - free-hoarder v2.0
    Server-side durability management, degradation, breaking, and repair
]]

-------------------------------------------------------------------------------
-- DURABILITY MANAGEMENT
-------------------------------------------------------------------------------

---Get current durability of a bag
---@param source number Player server ID
---@param slotName string Attachment slot
---@return number|nil durability Percentage (0-100) or nil if not found
function GetBagDurabilityServer(source, slotName)
    if not source or source <= 0 then return nil end
    if not EquippedBags or not EquippedBags[source] then return nil end
    if not EquippedBags[source][slotName] then return nil end
    
    local bagData = EquippedBags[source][slotName]
    
    -- Return stored durability or default to 100%
    return bagData.durability or 100
end

---Set durability on a bag
---@param source number Player server ID
---@param slotName string Attachment slot
---@param durability number Durability percentage (0-100)
---@param skipSync boolean? Skip client sync (for internal use)
---@return boolean success
function SetBagDurabilityServer(source, slotName, durability, skipSync)
    if not source or source <= 0 then return false end
    if not EquippedBags or not EquippedBags[source] then return false end
    if not EquippedBags[source][slotName] then return false end
    
    -- Clamp durability
    durability = math.max(0, math.min(100, durability))
    
    local bagData = EquippedBags[source][slotName]
    local previousDurability = bagData.durability or 100
    
    -- Update in memory
    EquippedBags[source][slotName].durability = durability
    
    -- Update metadata in inventory
    UpdateBagMetadataDurability(source, bagData.bagName, bagData.containerId, durability)
    
    -- Sync to client
    if not skipSync then
        TriggerClientEvent('free_hoarder:bagDurabilityUpdated', source, slotName, durability)
    end
    
    -- Trigger event hook
    if TriggerBagDurabilityChanged then
        TriggerBagDurabilityChanged({
            source = source,
            bagName = bagData.bagName,
            slotName = slotName,
            durability = durability,
            previousDurability = previousDurability
        })
    end
    
    return true
end

---Update bag item metadata with durability
---@param source number
---@param bagName string
---@param containerId string
---@param durability number
function UpdateBagMetadataDurability(source, bagName, containerId, durability)
    local items = exports.ox_inventory:GetInventoryItems(source)
    if not items then return end
    
    for slot, item in pairs(items) do
        if item.name == bagName and item.metadata and item.metadata.containerId == containerId then
            local metadata = item.metadata or {}
            metadata.durability = durability
            exports.ox_inventory:SetMetadata(source, slot, metadata)
            return
        end
    end
end

-------------------------------------------------------------------------------
-- DURABILITY DEGRADATION
-------------------------------------------------------------------------------

---Degrade bag durability (called when bag is opened)
---@param source number Player server ID
---@param slotName string Attachment slot
---@return number newDurability The new durability value
---@return boolean broken Whether the bag broke
function DegradeBagDurability(source, slotName)
    if not Config.Durability or not Config.Durability.enabled then
        return 100, false
    end
    
    local bagData = EquippedBags[source] and EquippedBags[source][slotName]
    if not bagData then return 100, false end
    
    local bagConfig = GetBagConfig(bagData.bagName)
    if not bagConfig then return 100, false end
    
    -- Check if durability is enabled for this bag
    local durabilityConfig = bagConfig.durability
    if not durabilityConfig or not durabilityConfig.enabled then
        return 100, false
    end
    
    local currentDurability = bagData.durability or 100
    local degradeAmount = durabilityConfig.degradePerOpen or Config.Durability.defaultDegradePerOpen or 2
    
    local newDurability = currentDurability - degradeAmount
    newDurability = math.max(0, newDurability)
    
    -- Update durability
    SetBagDurabilityServer(source, slotName, newDurability)
    
    -- Check thresholds for warnings
    local bagLabel = bagConfig.label or bagData.bagName
    
    if currentDurability > 25 and newDurability <= 25 then
        -- 25% warning
        TriggerClientEvent('free_hoarder:durabilityWarning', source, slotName, newDurability, 'low')
        NotifyPlayer(source, {
            title = 'Warning',
            description = bagLabel .. ' is showing wear (' .. newDurability .. '%)',
            type = 'warning'
        })
    elseif currentDurability > 10 and newDurability <= 10 then
        -- 10% warning
        TriggerClientEvent('free_hoarder:durabilityWarning', source, slotName, newDurability, 'critical')
        NotifyPlayer(source, {
            title = 'Warning',
            description = bagLabel .. ' is badly damaged (' .. newDurability .. '%)',
            type = 'warning'
        })
    elseif currentDurability > 5 and newDurability <= 5 then
        -- 5% warning - about to break!
        TriggerClientEvent('free_hoarder:durabilityWarning', source, slotName, newDurability, 'breaking')
        NotifyPlayer(source, {
            title = 'Critical!',
            description = bagLabel .. ' is about to break!',
            type = 'error'
        })
    end
    
    -- Check if broken
    if newDurability <= 0 then
        BreakBag(source, slotName)
        return 0, true
    end
    
    return newDurability, false
end

-------------------------------------------------------------------------------
-- BAG BREAKING
-------------------------------------------------------------------------------

---Break a bag (durability reached 0)
---@param source number Player server ID
---@param slotName string Attachment slot
function BreakBag(source, slotName)
    local bagData = EquippedBags[source] and EquippedBags[source][slotName]
    if not bagData then return end
    
    local bagConfig = GetBagConfig(bagData.bagName)
    local bagLabel = bagConfig and bagConfig.label or bagData.bagName
    
    print(('[free-hoarder] Bag broke for player %d: %s in slot %s'):format(source, bagData.bagName, slotName))
    
    -- Get bag contents before destruction
    local contents = {}
    if bagData.containerId then
        local inventory = exports.ox_inventory:GetInventory(bagData.containerId, false)
        if inventory and inventory.items then
            for _, item in pairs(inventory.items) do
                if item then
                    table.insert(contents, {
                        name = item.name,
                        count = item.count,
                        metadata = item.metadata
                    })
                end
            end
        end
    end
    
    -- Get player position for drops
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    
    -- Drop contents on ground
    if #contents > 0 then
        for _, item in ipairs(contents) do
            -- Create ground drop for each item
            local dropCoords = vec3(
                coords.x + math.random(-100, 100) / 100,
                coords.y + math.random(-100, 100) / 100,
                coords.z
            )
            
            exports.ox_inventory:CreateDropFromPlayer(source, item.name, item.count, item.metadata, dropCoords)
        end
        
        print(('[free-hoarder] Dropped %d items from broken bag'):format(#contents))
    end
    
    -- Clear the bag container
    if bagData.containerId then
        exports.ox_inventory:ClearInventory(bagData.containerId)
    end
    
    -- Remove the bag item from player inventory
    local items = exports.ox_inventory:GetInventoryItems(source)
    if items then
        for slot, item in pairs(items) do
            if item.name == bagData.bagName and item.metadata and item.metadata.containerId == bagData.containerId then
                exports.ox_inventory:RemoveItem(source, item.name, 1, nil, slot)
                break
            end
        end
    end
    
    -- Notify player
    NotifyPlayer(source, {
        title = 'Bag Destroyed',
        description = bagLabel .. ' has broken! Contents dropped.',
        type = 'error',
        duration = 5000
    })
    
    -- Trigger client event for effects
    TriggerClientEvent('free_hoarder:bagBroken', source, slotName, bagData.bagName)
    
    -- Trigger event hook
    if TriggerBagBroken then
        TriggerBagBroken({
            source = source,
            bagName = bagData.bagName,
            bagLabel = bagLabel,
            slotName = slotName,
            droppedItems = contents
        })
    end
    
    -- Log to Discord
    if Config.Durability and Config.Durability.logToDiscord and SendToDiscord then
        LogBagBroken(source, bagData.bagName, #contents)
    end
end

-------------------------------------------------------------------------------
-- REPAIR SYSTEM
-------------------------------------------------------------------------------

---Attempt to repair a bag
---@param source number Player server ID
---@param slotName string Attachment slot
---@return boolean success
---@return string|nil error
function RepairBag(source, slotName)
    if not Config.Durability or not Config.Durability.enabled then
        return false, 'Durability system is disabled'
    end
    
    local bagData = EquippedBags[source] and EquippedBags[source][slotName]
    if not bagData then
        return false, 'No bag in that slot'
    end
    
    local bagConfig = GetBagConfig(bagData.bagName)
    if not bagConfig then
        return false, 'Unknown bag type'
    end
    
    local currentDurability = bagData.durability or 100
    if currentDurability >= 100 then
        return false, 'Bag is already at full durability'
    end
    
    -- Get repair recipe
    local repairItems = GetRepairItems(bagConfig)
    if not repairItems then
        return false, 'No repair recipe for this bag'
    end
    
    -- Check if player has all required items
    for _, req in ipairs(repairItems) do
        local count = exports.ox_inventory:GetItemCount(source, req.name)
        if not count or count < req.count then
            return false, ('Missing %dx %s'):format(req.count - (count or 0), req.name)
        end
    end
    
    -- Remove repair items
    for _, req in ipairs(repairItems) do
        exports.ox_inventory:RemoveItem(source, req.name, req.count)
    end
    
    -- Restore durability to 100%
    SetBagDurabilityServer(source, slotName, 100)
    
    local bagLabel = bagConfig.label or bagData.bagName
    
    -- Notify player
    NotifyPlayer(source, {
        title = 'Repaired',
        description = bagLabel .. ' has been fully repaired',
        type = 'success'
    })
    
    -- Trigger event hook
    if TriggerBagRepaired then
        TriggerBagRepaired({
            source = source,
            bagName = bagData.bagName,
            slotName = slotName,
            durability = 100
        })
    end
    
    -- Log to Discord
    if Config.Durability and Config.Durability.logToDiscord and SendToDiscord then
        LogBagRepaired(source, bagData.bagName)
    end
    
    return true, nil
end

---Get repair items for a bag
---@param bagConfig table Bag configuration
---@return table|nil repairItems Array of {name, count}
function GetRepairItems(bagConfig)
    -- Check for bag-specific repair items
    if bagConfig.durability and bagConfig.durability.repairItems then
        return bagConfig.durability.repairItems
    end
    
    -- Check for material type
    local material = bagConfig.material or 'fabric'
    
    if Config.Durability and Config.Durability.repairRecipes then
        local recipe = Config.Durability.repairRecipes[material]
        if recipe then
            return recipe
        end
        
        -- Fall back to default
        return Config.Durability.repairRecipes.default
    end
    
    -- Hardcoded fallback
    return {
        { name = 'fabric', count = 2 },
        { name = 'sewing_kit', count = 1 }
    }
end

-------------------------------------------------------------------------------
-- REPAIR STATION TARGET
-------------------------------------------------------------------------------

---Check if player is at a repair station
---@param source number
---@return boolean
function IsAtRepairStation(source)
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    
    if not Config.Durability or not Config.Durability.repairStations then
        return false
    end
    
    for _, station in ipairs(Config.Durability.repairStations) do
        local dist = #(coords - station.coords)
        if dist <= (station.radius or 2.0) then
            return true
        end
    end
    
    return false
end

---Check if player has repair job
---@param source number
---@return boolean
function HasRepairJob(source)
    if not Config.Durability or not Config.Durability.repairJobs then
        return true  -- No job restriction if not configured
    end
    
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return false end
    
    local job = Player.PlayerData.job and Player.PlayerData.job.name
    
    for _, allowedJob in ipairs(Config.Durability.repairJobs) do
        if job == allowedJob then
            return true
        end
    end
    
    return false
end

-------------------------------------------------------------------------------
-- CALLBACKS
-------------------------------------------------------------------------------

---Get bag durability info
lib.callback.register('free_hoarder:getBagDurability', function(source, slotName)
    local durability = GetBagDurabilityServer(source, slotName)
    if not durability then
        return nil, 'Bag not found'
    end
    
    local bagData = EquippedBags[source] and EquippedBags[source][slotName]
    if not bagData then
        return nil, 'Bag not found'
    end
    
    local bagConfig = GetBagConfig(bagData.bagName)
    local repairItems = GetRepairItems(bagConfig)
    
    -- Check which repair items player has
    local hasItems = {}
    local missingItems = {}
    
    if repairItems then
        for _, req in ipairs(repairItems) do
            local count = exports.ox_inventory:GetItemCount(source, req.name) or 0
            if count >= req.count then
                table.insert(hasItems, { name = req.name, count = req.count, has = count })
            else
                table.insert(missingItems, { name = req.name, count = req.count, has = count })
            end
        end
    end
    
    return {
        durability = durability,
        bagName = bagData.bagName,
        bagLabel = bagConfig and bagConfig.label or bagData.bagName,
        repairItems = repairItems,
        hasItems = hasItems,
        missingItems = missingItems,
        canRepair = #missingItems == 0 and durability < 100
    }
end)

---Attempt repair
lib.callback.register('free_hoarder:repairBag', function(source, slotName)
    -- Check job restriction
    if not HasRepairJob(source) then
        return false, 'You don\'t have the skills to repair bags'
    end
    
    -- Check if at repair station (optional)
    if Config.Durability and Config.Durability.requireStation then
        if not IsAtRepairStation(source) then
            return false, 'You need to be at a repair station'
        end
    end
    
    return RepairBag(source, slotName)
end)

---Hook into bag opening to degrade durability
lib.callback.register('free_hoarder:onBagOpened', function(source, slotName)
    local newDurability, broken = DegradeBagDurability(source, slotName)
    return newDurability, broken
end)

-------------------------------------------------------------------------------
-- DISCORD LOGGING
-------------------------------------------------------------------------------

function LogBagBroken(source, bagName, itemCount)
    if not SendToDiscord then return end
    
    local Player = exports.qbx_core:GetPlayer(source)
    local playerName = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Unknown'
    
    SendToDiscord(
        '💔 Bag Broken',
        ('**Player:** %s (ID: %d)\n**Bag:** %s\n**Items Dropped:** %d'):format(
            playerName, source, bagName, itemCount
        ),
        15158332  -- Orange/warning color
    )
end

function LogBagRepaired(source, bagName)
    if not SendToDiscord then return end
    
    local Player = exports.qbx_core:GetPlayer(source)
    local playerName = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Unknown'
    
    SendToDiscord(
        '🔧 Bag Repaired',
        ('**Player:** %s (ID: %d)\n**Bag:** %s'):format(
            playerName, source, bagName
        ),
        5814783  -- Blue color
    )
end
