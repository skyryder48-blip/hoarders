--[[
    Client Props - free-hoarder
    Handles model streaming, prop creation, and attachment to player ped
]]

-- Track attached props by slot
---@type table<string, number>
local AttachedProps = {}

-- Track if two-hand carry is active
local TwoHandCarryActive = false
local DefaultMovementClipset = nil

-------------------------------------------------------------------------------
-- TWO-HAND CARRY ANIMATION SYSTEM
-------------------------------------------------------------------------------

---Apply carry animation and movement clipset for two-hand items
---@param bagConfig table Bag configuration with carry settings
function ApplyTwoHandCarry(bagConfig)
    if TwoHandCarryActive then return end
    
    local ped = PlayerPedId()
    local carryClipset = bagConfig.carryClipset or 'anim@heists@box_carry@'
    local carryAnim = bagConfig.carryAnim or 'idle'
    local movementClipset = bagConfig.movementClipset or 'move_m@bag'
    
    DebugPrint('Applying two-hand carry animation')
    
    -- Load animation dictionary
    lib.requestAnimDict(carryClipset)
    
    -- Play carry animation (upper body, looping)
    TaskPlayAnim(ped, carryClipset, carryAnim, 8.0, -8.0, -1, 49, 0, false, false, false)
    
    -- Apply movement clipset for walking while carrying
    if movementClipset then
        RequestClipSet(movementClipset)
        local waited = 0
        while not HasClipSetLoaded(movementClipset) and waited < 2000 do
            Wait(10)
            waited = waited + 10
        end
        
        if HasClipSetLoaded(movementClipset) then
            SetPedMovementClipset(ped, movementClipset, 0.5)
            DebugPrint('Applied movement clipset:', movementClipset)
        end
    end
    
    TwoHandCarryActive = true
end

---Remove carry animation and restore normal movement
function RemoveTwoHandCarry()
    if not TwoHandCarryActive then return end
    
    local ped = PlayerPedId()
    
    DebugPrint('Removing two-hand carry animation')
    
    -- Stop the carry animation
    ClearPedTasks(ped)
    
    -- Reset movement clipset to default
    ResetPedMovementClipset(ped, 0.5)
    
    TwoHandCarryActive = false
end

---Check if two-hand carry is currently active
---@return boolean
function IsTwoHandCarryActive()
    return TwoHandCarryActive
end


-------------------------------------------------------------------------------
-- MODEL LOADING
-------------------------------------------------------------------------------

---Load a model with timeout
---@param model string|number Model name or hash
---@param timeout? number Timeout in milliseconds (default 5000)
---@return boolean success
---@return number|string modelHashOrError
function LoadModelWithTimeout(model, timeout)
    local modelHash = type(model) == 'string' and joaat(model) or model
    timeout = timeout or 5000
    
    if not IsModelValid(modelHash) then
        return false, 'Invalid model: ' .. tostring(model)
    end
    
    if HasModelLoaded(modelHash) then
        return true, modelHash
    end
    
    RequestModel(modelHash)
    
    local waited = 0
    while not HasModelLoaded(modelHash) do
        Wait(10)
        waited = waited + 10
        if waited >= timeout then
            return false, 'Model load timeout: ' .. tostring(model)
        end
    end
    
    return true, modelHash
end

---Release a model from memory
---@param model string|number
function ReleaseModel(model)
    local modelHash = type(model) == 'string' and joaat(model) or model
    SetModelAsNoLongerNeeded(modelHash)
end

-------------------------------------------------------------------------------
-- PROP ATTACHMENT
-------------------------------------------------------------------------------

