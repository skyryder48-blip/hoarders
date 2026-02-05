--[[
    Shared Utilities for free-hoarder v2.0
    Contains constants, enums, helper functions, notifications, and event definitions
    Used by both client and server
]]

-------------------------------------------------------------------------------
-- ENUMS AND CONSTANTS
-------------------------------------------------------------------------------

-- Attachment slot definitions
---@enum AttachmentSlot
AttachmentSlot = {
    BACK = 'BACK',
    FRONT = 'FRONT',
    LEFT_SHOULDER = 'LEFT_SHOULDER',
    RIGHT_SHOULDER = 'RIGHT_SHOULDER',
    LEFT_HAND = 'LEFT_HAND',
    RIGHT_HAND = 'RIGHT_HAND',
    TWO_HAND = 'TWO_HAND',
    TUCKED = 'TUCKED'
}

-- Bag type categories
---@enum BagType
BagType = {
    BACKPACK = 'backpack',
    SHOULDERBAG = 'shoulderbag',
    HANDBAG = 'handbag',
    TWOHAND = 'twohand',
    TUCKED = 'tucked'
}

-- Movement states
---@enum MovementState
MovementState = {
    IDLE = 'idle',
    WALK = 'walk',
    RUN = 'run',
    SPRINT = 'sprint'
}

-- Ped bone IDs for attachment points
---@type table<string, number>
BoneIds = {
    [AttachmentSlot.BACK] = 24817,
    [AttachmentSlot.FRONT] = 24816,
    [AttachmentSlot.LEFT_SHOULDER] = 64729,
    [AttachmentSlot.RIGHT_SHOULDER] = 10706,
    [AttachmentSlot.LEFT_HAND] = 60309,
    [AttachmentSlot.RIGHT_HAND] = 28422,
    [AttachmentSlot.TWO_HAND] = 60309,
    [AttachmentSlot.TUCKED] = nil
}

-- Slot to bag type mapping
---@type table<string, string[]>
SlotAllowedTypes = {
    [AttachmentSlot.BACK] = { BagType.BACKPACK },
    [AttachmentSlot.FRONT] = { BagType.BACKPACK },
    [AttachmentSlot.LEFT_SHOULDER] = { BagType.SHOULDERBAG },
    [AttachmentSlot.RIGHT_SHOULDER] = { BagType.SHOULDERBAG },
    [AttachmentSlot.LEFT_HAND] = { BagType.HANDBAG },
    [AttachmentSlot.RIGHT_HAND] = { BagType.HANDBAG },
    [AttachmentSlot.TWO_HAND] = { BagType.TWOHAND },
    [AttachmentSlot.TUCKED] = { BagType.TUCKED }
}

-- Allowed weapon groups (melee only)
---@type table<number, boolean>
AllowedWeaponGroups = {
    [2685387236] = true,
    [3566412244] = true,
}

-- Long gun weapon hashes
---@type table<number, boolean>
LongGunWeapons = {
    [`WEAPON_ASSAULTRIFLE`] = true,
    [`WEAPON_ASSAULTRIFLE_MK2`] = true,
    [`WEAPON_CARBINERIFLE`] = true,
    [`WEAPON_CARBINERIFLE_MK2`] = true,
    [`WEAPON_ADVANCEDRIFLE`] = true,
    [`WEAPON_SPECIALCARBINE`] = true,
    [`WEAPON_SPECIALCARBINE_MK2`] = true,
    [`WEAPON_BULLPUPRIFLE`] = true,
    [`WEAPON_BULLPUPRIFLE_MK2`] = true,
    [`WEAPON_COMPACTRIFLE`] = true,
    [`WEAPON_MILITARYRIFLE`] = true,
    [`WEAPON_HEAVYRIFLE`] = true,
    [`WEAPON_TACTICALRIFLE`] = true,
    [`WEAPON_PUMPSHOTGUN`] = true,
    [`WEAPON_PUMPSHOTGUN_MK2`] = true,
    [`WEAPON_SAWNOFFSHOTGUN`] = true,
    [`WEAPON_ASSAULTSHOTGUN`] = true,
    [`WEAPON_BULLPUPSHOTGUN`] = true,
    [`WEAPON_MUSKET`] = true,
    [`WEAPON_HEAVYSHOTGUN`] = true,
    [`WEAPON_DBSHOTGUN`] = true,
    [`WEAPON_AUTOSHOTGUN`] = true,
    [`WEAPON_COMBATSHOTGUN`] = true,
}

