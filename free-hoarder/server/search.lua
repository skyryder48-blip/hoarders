--[[
    Server Search - free-hoarder v2.0
    Server-side validation and logic for player search/frisk system
]]

-------------------------------------------------------------------------------
-- RESTRAINT VERIFICATION
-------------------------------------------------------------------------------

---Check if a player is restrained (server-side validation)
---@param source number Player server ID
---@return boolean isRestrained
---@return string|nil reason 'handcuffed' or 'handsup'
function IsPlayerRestrainedServer(source)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return false, nil end
    
    -- Check handcuffed via metadata
    if Player.PlayerData.metadata and Player.PlayerData.metadata.ishandcuffed then
        return true, 'handcuffed'
    end
    
    -- Check state bags for various restraint states
    local playerState = Player(source).state
    if playerState then
        if playerState.ishandcuffed or playerState.isCuffed or playerState.handcuffed then
            return true, 'handcuffed'
        end
        if playerState.handsUp or playerState.handsup or playerState.isHandsUp then
            return true, 'handsup'
        end
    end
    
    return false, nil
end

---Verify restraint state callback
lib.callback.register('free_hoarder:verifyPlayerRestrained', function(source, targetServerId)
    return IsPlayerRestrainedServer(targetServerId)
end)

-------------------------------------------------------------------------------
-- SEARCH PLAYER
-------------------------------------------------------------------------------

---Get a player's equipped bags for searching
---@param searcherSource number Who is searching
---@param targetSource number Who is being searched
---@return boolean success
---@return table|nil bags
---@return string|nil targetName
---@return string|nil error
function GetPlayerBagsForSearch(searcherSource, targetSource)
    -- Validate target exists
    local TargetPlayer = exports.qbx_core:GetPlayer(targetSource)
    if not TargetPlayer then
        return false, nil, nil, 'Player not found'
    end
    
    local targetName = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
    
    -- Verify target is restrained
    local isRestrained, reason = IsPlayerRestrainedServer(targetSource)
    if not isRestrained then
        return false, nil, targetName, 'Target is not restrained'
    end
    
    -- Verify distance
    local searcherPed = GetPlayerPed(searcherSource)
    local targetPed = GetPlayerPed(targetSource)
    
    if not searcherPed or not targetPed or searcherPed == 0 or targetPed == 0 then
        return false, nil, targetName, 'Invalid player state'
    end
    
    local searcherCoords = GetEntityCoords(searcherPed)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(searcherCoords - targetCoords)
    
    local maxDistance = Config.Search and Config.Search.searchDistance or 3.0
    if distance > maxDistance then
        return false, nil, targetName, 'Too far away'
    end
    
    -- Get target's equipped bags
    local bags = EquippedBags[targetSource]
    if not bags or not next(bags) then
        return true, {}, targetName, nil  -- Success but no bags
    end
    
    -- Build bag data for client
    local bagList = {}
    for slotName, bagData in pairs(bags) do
        local bagConfig = GetBagConfig(bagData.bagName)
        
        bagList[slotName] = {
            bagName = bagData.bagName,
            label = bagConfig and bagConfig.label or bagData.bagName,
            type = bagConfig and bagConfig.type or 'backpack',
            containerId = bagData.containerId,
            isLocked = bagData.lock and bagData.lock.isLocked or false,
            lockType = bagData.lock and bagData.lock.type or nil,
            durability = bagData.durability or 100
        }
    end
    
    return true, bagList, targetName, nil
end

---Search player callback
lib.callback.register('free_hoarder:searchPlayer', function(source, targetServerId)
    local success, bags, targetName, error = GetPlayerBagsForSearch(source, targetServerId)
    
    if success then
        -- Log the search
        LogSearchAttempt(source, targetServerId, 'search')
        
        -- Notify target they're being searched
        if Config.Search and Config.Search.notifyTarget then
            NotifyPlayer(targetServerId, {
                title = 'Being Searched',
                description = 'Someone is searching your bags',
                type = 'warning'
            })
        end
    end
    
    return success, bags, targetName, error
end)

