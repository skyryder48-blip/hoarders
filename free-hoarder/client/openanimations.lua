--[[
    Client Opening Animations - free-hoarder v2.0
    Per-bag configurable opening animations
    
    Animation Types:
    - 'full' - Full body animation, blocks movement (large cases, two-hand)
    - 'upper' - Upper body only, can walk (wallets, small bags)
    - 'quick' - Very fast animation (tucked items)
    - 'none' - No animation
    
    All animations are cancellable.
]]

-------------------------------------------------------------------------------
-- LOCAL STATE
-------------------------------------------------------------------------------

local IsPlayingOpenAnimation = false
local CurrentOpenAnimData = nil
local AnimationCancelled = false

-------------------------------------------------------------------------------
-- ANIMATION DEFINITIONS
-------------------------------------------------------------------------------

-- Default animations by bag type
local DefaultAnimations = {
    -- Backpacks - full body, kneel down
    backpack = {
        type = 'full',
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        clip = 'machinic_loop_mechandplayer',
        duration = 2000,
        flag = 1,  -- Loop
        blockMovement = true,
    },
    
    -- Shoulder bags - upper body
    shoulderbag = {
        type = 'upper',
        dict = 'mp_common',
        clip = 'givetake1_a',
        duration = 1500,
        flag = 48,  -- Upper body only
        blockMovement = false,
    },
    
    -- Handbags (briefcase, clutch) - full body, open on ground/table
    handbag = {
        type = 'full',
        dict = 'anim@heists@ornate_bank@grab_cash',
        clip = 'grab',
        duration = 1800,
        flag = 1,
        blockMovement = true,
    },
    
    -- Two-hand carry items - set down animation
    twohand = {
        type = 'full',
        dict = 'anim@heists@box_carry@',
        clip = 'put_down_box',
        duration = 2000,
        flag = 0,
        blockMovement = true,
    },
    
    -- Tucked items (wallet, mag holder) - quick reach
    tucked = {
        type = 'quick',
        dict = 'mp_common',
        clip = 'givetake1_a',
        duration = 800,
        flag = 48,  -- Upper body
        blockMovement = false,
    },
}

-- Custom animations for specific bag items (override defaults)
local CustomAnimations = {
    -- Briefcase - dramatic open
    ['hoarder_hand_briefcase'] = {
        type = 'full',
        dict = 'anim@heists@ornate_bank@grab_cash',
        clip = 'intro',
        duration = 2500,
        flag = 0,
        blockMovement = true,
    },
    
    -- Rifle case - careful open
    ['hoarder_hand_riflecase'] = {
        type = 'full',
        dict = 'weapons@heavy@minigun',
        clip = 'yourewrong_intro',
        duration = 2000,
        flag = 0,
        blockMovement = true,
    },
    
    -- Wallet - quick pocket reach
    ['hoarder_wallet'] = {
        type = 'quick',
        dict = 'clothingtie',
        clip = 'try_tie_negative_a',
        duration = 600,
        flag = 48,
        blockMovement = false,
    },
    
    -- Cooler - open lid
    ['hoarder_carry_cooler'] = {
        type = 'full',
        dict = 'anim@amb@business@cfm@cfm_desktop_br@',
        clip = 'base_cfm_desktop_br',
        duration = 1500,
        flag = 0,
        blockMovement = true,
    },
    
    -- Toolbox - unlatch and open
    ['hoarder_carry_toolbox'] = {
        type = 'full',
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        clip = 'machinic_loop_player',
        duration = 1800,
        flag = 0,
        blockMovement = true,
    },
}

-------------------------------------------------------------------------------
-- ANIMATION HELPERS
-------------------------------------------------------------------------------

---Get animation data for a bag
---@param bagName string
---@param bagConfig table|nil
---@return table animData
local function GetAnimationForBag(bagName, bagConfig)
    -- Check if animations are enabled
    if not Config.OpenAnimations or not Config.OpenAnimations.enabled then
        return { type = 'none' }
    end
    
    -- Check for bag-specific config override
    if bagConfig and bagConfig.openAnimation then
        return bagConfig.openAnimation
    end
    
    -- Check for custom animation for this specific item
    if CustomAnimations[bagName] then
        return CustomAnimations[bagName]
    end
    
    -- Check config typeDefaults
    local bagType = bagConfig and bagConfig.type or 'backpack'
    if Config.OpenAnimations.typeDefaults and Config.OpenAnimations.typeDefaults[bagType] then
        return Config.OpenAnimations.typeDefaults[bagType]
    end
    
    -- Fall back to hardcoded default for bag type
    if DefaultAnimations[bagType] then
        return DefaultAnimations[bagType]
    end
    
    -- Ultimate fallback
    return DefaultAnimations.backpack
end

-- Note: Uses global LoadAnimDict from animations.lua

-------------------------------------------------------------------------------
-- PLAY OPENING ANIMATION
-------------------------------------------------------------------------------

