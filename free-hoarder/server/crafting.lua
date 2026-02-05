--[[
    Server Crafting Exports - free-hoarder v2.0
    Exports for external crafting resource integration
    
    USAGE:
    -- Get all recipes
    local recipes = exports['free-hoarder']:GetBagRecipes()
    
    -- Get specific recipe
    local recipe = exports['free-hoarder']:GetBagRecipe('hoarder_backpack_md')
    
    -- Check if player can craft
    local canCraft, missing = exports['free-hoarder']:CanPlayerCraftBag(source, 'hoarder_backpack_md')
    
    -- Craft a bag
    local success, error = exports['free-hoarder']:CraftBag(source, 'hoarder_backpack_md')
]]

local ox_inventory = exports.ox_inventory

-------------------------------------------------------------------------------
-- RECIPE EXPORTS
-------------------------------------------------------------------------------

---Get all bag crafting recipes
---@return table { bagName = { {name, count}, ... } }
local function GetBagRecipes()
    return Config.CraftingRecipes or {}
end
exports('GetBagRecipes', GetBagRecipes)

---Get crafting recipe for a specific bag
---@param bagName string
---@return table|nil recipe
local function GetBagRecipe(bagName)
    if not Config.CraftingRecipes then return nil end
    
    -- Check direct match
    if Config.CraftingRecipes[bagName] then
        return Config.CraftingRecipes[bagName]
    end
    
    -- Check if it's a variant - use base bag recipe
    if IsVariantItem and IsVariantItem(bagName) then
        local _, baseBag = GetVariantConfig(bagName)
        if baseBag and Config.CraftingRecipes[baseBag] then
            return Config.CraftingRecipes[baseBag]
        end
    end
    
    return nil
end
exports('GetBagRecipe', GetBagRecipe)

---Get all repair recipes
---@return table { materialType = { {name, count}, ... } }
local function GetRepairRecipes()
    return Config.RepairRecipes or {}
end
exports('GetRepairRecipes', GetRepairRecipes)

---Get repair recipe for a material type
---@param materialType string 'leather', 'nylon', 'plastic', etc.
---@return table recipe
local function GetRepairRecipe(materialType)
    if Config.RepairRecipes and Config.RepairRecipes[materialType] then
        return Config.RepairRecipes[materialType]
    end
    
    -- Default fallback
    return Config.RepairRecipes and Config.RepairRecipes.default or {
        { name = 'fabric', count = 2 },
        { name = 'sewing_kit', count = 1 },
    }
end
exports('GetRepairRecipe', GetRepairRecipe)

---Get all upgrade recipes
---@return table
local function GetUpgradeRecipes()
    return Config.UpgradeRecipes or {}
end
exports('GetUpgradeRecipes', GetUpgradeRecipes)

---Get specific upgrade recipe
---@param upgradeName string
---@return table|nil
local function GetUpgradeRecipe(upgradeName)
    return Config.UpgradeRecipes and Config.UpgradeRecipes[upgradeName]
end
exports('GetUpgradeRecipe', GetUpgradeRecipe)

-------------------------------------------------------------------------------
-- VARIANT EXPORTS
-------------------------------------------------------------------------------

---Get all variant names for a base bag
---@param baseBag string
---@return table variantNames
local function GetVariantNamesExport(baseBag)
    return GetVariantNames and GetVariantNames(baseBag) or {}
end
exports('GetVariantNames', GetVariantNamesExport)

---Get all registered variants
---@return table
local function GetAllVariantsExport()
    return GetAllVariants and GetAllVariants() or {}
end
exports('GetAllVariants', GetAllVariantsExport)

---Check if item is a variant
---@param itemName string
---@return boolean isVariant
---@return string|nil baseBag
local function IsVariantItemExport(itemName)
    if not IsVariantItem then return false, nil end
    
    local isVar = IsVariantItem(itemName)
    if isVar then
        local _, baseBag = GetVariantConfig(itemName)
        return true, baseBag
    end
    return false, nil
end
exports('IsVariantItem', IsVariantItemExport)

---Get merged config for a variant
---@param itemName string
---@return table|nil
local function GetMergedVariantConfigExport(itemName)
    return GetMergedVariantConfig and GetMergedVariantConfig(itemName)
