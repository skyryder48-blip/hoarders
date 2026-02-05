--[[
    Client Physical Systems - free-hoarder v2.0
    Combined stamina drain and swimming auto-drop systems
]]

-------------------------------------------------------------------------------
-- STAMINA SYSTEM
-------------------------------------------------------------------------------

local StaminaThreadActive = false
local CurrentStaminaMultiplier = 1.0
local LastCapacityCheck = 0

local DEFAULT_STAMINA_THRESHOLDS = {
    { capacity = 55, drain = 1.5 },
    { capacity = 80, drain = 2.5 },
    { capacity = 95, drain = 4.0 },
}

---Calculate stamina drain multiplier based on current capacity
---@return number multiplier
local function CalculateStaminaMultiplier()
    if not Config.Stamina or not Config.Stamina.enabled then
        return 1.0
    end
    
    local capacityPercent = 0
    local success, result = pcall(function()
        return exports['free-hoarder']:GetCapacityPercentage()
    end)
    
    if success and result then
        capacityPercent = result
    else
        local currentWeight = LocalPlayer.state['hoarder:inventoryWeight'] or 0
        local maxWeight = LocalPlayer.state['hoarder:maxWeight'] or 26500
        if maxWeight > 0 then
            capacityPercent = (currentWeight / maxWeight) * 100
        end
    end
    
    local thresholds = Config.Stamina.thresholds or DEFAULT_STAMINA_THRESHOLDS
    local multiplier = 1.0
    
    for _, threshold in ipairs(thresholds) do
        if capacityPercent >= threshold.capacity then
            multiplier = threshold.drain
        end
    end
    
    return multiplier
end

local function StartStaminaThread()
    if StaminaThreadActive then return end
    StaminaThreadActive = true
    
    CreateThread(function()
        while StaminaThreadActive do
            if not Config.Stamina or not Config.Stamina.enabled then
                Wait(5000)
                goto continue
            end
            
            local now = GetGameTimer()
            if now - LastCapacityCheck > 1000 then
                CurrentStaminaMultiplier = CalculateStaminaMultiplier()
                LastCapacityCheck = now
            end
            
            if CurrentStaminaMultiplier > 1.0 then
                local ped = PlayerPedId()
                
                if IsPedSprinting(ped) or IsPedSwimming(ped) then
                    local currentStamina = GetPlayerSprintStaminaRemaining(PlayerId())
                    
                    if currentStamina < 100 then
                        local waitTime = math.floor(100 / CurrentStaminaMultiplier)
                        Wait(math.max(waitTime, 10))
                    else
                        Wait(50)
                    end
                else
                    Wait(100)
                end
            else
                Wait(500)
            end
            
            ::continue::
        end
    end)
end

---Called when player's capacity changes
function OnCapacityChangedForStamina(currentWeight, maxWeight)
    if not Config.Stamina or not Config.Stamina.enabled then return end
    
    local oldMultiplier = CurrentStaminaMultiplier
    CurrentStaminaMultiplier = CalculateStaminaMultiplier()
    
    if Config.Stamina.notifyOnThreshold then
        if oldMultiplier < 1.5 and CurrentStaminaMultiplier >= 1.5 then
            NotifyWarning('You\'re carrying a lot - stamina drains faster')
        elseif oldMultiplier < 2.5 and CurrentStaminaMultiplier >= 2.5 then
            NotifyWarning('Heavy load - stamina drains much faster')
        elseif oldMultiplier >= 1.5 and CurrentStaminaMultiplier < 1.5 then
            NotifyInfo('Lighter load - normal stamina')
        end
    end
end

-------------------------------------------------------------------------------
-- SWIMMING AUTO-DROP SYSTEM
-------------------------------------------------------------------------------

local SwimmingThreadActive = false
local WasSwimming = false
local WasInWater = false
local DropWarningShown = false

---Check if player is swimming
---@return boolean
local function IsPlayerSwimming()
    local ped = PlayerPedId()
    return IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)
end

---Check if player is in water
---@return boolean
local function IsPlayerInWater()
    local ped = PlayerPedId()
    return IsEntityInWater(ped)
end

---Get player water depth (0.0 to 1.0)
---@return number
local function GetPlayerWaterDepth()
    local ped = PlayerPedId()
    return GetEntitySubmergedLevel(ped)
end

