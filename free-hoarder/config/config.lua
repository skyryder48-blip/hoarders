--[[
    Main Configuration for free-hoarder
    Adjust these settings to match your server's needs
]]

Config = Config or {}

-- Debug mode (enables verbose console output)
Config.Debug = true

-------------------------------------------------------------------------------
-- BASE INVENTORY SETTINGS
-- These MUST match your ox_inventory configuration
-------------------------------------------------------------------------------
Config.BaseWeight = 26500      -- Base max weight in grams (26.5kg)
Config.BaseSlots = 17          -- Base inventory slot count

-------------------------------------------------------------------------------
-- MOVEMENT REDUCTION SETTINGS
-- Weight-based speed penalties
-------------------------------------------------------------------------------
Config.Movement = {
    enabled = true,             -- Master toggle for movement reduction
    
    -- Base formula: 5% reduction per 5kg = 1% per kg (more noticeable)
    reductionPerKg = 0.01,      -- 1% reduction per kg over threshold
    
    -- Thresholds and caps per movement type
    -- startWeight: Weight (grams) where penalties begin
    -- maxReduction: Maximum speed reduction (0.30 = 30% slower, floor at 70% speed)
    thresholds = {
        walk = {
            startWeight = 15000,    -- Walking penalties start at 15kg
            maxReduction = 0.20     -- Floor at 80% speed (max 20% reduction)
        },
        run = {
            startWeight = 10000,    -- Running penalties start at 10kg  
            maxReduction = 0.30     -- Floor at 70% speed (max 30% reduction)
        },
        sprint = {
            startWeight = 5000,     -- Sprint penalties start at 5kg
            maxReduction = 0.40     -- Floor at 60% speed (max 40% reduction)
        }
    },
    
    -- Smooth speed transition rate (higher = faster transitions)
    transitionRate = 0.05,      -- Faster transitions for more responsive feel
    
    -- How often to recalculate speed when not encumbered (ms)
    idleCheckInterval = 500
}

-------------------------------------------------------------------------------
-- ANIMATION SETTINGS
-------------------------------------------------------------------------------
Config.Animations = {
    enabled = true,             -- Master toggle for equip/unequip animations
    
    -- Animation durations in milliseconds
    equipDuration = 1500,
    unequipDuration = 1200,
    
    -- Animation dictionaries and clips per bag type
    -- These can be overridden per-bag in bags.lua
    defaults = {
        backpack = {
            equip = { dict = 'clothingshirt', anim = 'try_shirt_positive_d', flag = 49 },
            unequip = { dict = 'clothingshirt', anim = 'try_shirt_negative_a', flag = 49 }
        },
        shoulderbag = {
            equip = { dict = 'missheistdockssetup1clipboard@base', anim = 'base', flag = 49 },
            unequip = { dict = 'missheistdockssetup1clipboard@base', anim = 'base', flag = 49 }
        },
        handbag = {
            equip = { dict = 'pickup_object', anim = 'pickup_low', flag = 48 },
            unequip = { dict = 'pickup_object', anim = 'putdown_low', flag = 48 }
        },
        twohand = {
            equip = { dict = 'anim@heists@box_carry@', anim = 'idle', flag = 49 },
            unequip = { dict = 'pickup_object', anim = 'putdown_low', flag = 48 }
        }
    }
}

-------------------------------------------------------------------------------
-- WEAPON RESTRICTION SETTINGS
-- Controls what happens when player tries to use weapons with bags equipped
-------------------------------------------------------------------------------
Config.WeaponRestrictions = {
    enabled = true,             -- Master toggle for weapon restrictions
    
    -- Restriction method:
    -- 'drop_to_ground' = Bag physically drops to ground as a pickup when restricted weapon drawn
    --                    Item is REMOVED from inventory, player must pick it up again
    --                    This is the RECOMMENDED method for realism
    -- 'block_weapon' = Weapon wheel completely blocked, cannot draw restricted weapons
    --                  Bag stays in inventory, player just can't use weapons
    method = 'drop_to_ground',
    
    -- What each bag type restricts:
    -- 'handbag' (clutch, briefcase, etc in LEFT/RIGHT_HAND):
    --     - Blocks TWO-HANDED weapons only (rifles, shotguns, SMGs, etc)
    --     - Allows pistols, melee, throwables
    -- 'twohand' (boxes, crates in TWO_HAND slot):
    --     - Blocks ALL weapons including melee
    --     - Player must drop item to use any weapon
    
    -- NOTE: Bags are ALWAYS equipped when in inventory
    -- There is no way to "hide" a bag - if it's in your inventory, it's visible
}