---Play the opening animation for a bag
---@param slotName string
---@param bagName string
---@param bagConfig table|nil
---@param onComplete function Callback when animation completes
---@param onCancel function|nil Callback when animation is cancelled
function PlayOpeningAnimation(slotName, bagName, bagConfig, onComplete, onCancel)
    -- Get animation data
    local animData = GetAnimationForBag(bagName, bagConfig)
    
    -- Skip if no animation
    if animData.type == 'none' then
        if onComplete then onComplete() end
        return
    end
    
    -- Check if already playing
    if IsPlayingOpenAnimation then
        if onCancel then onCancel('already_playing') end
        return
    end
    
    local ped = PlayerPedId()
    
    -- Load animation
    if not LoadAnimDict(animData.dict) then
        -- Failed to load, just complete without animation
        if onComplete then onComplete() end
        return
    end
    
    -- Set state
    IsPlayingOpenAnimation = true
    AnimationCancelled = false
    CurrentOpenAnimData = {
        slotName = slotName,
        bagName = bagName,
        animData = animData,
        startTime = GetGameTimer(),
        onComplete = onComplete,
        onCancel = onCancel
    }
    
    -- Block movement if required
    if animData.blockMovement then
        FreezeEntityPosition(ped, true)
    end
    
    -- Play animation
    TaskPlayAnim(
        ped,
        animData.dict,
        animData.clip,
        8.0,      -- Blend in
        -8.0,     -- Blend out
        animData.duration,
        animData.flag,
        0,        -- Playback rate
        false,    -- Lock X
        false,    -- Lock Y
        false     -- Lock Z
    )
    
    -- Monitor animation
    CreateThread(function()
        local startTime = GetGameTimer()
        local duration = animData.duration
        
        while IsPlayingOpenAnimation do
            Wait(50)
            
            -- Check for cancellation
            if AnimationCancelled then
                -- Stop animation
                StopAnimTask(ped, animData.dict, animData.clip, 1.0)
                
                -- Unfreeze
                if animData.blockMovement then
                    FreezeEntityPosition(ped, false)
                end
                
                -- Callback
                if CurrentOpenAnimData and CurrentOpenAnimData.onCancel then
                    CurrentOpenAnimData.onCancel('cancelled')
                end
                
                -- Reset state
                IsPlayingOpenAnimation = false
                CurrentOpenAnimData = nil
                return
            end
            
            -- Check for completion
            local elapsed = GetGameTimer() - startTime
            if elapsed >= duration then
                -- Animation complete
                StopAnimTask(ped, animData.dict, animData.clip, 1.0)
                
                -- Unfreeze
                if animData.blockMovement then
                    FreezeEntityPosition(ped, false)
                end
                
                -- Callback
                if CurrentOpenAnimData and CurrentOpenAnimData.onComplete then
                    CurrentOpenAnimData.onComplete()
                end
                
                -- Reset state
                IsPlayingOpenAnimation = false
                CurrentOpenAnimData = nil
                return
            end
            
            -- Check for interruption (player got in vehicle, died, etc)
            if IsPedInAnyVehicle(ped, false) or IsPedDeadOrDying(ped, true) then
                CancelOpeningAnimation()
            end
        end
    end)
end

---Cancel the current opening animation
---@param reason string|nil
function CancelOpeningAnimation(reason)
    if not IsPlayingOpenAnimation then return end
    
    AnimationCancelled = true
    
    if reason then
        print('[free-hoarder] Animation cancelled:', reason)
    end
end

---Check if an opening animation is currently playing
---@return boolean
function IsOpeningAnimationPlaying()
    return IsPlayingOpenAnimation
end

-------------------------------------------------------------------------------
-- KEYBIND FOR CANCELLATION
-------------------------------------------------------------------------------

-- Allow cancelling animation with movement keys or escape
CreateThread(function()
    while true do
        Wait(0)
        
        if IsPlayingOpenAnimation and CurrentOpenAnimData then
            local animData = CurrentOpenAnimData.animData
            
            -- Only check cancellation for full-body animations
            if animData.blockMovement then
                -- Check for movement input
                if IsControlPressed(0, 32) or  -- W
                   IsControlPressed(0, 33) or  -- S
                   IsControlPressed(0, 34) or  -- A
                   IsControlPressed(0, 35) or  -- D
                   IsControlPressed(0, 22) or  -- Space (jump)
                   IsControlPressed(0, 202) then -- Escape/Back
                    CancelOpeningAnimation('player_input')
                    NotifyInfo('Animation cancelled')
                end
            end
        else
            Wait(500)  -- Sleep when not animating
        end
    end
end)

-------------------------------------------------------------------------------
-- HOOK INTO BAG OPENING
-------------------------------------------------------------------------------

---Open a bag with animation
---@param slotName string
---@param bagData table
---@param callback function Called with (success) after animation
function OpenBagWithAnimation(slotName, bagData, callback)
    local bagConfig = bagData.config or Config.Bags[bagData.bagName]
    
    -- Check if animations are enabled
    if not Config.OpenAnimations or not Config.OpenAnimations.enabled then
        -- No animation, just open
        if callback then callback(true) end
        return
    end
    
    -- Check if this bag type should skip animation
    local bagType = bagConfig and bagConfig.type or 'backpack'
    if Config.OpenAnimations.skipForTypes then
        for _, skipType in ipairs(Config.OpenAnimations.skipForTypes) do
            if bagType == skipType then
                if callback then callback(true) end
                return
            end
        end
    end
    
    -- Play animation
    PlayOpeningAnimation(
        slotName,
        bagData.bagName,
        bagConfig,
        function()  -- On complete
            if callback then callback(true) end
        end,
        function(reason)  -- On cancel
            if callback then callback(false, reason) end
        end
    )
end

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------

exports('PlayOpeningAnimation', PlayOpeningAnimation)
exports('CancelOpeningAnimation', CancelOpeningAnimation)
exports('IsOpeningAnimationPlaying', IsOpeningAnimationPlaying)
exports('OpenBagWithAnimation', OpenBagWithAnimation)
exports('GetAnimationForBag', GetAnimationForBag)
