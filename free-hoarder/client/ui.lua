--[[
    Client UI - free-hoarder
    Modern ox_lib context menus with slot swapping functionality
]]

-------------------------------------------------------------------------------
-- KEYBIND REGISTRATION
-------------------------------------------------------------------------------

lib.addKeybind({
    name = 'hoarder_open_menu',
    description = 'Open Bag Menu',
    defaultKey = 'G',
    onPressed = function()
        if PlayerLoaded and not IsPlayingBagAnimation() then
            OpenBagManagementMenu()
        end
    end
})

-------------------------------------------------------------------------------
-- MAIN BAG MANAGEMENT MENU
-------------------------------------------------------------------------------

function OpenBagManagementMenu()
    local options = {}
    local hasBags = false
    
    -- Build options for each equipped bag
    for slotName, data in pairs(LocalEquippedBags) do
        hasBags = true
        local label = data.config and data.config.label or data.bagName
        local slotLabel = FormatSlotLabel(slotName)
        local bagType = data.config and data.config.type or 'backpack'
        
        -- Get alternate slots for this bag
        local alternateSlots = GetAlternateSlots(slotName, data.config)
        
        -- Check if bag can store outfits
        local canStoreOutfits = Config.OutfitSaving 
            and Config.OutfitSaving.enabled 
            and Config.OutfitSaving.allowedBagTypes 
            and Config.OutfitSaving.allowedBagTypes[bagType]
        
        -- Build bag submenu
        local bagMenuOptions = {}
        
        -- Outfit management option
        if canStoreOutfits then
            table.insert(bagMenuOptions, {
                title = 'Manage Outfits',
                description = 'Save and load outfits from this bag',
                icon = 'shirt',
                onSelect = function()
                    local success, err = pcall(function()
                        exports['free-hoarder']:OpenOutfitMenu(slotName)
                    end)
                    if not success then
                        Notify({ title = 'Error', description = 'Could not open outfit menu', type = 'error' })
                    end
                end
            })
        end
        
        -- Slot change options
        if #alternateSlots > 0 then
            for _, newSlot in ipairs(alternateSlots) do
                local newSlotLabel = FormatSlotLabel(newSlot)
                table.insert(bagMenuOptions, {
                    title = 'Move to ' .. newSlotLabel,
                    description = 'Change bag position',
                    icon = GetSlotIcon(newSlot),
                    onSelect = function()
                        SwapBagSlot(slotName, newSlot, data.bagName)
                    end
                })
            end
        end
        
        -- Open bag container option
        if data.containerId then
            table.insert(bagMenuOptions, {
                title = 'Open Bag',
                description = 'Access bag contents',
                icon = 'box-open',
                onSelect = function()
                    -- v2.0: Check if bag is locked before opening
                    if CheckBagLockBeforeOpen and not CheckBagLockBeforeOpen(slotName, data) then
                        return  -- Lock menu was shown instead
                    end
                    
                    -- v2.0: Check durability before opening (and notify server for degradation)
                    if CheckDurabilityBeforeOpen then
                        CheckDurabilityBeforeOpen(slotName, data)
                    end
                    
                    -- v2.0: Play opening animation before opening stash
                    if OpenBagWithAnimation and Config.OpenAnimations and Config.OpenAnimations.enabled then
                        OpenBagWithAnimation(slotName, data, function(success, reason)
                            if success then
                                TriggerServerEvent('free_hoarder:openBagContainer', slotName)
                            elseif reason then
                                -- Animation was cancelled
                                print('[free-hoarder] Bag open cancelled:', reason)
                            end
                        end)
                    else
                        TriggerServerEvent('free_hoarder:openBagContainer', slotName)
                    end
                end
            })
        end
        
        -- v2.0: Lock options
        local bagConfig = data.config or {}
        if bagConfig.lockable and Config.Locking and Config.Locking.enabled then
            local lockIcon = 'lock-open'
            local lockDesc = 'Add or manage bag lock'
            
            if data.lock and data.lock.isLocked then
                lockIcon = 'lock'
                lockDesc = 'Bag is locked - ' .. (GetLockTypeName and GetLockTypeName(data.lock.type) or data.lock.type)
            elseif data.lock then
                lockDesc = 'Bag has a lock (unlocked)'
            end
            
            table.insert(bagMenuOptions, {
                title = 'Lock Options',
                description = lockDesc,
                icon = lockIcon,
                onSelect = function()
                    if OpenLockMenu then
                        OpenLockMenu(slotName, data)
                    else
                        Notify({ title = 'Error', description = 'Lock system not available', type = 'error' })
                    end
                end
            })
        end
        
        -- v2.0: Durability option
        if bagConfig.durability and bagConfig.durability.enabled and Config.Durability and Config.Durability.enabled then
            local durabilityOption = GetDurabilityMenuOption and GetDurabilityMenuOption(slotName, data)
            if durabilityOption then
                table.insert(bagMenuOptions, durabilityOption)
            end
        end
        
        -- Throw bag option
        local throwingEnabled = Config.Throwing and Config.Throwing.enabled
        local canThrowType = true  -- Default to allowing throw
        
        -- Check if this bag type is explicitly disabled for throwing
        if throwingEnabled and Config.Throwing.throwableBagTypes then
            local throwable = Config.Throwing.throwableBagTypes[bagType]
            if throwable == false then
                canThrowType = false
            end
        end
        
        if throwingEnabled and canThrowType then
            table.insert(bagMenuOptions, {
                title = 'Throw Bag',
                description = 'Aim and throw your bag',
                icon = 'hand',
                onSelect = function()
                    if StartThrowAim then
                        StartThrowAim(slotName, data.bagName)
                    else
                        Notify({ title = 'Error', description = 'Throwing not available', type = 'error' })
                    end
                end
            })
        end
        
        -- Drop bag option
        table.insert(bagMenuOptions, {
            title = 'Drop Bag',
            description = 'Drop bag at your feet',
            icon = 'arrow-down',
            onSelect = function()
                TriggerServerEvent('free_hoarder:dropBagToGround', slotName, data.bagName)
                Notify({
                    title = 'Bag Dropped',
                    description = 'You dropped your ' .. (data.config and data.config.label or 'bag'),
                    type = 'info',
                    duration = 2000
                })
            end
        })
        
        -- Add main bag entry
        if #bagMenuOptions > 0 then
            -- Create submenu for this bag
            lib.registerContext({
                id = 'hoarder_bag_' .. slotName,
                title = label .. ' - ' .. slotLabel,
                menu = 'hoarder_main_menu',
                options = bagMenuOptions
            })
            
            table.insert(options, {
                title = label,
                description = 'Currently: ' .. slotLabel,
                icon = GetSlotIcon(slotName),
                menu = 'hoarder_bag_' .. slotName,
                arrow = true
            })
        else
            -- No options available for this bag
            table.insert(options, {
                title = label,
                description = 'Equipped: ' .. slotLabel,
                icon = GetSlotIcon(slotName),
                disabled = true
            })
        end
    end
    
    -- Status option
    table.insert(options, {
        title = 'View Status',
        description = 'Show bag and capacity information',
        icon = 'circle-info',
        onSelect = function()
            ShowBagStatus()
        end
    })
    
    -- No bags message
    if not hasBags then
        table.insert(options, 1, {
            title = 'No Bags Equipped',
            description = 'Bags auto-equip when added to inventory',
            icon = 'box-open',
            readOnly = true
        })
    end
    
    lib.registerContext({
        id = 'hoarder_main_menu',
        title = '🎒 Bag Management',
        options = options
    })
    
    lib.showContext('hoarder_main_menu')
