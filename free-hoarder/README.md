# free-hoarder v2.0

A comprehensive bag and inventory expansion system for FiveM QBX/QBCore servers using ox_inventory.

## Features

### Core Features (v1.x)
- **Multi-Bag System** - Equip multiple bags simultaneously in 8 different slots
- **Auto-Equip** - Bags automatically attach when entering inventory
- **Capacity Bonuses** - Each bag adds weight and slot capacity
- **Visual Props** - Bags appear on your character with proper positioning
- **Weapon Restrictions** - Certain weapons blocked based on equipped bags
- **Movement Penalties** - Speed reduction when over-encumbered
- **Two-Hand Carry** - Boxes, crates, coolers with carry animations
- **Clothing Integration** - Hides bags when conflicting clothing worn
- **Outfit Storage** - Save/load outfits in bag metadata
- **Ground Drops** - Drop bags as world objects

### v2.0 Features
- **Bag Locking** - PIN, Key, Padlock, and Biometric lock types
- **Durability System** - Bags degrade over time, can break, require repair
- **Search/Frisk** - Police can search restrained players' bags
- **Stamina Integration** - Heavy loads drain stamina faster
- **Swimming Auto-Drop** - Two-hand items drop when entering water
- **Opening Animations** - Per-bag configurable animations
- **Bag Variants** - Color/style variants as separate items
- **Crafting Integration** - Recipe exports for external crafting resources
- **Debug Mode** - In-game debug overlay for testing
- **Comprehensive Exports** - 35+ exports for external integration

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)
- [qbx_core](https://github.com/Qbox-project/qbx_core) or qb-core
- [ox_target](https://github.com/overextended/ox_target) (optional, for search/frisk)

## Installation

1. Download and extract to your resources folder
2. Add items from `items.lua` to your `ox_inventory/data/items.lua`
3. Add images to `ox_inventory/web/images/`
4. Add to your `server.cfg`:
   ```
   ensure free-hoarder
   ```
5. Configure `config/config.lua` to your preferences

## Configuration

### Main Config (`config/config.lua`)

```lua
Config.Debug = false                    -- Enable debug mode
Config.DefaultMaxWeight = 26500         -- Base player weight capacity (grams)
Config.AutoEquip = true                 -- Auto-equip bags when picked up
Config.MovementPenalty = true           -- Enable speed reduction when encumbered

-- Notification settings
Config.Notifications = {
    onEquip = true,
    onUnequip = true,
    onCapacityChange = false,
    onWeaponBlock = true,
    onDurabilityLow = true,
}
```

### Bag Types

| Type | Slot | Example Items |
|------|------|---------------|
| `backpack` | BACK, FRONT | Backpacks |
| `shoulderbag` | LEFT_SHOULDER, RIGHT_SHOULDER | Duffle, Messenger |
| `handbag` | LEFT_HAND, RIGHT_HAND | Briefcase, Clutch |
| `twohand` | TWO_HAND | Boxes, Crates, Coolers |
| `tucked` | TUCKED (invisible) | Wallet, Mag Holder |

### Locking System (v2.0)

```lua
Config.Locking = {
    enabled = true,
    defaultLockType = 'pin',
    pinLength = 4,
    maxPinAttempts = 3,
    lockoutDuration = 60,  -- seconds
}
```

**Lock Types:**
- `pin` - 4-digit PIN code
- `key` - Physical key item required
- `padlock` - Padlock item adds lock to bag
- `biometric` - Owner's fingerprint only

### Durability System (v2.0)

```lua
Config.Durability = {
    enabled = true,
    defaultDegradePerOpen = 2,  -- % per open
    repairTime = 5000,          -- ms
    repairJobs = { 'tailor' },  -- Jobs that can repair
}
```

### Search/Frisk System (v2.0)

```lua
Config.Search = {
    enabled = true,
    searchDistance = 2.5,
    takeDistance = 2.0,
    allowForceOpen = true,  -- Force open locked bags
    notifyTarget = true,    -- Notify when searched
}
```

Requires player to be restrained (handcuffed or hands up).

### Stamina System (v2.0)

```lua
Config.Stamina = {
    enabled = true,
    thresholds = {
        { capacity = 55, drain = 1.5 },  -- 55% capacity = 1.5x drain
        { capacity = 80, drain = 2.5 },  -- 80% capacity = 2.5x drain
    },
}
```

### Swimming Auto-Drop (v2.0)

```lua
Config.Swimming = {
    enabled = true,
    dropDepthThreshold = 0.5,  -- 0.5 = waist deep
    dropDelay = 500,           -- ms before dropping
    warnBeforeDrop = true,
}
```

### Opening Animations (v2.0)

```lua
Config.OpenAnimations = {
    enabled = true,
    playOnClose = true,
    skipForTypes = { },  -- Bag types to skip
}
```

Per-bag custom animations in `config/bags.lua`:
```lua
['hoarder_hand_briefcase'] = {
    -- ... other config
    openAnimation = {
        dict = 'anim@heists@ornate_bank@grab_cash',
        clip = 'intro',
        duration = 2500,
        blockMovement = true,
    },
}
```

## Bag Variants (v2.0)

Variants are color/style variations that share base bag properties:

```lua
-- In shared/variants.lua
Config.Variants.items['hoarder_backpack_sm'] = {
    { suffix = 'black', label = 'Small Backpack (Black)', model = 'prop_poly_bag_01' },
    { suffix = 'green', label = 'Small Backpack (Green)', model = 'prop_michael_backpack' },
}
```

Creates items: `hoarder_backpack_sm_black`, `hoarder_backpack_sm_green`

## Crafting Integration (v2.0)

Export recipes for external crafting resources:

```lua
-- Get all bag recipes
local recipes = exports['free-hoarder']:GetBagRecipes()

-- Get specific recipe
local recipe = exports['free-hoarder']:GetBagRecipe('hoarder_backpack_md')
-- Returns: { {name='fabric', count=5}, {name='leather', count=2}, ... }

-- Get repair recipes
local repairRecipes = exports['free-hoarder']:GetRepairRecipes()

-- Craft a bag (server-side)
local success, error = exports['free-hoarder']:CraftBag(source, 'hoarder_backpack_md')
```

## Exports

### Client Exports

```lua
-- Bag Information
exports['free-hoarder']:GetEquippedBags()           -- Returns all equipped bags
exports['free-hoarder']:GetBagInSlot(slotName)      -- Returns bag data for slot
exports['free-hoarder']:IsBagEquipped(bagName)      -- Check if specific bag equipped
exports['free-hoarder']:GetBagConfig(itemName)      -- Get bag configuration
exports['free-hoarder']:IsBagItem(itemName)         -- Check if item is a bag

-- Capacity
exports['free-hoarder']:GetCurrentWeight()          -- Current inventory weight
exports['free-hoarder']:GetCurrentMaxWeight()       -- Maximum weight capacity
exports['free-hoarder']:GetCapacityPercentage()     -- Capacity as percentage
exports['free-hoarder']:IsOverCapacity()            -- Check if over 100%
exports['free-hoarder']:GetBonusCapacity()          -- Bonus from bags

-- State
exports['free-hoarder']:IsTwoHandCarryActive()      -- Carrying two-hand item?
exports['free-hoarder']:IsWeaponRestricted()        -- Are weapons restricted?
exports['free-hoarder']:GetStaminaMultiplier()      -- Current stamina drain multiplier

-- Locking
exports['free-hoarder']:IsBagLocked(slotName)       -- Check if bag is locked
exports['free-hoarder']:GetBagLockData(slotName)    -- Get lock metadata

-- Durability
exports['free-hoarder']:GetBagDurability(slotName)  -- Get durability %

-- Variants
exports['free-hoarder']:IsVariantItem(itemName)     -- Check if item is a variant
exports['free-hoarder']:GetVariantNames(baseBag)    -- Get all variants for base bag
```

### Server Exports

```lua
-- Bag Management
exports['free-hoarder']:GetPlayerEquippedBags(source)
exports['free-hoarder']:GetPlayerBagInSlot(source, slotName)
exports['free-hoarder']:ForceEquipBag(source, bagName, slotName)
exports['free-hoarder']:ForceUnequipBag(source, slotName)
exports['free-hoarder']:GetBagContents(source, slotName)

-- Capacity
exports['free-hoarder']:GetPlayerCapacity(source)
exports['free-hoarder']:GetPlayerBonusCapacity(source)

-- Locking
exports['free-hoarder']:SetBagLock(source, slotName, lockData)
exports['free-hoarder']:UnlockBag(source, slotName)
exports['free-hoarder']:IsBagLockedServer(source, slotName)

-- Durability
exports['free-hoarder']:GetBagDurabilityServer(source, slotName)
exports['free-hoarder']:SetBagDurabilityServer(source, slotName, durability)
exports['free-hoarder']:RepairBag(source, slotName)

-- Crafting
exports['free-hoarder']:GetBagRecipes()
exports['free-hoarder']:GetBagRecipe(bagName)
exports['free-hoarder']:GetRepairRecipes()
exports['free-hoarder']:CraftBag(source, bagName)
exports['free-hoarder']:CanPlayerCraftBag(source, bagName)

-- Variants
exports['free-hoarder']:GetAllVariants()
exports['free-hoarder']:GetMergedVariantConfig(itemName)
```

## Events

### Client Events

```lua
-- Listen for bag events
RegisterNetEvent('free_hoarder:client:onBagEquipped', function(data)
    -- data = { source, bagName, slotName, containerId }
end)

RegisterNetEvent('free_hoarder:client:onBagUnequipped', function(data)
    -- data = { source, bagName, slotName }
end)

RegisterNetEvent('free_hoarder:client:onBagOpened', function(data)
    -- data = { source, bagName, slotName, containerId }
end)

RegisterNetEvent('free_hoarder:client:onBagLocked', function(data)
    -- data = { source, bagName, slotName, lockType }
end)

RegisterNetEvent('free_hoarder:client:onBagUnlocked', function(data)
    -- data = { source, bagName, slotName }
end)

RegisterNetEvent('free_hoarder:client:onCapacityChanged', function(data)
    -- data = { source, currentWeight, maxWeight, bonusWeight }
end)
```

### Server Events

```lua
RegisterNetEvent('free_hoarder:server:onBagEquipped', function(data) end)
RegisterNetEvent('free_hoarder:server:onBagUnequipped', function(data) end)
RegisterNetEvent('free_hoarder:server:onBagOpened', function(data) end)
RegisterNetEvent('free_hoarder:server:onBagSearched', function(data) end)
RegisterNetEvent('free_hoarder:server:onBagTaken', function(data) end)
RegisterNetEvent('free_hoarder:server:onBagBroken', function(data) end)
RegisterNetEvent('free_hoarder:server:onBagRepaired', function(data) end)
RegisterNetEvent('free_hoarder:server:onBagCrafted', function(data) end)
```

## Admin Commands

| Command | Description | Permission |
|---------|-------------|------------|
| `/hoarder_debug` | Toggle debug overlay | `free-hoarder.admin` |
| `/hoarder_give [player] [bag]` | Give bag to player | `free-hoarder.admin` |
| `/hoarder_clear [player]` | Clear all bags | `free-hoarder.admin` |
| `/hoarder_repair [player]` | Repair all bags | `free-hoarder.admin` |
| `/hoarder_setdurability [player] [%]` | Set bag durability | `free-hoarder.admin` |

## Discord Logging

Configure webhook in `config/config.lua`:

```lua
Config.Discord = {
    enabled = true,
    webhook = 'YOUR_WEBHOOK_URL',
    botName = 'Hoarder Logs',
}
```

Logs:
- Bag equipped/unequipped
- Bag dropped/thrown
- Bag searched
- Lock bypass attempts
- Bag broken/repaired
- Bag crafted

## Troubleshooting

### Bags not equipping
- Ensure items are added to ox_inventory
- Check for errors in F8 console
- Enable debug mode: `Config.Debug = true`

### Props not showing
- Verify model names in `config/bags.lua`
- Some models require streaming (add to `stream/`)

### Lock system not working
- Ensure `Config.Locking.enabled = true`
- Add lock items (padlock, keys) to inventory

### Durability not degrading
- Check `Config.Durability.enabled = true`
- Verify bag has `durability` config in bags.lua

## Migration from v1.x

1. Backup your current configuration
2. Replace all files with v2.0 version
3. Merge your custom bag configs into new `config/bags.lua`
4. Add new items from `items.lua` (lock items, repair materials, variants)
5. Update any external scripts using old exports (API unchanged)

## Credits

- Developed for QBX/QBCore FiveM framework
- Uses ox_inventory, ox_lib, ox_target by Overextended

## License

Free to use and modify. Attribution appreciated.

## Support

Report issues via GitHub or your community support channels.