-------------------------------------------------------------------------------
-- KEYBIND SETTINGS
-------------------------------------------------------------------------------
Config.Keybinds = {
    -- Open bag management radial menu
    openRadial = {
        key = 'G',
        description = 'Open Bag Menu'
    },
    
    -- Cycle through available attachment slots for selected bag
    cycleSlot = {
        key = 'CAPSLOCK',
        description = 'Cycle Bag Slot'
    }
}

-------------------------------------------------------------------------------
-- UI SETTINGS
-------------------------------------------------------------------------------
Config.UI = {
    -- Radial menu settings
    radial = {
        enabled = true,          -- Use radial menu (false = context menu)
        id = 'hoarder_bags',
        icon = 'backpack'
    },
    
    -- Notification settings
    notifications = {
        enabled = true,
        position = 'top-right',
        duration = 3000
    }
}

-------------------------------------------------------------------------------
-- SECURITY SETTINGS
-------------------------------------------------------------------------------
Config.Security = {
    -- Cooldown between equip/unequip actions (ms)
    actionCooldown = 2000,
    
    -- Maximum bags a player can have equipped at once (safety limit)
    maxEquippedBags = 6,
    
    -- Validate capacity changes server-side
    validateCapacity = true
}

-------------------------------------------------------------------------------
-- DROP SETTINGS
-- Behavior when player removes bag and goes over capacity
-------------------------------------------------------------------------------
Config.Drops = {
    -- Items that should never be force-dropped
    essentialItems = {
        ['phone'] = true,
        ['id_card'] = true,
        ['driver_license'] = true,
        ['cash'] = true
    },
    
    -- Drop method: 'ground' or 'inventory' (return to bag)
    method = 'ground',
    
    -- Time before dropped items despawn (seconds)
    despawnTime = 300,
    
    -- Maximum items in a single drop
    maxDropSlots = 50
}

-------------------------------------------------------------------------------
-- OVER-CAPACITY HANDLING
-- How to handle when player exceeds capacity after bag removal
-------------------------------------------------------------------------------
Config.OverCapacity = {
    -- Method: 'prevent', 'forceDrop', 'penalty', or 'warn'
    -- 'prevent' = Block bag drop if it would cause over-capacity
    -- 'forceDrop' = Auto-drop excess items to ground
    -- 'penalty' = Apply severe movement/action penalties
    -- 'warn' = Just warn player, allow temporary over-capacity
    method = 'penalty',
    
    -- For 'forceDrop' method
    forceDrop = false,
    
    -- For 'penalty' method
    penalty = {
        speedMultiplier = 0.3,   -- 30% speed when over capacity
        blockSprint = true,      -- Cannot sprint
        blockJump = true,        -- Cannot jump
        blockVehicle = false,    -- Can still enter vehicles
        warningInterval = 30000  -- Warning notification every 30s
    },
    
    -- For 'prevent' method - block the action that would cause over-capacity
    preventDropping = false,
    preventTrading = false
}

-------------------------------------------------------------------------------
-- INTEGRATION SETTINGS
-- For compatibility with other scripts
-------------------------------------------------------------------------------
Config.Integration = {
    -- Future: free-holsters integration
    holstersScript = 'free-holsters',
    
    -- Disable weapon wheel when handbags equipped
    disableWeaponWheel = true,
    
    -- Allow melee weapons when handbags equipped
    allowMeleeWithHandbag = true
}