end

-------------------------------------------------------------------------------
-- SLOT SWAP SUBMENU
-------------------------------------------------------------------------------

function RegisterSwapMenu(currentSlot, bagData, alternateSlots)
    local options = {}
    local bagLabel = bagData.config and bagData.config.label or bagData.bagName
    
    for _, newSlot in ipairs(alternateSlots) do
        local newSlotLabel = FormatSlotLabel(newSlot)
        
        table.insert(options, {
            title = 'Move to ' .. newSlotLabel,
            description = 'Swap bag position',
            icon = GetSlotIcon(newSlot),
            onSelect = function()
                SwapBagSlot(currentSlot, newSlot, bagData.bagName)
            end
        })
    end
    
    lib.registerContext({
        id = 'hoarder_swap_' .. currentSlot,
        title = bagLabel .. ' - Change Position',
        menu = 'hoarder_main_menu',
        options = options
    })
end

-------------------------------------------------------------------------------
-- SLOT SWAP LOGIC
-------------------------------------------------------------------------------

function SwapBagSlot(fromSlot, toSlot, bagName)
    -- Request server to swap the bag
    local result = lib.callback.await('free_hoarder:swapBagSlot', false, fromSlot, toSlot, bagName)
    
    if result and result.success then
        Notify({
            title = 'Bag Moved',
            description = FormatSlotLabel(fromSlot) .. ' → ' .. FormatSlotLabel(toSlot),
            type = 'success',
            duration = 2000
        })
    else
        Notify({
            title = 'Cannot Move Bag',
            description = result and result.error or 'Unknown error',
            type = 'error'
        })
    end
