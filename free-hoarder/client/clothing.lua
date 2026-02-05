--[[
    Clothing Integration - free-hoarder
    
    Integrates with illenium-appearance / fivem-appearance to:
    1. Hide bag props when conflicting clothing is worn
    2. Save and restore outfits from bags
]]

local clothingConfig = Config.Clothing
local outfitConfig = Config.OutfitSaving

-- Track hidden bag slots due to clothing conflicts
local HiddenByClothing = {}

-- Cache current clothing state
local CurrentClothing = {}

-- Track when clothing events fire (for smart polling)
local lastEventTime = 0

-------------------------------------------------------------------------------
-- CLOTHING CONFLICT DETECTION
-------------------------------------------------------------------------------

---Get current player clothing components
---@return table<number, {drawable: number, texture: number}>
local function GetCurrentClothing()
    local ped = PlayerPedId()
    local clothing = {}
    
    for componentId = 0, 11 do
        clothing[componentId] = {
            drawable = GetPedDrawableVariation(ped, componentId),
            texture = GetPedTextureVariation(ped, componentId)
        }
    end
    
    return clothing
end

---Check if a specific clothing component/drawable conflicts with a bag slot
---@param slotName string Bag attachment slot name
---@param componentId number GTA clothing component ID
---@param drawableId number Drawable variation ID
---@return boolean conflicts
local function CheckClothingConflict(slotName, componentId, drawableId)
    local slotConflicts = clothingConfig.conflicts[slotName]
    if not slotConflicts then return false end
    
    local conflictingDrawables = slotConflicts[componentId]
    if not conflictingDrawables then return false end
    
    -- Check each configured drawable
    for _, conflictDrawable in ipairs(conflictingDrawables) do
        -- -1 means "any non-zero drawable conflicts"
        if conflictDrawable == -1 then
            if drawableId > 0 then
                return true
            end
        -- Otherwise check for exact match
        elseif drawableId == conflictDrawable then
            return true
        end
    end
    
    return false
end

---Check all clothing against a bag slot
---@param slotName string
---@return boolean hasConflict
local function SlotHasClothingConflict(slotName)
    local clothing = GetCurrentClothing()
    
    for componentId, data in pairs(clothing) do
        if CheckClothingConflict(slotName, componentId, data.drawable) then
            return true
        end
    end
    
    return false
end

---Update bag visibility based on current clothing
function UpdateBagVisibilityForClothing()
    if not clothingConfig.enabled then return end
    
    local equippedBags = LocalEquippedBags or {}
    
    for slotName, bagData in pairs(equippedBags) do
        local hasConflict = SlotHasClothingConflict(slotName)
        local wasHidden = HiddenByClothing[slotName]
        
        if hasConflict and not wasHidden then
            -- Hide the bag prop
            HiddenByClothing[slotName] = true
            HideBagProp(slotName)
            
            -- Notify if configured
            if clothingConfig.conflictBehavior == 'notify' or clothingConfig.conflictBehavior == 'both' then
                local bagConfig = GetBagConfig(bagData.bagName)
                local bagLabel = bagConfig and bagConfig.label or bagData.bagName
                Notify({
                    title = 'Bag Hidden',
                    description = clothingConfig.hideMessage:format(bagLabel),
                    type = 'info',
                    duration = 3000
                })
            end
            
            DebugPrint('Hiding bag in slot', slotName, 'due to clothing conflict')
            
        elseif not hasConflict and wasHidden then
            -- Show the bag prop again
            HiddenByClothing[slotName] = nil
            ShowBagProp(slotName)
            
            -- Notify if configured
            if clothingConfig.conflictBehavior == 'notify' or clothingConfig.conflictBehavior == 'both' then
                local bagConfig = GetBagConfig(bagData.bagName)
                local bagLabel = bagConfig and bagConfig.label or bagData.bagName
                Notify({
                    title = 'Bag Visible',
                    description = clothingConfig.showMessage:format(bagLabel),
                    type = 'info',
                    duration = 3000
                })
            end
            
            DebugPrint('Showing bag in slot', slotName, 'clothing conflict resolved')
        end
    end
