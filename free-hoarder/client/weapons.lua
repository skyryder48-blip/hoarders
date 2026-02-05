--[[
    Client Weapons - free-hoarder
    Handles weapon restrictions based on equipped bags
    
    HANDBAGS (clutch, briefcase, shopping bag) in HAND slots:
    - Blocks two-handed weapons
    
    TWO-HAND CARRY (boxes, crates):
    - Blocks ALL weapons
    
    RESTRICTION METHODS:
    - 'drop_to_ground' = Bag physically drops as pickup when weapon drawn
    - 'block_weapon' = Weapon wheel/selection blocked entirely (recommended)
]]

-------------------------------------------------------------------------------
-- CONFIGURATION
-------------------------------------------------------------------------------

-- Get restriction method from config
local function GetRestrictionMethod()
    if Config and Config.WeaponRestrictions and Config.WeaponRestrictions.method then
        return Config.WeaponRestrictions.method
    end
    return 'block_weapon' -- Default
end

-- Check if weapon restrictions are enabled
local function AreRestrictionsEnabled()
    if Config and Config.WeaponRestrictions then
        return Config.WeaponRestrictions.enabled ~= false
    end
    return true -- Enabled by default
end

-------------------------------------------------------------------------------
-- TWO-HANDED WEAPON DETECTION
-------------------------------------------------------------------------------

local TwoHandedWeaponGroups = {
    [GetHashKey('GROUP_RIFLE')] = true,
    [GetHashKey('GROUP_MG')] = true,
    [GetHashKey('GROUP_SHOTGUN')] = true,
    [GetHashKey('GROUP_SNIPER')] = true,
    [GetHashKey('GROUP_HEAVY')] = true,
    [GetHashKey('GROUP_SMG')] = true,
}

local OneHandedExceptions = {
    [GetHashKey('WEAPON_MINISMG')] = true,
    [GetHashKey('WEAPON_MICROSMG')] = true,
    [GetHashKey('WEAPON_MACHINEPISTOL')] = true,
}

function IsTwoHandedWeapon(weaponHash)
    if not weaponHash or weaponHash == 0 then return false end
    if OneHandedExceptions[weaponHash] then return false end
    
    local weaponGroup = GetWeapontypeGroup(weaponHash)
    return TwoHandedWeaponGroups[weaponGroup] == true
end

function IsWeaponAllowed(weaponHash)
    if AllWeaponsBlocked then return false end
    if not WeaponsRestricted then return true end
    return not IsTwoHandedWeapon(weaponHash)
end

-------------------------------------------------------------------------------
-- RESTRICTION STATE
-------------------------------------------------------------------------------

WeaponsRestricted = false      -- Two-handed weapons blocked (handbag)
AllWeaponsBlocked = false      -- ALL weapons blocked (two-hand carry)
local CurrentRestrictedSlot = nil
local CurrentRestrictedItem = nil
local LastNotifyTime = 0
local WeaponBlockLoopActive = false

-------------------------------------------------------------------------------
-- WEAPON CONTROL BLOCKING (block_weapon method)
-- Runs ONLY when restrictions are active - stops when bag removed
-------------------------------------------------------------------------------

local function StartWeaponBlockLoop()
    if WeaponBlockLoopActive then return end
    WeaponBlockLoopActive = true
    
    DebugPrint('Starting weapon block loop')
    
    CreateThread(function()
        while WeaponBlockLoopActive and (WeaponsRestricted or AllWeaponsBlocked) do
            -- Block weapon wheel
            DisableControlAction(0, 37, true)  -- INPUT_SELECT_WEAPON (TAB)
            
            -- Block all weapon selection keys
            DisableControlAction(0, 157, true) -- INPUT_SELECT_WEAPON_UNARMED
            DisableControlAction(0, 158, true) -- INPUT_SELECT_WEAPON_MELEE
            DisableControlAction(0, 159, true) -- INPUT_SELECT_WEAPON_HANDGUN
            DisableControlAction(0, 160, true) -- INPUT_SELECT_WEAPON_SHOTGUN
            DisableControlAction(0, 161, true) -- INPUT_SELECT_WEAPON_SMG
            DisableControlAction(0, 162, true) -- INPUT_SELECT_WEAPON_AUTO_RIFLE
            DisableControlAction(0, 163, true) -- INPUT_SELECT_WEAPON_SNIPER
            DisableControlAction(0, 164, true) -- INPUT_SELECT_WEAPON_HEAVY
            DisableControlAction(0, 165, true) -- INPUT_SELECT_WEAPON_SPECIAL
            
            -- Block mouse wheel weapon switch
            DisableControlAction(0, 14, true)  -- INPUT_WEAPON_WHEEL_NEXT
            DisableControlAction(0, 15, true)  -- INPUT_WEAPON_WHEEL_PREV
            DisableControlAction(0, 16, true)  -- INPUT_SELECT_NEXT_WEAPON
            DisableControlAction(0, 17, true)  -- INPUT_SELECT_PREV_WEAPON
            
            -- If two-hand carry, also block melee/unarmed combat
            if AllWeaponsBlocked then
                DisableControlAction(0, 24, true)  -- INPUT_ATTACK
                DisableControlAction(0, 25, true)  -- INPUT_AIM
                DisableControlAction(0, 140, true) -- INPUT_MELEE_ATTACK_LIGHT
                DisableControlAction(0, 141, true) -- INPUT_MELEE_ATTACK_HEAVY
                DisableControlAction(0, 263, true) -- INPUT_MELEE_ATTACK_ALTERNATE
            end
            
            Wait(0)
        end
        
        WeaponBlockLoopActive = false
        DebugPrint('Weapon block loop stopped')
    end)
