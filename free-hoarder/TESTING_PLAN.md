# free-hoarder v2.0 Testing Plan

## File Structure (Final Consolidated)

```
free-hoarder/
├── config/
│   ├── config.lua      (main config + lock types + crafting recipes)
│   ├── bags.lua        (bag definitions + variants)
│   └── restrictions.lua
├── shared/
│   └── utils.lua       (enums + helpers + notifications + events)
├── client/
│   ├── main.lua
│   ├── props.lua
│   ├── animations.lua  (+ sounds)
│   ├── statebags.lua
│   ├── movement.lua
│   ├── weapons.lua
│   ├── clothing.lua
│   ├── locking.lua
│   ├── durability.lua
│   ├── search.lua      (+ player state detection)
│   ├── physical.lua    (stamina + swimming)
│   ├── openanimations.lua
│   ├── ui.lua          (+ quickdrop + throwing)
│   ├── exports.lua
│   └── debug.lua
├── server/
│   ├── inventory.lua
│   ├── statebags.lua
│   ├── main.lua
│   ├── hooks.lua
│   ├── drops.lua
│   ├── discord.lua
│   ├── admin.lua
│   ├── validation.lua
│   ├── locking.lua
│   ├── durability.lua
│   ├── search.lua
│   ├── crafting.lua
│   └── exports.lua
├── items.lua
├── fxmanifest.lua
└── README.md
```

**Total: 34 Lua files, ~14,500 lines**

## Pre-Test Setup

1. Ensure all dependencies are installed and started
2. Add all items from `items.lua` to ox_inventory
3. Give yourself admin permissions: `add_ace identifier.xxx free-hoarder.admin allow`
4. Use `/hoarder_debug` to enable debug overlay

## Core System Tests

### 1. Auto-Equip System
- [ ] Pick up `hoarder_backpack_sm` → Should auto-equip to BACK slot
- [ ] Pick up second backpack → Should not equip (slot occupied)
- [ ] Drop backpack → Prop should disappear, capacity reduced

### 2. Capacity System
- [ ] Equip small backpack → Weight limit should increase
- [ ] Fill inventory to 55% → No speed penalty
- [ ] Fill inventory to 75% → Speed should be reduced
- [ ] Fill inventory to 100%+ → Maximum speed penalty

### 3. Visual Props
- [ ] Equip backpack → Prop visible on back
- [ ] Equip duffle bag → Prop visible on shoulder
- [ ] Equip briefcase → Prop visible in hand
- [ ] Equip two-hand item → Both hands hold prop

### 4. Weapon Restrictions
- [ ] Equip briefcase in hand → Can use pistol, melee
- [ ] Equip briefcase → Cannot use rifle
- [ ] Equip two-hand box → Cannot use ANY weapon
- [ ] Drop two-hand → Weapons re-enabled

### 5. Movement System
- [ ] Empty inventory → Normal speed
- [ ] 50% capacity → Slightly reduced sprint
- [ ] 80% capacity → Noticeable reduction
- [ ] Two-hand carry → Walk animation plays

## v2.0 Feature Tests

### 6. Locking System (config/config.lua)

#### PIN Lock
- [ ] Open bag menu → Select "Lock Bag" → Enter 4-digit PIN
- [ ] Try opening locked bag → Requires PIN entry
- [ ] Enter wrong PIN 3 times → Lockout occurs
- [ ] Enter correct PIN → Bag opens
- [ ] Change PIN → Old PIN no longer works

#### Key Lock
- [ ] Set lock type to 'key' → Key item should spawn
- [ ] Try opening without key → Cannot open
- [ ] With key in inventory → Bag opens automatically
- [ ] Bypass with lockpick → Success/failure based on chance

#### Padlock
- [ ] Have padlock item → "Add Padlock" option appears
- [ ] Add padlock → Bag becomes locked
- [ ] Remove padlock → Key required or bypass

#### Biometric
- [ ] Enable biometric lock → Owner only
- [ ] Another player tries to open → Cannot open
- [ ] Bypass attempt with hacking device → Should be difficult

### 7. Durability System
- [ ] New bag shows 100% durability
- [ ] Open bag → Durability decreases (check config amount)
- [ ] At 25% → Yellow warning notification
- [ ] At 10% → Red warning notification
- [ ] At 5% → Critical warning
- [ ] At 0% → Bag breaks, contents drop

#### Repair
- [ ] Have repair materials in inventory
- [ ] At repair station (if configured) → "Repair Bag" option
- [ ] Complete repair → 100% durability restored
- [ ] Materials consumed

### 8. Search/Frisk System (client/search.lua)

#### Prerequisites
- Requires `ox_target`
- Test player must be restrained (handcuffed or hands up)

#### Search
- [ ] Target restrained player → "Search Bags" option appears
- [ ] Select search → List of their equipped bags shows
- [ ] Click unlocked bag → View contents (read-only)
- [ ] Click locked bag → Bypass options appear
- [ ] Bypass attempt → Success/failure with notification

#### Take Bag
- [ ] Target restrained player → "Take Bag" option appears
- [ ] Select bag to take → Progress bar
- [ ] Complete → Bag transfers to your inventory
- [ ] Target receives notification (if configured)

### 9. Physical Systems (client/physical.lua)

#### Stamina
- [ ] At <55% capacity → Normal stamina drain
- [ ] At 55% capacity → 1.5x stamina drain (sprint depletes faster)
- [ ] At 80% capacity → 2.5x stamina drain
- [ ] Threshold notification appears when crossing

