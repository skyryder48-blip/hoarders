--[[
    State Bags System - free-hoarder (Server)
    
    Uses OneSync state bags for:
    - Cross-client bag visibility sync
    - Reactive weight/capacity updates
    - Eliminating polling on clients
]]

-------------------------------------------------------------------------------
-- STATE BAG KEYS
-------------------------------------------------------------------------------
-- Player state bag keys used:
-- - equippedBags: table of equipped bag data { [slotName] = { bagName, model, containerId } }
-- - inventoryWeight: current inventory weight in grams
-- - maxWeight: current max weight capacity
-- - bagContentsWeight: total weight stored in bag containers
-- - isOverCapacity: boolean for over-capacity state

-------------------------------------------------------------------------------
-- STATE BAG SETTERS (Server -> All Clients)
-------------------------------------------------------------------------------

---Set player's equipped bags state (syncs to all clients)
---@param source number Player server ID
---@param bags table|nil Table of equipped bags or nil to clear
function SetPlayerBagsState(source, bags)
    local player = Player(source)
    if not player then return end
    
    -- Serialize bag data for state bag (flat structure)
    local bagState = {}
    if bags then
        for slotName, bagData in pairs(bags) do
            bagState[slotName] = {
                bagName = bagData.bagName,
                model = bagData.config and bagData.config.prop or nil,
                texture = bagData.config and bagData.config.propTexture or 0,
                containerId = bagData.containerId,
                type = bagData.config and bagData.config.type or 'backpack',
                offsets = bagData.config and bagData.config.offsets and bagData.config.offsets[slotName] or nil
            }
        end
    end
    
    -- Set state bag (auto-replicates to all clients)
    player.state:set('hoarder:equippedBags', next(bagState) and bagState or nil, true)
    
    DebugPrint('Set bags state for player', source, ':', json.encode(bagState))
end

---Update a single bag slot in player's state
---@param source number
---@param slotName string
---@param bagData table|nil
function UpdatePlayerBagSlotState(source, slotName, bagData)
    local player = Player(source)
    if not player then return end
    
    local currentState = player.state['hoarder:equippedBags'] or {}
    
    if bagData then
        currentState[slotName] = {
            bagName = bagData.bagName,
            model = bagData.config and bagData.config.prop or nil,
            texture = bagData.config and bagData.config.propTexture or 0,
            containerId = bagData.containerId,
            type = bagData.config and bagData.config.type or 'backpack',
            offsets = bagData.config and bagData.config.offsets and bagData.config.offsets[slotName] or nil
        }
    else
        currentState[slotName] = nil
    end
    
    player.state:set('hoarder:equippedBags', next(currentState) and currentState or nil, true)
end

---Set player's weight state (triggers reactive updates on client)
---@param source number
---@param currentWeight number
---@param maxWeight number
---@param bagContentsWeight number
function SetPlayerWeightState(source, currentWeight, maxWeight, bagContentsWeight)
    local player = Player(source)
    if not player then return end
    
    -- Use individual keys for granular updates
    player.state:set('hoarder:inventoryWeight', currentWeight, true)
    player.state:set('hoarder:maxWeight', maxWeight, true)
    player.state:set('hoarder:bagContentsWeight', bagContentsWeight or 0, true)
    player.state:set('hoarder:isOverCapacity', currentWeight > maxWeight, true)
    
    DebugPrint('Set weight state for player', source, 
        '- weight:', currentWeight, 
        'max:', maxWeight, 
        'bagContents:', bagContentsWeight or 0)
end

---Clear all state bags for a player (on disconnect/cleanup)
---@param source number
function ClearPlayerState(source)
    local player = Player(source)
    if not player then return end
    
    player.state:set('hoarder:equippedBags', nil, true)
    player.state:set('hoarder:inventoryWeight', nil, true)
    player.state:set('hoarder:maxWeight', nil, true)
    player.state:set('hoarder:bagContentsWeight', nil, true)
    player.state:set('hoarder:isOverCapacity', nil, true)
    
    DebugPrint('Cleared state for player', source)
end

-------------------------------------------------------------------------------
-- REACTIVE WEIGHT UPDATES VIA OX_INVENTORY HOOKS
-------------------------------------------------------------------------------

-- Debounce tracking to prevent rate limiting
local weightUpdateQueue = {}
local WEIGHT_UPDATE_DEBOUNCE = 100 -- ms

---Queue a weight update (debounced)
---@param source number
local function QueueWeightUpdate(source)
    if weightUpdateQueue[source] then return end
    
    weightUpdateQueue[source] = true
    
    SetTimeout(WEIGHT_UPDATE_DEBOUNCE, function()
        weightUpdateQueue[source] = nil
        
        -- Get weight from inventory object (GetPlayerWeight is client-side only)
        local currentWeight = 0
        local inventory = exports.ox_inventory:GetInventory(source, false)
        if inventory and inventory.weight then
            currentWeight = inventory.weight
        end
        
        -- Get max weight - base + bonus from bags
        local maxWeight = Config.BaseWeight or 26500
        local bonusWeight = CalculateTotalBonusCapacity and CalculateTotalBonusCapacity(source) or 0
        maxWeight = maxWeight + bonusWeight
        
        local bagContentsWeight = CalculateBagContentsWeight and CalculateBagContentsWeight(source) or 0
        
        SetPlayerWeightState(source, currentWeight, maxWeight, bagContentsWeight)
    end)
end

-- Hook: React to ANY inventory item movement
local swapHookId = exports.ox_inventory:registerHook('swapItems', function(payload)
    local source = payload.source
    if not source then return true end
    
    -- Queue weight update (debounced to prevent spam)
    QueueWeightUpdate(source)
    
    return true -- Allow the operation
end, {
    print = false -- Don't spam console
})

-- Hook: React to item creation (spawn items, purchases, etc)
local createHookId = exports.ox_inventory:registerHook('createItem', function(payload)
    if payload.inventoryId and type(payload.inventoryId) == 'number' then
        QueueWeightUpdate(payload.inventoryId)
    end
    return true
end, {
    print = false
})

-- Hook: React to item purchases
local buyHookId = exports.ox_inventory:registerHook('buyItem', function(payload)
    if payload.source then
        QueueWeightUpdate(payload.source)
    end
    return true
end, {
    print = false
})

DebugPrint('Registered ox_inventory hooks for reactive weight updates')

-------------------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------------------

-- Sync state for all online players on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    SetTimeout(3000, function()
        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local source = tonumber(playerId)
            if source then
                -- Initialize weight state
                QueueWeightUpdate(source)
                
                -- Initialize bags state from EquippedBags table
                if EquippedBags and EquippedBags[source] then
                    SetPlayerBagsState(source, EquippedBags[source])
                end
            end
        end
        
        print('[free-hoarder] State bags initialized for', #players, 'players')
    end)
end)

print('[free-hoarder] State bags system loaded')

-------------------------------------------------------------------------------
-- CLIENT REQUEST HANDLERS
-------------------------------------------------------------------------------

-- Handle client requesting state sync (on connect/resource start)
RegisterNetEvent('free_hoarder:requestStateSync', function()
    local source = source
    if source <= 0 then return end
    
    -- Sync bags state
    if EquippedBags and EquippedBags[source] then
        SetPlayerBagsState(source, EquippedBags[source])
    end
    
    -- Sync weight state
    QueueWeightUpdate(source)
    
    DebugPrint('State sync requested by player', source)
end)