end

local function StopWeaponBlockLoop()
    WeaponBlockLoopActive = false
end

-------------------------------------------------------------------------------
-- DROP TO GROUND (drop_to_ground method)
-- Removes bag from inventory and creates ground pickup
-------------------------------------------------------------------------------

local function DropBagToGround()
    if not CurrentRestrictedSlot or not CurrentRestrictedItem then return end
    
    DebugPrint('Dropping bag to ground:', CurrentRestrictedItem, 'from slot:', CurrentRestrictedSlot)
    
    local now = GetGameTimer()
    if now - LastNotifyTime > 2000 then
        LastNotifyTime = now
        Notify({
            title = 'Bag Dropped',
            description = 'You dropped your bag to draw your weapon',
            type = 'warning',
            duration = 3000
        })
    end
    
    -- Tell server to drop the bag
    TriggerServerEvent('free_hoarder:dropBagToGround', CurrentRestrictedSlot, CurrentRestrictedItem)
end

-------------------------------------------------------------------------------
-- EVENT-DRIVEN WEAPON MONITORING (for drop_to_ground method only)
-------------------------------------------------------------------------------

lib.onCache('weapon', function(newWeapon, oldWeapon)
    -- Only applies to drop_to_ground method
    if GetRestrictionMethod() ~= 'drop_to_ground' then return end
    if not AreRestrictionsEnabled() then return end
    
    local unarmedHash = GetHashKey('WEAPON_UNARMED')
    if not newWeapon or newWeapon == unarmedHash then return end
    
    -- Two-hand carry: any weapon triggers drop
    if AllWeaponsBlocked then
        DropBagToGround()
        return
    end
    
    -- Handbag: two-handed weapons trigger drop
    if WeaponsRestricted and IsTwoHandedWeapon(newWeapon) then
        DropBagToGround()
    end
end)

-------------------------------------------------------------------------------
-- RESTRICTION STATE MANAGEMENT
-------------------------------------------------------------------------------

function UpdateWeaponRestrictions()
    local handbagRestricted = false
    local twoHandBlocked = false
    local restrictedSlot = nil
    local restrictedItem = nil
    
    for slotName, bagData in pairs(LocalEquippedBags or {}) do
        if bagData and bagData.config then
            local bagType = bagData.config.type
            
            -- Two-hand carry blocks ALL weapons
            if bagType == 'twohand' and slotName == 'TWO_HAND' then
                twoHandBlocked = true
                restrictedSlot = slotName
                restrictedItem = bagData.bagName
                DebugPrint('Two-hand carry detected - blocking ALL weapons')
            -- Handbag blocks two-handed weapons
            elseif bagType == 'handbag' and (slotName == 'LEFT_HAND' or slotName == 'RIGHT_HAND') then
                handbagRestricted = true
                restrictedSlot = slotName
                restrictedItem = bagData.bagName
            end
        end
    end
    
    local wasRestricted = WeaponsRestricted or AllWeaponsBlocked
    local nowRestricted = handbagRestricted or twoHandBlocked
    
    WeaponsRestricted = handbagRestricted
    AllWeaponsBlocked = twoHandBlocked
    CurrentRestrictedSlot = restrictedSlot
    CurrentRestrictedItem = restrictedItem
    
    DebugPrint('Weapon restrictions:', 'handbag=' .. tostring(handbagRestricted), 'twohand=' .. tostring(twoHandBlocked))
    
    -- Handle control blocking based on method
    local method = GetRestrictionMethod()
    if method == 'block_weapon' then
        if nowRestricted and not wasRestricted then
            -- Just became restricted - start blocking
            StartWeaponBlockLoop()
            
            -- Force to unarmed if currently holding weapon
            local currentWeapon = GetSelectedPedWeapon(PlayerPedId())
            local unarmedHash = GetHashKey('WEAPON_UNARMED')
            
            if currentWeapon ~= unarmedHash then
                local shouldForce = AllWeaponsBlocked or (WeaponsRestricted and IsTwoHandedWeapon(currentWeapon))
                if shouldForce then
                    SetCurrentPedWeapon(PlayerPedId(), unarmedHash, true)
                    Notify({
                        title = 'Weapon Holstered',
                        description = AllWeaponsBlocked and 'Cannot use weapons while carrying' or 'Cannot use two-handed weapons with this bag',
                        type = 'warning',
                        duration = 3000
                    })
                end
            end
        elseif not nowRestricted and wasRestricted then
            -- Restrictions lifted - stop blocking
            StopWeaponBlockLoop()
        end
    elseif method == 'drop_to_ground' then
        -- For drop_to_ground, check if we need to drop immediately
        if nowRestricted and not wasRestricted then
            local currentWeapon = GetSelectedPedWeapon(PlayerPedId())
            local unarmedHash = GetHashKey('WEAPON_UNARMED')
            
            if currentWeapon ~= unarmedHash then
                local shouldDrop = AllWeaponsBlocked or (WeaponsRestricted and IsTwoHandedWeapon(currentWeapon))
                if shouldDrop then
                    SetTimeout(100, function()
                        if AllWeaponsBlocked or WeaponsRestricted then
                            DropBagToGround()
                        end
                    end)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- LONG GUN STORAGE (for bag containers only)
