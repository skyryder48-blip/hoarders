--[[
    State Bags System - free-hoarder (Client)
    
    Reactive handlers that replace polling loops:
    - Bag visibility sync across all clients
    - Weight/capacity reactive updates
    - Movement penalty application
    - Over-capacity detection
]]

local myServerId = nil
local myBagFilter = nil

-------------------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------------------

CreateThread(function()
    -- Wait for player to fully load
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end
    
    myServerId = GetPlayerServerId(PlayerId())
    myBagFilter = ('player:%d'):format(myServerId)
    
    DebugPrint('State bags client initialized, filter:', myBagFilter)
    
    -- Request initial state sync
    Wait(1000)
    TriggerServerEvent('free_hoarder:requestStateSync')
end)

-------------------------------------------------------------------------------
-- BAG VISIBILITY SYNC (ALL PLAYERS)
-- React to any player's equipped bags changing
-------------------------------------------------------------------------------

AddStateBagChangeHandler('hoarder:equippedBags', nil, function(bagName, key, value, _unused, replicated)
    -- Extract player ID from bag name (format: "player:123")
    local playerId = GetPlayerFromStateBagName(bagName)
    if playerId == 0 then return end
    
    local ped = GetPlayerPed(playerId)
    if not DoesEntityExist(ped) then return end
    
    local isLocalPlayer = IsLocalPlayer(playerId)
    
    DebugPrint('Bag state changed for player', playerId, 'local:', isLocalPlayer, 'data:', json.encode(value))
    
    if isLocalPlayer then
        -- Local player: Update LocalEquippedBags and props
        HandleLocalBagStateChange(value)
    else
        -- Remote player: Just handle prop visibility
        HandleRemoteBagStateChange(playerId, ped, value)
    end
end)

---Handle local player's bag state change
---@param bagsData table|nil
function HandleLocalBagStateChange(bagsData)
    -- Build current slots from state
    local currentSlots = {}
    if bagsData then
        for slotName, _ in pairs(bagsData) do
            currentSlots[slotName] = true
        end
    end
    
    -- Find removed bags
    for slotName, _ in pairs(LocalEquippedBags or {}) do
        if not currentSlots[slotName] then
            -- Bag was removed
            RemoveBagProp(slotName)
            DebugPrint('Removed bag from slot:', slotName)
        end
    end
    
    -- Update LocalEquippedBags and add/update props
    LocalEquippedBags = {}
    
    if bagsData then
        for slotName, bagData in pairs(bagsData) do
            -- Get full config for this bag
            local bagConfig = GetBagConfig(bagData.bagName)
            
            LocalEquippedBags[slotName] = {
                bagName = bagData.bagName,
                containerId = bagData.containerId,
                config = bagConfig
            }
            
            -- Attach/update prop
            if bagConfig then
                AttachBagProp(slotName, bagData.bagName, bagConfig)
            end
        end
    end
    
    -- Update weapon restrictions based on hand slots
    UpdateWeaponRestrictions()
    
    -- Check clothing conflicts
    if UpdateBagVisibilityForClothing then
        UpdateBagVisibilityForClothing()
    end
end

---Handle remote player's bag visibility
---@param playerId number
---@param ped number
---@param bagsData table|nil
function HandleRemoteBagStateChange(playerId, ped, bagsData)
    -- Track remote player props
    RemotePlayerProps = RemotePlayerProps or {}
    RemotePlayerProps[playerId] = RemotePlayerProps[playerId] or {}
    
    -- Clear existing props for this player
    for slotName, prop in pairs(RemotePlayerProps[playerId]) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    RemotePlayerProps[playerId] = {}
    
    -- Attach new props
    if bagsData then
        for slotName, bagData in pairs(bagsData) do
            if bagData.model then
                local prop = AttachBagPropToRemotePed(ped, slotName, bagData)
                if prop then
                    RemotePlayerProps[playerId][slotName] = prop
                end
            end
        end
    end
end

---Attach a bag prop to a remote player's ped
---@param ped number
---@param slotName string
---@param bagData table
---@return number|nil prop
function AttachBagPropToRemotePed(ped, slotName, bagData)
    local modelHash = type(bagData.model) == 'string' and joaat(bagData.model) or bagData.model
    
    if not IsModelValid(modelHash) then
        DebugPrint('Invalid model for remote ped:', bagData.model)
        return nil
    end
    
    RequestModel(modelHash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(10)
    end
    
    if not HasModelLoaded(modelHash) then
        return nil
    end
    
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, false)
    
    if not DoesEntityExist(prop) then
        SetModelAsNoLongerNeeded(modelHash)
        return nil
    end
    
    -- Get bone and offsets for slot
    local boneId = BoneIds[slotName] or 24817
    local offsets = bagData.offsets or { pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) }
    
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, boneId),
        offsets.pos.x, offsets.pos.y, offsets.pos.z,
        offsets.rot.x, offsets.rot.y, offsets.rot.z,
        true, true, false, true, 0, true
    )
    
    SetEntityCollisionOnEntity(prop, false, false)
    SetModelAsNoLongerNeeded(modelHash)
    
    return prop