-------------------------------------------------------------------------------
-- OPEN SEARCHED BAG
-------------------------------------------------------------------------------

---Open a searched bag's stash for viewing
lib.callback.register('free_hoarder:openSearchedBag', function(source, targetServerId, slotName)
    -- Re-validate restraint
    local isRestrained = IsPlayerRestrainedServer(targetServerId)
    if not isRestrained then
        return false, 'Target is no longer restrained'
    end
    
    -- Get bag data
    local bags = EquippedBags[targetServerId]
    if not bags or not bags[slotName] then
        return false, 'Bag not found'
    end
    
    local bagData = bags[slotName]
    
    -- Check if locked
    if bagData.lock and bagData.lock.isLocked then
        return false, 'Bag is locked'
    end
    
    -- Open the stash for the searcher
    if bagData.containerId then
        exports.ox_inventory:forceOpenInventory(source, 'stash', bagData.containerId)
        return true, nil
    end
    
    return false, 'No container'
end)

-------------------------------------------------------------------------------
-- BYPASS SEARCHED BAG LOCK
-------------------------------------------------------------------------------

---Check if searcher can bypass a lock
lib.callback.register('free_hoarder:canBypassSearchedBag', function(source, targetServerId, slotName, bypassType)
    -- Re-validate restraint
    local isRestrained = IsPlayerRestrainedServer(targetServerId)
    if not isRestrained then
        return false, 'Target is no longer restrained', nil
    end
    
    -- Get bag data
    local bags = EquippedBags[targetServerId]
    if not bags or not bags[slotName] then
        return false, 'Bag not found', nil
    end
    
    local bagData = bags[slotName]
    if not bagData.lock or not bagData.lock.isLocked then
        return false, 'Bag is not locked', nil
    end
    
    -- Check bypass items based on type
    if bypassType == 'pin' then
        local bypassItems = Config.Locking.pin.bypassItems or {'hacking_device', 'laptop'}
        local hasAll, missing = HasAllBypassItems(source, bypassItems)
        if not hasAll then
            return false, 'Missing: ' .. (missing or 'required items'), nil
        end
        return true, nil, {
            time = Config.Locking.pin.bypassTime or 15000,
            successRate = Config.Locking.pin.bypassSuccessRate or 85
        }
        
    elseif bypassType == 'key' then
        local bypassItems = Config.Locking.key.bypassItems or Config.Locking.padlock.bypassItems
        local bestItem = GetBestBypassItem(source, bypassItems)
        if not bestItem then
            return false, 'Need lockpick or tools', nil
        end
        local bypassTime = bagData.lock.type == 'padlock' 
            and (Config.Locking.padlock.bypassTime or 10000)
            or (Config.Locking.key.bypassTime or 8000)
        return true, nil, {
            time = bypassTime,
            successRate = bestItem.chance,
            breakChance = bestItem.breakChance,
            item = bestItem.item
        }
        
    elseif bypassType == 'biometric' then
        local bypassItems = Config.Locking.biometric.bypassItems or {'advanced_hacking_device', 'laptop'}
        local hasAll, missing = HasAllBypassItems(source, bypassItems)
        if not hasAll then
            return false, 'Missing: ' .. (missing or 'required items'), nil
        end
        return true, nil, {
            time = Config.Locking.biometric.bypassTime or 25000,
            successRate = Config.Locking.biometric.bypassSuccessRate or 50
        }
    end
    
    return false, 'Invalid bypass type', nil
end)