end
exports('GetMergedVariantConfig', GetMergedVariantConfigExport)

-------------------------------------------------------------------------------
-- CRAFTING HELPERS
-------------------------------------------------------------------------------

---Check if player has materials to craft a bag
---@param source number Player server ID
---@param bagName string
---@return boolean canCraft
---@return table|nil missing { {name, need, have}, ... }
local function CanPlayerCraftBag(source, bagName)
    local recipe = GetBagRecipe(bagName)
    if not recipe then
        return false, {{ name = 'unknown', need = 0, have = 0, error = 'No recipe' }}
    end
    
    local missing = {}
    local canCraft = true
    
    for _, ingredient in ipairs(recipe) do
        local count = ox_inventory:GetItemCount(source, ingredient.name) or 0
        if count < ingredient.count then
            canCraft = false
            table.insert(missing, {
                name = ingredient.name,
                need = ingredient.count,
                have = count,
            })
        end
    end
    
    return canCraft, #missing > 0 and missing or nil
end
exports('CanPlayerCraftBag', CanPlayerCraftBag)

---Check if player has materials to repair
---@param source number
---@param materialType string
---@return boolean canRepair
---@return table|nil missing
local function CanPlayerRepairBag(source, materialType)
    local recipe = GetRepairRecipe(materialType)
    
    local missing = {}
    local canRepair = true
    
    for _, ingredient in ipairs(recipe) do
        local count = ox_inventory:GetItemCount(source, ingredient.name) or 0
        if count < ingredient.count then
            canRepair = false
            table.insert(missing, {
                name = ingredient.name,
                need = ingredient.count,
                have = count,
            })
        end
    end
    
    return canRepair, #missing > 0 and missing or nil
end
exports('CanPlayerRepairBag', CanPlayerRepairBag)

---Craft a bag (consumes materials, gives bag)
---@param source number
---@param bagName string
---@param metadata table|nil Optional initial metadata
---@return boolean success
---@return string|nil error
local function CraftBag(source, bagName, metadata)
    if not Config.Crafting or not Config.Crafting.enabled then
        return false, 'Crafting is disabled'
    end
    
    -- Get bag config
    local bagConfig = GetBagConfigWithVariants and GetBagConfigWithVariants(bagName)
    if not bagConfig then
        bagConfig = Config.Bags and Config.Bags[bagName]
    end
    
    if not bagConfig then
        return false, 'Invalid bag type'
    end
    
    -- Check materials
    local canCraft, missing = CanPlayerCraftBag(source, bagName)
    if not canCraft then
        local list = {}
        for _, m in ipairs(missing or {}) do
            table.insert(list, ('%dx %s'):format(m.need - m.have, m.name))
        end
        return false, 'Missing: ' .. table.concat(list, ', ')
    end
    
    -- Check can carry
    if not ox_inventory:CanCarryItem(source, bagName, 1) then
        return false, 'Inventory full'
    end
    
    -- Remove materials
    local recipe = GetBagRecipe(bagName)
    for _, ingredient in ipairs(recipe) do
        ox_inventory:RemoveItem(source, ingredient.name, ingredient.count)
    end
    
    -- Create bag metadata
    local containerId = ('bag_%s_%d_%d'):format(bagName, source, os.time())
    local bagMetadata = metadata or {}
    bagMetadata.containerId = containerId
    bagMetadata.durability = 100
    bagMetadata.craftedBy = source
    bagMetadata.craftedAt = os.time()
    
    -- Give bag
    local success = ox_inventory:AddItem(source, bagName, 1, bagMetadata)
    
    if success then
        -- Register container
        if RegisterBagContainer then
            RegisterBagContainer(source, bagName, containerId)
        end
        
        -- Trigger event
        if TriggerBagCrafted then
            TriggerBagCrafted({
                source = source,
                bagName = bagName,
                containerId = containerId,
            })
        end
        
        -- Discord log
        if Config.Crafting.logToDiscord and SendToDiscord then
            local Player = exports.qbx_core:GetPlayer(source)
            local name = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Unknown'
            
            SendToDiscord(
                '🛠️ Bag Crafted',
                ('**Player:** %s (ID: %d)\n**Bag:** %s'):format(name, source, bagName),
                5814783
            )
        end
        
        return true, nil
    else
        -- Refund on failure
        for _, ingredient in ipairs(recipe) do
            ox_inventory:AddItem(source, ingredient.name, ingredient.count)
        end
        return false, 'Failed to create bag'
    end
