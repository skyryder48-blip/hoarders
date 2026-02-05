--[[
    Item Restrictions for free-hoarder
    
    Defines which items can/cannot go into specific bag types.
    
    RESTRICTION MODES:
    - blacklist: Listed items CANNOT go in this bag type
    - whitelist: ONLY listed items can go in this bag type
    
    If a bag type has no restrictions defined, all items are allowed.
    
    WEAPON RULES (hardcoded in validation):
    - Sniper rifles: ONLY allowed in bags with allowsSnipers = true (rifle case)
    - Long guns: ONLY allowed in bags with allowsLongGuns = true (large backpack, duffle, rifle case)
]]

Config = Config or {}

-------------------------------------------------------------------------------
-- GLOBAL BLACKLIST
-- Items that can NEVER go in ANY bag, regardless of bag type
-------------------------------------------------------------------------------
Config.GlobalBlacklist = {
    -- Heavy/Military weapons - too large for any bag
    'weapon_rpg',
    'weapon_minigun',
    'weapon_firework',
    'weapon_railgun',
    'weapon_grenadelauncher',
    'weapon_grenadelauncher_smoke',
    'weapon_hominglauncher',
    'weapon_compactlauncher',
    'weapon_rayminigun',
    'weapon_raypistol',     -- Alien weapons might be restricted
    'weapon_raycarbine',
    
    -- Other restricted items (customize as needed)
    -- 'parachute',  -- Uncomment if parachutes shouldn't go in bags
}

Config.Restrictions = {
    -------------------------------------------------------------------------------
    -- BACKPACK RESTRICTIONS
    -------------------------------------------------------------------------------
    [BagType.BACKPACK] = {
        -- Items that cannot go in backpacks
        blacklist = {
            -- Oversized items
            'weapon_rpg',
            'weapon_minigun',
            'weapon_firework',
            'weapon_railgun',
            'weapon_grenadelauncher',
            'weapon_grenadelauncher_smoke',
            'weapon_hominglauncher',
            
            -- Vehicle-related (too bulky)
            'lockpick_advanced',    -- Example: adjust to your items
        },
        
        -- If whitelist is defined, ONLY these items allowed (nil = allow all except blacklist)
        whitelist = nil
    },
    
    -------------------------------------------------------------------------------
    -- SHOULDERBAG RESTRICTIONS
    -------------------------------------------------------------------------------
    [BagType.SHOULDERBAG] = {
        blacklist = {
            -- Heavy weapons
            'weapon_rpg',
            'weapon_minigun',
            'weapon_firework',
            'weapon_railgun',
            'weapon_grenadelauncher',
            'weapon_grenadelauncher_smoke',
            'weapon_hominglauncher',
            
            -- Large items
            'parachute',
        },
        whitelist = nil
    },
    
    -------------------------------------------------------------------------------
    -- HANDBAG RESTRICTIONS
    -- Generally more restrictive due to smaller size
    -------------------------------------------------------------------------------
    [BagType.HANDBAG] = {
        blacklist = {
            -- All heavy weapons
            'weapon_rpg',
            'weapon_minigun',
            'weapon_firework',
            'weapon_railgun',
            'weapon_grenadelauncher',
            'weapon_grenadelauncher_smoke',
            'weapon_hominglauncher',
            
            -- Large items
            'parachute',
            
            -- Bulky items (adjust to your server)
            'armor',
            'heavyarmor',
        },
        whitelist = nil
    },
    
    -------------------------------------------------------------------------------
    -- RIFLE CASE SPECIFIC WHITELIST
    -- Override for specific bags - rifle case has special rules
    -------------------------------------------------------------------------------
    ['hoarder_hand_riflecase'] = {
        -- Rifle case can ONLY hold weapons and ammo
        whitelist = {
            -- Rifles
            'weapon_assaultrifle',
            'weapon_assaultrifle_mk2',
            'weapon_carbinerifle',
            'weapon_carbinerifle_mk2',
            'weapon_advancedrifle',
            'weapon_specialcarbine',
            'weapon_specialcarbine_mk2',
            'weapon_bullpuprifle',
            'weapon_bullpuprifle_mk2',
            'weapon_compactrifle',
            'weapon_militaryrifle',
            'weapon_heavyrifle',
            'weapon_tacticalrifle',
            
            -- Shotguns
            'weapon_pumpshotgun',
            'weapon_pumpshotgun_mk2',
            'weapon_sawnoffshotgun',
            'weapon_assaultshotgun',
            'weapon_bullpupshotgun',
            'weapon_musket',
            'weapon_heavyshotgun',
            'weapon_dbshotgun',
            'weapon_autoshotgun',
            'weapon_combatshotgun',
            
            -- Sniper rifles
            'weapon_sniperrifle',
            'weapon_heavysniper',
            'weapon_heavysniper_mk2',
            'weapon_marksmanrifle',
            'weapon_marksmanrifle_mk2',
            'weapon_precisionrifle',
            
            -- Ammo types (adjust to your ox_inventory items)
            'ammo_rifle',
            'ammo_shotgun',
            'ammo_sniper',
            'rifle_ammo',
            'shotgun_ammo',
            'sniper_ammo',
            
            -- Weapon attachments
            'weapon_suppressor',
            'weapon_flashlight',
            'weapon_scope',
            'weapon_grip',
            'extended_clip',
            'drum_magazine',
        },
        blacklist = nil  -- Whitelist takes precedence
    }
}