end

function GetAlternateSlots(currentSlot, bagConfig)
    local alternates = {}
    
    if not bagConfig or not bagConfig.allowedSlots then
        return alternates
    end
    
    for _, slot in ipairs(bagConfig.allowedSlots) do
        -- Not the current slot and not occupied by another bag
        if slot ~= currentSlot and not LocalEquippedBags[slot] then
            table.insert(alternates, slot)
        end
    end
    
    return alternates
end

-------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-- FormatSlotLabel and GetSlotIcon are defined in shared/utils.lua
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- STATUS DISPLAY
-------------------------------------------------------------------------------

function ShowBagStatus()
    local equippedCount = 0
    local totalCapacity = { weight = 0, slots = 0 }
    local lines = {}
    
    -- Weight info
    local currentWeight = exports.ox_inventory:GetPlayerWeight() or 0
    local maxWeight = exports.ox_inventory:GetPlayerMaxWeight() or (Config.BaseWeight or 26500)
    
    table.insert(lines, ('**Weight:** %s / %s'):format(
        FormatWeight(currentWeight),
        FormatWeight(maxWeight)
    ))
    
    -- Equipped bags
    if next(LocalEquippedBags) then
        table.insert(lines, '')
        table.insert(lines, '**Equipped Bags:**')
        
        for slotName, data in pairs(LocalEquippedBags) do
            equippedCount = equippedCount + 1
            local label = data.config and data.config.label or data.bagName
            local slotLabel = FormatSlotLabel(slotName)
            table.insert(lines, ('• %s (%s)'):format(label, slotLabel))
            
            if data.config and data.config.capacity then
                totalCapacity.weight = totalCapacity.weight + data.config.capacity.weight
                totalCapacity.slots = totalCapacity.slots + data.config.capacity.slots
            end
        end
        
        table.insert(lines, '')
        table.insert(lines, ('**Bonus Capacity:** +%s'):format(FormatWeight(totalCapacity.weight)))
    else
        table.insert(lines, '')
        table.insert(lines, '*No bags equipped*')
    end
    
    -- Weapon restrictions
    if WeaponsRestricted then
        table.insert(lines, '')
        table.insert(lines, '⚠️ **Two-Handed Weapons Restricted**')
    end
    
    lib.alertDialog({
        header = 'Bag Status',
        content = table.concat(lines, '\n'),
        centered = true,
        size = 'sm'
    })
end

-- FormatWeight is defined in shared/utils.lua

-------------------------------------------------------------------------------
-- BAG USE MENU (Right-click bag in inventory)
-------------------------------------------------------------------------------

RegisterNetEvent('free_hoarder:showBagUseMenu', function(data)
    local options = {}
    
    -- Open Bag option (always available)
    table.insert(options, {
        title = 'Open Bag',
        description = 'Access bag contents',
        icon = 'box-open',
        onSelect = function()
            TriggerServerEvent('free_hoarder:openBagContainer', data.slotName, data.containerId)
        end
    })
    
    -- Manage Outfits option (if supported)
    if data.canStoreOutfits then
        table.insert(options, {
            title = 'Manage Outfits',
            description = 'Save and load outfits from this bag',
            icon = 'shirt',
            onSelect = function()
                local success, err = pcall(function()
                    exports['free-hoarder']:OpenOutfitMenu(data.slotName)
                end)
                if not success then
                    Notify({ title = 'Error', description = 'Could not open outfit menu', type = 'error' })
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'hoarder_bag_use_menu',
        title = data.bagLabel or 'Bag Options',
        options = options
    })
    
    lib.showContext('hoarder_bag_use_menu')
end)

