--[[
    Server Locking - free-hoarder v2.0
    Server-side lock management, validation, and bypass handling
]]

-------------------------------------------------------------------------------
-- LOCK MANAGEMENT
-------------------------------------------------------------------------------

---Set a lock on a player's bag
---@param source number Player server ID
---@param slotName string Attachment slot
---@param lockType string LockType enum value
---@param lockData table Additional lock data (code, keyId, etc)
---@return boolean success
---@return string|nil error
function SetBagLockServer(source, slotName, lockType, lockData)
    if not source or source <= 0 then
        return false, 'Invalid player'
    end
    
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No equipped bags'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData then
        return false, 'No bag in slot'
    end
    
    -- Check if bag supports this lock type
    local bagConfig = GetBagConfig(bagData.bagName)
    if not bagConfig then
        return false, 'Unknown bag type'
    end
    
    if not bagConfig.lockable then
        return false, 'This bag cannot be locked'
    end
    
    -- Check if lock type is allowed for this bag
    if bagConfig.allowedLockTypes then
        local allowed = false
        for _, lt in ipairs(bagConfig.allowedLockTypes) do
            if lt == lockType then
                allowed = true
                break
            end
        end
        if not allowed then
            return false, 'This lock type is not compatible with this bag'
        end
    end
    
    -- Build lock structure
    local lock = {
        type = lockType,
        isLocked = true,
        setAt = os.time(),
        setBy = source
    }
    
    -- Add type-specific data
    if lockType == LockType.PIN then
        if not lockData.code or #lockData.code ~= (Config.Locking.pin.digits or 4) then
            return false, 'Invalid PIN code'
        end
        lock.code = lockData.code
        lock.failedAttempts = 0
        lock.lockedUntil = 0
        
    elseif lockType == LockType.KEY then
        lock.keyId = lockData.keyId or GenerateKeyId()
        -- Create key item for player
        CreateKeyItem(source, lock.keyId, bagData.bagName, bagConfig.label)
        
    elseif lockType == LockType.PADLOCK then
        -- Check if player has a padlock item
        local padlockItem = Config.Locking.padlock.padlockItem or 'padlock'
        local hasPadlock = exports.ox_inventory:GetItemCount(source, padlockItem)
        if not hasPadlock or hasPadlock < 1 then
            return false, 'You need a padlock to lock this bag'
        end
        -- Remove padlock item
        exports.ox_inventory:RemoveItem(source, padlockItem, 1)
        
        lock.keyId = lockData.keyId or GeneratePadlockId()
        -- Create padlock key item for player
        CreatePadlockKeyItem(source, lock.keyId, bagData.bagName, bagConfig.label)
        
    elseif lockType == LockType.BIOMETRIC then
        -- Get player identifier for biometric
        local Player = exports.qbx_core:GetPlayer(source)
        if not Player then
            return false, 'Could not get player data'
        end
        lock.ownerId = Player.PlayerData.citizenid
        lock.ownerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    else
        return false, 'Invalid lock type'
    end
    
    -- Store lock in bag data
    EquippedBags[source][slotName].lock = lock
    
    -- Update bag metadata in inventory
    UpdateBagMetadataLock(source, bagData.bagName, bagData.containerId, lock)
    
    -- Sync to client
    TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lock)
    
    -- Trigger event hook
    if TriggerBagLocked then
        TriggerBagLocked({
            source = source,
            bagName = bagData.bagName,
            slotName = slotName,
            lockType = lockType
        })
    end
    
    -- Log to Discord
    if Config.Locking.logBypasses and LogBagLocked then
        LogBagLocked(source, bagData.bagName, lockType)
    end
    
    return true, nil
end

---Remove lock from a player's bag
---@param source number Player server ID
---@param slotName string Attachment slot
---@return boolean success
---@return string|nil error
function RemoveBagLockServer(source, slotName)
    if not source or source <= 0 then
        return false, 'Invalid player'
    end
    
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No equipped bags'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData then
        return false, 'No bag in slot'
    end
    
    if not bagData.lock then
        return false, 'Bag is not locked'
    end
    
    local lockType = bagData.lock.type
    
    -- Clear lock
    EquippedBags[source][slotName].lock = nil
    
    -- Update bag metadata in inventory
    UpdateBagMetadataLock(source, bagData.bagName, bagData.containerId, nil)
    
    -- Sync to client
    TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, nil)
    
    -- Trigger event hook
    if TriggerBagUnlocked then
        TriggerBagUnlocked({
            source = source,
            bagName = bagData.bagName,
            slotName = slotName,
            lockType = lockType
        })
    end
    
    return true, nil
end

