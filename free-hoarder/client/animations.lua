--[[
    Client Animations - free-hoarder
    Handles equip and unequip animation sequences
    
    EVENT-DRIVEN: Control blocking starts/stops directly when animation state changes
]]

-- Track if animation is currently playing
---@type boolean
local IsAnimating = false
local AnimationControlLoopActive = false

-------------------------------------------------------------------------------
-- ANIMATION CONTROL BLOCKING (INTEGRATED)
-------------------------------------------------------------------------------

-- Start blocking controls when animation begins
local function StartAnimationControlBlock()
    if AnimationControlLoopActive then return end
    
    AnimationControlLoopActive = true
    
    CreateThread(function()
        while AnimationControlLoopActive and IsAnimating do
            -- Prevent weapon switching during animation
            DisableControlAction(0, 37, true) -- Weapon wheel
            DisableControlAction(0, 157, true) -- Select weapon unarmed
            DisableControlAction(0, 158, true) -- Select weapon melee
            DisableControlAction(0, 159, true) -- Select weapon shotgun
            DisableControlAction(0, 160, true) -- Select weapon heavy
            DisableControlAction(0, 161, true) -- Select weapon special
            DisableControlAction(0, 162, true) -- Select weapon autorifle
            
            Wait(8) -- 125 checks/sec for control disabling
        end
        
        AnimationControlLoopActive = false
    end)
end

-- Stop blocking controls when animation ends
local function StopAnimationControlBlock()
    AnimationControlLoopActive = false
end

-- Wrapper to set animation state and trigger control blocking
local function SetAnimationState(animating)
    local wasAnimating = IsAnimating
    IsAnimating = animating
    
    if animating and not wasAnimating then
        StartAnimationControlBlock()
    elseif not animating and wasAnimating then
        StopAnimationControlBlock()
    end
end

-------------------------------------------------------------------------------
-- ANIMATION DICTIONARY LOADING
-------------------------------------------------------------------------------

---Load an animation dictionary with timeout
---@param dict string Animation dictionary name
---@param timeout? number Timeout in milliseconds
---@return boolean success
function LoadAnimDict(dict, timeout)
    timeout = timeout or 5000
    
    if HasAnimDictLoaded(dict) then
        return true
    end
    
    RequestAnimDict(dict)
    
    local waited = 0
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        waited = waited + 10
        if waited >= timeout then
            DebugPrint('ERROR: Failed to load anim dict:', dict)
            return false
        end
    end
    
    return true
end

---Release an animation dictionary
---@param dict string
function ReleaseAnimDict(dict)
    RemoveAnimDict(dict)
end

-------------------------------------------------------------------------------
-- ANIMATION PLAYBACK
-------------------------------------------------------------------------------

---Get animation data for a bag type
---@param bagType string
---@param animType string 'equip' or 'unequip'
---@return table|nil
local function GetAnimationData(bagType, animType)
    local defaults = Config.Animations.defaults[bagType]
    if defaults and defaults[animType] then
        return defaults[animType]
    end
    return nil
end

---Play an animation and execute callback when done
---@param animData table Animation data { dict, anim, flag }
---@param duration number Duration in milliseconds
---@param callback? function Callback when animation completes
local function PlayAnimation(animData, duration, callback)
    if not animData or not animData.dict or not animData.anim then
        if callback then callback() end
        return
    end
    
    local ped = PlayerPedId()
    
    -- Load animation dictionary
    if not LoadAnimDict(animData.dict) then
        if callback then callback() end
        return
    end
    
    -- Start animation and control blocking
    SetAnimationState(true)
    
    -- Play animation
    TaskPlayAnim(
        ped,
        animData.dict,
        animData.anim,
        8.0,                    -- blendInSpeed
        -8.0,                   -- blendOutSpeed
        duration,               -- duration
        animData.flag or 49,    -- flag (49 = upper body only, can move)
        0.0,                    -- playbackRate
        false,                  -- lockX
        false,                  -- lockY
        false                   -- lockZ
    )
    
    -- Wait for animation to complete (or near complete for callback)
    SetTimeout(math.floor(duration * 0.7), function()
        if callback then
            callback()
        end
    end)
    
    -- Cleanup - end animation state and control blocking
    SetTimeout(duration + 100, function()
        SetAnimationState(false)
        ReleaseAnimDict(animData.dict)
    end)
end

-------------------------------------------------------------------------------
-- PUBLIC ANIMATION FUNCTIONS
-------------------------------------------------------------------------------

---Play equip animation for a bag type
---@param bagType string
---@param callback? function
function PlayEquipAnimation(bagType, callback)
    if not Config.Animations.enabled then
        if callback then callback() end
        return
    end
    
    local animData = GetAnimationData(bagType, 'equip')
    local duration = Config.Animations.equipDuration
    
    PlayAnimation(animData, duration, callback)