end

---Check if a player ID is the local player
---@param playerId number
---@return boolean
function IsLocalPlayer(playerId)
    return GetPlayerServerId(PlayerId()) == GetPlayerServerId(playerId)
end

-------------------------------------------------------------------------------
-- WEIGHT/CAPACITY REACTIVE UPDATES (LOCAL PLAYER ONLY)
-------------------------------------------------------------------------------

-- React to inventory weight changes
AddStateBagChangeHandler('hoarder:inventoryWeight', nil, function(bagName, key, value, _unused, replicated)
    -- Only process our own weight
    if bagName ~= myBagFilter then return end
    if value == nil then return end
    
    CurrentWeight = value
    DebugPrint('Weight updated reactively:', value)
    
    -- Trigger movement recalculation
    RecalculateMovement()
end)

-- React to max weight changes
AddStateBagChangeHandler('hoarder:maxWeight', nil, function(bagName, key, value, _unused, replicated)
    if bagName ~= myBagFilter then return end
    if value == nil then return end
    
    CurrentMaxWeight = value
    DebugPrint('Max weight updated reactively:', value)
    
    RecalculateMovement()
end)

-- React to over-capacity state
AddStateBagChangeHandler('hoarder:isOverCapacity', nil, function(bagName, key, value, _unused, replicated)
    if bagName ~= myBagFilter then return end
    
    local wasOverCapacity = IsOverCapacity
    IsOverCapacity = value == true
    
    if IsOverCapacity and not wasOverCapacity then
        DebugPrint('Now over capacity!')
        StartOverCapacityPenalties()
    elseif not IsOverCapacity and wasOverCapacity then
        DebugPrint('No longer over capacity')
        StopOverCapacityPenalties()
    end
end)

-------------------------------------------------------------------------------
-- MOVEMENT PENALTY SYSTEM (REACTIVE)
-------------------------------------------------------------------------------

local CurrentWeight = 0
local CurrentMaxWeight = Config.BaseWeight or 26500
local CurrentMoveRate = 1.0
local MovementThreadActive = false

---Recalculate and apply movement penalties
function RecalculateMovement()
    if not Config.Movement or not Config.Movement.enabled then return end
    
    local weightRatio = CurrentWeight / CurrentMaxWeight
    local thresholds = Config.Movement.thresholds
    
    -- Calculate target move rate based on weight
    local targetRate = 1.0
    
    if CurrentWeight > (thresholds.sprint.startWeight or 5000) then
        local overWeight = CurrentWeight - thresholds.sprint.startWeight
        local penalty = (overWeight / 1000) * (Config.Movement.reductionPerKg or 0.01)
        targetRate = math.max(1.0 - thresholds.sprint.maxReduction, 1.0 - penalty)
    end
    
    -- Only start thread if we need to apply penalties
    if targetRate < 0.99 and not MovementThreadActive then
        StartMovementThread(targetRate)
    elseif targetRate >= 0.99 and MovementThreadActive then
        MovementThreadActive = false
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
    else
        CurrentMoveRate = targetRate
    end
end