-------------------------------------------------------------------------------
-- QUICK DROP SYSTEM
-------------------------------------------------------------------------------

local QuickDropEnabled = false
local LastDropTime = 0
local DropCooldown = 200
local IsHolding = false

---Drop the first occupied inventory slot
---@return boolean success
local function DropFirstItem()
    local now = GetGameTimer()
    if now - LastDropTime < DropCooldown then
        return false
    end
    
    local dropped = lib.callback.await('free_hoarder:dropFirstInventorySlot', false)
    
    if dropped then
        LastDropTime = now
        if PlayDropSound then
            PlayDropSound('generic')
        end
        return true
    end
    
    return false
end

---Handle keybind press
function OnQuickDropPressed()
    if not QuickDropEnabled then return end
    
    IsHolding = true
    local dropped = DropFirstItem()
    
    if not dropped then
        NotifyInfo('Your inventory is empty')
        return
    end
    
    CreateThread(function()
        while IsHolding do
            Wait(DropCooldown)
            if IsHolding then
                local success = DropFirstItem()
                if not success then
                    IsHolding = false
                    NotifyInfo('All items dropped')
                end
            end
        end
    end)
end

---Handle keybind release
function OnQuickDropReleased()
    IsHolding = false
end

-- Initialize quick drop
CreateThread(function()
    Wait(1000)
    
    if not Config or not Config.QuickDrop or not Config.QuickDrop.enabled then
        return
    end
    
    QuickDropEnabled = true
    DropCooldown = Config.QuickDrop.cooldown or 200
    
    lib.addKeybind({
        name = 'hoarder_quickdrop',
        description = Config.QuickDrop.description or 'Quick Drop Item',
        defaultKey = Config.QuickDrop.key or 'Y',
        onPressed = OnQuickDropPressed,
        onReleased = OnQuickDropReleased
    })
    
    print('[free-hoarder] Quick drop keybind registered:', Config.QuickDrop.key or 'Y')
end)

exports('QuickDrop', DropFirstItem)

-------------------------------------------------------------------------------
-- THROWING SYSTEM
-------------------------------------------------------------------------------

local IsAiming = false
local ThrowMarker = nil
local CurrentThrowSlot = nil
local CurrentThrowBag = nil
local ThrowDistance = 5.0

---Get throw target position based on player aim
---@return vector3|nil targetPos
---@return number distance
local function GetThrowTarget()
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local camRot = GetGameplayCamRot(2)
    
    local radX = math.rad(camRot.x)
    local radZ = math.rad(camRot.z)
    
    local direction = vector3(
        -math.sin(radZ) * math.abs(math.cos(radX)),
        math.cos(radZ) * math.abs(math.cos(radX)),
        math.sin(radX)
    )
    
    local startPos = pedCoords + vector3(0.0, 0.0, 0.5)
    local endPos = startPos + (direction * ThrowDistance)
    
    local rayHandle = StartShapeTestRay(
        startPos.x, startPos.y, startPos.z,
        endPos.x, endPos.y, endPos.z,
        1 + 16 + 256, ped, 0
    )
    
    local retval, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
    
    if hit == 1 and hitCoords then
        local targetVec = vector3(hitCoords.x, hitCoords.y, hitCoords.z)
        local dist = #(startPos - targetVec)
        return targetVec, dist
    else
        local groundZ = endPos.z
        local found, z = GetGroundZFor_3dCoord(endPos.x, endPos.y, endPos.z + 10.0, false)
        if found then groundZ = z end
        return vector3(endPos.x, endPos.y, groundZ), ThrowDistance
    end
end

