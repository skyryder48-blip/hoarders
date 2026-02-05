--[[
    Client Main - free-hoarder
    Handles client initialization, state management, and core event handlers
]]

-- Local state tracking
---@type table<string, table> Client-side tracking of equipped bags
LocalEquippedBags = {}

-- Current capacity (synced from server)
---@type number
CurrentMaxWeight = Config.BaseWeight

---@type number
CurrentMaxSlots = Config.BaseSlots

-- Weapon restriction state
---@type boolean
WeaponsRestricted = false

-- Player loaded state
---@type boolean
PlayerLoaded = false

-------------------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------------------

CreateThread(function()
    -- Wait for player to be loaded
    while not LocalPlayer.state.isLoggedIn do
        Wait(100)
    end
    
    PlayerLoaded = true
    DebugPrint('Client initialized')
    
    -- Request equipped bags from server
    Wait(2000) -- Give server time to restore
    local equipped = lib.callback.await('free_hoarder:getEquippedBags')
    if equipped then
        for slotName, data in pairs(equipped) do
            LocalEquippedBags[slotName] = data
            if data.config then
                AttachBagProp(slotName, data.bagName, data.config)
                if data.config.restrictsWeapons and IsHandSlot(slotName) then
                    UpdateWeaponRestriction()
                end
            end
        end
    end
end)

-------------------------------------------------------------------------------
-- SERVER EVENT HANDLERS
-------------------------------------------------------------------------------

---Bag equipped event from server
RegisterNetEvent('free_hoarder:bagEquipped', function(slotName, bagName, bagConfig, lockData, durabilityData)
    DebugPrint(('Bag equipped: %s to %s'):format(bagName, slotName))
    
    -- Track locally
    LocalEquippedBags[slotName] = {
        bagName = bagName,
        config = bagConfig,
        lock = lockData or nil,              -- v2.0: Include lock data
        durability = durabilityData or 100   -- v2.0: Include durability data
    }
    
    -- Play animation if enabled
    if Config.Animations.enabled then
        PlayEquipAnimation(bagConfig.type, function()
            AttachBagProp(slotName, bagName, bagConfig)
        end)
    else
        AttachBagProp(slotName, bagName, bagConfig)
    end
    
    -- Update weapon restriction state
    if bagConfig.restrictsWeapons and IsHandSlot(slotName) then
        UpdateWeaponRestriction()
    end
    
    -- Notify player
    if Config.UI.notifications.enabled then
        Notify({
            title = 'Bag Equipped',
            description = bagConfig.label or bagName,
            type = 'success',
            position = Config.UI.notifications.position,
            duration = Config.UI.notifications.duration
        })
    end
end)

---Bag unequipped event from server
RegisterNetEvent('free_hoarder:bagUnequipped', function(slotName)
    DebugPrint(('Bag unequipped from: %s'):format(slotName))
    
    local bagData = LocalEquippedBags[slotName]
    
    -- Play animation if enabled
    if Config.Animations.enabled and bagData and bagData.config then
        PlayUnequipAnimation(bagData.config.type, function()
            RemoveBagProp(slotName)
        end)
    else
        RemoveBagProp(slotName)
    end
    
    -- Remove from local tracking
    LocalEquippedBags[slotName] = nil
    
    -- Update weapon restriction state
    UpdateWeaponRestriction()
    
    -- Notify player
    if Config.UI.notifications.enabled then
        Notify({
            title = 'Bag Removed',
            description = bagData and bagData.config and bagData.config.label or 'Bag',
            type = 'info',
            position = Config.UI.notifications.position,
            duration = Config.UI.notifications.duration
        })
    end
end)