---Attach a bag prop to the player
---@param slotName string Attachment slot name
---@param bagName string Bag item name
---@param bagConfig table Bag configuration
---@return number|nil propHandle
function AttachBagProp(slotName, bagName, bagConfig)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        DebugPrint('ERROR: Player ped does not exist')
        return nil
    end
    
    -- Tucked bags have no visible prop - just return success without creating anything
    if IsTuckedBagType(bagConfig.type) or IsTuckedSlot(slotName) or not bagConfig.model then
        DebugPrint('Tucked bag equipped (no prop):', bagName)
        return -1  -- Return special value indicating no prop needed
    end
    
    -- Remove existing prop in this slot
    if AttachedProps[slotName] and DoesEntityExist(AttachedProps[slotName]) then
        DeleteEntity(AttachedProps[slotName])
        AttachedProps[slotName] = nil
    end
    
    -- Get model name with fallback
    local modelName = bagConfig.model
    local fallbackModel = bagConfig.fallbackModel
    
    if not modelName then
        DebugPrint('ERROR: No model defined for bag:', bagName)
        return nil
    end
    
    -- Load model (try primary first, then fallback)
    local success, modelHash = LoadModelWithTimeout(modelName)
    if not success then
        print(('[free-hoarder] WARNING: Primary model "%s" failed: %s'):format(modelName, tostring(modelHash)))
        
        -- Try fallback if available
        if fallbackModel then
            print(('[free-hoarder] Trying fallback model: %s'):format(fallbackModel))
            success, modelHash = LoadModelWithTimeout(fallbackModel)
            if not success then
                print(('[free-hoarder] ERROR: Fallback model also failed: %s'):format(tostring(modelHash)))
                return nil
            end
            modelName = fallbackModel
        else
            return nil
        end
    end
    
    -- Get attachment offset for this slot
    local offsets = bagConfig.offsets and bagConfig.offsets[slotName]
    if not offsets then
        DebugPrint('ERROR: No offsets defined for slot:', slotName)
        ReleaseModel(modelHash)
        return nil
    end
    
    -- Create the prop
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
    
    if not DoesEntityExist(prop) then
        DebugPrint('ERROR: Failed to create prop for:', modelName)
        ReleaseModel(modelHash)
        return nil
    end
    
    -- Get bone index
    local boneId = BoneIds[slotName]
    if not boneId then
        DebugPrint('ERROR: No bone ID for slot:', slotName)
        DeleteEntity(prop)
        ReleaseModel(modelHash)
        return nil
    end
    
    local boneIndex = GetPedBoneIndex(ped, boneId)
    
    -- Attach to player
    AttachEntityToEntity(
        prop,               -- entity1 (prop)
        ped,                -- entity2 (player)
        boneIndex,          -- boneIndex
        offsets.pos.x,      -- xPos
        offsets.pos.y,      -- yPos
        offsets.pos.z,      -- zPos
        offsets.rot.x,      -- xRot
        offsets.rot.y,      -- yRot
        offsets.rot.z,      -- zRot
        false,              -- p9
        true,               -- useSoftPinning
        false,              -- collision
        true,               -- isPed (CRITICAL for correct rotation)
        2,                  -- rotationOrder
        true                -- syncRot
    )
    
    -- Disable collision
    SetEntityCompletelyDisableCollision(prop, false, true)
    
    -- Store reference
    AttachedProps[slotName] = prop
    
    -- Release model from memory
    ReleaseModel(modelHash)
    
    -- Apply two-hand carry animation if this is a TWO_HAND slot
    if slotName == 'TWO_HAND' and bagConfig.type == 'twohand' then
        ApplyTwoHandCarry(bagConfig)
    end
    
    DebugPrint(('Attached prop %s to slot %s (entity: %d)'):format(modelName, slotName, prop))
    
    return prop
end

---Remove a bag prop from a specific slot
---@param slotName string
function RemoveBagProp(slotName)
    local prop = AttachedProps[slotName]
    
    if prop and DoesEntityExist(prop) then
        -- Detach first
        DetachEntity(prop, false, false)
        
        -- Small delay then delete
        SetTimeout(50, function()
            if DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
        end)
        
        DebugPrint(('Removed prop from slot %s'):format(slotName))
    end
    
    -- Remove two-hand carry animation if this was a TWO_HAND slot
    if slotName == 'TWO_HAND' then
        RemoveTwoHandCarry()
    end
    
    AttachedProps[slotName] = nil
end

---Remove all attached bag props
function RemoveAllBagProps()
    for slotName, prop in pairs(AttachedProps) do
        if prop and DoesEntityExist(prop) then
            DetachEntity(prop, false, false)
            DeleteEntity(prop)
        end
    end
    
    AttachedProps = {}
    
    -- Also clear any two-hand carry animation
    RemoveTwoHandCarry()
    
    DebugPrint('Removed all bag props')
end

-------------------------------------------------------------------------------
-- PROP VALIDATION
-------------------------------------------------------------------------------

---Check if a prop is still valid and attached
---@param slotName string
---@return boolean
function IsPropValid(slotName)
    local prop = AttachedProps[slotName]
    return prop and DoesEntityExist(prop) and IsEntityAttachedToEntity(prop, PlayerPedId())
end

---Validate and repair all attached props
function ValidateAllProps()
    local ped = PlayerPedId()
    
    for slotName, prop in pairs(AttachedProps) do
        if not prop or not DoesEntityExist(prop) or not IsEntityAttachedToEntity(prop, ped) then
            DebugPrint(('Prop invalid for slot %s, reattaching...'):format(slotName))
            
            -- Get bag data
            local bagData = LocalEquippedBags[slotName]
            if bagData and bagData.config then
                AttachedProps[slotName] = nil
                AttachBagProp(slotName, bagData.bagName, bagData.config)
            else
                AttachedProps[slotName] = nil
            end
        end
    end