---Check if player should drop items in water
---@return boolean shouldDrop
---@return string reason
local function ShouldDropInWater()
    if not Config.Swimming or not Config.Swimming.enabled then
        return false, 'disabled'
    end
    
    local hasTwoHand = false
    local success, result = pcall(function()
        return exports['free-hoarder']:IsTwoHandCarryActive()
    end)
    
    if success then
        hasTwoHand = result
    else
        hasTwoHand = LocalEquippedBags and LocalEquippedBags['TWO_HAND'] ~= nil
    end
    
    if not hasTwoHand then
        return false, 'no_item'
    end
    
    local isSwimming = IsPlayerSwimming()
    local waterDepth = GetPlayerWaterDepth()
    local depthThreshold = Config.Swimming.dropDepthThreshold or 0.5
    
    if isSwimming then
        return true, 'swimming'
    end
    
    if waterDepth >= depthThreshold then
        return true, 'submerged'
    end
    
    return false, 'safe'
end

---Drop two-hand item in water
local function DropTwoHandItemInWater()
    local twoHandData = nil
    
    if LocalEquippedBags and LocalEquippedBags['TWO_HAND'] then
        twoHandData = LocalEquippedBags['TWO_HAND']
    end
    
    if not twoHandData then return end
    
    local bagConfig = twoHandData.config or (Config.Bags and Config.Bags[twoHandData.bagName])
    local bagLabel = bagConfig and bagConfig.label or twoHandData.bagName
    
    PlaySoundFrontend(-1, 'WEAPON_THROW', 'HUD_FRONTEND_WEAPONS_SOUNDSET', true)
    NotifyWarning(bagLabel .. ' dropped in the water!')
    TriggerServerEvent('free_hoarder:dropBagToGround', 'TWO_HAND', twoHandData.bagName)
    
    if TriggerBagDropped then
        TriggerBagDropped({
            source = GetPlayerServerId(PlayerId()),
            bagName = twoHandData.bagName,
            bagLabel = bagLabel,
            slotName = 'TWO_HAND',
            reason = 'water'
        })
    end
end

local function ShowWaterWarning()
    if DropWarningShown then return end
    DropWarningShown = true
    NotifyWarning('Entering water - you\'ll drop your item!')
    SetTimeout(3000, function()
        DropWarningShown = false
    end)
end

local function StartSwimmingThread()
    if SwimmingThreadActive then return end
    SwimmingThreadActive = true
    
    CreateThread(function()
        while SwimmingThreadActive do
            if not Config.Swimming or not Config.Swimming.enabled then
                Wait(5000)
                goto continue
            end
            
            local hasTwoHand = false
            local success, result = pcall(function()
                return exports['free-hoarder']:IsTwoHandCarryActive()
            end)
            
            if success then
                hasTwoHand = result
            else
                hasTwoHand = LocalEquippedBags and LocalEquippedBags['TWO_HAND'] ~= nil
            end
            
            if not hasTwoHand then
                WasSwimming = false
                WasInWater = false
                Wait(1000)
                goto continue
            end
            
            local shouldDrop, reason = ShouldDropInWater()
            local isInWater = IsPlayerInWater()
            local waterDepth = GetPlayerWaterDepth()
            
            if isInWater and not WasInWater and not shouldDrop then
                if Config.Swimming.warnBeforeDrop then
                    ShowWaterWarning()
                end
            end
            
            if shouldDrop then
                if Config.Swimming.dropDelay and Config.Swimming.dropDelay > 0 then
                    Wait(Config.Swimming.dropDelay)
                    shouldDrop, reason = ShouldDropInWater()
                end
                
                if shouldDrop then
                    DropTwoHandItemInWater()
                    Wait(2000)
                end
            end
            
            WasSwimming = IsPlayerSwimming()
            WasInWater = isInWater
            
            if isInWater then
                Wait(100)
            elseif waterDepth > 0 then
                Wait(200)
            else
                Wait(500)
            end
            
            ::continue::
        end
    end)
end

-------------------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------------------

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(1000)
    end
    
    if Config.Stamina and Config.Stamina.enabled then
        StartStaminaThread()
        print('[free-hoarder] Stamina system started')
    end
    
    if Config.Swimming and Config.Swimming.enabled then
        StartSwimmingThread()
        print('[free-hoarder] Swimming auto-drop started')
    end
end)

RegisterNetEvent('free_hoarder:capacityChanged', function(currentWeight, maxWeight)
    OnCapacityChangedForStamina(currentWeight, maxWeight)
end)

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------

exports('GetStaminaMultiplier', function() return CurrentStaminaMultiplier end)
exports('IsStaminaDrainActive', function() return CurrentStaminaMultiplier > 1.0 end)
exports('IsPlayerInWater', IsPlayerInWater)
exports('IsPlayerSwimming', IsPlayerSwimming)
exports('GetPlayerWaterDepth', GetPlayerWaterDepth)
exports('ShouldDropInWater', ShouldDropInWater)
