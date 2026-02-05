--[[
    Server Exports - free-hoarder v2.0
    Centralized export functions for external resource integration
    
    Usage from other resources:
    exports['free-hoarder']:GetPlayerEquippedBags(source)
    exports['free-hoarder']:GetPlayerTotalCapacity(source)
    etc.
]]

-------------------------------------------------------------------------------
-- BAG STATE EXPORTS
-------------------------------------------------------------------------------

---Get all equipped bags for a player
---@param source number Player server ID
---@return table<string, table> Table of slotName -> bagData
local function GetPlayerEquippedBagsExport(source)
    if not source or source <= 0 then return {} end
    if not EquippedBags or not EquippedBags[source] then return {} end
    return DeepCopy(EquippedBags[source])
end
exports('GetPlayerEquippedBags', GetPlayerEquippedBagsExport)

---Check if a player has any bags equipped
---@param source number Player server ID
---@return boolean
local function PlayerHasAnyBag(source)
    if not source or source <= 0 then return false end
    if not EquippedBags or not EquippedBags[source] then return false end
    for _ in pairs(EquippedBags[source]) do
        return true
    end
    return false
end
exports('PlayerHasAnyBag', PlayerHasAnyBag)

---Check if a player has a specific bag type equipped
---@param source number Player server ID
---@param bagType string BagType enum value
---@return boolean
local function PlayerHasBagType(source, bagType)
    if not source or source <= 0 then return false end
    if not EquippedBags or not EquippedBags[source] then return false end
    
    for _, bagData in pairs(EquippedBags[source]) do
        local config = GetBagConfig(bagData.bagName)
        if config and config.type == bagType then
            return true
        end
    end
    return false
end
exports('PlayerHasBagType', PlayerHasBagType)

---Get bag data for a specific slot on a player
---@param source number Player server ID
---@param slotName string AttachmentSlot enum value
---@return table|nil bagData
local function GetPlayerBagInSlot(source, slotName)
    if not source or source <= 0 then return nil end
    if not EquippedBags or not EquippedBags[source] then return nil end
    if not EquippedBags[source][slotName] then return nil end
    return DeepCopy(EquippedBags[source][slotName])
end
exports('GetPlayerBagInSlot', GetPlayerBagInSlot)

---Get the number of bags a player has equipped
---@param source number Player server ID
---@return number
local function GetPlayerEquippedBagCount(source)
    if not source or source <= 0 then return 0 end
    if not EquippedBags or not EquippedBags[source] then return 0 end
    local count = 0
    for _ in pairs(EquippedBags[source]) do
        count = count + 1
    end
    return count
end
exports('GetPlayerEquippedBagCount', GetPlayerEquippedBagCount)

-------------------------------------------------------------------------------
-- CAPACITY EXPORTS
-------------------------------------------------------------------------------

---Get total capacity for a player (base + bonus from bags)
---@param source number Player server ID
---@return table {weight: number, slots: number, bonusWeight: number, bonusSlots: number}
local function GetPlayerTotalCapacity(source)
    local baseWeight = Config and Config.BaseWeight or 26500
    local baseSlots = Config and Config.BaseSlots or 17
    
    local bonusWeight, bonusSlots = 0, 0
    if GetPlayerBonusCapacity then
        bonusWeight, bonusSlots = GetPlayerBonusCapacity(source)
    end
    
    return {
        weight = baseWeight + bonusWeight,
        slots = baseSlots + bonusSlots,
        bonusWeight = bonusWeight,
        bonusSlots = bonusSlots,
        baseWeight = baseWeight,
        baseSlots = baseSlots
    }
end
exports('GetPlayerTotalCapacity', GetPlayerTotalCapacity)

---Get bonus capacity from bags only
---@param source number Player server ID
---@return number bonusWeight
---@return number bonusSlots
local function GetPlayerBonusCapacityExport(source)
    if GetPlayerBonusCapacity then
        return GetPlayerBonusCapacity(source)
    end
    return 0, 0
end
exports('GetPlayerBonusCapacity', GetPlayerBonusCapacityExport)

-------------------------------------------------------------------------------
-- BAG MANIPULATION EXPORTS
-------------------------------------------------------------------------------

---Force equip a bag on a player (admin/script use)
---@param source number Player server ID
---@param bagName string Item name of the bag
---@param slotName string? Preferred slot (auto-selected if nil)
---@return boolean success
---@return string|nil error
local function ForceEquipBag(source, bagName, slotName)
    if not source or source <= 0 then
        return false, 'Invalid player source'
    end
    
    local bagConfig = GetBagConfig(bagName)
    if not bagConfig then
        return false, 'Unknown bag: ' .. tostring(bagName)
    end
    
    -- Auto-select slot if not provided
    if not slotName then
        local allowedSlots = bagConfig.allowedSlots
        if allowedSlots and #allowedSlots > 0 then
            -- Find first empty allowed slot
            for _, slot in ipairs(allowedSlots) do
                if not EquippedBags[source] or not EquippedBags[source][slot] then
                    slotName = slot
                    break
                end
            end
        end
        
        if not slotName then
            return false, 'No available slot for this bag type'
        end
    end
    
    -- Equip the bag
    if EquipBagInSlot then
        local success = EquipBagInSlot(source, slotName, bagName, {})
        if success then
            return true, nil
        else
            return false, 'Failed to equip bag'
        end
    end
    
    return false, 'EquipBagInSlot function not available'
end
exports('ForceEquipBag', ForceEquipBag)