---Start movement penalty application thread
---@param targetRate number
function StartMovementThread(targetRate)
    if MovementThreadActive then 
        CurrentMoveRate = targetRate
        return 
    end
    
    MovementThreadActive = true
    CurrentMoveRate = targetRate
    
    CreateThread(function()
        local ped = PlayerPedId()
        local lastPedCheck = 0
        
        while MovementThreadActive do
            local now = GetGameTimer()
            
            -- Update ped reference every 500ms
            if now - lastPedCheck > 500 then
                ped = PlayerPedId()
                lastPedCheck = now
            end
            
            -- Apply move rate override (required periodically - doesn't persist)
            SetPedMoveRateOverride(ped, CurrentMoveRate)
            
            -- 100ms refresh - SetPedMoveRateOverride effect lasts ~200ms
            Wait(100)
        end
        
        -- Reset on exit
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
    end)
end

-------------------------------------------------------------------------------
-- OVER-CAPACITY PENALTY SYSTEM (REACTIVE)
-------------------------------------------------------------------------------

local OverCapacityThreadActive = false
local LastOverCapacityWarning = 0
local StoredOverCapacityRate = 0.3 -- From config

---Start over-capacity penalties
function StartOverCapacityPenalties()
    if OverCapacityThreadActive then return end
    if not Config.OverCapacity or Config.OverCapacity.method ~= 'penalty' then return end
    
    OverCapacityThreadActive = true
    StoredOverCapacityRate = Config.OverCapacity.penalty.speedMultiplier or 0.3
    
    CreateThread(function()
        local penalty = Config.OverCapacity.penalty
        local ped = PlayerPedId()
        local lastPedCheck = 0
        
        DebugPrint('Over-capacity loop started (rate:', StoredOverCapacityRate, ')')
        
        -- Show initial warning
        local overAmount = CurrentWeight - CurrentMaxWeight
        Notify({
            title = 'Over Capacity!',
            description = ('Drop %s to move normally'):format(FormatWeight(overAmount)),
            type = 'warning',
            duration = 5000
        })
        LastOverCapacityWarning = GetGameTimer()
        
        while OverCapacityThreadActive and IsOverCapacity do
            local now = GetGameTimer()
            
            -- Update ped reference
            if now - lastPedCheck > 500 then
                ped = PlayerPedId()
                lastPedCheck = now
            end
            
            -- Apply severe speed reduction (pre-calculated rate)
            SetPedMoveRateOverride(ped, StoredOverCapacityRate)
            
            -- Block controls
            if penalty.blockSprint then
                DisableControlAction(0, 21, true)
            end
            if penalty.blockJump then
                DisableControlAction(0, 22, true)
            end
            
            -- Periodic warning (every 30 seconds)
            local interval = penalty.warningInterval or 30000
            if now - LastOverCapacityWarning > interval then
                LastOverCapacityWarning = now
                local overAmount = CurrentWeight - CurrentMaxWeight
                Notify({
                    title = 'Over Capacity!',
                    description = ('Drop %s to move normally'):format(FormatWeight(overAmount)),
                    type = 'warning',
                    duration = 5000
                })
            end
            
            Wait(50) -- 50ms for control blocking, 100ms would miss too many inputs
        end
        
        -- Reset on exit
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
        OverCapacityThreadActive = false
        
        DebugPrint('Over-capacity loop stopped')
    end)
end

---Stop over-capacity penalties
function StopOverCapacityPenalties()
    OverCapacityThreadActive = false
end

-------------------------------------------------------------------------------
-- OX_LIB CACHE INTEGRATION (REPLACES POLLING)
-------------------------------------------------------------------------------

-- React to ped model changes (respawn, character switch)
lib.onCache('ped', function(newPed, oldPed)
    if not newPed then return end
    
    DebugPrint('Ped changed, reattaching props...')
    
    -- Small delay for model to stabilize
    Wait(500)
    
    -- Reattach all local player props
    for slotName, bagData in pairs(LocalEquippedBags or {}) do
        if bagData and bagData.config then
            RemoveBagProp(slotName)
            Wait(50)
            AttachBagProp(slotName, bagData.bagName, bagData.config)
        end
    end
    
    -- Update clothing visibility
    if UpdateBagVisibilityForClothing then
        UpdateBagVisibilityForClothing()
    end
end)

-- React to vehicle entry/exit
lib.onCache('vehicle', function(vehicle, oldVehicle)
    -- Could be used to adjust bag visibility in vehicles
    if vehicle then
        DebugPrint('Entered vehicle:', vehicle)
    else
        DebugPrint('Exited vehicle')
    end
end)

-- React to weapon changes (for weapon restrictions)
lib.onCache('weapon', function(weapon, oldWeapon)
    if not WeaponsRestricted then return end
    
    if weapon and weapon ~= `WEAPON_UNARMED` then
        -- Check if it's a restricted weapon
        if IsTwoHandedWeapon and IsTwoHandedWeapon(weapon) then
            SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true)
            
            Notify({
                title = 'Hands Full',
                description = 'Cannot use two-handed weapons while holding a bag',
                type = 'warning'
            })
        end
    end
end)

-------------------------------------------------------------------------------
-- CLEANUP
-------------------------------------------------------------------------------

-- Clean up remote player props when they leave
AddEventHandler('playerDropped', function()
    local playerId = source
    if RemotePlayerProps and RemotePlayerProps[playerId] then
        for _, prop in pairs(RemotePlayerProps[playerId]) do
            if DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
        end
        RemotePlayerProps[playerId] = nil
    end
end)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    MovementThreadActive = false
    OverCapacityThreadActive = false
    
    -- Clean up all remote props
    if RemotePlayerProps then
        for _, props in pairs(RemotePlayerProps) do
            for _, prop in pairs(props) do
                if DoesEntityExist(prop) then
                    DeleteEntity(prop)
                end
            end
        end
    end
end)

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------


print('[free-hoarder] State bags client system loaded')
