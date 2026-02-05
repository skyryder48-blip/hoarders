--[[
    Server Inventory Integration - free-hoarder
    
    SIMPLIFIED SYSTEM:
    - Bag in inventory = prop shown + capacity bonus (automatic)
    - Bag leaves inventory = prop removed + capacity reduced (automatic)
    - No metadata, no manual equip/unequip
]]

local ox_inventory = exports.ox_inventory

-------------------------------------------------------------------------------
-- SHARED STATE
-------------------------------------------------------------------------------

-- Player equipped bags: source -> { [slotName] = { invSlot, bagName } }
EquippedBags = EquippedBags or {}

-- Player cooldowns
PlayerCooldowns = PlayerCooldowns or {}

-------------------------------------------------------------------------------
-- STATE MANAGEMENT
-------------------------------------------------------------------------------

function InitializePlayerState(source)
    EquippedBags[source] = {}
    PlayerCooldowns[source] = 0
    print('[free-hoarder] Initialized state for player', source)
end

function CleanupPlayerState(source)
    EquippedBags[source] = nil
    PlayerCooldowns[source] = nil
end

function GetPlayerEquippedBags(source)
    return EquippedBags[source] or {}
end

function IsSlotOccupied(source, slotName)
    local bags = EquippedBags[source]
    return bags and bags[slotName] ~= nil
end

function CountEquippedBags(source)
    local count = 0
    local bags = EquippedBags[source]
    if bags then
        for _ in pairs(bags) do
            count = count + 1
        end
    end
    return count
end

function CheckCooldown(source)
    local now = GetGameTimer()
    local lastAction = PlayerCooldowns[source] or 0
    if now - lastAction < (Config.Security and Config.Security.actionCooldown or 1000) then
        return false
    end
    PlayerCooldowns[source] = now
    return true
end

-------------------------------------------------------------------------------
-- CAPACITY MANAGEMENT
-------------------------------------------------------------------------------

-- Track bag contents weight per player
BagContentsWeight = BagContentsWeight or {}

---Calculate total weight stored in all equipped bag containers
---@param source number
---@return number totalWeight
function CalculateBagContentsWeight(source)
    local totalWeight = 0
    local bags = EquippedBags[source]
    if not bags then return 0 end
    
    for _, bagData in pairs(bags) do
        local containerId = bagData.containerId
        if containerId then
            -- Get stash contents weight
            local stashItems = exports.ox_inventory:GetInventoryItems(containerId)
            if stashItems then
                for _, item in pairs(stashItems) do
                    if item then
                        totalWeight = totalWeight + (item.weight or 0) * (item.count or 1)
                    end
                end
            end
        end
    end
    
    return totalWeight
end

function CalculateTotalBonusCapacity(source)
    local totalWeight = 0
    local totalSlots = 0
    
    local bags = EquippedBags[source]
    if not bags then return 0, 0 end
    
    for _, bagData in pairs(bags) do
        local config = GetBagConfig(bagData.bagName)
        if config and config.capacity then
            totalWeight = totalWeight + config.capacity.weight
            totalSlots = totalSlots + config.capacity.slots
        end
    end
    
    return totalWeight, totalSlots
end

function UpdatePlayerCapacity(source)
    local bonusWeight, bonusSlots = CalculateTotalBonusCapacity(source)
    local bagContentsWeight = CalculateBagContentsWeight(source)
    
    -- Effective max = base + bag bonus - bag contents (bag contents "use up" the bonus)
    local effectiveMaxWeight = (Config.BaseWeight or 26500) + bonusWeight - bagContentsWeight
    
    -- Don't go below base weight
    if effectiveMaxWeight < (Config.BaseWeight or 26500) then
        effectiveMaxWeight = Config.BaseWeight or 26500
    end
    
    print('[free-hoarder] Updating capacity:', source, 
          'base=', Config.BaseWeight, 
          'bonus=', bonusWeight, 
          'bagContents=', bagContentsWeight,
          'effective=', effectiveMaxWeight)
    
    -- Set max weight
    pcall(function()
        exports.ox_inventory:SetMaxWeight(source, effectiveMaxWeight)
    end)
    
    -- Get current weight for state bag sync (using inventory object, not client-side export)
    local currentWeight = 0
    pcall(function()
        local inventory = exports.ox_inventory:GetInventory(source, false)
        if inventory and inventory.weight then
            currentWeight = inventory.weight
        end
    end)
    
    -- Sync weight state via state bags (triggers reactive updates on client)
    if SetPlayerWeightState then
        SetPlayerWeightState(source, currentWeight, effectiveMaxWeight, bagContentsWeight)
    end
    
    -- Legacy client event (for backwards compatibility)
    TriggerClientEvent('free_hoarder:capacityUpdated', source, effectiveMaxWeight, bonusSlots)
