--[[
    Client Durability - free-hoarder v2.0
    Client-side durability display, warnings, and repair UI
]]

-------------------------------------------------------------------------------
-- EVENT HANDLERS
-------------------------------------------------------------------------------

---Durability updated from server
RegisterNetEvent('free_hoarder:bagDurabilityUpdated', function(slotName, durability)
    if not LocalEquippedBags then return end
    if not LocalEquippedBags[slotName] then return end
    
    LocalEquippedBags[slotName].durability = durability
    
    if DebugLog then
        DebugLog('Durability updated for slot', slotName, '-', durability .. '%')
    end
end)

---Durability warning from server
RegisterNetEvent('free_hoarder:durabilityWarning', function(slotName, durability, severity)
    -- Play warning sound based on severity
    if severity == 'breaking' then
        PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
    elseif severity == 'critical' then
        PlaySoundFrontend(-1, 'MEDAL_DOWN', 'HUD_MINI_GAME_SOUNDSET', true)
    else
        PlaySoundFrontend(-1, 'CLICK_BACK', 'WEB_NAVIGATION_SOUNDS_PHONE', true)
    end
end)

---Bag broken event
RegisterNetEvent('free_hoarder:bagBroken', function(slotName, bagName)
    -- Play breaking sound
    PlaySoundFrontend(-1, 'WEAPON_SNIPER_RIFLE_DISTANT', 'HUD_FRONTEND_WEAPONS_SOUNDSET', true)
    
    -- Screen effect
    StartScreenEffect('DeathFailOut', 500, false)
    
    -- Remove from local tracking (server will handle the rest)
    if LocalEquippedBags and LocalEquippedBags[slotName] then
        LocalEquippedBags[slotName] = nil
    end
end)

-------------------------------------------------------------------------------
-- DURABILITY UI
-------------------------------------------------------------------------------

---Get durability color based on percentage
---@param durability number
---@return string color Hex color
local function GetDurabilityColor(durability)
    if durability > 50 then
        return '#4CAF50'  -- Green
    elseif durability > 25 then
        return '#FF9800'  -- Orange
    elseif durability > 10 then
        return '#FF5722'  -- Deep Orange
    else
        return '#F44336'  -- Red
    end
end

---Get durability bar icon based on percentage
---@param durability number
---@return string icon
local function GetDurabilityIcon(durability)
    if durability > 75 then
        return 'shield'
    elseif durability > 50 then
        return 'shield-halved'
    elseif durability > 25 then
        return 'triangle-exclamation'
    else
        return 'heart-crack'
    end
end

---Open repair menu for a bag
---@param slotName string
---@param bagData table
function OpenRepairMenu(slotName, bagData)
    -- Get durability info from server
    local info, error = lib.callback.await('free_hoarder:getBagDurability', false, slotName)
    
    if not info then
        NotifyError(error or 'Could not get durability info')
        return
    end
    
    local options = {}
    
    -- Durability display
    local durabilityColor = GetDurabilityColor(info.durability)
    local durabilityIcon = GetDurabilityIcon(info.durability)
    
    table.insert(options, {
        title = ('Durability: %d%%'):format(info.durability),
        description = info.durability >= 100 and 'Bag is in perfect condition' or 'Bag condition',
        icon = durabilityIcon,
        iconColor = durabilityColor,
        progress = info.durability,
        colorScheme = info.durability > 50 and 'green' or (info.durability > 25 and 'orange' or 'red'),
        disabled = true
    })
    
    -- Required materials section
    if info.repairItems and #info.repairItems > 0 then
        table.insert(options, {
            title = 'Required Materials',
            description = 'Items needed for repair',
            icon = 'toolbox',
            disabled = true
        })
        
        for _, item in ipairs(info.repairItems) do
            local hasEnough = false
            local playerHas = 0
            
            -- Check has/missing
            for _, has in ipairs(info.hasItems or {}) do
                if has.name == item.name then
                    hasEnough = true
                    playerHas = has.has
                    break
                end
            end
            
            if not hasEnough then
                for _, missing in ipairs(info.missingItems or {}) do
                    if missing.name == item.name then
                        playerHas = missing.has
                        break
                    end
                end
            end
            
            table.insert(options, {
                title = ('  %s'):format(item.name),
                description = ('%d / %d'):format(playerHas, item.count),
                icon = hasEnough and 'check' or 'xmark',
                iconColor = hasEnough and '#4CAF50' or '#F44336',
                disabled = true
            })
        end
    end
    
    -- Repair button
    if info.canRepair then
        table.insert(options, {
            title = 'Repair Bag',
            description = 'Use materials to repair',
            icon = 'wrench',
            onSelect = function()
                AttemptRepair(slotName, info.bagLabel)
            end
        })
    elseif info.durability >= 100 then
        table.insert(options, {
            title = 'No Repair Needed',
            description = 'Bag is already at full durability',
            icon = 'check-circle',
            iconColor = '#4CAF50',
            disabled = true
        })
    else
        table.insert(options, {
            title = 'Cannot Repair',
            description = 'Missing required materials',
            icon = 'ban',
            iconColor = '#F44336',
            disabled = true
        })
    end
    
    -- Back button
    table.insert(options, {
        title = 'Back',
        icon = 'arrow-left',
        onSelect = function()
            -- Return to bag menu
            if OpenBagManagementMenu then
                OpenBagManagementMenu()
            end
        end
    })
    
    lib.registerContext({
        id = 'hoarder_repair_menu',
        title = 'Bag Repair - ' .. info.bagLabel,
        options = options
    })
    
    lib.showContext('hoarder_repair_menu')