-- Sniper rifle weapon hashes
---@type table<number, boolean>
SniperWeapons = {
    [`WEAPON_SNIPERRIFLE`] = true,
    [`WEAPON_HEAVYSNIPER`] = true,
    [`WEAPON_HEAVYSNIPER_MK2`] = true,
    [`WEAPON_MARKSMANRIFLE`] = true,
    [`WEAPON_MARKSMANRIFLE_MK2`] = true,
    [`WEAPON_PRECISIONRIFLE`] = true,
}

-------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-------------------------------------------------------------------------------

---Check if a bag type is allowed in a specific slot
---@param bagType string
---@param slotName string
---@return boolean
function IsBagTypeAllowedInSlot(bagType, slotName)
    local allowedTypes = SlotAllowedTypes[slotName]
    if not allowedTypes then return false end
    for _, allowed in ipairs(allowedTypes) do
        if allowed == bagType then return true end
    end
    return false
end

---Check if a slot is a hand slot
---@param slotName string
---@return boolean
function IsHandSlot(slotName)
    return slotName == AttachmentSlot.LEFT_HAND or slotName == AttachmentSlot.RIGHT_HAND
end

---Check if a slot is a two-hand slot
---@param slotName string
---@return boolean
function IsTwoHandSlot(slotName)
    return slotName == AttachmentSlot.TWO_HAND
end

---Check if a slot is tucked
---@param slotName string
---@return boolean
function IsTuckedSlot(slotName)
    return slotName == AttachmentSlot.TUCKED
end

---Check if a bag type is tucked
---@param bagType string
---@return boolean
function IsTuckedBagType(bagType)
    return bagType == BagType.TUCKED or bagType == 'tucked'
end

---Get all slots for a specific bag type
---@param bagType string
---@return string[]
function GetSlotsForBagType(bagType)
    local slots = {}
    for slot, types in pairs(SlotAllowedTypes) do
        for _, t in ipairs(types) do
            if t == bagType then
                table.insert(slots, slot)
                break
            end
        end
    end
    return slots
end

---Convert grams to human-readable format
---@param grams number
---@param useGramsUnder1kg boolean?
---@return string
function FormatWeight(grams, useGramsUnder1kg)
    if useGramsUnder1kg and grams < 1000 then
        return string.format('%dg', grams)
    end
    return string.format('%.1f kg', grams / 1000)
end

---Check if a weapon is a long gun
---@param weaponHash number
---@return boolean
function IsLongGun(weaponHash)
    return LongGunWeapons[weaponHash] == true
end

---Check if a weapon is a sniper
---@param weaponHash number
---@return boolean
function IsSniper(weaponHash)
    return SniperWeapons[weaponHash] == true
end

---Deep copy a table
---@param orig table
---@return table
function DeepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in next, orig, nil do
            copy[DeepCopy(k)] = DeepCopy(v)
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

---Print debug message
---@param ... any
function DebugPrint(...)
    if Config and Config.Debug then
        print('[free-hoarder]', ...)
    end
end

---Format slot name for display
---@param slotName string
---@return string
function FormatSlotLabel(slotName)
    local labels = {
        ['BACK'] = 'Back',
        ['FRONT'] = 'Front',
        ['LEFT_SHOULDER'] = 'Left Shoulder',
        ['RIGHT_SHOULDER'] = 'Right Shoulder',
        ['LEFT_HAND'] = 'Left Hand',
        ['RIGHT_HAND'] = 'Right Hand',
        ['TWO_HAND'] = 'Carrying',
        ['TUCKED'] = 'Concealed',
    }
    return labels[slotName] or slotName:gsub('_', ' '):lower():gsub('^%l', string.upper)
end

---Get icon for a slot type
---@param slotName string
---@return string
function GetSlotIcon(slotName)
    local icons = {
        ['BACK'] = 'backpack',
        ['FRONT'] = 'backpack',
        ['LEFT_SHOULDER'] = 'suitcase',
        ['RIGHT_SHOULDER'] = 'suitcase',
        ['LEFT_HAND'] = 'hand-holding',
        ['RIGHT_HAND'] = 'hand-holding',
        ['TWO_HAND'] = 'box',
        ['TUCKED'] = 'wallet',
    }
    return icons[slotName] or 'bag-shopping'
end

-------------------------------------------------------------------------------
-- NOTIFICATION SYSTEM
-------------------------------------------------------------------------------