end

---Called when items are added/removed from bag containers
---@param source number
function OnBagContentsChanged(source)
    if not source then return end
    UpdatePlayerCapacity(source)
end

-------------------------------------------------------------------------------
-- AUTO EQUIP/UNEQUIP (called by hooks)
-------------------------------------------------------------------------------

function AutoEquipBag(source, bagName)
    if not source or source <= 0 then return end
    if not GetPlayerPed(source) or GetPlayerPed(source) == 0 then return end
    
    local bagConfig = GetBagConfig(bagName)
    if not bagConfig then return end
    
    -- Init state if needed
    if not EquippedBags[source] then
        EquippedBags[source] = {}
    end
    
    -- Find ALL bags of this type in inventory
    local items = ox_inventory:GetInventoryItems(source)
    if not items then return end
    
    local bagsFound = {}
    for slot, item in pairs(items) do
        if item and item.name == bagName then
            table.insert(bagsFound, {
                slot = slot,
                metadata = item.metadata or {},
                containerId = item.metadata and item.metadata.containerId or nil
            })
        end
    end
    
    if #bagsFound == 0 then
        print('[free-hoarder] Bag not found in inventory:', bagName)
        return
    end
    
    -- Process each bag found
    for _, bagInfo in ipairs(bagsFound) do
        local bagInvSlot = bagInfo.slot
        local existingContainerId = bagInfo.containerId
        
        -- Check if this specific bag is already tracked (by containerId)
        local alreadyTracked = false
        if existingContainerId then
            for _, data in pairs(EquippedBags[source]) do
                if data.containerId == existingContainerId then
                    alreadyTracked = true
                    break
                end
            end
        end
        
        if alreadyTracked then
            print('[free-hoarder] Bag already tracked:', bagName, 'containerId:', existingContainerId)
            goto continue
        end
        
        -- Find available slot for this bag type
        local availableSlot = nil
        for _, slotName in ipairs(bagConfig.allowedSlots) do
            if not IsSlotOccupied(source, slotName) then
                availableSlot = slotName
                break
            end
        end
        
        if not availableSlot then
            print('[free-hoarder] No slot available for:', bagName)
            goto continue
        end
        
        -- Get current item data to check for existing containerId
        local slotData = ox_inventory:GetSlot(source, bagInvSlot)
        local metadata = slotData and slotData.metadata or {}
        
        -- Use existing containerId from metadata, or generate a new one
        local containerId = metadata.containerId
        if not containerId then
            -- Generate a unique persistent ID (uses os.time + random for uniqueness)
            containerId = ('%s_%d_%d'):format(bagName, os.time(), math.random(1000, 9999))
            
            -- Store containerId in item metadata so it persists
            metadata.containerId = containerId
            ox_inventory:SetMetadata(source, bagInvSlot, metadata)
            
            print('[free-hoarder] Generated new containerId:', containerId)
        else
            print('[free-hoarder] Using existing containerId from metadata:', containerId)
        end
        
        -- Track it
        EquippedBags[source][availableSlot] = {
            invSlot = bagInvSlot,
            bagName = bagName,
            containerId = containerId,
            lock = metadata.lock or nil,              -- v2.0: Include existing lock from metadata
            durability = metadata.durability or 100   -- v2.0: Include durability from metadata (default 100%)
        }
        
        -- Register the container (will use existing stash data if it exists)
        RegisterBagContainer(source, bagName, containerId)
        
        -- Update capacity
        UpdatePlayerCapacity(source)
        
        -- Sync state bags (replaces client events for cross-client sync)
        if SetPlayerBagsState then
            SetPlayerBagsState(source, EquippedBags[source])
        end
        
        -- Tell client to show prop (legacy event, statebags also handle this)
        -- v2.0: Also include lock and durability data for client sync
        TriggerClientEvent('free_hoarder:bagEquipped', source, availableSlot, bagName, bagConfig, metadata.lock, metadata.durability or 100)
        
        -- v2.0: Trigger event hooks for external resources
        if TriggerBagEquipped then
            TriggerBagEquipped({
                source = source,
                bagName = bagName,
                bagLabel = bagConfig.label or bagName,
                slotName = availableSlot,
                containerId = containerId,
                metadata = metadata
            })
        end
        
        print('[free-hoarder] Equipped', bagName, 'to', availableSlot, 'for player', source, 'containerId:', containerId)
        
        ::continue::
    end