---Update bag item metadata with lock info
---@param source number
---@param bagName string
---@param containerId string
---@param lock table|nil
function UpdateBagMetadataLock(source, bagName, containerId, lock)
    local items = exports.ox_inventory:GetInventoryItems(source)
    if not items then return end
    
    for slot, item in pairs(items) do
        if item.name == bagName and item.metadata and item.metadata.containerId == containerId then
            local metadata = item.metadata or {}
            metadata.lock = lock
            exports.ox_inventory:SetMetadata(source, slot, metadata)
            return
        end
    end
end

-------------------------------------------------------------------------------
-- KEY ITEM CREATION
-------------------------------------------------------------------------------

---Create a key item for a key-locked bag
---@param source number
---@param keyId string
---@param bagName string
---@param bagLabel string
function CreateKeyItem(source, keyId, bagName, bagLabel)
    local keyItem = Config.Locking.key.keyItem or 'hoarder_bag_key'
    
    exports.ox_inventory:AddItem(source, keyItem, 1, {
        keyId = keyId,
        bagName = bagName,
        label = 'Key for ' .. (bagLabel or bagName),
        description = 'Unlocks a specific bag'
    })
    
    print(('[free-hoarder] Created key %s for player %d'):format(keyId, source))
end

---Create a padlock key item
---@param source number
---@param keyId string
---@param bagName string
---@param bagLabel string
function CreatePadlockKeyItem(source, keyId, bagName, bagLabel)
    local keyItem = Config.Locking.padlock.keyItem or 'hoarder_padlock_key'
    
    exports.ox_inventory:AddItem(source, keyItem, 1, {
        keyId = keyId,
        bagName = bagName,
        label = 'Padlock Key',
        description = 'Key for a padlock on ' .. (bagLabel or bagName)
    })
    
    print(('[free-hoarder] Created padlock key %s for player %d'):format(keyId, source))
end

-------------------------------------------------------------------------------
-- LOCK VERIFICATION CALLBACKS
-------------------------------------------------------------------------------

---Verify PIN code
lib.callback.register('free_hoarder:verifyPIN', function(source, slotName, enteredCode)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    local lock = bagData.lock
    if lock.type ~= LockType.PIN then
        return false, 'Not a PIN lock'
    end
    
    -- Check lockout
    if lock.lockedUntil and lock.lockedUntil > os.time() then
        local remaining = lock.lockedUntil - os.time()
        return false, ('Locked out for %d seconds'):format(remaining)
    end
    
    -- Verify code
    if enteredCode == lock.code then
        -- Correct - unlock
        lock.isLocked = false
        lock.failedAttempts = 0
        EquippedBags[source][slotName].lock = lock
        TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lock)
        return true, nil
    else
        -- Wrong code
        lock.failedAttempts = (lock.failedAttempts or 0) + 1
        local maxAttempts = Config.Locking.pin.maxAttempts or 3
        
        if lock.failedAttempts >= maxAttempts then
            -- Lockout
            lock.lockedUntil = os.time() + (Config.Locking.pin.lockoutTime or 60)
            lock.failedAttempts = 0
            EquippedBags[source][slotName].lock = lock
            TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lock)
            return false, 'Too many attempts. Locked out.'
        end
        
        EquippedBags[source][slotName].lock = lock
        local remaining = maxAttempts - lock.failedAttempts
        return false, ('Wrong PIN. %d attempts remaining'):format(remaining)
    end
end)

---Verify key item
lib.callback.register('free_hoarder:verifyKey', function(source, slotName)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    local lock = bagData.lock
    if lock.type ~= LockType.KEY and lock.type ~= LockType.PADLOCK then
        return false, 'Not a key/padlock lock'
    end
    
    -- Check if player has matching key
    local keyItem = lock.type == LockType.KEY 
        and (Config.Locking.key.keyItem or 'hoarder_bag_key')
        or (Config.Locking.padlock.keyItem or 'hoarder_padlock_key')
    
    local items = exports.ox_inventory:GetInventoryItems(source)
    if not items then
        return false, 'Could not check inventory'
    end
    
    for _, item in pairs(items) do
        if item.name == keyItem and item.metadata and item.metadata.keyId == lock.keyId then
            -- Found matching key - unlock
            lock.isLocked = false
            EquippedBags[source][slotName].lock = lock
            TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lock)
            return true, nil
        end
    end
    
    return false, 'You don\'t have the right key'
end)

---Verify biometric (owner check)
lib.callback.register('free_hoarder:verifyBiometric', function(source, slotName)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    local lock = bagData.lock
    if lock.type ~= LockType.BIOMETRIC then
        return false, 'Not a biometric lock'
    end
    
    -- Check if player is the owner
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then
        return false, 'Could not verify identity'
    end
    
    if Player.PlayerData.citizenid == lock.ownerId then
        -- Owner verified - unlock
        lock.isLocked = false
        EquippedBags[source][slotName].lock = lock
        TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lock)
        return true, nil
    end
    
    return false, 'Biometric mismatch - not authorized'
end)