---Restore visuals after reconnect/resource restart
RegisterNetEvent('free_hoarder:restoreVisuals', function(equippedBags)
    DebugPrint('Restoring bag visuals...')
    
    -- Clear any existing props first
    RemoveAllBagProps()
    LocalEquippedBags = {}
    
    -- Restore each bag
    for slotName, data in pairs(equippedBags) do
        local bagConfig = GetBagConfig(data.bagName)
        if bagConfig then
            LocalEquippedBags[slotName] = {
                bagName = data.bagName,
                config = bagConfig
            }
            AttachBagProp(slotName, data.bagName, bagConfig)
        end
    end
    
    -- Update weapon restrictions
    UpdateWeaponRestriction()
    
    DebugPrint(('Restored %d bag visuals'):format(#equippedBags or 0))
end)

---Capacity updated event from server
RegisterNetEvent('free_hoarder:capacityUpdated', function(maxWeight, maxSlots)
    CurrentMaxWeight = maxWeight
    CurrentMaxSlots = maxSlots
    DebugPrint(('Capacity updated: %s, %d slots'):format(FormatWeight(maxWeight), maxSlots))
end)

---Clear all bags (admin command)
RegisterNetEvent('free_hoarder:clearAllBags', function()
    DebugPrint('Admin: Clearing all bags')
    
    -- Remove all props
    RemoveAllBagProps()
    
    -- Clear local tracking
    LocalEquippedBags = {}
    
    -- Update weapon restrictions
    UpdateWeaponRestriction()
    
    Notify({
        title = 'Bags Cleared',
        description = 'All equipped bags have been removed by admin',
        type = 'info',
        duration = 3000
    })
end)

---Over capacity warning (from server)
RegisterNetEvent('free_hoarder:overCapacityWarning', function(excessWeight)
    Notify({
        title = 'Over Capacity!',
        description = ('You are %s over your carry limit'):format(FormatWeight(excessWeight)),
        type = 'error',
        position = Config.UI.notifications.position,
        duration = 5000
    })
    
    -- Set over-capacity state
    IsOverCapacity = true
    OverCapacityAmount = excessWeight
    DebugPrint('Over-capacity triggered from server:', excessWeight)
end)

-- Track over-capacity state (updated by state bags in statebags.lua)
IsOverCapacity = IsOverCapacity or false
OverCapacityAmount = OverCapacityAmount or 0
LastOverCapacityWarning = LastOverCapacityWarning or 0

-- NOTE: Over-capacity penalties are now handled reactively by statebags.lua
-- The hoarder:isOverCapacity state bag triggers StartOverCapacityPenalties()
-- This eliminates the need for constant polling

---Clear all props (resource restart)
RegisterNetEvent('free_hoarder:clearAllProps', function()
    RemoveAllBagProps()
    LocalEquippedBags = {}
    WeaponsRestricted = false
    DebugPrint('All props cleared')
end)

-------------------------------------------------------------------------------
-- EQUIP/UNEQUIP REQUEST HANDLERS
-------------------------------------------------------------------------------

---Server requests client to show equip menu
RegisterNetEvent('free_hoarder:requestEquip', function(itemSlot, bagName)
    local bagConfig = GetBagConfig(bagName)
    if not bagConfig then return end
    
    -- Get available slots from server
    local availableSlots = lib.callback.await('free_hoarder:getAvailableSlots', itemSlot)
    
    if not availableSlots or #availableSlots == 0 then
        Notify({
            title = 'Cannot Equip',
            description = 'No available attachment slots',
            type = 'error'
        })
        return
    end
    
    -- If only one slot available, equip directly
    if #availableSlots == 1 then
        local result = lib.callback.await('free_hoarder:equipBag', itemSlot, availableSlots[1].name)
        if not result.success then
            Notify({
                title = 'Error',
                description = result.error or 'Failed to equip bag',
                type = 'error'
            })
        end
        return
    end
    
    -- Multiple slots available - show radial menu
    ShowSlotSelectionMenu(itemSlot, bagName, bagConfig, availableSlots)
end)

---Server requests client to unequip
RegisterNetEvent('free_hoarder:requestUnequip', function(slotName)
    local result = lib.callback.await('free_hoarder:unequipBag', slotName)
    if not result.success then
        Notify({
            title = 'Error',
            description = result.error or 'Failed to unequip bag',
            type = 'error'
        })
    end
end)

-------------------------------------------------------------------------------
-- WEAPON RESTRICTION MANAGEMENT
-------------------------------------------------------------------------------

---Update weapon restriction state based on equipped handbags
---Delegates to UpdateWeaponRestrictions() in weapons.lua
function UpdateWeaponRestriction()
    if UpdateWeaponRestrictions then
        UpdateWeaponRestrictions()
    end
end

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------

---Check if weapons are currently restricted
---@return boolean
exports('IsWeaponRestricted', function()
    return WeaponsRestricted
end)

---Get all equipped bags (client-side)
---@return table<string, table>
    return LocalEquippedBags
end)

---Get total bonus capacity from equipped bags
---@return number weight
---@return number slots
exports('GetTotalBonusCapacity', function()
    local totalWeight = 0
    local totalSlots = 0
    
    for _, data in pairs(LocalEquippedBags) do
        if data.config and data.config.capacity then
            totalWeight = totalWeight + data.config.capacity.weight
            totalSlots = totalSlots + data.config.capacity.slots
        end
    end
    
    return totalWeight, totalSlots
end)

-------------------------------------------------------------------------------
-- DEBUG COMMANDS
-------------------------------------------------------------------------------

-- Check over-capacity status
RegisterCommand('hoarder_capacity', function()
    local currentWeight = 0
    local maxWeight = Config.BaseWeight or 26500
    
    pcall(function()
        currentWeight = exports.ox_inventory:GetPlayerWeight() or 0
        maxWeight = exports.ox_inventory:GetPlayerMaxWeight() or maxWeight
    end)
    
    print('=== Capacity Debug ===')
    print(('Current Weight: %.1fkg'):format(currentWeight / 1000))
    print(('Max Weight: %.1fkg'):format(maxWeight / 1000))
    print(('Over Capacity: %s'):format(tostring(IsOverCapacity)))
    if IsOverCapacity then
        print(('Excess: %.1fkg'):format(OverCapacityAmount / 1000))
    end
    print(('Penalty Method: %s'):format(Config.OverCapacity and Config.OverCapacity.method or 'none'))
    
    -- Show bag bonuses
    local bagBonus = 0
    for slotName, data in pairs(LocalEquippedBags) do
        if data.config and data.config.capacity then
            bagBonus = bagBonus + data.config.capacity.weight
            print(('  %s: +%.1fkg'):format(data.bagName, data.config.capacity.weight / 1000))
        end
    end
    print(('Total Bag Bonus: +%.1fkg'):format(bagBonus / 1000))
end, false)

-------------------------------------------------------------------------------
-- RESOURCE CLEANUP
-------------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RemoveAllBagProps()
    end
end)