end

function AutoUnequipBag(source, bagName, specificContainerId)
    if not source or source <= 0 then return end
    
    local bags = EquippedBags[source]
    if not bags then return end
    
    -- Get all items to check which bags are still in inventory
    local items = ox_inventory:GetInventoryItems(source) or {}
    
    -- Build list of containerIds still in inventory
    local containerIdsInInventory = {}
    for _, item in pairs(items) do
        if item and item.name == bagName and item.metadata and item.metadata.containerId then
            containerIdsInInventory[item.metadata.containerId] = true
        end
    end
    
    -- Find equipped bags of this type that are no longer in inventory
    local slotsToRemove = {}
    for slotName, data in pairs(bags) do
        if data.bagName == bagName then
            -- If specificContainerId provided, only remove that one
            if specificContainerId then
                if data.containerId == specificContainerId and not containerIdsInInventory[specificContainerId] then
                    table.insert(slotsToRemove, slotName)
                end
            else
                -- Remove any bag of this type that's no longer in inventory
                if not containerIdsInInventory[data.containerId] then
                    table.insert(slotsToRemove, slotName)
                end
            end
        end
    end
    
    -- Remove the bags that are no longer in inventory
    for _, slotName in ipairs(slotsToRemove) do
        local bagData = bags[slotName]
        local bagConfig = GetBagConfig(bagData.bagName)
        print('[free-hoarder] Unequipping', bagName, 'from', slotName, 'containerId:', bagData.containerId)
        
        EquippedBags[source][slotName] = nil
        
        -- Tell client to remove prop (legacy event)
        TriggerClientEvent('free_hoarder:bagUnequipped', source, slotName)
        
        -- v2.0: Trigger event hooks for external resources
        if TriggerBagUnequipped then
            TriggerBagUnequipped({
                source = source,
                bagName = bagData.bagName,
                bagLabel = bagConfig and bagConfig.label or bagData.bagName,
                slotName = slotName,
                containerId = bagData.containerId
            })
        end
    end
    
    -- Update capacity and sync state bags if any bags were removed
    if #slotsToRemove > 0 then
        UpdatePlayerCapacity(source)
        
        -- Sync state bags (replaces client events for cross-client sync)
        if SetPlayerBagsState then
            SetPlayerBagsState(source, EquippedBags[source])
        end
    end
end

-------------------------------------------------------------------------------
-- SCAN INVENTORY (for resource start / player join)
-------------------------------------------------------------------------------

function ScanAndEquipAllBags(source)
    if not source or source <= 0 then return end
    if not GetPlayerPed(source) or GetPlayerPed(source) == 0 then return end
    
    local items = ox_inventory:GetInventoryItems(source)
    if not items then return end
    
    print('[free-hoarder] Scanning inventory for player:', source)
    
    -- Initialize
    if not EquippedBags[source] then
        EquippedBags[source] = {}
    end
    
    -- Find all bags and equip them
    for slot, item in pairs(items) do
        if item and IsBagItem(item.name) then
            AutoEquipBag(source, item.name)
        end
    end
end