---Re-lock a bag (toggle lock state)
lib.callback.register('free_hoarder:relockBag', function(source, slotName)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    local lock = bagData.lock
    lock.isLocked = true
    EquippedBags[source][slotName].lock = lock
    TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lock)
    
    return true, nil
end)

---Change PIN code
lib.callback.register('free_hoarder:changePIN', function(source, slotName, currentCode, newCode)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    local lock = bagData.lock
    if lock.type ~= LockType.PIN then
        return false, 'Not a PIN lock'
    end
    
    -- Verify current code
    if currentCode ~= lock.code then
        return false, 'Current PIN is incorrect'
    end
    
    -- Validate new code
    local digits = Config.Locking.pin.digits or 4
    if not newCode or #newCode ~= digits or not newCode:match('^%d+$') then
        return false, 'New PIN must be ' .. digits .. ' digits'
    end
    
    -- Update code
    lock.code = newCode
    EquippedBags[source][slotName].lock = lock
    UpdateBagMetadataLock(source, bagData.bagName, bagData.containerId, lock)
    TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lock)
    
    return true, nil
end)

-------------------------------------------------------------------------------
-- BYPASS CALLBACKS
-------------------------------------------------------------------------------

---Attempt to bypass PIN lock
lib.callback.register('free_hoarder:bypassPIN', function(source, slotName)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    local lock = bagData.lock
    if lock.type ~= LockType.PIN then
        return false, 'Not a PIN lock'
    end
    
    -- Check required items
    local bypassItems = Config.Locking.pin.bypassItems or {'hacking_device', 'laptop'}
    local hasAll, missing = HasAllBypassItems(source, bypassItems)
    
    if not hasAll then
        return false, 'Missing required item: ' .. (missing or 'unknown'), nil
    end
    
    -- Return bypass time and success rate for client to handle progress
    return true, nil, {
        time = Config.Locking.pin.bypassTime or 15000,
        successRate = Config.Locking.pin.bypassSuccessRate or 85
    }
end)

---Complete PIN bypass (called after progress bar)
lib.callback.register('free_hoarder:completePINBypass', function(source, slotName)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    -- Roll for success
    local successRate = Config.Locking.pin.bypassSuccessRate or 85
    local roll = math.random(1, 100)
    
    if roll <= successRate then
        -- Success - unlock and reset PIN
        local lock = bagData.lock
        lock.isLocked = false
        lock.code = nil  -- PIN is reset
        EquippedBags[source][slotName].lock = lock
        TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lock)
        
        -- Trigger event
        if TriggerBagLockBypassed then
            TriggerBagLockBypassed({
                source = source,
                bagName = bagData.bagName,
                slotName = slotName,
                lockType = LockType.PIN,
                bypassMethod = 'hack'
            })
        end
        
        -- Log
        if Config.Locking.logBypasses and LogBagBypassed then
            LogBagBypassed(source, bagData.bagName, LockType.PIN, 'hack')
        end
        
        return true, 'Lock bypassed. PIN has been reset.'
    else
        return false, 'Bypass failed. The security system held.'
    end
end)

---Attempt to bypass key/padlock
lib.callback.register('free_hoarder:bypassKeyLock', function(source, slotName)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    local lock = bagData.lock
    if lock.type ~= LockType.KEY and lock.type ~= LockType.PADLOCK then
        return false, 'Not a key/padlock lock'
    end
    
    -- Get bypass items config
    local bypassItems = lock.type == LockType.KEY 
        and Config.Locking.key.bypassItems 
        or Config.Locking.padlock.bypassItems
    
    -- Find best bypass item player has
    local bestItem = GetBestBypassItem(source, bypassItems)
    
    if not bestItem then
        return false, 'You need a tool to pick this lock (lockpick, screwdriver, crowbar, hammer, or knife)'
    end
    
    local bypassTime = lock.type == LockType.KEY 
        and Config.Locking.key.bypassTime 
        or Config.Locking.padlock.bypassTime
    
    return true, nil, {
        time = bypassTime or 8000,
        successRate = bestItem.chance,
        breakChance = bestItem.breakChance,
        item = bestItem.item
    }
end)

