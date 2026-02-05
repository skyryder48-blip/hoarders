--[[
    Bag Definitions for free-hoarder
    
    Each bag item must be registered in ox_inventory separately.
    This file defines the behavior and properties of each bag type.
    
    NATIVE GTA5 PROPS are used by default.
    Replace with custom props when available.
]]

Config = Config or {}

Config.Bags = {
    -------------------------------------------------------------------------------
    -- BACKPACKS
    -- Attach to: BACK, FRONT
    -- Max equipped: 2 (one per slot)
    -------------------------------------------------------------------------------
    
    ['hoarder_backpack_sm'] = {
        label = 'Small Backpack',
        type = BagType.BACKPACK,
        allowedSlots = { AttachmentSlot.BACK, AttachmentSlot.FRONT },
        
        -- Native GTA prop (plastic bag style for small)
        model = 'prop_carrier_bag_01',
        
        -- Capacity bonus when equipped
        capacity = {
            weight = 8000,      -- 8kg bonus
            slots = 6
        },
        
        -- Attachment offsets per slot { position, rotation }
        offsets = {
            [AttachmentSlot.BACK] = {
                pos = vec3(0.0, -0.12, 0.0),
                rot = vec3(0.0, 90.0, 180.0)
            },
            [AttachmentSlot.FRONT] = {
                pos = vec3(0.0, 0.15, 0.0),
                rot = vec3(0.0, 90.0, 0.0)
            }
        },
        
        restrictsWeapons = false,
        allowsLongGuns = false,
        allowsSnipers = false,
        
        -- Locking (v2.0)
        lockable = true,
        allowedLockTypes = { 'pin', 'padlock' },
        
        -- Durability (v2.0)
        material = 'plastic',            -- Plastic bag - less durable
        durability = {
            enabled = true,
            maxDurability = 100,
            degradePerOpen = 3,          -- Lose 3% per open (fragile bag)
        },
        
    },
    
    ['hoarder_backpack_md'] = {
        label = 'Medium Backpack',
        type = BagType.BACKPACK,
        allowedSlots = { AttachmentSlot.BACK, AttachmentSlot.FRONT },
        model = 'prop_cs_heist_bag_02',  -- Heist bag (medium size)
        capacity = {
            weight = 15000,     -- 15kg bonus
            slots = 10
        },
        offsets = {
            [AttachmentSlot.BACK] = {
                pos = vec3(0.0, -0.15, 0.0),
                rot = vec3(0.0, 90.0, 180.0)
            },
            [AttachmentSlot.FRONT] = {
                pos = vec3(0.0, 0.18, 0.0),
                rot = vec3(0.0, 90.0, 0.0)
            }
        },
        restrictsWeapons = false,
        allowsLongGuns = false,
        allowsSnipers = false,
        
        -- Locking (v2.0)
        lockable = true,
        allowedLockTypes = { 'pin', 'key', 'padlock' },
        
        -- Durability (v2.0)
        material = 'nylon',              -- Material type for repair recipe
        durability = {
            enabled = true,
            maxDurability = 100,
            degradePerOpen = 1,          -- Lose 1% per open (sturdy bag)
        },
    },
    
    ['hoarder_backpack_lg'] = {
        label = 'Large Hiking Pack',
        type = BagType.BACKPACK,
        allowedSlots = { AttachmentSlot.BACK, AttachmentSlot.FRONT },
        model = 'prop_cs_heist_bag_01',  -- Larger heist bag
        capacity = {
            weight = 25000,     -- 25kg bonus
            slots = 15
        },
        offsets = {
            [AttachmentSlot.BACK] = {
                pos = vec3(0.0, -0.18, 0.05),
                rot = vec3(0.0, 90.0, 180.0)
            },
            [AttachmentSlot.FRONT] = {
                pos = vec3(0.0, 0.20, 0.0),
                rot = vec3(0.0, 90.0, 0.0)
            }
        },
        restrictsWeapons = false,
        allowsLongGuns = true,
        allowsSnipers = false,
    },
    
    -------------------------------------------------------------------------------
    -- SHOULDERBAGS
    -- Attach to: LEFT_SHOULDER, RIGHT_SHOULDER
    -- Max equipped: 2 (one per slot)
    -------------------------------------------------------------------------------
    
    ['hoarder_shoulder_purse'] = {
        label = 'Purse',
        type = BagType.SHOULDERBAG,
        allowedSlots = { AttachmentSlot.LEFT_SHOULDER, AttachmentSlot.RIGHT_SHOULDER },
        model = 'prop_ld_handbag',
        capacity = {
            weight = 3000,      -- 3kg bonus
            slots = 4
        },
        offsets = {
            [AttachmentSlot.LEFT_SHOULDER] = {
                pos = vec3(0.15, -0.02, -0.18),
                rot = vec3(0.0, 0.0, 0.0)
            },
            [AttachmentSlot.RIGHT_SHOULDER] = {
                pos = vec3(-0.15, -0.02, -0.18),
                rot = vec3(0.0, 0.0, 180.0)
            }
        },
        restrictsWeapons = false,
        allowsLongGuns = false,
        allowsSnipers = false
    },
    
    ['hoarder_shoulder_messenger'] = {
        label = 'Messenger Bag',
        type = BagType.SHOULDERBAG,
        allowedSlots = { AttachmentSlot.LEFT_SHOULDER, AttachmentSlot.RIGHT_SHOULDER },
        model = 'prop_security_case_01',
        capacity = {
            weight = 7000,      -- 7kg bonus
            slots = 6
        },
        offsets = {
            [AttachmentSlot.LEFT_SHOULDER] = {
                pos = vec3(0.18, -0.05, -0.20),
                rot = vec3(-15.0, 0.0, 10.0)
            },
            [AttachmentSlot.RIGHT_SHOULDER] = {
                pos = vec3(-0.18, -0.05, -0.20),
                rot = vec3(-15.0, 0.0, -10.0)
            }
        },
        restrictsWeapons = false,
        allowsLongGuns = false,
        allowsSnipers = false
    },
    
    ['hoarder_shoulder_duffle'] = {
        label = 'Duffle Bag',
        type = BagType.SHOULDERBAG,
        allowedSlots = { AttachmentSlot.LEFT_SHOULDER, AttachmentSlot.RIGHT_SHOULDER },
        model = 'prop_big_bag_01',           -- Large bag prop (verified native)
        fallbackModel = 'prop_cs_heist_bag_01',  -- Fallback to heist bag
        capacity = {
            weight = 12000,     -- 12kg bonus
            slots = 8
        },
        offsets = {
            [AttachmentSlot.LEFT_SHOULDER] = {
                pos = vec3(0.15, 0.0, -0.15),
                rot = vec3(0.0, 0.0, 90.0)
            },
            [AttachmentSlot.RIGHT_SHOULDER] = {
                pos = vec3(-0.15, 0.0, -0.15),
                rot = vec3(0.0, 0.0, -90.0)
            }
        },
        restrictsWeapons = false,
        allowsLongGuns = true,
        allowsSnipers = false
    },
    
    -------------------------------------------------------------------------------
    -- HANDBAGS
    -- Attach to: LEFT_HAND, RIGHT_HAND
    -- Max equipped: 2 (one per slot)
    -- NOTE: Most handbags restrict weapon usage
    -------------------------------------------------------------------------------
    
    ['hoarder_hand_clutch'] = {
        label = 'Clutch',
        type = BagType.HANDBAG,
        allowedSlots = { AttachmentSlot.LEFT_HAND, AttachmentSlot.RIGHT_HAND },
        model = 'prop_ld_wallet_02',
        capacity = {
            weight = 1000,      -- 1kg bonus
            slots = 2
        },
        offsets = {
            [AttachmentSlot.LEFT_HAND] = {
                pos = vec3(0.0, 0.02, 0.0),
                rot = vec3(90.0, 0.0, 0.0)
            },
            [AttachmentSlot.RIGHT_HAND] = {
                pos = vec3(0.0, 0.02, 0.0),
                rot = vec3(0.0, 0.0, 90.0)
            }
        },
        restrictsWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
    },
    
    ['hoarder_hand_briefcase'] = {
        label = 'Briefcase',
        type = BagType.HANDBAG,
        allowedSlots = { AttachmentSlot.LEFT_HAND, AttachmentSlot.RIGHT_HAND },
        model = 'prop_ld_case_01',
        capacity = {
            weight = 4000,      -- 4kg bonus
            slots = 4
        },
        offsets = {
            [AttachmentSlot.LEFT_HAND] = {
                pos = vec3(0.0, 0.05, 0.0),
                rot = vec3(90.0, 0.0, 0.0)
            },
            [AttachmentSlot.RIGHT_HAND] = {
                pos = vec3(0.0, 0.05, 0.0),
                rot = vec3(0.0, 0.0, 90.0)
            }
        },
        restrictsWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
        
        -- Locking (v2.0) - Briefcase supports all lock types including biometric
        lockable = true,
        allowedLockTypes = { 'pin', 'key', 'padlock', 'biometric' },
        
        -- Durability (v2.0)
        material = 'leather',
        durability = {
            enabled = true,
            maxDurability = 100,
            degradePerOpen = 0.5,
        },
        
        -- Opening Animation (v2.0) - Custom unlatch animation
        openAnimation = {
            dict = 'anim@amb@business@bgen@bgen_no_work@',
            clip = 'sit_phone_check_text_idle_c',
            duration = 1500,
            blockMovement = false,
            upperBodyOnly = true,
        },
    },
    
    ['hoarder_hand_riflecase'] = {
        label = 'Rifle Case',
        type = BagType.HANDBAG,
        allowedSlots = { AttachmentSlot.LEFT_HAND, AttachmentSlot.RIGHT_HAND },
        model = 'prop_gun_case_01',
        capacity = {
            weight = 8000,      -- 8kg bonus
            slots = 4
        },
        offsets = {
            [AttachmentSlot.LEFT_HAND] = {
                pos = vec3(0.0, 0.05, 0.0),
                rot = vec3(90.0, 0.0, 0.0)
            },
            [AttachmentSlot.RIGHT_HAND] = {
                pos = vec3(0.0, 0.05, 0.0),
                rot = vec3(0.0, 0.0, 90.0)
            }
        },
        restrictsWeapons = true,
        allowsLongGuns = true,
        allowsSnipers = true
    },
    
    -------------------------------------------------------------------------------
    -- SHOPPING BAGS
    -------------------------------------------------------------------------------
    
    ['hoarder_hand_shopping_01'] = {
        label = 'Shopping Bag',
        type = BagType.HANDBAG,
        allowedSlots = { AttachmentSlot.LEFT_HAND, AttachmentSlot.RIGHT_HAND },
        model = 'prop_paper_bag_small',
        capacity = {
            weight = 6000,      -- 6kg bonus
            slots = 5
        },
        offsets = {
            [AttachmentSlot.LEFT_HAND] = {
                pos = vec3(0.0, 0.05, -0.03),
                rot = vec3(90.0, 0.0, 0.0)
            },
            [AttachmentSlot.RIGHT_HAND] = {
                pos = vec3(0.0, 0.05, -0.03),
                rot = vec3(0.0, 0.0, 90.0)
            }
        },
        restrictsWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
    },
    
    ['hoarder_hand_shopping_02'] = {
        label = 'Shopping Bag',
        type = BagType.HANDBAG,
        allowedSlots = { AttachmentSlot.LEFT_HAND, AttachmentSlot.RIGHT_HAND },
        model = 'prop_paper_bag_01',
        capacity = {
            weight = 6000,
            slots = 5
        },
        offsets = {
            [AttachmentSlot.LEFT_HAND] = {
                pos = vec3(0.0, 0.05, -0.03),
                rot = vec3(90.0, 0.0, 0.0)
            },
            [AttachmentSlot.RIGHT_HAND] = {
                pos = vec3(0.0, 0.05, -0.03),
                rot = vec3(0.0, 0.0, 90.0)
            }
        },
        restrictsWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
    },
    
    ['hoarder_hand_shopping_03'] = {
        label = 'Shopping Bag',
        type = BagType.HANDBAG,
        allowedSlots = { AttachmentSlot.LEFT_HAND, AttachmentSlot.RIGHT_HAND },
        model = 'prop_cs_shopping_bag',
        capacity = {
            weight = 6000,
            slots = 5
        },
        offsets = {
            [AttachmentSlot.LEFT_HAND] = {
                pos = vec3(0.0, 0.05, -0.05),
                rot = vec3(90.0, 0.0, 0.0)
            },
            [AttachmentSlot.RIGHT_HAND] = {
                pos = vec3(0.0, 0.05, -0.05),
                rot = vec3(0.0, 0.0, 90.0)
            }
        },
        restrictsWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
    },
    
    -------------------------------------------------------------------------------
    -- TWO-HAND CARRY ITEMS
    -- Attach to: TWO_HAND (uses both hands)
    -- Blocks ALL weapons - player cannot use any weapons while carrying
    -- Uses carrying animation/clipset
    -------------------------------------------------------------------------------
    
    ['hoarder_carry_box_sm'] = {
        label = 'Small Box',
        type = BagType.TWOHAND,
        allowedSlots = { AttachmentSlot.TWO_HAND },
        model = 'prop_cs_cardbox_01',  -- Small cardboard box
        capacity = {
            weight = 5000,      -- 5kg bonus
            slots = 4
        },
        offsets = {
            [AttachmentSlot.TWO_HAND] = {
                pos = vec3(0.025, 0.08, 0.255),
                rot = vec3(-87.0, 0.0, 0.0)
            }
        },
        restrictsWeapons = true,  -- Blocks ALL weapons
        blocksAllWeapons = true,  -- Flag for complete weapon block
        allowsLongGuns = false,
        allowsSnipers = false,
        -- Two-hand carry specific settings
        carryClipset = 'anim@heists@box_carry@',
        carryAnim = 'idle',
        movementClipset = 'move_m@bag',
    },
    
    ['hoarder_carry_box_md'] = {
        label = 'Medium Box',
        type = BagType.TWOHAND,
        allowedSlots = { AttachmentSlot.TWO_HAND },
        model = 'prop_box_ammo04a',  -- Medium ammo box
        capacity = {
            weight = 10000,     -- 10kg bonus
            slots = 8
        },
        offsets = {
            [AttachmentSlot.TWO_HAND] = {
                pos = vec3(0.025, 0.08, 0.27),
                rot = vec3(-87.0, 0.0, 0.0)
            }
        },
        restrictsWeapons = true,
        blocksAllWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
        carryClipset = 'anim@heists@box_carry@',
        carryAnim = 'idle',
        movementClipset = 'move_m@bag',
    },
    
    ['hoarder_carry_box_lg'] = {
        label = 'Large Box',
        type = BagType.TWOHAND,
        allowedSlots = { AttachmentSlot.TWO_HAND },
        model = 'hei_prop_heist_box',  -- Large heist box
        capacity = {
            weight = 20000,     -- 20kg bonus
            slots = 15
        },
        offsets = {
            [AttachmentSlot.TWO_HAND] = {
                pos = vec3(0.025, 0.08, 0.29),
                rot = vec3(-87.0, 0.0, 0.0)
            }
        },
        restrictsWeapons = true,
        blocksAllWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
        carryClipset = 'anim@heists@box_carry@',
        carryAnim = 'idle',
        movementClipset = 'move_m@bag',
        
        -- Opening Animation (v2.0) - Put down, open, blocks movement
        openAnimation = {
            dict = 'anim@heists@box_carry@',
            clip = 'idle',
            duration = 2500,
            blockMovement = true,      -- Can't move while opening
            upperBodyOnly = false,
        },
    },
    
    ['hoarder_carry_crate'] = {
        label = 'Wooden Crate',
        type = BagType.TWOHAND,
        allowedSlots = { AttachmentSlot.TWO_HAND },
        model = 'prop_boxpile_04a',  -- Wooden crate
        capacity = {
            weight = 25000,     -- 25kg bonus
            slots = 20
        },
        offsets = {
            [AttachmentSlot.TWO_HAND] = {
                pos = vec3(0.025, 0.1, 0.32),
                rot = vec3(-87.0, 0.0, 0.0)
            }
        },
        restrictsWeapons = true,
        blocksAllWeapons = true,
        allowsLongGuns = true,   -- Can store long guns in crate
        allowsSnipers = true,    -- Can store snipers in crate
        carryClipset = 'anim@heists@box_carry@',
        carryAnim = 'idle',
        movementClipset = 'move_m@bag',
    },
    
    ['hoarder_carry_cooler'] = {
        label = 'Cooler',
        type = BagType.TWOHAND,
        allowedSlots = { AttachmentSlot.TWO_HAND },
        model = 'prop_cooler_01',  -- Cooler box
        capacity = {
            weight = 8000,      -- 8kg bonus
            slots = 6
        },
        offsets = {
            [AttachmentSlot.TWO_HAND] = {
                pos = vec3(0.025, 0.1, 0.25),
                rot = vec3(-87.0, 0.0, 0.0)
            }
        },
        restrictsWeapons = true,
        blocksAllWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
        carryClipset = 'anim@heists@box_carry@',
        carryAnim = 'idle',
        movementClipset = 'move_m@bag',
    },
    
    ['hoarder_carry_toolbox'] = {
        label = 'Toolbox',
        type = BagType.TWOHAND,
        allowedSlots = { AttachmentSlot.TWO_HAND },
        model = 'prop_tool_box_04',  -- Mechanic toolbox
        capacity = {
            weight = 12000,     -- 12kg bonus
            slots = 10
        },
        offsets = {
            [AttachmentSlot.TWO_HAND] = {
                pos = vec3(0.025, 0.08, 0.24),
                rot = vec3(-87.0, 0.0, 0.0)
            }
        },
        restrictsWeapons = true,
        blocksAllWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
        carryClipset = 'anim@heists@box_carry@',
        carryAnim = 'idle',
        movementClipset = 'move_m@bag',
    },
    
    -------------------------------------------------------------------------------
    -- JOB-SPECIFIC BAGS
    -- These bags can only be used by players with specific jobs
    -------------------------------------------------------------------------------
    
    ['hoarder_medic_bag'] = {
        label = 'Medic Bag',
        type = BagType.SHOULDERBAG,
        allowedSlots = { AttachmentSlot.LEFT_SHOULDER, AttachmentSlot.RIGHT_SHOULDER },
        model = 'prop_cs_heist_bag_02',
        capacity = {
            weight = 12000,
            slots = 15
        },
        offsets = {
            [AttachmentSlot.LEFT_SHOULDER] = {
                pos = vec3(-0.25, -0.10, 0.0),
                rot = vec3(0.0, 0.0, -10.0)
            },
            [AttachmentSlot.RIGHT_SHOULDER] = {
                pos = vec3(0.25, -0.10, 0.0),
                rot = vec3(0.0, 0.0, 10.0)
            }
        },
        restrictsWeapons = false,
        allowsLongGuns = false,
        allowsSnipers = false,
        -- Job restriction - only EMS can use
        jobRestriction = { 'ambulance', 'doctor', 'ems' },
    },
    
    ['hoarder_police_duffle'] = {
        label = 'Police Equipment Bag',
        type = BagType.SHOULDERBAG,
        allowedSlots = { AttachmentSlot.LEFT_SHOULDER, AttachmentSlot.RIGHT_SHOULDER },
        model = 'prop_cs_heist_bag_01',
        capacity = {
            weight = 20000,
            slots = 20
        },
        offsets = {
            [AttachmentSlot.LEFT_SHOULDER] = {
                pos = vec3(-0.25, -0.10, 0.0),
                rot = vec3(0.0, 0.0, -10.0)
            },
            [AttachmentSlot.RIGHT_SHOULDER] = {
                pos = vec3(0.25, -0.10, 0.0),
                rot = vec3(0.0, 0.0, 10.0)
            }
        },
        restrictsWeapons = false,
        allowsLongGuns = true,  -- Can store rifles
        allowsSnipers = true,
        -- Job restriction - only police can use
        jobRestriction = { 'police', 'sheriff', 'fbi' },
    },
    
    ['hoarder_mechanic_toolbag'] = {
        label = 'Mechanic Tool Bag',
        type = BagType.SHOULDERBAG,
        allowedSlots = { AttachmentSlot.LEFT_SHOULDER, AttachmentSlot.RIGHT_SHOULDER },
        model = 'prop_tool_bag_01',
        capacity = {
            weight = 15000,
            slots = 12
        },
        offsets = {
            [AttachmentSlot.LEFT_SHOULDER] = {
                pos = vec3(-0.25, -0.10, 0.0),
                rot = vec3(0.0, 0.0, -10.0)
            },
            [AttachmentSlot.RIGHT_SHOULDER] = {
                pos = vec3(0.25, -0.10, 0.0),
                rot = vec3(0.0, 0.0, 10.0)
            }
        },
        restrictsWeapons = false,
        allowsLongGuns = false,
        allowsSnipers = false,
        -- Job restriction - only mechanics can use
        jobRestriction = { 'mechanic', 'tuner', 'bennys' },
    },
    
    -------------------------------------------------------------------------------
    -- DURABILITY EXAMPLE BAGS
    -- These bags wear out over time and need repair
    -------------------------------------------------------------------------------
    
    ['hoarder_paper_bag'] = {
        label = 'Paper Bag',
        type = BagType.HANDBAG,
        allowedSlots = { AttachmentSlot.LEFT_HAND, AttachmentSlot.RIGHT_HAND },
        model = 'prop_paper_bag_01',
        capacity = {
            weight = 3000,
            slots = 3
        },
        offsets = {
            [AttachmentSlot.LEFT_HAND] = {
                pos = vec3(0.0, 0.05, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            },
            [AttachmentSlot.RIGHT_HAND] = {
                pos = vec3(0.0, 0.05, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            }
        },
        restrictsWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
        -- Durability - tears easily
        durability = {
            maxUses = 20,       -- Opens before breaking
            canRepair = false,  -- Cannot be repaired, too cheap
        },
    },
    
    ['hoarder_plastic_bag'] = {
        label = 'Plastic Bag',
        type = BagType.HANDBAG,
        allowedSlots = { AttachmentSlot.LEFT_HAND, AttachmentSlot.RIGHT_HAND },
        model = 'prop_carrier_bag_01',
        capacity = {
            weight = 2000,
            slots = 2
        },
        offsets = {
            [AttachmentSlot.LEFT_HAND] = {
                pos = vec3(0.0, 0.05, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            },
            [AttachmentSlot.RIGHT_HAND] = {
                pos = vec3(0.0, 0.05, 0.0),
                rot = vec3(0.0, 0.0, 0.0)
            }
        },
        restrictsWeapons = true,
        allowsLongGuns = false,
        allowsSnipers = false,
        -- Durability - very fragile
        durability = {
            maxUses = 10,
            canRepair = false,
        },
    },
    
    -------------------------------------------------------------------------------
    -- TUCKED BAGS (No visible prop - concealed carry)
    -- These items add inventory capacity but have no visible model on player
    -------------------------------------------------------------------------------
    
    ['hoarder_mag_holder'] = {
        label = 'Magazine Holder',
        type = BagType.TUCKED,
        allowedSlots = { AttachmentSlot.TUCKED },
        model = nil,  -- No prop
        capacity = {
            weight = 2000,  -- 2kg
            slots = 2
        },
        -- No offsets needed - no prop
        restrictsWeapons = false,
        allowsLongGuns = false,
        allowsSnipers = false,
        -- No item restrictions - can hold any ammo/magazines
    },
    
    ['hoarder_wallet'] = {
        label = 'Wallet',
        type = BagType.TUCKED,
        allowedSlots = { AttachmentSlot.TUCKED },
        model = nil,  -- No prop
        capacity = {
            weight = 1000,  -- 1kg
            slots = 8
        },
        -- No offsets needed - no prop
        restrictsWeapons = false,
        allowsLongGuns = false,
        allowsSnipers = false,
        -- Item whitelist - only these items can be stored
        allowedItems = {
            'id_card',
            'driver_license',
            'weaponlicense',
            'bank_card',
            'cash',
            'black_money',
        },
    }
}

-------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-------------------------------------------------------------------------------

---Get bag configuration by item name
---Also checks variants (v2.0)
---@param itemName string
---@return table|nil
function GetBagConfig(itemName)
    -- Check direct config first
    if Config.Bags[itemName] then
        return Config.Bags[itemName]
    end
    
    -- Check if it's a variant (v2.0)
    if GetMergedVariantConfig then
        local variantConfig = GetMergedVariantConfig(itemName)
        if variantConfig then
            return variantConfig
        end
    end
    
    return nil
end

---Check if an item is a bag
---Also checks variants (v2.0)
---@param itemName string
---@return boolean
function IsBagItem(itemName)
    -- Check direct config
    if Config.Bags[itemName] then
        return true
    end
    
    -- Check variants (v2.0)
    if IsVariantItem then
        return IsVariantItem(itemName)
    end
    
    return false
end

---Get all bags of a specific type
---@param bagType string
---@return table<string, table>
function GetBagsByType(bagType)
    local bags = {}
    for name, config in pairs(Config.Bags) do
        if config.type == bagType then
            bags[name] = config
        end
    end
    return bags
end

-------------------------------------------------------------------------------
-- BAG VARIANTS
-- Color/style variants for bags as separate items
-- Variants inherit ALL properties from base bag, only model/label change
-------------------------------------------------------------------------------

Config.Variants = {
    enabled = true,
    
    -- Variant definitions by base bag
    -- Format: baseBagName = { { suffix, label, model }, ... }
    items = {
        -----------------------------------------------------------------------
        -- BACKPACK VARIANTS
        -----------------------------------------------------------------------
        ['hoarder_backpack_sm'] = {
            {
                suffix = 'black',
                label = 'Small Backpack (Black)',
                model = 'prop_poly_bag_01',
            },
            {
                suffix = 'green',
                label = 'Small Backpack (Green)',
                model = 'prop_michael_backpack',
            },
        },
        
        ['hoarder_backpack_md'] = {
            {
                suffix = 'black',
                label = 'Medium Backpack (Black)',
                model = 'prop_cs_heist_bag_02',
            },
            {
                suffix = 'camo',
                label = 'Medium Backpack (Camo)',
                model = 'p_michael_backpack_s',
            },
        },
        
        ['hoarder_backpack_lg'] = {
            {
                suffix = 'military',
                label = 'Large Backpack (Military)',
                model = 'prop_parachute_bag_01',
            },
        },
        
        -----------------------------------------------------------------------
        -- SHOULDER BAG VARIANTS
        -----------------------------------------------------------------------
        ['hoarder_shoulder_duffle'] = {
            {
                suffix = 'black',
                label = 'Duffle Bag (Black)',
                model = 'hei_p_m_bag_var22_arm_s',
            },
            {
                suffix = 'grey',
                label = 'Duffle Bag (Grey)',
                model = 'prop_ld_suitcase_01',
            },
        },
        
        -----------------------------------------------------------------------
        -- BRIEFCASE VARIANTS
        -----------------------------------------------------------------------
        ['hoarder_hand_briefcase'] = {
            {
                suffix = 'silver',
                label = 'Briefcase (Silver)',
                model = 'prop_security_case_01',
            },
            {
                suffix = 'money',
                label = 'Money Case',
                model = 'prop_cash_case_01',
            },
        },
    },
}

-------------------------------------------------------------------------------
-- VARIANT HELPER FUNCTIONS
-------------------------------------------------------------------------------

---Get the full variant item name
---@param baseBag string
---@param suffix string
---@return string
function GetVariantItemName(baseBag, suffix)
    return baseBag .. '_' .. suffix
end

---Parse a variant item name to get base bag and suffix
---@param itemName string
---@return string|nil baseBag
---@return string|nil suffix
function ParseVariantItemName(itemName)
    if not itemName then return nil, nil end
    
    if Config.Variants and Config.Variants.items then
        for baseBag, variants in pairs(Config.Variants.items) do
            for _, variant in ipairs(variants) do
                local fullName = GetVariantItemName(baseBag, variant.suffix)
                if fullName == itemName then
                    return baseBag, variant.suffix
                end
            end
        end
    end
    
    return nil, nil
end

---Check if an item is a variant
---@param itemName string
---@return boolean
function IsVariantItem(itemName)
    local baseBag, _ = ParseVariantItemName(itemName)
    return baseBag ~= nil
end

---Get variant config by item name
---@param itemName string
---@return table|nil variantConfig
---@return string|nil baseBagName
function GetVariantConfig(itemName)
    if not Config.Variants or not Config.Variants.items then
        return nil, nil
    end
    
    for baseBag, variants in pairs(Config.Variants.items) do
        for _, variant in ipairs(variants) do
            local fullName = GetVariantItemName(baseBag, variant.suffix)
            if fullName == itemName then
                return variant, baseBag
            end
        end
    end
    
    return nil, nil
end

---Get merged config for a variant (base bag config + variant overrides)
---@param itemName string
---@return table|nil
function GetMergedVariantConfig(itemName)
    local variant, baseBag = GetVariantConfig(itemName)
    if not variant or not baseBag then return nil end
    
    local baseConfig = Config.Bags and Config.Bags[baseBag]
    if not baseConfig then return nil end
    
    -- Deep copy base config
    local merged = {}
    for k, v in pairs(baseConfig) do
        if type(v) == 'table' then
            merged[k] = {}
            for k2, v2 in pairs(v) do
                if type(v2) == 'table' then
                    merged[k][k2] = {}
                    for k3, v3 in pairs(v2) do
                        merged[k][k2][k3] = v3
                    end
                else
                    merged[k][k2] = v2
                end
            end
        else
            merged[k] = v
        end
    end
    
    -- Override with variant specifics
    merged.label = variant.label
    merged.model = variant.model
    merged.isVariant = true
    merged.baseBag = baseBag
    merged.variantSuffix = variant.suffix
    
    return merged
end

---Get all variant names for a base bag
---@param baseBag string
---@return table variantNames
function GetVariantNames(baseBag)
    local names = {}
    
    if Config.Variants and Config.Variants.items and Config.Variants.items[baseBag] then
        for _, variant in ipairs(Config.Variants.items[baseBag]) do
            table.insert(names, GetVariantItemName(baseBag, variant.suffix))
        end
    end
    
    return names
end

---Get all registered variants
---@return table { itemName = { baseBag, suffix, label, model } }
function GetAllVariants()
    local all = {}
    
    if Config.Variants and Config.Variants.items then
        for baseBag, variants in pairs(Config.Variants.items) do
            for _, variant in ipairs(variants) do
                local itemName = GetVariantItemName(baseBag, variant.suffix)
                all[itemName] = {
                    baseBag = baseBag,
                    suffix = variant.suffix,
                    label = variant.label,
                    model = variant.model,
                }
            end
        end
    end
    
    return all
end
