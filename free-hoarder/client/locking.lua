--[[
    Client Locking - free-hoarder v2.0
    Client-side lock UI, PIN entry, and bypass handling
]]

-------------------------------------------------------------------------------
-- LOCAL STATE
-------------------------------------------------------------------------------

local CurrentLockAttempt = nil  -- Track ongoing lock operations

-------------------------------------------------------------------------------
-- LOCK STATE SYNC
-------------------------------------------------------------------------------

RegisterNetEvent('free_hoarder:bagLockUpdated', function(slotName, lock)
    if not LocalEquippedBags then return end
    if not LocalEquippedBags[slotName] then return end
    
    LocalEquippedBags[slotName].lock = lock
    
    if DebugLog then
        DebugLog('Lock updated for slot', slotName, '- Locked:', lock and lock.isLocked or false)
    end
end)

-------------------------------------------------------------------------------
-- PIN ENTRY UI
-------------------------------------------------------------------------------

---Prompt user to enter a PIN
---@param title string Dialog title
---@param description string? Optional description
---@return string|nil pin The entered PIN or nil if cancelled
local function PromptPIN(title, description)
    local digits = Config.Locking and Config.Locking.pin and Config.Locking.pin.digits or 4
    
    local input = lib.inputDialog(title, {
        {
            type = 'input',
            label = 'Enter PIN',
            description = description or ('Enter your %d-digit code'):format(digits),
            icon = 'lock',
            password = true,
            required = true,
            min = digits,
            max = digits
        }
    })
    
    if not input then return nil end
    
    local pin = input[1]
    
    -- Validate numeric
    if not pin:match('^%d+$') then
        NotifyError('PIN must be numbers only')
        return nil
    end
    
    return pin
end

---Prompt user to set a new PIN with confirmation
---@return string|nil pin The new PIN or nil if cancelled
local function PromptNewPIN()
    local digits = Config.Locking and Config.Locking.pin and Config.Locking.pin.digits or 4
    
    local input = lib.inputDialog('Set PIN Code', {
        {
            type = 'input',
            label = 'New PIN',
            description = ('Enter a %d-digit code'):format(digits),
            icon = 'lock',
            password = true,
            required = true,
            min = digits,
            max = digits
        },
        {
            type = 'input',
            label = 'Confirm PIN',
            description = 'Enter the same code again',
            icon = 'lock',
            password = true,
            required = true,
            min = digits,
            max = digits
        }
    })
    
    if not input then return nil end
    
    local pin1, pin2 = input[1], input[2]
    
    -- Validate numeric
    if not pin1:match('^%d+$') then
        NotifyError('PIN must be numbers only')
        return nil
    end
    
    -- Validate match
    if pin1 ~= pin2 then
        NotifyError('PINs do not match')
        return nil
    end
    
    return pin1
end

---Prompt user to change PIN
---@return string|nil currentPIN, string|nil newPIN
local function PromptChangePIN()
    local digits = Config.Locking and Config.Locking.pin and Config.Locking.pin.digits or 4
    
    local input = lib.inputDialog('Change PIN Code', {
        {
            type = 'input',
            label = 'Current PIN',
            description = 'Enter your current code',
            icon = 'key',
            password = true,
            required = true,
            min = digits,
            max = digits
        },
        {
            type = 'input',
            label = 'New PIN',
            description = ('Enter a new %d-digit code'):format(digits),
            icon = 'lock',
            password = true,
            required = true,
            min = digits,
            max = digits
        },
        {
            type = 'input',
            label = 'Confirm New PIN',
            description = 'Enter the new code again',
            icon = 'lock',
            password = true,
            required = true,
            min = digits,
            max = digits
        }
    })
    
    if not input then return nil, nil end
    
    local current, new1, new2 = input[1], input[2], input[3]
    
    -- Validate numeric
    if not new1:match('^%d+$') then
        NotifyError('PIN must be numbers only')
        return nil, nil
    end
    
    -- Validate match
    if new1 ~= new2 then
        NotifyError('New PINs do not match')
        return nil, nil
    end
    
    return current, new1
end

-------------------------------------------------------------------------------
-- LOCK TYPE SELECTION UI
-------------------------------------------------------------------------------