---Force unequip a bag from a player
---@param source number Player server ID
---@param slotName string Slot to unequip from
---@return boolean success
---@return string|nil error
local function ForceUnequipBagExport(source, slotName)
    if not source or source <= 0 then
        return false, 'Invalid player source'
    end
    
    if not EquippedBags or not EquippedBags[source] or not EquippedBags[source][slotName] then
        return false, 'No bag in slot: ' .. tostring(slotName)
    end
    
    if ForceUnequipBag then
        ForceUnequipBag(source, slotName)
        return true, nil
    end
    
    return false, 'ForceUnequipBag function not available'
end
exports('ForceUnequipBag', ForceUnequipBagExport)

---Force unequip all bags from a player
---@param source number Player server ID
---@return number unequippedCount
local function ForceUnequipAllBags(source)
    if not source or source <= 0 then return 0 end
    if not EquippedBags or not EquippedBags[source] then return 0 end
    
    local count = 0
    local slots = {}
    
    -- Collect slots first to avoid modifying during iteration
    for slotName in pairs(EquippedBags[source]) do
        table.insert(slots, slotName)
    end
    
    for _, slotName in ipairs(slots) do
        local success = ForceUnequipBagExport(source, slotName)
        if success then
            count = count + 1
        end
    end
    
    return count
end
exports('ForceUnequipAllBags', ForceUnequipAllBags)

-------------------------------------------------------------------------------
-- BAG CONTENTS EXPORTS
-------------------------------------------------------------------------------

---Get the contents of a player's bag
---@param source number Player server ID
---@param slotName string Attachment slot
---@return table|nil items Array of items in the bag, or nil if not found
local function GetBagContents(source, slotName)
    if not source or source <= 0 then return nil end
    if not EquippedBags or not EquippedBags[source] then return nil end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.containerId then return nil end
    
    -- Get items from ox_inventory stash
    local inventory = exports.ox_inventory:GetInventory(bagData.containerId, false)
    if not inventory then return nil end
    
    return inventory.items or {}
end
exports('GetBagContents', GetBagContents)

---Check if a bag is empty
---@param source number Player server ID
---@param slotName string Attachment slot
---@return boolean|nil isEmpty (nil if bag not found)
local function IsBagEmpty(source, slotName)
    local contents = GetBagContents(source, slotName)
    if contents == nil then return nil end
    
    for _, item in pairs(contents) do
        if item then return false end
    end
    return true
end
exports('IsBagEmpty', IsBagEmpty)

-------------------------------------------------------------------------------
-- LOCK EXPORTS (for Phase 2)
-------------------------------------------------------------------------------

---Set lock state on a player's bag
---@param source number Player server ID
---@param slotName string Attachment slot
---@param lockData table|nil Lock data or nil to remove lock
---@return boolean success
local function SetBagLock(source, slotName, lockData)
    if not source or source <= 0 then return false end
    if not EquippedBags or not EquippedBags[source] then return false end
    if not EquippedBags[source][slotName] then return false end
    
    EquippedBags[source][slotName].lock = lockData
    
    -- Sync to client
    TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lockData)
    
    return true
end
exports('SetBagLock', SetBagLock)

---Check if a player's bag is locked
---@param source number Player server ID
---@param slotName string Attachment slot
---@return boolean
local function IsBagLockedServer(source, slotName)
    if not source or source <= 0 then return false end
    if not EquippedBags or not EquippedBags[source] then return false end
    if not EquippedBags[source][slotName] then return false end
    
    local bagData = EquippedBags[source][slotName]
    return bagData.lock and bagData.lock.isLocked or false
end
exports('IsBagLocked', IsBagLockedServer)

-------------------------------------------------------------------------------
-- DURABILITY EXPORTS (for Phase 3)
-------------------------------------------------------------------------------

---Set durability on a player's bag
---@param source number Player server ID
---@param slotName string Attachment slot
---@param durability number Durability percentage (0-100)
---@return boolean success
local function SetBagDurability(source, slotName, durability)
    if not source or source <= 0 then return false end
    if not EquippedBags or not EquippedBags[source] then return false end
    if not EquippedBags[source][slotName] then return false end
    
    durability = math.max(0, math.min(100, durability))
    EquippedBags[source][slotName].durability = durability
    
    -- Sync to client
    TriggerClientEvent('free_hoarder:bagDurabilityUpdated', source, slotName, durability)
    
    return true
end
exports('SetBagDurability', SetBagDurability)

---Get durability of a player's bag
---@param source number Player server ID
---@param slotName string Attachment slot
---@return number|nil durability
local function GetBagDurabilityServer(source, slotName)
    if not source or source <= 0 then return nil end
    if not EquippedBags or not EquippedBags[source] then return nil end
    if not EquippedBags[source][slotName] then return nil end
    
    return EquippedBags[source][slotName].durability
end
exports('GetBagDurability', GetBagDurabilityServer)

-------------------------------------------------------------------------------
-- UTILITY EXPORTS
-------------------------------------------------------------------------------

---Get the config for a specific bag item
---@param itemName string
---@return table|nil bagConfig
local function GetBagConfigExport(itemName)
    if GetBagConfig then
        return DeepCopy(GetBagConfig(itemName))
    end
    return nil
end
exports('GetBagConfig', GetBagConfigExport)

---Check if an item is a bag
---@param itemName string
---@return boolean
local function IsBagItemExport(itemName)
    if IsBagItem then
        return IsBagItem(itemName)
    end
    return false
end
exports('IsBagItem', IsBagItemExport)

---Get all bag configurations
---@return table All bag configs
local function GetAllBagConfigs()
    if Config and Config.Bags then
        return DeepCopy(Config.Bags)
    end
    return {}
end
exports('GetAllBagConfigs', GetAllBagConfigs)