---Complete bypass on searched bag
lib.callback.register('free_hoarder:completeSearchedBagBypass', function(source, targetServerId, slotName, bypassType, bypassItem)
    -- Re-validate restraint
    local isRestrained = IsPlayerRestrainedServer(targetServerId)
    if not isRestrained then
        return false, 'Target is no longer restrained'
    end
    
    -- Get bag data
    local bags = EquippedBags[targetServerId]
    if not bags or not bags[slotName] then
        return false, 'Bag not found'
    end
    
    local bagData = bags[slotName]
    if not bagData.lock or not bagData.lock.isLocked then
        return false, 'Bag is not locked'
    end
    
    -- Handle bypass based on type
    local success = false
    local message = ''
    
    if bypassType == 'pin' then
        local successRate = Config.Locking.pin.bypassSuccessRate or 85
        if math.random(1, 100) <= successRate then
            success = true
            message = 'PIN lock bypassed'
        else
            message = 'Bypass failed - security held'
        end
        
    elseif bypassType == 'key' then
        local bypassItems = Config.Locking.key.bypassItems or Config.Locking.padlock.bypassItems
        local itemData = nil
        for _, data in ipairs(bypassItems) do
            if data.item == bypassItem then
                itemData = data
                break
            end
        end
        
        if not itemData then
            return false, 'Invalid tool'
        end
        
        -- Check for tool break
        if math.random(1, 100) <= itemData.breakChance then
            exports.ox_inventory:RemoveItem(source, bypassItem, 1)
            return false, 'Your ' .. bypassItem .. ' broke!'
        end
        
        if math.random(1, 100) <= itemData.chance then
            success = true
            message = 'Lock picked'
        else
            message = 'Failed to pick lock'
        end
        
    elseif bypassType == 'biometric' then
        local successRate = Config.Locking.biometric.bypassSuccessRate or 50
        if math.random(1, 100) <= successRate then
            success = true
            message = 'Biometric bypassed'
        else
            message = 'Bypass failed - alert triggered'
        end
    end
    
    if success then
        -- Unlock the bag
        bagData.lock.isLocked = false
        EquippedBags[targetServerId][slotName] = bagData
        
        -- Sync to target's client
        TriggerClientEvent('free_hoarder:bagLockUpdated', targetServerId, slotName, bagData.lock)
        
        -- Notify target
        if Config.Search and Config.Search.notifyOnBypass then
            local bagConfig = GetBagConfig(bagData.bagName)
            NotifyPlayer(targetServerId, {
                title = 'Bag Unlocked',
                description = (bagConfig and bagConfig.label or 'Your bag') .. ' lock was bypassed!',
                type = 'error'
            })
        end
        
        -- Log bypass
        LogSearchAttempt(source, targetServerId, 'bypass', bypassType)
        
        -- Trigger event
        if TriggerBagLockBypassed then
            TriggerBagLockBypassed({
                source = source,
                targetSource = targetServerId,
                bagName = bagData.bagName,
                slotName = slotName,
                lockType = bagData.lock.type,
                bypassMethod = bypassType
            })
        end
    end
    
    return success, message
end)

---Force open a searched bag (destroy lock)
lib.callback.register('free_hoarder:forceOpenSearchedBag', function(source, targetServerId, slotName)
    -- Re-validate restraint
    local isRestrained = IsPlayerRestrainedServer(targetServerId)
    if not isRestrained then
        return false, 'Target is no longer restrained'
    end
    
    -- Get bag data
    local bags = EquippedBags[targetServerId]
    if not bags or not bags[slotName] then
        return false, 'Bag not found'
    end
    
    local bagData = bags[slotName]
    
    -- Remove the lock entirely
    bagData.lock = nil
    EquippedBags[targetServerId][slotName] = bagData
    
    -- Update metadata
    UpdateBagMetadataLock(targetServerId, bagData.bagName, bagData.containerId, nil)
    
    -- Sync to target's client
    TriggerClientEvent('free_hoarder:bagLockUpdated', targetServerId, slotName, nil)
    
    -- Notify target
    local bagConfig = GetBagConfig(bagData.bagName)
    NotifyPlayer(targetServerId, {
        title = 'Lock Destroyed',
        description = (bagConfig and bagConfig.label or 'Your bag') .. ' lock was broken!',
        type = 'error'
    })
    
    -- Log
    LogSearchAttempt(source, targetServerId, 'force_open')
    
    return true, nil
end)

-------------------------------------------------------------------------------
-- TAKE BAG
-------------------------------------------------------------------------------

---Get bags available to take from a player
lib.callback.register('free_hoarder:getPlayerBagsForTake', function(source, targetServerId)
    return GetPlayerBagsForSearch(source, targetServerId)
end)