-------------------------------------------------------------------------------
-- RESTRICTION HELPER FUNCTIONS
-------------------------------------------------------------------------------

---Check if an item is blacklisted for a bag type
---@param itemName string
---@param bagType string
---@param specificBag string|nil Specific bag item name for overrides
---@return boolean
function IsItemBlacklisted(itemName, bagType, specificBag)
    -- Normalize item name to lowercase for comparison
    local normalizedItem = string.lower(itemName)
    
    -- Check specific bag override first
    if specificBag and Config.Restrictions[specificBag] then
        local override = Config.Restrictions[specificBag]
        if override.blacklist then
            for _, blocked in ipairs(override.blacklist) do
                if normalizedItem == string.lower(blocked) then
                    return true
                end
            end
        end
    end
    
    -- Check bag type restrictions
    local typeRestrictions = Config.Restrictions[bagType]
    if typeRestrictions and typeRestrictions.blacklist then
        for _, blocked in ipairs(typeRestrictions.blacklist) do
            if normalizedItem == string.lower(blocked) then
                return true
            end
        end
    end
    
    return false
end

---Check if an item is whitelisted for a bag (if whitelist exists)
---@param itemName string
---@param bagType string
---@param specificBag string|nil Specific bag item name for overrides
---@return boolean|nil Returns nil if no whitelist exists (all allowed)
function IsItemWhitelisted(itemName, bagType, specificBag)
    -- Check specific bag override first
    if specificBag and Config.Restrictions[specificBag] then
        local override = Config.Restrictions[specificBag]
        if override.whitelist then
            for _, allowed in ipairs(override.whitelist) do
                if itemName == allowed then
                    return true
                end
            end
            return false  -- Whitelist exists but item not in it
        end
    end
    
    -- Check bag type restrictions
    local typeRestrictions = Config.Restrictions[bagType]
    if typeRestrictions and typeRestrictions.whitelist then
        for _, allowed in ipairs(typeRestrictions.whitelist) do
            if itemName == allowed then
                return true
            end
        end
        return false  -- Whitelist exists but item not in it
    end
    
    return nil  -- No whitelist, item allowed (unless blacklisted)
end

---Full validation check for an item in a bag
---@param itemName string
---@param bagConfig table The bag's configuration from Config.Bags
---@return boolean allowed
---@return string|nil reason
function ValidateItemForBag(itemName, bagConfig)
    local bagType = bagConfig.type
    local bagName = nil
    
    -- Find the bag name from config
    for name, config in pairs(Config.Bags) do
        if config == bagConfig then
            bagName = name
            break
        end
    end
    
    print('[free-hoarder] ValidateItemForBag - Item:', itemName, 'BagType:', bagType, 'BagName:', bagName or 'unknown')
    
    -- Normalize item name for comparison
    local normalizedItem = string.lower(itemName)
    
    -- CHECK BAG-SPECIFIC ALLOWED ITEMS FIRST (whitelist mode)
    -- If allowedItems is defined, ONLY those items can go in this bag
    if bagConfig.allowedItems then
        local isAllowed = false
        for _, allowedItem in ipairs(bagConfig.allowedItems) do
            if normalizedItem == string.lower(allowedItem) then
                isAllowed = true
                break
            end
        end
        
        if not isAllowed then
            print('[free-hoarder] Item not in allowedItems whitelist:', itemName)
            return false, 'This item cannot be stored in this container'
        end
        
        -- Item is in whitelist, allow it (skip other checks)
        print('[free-hoarder] Item is in allowedItems whitelist:', itemName)
        return true, nil
    end
    
    -- CHECK GLOBAL BLACKLIST FIRST (items that can't go in ANY bag)
    if Config.GlobalBlacklist then
        for _, blocked in ipairs(Config.GlobalBlacklist) do
            if normalizedItem == string.lower(blocked) then
                print('[free-hoarder] Item is GLOBALLY BLACKLISTED:', itemName)
                return false, 'This item is too large for any bag'
            end
        end
    end
    
    -- Check weapon-specific rules using hash
    local itemHash = GetHashKey(itemName)
    
    -- Sniper check (only allowed in bags with allowsSnipers)
    if IsSniper(itemHash) then
        print('[free-hoarder] Item is a sniper rifle, allowsSnipers:', tostring(bagConfig.allowsSnipers))
        if not bagConfig.allowsSnipers then
            return false, 'Sniper rifles require a rifle case'
        end
    end
    
    -- Long gun check (only allowed in bags with allowsLongGuns)
    if IsLongGun(itemHash) then
        print('[free-hoarder] Item is a long gun, allowsLongGuns:', tostring(bagConfig.allowsLongGuns))
        if not bagConfig.allowsLongGuns then
            return false, 'Long guns require a large backpack, duffle bag, or rifle case'
        end
    end
    
    -- Check whitelist first (takes precedence)
    local whitelisted = IsItemWhitelisted(itemName, bagType, bagName)
    print('[free-hoarder] Whitelist check result:', tostring(whitelisted))
    if whitelisted == false then
        return false, 'This item is not allowed in this bag'
    end
    
    -- Check blacklist
    local blacklisted = IsItemBlacklisted(itemName, bagType, bagName)
    print('[free-hoarder] Blacklist check result:', tostring(blacklisted))
    if blacklisted then
        return false, 'This item cannot be stored in this bag'
    end
    
    return true, nil
end