-------------------------------------------------------------------------------
-- CALLBACKS (for client requests)
-------------------------------------------------------------------------------

lib.callback.register('free_hoarder:getEquippedBags', function(source)
    return EquippedBags[source] or {}
end)

lib.callback.register('free_hoarder:getAvailableSlots', function(source, bagName)
    local bagConfig = GetBagConfig(bagName)
    if not bagConfig then return {} end
    
    local available = {}
    for _, slotName in ipairs(bagConfig.allowedSlots) do
        if not IsSlotOccupied(source, slotName) then
            table.insert(available, { name = slotName, label = slotName })
        end
    end
    return available
end)

-- Swap bag to different attachment slot
lib.callback.register('free_hoarder:swapBagSlot', function(source, fromSlot, toSlot, bagName)
    local bags = EquippedBags[source]
    if not bags then
        return { success = false, error = 'No bags equipped' }
    end
    
    local bagData = bags[fromSlot]
    if not bagData then
        return { success = false, error = 'Bag not found in slot' }
    end
    
    if bagData.bagName ~= bagName then
        return { success = false, error = 'Bag mismatch' }
    end
    
    -- Check target slot is free
    if bags[toSlot] then
        return { success = false, error = 'Target slot occupied' }
    end
    
    -- Verify bag config allows this slot
    local bagConfig = GetBagConfig(bagName)
    if not bagConfig then
        return { success = false, error = 'Invalid bag' }
    end
    
    local slotValid = false
    for _, allowed in ipairs(bagConfig.allowedSlots) do
        if allowed == toSlot then
            slotValid = true
            break
        end
    end
    
    if not slotValid then
        return { success = false, error = 'Invalid slot for this bag' }
    end
    
    -- Perform swap
    bags[toSlot] = bagData
    bags[fromSlot] = nil
    
    -- Update client props
    TriggerClientEvent('free_hoarder:bagUnequipped', source, fromSlot)
    TriggerClientEvent('free_hoarder:bagEquipped', source, toSlot, bagName, bagConfig)
    
    print('[free-hoarder] Swapped', bagName, 'from', fromSlot, 'to', toSlot, 'for player', source)
    
    return { success = true }
end)

-------------------------------------------------------------------------------
-- OVER-CAPACITY HANDLING
-------------------------------------------------------------------------------

-- Check if player is over capacity and handle excess items
function HandleOverCapacity(source)
    -- Get weight from inventory object (GetPlayerWeight is client-side only)
    local currentWeight = 0
    local inventory = exports.ox_inventory:GetInventory(source, false)
    if inventory and inventory.weight then
        currentWeight = inventory.weight
    end
    
    local maxWeight = Config.BaseWeight or 26500
    -- Add bonus from bags
    local bonusWeight = CalculateTotalBonusCapacity and CalculateTotalBonusCapacity(source) or 0
    maxWeight = maxWeight + bonusWeight
    
    if currentWeight <= maxWeight then
        return -- Not over capacity
    end
    
    local excessWeight = currentWeight - maxWeight
    print('[free-hoarder] Player', source, 'is over capacity by', excessWeight)
    
    -- Option 1: Force drop excess items (configured in Config.OverCapacity)
    if Config.OverCapacity and Config.OverCapacity.forceDrop then
        TriggerEvent('free_hoarder:handleOverCapacity', source, excessWeight)
    end
    
    -- Option 2: Apply movement penalty (always applied via client)
    TriggerClientEvent('free_hoarder:overCapacityWarning', source, excessWeight)
end

-------------------------------------------------------------------------------
-- STARTUP
-------------------------------------------------------------------------------

CreateThread(function()
    Wait(1000)
    local count = 0
    for bagName in pairs(Config.Bags) do
        count = count + 1
    end
    print('[free-hoarder] Loaded', count, 'bag configurations')
end)

-------------------------------------------------------------------------------
-- CONTAINER REGISTRATION
-- Register bags as stash containers in ox_inventory
-------------------------------------------------------------------------------

local RegisteredContainers = {}