---Take a bag from a player
lib.callback.register('free_hoarder:takeBagFromPlayer', function(source, targetServerId, slotName)
    -- Re-validate restraint
    local isRestrained = IsPlayerRestrainedServer(targetServerId)
    if not isRestrained then
        return false, 'Target is no longer restrained'
    end
    
    -- Validate distance
    local searcherPed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(targetServerId)
    
    if not searcherPed or not targetPed then
        return false, 'Invalid player state'
    end
    
    local searcherCoords = GetEntityCoords(searcherPed)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(searcherCoords - targetCoords)
    
    local maxDistance = Config.Search and Config.Search.takeDistance or 2.0
    if distance > maxDistance then
        return false, 'Too far away'
    end
    
    -- Get bag data
    local bags = EquippedBags[targetServerId]
    if not bags or not bags[slotName] then
        return false, 'Bag not found'
    end
    
    local bagData = bags[slotName]
    local bagConfig = GetBagConfig(bagData.bagName)
    
    -- Check if searcher has room for the bag
    local canCarry = exports.ox_inventory:CanCarryItem(source, bagData.bagName, 1)
    if not canCarry then
        return false, 'You cannot carry this bag'
    end
    
    -- Find the bag item in target's inventory
    local targetItems = exports.ox_inventory:GetInventoryItems(targetServerId)
    local bagSlot = nil
    local bagMetadata = nil
    
    for slot, item in pairs(targetItems) do
        if item.name == bagData.bagName and item.metadata and item.metadata.containerId == bagData.containerId then
            bagSlot = slot
            bagMetadata = item.metadata
            break
        end
    end
    
    if not bagSlot then
        return false, 'Could not find bag item'
    end
    
    -- Remove bag from target
    exports.ox_inventory:RemoveItem(targetServerId, bagData.bagName, 1, bagMetadata, bagSlot)
    
    -- Give bag to searcher (with same metadata including contents)
    exports.ox_inventory:AddItem(source, bagData.bagName, 1, bagMetadata)
    
    -- Notify target
    local bagLabel = bagConfig and bagConfig.label or bagData.bagName
    NotifyPlayer(targetServerId, {
        title = 'Bag Taken',
        description = 'Someone took your ' .. bagLabel,
        type = 'error'
    })
    
    -- Log
    LogSearchAttempt(source, targetServerId, 'take', bagData.bagName)
    
    -- Trigger event
    if TriggerBagTaken then
        TriggerBagTaken({
            source = source,
            targetSource = targetServerId,
            bagName = bagData.bagName,
            bagLabel = bagLabel,
            slotName = slotName
        })
    end
    
    return true, nil
end)

-------------------------------------------------------------------------------
-- DISCORD LOGGING
-------------------------------------------------------------------------------

function LogSearchAttempt(source, targetSource, action, detail)
    if not Config.Search or not Config.Search.logToDiscord then return end
    if not SendToDiscord then return end
    
    local SearcherPlayer = exports.qbx_core:GetPlayer(source)
    local TargetPlayer = exports.qbx_core:GetPlayer(targetSource)
    
    local searcherName = SearcherPlayer and (SearcherPlayer.PlayerData.charinfo.firstname .. ' ' .. SearcherPlayer.PlayerData.charinfo.lastname) or 'Unknown'
    local targetName = TargetPlayer and (TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname) or 'Unknown'
    
    local actionLabels = {
        search = '🔍 Player Searched',
        bypass = '🔓 Lock Bypassed',
        force_open = '🔨 Lock Forced',
        take = '👜 Bag Taken'
    }
    
    local title = actionLabels[action] or 'Search Action'
    local detailText = detail and ('\n**Detail:** %s'):format(detail) or ''
    
    SendToDiscord(
        title,
        ('**Searcher:** %s (ID: %d)\n**Target:** %s (ID: %d)%s'):format(
            searcherName, source, targetName, targetSource, detailText
        ),
        action == 'take' and 15158332 or 5814783  -- Orange for take, blue for others
    )
end