-------------------------------------------------------------------------------

-- Long gun weapon hashes (for reference - used by container validation)
local LongGunWeapons = {
    -- Rifles
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
    
    -- Shotguns
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
    
    -- Snipers
    [`WEAPON_SNIPERRIFLE`] = true,
    [`WEAPON_HEAVYSNIPER`] = true,
    [`WEAPON_HEAVYSNIPER_MK2`] = true,
    [`WEAPON_MARKSMANRIFLE`] = true,
    [`WEAPON_MARKSMANRIFLE_MK2`] = true,
    [`WEAPON_PRECISIONRIFLE`] = true,
    
    -- MGs
    [`WEAPON_MG`] = true,
    [`WEAPON_COMBATMG`] = true,
    [`WEAPON_COMBATMG_MK2`] = true,
    [`WEAPON_GUSENBERG`] = true,
    
    -- Heavy
    [`WEAPON_RPG`] = true,
    [`WEAPON_GRENADELAUNCHER`] = true,
    [`WEAPON_GRENADELAUNCHER_SMOKE`] = true,
    [`WEAPON_MINIGUN`] = true,
    [`WEAPON_FIREWORK`] = true,
    [`WEAPON_RAILGUN`] = true,
    [`WEAPON_HOMINGLAUNCHER`] = true,
    [`WEAPON_COMPACTLAUNCHER`] = true,
    [`WEAPON_RAYMINIGUN`] = true,
    [`WEAPON_EMPLAUNCHER`] = true,
}

-- Note: IsLongGun function is defined in shared/utils.lua
-- Long gun usage is NOT restricted based on bags
-- The allowsLongGuns property only affects what can be stored in bag containers
-- Players can always USE any weapon they have in their inventory

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------

exports('IsTwoHandedWeapon', IsTwoHandedWeapon)
exports('AreAllWeaponsBlocked', function() return AllWeaponsBlocked end)

-------------------------------------------------------------------------------
-- VEHICLE ENTRY AUTO-DROP
-- Drop two-hand items when entering vehicles
-------------------------------------------------------------------------------

lib.onCache('vehicle', function(vehicle, oldVehicle)
    -- Only care when entering a vehicle (vehicle becomes non-nil)
    if not vehicle then return end
    
    -- Check if config allows this
    if not Config or not Config.VehicleEntry or not Config.VehicleEntry.enabled then return end
    if not Config.VehicleEntry.dropTwoHandOnEntry then return end
    
    -- Check if carrying two-hand item
    if not AllWeaponsBlocked then return end
    if not CurrentRestrictedSlot or CurrentRestrictedSlot ~= 'TWO_HAND' then return end
    
    DebugPrint('Entering vehicle with two-hand item - dropping')
    
    -- Drop the item
    TriggerServerEvent('free_hoarder:dropBagToGround', CurrentRestrictedSlot, CurrentRestrictedItem)
    
    -- Notify player
    if Config.VehicleEntry.notifyOnDrop then
        Notify({
            title = 'Item Dropped',
            description = Config.VehicleEntry.notifyMessage or 'You put down what you were carrying',
            type = 'info',
            duration = 3000
        })
    end
end)