---Register a bag as a container for a player
---@param source number
---@param bagName string
---@param containerId string
function RegisterBagContainer(source, bagName, containerId)
    local bagConfig = GetBagConfig(bagName)
    if not bagConfig then return end
    
    -- Create unique stash for this bag
    local stashName = containerId
    
    -- Only register if not already registered
    if RegisteredContainers[stashName] then return end
    
    -- Register the stash with ox_inventory
    local success = pcall(function()
        exports.ox_inventory:RegisterStash(stashName, bagConfig.label or bagName, bagConfig.capacity.slots, bagConfig.capacity.weight)
    end)
    
    if success then
        RegisteredContainers[stashName] = true
        print('[free-hoarder] Registered container:', stashName, 'slots:', bagConfig.capacity.slots, 'weight:', bagConfig.capacity.weight)
    else
        print('[free-hoarder] Failed to register container:', stashName)
    end
end

-------------------------------------------------------------------------------
-- ITEM USE HANDLER
-- Export for ox_inventory item use (when player right-clicks bag)
-- Triggers client-side menu with options: Open Bag, Manage Outfits
-------------------------------------------------------------------------------

exports('useBag', function(event, item, inventory, slot, data)
    print('[free-hoarder] useBag export called! Event:', event, 'Item:', item and item.name or 'nil')
    
    if event ~= 'usingItem' then 
        print('[free-hoarder] Event is not usingItem, ignoring')
        return 
    end
    
    local source = inventory.id
    if not source or type(source) ~= 'number' then 
        print('[free-hoarder] Invalid source:', source)
        return 
    end
    
    print('[free-hoarder] Player', source, 'using bag:', item.name)
    
    local bagConfig = GetBagConfig(item.name)
    if not bagConfig then
        print('[free-hoarder] No bag config found for:', item.name)
        return false
    end
    
    -- Find this bag's container ID and slot from equipped bags
    local bags = EquippedBags[source]
    local containerId = nil
    local bagSlotName = nil
    
    print('[free-hoarder] Equipped bags for player:', json.encode(bags or {}))
    
    if bags then
        for slotName, bagData in pairs(bags) do
            if bagData.bagName == item.name then
                containerId = bagData.containerId
                bagSlotName = slotName
                print('[free-hoarder] Found matching bag in slot', slotName, 'containerId:', containerId)
                break
            end
        end
    end
    
    -- If bag isn't equipped yet, try to equip it first
    if not containerId then
        print('[free-hoarder] Bag not equipped, auto-equipping...')
        AutoEquipBag(source, item.name)
        
        -- Check again after equip
        bags = EquippedBags[source]
        if bags then
            for slotName, bagData in pairs(bags) do
                if bagData.bagName == item.name then
                    containerId = bagData.containerId
                    bagSlotName = slotName
                    print('[free-hoarder] After auto-equip, containerId:', containerId, 'slot:', slotName)
                    break
                end
            end
        end
    end
    
    if not containerId then
        print('[free-hoarder] ERROR: No containerId found, cannot open bag')
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Could not open bag - no available slots'
        })
        return false
    end
    
    -- Register the container if not already registered
    RegisterBagContainer(source, item.name, containerId)
    
    -- Check if outfit saving is enabled for this bag type
    local canStoreOutfits = Config.OutfitSaving 
        and Config.OutfitSaving.enabled 
        and Config.OutfitSaving.allowedBagTypes 
        and Config.OutfitSaving.allowedBagTypes[bagConfig.type]
    
    -- Trigger client-side menu with options
    TriggerClientEvent('free_hoarder:showBagUseMenu', source, {
        bagName = item.name,
        slotName = bagSlotName,
        containerId = containerId,
        bagType = bagConfig.type,
        canStoreOutfits = canStoreOutfits,
        bagLabel = bagConfig.label or item.name
    })
    
    return false -- Don't consume the item
end)

print('[free-hoarder] useBag export registered - right-click bags for options!')

-------------------------------------------------------------------------------
-- OUTFIT STORAGE SYSTEM
-- Store player outfits in bag metadata
-------------------------------------------------------------------------------

-- Cache for bag outfits (containerId -> outfits array)
local BagOutfits = {}

