--[[
    ███████╗██████╗ ███████╗███████╗    ██╗  ██╗ ██████╗  █████╗ ██████╗ ██████╗ ███████╗██████╗
    ██╔════╝██╔══██╗██╔════╝██╔════╝    ██║  ██║██╔═══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
    █████╗  ██████╔╝█████╗  █████╗█████╗███████║██║   ██║███████║██████╔╝██║  ██║█████╗  ██████╔╝
    ██╔══╝  ██╔══██╗██╔══╝  ██╔══╝╚════╝██╔══██║██║   ██║██╔══██║██╔══██╗██║  ██║██╔══╝  ██╔══██╗
    ██║     ██║  ██║███████╗███████╗    ██║  ██║╚██████╔╝██║  ██║██║  ██║██████╔╝███████╗██║  ██║
    ╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝

    Weight-Based Movement & Multi-Bag System for QBox
    Version: 2.0.0
    Author: Free Scripts
    
    Features:
    - Event-driven architecture using OneSync state bags
    - Cross-client bag visibility synchronization
    - Reactive weight/capacity updates via ox_inventory hooks
    - Bag locking (PIN, key, padlock, biometric)
    - Durability system with repair stations
    - Player search/frisk integration
    - Stamina drain integration
    - Per-bag opening animations
    - Color variants
    - Comprehensive exports and events for external resources
    
    Dependencies: ox_lib, ox_inventory, qbx_core
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'free-hoarder'
author 'Free Scripts'
description 'Weight-based movement reduction and multi-bag carry system with OneSync state bags'
version '2.0.0'

-- Dependencies
dependencies {
    'ox_lib',
    'ox_inventory',
    'qbx_core'
}

-- Shared files (loaded first, order matters)
shared_scripts {
    '@ox_lib/init.lua',
    'shared/utils.lua',           -- Enums, helpers, notifications, events (consolidated)
    'config/config.lua',          -- Main config (includes lock types, crafting recipes)
    'config/bags.lua',            -- Bag definitions (includes variants)
    'config/restrictions.lua'
}

-- Client scripts (order matters - statebags before movement for reactive handlers)
client_scripts {
    'client/main.lua',
    'client/props.lua',
    'client/animations.lua',     -- Animations + Sounds (consolidated)
    'client/statebags.lua',      -- State bag handlers (reactive updates)
    'client/movement.lua',       -- Movement (triggered by state bags)
    'client/weapons.lua',
    'client/clothing.lua',       -- Clothing/outfit system
    'client/locking.lua',        -- v2.0: Bag locking client UI
    'client/durability.lua',     -- v2.0: Bag durability client UI
    'client/search.lua',         -- v2.0: Search/frisk + player state detection
    'client/physical.lua',       -- v2.0: Stamina + Swimming (consolidated)
    'client/openanimations.lua', -- v2.0: Bag opening animations
    'client/ui.lua',             -- UI menus + quickdrop + throwing (consolidated)
    'client/exports.lua',        -- v2.0: Centralized exports
    'client/debug.lua'           -- v2.0: Debug overlay and logging
}

-- Server scripts
server_scripts {
    'server/inventory.lua',
    'server/statebags.lua',      -- State bag sync & ox_inventory hooks
    'server/main.lua',
    'server/hooks.lua',
    'server/drops.lua',
    'server/discord.lua',        -- Discord webhook logging
    'server/admin.lua',          -- Admin commands
    'server/validation.lua',     -- Server-side validation & callbacks
    'server/locking.lua',        -- v2.0: Bag locking server logic
    'server/durability.lua',     -- v2.0: Bag durability server logic
    'server/search.lua',         -- v2.0: Search/frisk server logic
    'server/crafting.lua',       -- v2.0: Crafting/variant exports
    'server/exports.lua'         -- v2.0: Centralized exports
}

-- Stream custom prop models
files {
    'stream/*.ydr',
    'stream/*.ytd',
    'stream/**/*.ydr',
    'stream/**/*.ytd'
}

-- Provide client exports
exports {
    -- Existing exports
    'IsWeaponRestricted',
    'GetEquippedBags',
    'GetTotalBonusCapacity',
    'UpdateBagVisibilityForClothing',
    'SaveOutfitToBag',
    'LoadOutfitFromBag',
    'OpenOutfitMenu',
    'IsBagHiddenByClothing',
    'ValidateAllBagProps',
    'CheckClothingConflicts',
    'GetCurrentWeight',
    'GetCurrentMaxWeight',
    'IsOverCapacity',
    'GetPropHandle',
    'HidePropBySlot',
    'ShowPropBySlot',
    'IsTwoHandCarryActive',
    
    -- v2.0 exports
    'HasAnyBagEquipped',
    'HasBagType',
    'GetBagInSlot',
    'GetEquippedBagCount',
    'GetTotalCapacity',
    'GetCapacityPercentage',
    'AreWeaponsRestricted',
    'IsWeaponAllowed',
    'IsBagLocked',
    'GetBagLockType',
    'GetBagDurability',
    'IsBagAboutToBreak',
    'GetBagConfig',
    'IsBagItem',
    'ToggleDebug'
}

-- Provide server exports
server_exports {
    -- Existing exports
    'GetPlayerEquippedBags',
    'GetPlayerBonusCapacity',
    'ForceUnequipBag',
    'useBag',
    
    -- v2.0 exports
    'PlayerHasAnyBag',
    'PlayerHasBagType',
    'GetPlayerBagInSlot',
    'GetPlayerEquippedBagCount',
    'GetPlayerTotalCapacity',
    'ForceEquipBag',
    'ForceUnequipAllBags',
    'GetBagContents',
    'IsBagEmpty',
    'SetBagLock',
    'IsBagLocked',
    'SetBagDurability',
    'GetBagDurability',
    'GetBagConfig',
    'IsBagItem',
    'GetAllBagConfigs'
}