end

---Attempt to repair a bag
---@param slotName string
---@param bagLabel string
function AttemptRepair(slotName, bagLabel)
    -- Show progress bar
    if lib.progressBar({
        duration = Config.Durability and Config.Durability.repairTime or 5000,
        label = 'Repairing ' .. bagLabel .. '...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'clothingtie',
            clip = 'try_tie_positive_a'
        }
    }) then
        -- Completed - send to server
        local success, error = lib.callback.await('free_hoarder:repairBag', false, slotName)
        
        if success then
            NotifySuccess(bagLabel .. ' has been repaired')
            PlaySoundFrontend(-1, 'PICK_UP_WEAPON', 'HUD_FRONTEND_CUSTOM_SOUNDSET', true)
        else
            NotifyError(error or 'Repair failed')
        end
    else
        NotifyWarning('Repair cancelled')
    end
end

-------------------------------------------------------------------------------
-- HOOK INTO BAG OPENING
-------------------------------------------------------------------------------

---Check durability before opening bag and notify server
---@param slotName string
---@param bagData table
---@return boolean canOpen
function CheckDurabilityBeforeOpen(slotName, bagData)
    if not Config.Durability or not Config.Durability.enabled then
        return true
    end
    
    local bagConfig = bagData.config
    if not bagConfig then return true end
    
    -- Check if durability is enabled for this bag
    if not bagConfig.durability or not bagConfig.durability.enabled then
        return true
    end
    
    local durability = bagData.durability or 100
    
    -- Warn if very low
    if durability <= 5 then
        -- Show warning but still allow opening
        NotifyWarning('Your bag is about to break!')
    end
    
    -- Notify server that bag is being opened (for degradation)
    lib.callback.await('free_hoarder:onBagOpened', false, slotName)
    
    return true
end

-------------------------------------------------------------------------------
-- DURABILITY IN BAG MENU
-------------------------------------------------------------------------------

---Get durability menu option for a bag
---@param slotName string
---@param bagData table
---@return table|nil option Menu option or nil if durability disabled
function GetDurabilityMenuOption(slotName, bagData)
    local bagConfig = bagData.config
    if not bagConfig then return nil end
    
    -- Check if durability is enabled
    if not Config.Durability or not Config.Durability.enabled then
        return nil
    end
    
    if not bagConfig.durability or not bagConfig.durability.enabled then
        return nil
    end
    
    local durability = bagData.durability or 100
    local color = GetDurabilityColor(durability)
    local icon = GetDurabilityIcon(durability)
    
    return {
        title = ('Durability: %d%%'):format(durability),
        description = durability < 100 and 'View repair options' or 'Bag is in good condition',
        icon = icon,
        iconColor = color,
        progress = durability,
        colorScheme = durability > 50 and 'green' or (durability > 25 and 'orange' or 'red'),
        onSelect = function()
            OpenRepairMenu(slotName, bagData)
        end
    }
end

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------

exports('OpenRepairMenu', OpenRepairMenu)
exports('GetDurabilityMenuOption', GetDurabilityMenuOption)
exports('CheckDurabilityBeforeOpen', CheckDurabilityBeforeOpen)