---Get outfits stored in a bag
---@param containerId string
---@return table outfits
local function GetBagOutfitsData(containerId)
    if not containerId then return {} end
    
    -- Check cache first
    if BagOutfits[containerId] then
        return BagOutfits[containerId]
    end
    
    -- Try to load from database/kvp
    local key = 'bag_outfits_' .. containerId
    local data = GetResourceKvpString(key)
    
    if data then
        local outfits = json.decode(data)
        if outfits then
            BagOutfits[containerId] = outfits
            return outfits
        end
    end
    
    return {}
end

---Save outfits to bag storage
---@param containerId string
---@param outfits table
local function SaveBagOutfitsData(containerId, outfits)
    if not containerId then return end
    
    BagOutfits[containerId] = outfits
    
    -- Persist to kvp
    local key = 'bag_outfits_' .. containerId
    SetResourceKvp(key, json.encode(outfits))
end

-- Callback: Save outfit to bag
lib.callback.register('free_hoarder:saveOutfitToBag', function(source, containerId, outfitName, appearance)
    print('[free-hoarder] saveOutfitToBag called - containerId:', containerId, 'name:', outfitName)
    
    if not containerId or not appearance then 
        print('[free-hoarder] saveOutfitToBag FAILED - missing data')
        return false 
    end
    
    local outfits = GetBagOutfitsData(containerId)
    local maxOutfits = Config.OutfitSaving and Config.OutfitSaving.maxOutfitsPerBag or 3
    
    print('[free-hoarder] Current outfits:', #outfits, '/', maxOutfits)
    
    -- Check if bag is full
    if #outfits >= maxOutfits then
        print('[free-hoarder] saveOutfitToBag FAILED - bag full')
        return false
    end
    
    -- Add new outfit
    table.insert(outfits, {
        name = outfitName or ('Outfit %d'):format(#outfits + 1),
        appearance = appearance,
        savedAt = os.date('%Y-%m-%d %H:%M'),
        savedBy = source
    })
    
    SaveBagOutfitsData(containerId, outfits)
    
    print('[free-hoarder] Saved outfit "' .. outfitName .. '" to bag:', containerId, 'Total outfits:', #outfits)
    return true
end)

-- Callback: Get outfit from bag
lib.callback.register('free_hoarder:getOutfitFromBag', function(source, containerId, outfitIndex)
    print('[free-hoarder] getOutfitFromBag called - containerId:', containerId, 'index:', outfitIndex)
    
    if not containerId or not outfitIndex then return nil end
    
    local outfits = GetBagOutfitsData(containerId)
    print('[free-hoarder] Found', #outfits, 'outfits in bag')
    
    if outfitIndex > 0 and outfitIndex <= #outfits then
        return outfits[outfitIndex]
    end
    
    return nil
end)

-- Callback: Get all outfits from bag
lib.callback.register('free_hoarder:getBagOutfits', function(source, containerId)
    print('[free-hoarder] getBagOutfits called - containerId:', containerId)
    
    if not containerId then return {} end
    
    local outfits = GetBagOutfitsData(containerId)
    print('[free-hoarder] Found', #outfits, 'outfits in bag:', containerId)
    
    -- Return simplified list (don't send full appearance data for list)
    local list = {}
    for i, outfit in ipairs(outfits) do
        print('[free-hoarder]   -', i, ':', outfit.name)
        table.insert(list, {
            name = outfit.name,
            savedAt = outfit.savedAt,
            index = i
        })
    end
    
    return list
end)

-- Callback: Delete outfit from bag
lib.callback.register('free_hoarder:deleteOutfitFromBag', function(source, containerId, outfitIndex)
    if not containerId or not outfitIndex then return false end
    
    local outfits = GetBagOutfitsData(containerId)
    
    if outfitIndex > 0 and outfitIndex <= #outfits then
        local removed = table.remove(outfits, outfitIndex)
        SaveBagOutfitsData(containerId, outfits)
        
        print('[free-hoarder] Deleted outfit "' .. (removed.name or 'unknown') .. '" from bag:', containerId)
        return true
    end
    
    return false
end)

print('[free-hoarder] Outfit storage system initialized')