-------------------------------------------------------------------------------
-- CLOTHING INTEGRATION (illenium-appearance / fivem-appearance)
-- Hide bag props when conflicting clothing is worn
-------------------------------------------------------------------------------
Config.Clothing = {
    enabled = true,
    
    -- Appearance script to integrate with
    -- Options: 'illenium-appearance', 'fivem-appearance', 'esx_skin', 'qb-clothing'
    appearanceScript = 'illenium-appearance',
    
    -- GTA V Clothing Component IDs Reference:
    -- 0 = Head, 1 = Mask, 2 = Hair, 3 = Torso/Arms, 4 = Legs, 5 = Parachute/Bag,
    -- 6 = Shoes, 7 = Accessories, 8 = Undershirt, 9 = Body Armor,
    -- 10 = Decals, 11 = Tops/Jackets
    
    -- Configure which clothing components/drawables hide which bag slots
    -- Format: [slotName] = { [componentId] = { drawable IDs that conflict } }
    -- Use -1 to mean "all non-zero drawables"
    
    conflicts = {
        -- BACK slot - backpacks worn on back
        ['BACK'] = {
            -- Component 5 (Parachute/Bag slot) - EUP/clothing backpacks
            [5] = { -1 },  -- -1 means any drawable > 0 hides the prop
            -- Component 11 (Tops/Jackets) - specific bulky jackets
            -- [11] = { 45, 46, 47, 123 }, -- Example: specific jacket drawable IDs
        },
        
        -- FRONT slot - bags worn on chest
        ['FRONT'] = {
            -- Component 9 (Body Armor) - any armor hides front bags
            [9] = { -1 },
            -- Component 7 (Accessories) - tactical vests/plate carriers
            -- [7] = { 10, 11, 12 }, -- Example: specific vest drawable IDs
        },
        
        -- LEFT_SHOULDER slot - messenger bags, slings
        ['LEFT_SHOULDER'] = {
            [5] = { -1 },  -- Parachute/bag component conflicts
        },
        
        -- RIGHT_SHOULDER slot
        ['RIGHT_SHOULDER'] = {
            [5] = { -1 },
        },
        
        -- LEFT_HAND and RIGHT_HAND typically have no clothing conflicts
        ['LEFT_HAND'] = {},
        ['RIGHT_HAND'] = {},
    },
    
    -- Behavior when conflict detected
    -- 'hide' = Hide the bag prop (bag still equipped/functional, just invisible)
    -- 'notify' = Show notification that clothing conflicts
    -- 'both' = Hide prop AND notify player
    conflictBehavior = 'both',
    
    -- Notification settings
    hideMessage = 'Your %s is hidden by your clothing',
    showMessage = 'Your %s is now visible',
    
    -- Check interval (ms) - how often to check for clothing changes
    -- Lower = more responsive but more resource usage
    checkInterval = 1000,
}

-------------------------------------------------------------------------------
-- OUTFIT SAVING
-- Allow bags to store and restore player outfits
-------------------------------------------------------------------------------
Config.OutfitSaving = {
    enabled = true,
    
    -- Which bag types can save outfits (by BagType enum)
    allowedBagTypes = {
        ['backpack'] = true,
        ['shoulderbag'] = true,
        ['handbag'] = false,  -- Too small for clothes realistically
        ['twohand'] = false,  -- Carry items, not for outfits
        ['tucked'] = false,   -- Concealed items, not for outfits
    },
    
    -- Maximum outfits that can be saved per bag
    maxOutfitsPerBag = 3,
    
    -- What components to save with the outfit
    saveComponents = {
        clothing = true,    -- Components 0-11 (all clothing)
        props = true,       -- Props 0-8 (hats, glasses, watches, earrings, etc.)
        hair = false,       -- Hair style/color (component 2) - usually don't change
        overlays = false,   -- Face overlays/makeup - usually don't change
    },
    
    -- Specific components to exclude (even if category is enabled)
    excludeComponents = {
        -- [2] = true,  -- Example: exclude hair even if clothing=true
    },
    
    -- Animation when changing outfits
    changeAnimation = {
        enabled = true,
        dict = 'clothingspecs',
        anim = 'try_glasses_positive_a',
        duration = 3000,
    },
    
    -- UI settings
    ui = {
        showInRadial = true,       -- Add outfit options to bag radial menu
        allowNaming = true,        -- Let players name their outfits
        defaultNameFormat = 'Outfit %d',
        confirmDelete = true,      -- Require confirmation to delete outfits
    },
}

-------------------------------------------------------------------------------
-- DISCORD WEBHOOK LOGGING
-- Log events to Discord for admin monitoring
-------------------------------------------------------------------------------
Config.Discord = {
    enabled = false,  -- Set to true and add webhook URL to enable
    
    -- Your Discord webhook URL
    webhookUrl = 'YOUR_WEBHOOK_URL_HERE',
    
    -- What events to log
    logEquip = true,        -- Log when bags are equipped
    logUnequip = false,     -- Log when bags are unequipped (can be spammy)
    logDrop = true,         -- Log when bags are dropped to ground
    logSuspicious = true,   -- Log suspicious activity (exploit attempts)
    logAdmin = true,        -- Log admin command usage
    logDurability = true,   -- Log when bags break from wear
}