---Show lock type selection menu
---@param bagConfig table Bag configuration
---@param slotName string
---@return string|nil lockType Selected lock type
local function SelectLockType(bagConfig, slotName)
    local options = {}
    
    -- Get allowed lock types for this bag
    local allowedTypes = bagConfig.allowedLockTypes or { LockType.PIN, LockType.KEY, LockType.PADLOCK, LockType.BIOMETRIC }
    
    for _, lockType in ipairs(allowedTypes) do
        local description = ''
        local icon = GetLockTypeIcon(lockType)
        
        if lockType == LockType.PIN then
            description = 'Set a 4-digit PIN code'
        elseif lockType == LockType.KEY then
            description = 'Creates a unique key item'
        elseif lockType == LockType.PADLOCK then
            description = 'Requires a padlock item'
        elseif lockType == LockType.BIOMETRIC then
            description = 'Fingerprint - only you can open'
        end
        
        table.insert(options, {
            title = GetLockTypeName(lockType),
            description = description,
            icon = icon,
            args = { lockType = lockType }
        })
    end
    
    table.insert(options, {
        title = 'Cancel',
        icon = 'xmark'
    })
    
    local selected = lib.registerContext({
        id = 'hoarder_lock_type_select',
        title = 'Select Lock Type',
        options = options
    })
    
    lib.showContext('hoarder_lock_type_select')
    
    -- Wait for selection (this is handled via onSelect, need different approach)
    -- Actually, let's use a different method
end

-------------------------------------------------------------------------------
-- LOCK MENU
-------------------------------------------------------------------------------

---Show lock options for a bag
---@param slotName string
---@param bagData table
function OpenLockMenu(slotName, bagData)
    local bagConfig = GetBagConfig(bagData.bagName)
    if not bagConfig then return end
    
    local lock = bagData.lock
    local options = {}
    
    if lock and lock.isLocked then
        -- Bag is locked - show unlock options
        
        if lock.type == LockType.PIN then
            table.insert(options, {
                title = 'Enter PIN',
                description = 'Unlock with your PIN code',
                icon = 'keyboard',
                onSelect = function()
                    AttemptPINUnlock(slotName)
                end
            })
            
            table.insert(options, {
                title = 'Change PIN',
                description = 'Change your PIN code',
                icon = 'pen',
                onSelect = function()
                    AttemptChangePIN(slotName)
                end
            })
            
            table.insert(options, {
                title = 'Hack Lock',
                description = 'Requires hacking device + laptop',
                icon = 'microchip',
                onSelect = function()
                    AttemptPINBypass(slotName)
                end
            })
            
        elseif lock.type == LockType.KEY or lock.type == LockType.PADLOCK then
            table.insert(options, {
                title = 'Use Key',
                description = 'Unlock with matching key',
                icon = 'key',
                onSelect = function()
                    AttemptKeyUnlock(slotName)
                end
            })
            
            table.insert(options, {
                title = 'Pick Lock',
                description = 'Attempt to pick the lock',
                icon = 'screwdriver',
                onSelect = function()
                    AttemptKeyBypass(slotName)
                end
            })
            
        elseif lock.type == LockType.BIOMETRIC then
            table.insert(options, {
                title = 'Scan Fingerprint',
                description = 'Verify your identity',
                icon = 'fingerprint',
                onSelect = function()
                    AttemptBiometricUnlock(slotName)
                end
            })
            
            table.insert(options, {
                title = 'Hack Biometric',
                description = 'Requires advanced hacking device + laptop',
                icon = 'microchip',
                onSelect = function()
                    AttemptBiometricBypass(slotName)
                end
            })
        end
        
    elseif lock and not lock.isLocked then
        -- Bag has lock but is unlocked - show re-lock option
        table.insert(options, {
            title = 'Re-lock Bag',
            description = 'Lock the bag again',
            icon = 'lock',
            onSelect = function()
                RelockBag(slotName)
            end
        })
        
        if lock.type == LockType.PIN then
            table.insert(options, {
                title = 'Change PIN',
                description = 'Change your PIN code',
                icon = 'pen',
                onSelect = function()
                    AttemptChangePIN(slotName)
                end
            })
        end
        
        table.insert(options, {
            title = 'Remove Lock',
            description = 'Permanently remove the lock',
            icon = 'trash',
            onSelect = function()
                RemoveLock(slotName)
            end
        })
        
    else
        -- No lock - show setup options
        if bagConfig.lockable then
            local allowedTypes = bagConfig.allowedLockTypes or { LockType.PIN, LockType.KEY, LockType.PADLOCK, LockType.BIOMETRIC }
            
            for _, lockType in ipairs(allowedTypes) do
                local description = ''
                local icon = GetLockTypeIcon(lockType)
                
                if lockType == LockType.PIN then
                    description = 'Set a 4-digit PIN code'
                elseif lockType == LockType.KEY then
                    description = 'Creates a unique key item'
                elseif lockType == LockType.PADLOCK then
                    description = 'Requires a padlock item'
                elseif lockType == LockType.BIOMETRIC then
                    description = 'Fingerprint - only you can open'
                end
                
                table.insert(options, {
                    title = 'Add ' .. GetLockTypeName(lockType),
                    description = description,
                    icon = icon,
                    onSelect = function()
                        SetupLock(slotName, lockType)
                    end
                })
            end
        else
            table.insert(options, {
                title = 'Cannot Lock',
                description = 'This bag type cannot be locked',
                icon = 'ban',
                disabled = true
            })
        end
    end
    
    table.insert(options, {
        title = 'Back',
        icon = 'arrow-left',
        onSelect = function()
            -- Return to bag menu
            if OpenBagMenu then
                OpenBagMenu(slotName, bagData)
            end
        end
    })
    
    lib.registerContext({
        id = 'hoarder_lock_menu',
        title = 'Bag Lock Options',
        options = options
    })
    
    lib.showContext('hoarder_lock_menu')