end

---Hide a bag prop (called by conflict system)
---@param slotName string
function HideBagProp(slotName)
    -- Use export from props.lua
    if HidePropBySlot then
        HidePropBySlot(slotName)
    else
        -- Fallback using export
        pcall(function()
            exports['free-hoarder']:HidePropBySlot(slotName)
        end)
    end
end

---Show a bag prop (called when conflict resolved)
---@param slotName string
function ShowBagProp(slotName)
    -- Use export from props.lua
    if ShowPropBySlot then
        ShowPropBySlot(slotName)
    else
        -- Fallback using export
        pcall(function()
            exports['free-hoarder']:ShowPropBySlot(slotName)
        end)
    end
end

---Check if a slot's bag is hidden by clothing
---@param slotName string
---@return boolean
function IsBagHiddenByClothing(slotName)
    return HiddenByClothing[slotName] == true
end

-------------------------------------------------------------------------------
-- CLOTHING CHANGE EVENT HANDLERS (EVENT-DRIVEN ONLY)
-------------------------------------------------------------------------------

-- Track last clothing hash for change detection
local lastClothingHash = 0

-- Get a hash of current clothing for quick comparison
local function GetClothingHash()
    local ped = PlayerPedId()
    local hash = 0
    for componentId = 0, 11 do
        hash = hash + (GetPedDrawableVariation(ped, componentId) * (componentId + 1))
    end
    return hash
end

-- Called by appearance script events
local function OnClothingEvent()
    Wait(500) -- Wait for outfit to apply
    local newHash = GetClothingHash()
    if newHash ~= lastClothingHash then
        lastClothingHash = newHash
        UpdateBagVisibilityForClothing()
    end
end

-- illenium-appearance integration (most common appearance script)
AddEventHandler('illenium-appearance:client:loadJobOutfit', OnClothingEvent)

AddEventHandler('illenium-appearance:client:onOutfitPreview', function()
    Wait(100)
    local newHash = GetClothingHash()
    if newHash ~= lastClothingHash then
        lastClothingHash = newHash
        UpdateBagVisibilityForClothing()
    end
end)

AddEventHandler('illenium-appearance:client:ApplyOutfit', OnClothingEvent)

-- fivem-appearance events
AddEventHandler('fivem-appearance:client:changeClothing', OnClothingEvent)

-- Generic skin/clothing change events
AddEventHandler('skinchanger:modelLoaded', function()
    Wait(500)
    lastClothingHash = GetClothingHash()
    UpdateBagVisibilityForClothing()
    -- Re-attach all bag props after model change
    if ReattachAllProps then
        ReattachAllProps()
    end
end)

AddEventHandler('qb-clothing:client:loadOutfit', OnClothingEvent)
AddEventHandler('qb-clothing:client:loadPlayerClothing', OnClothingEvent)
AddEventHandler('esx_skin:playerRegistered', OnClothingEvent)

-- Trigger clothing check when bag is equipped (from statebags or server event)
RegisterNetEvent('free_hoarder:bagEquipped', function(slotName, bagName, bagConfig)
    if clothingConfig.enabled then
        Wait(200)
        lastClothingHash = GetClothingHash()
        UpdateBagVisibilityForClothing()
    end
end)

-- Also check on state bag change (handled in statebags.lua but export for manual trigger)
exports('CheckClothingConflicts', function()
    if clothingConfig.enabled then
        lastClothingHash = GetClothingHash()
        UpdateBagVisibilityForClothing()
    end
end)