end

---Play unequip animation for a bag type
---@param bagType string
---@param callback? function
function PlayUnequipAnimation(bagType, callback)
    if not Config.Animations.enabled then
        if callback then callback() end
        return
    end
    
    local animData = GetAnimationData(bagType, 'unequip')
    local duration = Config.Animations.unequipDuration
    
    PlayAnimation(animData, duration, callback)
end

---Check if an animation is currently playing
---@return boolean
function IsPlayingBagAnimation()
    return IsAnimating
end

---Cancel current animation
function CancelBagAnimation()
    if IsAnimating then
        local ped = PlayerPedId()
        ClearPedTasks(ped)
        SetAnimationState(false)
    end
end

-------------------------------------------------------------------------------
-- ANIMATION TOGGLE
-------------------------------------------------------------------------------

---Toggle animations on/off at runtime
---@param enabled boolean
function SetAnimationsEnabled(enabled)
    Config.Animations.enabled = enabled
    DebugPrint(('Animations %s'):format(enabled and 'enabled' or 'disabled'))
end

---Check if animations are enabled
---@return boolean
function AreAnimationsEnabled()
    return Config.Animations.enabled
end

-------------------------------------------------------------------------------
-- SOUND EFFECTS
-------------------------------------------------------------------------------

local soundsConfig = nil

CreateThread(function()
    Wait(500)
    soundsConfig = Config and Config.Sounds or {}
end)

---Play a sound effect
---@param soundName string Name from Config.Sounds
---@param entity number|nil Entity to attach sound to
local function PlaySound(soundName, entity)
    if not soundsConfig or not soundsConfig.enabled then return end
    
    local sound = soundsConfig.sounds and soundsConfig.sounds[soundName]
    if not sound then return end
    
    entity = entity or PlayerPedId()
    
    if sound.native then
        PlaySoundFromEntity(-1, sound.name, entity, sound.set, true, 0)
    else
        if sound.file then
            TriggerEvent('xsound:PlayOnEntity', soundName, sound.file, entity, sound.volume or 0.5)
        end
    end
end

---Play equip sound based on bag type
---@param bagType string
function PlayEquipSound(bagType)
    if not soundsConfig or not soundsConfig.enabled then return end
    local soundName = 'equip_' .. bagType
    if not soundsConfig.sounds or not soundsConfig.sounds[soundName] then
        soundName = 'equip_generic'
    end
    PlaySound(soundName)
end

---Play unequip sound based on bag type
---@param bagType string
function PlayUnequipSound(bagType)
    if not soundsConfig or not soundsConfig.enabled then return end
    local soundName = 'unequip_' .. bagType
    if not soundsConfig.sounds or not soundsConfig.sounds[soundName] then
        soundName = 'unequip_generic'
    end
    PlaySound(soundName)
end

---Play drop sound
---@param bagType string
function PlayDropSound(bagType)
    if not soundsConfig or not soundsConfig.enabled then return end
    local soundName = 'drop_' .. bagType
    if not soundsConfig.sounds or not soundsConfig.sounds[soundName] then
        soundName = 'drop_generic'
    end
    PlaySound(soundName)
end

---Play bag open/close sound
---@param bagType string
---@param isOpening boolean
function PlayBagOpenSound(bagType, isOpening)
    if not soundsConfig or not soundsConfig.enabled then return end
    local action = isOpening and 'open' or 'close'
    local soundName = action .. '_' .. bagType
    if not soundsConfig.sounds or not soundsConfig.sounds[soundName] then
        soundName = action .. '_generic'
    end
    PlaySound(soundName)
end

---Play bag rummage/search sound
function PlayRummageSound()
    if not soundsConfig or not soundsConfig.enabled then return end
    PlaySound('rummage')
end

---Play bag throw sound
function PlayThrowSound()
    if not soundsConfig or not soundsConfig.enabled then return end
    PlaySound('throw')
end

---Play bag break/tear sound
---@param bagType string
function PlayBreakSound(bagType)
    if not soundsConfig or not soundsConfig.enabled then return end
    local soundName = 'break_' .. bagType
    if not soundsConfig.sounds or not soundsConfig.sounds[soundName] then
        soundName = 'break_generic'
    end
    PlaySound(soundName)
end

---Play zipper sound
function PlayZipperSound()
    if not soundsConfig or not soundsConfig.enabled then return end
    PlaySound('zipper')
end

---Play rustle sound (paper/plastic bags)
function PlayRustleSound()
    if not soundsConfig or not soundsConfig.enabled then return end
    PlaySound('rustle')
end

-- Sound exports
exports('PlayEquipSound', PlayEquipSound)
exports('PlayUnequipSound', PlayUnequipSound)
exports('PlayDropSound', PlayDropSound)
exports('PlayBagOpenSound', PlayBagOpenSound)