end

-------------------------------------------------------------------------------
-- LOCK SETUP
-------------------------------------------------------------------------------

---Set up a new lock on a bag
---@param slotName string
---@param lockType string
function SetupLock(slotName, lockType)
    local lockData = {}
    
    if lockType == LockType.PIN then
        -- Prompt for PIN
        local pin = PromptNewPIN()
        if not pin then return end
        lockData.code = pin
        
    elseif lockType == LockType.KEY then
        -- Key is generated server-side
        -- Just confirm
        local confirm = lib.alertDialog({
            header = 'Add Key Lock',
            content = 'This will create a unique key item. You will need this key to unlock the bag. Continue?',
            centered = true,
            cancel = true
        })
        if confirm ~= 'confirm' then return end
        
    elseif lockType == LockType.PADLOCK then
        -- Check for padlock item (server will verify too)
        local confirm = lib.alertDialog({
            header = 'Add Padlock',
            content = 'This will consume a padlock from your inventory and create a key. Continue?',
            centered = true,
            cancel = true
        })
        if confirm ~= 'confirm' then return end
        
    elseif lockType == LockType.BIOMETRIC then
        -- Confirm biometric setup
        local confirm = lib.alertDialog({
            header = 'Add Biometric Lock',
            content = 'This will register your fingerprint. Only you will be able to open this bag. Continue?',
            centered = true,
            cancel = true
        })
        if confirm ~= 'confirm' then return end
    end
    
    -- Send to server
    local success, error = lib.callback.await('free_hoarder:setupLock', false, slotName, lockType, lockData)
    
    if success then
        NotifySuccess('Lock added successfully')
        PlaySound('lock')
    else
        NotifyError(error or 'Failed to add lock')
    end
end

---Remove lock from bag
---@param slotName string
function RemoveLock(slotName)
    local confirm = lib.alertDialog({
        header = 'Remove Lock',
        content = 'Are you sure you want to permanently remove this lock?',
        centered = true,
        cancel = true
    })
    
    if confirm ~= 'confirm' then return end
    
    local success, error = lib.callback.await('free_hoarder:removeLock', false, slotName)
    
    if success then
        NotifySuccess('Lock removed')
    else
        NotifyError(error or 'Failed to remove lock')
    end
end

---Re-lock an unlocked bag
---@param slotName string
function RelockBag(slotName)
    local success, error = lib.callback.await('free_hoarder:relockBag', false, slotName)
    
    if success then
        NotifyInfo('Bag locked')
        PlaySound('lock')
    else
        NotifyError(error or 'Failed to lock bag')
    end
end

-------------------------------------------------------------------------------
-- UNLOCK ATTEMPTS
-------------------------------------------------------------------------------

---Attempt to unlock with PIN
---@param slotName string
function AttemptPINUnlock(slotName)
    local pin = PromptPIN('Enter PIN')
    if not pin then return end
    
    local success, error = lib.callback.await('free_hoarder:verifyPIN', false, slotName, pin)
    
    if success then
        NotifySuccess('Bag unlocked')
        PlaySound('unlock')
    else
        NotifyError(error or 'Wrong PIN')
    end
end

---Attempt to unlock with key
---@param slotName string
function AttemptKeyUnlock(slotName)
    local success, error = lib.callback.await('free_hoarder:verifyKey', false, slotName)
    
    if success then
        NotifySuccess('Bag unlocked')
        PlaySound('unlock')
    else
        NotifyError(error or 'You don\'t have the right key')
    end
end

---Attempt to unlock with biometric
---@param slotName string
function AttemptBiometricUnlock(slotName)
    -- Show fingerprint scanning animation
    if lib.progressCircle({
        duration = 2000,
        label = 'Scanning fingerprint...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = true, combat = true }
    }) then
        local success, error = lib.callback.await('free_hoarder:verifyBiometric', false, slotName)
        
        if success then
            NotifySuccess('Identity verified')
            PlaySound('unlock')
        else
            NotifyError(error or 'Biometric mismatch')
        end
    end