-- Initial clothing hash on player load (one-time)
CreateThread(function()
    if not clothingConfig.enabled then return end
    
    while not PlayerLoaded do
        Wait(1000)
    end
    
    Wait(3000) -- Wait for character to fully load
    lastClothingHash = GetClothingHash()
    
    -- Initial check if bags already equipped
    if LocalEquippedBags and next(LocalEquippedBags) then
        UpdateBagVisibilityForClothing()
    end
    
    DebugPrint('[free-hoarder] Clothing system initialized (event-driven only)')
    DebugPrint('[free-hoarder] NO POLLING - updates via appearance script events')
end)

-- NOTE: No polling loop! Clothing changes are detected via:
-- 1. illenium-appearance / fivem-appearance / qb-clothing events
-- 2. skinchanger:modelLoaded event
-- 3. Bag equip events (to check for conflicts)
-- 4. Manual export CheckClothingConflicts()

-------------------------------------------------------------------------------
-- OUTFIT SAVING SYSTEM
-------------------------------------------------------------------------------

---Get full player appearance data
---@return table appearanceData
local function GetPlayerAppearance()
    local ped = PlayerPedId()
    local appearance = {
        model = GetEntityModel(ped),
        components = {},
        props = {},
        headBlend = nil,
        faceFeatures = {},
        headOverlays = {},
        hair = {},
    }
    
    -- Get clothing components (0-11)
    if outfitConfig.saveComponents.clothing then
        for i = 0, 11 do
            appearance.components[i] = {
                drawable = GetPedDrawableVariation(ped, i),
                texture = GetPedTextureVariation(ped, i),
                palette = GetPedPaletteVariation(ped, i)
            }
        end
    end
    
    -- Get props (hats, glasses, watches, etc.)
    if outfitConfig.saveComponents.props then
        for i = 0, 8 do
            appearance.props[i] = {
                drawable = GetPedPropIndex(ped, i),
                texture = GetPedPropTextureIndex(ped, i)
            }
        end
    end
    
    -- Get hair
    if outfitConfig.saveComponents.hair then
        appearance.hair = {
            style = GetPedDrawableVariation(ped, 2),
            color = GetPedHairColor(ped),
            highlight = GetPedHairHighlightColor(ped)
        }
    end
    
    return appearance
end

---Apply saved appearance to player
---@param appearance table
local function ApplyPlayerAppearance(appearance)
    local ped = PlayerPedId()
    
    -- Apply clothing components
    if appearance.components then
        for componentId, data in pairs(appearance.components) do
            SetPedComponentVariation(ped, tonumber(componentId), data.drawable, data.texture, data.palette or 0)
        end
    end
    
    -- Apply props
    if appearance.props then
        for propId, data in pairs(appearance.props) do
            if data.drawable == -1 then
                ClearPedProp(ped, tonumber(propId))
            else
                SetPedPropIndex(ped, tonumber(propId), data.drawable, data.texture, true)
            end
        end
    end
    
    -- Apply hair
    if appearance.hair and appearance.hair.style then
        SetPedComponentVariation(ped, 2, appearance.hair.style, 0, 0)
        SetPedHairColor(ped, appearance.hair.color or 0, appearance.hair.highlight or 0)
    end
end