#### Swimming Auto-Drop
- [ ] Equip two-hand item (box/crate)
- [ ] Walk toward water → Warning appears
- [ ] Enter water past threshold → Item auto-drops
- [ ] Notification: "Item dropped in the water"

### 10. Opening Animations (client/openanimations.lua)

#### Backpack
- [ ] Open backpack → Upper body animation plays
- [ ] Can still walk during animation

#### Briefcase
- [ ] Open briefcase → Full body animation
- [ ] Movement blocked during animation
- [ ] Press WASD → Animation cancels

#### Wallet (Tucked)
- [ ] Open wallet → Quick animation
- [ ] No movement block

#### Two-Hand
- [ ] Open box → Set-down animation
- [ ] Movement blocked

### 11. Variants System (config/bags.lua)
- [ ] Give `hoarder_backpack_sm_black` → Should equip as small backpack
- [ ] Props should use variant model (different color)
- [ ] Capacity should match base backpack
- [ ] Container works normally

### 12. Crafting Exports (server/crafting.lua)
```lua
-- Test in server console
print(json.encode(exports['free-hoarder']:GetBagRecipes()))
print(json.encode(exports['free-hoarder']:GetBagRecipe('hoarder_backpack_md')))
print(json.encode(exports['free-hoarder']:GetRepairRecipes()))
```

### 13. UI Features (client/ui.lua)

#### Quick Drop
- [ ] Press Y (default) → First inventory item drops
- [ ] Hold Y → Items continue dropping
- [ ] Release Y → Stops dropping
- [ ] Empty inventory → "Your inventory is empty" notification

#### Throwing
- [ ] Open bag menu → Select "Throw Bag"
- [ ] Aim at ground → Green target marker appears
- [ ] Left-click → Bag thrown to target
- [ ] Right-click/ESC → Cancel throw mode

### 14. Sounds (client/animations.lua)
- [ ] Equip bag → Equip sound plays (if configured)
- [ ] Open bag → Open sound plays
- [ ] Drop bag → Drop sound plays
- [ ] Throw bag → Throw sound plays

## Integration Tests

### 15. Event Hooks
Test with external script listening to events:
```lua
RegisterNetEvent('free_hoarder:client:onBagEquipped', function(data)
    print('Bag equipped:', json.encode(data))
end)
```
- [ ] Events fire correctly on equip/unequip
- [ ] Events fire on lock/unlock
- [ ] Events fire on search/take

### 16. Export Functionality
```lua
-- Client-side tests
print(exports['free-hoarder']:GetEquippedBags())
print(exports['free-hoarder']:GetCapacityPercentage())
print(exports['free-hoarder']:IsTwoHandCarryActive())
print(exports['free-hoarder']:IsWeaponRestricted())
print(exports['free-hoarder']:GetStaminaMultiplier())
```

### 17. Discord Logging
- [ ] Configure webhook URL
- [ ] Equip bag → Check Discord for log
- [ ] Drop bag → Check Discord for log
- [ ] Search player → Check Discord for log
- [ ] Lock bypass → Check Discord for log

## Performance Tests

### 18. Idle CPU Usage
- [ ] With no bags equipped → ~0.00ms
- [ ] With bags equipped, idle → ~0.00ms
- [ ] `/hoarder_debug` should show CPU usage

### 19. Stress Test
- [ ] Equip maximum bags (all slots)
- [ ] Run around for 5 minutes
- [ ] No memory leaks or increasing CPU

## Admin Commands

### 20. Command Tests
- [ ] `/hoarder_debug` → Toggle debug overlay
- [ ] `/hoarder_give [id] hoarder_backpack_sm` → Give bag to player
- [ ] `/hoarder_clear [id]` → Remove all bags
- [ ] `/hoarder_repair [id]` → Repair all bags
- [ ] `/hoarder_setdurability [id] 50` → Set durability to 50%

## Edge Cases

### 21. Edge Case Tests
- [ ] Disconnect while bag equipped → Reconnect, bags persist
- [ ] Die while bag equipped → Respawn, bags persist
- [ ] Trade bag to another player → Works correctly
- [ ] Sell bag to shop → Works correctly
- [ ] Bag in vehicle trunk → Works correctly

## Bug Regression

### 22. Previous Bug Checks
- [ ] No "useBag export" errors
- [ ] No prop flickering
- [ ] No weapon getting stuck equipped
- [ ] No duplicate bags on reconnect
- [ ] No negative capacity values

## Consolidated Files Verification

### 23. File Consolidation Checks
- [ ] `config/config.lua` contains lock types and crafting recipes
- [ ] `config/bags.lua` contains variant definitions
- [ ] `client/animations.lua` contains sound functions
- [ ] `client/ui.lua` contains quickdrop and throwing
- [ ] `client/search.lua` contains player state detection
- [ ] `client/physical.lua` contains stamina and swimming

## Sign-Off

| Test Category | Pass/Fail | Notes |
|---------------|-----------|-------|
| Auto-Equip | | |
| Capacity | | |
| Visual Props | | |
| Weapon Restrictions | | |
| Movement | | |
| Locking | | |
| Durability | | |
| Search/Frisk | | |
| Physical Systems | | |
| Animations | | |
| Variants | | |
| Crafting | | |
| UI Features | | |
| Sounds | | |
| Events | | |
| Exports | | |
| Discord | | |
| Performance | | |
| Admin Commands | | |
| Edge Cases | | |
| Consolidated Files | | |

**Tested By:** _______________
**Date:** _______________
**Version:** 2.0.0 (Consolidated)
**File Count:** 36 Lua files
**Line Count:** ~14,800 lines
