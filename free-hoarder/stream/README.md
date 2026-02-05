# Streaming Props for free-hoarder

This folder is for custom/addon prop models. Place your `.ydr` (model) and `.ytd` (texture) files directly here.

## How Streaming Works

FiveM automatically streams files in this folder to players. No additional configuration needed - just drop your files here and restart the resource.

## Adding Addon Props

### Step 1: Get Your Prop Files
You need two files for each prop:
- `yourprop.ydr` - The 3D model
- `yourprop.ytd` - The texture dictionary

### Step 2: Place Files Here
```
stream/
├── my_custom_backpack.ydr
├── my_custom_backpack.ytd
├── my_custom_briefcase.ydr
├── my_custom_briefcase.ytd
└── README.md
```

### Step 3: Configure the Bag
Edit `config/bags.lua` to use your prop:

```lua
['my_custom_bag_item'] = {
    label = 'My Custom Bag',
    type = BagType.BACKPACK,  -- or SHOULDERBAG, HANDBAG, TWOHAND
    allowedSlots = { AttachmentSlot.BACK },
    
    -- Use your streamed prop name (filename without extension)
    model = 'my_custom_backpack',
    
    capacity = {
        weight = 15000,
        slots = 10
    },
    offsets = {
        [AttachmentSlot.BACK] = {
            pos = vec3(0.0, -0.12, 0.0),
            rot = vec3(0.0, 90.0, 180.0)
        }
    },
    restrictsWeapons = false,
    allowsLongGuns = false,
    allowsSnipers = false,
}
```

### Step 4: Add to ox_inventory
Add the item to `ox_inventory/data/items.lua`:

```lua
['my_custom_bag_item'] = {
    label = 'My Custom Bag',
    weight = 500,
    stack = false,
    close = false,
    description = 'My custom bag. Right-click to open.',
    server = {
        export = 'free-hoarder.useBag'
    }
},
```

### Step 5: Add Inventory Image
Place `my_custom_bag_item.png` in `ox_inventory/web/images/`

### Step 6: Restart
Restart both `ox_inventory` and `free-hoarder` resources.

---

## Adjusting Prop Position/Rotation

The `offsets` table controls where the prop attaches:

```lua
offsets = {
    [AttachmentSlot.BACK] = {
        pos = vec3(X, Y, Z),    -- Position offset from bone
        rot = vec3(RX, RY, RZ)  -- Rotation in degrees
    }
}
```

**Position Guide:**
- `X` = Left/Right (negative = left)
- `Y` = Forward/Back (negative = forward/closer to body)
- `Z` = Up/Down (positive = up)

**Testing Command:**
Use `/hoarder_testprop <model_name>` in-game to verify your prop loads correctly.

---

## Bag Types & Slots

| Type | Allowed Slots | Weapon Behavior |
|------|---------------|-----------------|
| `BACKPACK` | BACK, FRONT | No restrictions |
| `SHOULDERBAG` | LEFT_SHOULDER, RIGHT_SHOULDER | No restrictions |
| `HANDBAG` | LEFT_HAND, RIGHT_HAND | Blocks two-handed weapons |
| `TWOHAND` | TWO_HAND | Blocks ALL weapons |

---

## Native GTA Props (Fallback Reference)

If you don't have custom props, the script uses these GTA native props:

**Backpacks:**
- `prop_cs_heist_bag_01` (large)
- `prop_cs_heist_bag_02` (medium)
- `prop_carrier_bag_01` (small)

**Handbags:**
- `prop_ld_purse_01` (clutch)
- `prop_ld_case_01` (briefcase)
- `prop_cs_shopping_bag` (shopping bag)

**Two-Hand Carry:**
- `prop_cs_cardbox_01` (small box)
- `prop_box_ammo04a` (medium box)
- `hei_prop_heist_box` (large box)
- `prop_boxpile_04a` (wooden crate)
- `prop_cooler_01` (cooler)
- `prop_tool_box_04` (toolbox)

---

## Troubleshooting

**Prop not appearing:**
1. Check model name matches filename (without extension)
2. Run `/hoarder_testprop modelname` to test
3. Check F8 console for errors
4. Ensure resource restarted after adding files

**Prop in wrong position:**
1. Adjust `pos` values in config
2. Start with small changes (0.01 increments)
3. Adjust `rot` if prop faces wrong direction

**Texture issues:**
1. Ensure `.ytd` filename matches `.ydr` filename
2. Check texture is embedded correctly in the ytd
