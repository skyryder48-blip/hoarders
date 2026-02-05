--[[
    Client Debug - free-hoarder v2.0
    In-game debug overlay and F8 console logging
    
    Features:
    - Toggle command: /hoarder_debug
    - Floating text overlay showing bag state
    - Detailed F8 console logging
    - Admin permission required (ace: free-hoarder.admin)
]]

local DebugEnabled = false
local DebugOverlayActive = false

-------------------------------------------------------------------------------
-- DEBUG OVERLAY RENDERING
-------------------------------------------------------------------------------

local function DrawDebugText(x, y, text)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(0.0, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow()
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

local function RenderDebugOverlay()
    if not DebugOverlayActive then return end
    
    local x, y = 0.01, 0.3
    local lineHeight = 0.025
    local line = 0
    
    -- Header
    DrawDebugText(x, y + (line * lineHeight), "~y~=== FREE-HOARDER DEBUG ===~s~")
    line = line + 1
    
    -- Equipped Bags
    DrawDebugText(x, y + (line * lineHeight), "~b~Equipped Bags:~s~")
    line = line + 1
    
    local bags = LocalEquippedBags or {}
    local bagCount = 0
    
    for slotName, bagData in pairs(bags) do
        bagCount = bagCount + 1
        local config = GetBagConfig and GetBagConfig(bagData.bagName) or {}
        local label = config.label or bagData.bagName
        local lockStatus = bagData.lock and bagData.lock.isLocked and " ~r~[LOCKED]~s~" or ""
        local durability = bagData.durability and (" ~o~[" .. bagData.durability .. "%]~s~") or ""
        
        DrawDebugText(x, y + (line * lineHeight), ("  %s: %s%s%s"):format(slotName, label, lockStatus, durability))
        line = line + 1
    end
    
    if bagCount == 0 then
        DrawDebugText(x, y + (line * lineHeight), "  ~c~(none)~s~")
        line = line + 1
    end
    
    -- Capacity
    line = line + 0.5
    DrawDebugText(x, y + (line * lineHeight), "~b~Capacity:~s~")
    line = line + 1
    
    local currentWeight = GetCurrentWeight and GetCurrentWeight() or 0
    local maxWeight = GetCurrentMaxWeight and GetCurrentMaxWeight() or 26500
    local percentage = maxWeight > 0 and (currentWeight / maxWeight * 100) or 0
    
    local baseWeight = Config and Config.BaseWeight or 26500
    local baseSlots = Config and Config.BaseSlots or 17
    local bonusWeight, bonusSlots = 0, 0
    if GetTotalBonusCapacity then
        bonusWeight, bonusSlots = GetTotalBonusCapacity()
    end
    
    local weightColor = percentage > 100 and "~r~" or (percentage > 80 and "~o~" or "~g~")
    
    DrawDebugText(x, y + (line * lineHeight), ("  Weight: %s%.1f~s~ / %.1f kg (%.0f%%)"):format(
        weightColor, currentWeight / 1000, maxWeight / 1000, percentage
    ))
    line = line + 1
    
    DrawDebugText(x, y + (line * lineHeight), ("  Bonus: +%.1f kg, +%d slots"):format(bonusWeight / 1000, bonusSlots))
    line = line + 1
    
    -- Weapon Restrictions
    line = line + 0.5
    DrawDebugText(x, y + (line * lineHeight), "~b~Weapon Restrictions:~s~")
    line = line + 1
    
    local restricted = false
    local restrictionReason = "None"
    
    for slotName, bagData in pairs(bags) do
        if IsTwoHandSlot and IsTwoHandSlot(slotName) then
            restricted = true
            restrictionReason = "Two-hand item (ALL weapons blocked)"
            break
        elseif IsHandSlot and IsHandSlot(slotName) then
            local config = GetBagConfig and GetBagConfig(bagData.bagName) or {}
            if config.restrictsWeapons then
                restricted = true
                restrictionReason = "Handbag (melee only)"
            end
        end
    end
    
    local restrictColor = restricted and "~r~" or "~g~"
    DrawDebugText(x, y + (line * lineHeight), ("  Status: %s%s~s~"):format(restrictColor, restricted and "RESTRICTED" or "NONE"))
    line = line + 1
    
    if restricted then
        DrawDebugText(x, y + (line * lineHeight), ("  Reason: %s"):format(restrictionReason))
        line = line + 1
    end
    
    -- Two-Hand Carry State
    line = line + 0.5
    local twoHandActive = IsTwoHandCarryActive and IsTwoHandCarryActive() or false
    local twoHandColor = twoHandActive and "~g~" or "~c~"
    DrawDebugText(x, y + (line * lineHeight), ("~b~Two-Hand Carry:~s~ %s%s~s~"):format(twoHandColor, twoHandActive and "ACTIVE" or "inactive"))
    line = line + 1
    
    -- Movement State (if available)
    if CurrentMovementState then
        DrawDebugText(x, y + (line * lineHeight), ("~b~Movement State:~s~ %s"):format(CurrentMovementState or "unknown"))
        line = line + 1
    end
    
    -- Clothing Conflicts
    line = line + 0.5
    DrawDebugText(x, y + (line * lineHeight), "~b~Clothing Conflicts:~s~")
    line = line + 1
    
    local hasConflict = false
    for slotName in pairs(bags) do
        if IsBagHiddenByClothing and IsBagHiddenByClothing(slotName) then
            hasConflict = true
            DrawDebugText(x, y + (line * lineHeight), ("  ~o~%s: Hidden by clothing~s~"):format(slotName))
            line = line + 1
        end
    end
    
    if not hasConflict then
        DrawDebugText(x, y + (line * lineHeight), "  ~c~(none)~s~")
        line = line + 1
    end
    
    -- Footer
    line = line + 0.5
    DrawDebugText(x, y + (line * lineHeight), "~c~/hoarder_debug to toggle~s~")
end

-------------------------------------------------------------------------------
-- DEBUG THREAD
-------------------------------------------------------------------------------

local function StartDebugOverlay()
    if DebugOverlayActive then return end
    DebugOverlayActive = true
    
    CreateThread(function()
        while DebugOverlayActive do
            RenderDebugOverlay()
            Wait(0)
        end
    end)
    
    DebugLog("Debug overlay started")
end

local function StopDebugOverlay()
    DebugOverlayActive = false
    DebugLog("Debug overlay stopped")
end

-------------------------------------------------------------------------------
-- F8 CONSOLE LOGGING
-------------------------------------------------------------------------------

---Log debug message to F8 console
---@param ... any Messages to log
function DebugLog(...)
    if not DebugEnabled then return end
    
    local args = {...}
    local msg = ""
    for i, v in ipairs(args) do
        msg = msg .. tostring(v) .. (i < #args and " " or "")
    end
    
    print(("[free-hoarder:DEBUG] %s"):format(msg))
end

---Log bag state to F8 console
function DebugLogBagState()
    if not DebugEnabled then return end
    
    DebugLog("=== BAG STATE ===")
    
    local bags = LocalEquippedBags or {}
    local count = 0
    
    for slotName, bagData in pairs(bags) do
        count = count + 1
        local config = GetBagConfig and GetBagConfig(bagData.bagName) or {}
        DebugLog(("  Slot: %s"):format(slotName))
        DebugLog(("    Bag: %s (%s)"):format(bagData.bagName, config.label or "Unknown"))
        DebugLog(("    Type: %s"):format(config.type or "unknown"))
        DebugLog(("    Container: %s"):format(bagData.containerId or "none"))
        if bagData.lock then
            DebugLog(("    Lock: %s (Locked: %s)"):format(bagData.lock.type or "none", tostring(bagData.lock.isLocked)))
        end
        if bagData.durability then
            DebugLog(("    Durability: %d%%"):format(bagData.durability))
        end
    end
    
    if count == 0 then
        DebugLog("  No bags equipped")
    end
    
    DebugLog("=== END BAG STATE ===")
end

---Log capacity state to F8 console
function DebugLogCapacity()
    if not DebugEnabled then return end
    
    local currentWeight = GetCurrentWeight and GetCurrentWeight() or 0
    local maxWeight = GetCurrentMaxWeight and GetCurrentMaxWeight() or 26500
    local bonusWeight, bonusSlots = 0, 0
    if GetTotalBonusCapacity then
        bonusWeight, bonusSlots = GetTotalBonusCapacity()
    end
    
    DebugLog("=== CAPACITY STATE ===")
    DebugLog(("  Current: %.2f kg"):format(currentWeight / 1000))
    DebugLog(("  Max: %.2f kg"):format(maxWeight / 1000))
    DebugLog(("  Bonus Weight: +%.2f kg"):format(bonusWeight / 1000))
    DebugLog(("  Bonus Slots: +%d"):format(bonusSlots))
    DebugLog(("  Percentage: %.1f%%"):format(maxWeight > 0 and (currentWeight / maxWeight * 100) or 0))
    DebugLog("=== END CAPACITY STATE ===")
end

-------------------------------------------------------------------------------
-- TOGGLE COMMAND
-------------------------------------------------------------------------------

RegisterCommand('hoarder_debug', function()
    -- Check for admin permission via callback
    lib.callback('free_hoarder:checkAdminPermission', false, function(hasPermission)
        if not hasPermission then
            NotifyError('You do not have permission to use debug mode')
            return
        end
        
        DebugEnabled = not DebugEnabled
        
        if DebugEnabled then
            StartDebugOverlay()
            NotifySuccess('Debug mode enabled')
            DebugLogBagState()
            DebugLogCapacity()
        else
            StopDebugOverlay()
            NotifyInfo('Debug mode disabled')
        end
    end)
end, false)

-- Also allow toggle via export
local function ToggleDebug(enable)
    if enable == nil then
        DebugEnabled = not DebugEnabled
    else
        DebugEnabled = enable
    end
    
    if DebugEnabled then
        StartDebugOverlay()
    else
        StopDebugOverlay()
    end
    
    return DebugEnabled
end
exports('ToggleDebug', ToggleDebug)

-------------------------------------------------------------------------------
-- EVENT LOGGING (when debug enabled)
-------------------------------------------------------------------------------

-- Log bag equipped events
RegisterNetEvent('free_hoarder:client:onBagEquipped', function(data)
    DebugLog("EVENT: Bag equipped -", data.bagName, "in slot", data.slotName)
end)

-- Log bag unequipped events
RegisterNetEvent('free_hoarder:client:onBagUnequipped', function(data)
    DebugLog("EVENT: Bag unequipped -", data.bagName, "from slot", data.slotName)
end)

-- Log capacity changes
RegisterNetEvent('free_hoarder:client:onCapacityChanged', function(data)
    DebugLog("EVENT: Capacity changed - Total:", data.totalWeight, "Bonus:", data.bonusWeight)
end)