---Complete key/padlock bypass
lib.callback.register('free_hoarder:completeKeyBypass', function(source, slotName, bypassItem)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    local lock = bagData.lock
    
    -- Get bypass items config
    local bypassItems = lock.type == LockType.KEY 
        and Config.Locking.key.bypassItems 
        or Config.Locking.padlock.bypassItems
    
    -- Find the item data
    local itemData = nil
    for _, data in ipairs(bypassItems) do
        if data.item == bypassItem then
            itemData = data
            break
        end
    end
    
    if not itemData then
        return false, 'Invalid bypass item'
    end
    
    -- Check if item breaks
    local breakRoll = math.random(1, 100)
    if breakRoll <= itemData.breakChance then
        -- Item breaks
        exports.ox_inventory:RemoveItem(source, bypassItem, 1)
        return false, 'Your ' .. bypassItem .. ' broke!'
    end
    
    -- Roll for success
    local successRoll = math.random(1, 100)
    if successRoll <= itemData.chance then
        -- Success - unlock
        lock.isLocked = false
        EquippedBags[source][slotName].lock = lock
        TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lock)
        
        -- Trigger event
        if TriggerBagLockBypassed then
            TriggerBagLockBypassed({
                source = source,
                bagName = bagData.bagName,
                slotName = slotName,
                lockType = lock.type,
                bypassMethod = 'pick',
                bypassItem = bypassItem
            })
        end
        
        -- Log
        if Config.Locking.logBypasses and LogBagBypassed then
            LogBagBypassed(source, bagData.bagName, lock.type, bypassItem)
        end
        
        return true, 'Lock picked successfully'
    else
        return false, 'Failed to pick the lock'
    end
end)

---Attempt to bypass biometric
lib.callback.register('free_hoarder:bypassBiometric', function(source, slotName)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    local lock = bagData.lock
    if lock.type ~= LockType.BIOMETRIC then
        return false, 'Not a biometric lock'
    end
    
    -- Check required items
    local bypassItems = Config.Locking.biometric.bypassItems or {'advanced_hacking_device', 'laptop'}
    local hasAll, missing = HasAllBypassItems(source, bypassItems)
    
    if not hasAll then
        return false, 'Missing required item: ' .. (missing or 'unknown')
    end
    
    return true, nil, {
        time = Config.Locking.biometric.bypassTime or 25000,
        successRate = Config.Locking.biometric.bypassSuccessRate or 50
    }
end)

---Complete biometric bypass
lib.callback.register('free_hoarder:completeBiometricBypass', function(source, slotName)
    if not EquippedBags or not EquippedBags[source] then
        return false, 'No bags equipped'
    end
    
    local bagData = EquippedBags[source][slotName]
    if not bagData or not bagData.lock then
        return false, 'No lock on bag'
    end
    
    local lock = bagData.lock
    
    -- Roll for success
    local successRate = Config.Locking.biometric.bypassSuccessRate or 50
    local roll = math.random(1, 100)
    
    if roll <= successRate then
        -- Success - unlock and clear owner
        lock.isLocked = false
        lock.ownerId = nil
        lock.ownerName = nil
        EquippedBags[source][slotName].lock = lock
        TriggerClientEvent('free_hoarder:bagLockUpdated', source, slotName, lock)
        
        -- Trigger event
        if TriggerBagLockBypassed then
            TriggerBagLockBypassed({
                source = source,
                bagName = bagData.bagName,
                slotName = slotName,
                lockType = LockType.BIOMETRIC,
                bypassMethod = 'hack'
            })
        end
        
        -- Log
        if Config.Locking.logBypasses and LogBagBypassed then
            LogBagBypassed(source, bagData.bagName, LockType.BIOMETRIC, 'advanced_hack')
        end
        
        return true, 'Biometric bypassed. Fingerprint data cleared.'
    else
        return false, 'Bypass failed. Security system triggered alert.'
    end
end)

-------------------------------------------------------------------------------
-- LOCK SETUP CALLBACKS
-------------------------------------------------------------------------------

---Set up a new lock on a bag
lib.callback.register('free_hoarder:setupLock', function(source, slotName, lockType, lockData)
    local success, error = SetBagLockServer(source, slotName, lockType, lockData)
    return success, error
end)

---Remove lock from bag
lib.callback.register('free_hoarder:removeLock', function(source, slotName)
    local success, error = RemoveBagLockServer(source, slotName)
    return success, error
end)

-------------------------------------------------------------------------------
-- DISCORD LOGGING
-------------------------------------------------------------------------------

function LogBagLocked(source, bagName, lockType)
    if not SendToDiscord then return end
    
    local Player = exports.qbx_core:GetPlayer(source)
    local playerName = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Unknown'
    
    SendToDiscord(
        'Bag Locked',
        ('**Player:** %s (ID: %d)\n**Bag:** %s\n**Lock Type:** %s'):format(
            playerName, source, bagName, GetLockTypeName(lockType)
        ),
        5814783  -- Blue
    )
end

function LogBagBypassed(source, bagName, lockType, method)
    if not SendToDiscord then return end
    
    local Player = exports.qbx_core:GetPlayer(source)
    local playerName = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Unknown'
    
    SendToDiscord(
        '⚠️ Bag Lock Bypassed',
        ('**Player:** %s (ID: %d)\n**Bag:** %s\n**Lock Type:** %s\n**Method:** %s'):format(
            playerName, source, bagName, GetLockTypeName(lockType), method
        ),
        15158332  -- Orange/warning
    )
end