end

---Attempt to change PIN
---@param slotName string
function AttemptChangePIN(slotName)
    local current, newPIN = PromptChangePIN()
    if not current or not newPIN then return end
    
    local success, error = lib.callback.await('free_hoarder:changePIN', false, slotName, current, newPIN)
    
    if success then
        NotifySuccess('PIN changed successfully')
    else
        NotifyError(error or 'Failed to change PIN')
    end
end

-------------------------------------------------------------------------------
-- BYPASS ATTEMPTS
-------------------------------------------------------------------------------

---Attempt to bypass PIN lock
---@param slotName string
function AttemptPINBypass(slotName)
    -- Check if we can attempt bypass
    local canBypass, error, bypassData = lib.callback.await('free_hoarder:bypassPIN', false, slotName)
    
    if not canBypass then
        NotifyError(error or 'Cannot bypass this lock')
        return
    end
    
    -- Show progress bar
    if lib.progressBar({
        duration = bypassData.time,
        label = 'Hacking security system...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@heists@ornate_bank@hack',
            clip = 'hack_loop'
        }
    }) then
        -- Completed - check result
        local success, result = lib.callback.await('free_hoarder:completePINBypass', false, slotName)
        
        if success then
            NotifySuccess(result or 'Lock bypassed')
            PlaySound('unlock')
        else
            NotifyError(result or 'Bypass failed')
        end
    else
        NotifyWarning('Bypass cancelled')
    end
end

---Attempt to bypass key/padlock
---@param slotName string
function AttemptKeyBypass(slotName)
    -- Check if we can attempt bypass
    local canBypass, error, bypassData = lib.callback.await('free_hoarder:bypassKeyLock', false, slotName)
    
    if not canBypass then
        NotifyError(error or 'Cannot pick this lock')
        return
    end
    
    -- Show what tool we're using
    NotifyInfo(('Using %s (%d%% success chance)'):format(bypassData.item, bypassData.successRate))
    
    -- Show progress bar
    if lib.progressBar({
        duration = bypassData.time,
        label = 'Picking lock...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer'
        }
    }) then
        -- Completed - check result
        local success, result = lib.callback.await('free_hoarder:completeKeyBypass', false, slotName, bypassData.item)
        
        if success then
            NotifySuccess(result or 'Lock picked')
            PlaySound('unlock')
        else
            NotifyError(result or 'Failed to pick lock')
        end
    else
        NotifyWarning('Lockpicking cancelled')
    end
end

---Attempt to bypass biometric lock
---@param slotName string
function AttemptBiometricBypass(slotName)
    -- Check if we can attempt bypass
    local canBypass, error, bypassData = lib.callback.await('free_hoarder:bypassBiometric', false, slotName)
    
    if not canBypass then
        NotifyError(error or 'Cannot bypass this lock')
        return
    end
    
    -- Show progress bar
    if lib.progressBar({
        duration = bypassData.time,
        label = 'Bypassing biometric security...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@heists@ornate_bank@hack',
            clip = 'hack_loop'
        }
    }) then
        -- Completed - check result
        local success, result = lib.callback.await('free_hoarder:completeBiometricBypass', false, slotName)
        
        if success then
            NotifySuccess(result or 'Biometric bypassed')
            PlaySound('unlock')
        else
            NotifyError(result or 'Bypass failed')
        end
    else
        NotifyWarning('Bypass cancelled')
    end
end

-------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-------------------------------------------------------------------------------

---Play lock/unlock sound
---@param type string 'lock' or 'unlock'
local function PlaySound(type)
    if type == 'lock' then
        PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', true)
    elseif type == 'unlock' then
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
end

-------------------------------------------------------------------------------
-- CHECK IF BAG IS LOCKED (before opening)
-------------------------------------------------------------------------------

---Check if a bag is locked and handle unlock if needed
---@param slotName string
---@param bagData table
---@return boolean canOpen True if bag can be opened
function CheckBagLockBeforeOpen(slotName, bagData)
    if not bagData.lock or not bagData.lock.isLocked then
        return true  -- No lock or already unlocked
    end
    
    -- Bag is locked - show lock menu instead
    NotifyWarning('This bag is locked')
    OpenLockMenu(slotName, bagData)
    return false
end

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------

exports('OpenLockMenu', OpenLockMenu)
exports('CheckBagLockBeforeOpen', CheckBagLockBeforeOpen)