---Save current outfit to a bag
---@param bagSlotName string The attachment slot of the bag
---@param outfitName string Name for the outfit
---@return boolean success
function SaveOutfitToBag(bagSlotName, outfitName)
    DebugPrint('SaveOutfitToBag called - slot:', bagSlotName, 'name:', outfitName)
    
    if not outfitConfig.enabled then
        Notify({ title = 'Error', description = 'Outfit saving is disabled', type = 'error' })
        return false
    end
    
    local bagData = LocalEquippedBags[bagSlotName]
    DebugPrint('bagData:', bagData ~= nil, 'containerId:', bagData and bagData.containerId or 'nil')
    
    if not bagData then
        Notify({ title = 'Error', description = 'No bag in that slot', type = 'error' })
        return false
    end
    
    local bagConfig = GetBagConfig(bagData.bagName)
    if not bagConfig then return false end
    
    -- Check if this bag type allows outfit saving
    local bagType = bagConfig.type
    if not outfitConfig.allowedBagTypes[bagType] then
        Notify({ title = 'Error', description = 'This bag cannot store outfits', type = 'error' })
        return false
    end
    
    -- Get current appearance
    local appearance = GetPlayerAppearance()
    DebugPrint('Got appearance data, sending to server...')
    
    -- Send to server to save in bag metadata
    local success = lib.callback.await('free_hoarder:saveOutfitToBag', false, bagData.containerId, outfitName, appearance)
    
    DebugPrint('Server response:', success)
    
    if success then
        Notify({ 
            title = 'Outfit Saved', 
            description = ('Saved "%s" to your %s'):format(outfitName, bagConfig.label),
            type = 'success' 
        })
    else
        Notify({ title = 'Error', description = 'Failed to save outfit', type = 'error' })
    end
    
    return success
end

---Load outfit from a bag
---@param bagSlotName string
---@param outfitIndex number
---@return boolean success
function LoadOutfitFromBag(bagSlotName, outfitIndex)
    if not outfitConfig.enabled then return false end
    
    local bagData = LocalEquippedBags[bagSlotName]
    if not bagData then return false end
    
    -- Request outfit from server
    local outfit = lib.callback.await('free_hoarder:getOutfitFromBag', false, bagData.containerId, outfitIndex)
    
    if not outfit then
        Notify({ title = 'Error', description = 'Outfit not found', type = 'error' })
        return false
    end
    
    -- Play changing animation if enabled
    local animConfig = outfitConfig.changeAnimation
    if animConfig and animConfig.enabled then
        local ped = PlayerPedId()
        lib.requestAnimDict(animConfig.dict)
        TaskPlayAnim(ped, animConfig.dict, animConfig.anim, 8.0, -8.0, animConfig.duration or 3000, 49, 0, false, false, false)
        Wait(animConfig.duration or 3000)
        ClearPedTasks(ped)
    end
    
    -- Apply the outfit
    ApplyPlayerAppearance(outfit.appearance)
    
    Notify({ 
        title = 'Outfit Loaded', 
        description = ('Changed into "%s"'):format(outfit.name),
        type = 'success' 
    })
    
    -- Update bag visibility after outfit change
    Wait(100)
    UpdateBagVisibilityForClothing()
    
    return true
end

---Get list of outfits saved in a bag
---@param bagSlotName string
---@return table outfits
function GetBagOutfits(bagSlotName)
    local bagData = LocalEquippedBags[bagSlotName]
    if not bagData then return {} end
    
    return lib.callback.await('free_hoarder:getBagOutfits', false, bagData.containerId) or {}
end

---Delete an outfit from a bag
---@param bagSlotName string
---@param outfitIndex number
---@return boolean success
function DeleteOutfitFromBag(bagSlotName, outfitIndex)
    local bagData = LocalEquippedBags[bagSlotName]
    if not bagData then return false end
    
    local success = lib.callback.await('free_hoarder:deleteOutfitFromBag', false, bagData.containerId, outfitIndex)
    
    if success then
        Notify({ title = 'Outfit Deleted', type = 'success' })
    end
    
    return success
end

-------------------------------------------------------------------------------
-- OUTFIT MANAGEMENT UI
-------------------------------------------------------------------------------