---Draw throw target marker
---@param targetPos vector3
local function DrawThrowMarker(targetPos)
    if not targetPos then return end
    
    local x, y, z
    if type(targetPos) == 'vector3' then
        x, y, z = targetPos.x, targetPos.y, targetPos.z
    elseif type(targetPos) == 'table' then
        x, y, z = targetPos.x or targetPos[1], targetPos.y or targetPos[2], targetPos.z or targetPos[3]
    else
        return
    end
    
    if not x or not y or not z then return end
    
    DrawMarker(1, x, y, z + 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.2, 100, 200, 100, 150, false, false, 2, false, nil, nil, false)
    
    local ped = PlayerPedId()
    local startCoords = GetEntityCoords(ped)
    local startX, startY, startZ = startCoords.x, startCoords.y, startCoords.z + 1.0
    local midX, midY, midZ = (startX + x) / 2, (startY + y) / 2, ((startZ + z) / 2) + 1.5
    
    for i = 0, 10 do
        local t = i / 10
        local t2 = t * t
        local mt = 1 - t
        local mt2 = mt * mt
        
        local posX = mt2 * startX + 2 * mt * t * midX + t2 * x
        local posY = mt2 * startY + 2 * mt * t * midY + t2 * y
        local posZ = mt2 * startZ + 2 * mt * t * midZ + t2 * z
        
        DrawMarker(28, posX, posY, posZ, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.05, 0.05, 200, 200, 200, 200, false, false, 2, false, nil, nil, false)
    end
end

---Execute the throw
---@param slotName string
---@param bagName string
---@param targetPos vector3|table
local function ExecuteThrow(slotName, bagName, targetPos)
    if not targetPos then return end
    
    local ped = PlayerPedId()
    local throwCoords
    
    if type(targetPos) == 'vector3' then
        throwCoords = targetPos
    else
        throwCoords = vector3(targetPos.x or targetPos[1] or 0, targetPos.y or targetPos[2] or 0, targetPos.z or targetPos[3] or 0)
    end
    
    lib.requestAnimDict('anim@heists@ornate_bank@grab_cash')
    TaskPlayAnim(ped, 'anim@heists@ornate_bank@grab_cash', 'throw', 8.0, -8.0, 500, 0, 0, false, false, false)
    
    if PlayThrowSound then PlayThrowSound() end
    
    TriggerServerEvent('free_hoarder:throwBagToGround', slotName, bagName, throwCoords)
    Notify({ title = 'Bag Thrown', description = 'You threw your bag', type = 'info', duration = 2000 })
end

---Start throw aiming mode
---@param slotName string
---@param bagName string
function StartThrowAim(slotName, bagName)
    if IsAiming then return end
    if not slotName or not bagName then return end
    
    IsAiming = true
    CurrentThrowSlot = slotName
    CurrentThrowBag = bagName
    
    Notify({ title = 'Throw Mode', description = 'Aim and click to throw, right-click to cancel', type = 'info', duration = 3000 })
    
    CreateThread(function()
        while IsAiming do
            local targetPos, distance = GetThrowTarget()
            
            if targetPos then
                DrawThrowMarker(targetPos)
                ThrowMarker = targetPos
            end
            
            if IsControlJustPressed(0, 24) then
                if ThrowMarker then
                    ExecuteThrow(CurrentThrowSlot, CurrentThrowBag, ThrowMarker)
                end
                CancelThrowAim()
            end
            
            if IsControlJustPressed(0, 25) or IsControlJustPressed(0, 200) then
                CancelThrowAim()
            end
            
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('~INPUT_ATTACK~ Throw | ~INPUT_AIM~ Cancel')
            EndTextCommandDisplayHelp(0, false, true, -1)
            
            Wait(0)
        end
    end)
end

---Cancel throw aiming mode
function CancelThrowAim()
    IsAiming = false
    ThrowMarker = nil
    CurrentThrowSlot = nil
    CurrentThrowBag = nil
end

---Check if in throw aiming mode
---@return boolean
function IsThrowAiming()
    return IsAiming
end

exports('StartThrowAim', StartThrowAim)
exports('CancelThrowAim', CancelThrowAim)
exports('IsThrowAiming', IsThrowAiming)
