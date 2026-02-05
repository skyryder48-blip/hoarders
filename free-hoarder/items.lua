--[[
    ox_inventory Item Definitions for free-hoarder
    
    Add these items to your ox_inventory items.lua
    
    IMPORTANT: 
    - Bags auto-equip when entering inventory (prop attaches, capacity added)
    - Right-click/use a bag to OPEN it and store items inside
    - The server export is REQUIRED for the bag to open
    - close = false keeps inventory open so the bag stash can open
]]

-------------------------------------------------------------------------------
-- ITEMS.LUA FORMAT
-- Add these to your ox_inventory/data/items.lua file
-------------------------------------------------------------------------------

--[[ COPY FROM HERE

    -- BACKPACKS
    ['hoarder_backpack_sm'] = {
        label = 'Small Backpack',
        weight = 500,
        stack = false,
        close = false,
        description = 'A small daypack for light carrying. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_backpack_md'] = {
        label = 'Medium Backpack',
        weight = 750,
        stack = false,
        close = false,
        description = 'A medium backpack for everyday use. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_backpack_lg'] = {
        label = 'Large Hiking Pack',
        weight = 1200,
        stack = false,
        close = false,
        description = 'A large hiking backpack. Can hold long guns. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- SHOULDERBAGS
    ['hoarder_shoulder_purse'] = {
        label = 'Purse',
        weight = 200,
        stack = false,
        close = false,
        description = 'A stylish purse. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_shoulder_messenger'] = {
        label = 'Messenger Bag',
        weight = 400,
        stack = false,
        close = false,
        description = 'A professional messenger bag. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_shoulder_duffle'] = {
        label = 'Duffle Bag',
        weight = 600,
        stack = false,
        close = false,
        description = 'A large duffle bag. Can hold long guns. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- HANDBAGS
    ['hoarder_hand_clutch'] = {
        label = 'Clutch',
        weight = 100,
        stack = false,
        close = false,
        description = 'A small clutch purse. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_hand_briefcase'] = {
        label = 'Briefcase',
        weight = 300,
        stack = false,
        close = false,
        description = 'A professional briefcase. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_hand_riflecase'] = {
        label = 'Rifle Case',
        weight = 800,
        stack = false,
        close = false,
        description = 'A hard rifle case. Can hold rifles and snipers. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- SHOPPING BAGS (variants)
    ['hoarder_hand_shopping_01'] = {
        label = 'Shopping Bag',
        weight = 50,
        stack = false,
        close = false,
        description = 'A paper shopping bag. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_hand_shopping_02'] = {
        label = 'Shopping Bag',
        weight = 50,
        stack = false,
        close = false,
        description = 'A paper shopping bag. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_hand_shopping_03'] = {
        label = 'Shopping Bag',
        weight = 50,
        stack = false,
        close = false,
        description = 'A paper shopping bag. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- TWO-HAND CARRY ITEMS (blocks ALL weapons while carrying)
    ['hoarder_carry_box_sm'] = {
        label = 'Small Box',
        weight = 200,
        stack = false,
        close = false,
        description = 'A small cardboard box. Requires both hands. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_carry_box_md'] = {
        label = 'Medium Box',
        weight = 400,
        stack = false,
        close = false,
        description = 'A medium cardboard box. Requires both hands. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_carry_box_lg'] = {
        label = 'Large Box',
        weight = 600,
        stack = false,
        close = false,
        description = 'A large box. Requires both hands. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_carry_crate'] = {
        label = 'Wooden Crate',
        weight = 1000,
        stack = false,
        close = false,
        description = 'A large wooden crate. Can store long guns. Requires both hands. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_carry_cooler'] = {
        label = 'Cooler',
        weight = 500,
        stack = false,
        close = false,
        description = 'A portable cooler. Requires both hands. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_carry_toolbox'] = {
        label = 'Toolbox',
        weight = 800,
        stack = false,
        close = false,
        description = 'A heavy-duty toolbox. Requires both hands. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- JOB-SPECIFIC BAGS
    ['hoarder_medic_bag'] = {
        label = 'Medic Bag',
        weight = 600,
        stack = false,
        close = false,
        description = 'EMS medical supply bag. Job restricted. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_police_duffle'] = {
        label = 'Police Equipment Bag',
        weight = 800,
        stack = false,
        close = false,
        description = 'Police equipment bag. Can store long guns. Job restricted. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_mechanic_toolbag'] = {
        label = 'Mechanic Tool Bag',
        weight = 700,
        stack = false,
        close = false,
        description = 'Mechanic tool bag. Job restricted. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- DURABILITY BAGS (wear out over time)
    ['hoarder_paper_bag'] = {
        label = 'Paper Bag',
        weight = 10,
        stack = false,
        close = false,
        description = 'A cheap paper bag. Tears easily. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_plastic_bag'] = {
        label = 'Plastic Bag',
        weight = 5,
        stack = false,
        close = false,
        description = 'A thin plastic bag. Very fragile. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- TUCKED ITEMS (no visible prop)
    ['hoarder_mag_holder'] = {
        label = 'Magazine Holder',
        weight = 100,
        stack = false,
        close = false,
        description = 'A concealed magazine holder. Adds 2 extra slots. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_wallet'] = {
        label = 'Wallet',
        weight = 50,
        stack = false,
        close = false,
        description = 'A leather wallet. Holds IDs, licenses, and money. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -------------------------------------------------------------------------------
    -- LOCK SYSTEM ITEMS (v2.0)
    -------------------------------------------------------------------------------
    
    ['hoarder_bag_key'] = {
        label = 'Bag Key',
        weight = 10,
        stack = false,
        close = true,
        description = 'A small key that unlocks a specific bag.',
        -- metadata.keyId links to the bag lock
        -- metadata.bagName shows which bag type
        -- metadata.label shows custom label
    },
    
    ['hoarder_padlock_key'] = {
        label = 'Padlock Key',
        weight = 15,
        stack = false,
        close = true,
        description = 'A key for a padlock attached to a bag.',
        -- metadata.keyId links to the padlock
    },
    
    ['padlock'] = {
        label = 'Padlock',
        weight = 200,
        stack = true,
        close = true,
        description = 'A sturdy padlock. Can be attached to lockable bags.',
    },
    
    -- NOTE: The following items may already exist in your server
    -- Only add them if they don't exist
    
    --[[
    ['hacking_device'] = {
        label = 'Hacking Device',
        weight = 500,
        stack = false,
        close = true,
        description = 'A device used to bypass electronic locks.',
    },
    
    ['advanced_hacking_device'] = {
        label = 'Advanced Hacking Device',
        weight = 750,
        stack = false,
        close = true,
        description = 'An advanced device capable of bypassing biometric security.',
    },
    
    ['laptop'] = {
        label = 'Laptop',
        weight = 2000,
        stack = false,
        close = true,
        description = 'A portable computer.',
    },
    
    ['lockpick'] = {
        label = 'Lockpick',
        weight = 50,
        stack = true,
        close = true,
        description = 'A set of lockpicks for opening locks.',
    },
    
    ['screwdriver'] = {
        label = 'Screwdriver',
        weight = 200,
        stack = true,
        close = true,
        description = 'A flathead screwdriver.',
    },
    
    ['crowbar'] = {
        label = 'Crowbar',
        weight = 1500,
        stack = false,
        close = true,
        description = 'A heavy metal crowbar.',
    },
    
    ['hammer'] = {
        label = 'Hammer',
        weight = 800,
        stack = false,
        close = true,
        description = 'A standard claw hammer.',
    },
    
    ['knife'] = {
        label = 'Knife',
        weight = 150,
        stack = false,
        close = true,
        description = 'A sharp knife.',
    },
    
    -------------------------------------------------------------------------------
    -- REPAIR SYSTEM ITEMS (v2.0)
    -------------------------------------------------------------------------------
    
    ['fabric'] = {
        label = 'Fabric',
        weight = 100,
        stack = true,
        close = true,
        description = 'A piece of fabric for crafting or repairs.',
    },
    
    ['leather'] = {
        label = 'Leather',
        weight = 150,
        stack = true,
        close = true,
        description = 'A piece of leather for crafting or repairs.',
    },
    
    ['sewing_kit'] = {
        label = 'Sewing Kit',
        weight = 200,
        stack = true,
        close = true,
        description = 'A kit with needles and thread for repairs.',
    },
    
    ['thread'] = {
        label = 'Thread',
        weight = 20,
        stack = true,
        close = true,
        description = 'A spool of thread.',
    },
    
    ['duct_tape'] = {
        label = 'Duct Tape',
        weight = 150,
        stack = true,
        close = true,
        description = 'Heavy-duty tape for quick fixes.',
    },
    
    ['plastic'] = {
        label = 'Plastic Sheet',
        weight = 50,
        stack = true,
        close = true,
        description = 'A sheet of plastic material.',
    },
    
    -- ADDITIONAL CRAFTING MATERIALS (v2.0)
    ['cardboard'] = {
        label = 'Cardboard',
        weight = 100,
        stack = true,
        close = true,
        description = 'Sturdy cardboard material.',
    },
    
    ['wood'] = {
        label = 'Wood Planks',
        weight = 500,
        stack = true,
        close = true,
        description = 'Wooden planks for construction.',
    },
    
    ['metalscrap'] = {
        label = 'Metal Scrap',
        weight = 300,
        stack = true,
        close = true,
        description = 'Scrap metal for crafting.',
    },
    
    -- BAG VARIANTS (v2.0)
    -- Small Backpack Variants
    ['hoarder_backpack_sm_black'] = {
        label = 'Small Backpack (Black)',
        weight = 500,
        stack = false,
        close = false,
        description = 'A small black daypack. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_backpack_sm_green'] = {
        label = 'Small Backpack (Green)',
        weight = 500,
        stack = false,
        close = false,
        description = 'A small green daypack. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- Medium Backpack Variants
    ['hoarder_backpack_md_black'] = {
        label = 'Medium Backpack (Black)',
        weight = 750,
        stack = false,
        close = false,
        description = 'A medium black backpack. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_backpack_md_camo'] = {
        label = 'Medium Backpack (Camo)',
        weight = 750,
        stack = false,
        close = false,
        description = 'A medium camo backpack. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- Large Backpack Variants
    ['hoarder_backpack_lg_military'] = {
        label = 'Large Backpack (Military)',
        weight = 1200,
        stack = false,
        close = false,
        description = 'A large military backpack. Can hold long guns. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- Duffle Bag Variants
    ['hoarder_shoulder_duffle_black'] = {
        label = 'Duffle Bag (Black)',
        weight = 850,
        stack = false,
        close = false,
        description = 'A black duffle bag. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_shoulder_duffle_grey'] = {
        label = 'Duffle Bag (Grey)',
        weight = 850,
        stack = false,
        close = false,
        description = 'A grey duffle bag. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    -- Briefcase Variants
    ['hoarder_hand_briefcase_silver'] = {
        label = 'Briefcase (Silver)',
        weight = 600,
        stack = false,
        close = false,
        description = 'A silver briefcase. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    
    ['hoarder_hand_briefcase_money'] = {
        label = 'Money Case',
        weight = 600,
        stack = false,
        close = false,
        description = 'A case for carrying cash. Right-click to open.',
        server = {
            export = 'free-hoarder.useBag'
        }
    },
    ]]

END COPY ]]

-------------------------------------------------------------------------------
-- INVENTORY IMAGES
-- Place these images in ox_inventory/web/images/
-------------------------------------------------------------------------------

--[[
Required images:
- hoarder_backpack_sm.png
- hoarder_backpack_md.png
- hoarder_backpack_lg.png
- hoarder_shoulder_purse.png
- hoarder_shoulder_messenger.png
- hoarder_shoulder_duffle.png
- hoarder_hand_clutch.png
- hoarder_hand_briefcase.png
- hoarder_hand_riflecase.png
- hoarder_hand_shopping_01.png
- hoarder_hand_shopping_02.png
- hoarder_hand_shopping_03.png
- hoarder_carry_box_sm.png
- hoarder_carry_box_md.png
- hoarder_carry_box_lg.png
- hoarder_carry_crate.png
- hoarder_carry_cooler.png
- hoarder_carry_toolbox.png
- hoarder_medic_bag.png
- hoarder_police_duffle.png
- hoarder_mechanic_toolbag.png
- hoarder_paper_bag.png
- hoarder_plastic_bag.png
- hoarder_mag_holder.png
- hoarder_wallet.png
- hoarder_bag_key.png
- hoarder_padlock_key.png
- padlock.png
- fabric.png
- leather.png
- sewing_kit.png
- thread.png
- duct_tape.png
- plastic.png
- cardboard.png
- wood.png
- metalscrap.png

Variant images (v2.0):
- hoarder_backpack_sm_black.png
- hoarder_backpack_sm_green.png
- hoarder_backpack_md_black.png
- hoarder_backpack_md_camo.png
- hoarder_backpack_lg_military.png
- hoarder_shoulder_duffle_black.png
- hoarder_shoulder_duffle_grey.png
- hoarder_hand_briefcase_silver.png
- hoarder_hand_briefcase_money.png
]]