---Open outfit management menu for a bag
---@param bagSlotName string
function OpenOutfitMenu(bagSlotName)
    if not outfitConfig or not outfitConfig.enabled then 
        Notify({ title = 'Error', description = 'Outfit system is disabled', type = 'error' })
        return 
    end
    
    local bagData = LocalEquippedBags[bagSlotName]
    if not bagData then 
        Notify({ title = 'Error', description = 'No bag found in this slot', type = 'error' })
        return 
    end
    
    local bagConfig = GetBagConfig(bagData.bagName)
    if not bagConfig then 
        Notify({ title = 'Error', description = 'Bag configuration not found', type = 'error' })
        return 
    end
    
    -- Check if bag type allows outfits
    if not outfitConfig.allowedBagTypes or not outfitConfig.allowedBagTypes[bagConfig.type] then
        Notify({ title = 'Error', description = 'This bag cannot store outfits', type = 'error' })
        return
    end
    
    DebugPrint('Opening outfit menu for', bagSlotName, 'containerId:', bagData.containerId)
    
    -- Get saved outfits
    local outfits = GetBagOutfits(bagSlotName)
    local canSaveMore = #outfits < outfitConfig.maxOutfitsPerBag
    
    -- Build menu options
    local options = {}
    
    -- Save current outfit option
    if canSaveMore then
        table.insert(options, {
            title = 'Save Current Outfit',
            description = ('Save what you\'re wearing (%d/%d slots)'):format(#outfits, outfitConfig.maxOutfitsPerBag),
            icon = 'plus',
            onSelect = function()
                local input = lib.inputDialog('Save Outfit', {
                    { type = 'input', label = 'Outfit Name', placeholder = 'My Outfit', required = true }
                })
                
                if input and input[1] then
                    SaveOutfitToBag(bagSlotName, input[1])
                end
            end
        })
    else
        table.insert(options, {
            title = 'Save Current Outfit',
            description = 'Bag is full - delete an outfit first',
            icon = 'plus',
            disabled = true
        })
    end
    
    -- Divider
    if #outfits > 0 then
        table.insert(options, {
            title = '─── Saved Outfits ───',
            disabled = true
        })
    end
    
    -- List saved outfits
    for i, outfit in ipairs(outfits) do
        table.insert(options, {
            title = outfit.name or ('Outfit %d'):format(i),
            description = outfit.savedAt and ('Saved: %s'):format(outfit.savedAt) or nil,
            icon = 'shirt',
            onSelect = function()
                lib.registerContext({
                    id = 'outfit_actions_' .. i,
                    title = outfit.name or ('Outfit %d'):format(i),
                    menu = 'outfit_management',
                    options = {
                        {
                            title = 'Wear This Outfit',
                            icon = 'person-running',
                            onSelect = function()
                                LoadOutfitFromBag(bagSlotName, i)
                            end
                        },
                        {
                            title = 'Delete Outfit',
                            icon = 'trash',
                            onSelect = function()
                                local confirm = lib.alertDialog({
                                    header = 'Delete Outfit?',
                                    content = ('Are you sure you want to delete "%s"?'):format(outfit.name),
                                    centered = true,
                                    cancel = true
                                })
                                if confirm == 'confirm' then
                                    DeleteOutfitFromBag(bagSlotName, i)
                                end
                            end
                        }
                    }
                })
                lib.showContext('outfit_actions_' .. i)
            end
        })
    end
    
    -- Show the menu
    lib.registerContext({
        id = 'outfit_management',
        title = ('%s - Outfits'):format(bagConfig.label),
        options = options
    })
    
    lib.showContext('outfit_management')
end

-- Register export immediately after function definition
exports('OpenOutfitMenu', OpenOutfitMenu)

-------------------------------------------------------------------------------
-- OTHER EXPORTS
-------------------------------------------------------------------------------

exports('UpdateBagVisibilityForClothing', UpdateBagVisibilityForClothing)
exports('SaveOutfitToBag', SaveOutfitToBag)
exports('LoadOutfitFromBag', LoadOutfitFromBag)

-------------------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------------------

CreateThread(function()
    Wait(2000) -- Wait for other systems to initialize
    
    if clothingConfig.enabled then
        UpdateBagVisibilityForClothing()
        DebugPrint('Clothing integration initialized')
    end
    
    if outfitConfig.enabled then
        DebugPrint('Outfit saving system initialized')
    end
end)