---@class NotificationData
---@field title string?
---@field description string
---@field type 'success'|'error'|'warning'|'info'
---@field duration number?
---@field position string?
---@field icon string?

---Send a notification
---@param data NotificationData
function Notify(data)
    if not data or not data.description then return end
    data.type = data.type or 'info'
    data.duration = data.duration or 3000
    
    if lib and lib.notify then
        lib.notify({
            title = data.title,
            description = data.description,
            type = data.type,
            duration = data.duration,
            position = data.position or 'top',
            icon = data.icon
        })
        return
    end
    
    print(('[free-hoarder] [%s] %s: %s'):format(string.upper(data.type), data.title or 'Notification', data.description))
end

function NotifySuccess(description, title)
    Notify({ title = title, description = description, type = 'success', icon = 'check' })
end

function NotifyError(description, title)
    Notify({ title = title, description = description, type = 'error', icon = 'xmark' })
end

function NotifyWarning(description, title)
    Notify({ title = title, description = description, type = 'warning', icon = 'triangle-exclamation' })
end

function NotifyInfo(description, title)
    Notify({ title = title, description = description, type = 'info', icon = 'circle-info' })
end

-- Bag-specific notifications (check Config.Notifications flags)
function NotifyBagEquipped(bagLabel)
    if Config and Config.Notifications and not Config.Notifications.onEquip then return end
    NotifySuccess(bagLabel .. ' equipped', 'Bag')
end

function NotifyBagUnequipped(bagLabel)
    if Config and Config.Notifications and not Config.Notifications.onUnequip then return end
    NotifyInfo(bagLabel .. ' removed', 'Bag')
end

function NotifyBagDropped(bagLabel)
    if Config and Config.Notifications and not Config.Notifications.onDrop then return end
    NotifyInfo('You dropped your ' .. bagLabel)
end

function NotifyWeaponBlocked(reason)
    if Config and Config.Notifications and not Config.Notifications.onWeaponBlock then return end
    NotifyWarning(reason or 'Cannot use weapons while carrying this item')
end

function NotifyCapacityChanged(weightBonus, slotBonus)
    if Config and Config.Notifications and not Config.Notifications.onCapacityChange then return end
    NotifyInfo(('+%s capacity, +%d slots'):format(FormatWeight(weightBonus), slotBonus))
end

function NotifyDurabilityLow(bagLabel, durability)
    if Config and Config.Notifications and not Config.Notifications.onDurabilityLow then return end
    NotifyWarning(('%s is wearing out (%d%% remaining)'):format(bagLabel, durability), 'Warning')
end

function NotifyDurabilityCritical(bagLabel)
    if Config and Config.Notifications and not Config.Notifications.onDurabilityLow then return end
    NotifyError(bagLabel .. ' is about to break!', 'Critical')
end

function NotifyBagBroken(bagLabel)
    if Config and Config.Notifications and not Config.Notifications.onDurabilityBreak then return end
    NotifyError(bagLabel .. ' has broken! Contents dropped.', 'Bag Destroyed')
end

function NotifyJobRestriction(reason)
    if Config and Config.Notifications and not Config.Notifications.onJobRestriction then return end
    NotifyError(reason or 'You cannot use this bag')
end

function NotifyBagLocked(bagLabel)
    NotifyInfo(bagLabel .. ' has been locked')
end

function NotifyBagUnlocked(bagLabel)
    NotifySuccess(bagLabel .. ' has been unlocked')
end

function NotifyWrongPIN(attemptsRemaining)
    if attemptsRemaining then
        NotifyError(('Wrong PIN. %d attempts remaining'):format(attemptsRemaining))
    else
        NotifyError('Wrong PIN')
    end
end

function NotifyBagRepaired(bagLabel)
    NotifySuccess(bagLabel .. ' has been repaired')
end

function NotifySearchStarted(targetName)
    NotifyInfo('Searching ' .. targetName .. '...')
end

function NotifyBagTaken(bagLabel, fromName)
    NotifySuccess(('Took %s from %s'):format(bagLabel, fromName))
end

function NotifyBagTakenFromYou(bagLabel, byName)
    NotifyWarning(('%s took your %s'):format(byName, bagLabel))
end

-------------------------------------------------------------------------------
-- EVENT SYSTEM
-------------------------------------------------------------------------------

