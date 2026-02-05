--[[
    Client Movement - free-hoarder
    Weight-based movement speed reduction system
    
    EVENT-DRIVEN ARCHITECTURE:
    - Movement penalties are triggered by state bag changes (from statebags.lua)
    - Per-frame loop only runs when actively applying penalties
    - Eliminates constant polling for weight changes
    
    Uses SET_PED_MOVE_RATE_OVERRIDE native (only native that can reduce speed below 1.0)
]]

local ox_inventory = exports.ox_inventory

-- Current state (updated by state bags or legacy events)
CurrentWeight = CurrentWeight or 0
CurrentMaxWeight = CurrentMaxWeight or (Config.BaseWeight or 26500)
local CurrentMoveRate = 1.0
local TargetMoveRate = 1.0
IsEncumbered = IsEncumbered or false
local LastDebugTime = 0
-- MovementLoopActive declared below with StoredMoveRate

-------------------------------------------------------------------------------
-- SPEED CALCULATION
-------------------------------------------------------------------------------

---Calculate speed multiplier based on weight and movement state
---@param weight number Weight in grams
---@param movementState string 'walk', 'run', or 'sprint'
---@return number multiplier (1.0 = normal speed, 0.7 = 30% slower)
local function CalculateSpeedMultiplier(weight, movementState)
    if not Config.Movement or not Config.Movement.enabled then
        return 1.0
    end
    
    local threshold = Config.Movement.thresholds[movementState]
    if not threshold then
        return 1.0
    end
    
    -- Convert to kg for calculation
    local weightKg = weight / 1000
    local thresholdKg = threshold.startWeight / 1000
    
    -- Calculate effective weight (weight above threshold)
    local effectiveWeight = math.max(0, weightKg - thresholdKg)
    
    if effectiveWeight <= 0 then
        return 1.0
    end
    
    -- Calculate reduction: reductionPerKg per kg over threshold
    local reduction = effectiveWeight * Config.Movement.reductionPerKg
    
    -- Apply sprint penalty multiplier (sprinting is harder when heavy)
    if movementState == 'sprint' then
        reduction = reduction * 1.3
    end
    
    -- Clamp to maximum reduction
    reduction = math.min(reduction, threshold.maxReduction)
    
    -- Return multiplier (1.0 - reduction)
    return math.max(0.5, 1.0 - reduction) -- Never go below 50% speed
end

---Get current movement state
---@param ped number
---@return string
local function GetMovementState(ped)
    if IsPedSprinting(ped) then
        return 'sprint'
    elseif IsPedRunning(ped) then
        return 'run'
    elseif IsPedWalking(ped) then
        return 'walk'
    end
    return 'idle'
end

-------------------------------------------------------------------------------
-- EVENT-DRIVEN MOVEMENT SYSTEM
-------------------------------------------------------------------------------

-- Stored state - calculated once, applied per-frame only when needed
local StoredMoveRate = 1.0
local MovementLoopActive = false

---Calculate and store the movement rate based on current weight
---Called ONLY on inventory changes, not every frame
local function CalculateAndStoreMovement()
    if not Config.Movement or not Config.Movement.enabled then
        StoredMoveRate = 1.0
        IsEncumbered = false
        return
    end
    
    local thresholds = Config.Movement.thresholds
    local needsPenalty = CurrentWeight > (thresholds.sprint.startWeight or 5000)
    
    if needsPenalty then
        -- Calculate the move rate based on weight
        local weightKg = CurrentWeight / 1000
        local thresholdKg = thresholds.sprint.startWeight / 1000
        local effectiveWeight = math.max(0, weightKg - thresholdKg)
        
        local reduction = effectiveWeight * Config.Movement.reductionPerKg
        reduction = math.min(reduction, thresholds.sprint.maxReduction)
        
        StoredMoveRate = math.max(0.5, 1.0 - reduction)
        IsEncumbered = true
        
        DebugPrint('Movement calculated: weight=', CurrentWeight, 'rate=', StoredMoveRate)
        
        -- Start the application loop if not already running
        if not MovementLoopActive then
            StartMovementApplicationLoop()
        end
    else
        StoredMoveRate = 1.0
        IsEncumbered = false
        MovementLoopActive = false
        
        -- Reset speed immediately
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
        
        DebugPrint('Movement cleared - not encumbered')
    end
end

---Recalculate movement penalties (called by events only)
---@param newWeight number|nil New weight value (optional, uses CurrentWeight if nil)
function RecalculateMovement(newWeight)
    if newWeight then
        CurrentWeight = newWeight
    end
    CalculateAndStoreMovement()
end