-------------------------------------------------------------------------------
-- SOUND EFFECTS
-- Audio feedback for bag interactions
-------------------------------------------------------------------------------
Config.Sounds = {
    enabled = true,
    
    -- Sound definitions
    -- native = true uses GTA sound, native = false requires external sound system
    sounds = {
        -- Equip sounds
        equip_backpack = { native = true, name = 'BACK_SMALL', set = 'HUD_MINI_GAME_SOUNDSET' },
        equip_shoulderbag = { native = true, name = 'BACK_SMALL', set = 'HUD_MINI_GAME_SOUNDSET' },
        equip_handbag = { native = true, name = 'PICK_UP', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        equip_twohand = { native = true, name = 'PICK_UP', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        equip_generic = { native = true, name = 'PICK_UP', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        
        -- Unequip sounds
        unequip_generic = { native = true, name = 'DROP_WEAPON', set = 'GTAO_MUGGER_SOUNDSET' },
        
        -- Drop sounds
        drop_backpack = { native = true, name = 'DROPPED', set = 'GTAO_MUGGER_SOUNDSET' },
        drop_twohand = { native = true, name = 'OOH', set = 'GTAO_MUGGER_SOUNDSET' },
        drop_generic = { native = true, name = 'DROPPED', set = 'GTAO_MUGGER_SOUNDSET' },
        
        -- Open/close sounds
        open_backpack = { native = true, name = 'NAV_UP_DOWN', set = 'HUD_FREEMODE_SOUNDSET' },
        close_backpack = { native = true, name = 'NAV_UP_DOWN', set = 'HUD_FREEMODE_SOUNDSET' },
        open_generic = { native = true, name = 'SELECT', set = 'HUD_FREEMODE_SOUNDSET' },
        close_generic = { native = true, name = 'BACK', set = 'HUD_FREEMODE_SOUNDSET' },
        
        -- Other sounds
        zipper = { native = true, name = 'NAV_UP_DOWN', set = 'HUD_FREEMODE_SOUNDSET' },
        rustle = { native = true, name = 'SELECT', set = 'HUD_FREEMODE_SOUNDSET' },
        throw = { native = true, name = 'MP_Flash', set = 'WastedSounds' },
        rummage = { native = true, name = 'CONTINUE', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        
        -- Break sounds
        break_handbag = { native = true, name = 'CRASH', set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
        break_generic = { native = true, name = 'CRASH', set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    }
}

-------------------------------------------------------------------------------
-- BAG DURABILITY SYSTEM
-- Bags degrade over time and use
-------------------------------------------------------------------------------
Config.Durability = {
    enabled = false,  -- Set to true to enable durability
    
    -- How much durability decreases per action
    decreasePerUse = 1,         -- Each time bag container is opened
    decreasePerDrop = 5,        -- Each time bag is dropped to ground
    decreasePerThrow = 10,      -- Each time bag is thrown
    
    -- Warning thresholds
    lowDurabilityWarning = 25,  -- Warn player when durability below this %
    
    -- What happens when durability hits 0
    -- 'break' = Bag is destroyed, contents drop to ground
    -- 'unusable' = Bag can't be opened until repaired
    -- 'penalty' = Bag capacity reduced by 50%
    zeroAction = 'unusable',
    
    -- Repair settings
    repairEnabled = true,
    repairCost = 500,           -- Base cost to repair
    repairLocations = {
        -- { coords = vector3(x, y, z), radius = 2.0, label = 'Clothing Store' }
    },
}

-------------------------------------------------------------------------------
-- QUICK DROP KEYBIND
-- Drop first occupied inventory slot (hold to dump entire inventory)
-------------------------------------------------------------------------------
Config.QuickDrop = {
    enabled = true,
    
    key = 'Y',                  -- Default keybind (can be rebound in GTA settings)
    description = 'Quick Drop Item',
    
    cooldown = 250,             -- ms between drops when holding key
    
    -- Drop behavior
    dropInFront = true,         -- Drop in front of player (false = at feet)
    dropDistance = 0.8,         -- How far in front to drop (meters)
}

-------------------------------------------------------------------------------
-- BAG THROWING
-- Throw/toss bags instead of just dropping
-------------------------------------------------------------------------------
Config.Throwing = {
    enabled = true,
    
    maxDistance = 8.0,          -- Maximum throw distance (meters)
    
    -- Which bag types can be thrown (others just drop)
    throwableBagTypes = {
        ['handbag'] = true,
        ['twohand'] = true,
        ['shoulderbag'] = true,
        ['backpack'] = false,   -- Heavy, can't throw
        ['tucked'] = false,     -- Concealed items, can't throw
    },
    
    -- Animation settings
    animation = {
        dict = 'anim@heists@ornate_bank@grab_cash',
        name = 'throw',
        duration = 500,
    },
}

-------------------------------------------------------------------------------
-- VEHICLE ENTRY BEHAVIOR
-- What happens to two-hand items when entering vehicles
-------------------------------------------------------------------------------
Config.VehicleEntry = {
    enabled = true,
    
    -- Auto-drop two-hand carry items when entering vehicle
    dropTwoHandOnEntry = true,
    
    -- Notify player when item is dropped
    notifyOnDrop = true,
    notifyMessage = 'You put down what you were carrying to enter the vehicle',
}

-------------------------------------------------------------------------------
-- NOTIFICATIONS
-- Control which notifications are shown
-------------------------------------------------------------------------------
Config.Notifications = {
    -- Bag lifecycle
    onEquip = true,             -- "Backpack equipped"
    onUnequip = true,           -- "Backpack removed"
    onDrop = true,              -- "You dropped your bag"
    onCapacityChange = false,   -- "+15kg capacity" (can be spammy)
    
    -- Weapon restrictions
    onWeaponBlock = true,       -- "Cannot use weapons while carrying"
    
    -- Durability (v2.0)
    onDurabilityLow = true,     -- "Your bag is wearing out" (at 25%, 10%, 5%)
    onDurabilityBreak = true,   -- "Your bag has broken"
    onDurabilityRepaired = true, -- "Your bag has been repaired"
    
    -- Locking (v2.0)
    onBagLocked = true,         -- "Bag has been locked"
    onBagUnlocked = true,       -- "Bag has been unlocked"
    onWrongPIN = true,          -- "Wrong PIN"
    onLockBypassed = true,      -- "Lock has been bypassed"
    
    -- Search/Frisk (v2.0)
    onSearched = true,          -- "You are being searched"
    onBagTaken = true,          -- "Your bag was taken"
    
    -- Job restrictions
    onJobRestriction = true,    -- "You cannot use this bag"
}

-------------------------------------------------------------------------------
-- CAPACITY VALIDATION
-- Server-side validation to prevent exploits
-------------------------------------------------------------------------------
Config.CapacityValidation = {
    enabled = true,
    
    -- Log validation failures
    logFailures = true,
    
    -- Kick player on repeated violations
    kickOnViolation = false,
    violationThreshold = 5,     -- Violations before kick
}

-------------------------------------------------------------------------------
-- BAG LOCKING SYSTEM (v2.0)
-- Configure lock types, bypass items, and success rates
-------------------------------------------------------------------------------
Config.Locking = {
    enabled = true,
    
    -- PIN Lock settings
    pin = {
        digits = 4,                    -- PIN length (4 digits)
        maxAttempts = 3,               -- Attempts before lockout
        lockoutTime = 60,              -- Lockout duration in seconds
        bypassItems = {                -- ALL items required to bypass (hacking)
            'hacking_device',
            'laptop'
        },
        bypassTime = 15000,            -- Time to bypass in ms
        bypassSuccessRate = 85,        -- % chance of success
    },
    
    -- Key Lock settings
    key = {
        keyItem = 'hoarder_bag_key',   -- Item name for keys
        bypassItems = {                -- ANY of these can bypass (lockpicking)
            { item = 'lockpick', chance = 60, breakChance = 30 },
            { item = 'screwdriver', chance = 40, breakChance = 10 },
            { item = 'crowbar', chance = 70, breakChance = 5 },
            { item = 'hammer', chance = 50, breakChance = 20 },
            { item = 'knife', chance = 30, breakChance = 15 },
        },
        bypassTime = 8000,             -- Time to pick in ms
    },
    
    -- Padlock settings (add-on item, same bypass as key)
    padlock = {
        padlockItem = 'padlock',           -- Item consumed to add lock
        keyItem = 'hoarder_padlock_key',   -- Key item created for padlocks
        bypassItems = {                    -- Same as key lock
            { item = 'lockpick', chance = 60, breakChance = 30 },
            { item = 'screwdriver', chance = 40, breakChance = 10 },
            { item = 'crowbar', chance = 70, breakChance = 5 },
            { item = 'hammer', chance = 50, breakChance = 20 },
            { item = 'knife', chance = 30, breakChance = 15 },
        },
        bypassTime = 10000,            -- Time to pick in ms
    },
    
    -- Biometric Lock settings (most secure)
    biometric = {
        bypassItems = {                -- ALL items required to bypass
            'advanced_hacking_device',
            'laptop'
        },
        bypassTime = 25000,            -- Time to bypass in ms (longest)
        bypassSuccessRate = 50,        -- Lower success rate (more secure)
    },
    
    -- General settings
    notifyOwnerOnBypass = true,        -- Notify bag owner when their lock is bypassed
    logToDiscord = true,               -- Log lock/bypass events to Discord
}

-------------------------------------------------------------------------------
-- BAG DURABILITY SYSTEM (v2.0)
-- Bags degrade over use and can break
-------------------------------------------------------------------------------
Config.Durability = {
    enabled = true,
    
    -- Default degradation when not specified per-bag
    defaultDegradePerOpen = 2,         -- Lose 2% durability each time bag is opened
    
    -- Repair settings
    repairTime = 5000,                 -- Time to repair in ms
    requireStation = false,            -- Require player to be at repair station
    
    -- Jobs allowed to repair bags
    repairJobs = {
        'tailor',
        'clothingstore',
    },
    
    -- Repair stations (optional - only if requireStation = true)
    repairStations = {
        -- { coords = vec3(x, y, z), radius = 2.0, label = 'Tailor Shop' },
    },
    
    -- Repair recipes by material type
    -- Each bag can specify a 'material' property to use different recipes
    repairRecipes = {
        default = {
            { name = 'fabric', count = 2 },
            { name = 'sewing_kit', count = 1 },
        },
        leather = {
            { name = 'leather', count = 2 },
            { name = 'sewing_kit', count = 1 },
        },
        nylon = {
            { name = 'fabric', count = 3 },
            { name = 'thread', count = 2 },
        },
        plastic = {
            { name = 'plastic', count = 2 },
            { name = 'duct_tape', count = 1 },
        },
        metal = {
            { name = 'metalscrap', count = 2 },
            { name = 'screwdriver', count = 1 },
        },
    },
    
    -- Discord logging
    logToDiscord = true,
}

-------------------------------------------------------------------------------
-- PLAYER SEARCH/FRISK SYSTEM (v2.0)
-- Search and take bags from restrained players
-------------------------------------------------------------------------------
Config.Search = {
    enabled = true,
    
    -- Distance settings
    searchDistance = 2.5,              -- Max distance to search bags
    takeDistance = 2.0,                -- Max distance to take bags
    
    -- Timing
    takeDuration = 3000,               -- Time to take a bag (ms)
    
    -- Lock handling
    allowForceOpen = true,             -- Allow breaking locks (destroys the lock)
    
    -- Notifications
    notifyTarget = true,               -- Notify target when being searched
    notifyOnBypass = true,             -- Notify target when lock is bypassed
    
    -- Restraint detection
    -- These are the state bag keys and metadata checks used
    -- Most police scripts use these standard names
    restraintChecks = {
        metadata = { 'ishandcuffed' },              -- QBX Core metadata
        stateBags = { 'ishandcuffed', 'isCuffed', 'handcuffed', 'handsUp', 'handsup', 'isHandsUp' }
    },
    
    -- Job restrictions (optional)
    -- Set to nil or empty table to allow anyone to search
    -- Set to job names to restrict searching to certain jobs
    allowedJobs = nil,  -- Example: { 'police', 'sheriff', 'bcso' }
    
    -- Discord logging
    logToDiscord = true,
}

-------------------------------------------------------------------------------
-- STAMINA SYSTEM (v2.0)
-- Drain stamina faster when carrying heavy loads
-------------------------------------------------------------------------------
Config.Stamina = {
    enabled = true,
    
    -- Capacity thresholds and drain multipliers
    -- At each threshold, stamina drains X times faster than normal
    thresholds = {
        { capacity = 55, drain = 1.5 },   -- At 55% capacity: 1.5x drain
        { capacity = 80, drain = 2.5 },   -- At 80% capacity: 2.5x drain
        { capacity = 95, drain = 4.0 },   -- At 95% capacity: 4x drain
    },
    
    -- Notify player when crossing thresholds
    notifyOnThreshold = true,
    
    -- Show visual indicator when drain is active
    showIndicator = false,
}

-------------------------------------------------------------------------------
-- SWIMMING AUTO-DROP (v2.0)
-- Automatically drop two-hand items when entering water
-------------------------------------------------------------------------------
Config.Swimming = {
    enabled = true,
    
    -- Water depth at which items are dropped (0.0 to 1.0)
    -- 0.5 = waist deep, 1.0 = fully submerged
    dropDepthThreshold = 0.5,
    
    -- Delay before dropping (ms) - prevents accidental drops from splashes
    dropDelay = 500,
    
    -- Warn player when entering water with carryable item
    warnBeforeDrop = true,
    
    -- Which bag types are affected (two-hand is always affected)
    -- Set to true to also drop bags from hands
    dropHandBags = false,
}

-------------------------------------------------------------------------------
-- BAG OPENING ANIMATIONS (v2.0)
-- Play animations when opening bags
-------------------------------------------------------------------------------
Config.OpenAnimations = {
    enabled = true,
    
    -- Also play a (shorter) animation when closing bags
    playOnClose = true,
    
    -- Skip animations for certain bag types (fast access)
    skipForTypes = {
        -- BagType.TUCKED,  -- Uncomment to skip for wallets/mag holders
    },
    
    -- Cancel triggers (animation cancels if any of these happen)
    -- Built-in: ESC key, ragdoll, death, entering water, entering vehicle
    
    -- Animation presets by bag type
    -- These can be overridden per-bag in Config.Bags[bagName].openAnimation
    typeDefaults = {
        backpack = {
            dict = 'anim@heists@ornate_bank@grab_cash',
            clip = 'grab',
            duration = 1500,
            blockMovement = false,
            upperBodyOnly = false,
        },
        shoulderbag = {
            dict = 'anim@heists@ornate_bank@grab_cash',
            clip = 'grab',
            duration = 1200,
            blockMovement = false,
            upperBodyOnly = true,
        },
        handbag = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped',
            duration = 1000,
            blockMovement = false,
            upperBodyOnly = true,
        },
        twohand = {
            dict = 'anim@heists@box_carry@',
            clip = 'idle',
            duration = 2000,
            blockMovement = true,
            upperBodyOnly = false,
        },
        tucked = {
            dict = 'mp_common',
            clip = 'givetake1_a',
            duration = 800,
            blockMovement = false,
            upperBodyOnly = true,
        },
    },
}

-------------------------------------------------------------------------------
-- CRAFTING CONFIGURATION
-- Recipes for crafting bags (export for external crafting resources)
-------------------------------------------------------------------------------

Config.Crafting = {
    enabled = true,
    logToDiscord = true,
}

Config.CraftingRecipes = {
    -- BACKPACKS
    ['hoarder_backpack_sm'] = {
        { name = 'fabric', count = 3 },
        { name = 'thread', count = 2 },
    },
    ['hoarder_backpack_md'] = {
        { name = 'fabric', count = 5 },
        { name = 'leather', count = 2 },
        { name = 'thread', count = 3 },
    },
    ['hoarder_backpack_lg'] = {
        { name = 'fabric', count = 8 },
        { name = 'leather', count = 4 },
        { name = 'thread', count = 5 },
        { name = 'metalscrap', count = 2 },
    },
    
    -- SHOULDER BAGS
    ['hoarder_shoulder_purse'] = {
        { name = 'leather', count = 3 },
        { name = 'thread', count = 2 },
    },
    ['hoarder_shoulder_messenger'] = {
        { name = 'fabric', count = 4 },
        { name = 'leather', count = 2 },
        { name = 'thread', count = 2 },
    },
    ['hoarder_shoulder_duffle'] = {
        { name = 'fabric', count = 6 },
        { name = 'thread', count = 4 },
        { name = 'metalscrap', count = 1 },
    },
    
    -- HANDBAGS
    ['hoarder_hand_clutch'] = {
        { name = 'leather', count = 2 },
        { name = 'thread', count = 1 },
    },
    ['hoarder_hand_briefcase'] = {
        { name = 'leather', count = 4 },
        { name = 'metalscrap', count = 2 },
        { name = 'thread', count = 2 },
    },
    ['hoarder_hand_riflecase'] = {
        { name = 'plastic', count = 4 },
        { name = 'metalscrap', count = 3 },
        { name = 'sewing_kit', count = 1 },
    },
    
    -- TWO-HAND CARRY
    ['hoarder_carry_box_sm'] = {
        { name = 'cardboard', count = 2 },
    },
    ['hoarder_carry_box_md'] = {
        { name = 'cardboard', count = 4 },
        { name = 'duct_tape', count = 1 },
    },
    ['hoarder_carry_box_lg'] = {
        { name = 'cardboard', count = 6 },
        { name = 'duct_tape', count = 2 },
    },
    ['hoarder_carry_crate'] = {
        { name = 'wood', count = 8 },
        { name = 'metalscrap', count = 2 },
    },
    ['hoarder_carry_cooler'] = {
        { name = 'plastic', count = 5 },
        { name = 'metalscrap', count = 2 },
    },
    ['hoarder_carry_toolbox'] = {
        { name = 'metalscrap', count = 6 },
        { name = 'plastic', count = 2 },
    },
    
    -- TUCKED (CONCEALED)
    ['hoarder_wallet'] = {
        { name = 'leather', count = 1 },
    },
    ['hoarder_mag_holder'] = {
        { name = 'leather', count = 2 },
        { name = 'thread', count = 1 },
    },
}

-------------------------------------------------------------------------------
-- REPAIR RECIPES BY MATERIAL TYPE
-------------------------------------------------------------------------------

Config.RepairRecipes = {
    default = {
        { name = 'fabric', count = 2 },
        { name = 'sewing_kit', count = 1 },
    },
    leather = {
        { name = 'leather', count = 2 },
        { name = 'sewing_kit', count = 1 },
    },
    nylon = {
        { name = 'fabric', count = 3 },
        { name = 'thread', count = 2 },
    },
    plastic = {
        { name = 'plastic', count = 2 },
        { name = 'duct_tape', count = 1 },
    },
    metal = {
        { name = 'metalscrap', count = 2 },
        { name = 'duct_tape', count = 1 },
    },
    cardboard = {
        { name = 'cardboard', count = 2 },
        { name = 'duct_tape', count = 1 },
    },
    wood = {
        { name = 'wood', count = 3 },
        { name = 'metalscrap', count = 1 },
    },
}

-------------------------------------------------------------------------------
-- UPGRADE RECIPES (Optional - upgrade smaller bags to larger)
-------------------------------------------------------------------------------

Config.UpgradeRecipes = {
    ['hoarder_backpack_sm_to_md'] = {
        input = 'hoarder_backpack_sm',
        output = 'hoarder_backpack_md',
        materials = {
            { name = 'fabric', count = 3 },
            { name = 'leather', count = 2 },
            { name = 'thread', count = 2 },
        },
    },
    ['hoarder_backpack_md_to_lg'] = {
        input = 'hoarder_backpack_md',
        output = 'hoarder_backpack_lg',
        materials = {
            { name = 'fabric', count = 4 },
            { name = 'leather', count = 3 },
            { name = 'thread', count = 3 },
            { name = 'metalscrap', count = 2 },
        },
    },
    ['hoarder_carry_box_sm_to_md'] = {
        input = 'hoarder_carry_box_sm',
        output = 'hoarder_carry_box_md',
        materials = {
            { name = 'cardboard', count = 3 },
            { name = 'duct_tape', count = 1 },
        },
    },
}

-------------------------------------------------------------------------------
-- LOCK TYPE DEFINITIONS
-------------------------------------------------------------------------------

---@enum LockType
LockType = {
    NONE = 'none',
    PIN = 'pin',
    KEY = 'key',
    PADLOCK = 'padlock',
    BIOMETRIC = 'biometric'
}

---Check if a lock type is valid
---@param lockType string
---@return boolean
function IsValidLockType(lockType)
    return lockType == LockType.PIN 
        or lockType == LockType.KEY 
        or lockType == LockType.PADLOCK 
        or lockType == LockType.BIOMETRIC
end

---Get lock type display name
---@param lockType string
---@return string
function GetLockTypeName(lockType)
    local names = {
        [LockType.NONE] = 'None',
        [LockType.PIN] = 'PIN Code',
        [LockType.KEY] = 'Key Lock',
        [LockType.PADLOCK] = 'Padlock',
        [LockType.BIOMETRIC] = 'Biometric',
    }
    return names[lockType] or 'Unknown'
end

---Get lock type icon (FontAwesome)
---@param lockType string
---@return string
function GetLockTypeIcon(lockType)
    local icons = {
        [LockType.NONE] = 'lock-open',
        [LockType.PIN] = 'keyboard',
        [LockType.KEY] = 'key',
        [LockType.PADLOCK] = 'lock',
        [LockType.BIOMETRIC] = 'fingerprint',
    }
    return icons[lockType] or 'lock'
end

---Generate a unique key ID
---@return string
function GenerateKeyId()
    local chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    local id = 'key_'
    for i = 1, 12 do
        local idx = math.random(1, #chars)
        id = id .. chars:sub(idx, idx)
    end
    return id
end

---Generate a unique padlock ID
---@return string
function GeneratePadlockId()
    local chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    local id = 'padlock_'
    for i = 1, 8 do
        local idx = math.random(1, #chars)
        id = id .. chars:sub(idx, idx)
    end
    return id
end

-------------------------------------------------------------------------------
-- SERVER-SIDE LOCK HELPERS (only available on server)
-------------------------------------------------------------------------------

if IsDuplicityVersion() then
    ---Check if player has all required bypass items
    ---@param source number Player server ID
    ---@param items table Array of item names required
    ---@return boolean hasAll
    ---@return string|nil missingItem First missing item name
    function HasAllBypassItems(source, items)
        for _, itemName in ipairs(items) do
            local count = exports.ox_inventory:GetItemCount(source, itemName)
            if not count or count < 1 then
                return false, itemName
            end
        end
        return true, nil
    end

    ---Check if player has any of the bypass items (for key/padlock)
    ---@param source number Player server ID
    ---@param items table Array of {item, chance, breakChance}
    ---@return table|nil bestItem The bypass item data with highest chance player has
    function GetBestBypassItem(source, items)
        local bestItem = nil
        local bestChance = 0
        
        for _, itemData in ipairs(items) do
            local count = exports.ox_inventory:GetItemCount(source, itemData.item)
            if count and count >= 1 then
                if itemData.chance > bestChance then
                    bestChance = itemData.chance
                    bestItem = itemData
                end
            end
        end
        
        return bestItem
    end
end