HoarderEvents = {
    BAG_EQUIPPED = 'free_hoarder:%s:onBagEquipped',
    BAG_UNEQUIPPED = 'free_hoarder:%s:onBagUnequipped',
    BAG_OPENED = 'free_hoarder:%s:onBagOpened',
    BAG_CLOSED = 'free_hoarder:%s:onBagClosed',
    BAG_DROPPED = 'free_hoarder:%s:onBagDropped',
    BAG_THROWN = 'free_hoarder:%s:onBagThrown',
    BAG_LOCKED = 'free_hoarder:%s:onBagLocked',
    BAG_UNLOCKED = 'free_hoarder:%s:onBagUnlocked',
    BAG_LOCK_BYPASSED = 'free_hoarder:%s:onBagLockBypassed',
    BAG_LOCK_FAILED = 'free_hoarder:%s:onBagLockFailed',
    BAG_DURABILITY_CHANGED = 'free_hoarder:%s:onBagDurabilityChanged',
    BAG_DURABILITY_LOW = 'free_hoarder:%s:onBagDurabilityLow',
    BAG_BROKEN = 'free_hoarder:%s:onBagBroken',
    BAG_REPAIRED = 'free_hoarder:%s:onBagRepaired',
    BAG_SEARCHED = 'free_hoarder:%s:onBagSearched',
    BAG_TAKEN = 'free_hoarder:%s:onBagTaken',
    CAPACITY_CHANGED = 'free_hoarder:%s:onCapacityChanged',
    ANIMATION_STARTED = 'free_hoarder:%s:onAnimationStarted',
    ANIMATION_COMPLETED = 'free_hoarder:%s:onAnimationCompleted',
    ANIMATION_CANCELLED = 'free_hoarder:%s:onAnimationCancelled',
}

local function GetEventName(eventKey, isServer)
    return eventKey:format(isServer and 'server' or 'client')
end

function TriggerHoarderEvent(eventKey, ...)
    local isServer = IsDuplicityVersion()
    local eventName = GetEventName(eventKey, isServer)
    TriggerEvent(eventName, ...)
    if Config and Config.Debug then
        print(('[free-hoarder] Event: %s'):format(eventName))
    end
end

function TriggerHoarderClientEvent(eventKey, ...)
    if not IsDuplicityVersion() then return end
    TriggerClientEvent(GetEventName(eventKey, false), -1, ...)
end

function TriggerHoarderClientEventForPlayer(source, eventKey, ...)
    if not IsDuplicityVersion() then return end
    TriggerClientEvent(GetEventName(eventKey, false), source, ...)
end

function TriggerHoarderServerEvent(eventKey, ...)
    if IsDuplicityVersion() then return end
    TriggerServerEvent(GetEventName(eventKey, true), ...)
end

-- Convenience event triggers
function TriggerBagEquipped(data) TriggerHoarderEvent(HoarderEvents.BAG_EQUIPPED, data) end
function TriggerBagUnequipped(data) TriggerHoarderEvent(HoarderEvents.BAG_UNEQUIPPED, data) end
function TriggerBagOpened(data) TriggerHoarderEvent(HoarderEvents.BAG_OPENED, data) end
function TriggerBagClosed(data) TriggerHoarderEvent(HoarderEvents.BAG_CLOSED, data) end
function TriggerBagDropped(data) TriggerHoarderEvent(HoarderEvents.BAG_DROPPED, data) end
function TriggerBagLocked(data) TriggerHoarderEvent(HoarderEvents.BAG_LOCKED, data) end
function TriggerBagUnlocked(data) TriggerHoarderEvent(HoarderEvents.BAG_UNLOCKED, data) end
function TriggerBagLockBypassed(data) TriggerHoarderEvent(HoarderEvents.BAG_LOCK_BYPASSED, data) end
function TriggerBagDurabilityChanged(data) TriggerHoarderEvent(HoarderEvents.BAG_DURABILITY_CHANGED, data) end
function TriggerBagBroken(data) TriggerHoarderEvent(HoarderEvents.BAG_BROKEN, data) end
function TriggerBagRepaired(data) TriggerHoarderEvent(HoarderEvents.BAG_REPAIRED, data) end
function TriggerBagSearched(data) TriggerHoarderEvent(HoarderEvents.BAG_SEARCHED, data) end
function TriggerBagTaken(data) TriggerHoarderEvent(HoarderEvents.BAG_TAKEN, data) end
function TriggerCapacityChanged(data) TriggerHoarderEvent(HoarderEvents.CAPACITY_CHANGED, data) end