end
exports('CraftBag', CraftBag)

---Upgrade a bag to a larger version
---@param source number
---@param upgradeName string
---@return boolean success
---@return string|nil error
local function UpgradeBag(source, upgradeName)
    local recipe = GetUpgradeRecipe(upgradeName)
    if not recipe then
        return false, 'Invalid upgrade'
    end
    
    -- Check has input bag
    local count = ox_inventory:GetItemCount(source, recipe.input) or 0
    if count < 1 then
        return false, 'Missing input bag'
    end
    
    -- Check materials
    local missing = {}
    for _, mat in ipairs(recipe.materials) do
        local have = ox_inventory:GetItemCount(source, mat.name) or 0
        if have < mat.count then
            table.insert(missing, ('%dx %s'):format(mat.count - have, mat.name))
        end
    end
    
    if #missing > 0 then
        return false, 'Missing: ' .. table.concat(missing, ', ')
    end
    
    -- Check can carry output
    if not ox_inventory:CanCarryItem(source, recipe.output, 1) then
        return false, 'Cannot carry upgraded bag'
    end
    
    -- Find input bag with metadata
    local items = ox_inventory:GetInventoryItems(source)
    local inputSlot, inputMeta = nil, nil
    
    for slot, item in pairs(items) do
        if item.name == recipe.input then
            inputSlot = slot
            inputMeta = item.metadata
            break
        end
    end
    
    if not inputSlot then
        return false, 'Bag not found'
    end
    
    -- Remove input and materials
    ox_inventory:RemoveItem(source, recipe.input, 1, nil, inputSlot)
    for _, mat in ipairs(recipe.materials) do
        ox_inventory:RemoveItem(source, mat.name, mat.count)
    end
    
    -- Create new container, transfer contents
    local newContainerId = ('bag_%s_%d_%d'):format(recipe.output, source, os.time())
    local oldContainerId = inputMeta and inputMeta.containerId
    
    if oldContainerId then
        -- Get output bag config for container registration
        local outputConfig = GetBagConfigWithVariants and GetBagConfigWithVariants(recipe.output)
        if not outputConfig then
            outputConfig = Config.Bags and Config.Bags[recipe.output]
        end
        
        if outputConfig then
            ox_inventory:RegisterStash(
                newContainerId,
                outputConfig.label or 'Bag',
                outputConfig.capacity.slots,
                outputConfig.capacity.weight
            )
            
            -- Transfer items from old to new
            local oldContents = ox_inventory:GetInventory(oldContainerId, false)
            if oldContents and oldContents.items then
                for _, item in pairs(oldContents.items) do
                    if item then
                        ox_inventory:AddItem(newContainerId, item.name, item.count, item.metadata)
                    end
                end
            end
        end
    end
    
    -- Give upgraded bag
    local newMeta = {
        containerId = newContainerId,
        durability = 100,
        upgradedFrom = recipe.input,
        upgradedAt = os.time(),
    }
    
    ox_inventory:AddItem(source, recipe.output, 1, newMeta)
    
    return true, nil
end
exports('UpgradeBag', UpgradeBag)

-------------------------------------------------------------------------------
-- INITIALIZATION
-------------------------------------------------------------------------------

CreateThread(function()
    Wait(1000)
    
    local recipeCount = 0
    if Config.CraftingRecipes then
        for _ in pairs(Config.CraftingRecipes) do
            recipeCount = recipeCount + 1
        end
    end
    
    local variantCount = 0
    if Config.Variants and Config.Variants.items then
        for _, variants in pairs(Config.Variants.items) do
            variantCount = variantCount + #variants
        end
    end
    
    print(('[free-hoarder] Crafting system: %d recipes, %d variants'):format(recipeCount, variantCount))
end)
