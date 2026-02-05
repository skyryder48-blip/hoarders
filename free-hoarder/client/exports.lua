--[[
    Client Exports - free-hoarder v2.0
    Centralized export functions for external resource integration
    
    Usage from other resources:
    exports['free-hoarder']:GetEquippedBags()
    exports['free-hoarder']:GetTotalCapacity()
    etc.
]]

-------------------------------------------------------------------------------
-- BAG STATE EXPORTS
-------------------------------------------------------------------------------

---Get all currently equipped bags for the local player
---@return table<string, table> Table of slotName -> bagData
local function GetEquippedBagsExport()
    if not LocalEquippedBags then return {} end
    return DeepCopy(LocalEquippedBags)
end
exports('GetEquippedBags', GetEquippedBagsExport)

---Check if player has any bags equipped
---@return boolean
local function HasAnyBagEquipped()
    if not LocalEquippedBags then return false end
    for _ in pairs(LocalEquippedBags) do
        return true
    end
    return false
end
exports('HasAnyBagEquipped', HasAnyBagEquipped)

---Check if player has a specific bag type equipped
---@param bagType string BagType enum value (backpack, shoulderbag, handbag, twohand, tucked)
---@return boolean
local function HasBagType(bagType)
    if not LocalEquippedBags then return false end
    for _, bagData in pairs(LocalEquippedBags) do
        if bagData.type == bagType then
            return true
        end
    end
    return false
end
exports('HasBagType', HasBagType)

---Get bag data for a specific slot
---@param slotName string AttachmentSlot enum value
---@return table|nil bagData
local function GetBagInSlot(slotName)
    if not LocalEquippedBags or not LocalEquippedBags[slotName] then return nil end
    return DeepCopy(LocalEquippedBags[slotName])
end
exports('GetBagInSlot', GetBagInSlot)

---Get the number of equipped bags
---@return number
local function GetEquippedBagCount()
    if not LocalEquippedBags then return 0 end
    local count = 0
    for _ in pairs(LocalEquippedBags) do
        count = count + 1
    end
    return count
end
exports('GetEquippedBagCount', GetEquippedBagCount)

-------------------------------------------------------------------------------
-- CAPACITY EXPORTS
-------------------------------------------------------------------------------

---Get total capacity (base + bonus from bags)
---@return table {weight: number, slots: number}
local function GetTotalCapacity()
    local baseWeight = Config and Config.BaseWeight or 26500
    local baseSlots = Config and Config.BaseSlots or 17
    
    local bonusWeight, bonusSlots = 0, 0
    if GetTotalBonusCapacity then
        bonusWeight, bonusSlots = GetTotalBonusCapacity()
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
exports('GetTotalCapacity', GetTotalCapacity)

---Get current weight from ox_inventory
---@return number currentWeight in grams
local function GetCurrentWeightExport()
    if GetCurrentWeight then
        return GetCurrentWeight()
    end
    return 0
end
exports('GetCurrentWeight', GetCurrentWeightExport)

---Get current max weight (base + bonuses)
---@return number maxWeight in grams
local function GetCurrentMaxWeightExport()
    if GetCurrentMaxWeight then
        return GetCurrentMaxWeight()
    end
    return Config and Config.BaseWeight or 26500
end
exports('GetCurrentMaxWeight', GetCurrentMaxWeightExport)

---Get capacity percentage (how full inventory is)
---@return number percentage 0-100+
local function GetCapacityPercentage()
    local current = GetCurrentWeightExport()
    local max = GetCurrentMaxWeightExport()
    if max <= 0 then return 0 end
    return (current / max) * 100
end
exports('GetCapacityPercentage', GetCapacityPercentage)

---Check if player is over capacity
---@return boolean
local function IsOverCapacityExport()
    if IsOverCapacity then
        return IsOverCapacity()
    end
    return GetCapacityPercentage() > 100
end
exports('IsOverCapacity', IsOverCapacityExport)

-------------------------------------------------------------------------------
-- WEAPON RESTRICTION EXPORTS
-------------------------------------------------------------------------------