---Movement application loop - ONLY applies pre-calculated rate
---NOTE: SetPedMoveRateOverride doesn't persist, so we must reapply it periodically
---This loop ONLY runs when player is encumbered (above weight threshold)
function StartMovementApplicationLoop()
    if MovementLoopActive then return end
    
    MovementLoopActive = true
    
    CreateThread(function()
        local ped = PlayerPedId()
        local lastPedUpdate = 0
        
        DebugPrint('Movement application loop started (rate:', StoredMoveRate, ')')
        
        while MovementLoopActive and IsEncumbered do
            local now = GetGameTimer()
            
            -- Update ped reference every 500ms
            if now - lastPedUpdate > 500 then
                ped = PlayerPedId()
                lastPedUpdate = now
            end
            
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                -- Simply apply the pre-calculated rate - no calculations here
                SetPedMoveRateOverride(ped, StoredMoveRate)
            end
            
            -- 100ms refresh rate - SetPedMoveRateOverride effect lasts ~200ms
            -- This is a necessary trade-off: the native doesn't persist permanently
            Wait(100)
        end
        
        -- Reset on exit
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
        MovementLoopActive = false
        
        DebugPrint('Movement application loop stopped')
    end)
end

-- Legacy function for compatibility
function StartMovementLoop()
    StartMovementApplicationLoop()
end
-------------------------------------------------------------------------------
-- EVENT-DRIVEN WEIGHT UPDATES (ZERO POLLING)
-------------------------------------------------------------------------------

-- Encumbrance state is stored and only recalculated on events
local EncumbranceState = {
    isEncumbered = false,
    currentWeight = 0,
    maxWeight = Config.BaseWeight or 26500,
    lastUpdate = 0
}

---Fetch weight and recalculate (called by events only)
local function UpdateWeightFromInventory()
    local success, weight = pcall(function()
        return ox_inventory:GetPlayerWeight()
    end)
    
    if success and weight then
        EncumbranceState.currentWeight = weight
        CurrentWeight = weight
        EncumbranceState.lastUpdate = GetGameTimer()
        RecalculateMovement(weight)
    end
end

-- ox_inventory:updateInventory - fires on ANY inventory change
AddEventHandler('ox_inventory:updateInventory', function(changes)
    UpdateWeightFromInventory()
end)

-- Capacity update event (from server when bags equip/unequip)
RegisterNetEvent('free_hoarder:capacityUpdated', function(maxWeight, bonusSlots)
    EncumbranceState.maxWeight = maxWeight
    CurrentMaxWeight = maxWeight
    RecalculateMovement()
end)

-- State bag weight change (from server hooks)
-- This is handled in statebags.lua but we also listen here for redundancy
RegisterNetEvent('free_hoarder:weightChanged', function(newWeight, newMaxWeight)
    EncumbranceState.currentWeight = newWeight
    EncumbranceState.maxWeight = newMaxWeight
    CurrentWeight = newWeight
    CurrentMaxWeight = newMaxWeight
    RecalculateMovement(newWeight)
end)

-------------------------------------------------------------------------------
-- INITIALIZATION (ONE-TIME SETUP)
-------------------------------------------------------------------------------

CreateThread(function()
    -- Wait for player to load
    while not PlayerLoaded do
        Wait(500)
    end
    
    -- Wait for inventory to be ready
    Wait(3000)
    
    -- Initial weight fetch (one-time)
    UpdateWeightFromInventory()
    
    if Config.Debug then
        print('[free-hoarder] Movement system initialized (fully event-driven)')
        print('[free-hoarder] Movement enabled:', Config.Movement and Config.Movement.enabled or false)
        print('[free-hoarder] Initial weight:', CurrentWeight, 'grams')
        print('[free-hoarder] NO POLLING - updates via ox_inventory:updateInventory event')
    end
end)

-------------------------------------------------------------------------------
-- DEBUG/STATUS
-------------------------------------------------------------------------------

---Get current movement status
---@return table
function GetMovementStatus()
    return {
        weight = CurrentWeight,
        weightKg = CurrentWeight / 1000,
        isEncumbered = IsEncumbered,
        currentMoveRate = CurrentMoveRate,
        targetMoveRate = TargetMoveRate,
        speedPercent = math.floor(CurrentMoveRate * 100)
    }
end

-- Debug command - always register for testing
RegisterCommand('hoarder_movement', function()
    local status = GetMovementStatus()
    local maxWeight = 0
    pcall(function()
        maxWeight = exports.ox_inventory:GetPlayerMaxWeight() or 0
    end)
    
    print('=== Movement Debug ===')
    print(('Weight: %.1fkg / %.1fkg'):format(status.weight / 1000, maxWeight / 1000))
    print(('Encumbered: %s'):format(tostring(status.isEncumbered)))
    print(('Current Rate: %.2f | Target: %.2f'):format(status.currentMoveRate, status.targetMoveRate))
    print(('Speed: %d%%'):format(status.speedPercent))
    print(('Movement Enabled: %s'):format(tostring(Config.Movement and Config.Movement.enabled)))
    
    -- Print thresholds
    if Config.Movement and Config.Movement.thresholds then
        print('Thresholds:')
        for state, data in pairs(Config.Movement.thresholds) do
            print(('  %s: start=%.1fkg, maxReduction=%.0f%%'):format(
                state, data.startWeight / 1000, data.maxReduction * 100
            ))
        end
    end
end, false)

-------------------------------------------------------------------------------
-- STAMINA INTEGRATION
-- NOTE: Stamina drain is now handled by client/stamina.lua (v2.0)
-- See Config.Stamina for configuration
-------------------------------------------------------------------------------