end

-------------------------------------------------------------------------------
-- PROP VISIBILITY
-------------------------------------------------------------------------------

---Set prop visibility (for cutscenes, etc.)
---@param visible boolean
function SetAllPropsVisible(visible)
    for _, prop in pairs(AttachedProps) do
        if prop and DoesEntityExist(prop) then
            SetEntityVisible(prop, visible, false)
        end
    end
end

-------------------------------------------------------------------------------
-- EVENT-DRIVEN PROP VALIDATION (ZERO POLLING)
-------------------------------------------------------------------------------

-- Validate props only when triggered by events:
-- 1. Bag equipped/unequipped (server events)
-- 2. Ped model changed (lib.onCache in statebags.lua)
-- 3. Resource start

-- Called by server when bag state changes
RegisterNetEvent('free_hoarder:bagEquipped', function(slotName, bagName, bagConfig)
    -- Validate existing props after a short delay
    SetTimeout(500, function()
        ValidateAllProps()
    end)
end)

RegisterNetEvent('free_hoarder:bagUnequipped', function(slotName)
    -- Validate remaining props
    SetTimeout(500, function()
        ValidateAllProps()
    end)
end)

-- Export for other scripts to trigger validation
exports('ValidateAllBagProps', ValidateAllProps)

-------------------------------------------------------------------------------
-- PROP VISIBILITY FUNCTIONS (for clothing integration)
-------------------------------------------------------------------------------

---Get a prop handle for a slot
---@param slotName string
---@return number|nil propHandle
function GetPropHandle(slotName)
    return AttachedProps[slotName]
end

---Hide a prop by slot name
---@param slotName string
function HidePropBySlot(slotName)
    local propHandle = AttachedProps[slotName]
    if propHandle and DoesEntityExist(propHandle) then
        SetEntityVisible(propHandle, false, false)
        SetEntityCollision(propHandle, false, false)
        DebugPrint('Hid prop in slot:', slotName)
    end
end

---Show a prop by slot name
---@param slotName string
function ShowPropBySlot(slotName)
    local propHandle = AttachedProps[slotName]
    if propHandle and DoesEntityExist(propHandle) then
        SetEntityVisible(propHandle, true, false)
        -- Keep collision off for attached props
        DebugPrint('Showed prop in slot:', slotName)
    end
end

exports('HidePropBySlot', HidePropBySlot)
exports('ShowPropBySlot', ShowPropBySlot)

-- NOTE: Ped model changes are handled by lib.onCache('ped') in statebags.lua
-- which calls ReattachAllProps() - no polling needed

-------------------------------------------------------------------------------
-- DEBUG COMMANDS
-------------------------------------------------------------------------------

-- Test if a prop model is valid
RegisterCommand('hoarder_testprop', function(source, args)
    local modelName = args[1]
    if not modelName then
        print('Usage: /hoarder_testprop <model_name>')
        return
    end
    
    local modelHash = joaat(modelName)
    local isValid = IsModelValid(modelHash)
    
    print(('Model "%s" (hash: %d) - Valid: %s'):format(modelName, modelHash, tostring(isValid)))
    
    if isValid then
        -- Try to load it
        RequestModel(modelHash)
        local waited = 0
        while not HasModelLoaded(modelHash) and waited < 3000 do
            Wait(10)
            waited = waited + 10
        end
        
        if HasModelLoaded(modelHash) then
            print('  Model loaded successfully!')
            
            -- Create test prop
            local coords = GetEntityCoords(PlayerPedId())
            local prop = CreateObject(modelHash, coords.x + 1.0, coords.y, coords.z, true, true, false)
            
            if DoesEntityExist(prop) then
                print('  Prop created at your location (will delete in 5 seconds)')
                SetTimeout(5000, function()
                    if DoesEntityExist(prop) then
                        DeleteEntity(prop)
                    end
                end)
            else
                print('  WARNING: Prop creation failed!')
            end
            
            SetModelAsNoLongerNeeded(modelHash)
        else
            print('  WARNING: Model load timeout!')
        end
    end
end, false)

-- List all current bag props
RegisterCommand('hoarder_props', function()
    print('=== Attached Bag Props ===')
    local count = 0
    for slotName, prop in pairs(AttachedProps) do
        if prop and DoesEntityExist(prop) then
            print(('  %s: Entity %d (exists: true)'):format(slotName, prop))
            count = count + 1
        else
            print(('  %s: Invalid/missing'):format(slotName))
        end
    end
    print(('Total valid props: %d'):format(count))
end, false)

-- Note: Ped change detection is now combined with validation loop above for efficiency