---Check if weapons are currently restricted
---@return boolean restricted
---@return string|nil reason
local function AreWeaponsRestricted()
    if not LocalEquippedBags then return false, nil end
    
    for slotName, bagData in pairs(LocalEquippedBags) do
        -- Two-hand items block ALL weapons
        if IsTwoHandSlot(slotName) then
            return true, 'Carrying two-hand item'
        end
        
        -- Hand bags restrict most weapons
        if IsHandSlot(slotName) and bagData.restrictsWeapons then
            return true, 'Holding a bag'
        end
    end
    
    return false, nil
end
exports('AreWeaponsRestricted', AreWeaponsRestricted)

---Check if a specific weapon is allowed with current bags
---@param weaponHash number
---@return boolean allowed
---@return string|nil reason
local function IsWeaponAllowed(weaponHash)
    if IsWeaponRestricted and type(IsWeaponRestricted) == 'function' then
        local restricted = IsWeaponRestricted(weaponHash)
        if restricted then
            return false, 'Weapon restricted by equipped bags'
        end
    end
    return true, nil
end
exports('IsWeaponAllowed', IsWeaponAllowed)

-------------------------------------------------------------------------------
-- LOCK STATE EXPORTS (for Phase 2)
-------------------------------------------------------------------------------

---Check if a bag in a specific slot is locked
---@param slotName string
---@return boolean
local function IsBagLocked(slotName)
    if not LocalEquippedBags or not LocalEquippedBags[slotName] then return false end
    local bagData = LocalEquippedBags[slotName]
    return bagData.lock and bagData.lock.isLocked or false
end
exports('IsBagLocked', IsBagLocked)

---Get lock type for a bag
---@param slotName string
---@return string|nil lockType 'pin'|'key'|'padlock'|'biometric' or nil if not locked
local function GetBagLockType(slotName)
    if not LocalEquippedBags or not LocalEquippedBags[slotName] then return nil end
    local bagData = LocalEquippedBags[slotName]
    if bagData.lock and bagData.lock.isLocked then
        return bagData.lock.type
    end
    return nil
end
exports('GetBagLockType', GetBagLockType)

-------------------------------------------------------------------------------
-- DURABILITY EXPORTS (for Phase 3)
-------------------------------------------------------------------------------

---Get durability of a bag in a specific slot
---@param slotName string
---@return number|nil durability Percentage (0-100) or nil if no durability system
local function GetBagDurability(slotName)
    if not LocalEquippedBags or not LocalEquippedBags[slotName] then return nil end
    local bagData = LocalEquippedBags[slotName]
    return bagData.durability
end
exports('GetBagDurability', GetBagDurability)

---Check if a bag is about to break (durability < 5%)
---@param slotName string
---@return boolean
local function IsBagAboutToBreak(slotName)
    local durability = GetBagDurability(slotName)
    if not durability then return false end
    return durability < 5
end
exports('IsBagAboutToBreak', IsBagAboutToBreak)

-------------------------------------------------------------------------------
-- PROP/VISUAL EXPORTS
-------------------------------------------------------------------------------

---Get the prop entity handle for a bag slot
---@param slotName string
---@return number|nil entityHandle
local function GetPropHandleExport(slotName)
    if GetPropHandle then
        return GetPropHandle(slotName)
    end
    return nil
end
exports('GetPropHandle', GetPropHandleExport)

---Check if two-hand carry animation is active
---@return boolean
local function IsTwoHandCarryActiveExport()
    if IsTwoHandCarryActive then
        return IsTwoHandCarryActive()
    end
    return false
end
exports('IsTwoHandCarryActive', IsTwoHandCarryActiveExport)

---Check if a bag is hidden by clothing conflict
---@param slotName string
---@return boolean
local function IsBagHiddenByClothingExport(slotName)
    if IsBagHiddenByClothing then
        return IsBagHiddenByClothing(slotName)
    end
    return false
end
exports('IsBagHiddenByClothing', IsBagHiddenByClothingExport)

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
