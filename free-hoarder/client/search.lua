--[[
    Client Search - free-hoarder v2.0
    Player search/frisk system with ox_target integration
    
    Features:
    - Search player's bags (requires target to be restrained)
    - Take bags from restrained players
    - View bag contents read-only
    
    Includes player state detection (handcuffed/hands up)
]]

-------------------------------------------------------------------------------
-- PLAYER STATE DETECTION
-------------------------------------------------------------------------------

---Check if local player is handcuffed
---@return boolean
function IsLocalPlayerHandcuffed()
    if QBX and QBX.PlayerData and QBX.PlayerData.metadata then
        if QBX.PlayerData.metadata.ishandcuffed then
            return true
        end
    end
    
    local state = LocalPlayer.state
    if state then
        if state.isHandcuffed or state.isCuffed or state.handcuffed then
            return true
        end
    end
    
    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
        return true
    end
    if IsEntityPlayingAnim(ped, 'anim@move_m@prisoner_cuffed', 'idle', 3) then
        return true
    end
    
    return false
end

---Check if local player has hands up
---@return boolean
function IsLocalPlayerHandsUp()
    local state = LocalPlayer.state
    if state then
        if state.handsUp or state.handsup or state.isHandsUp then
            return true
        end
    end
    
    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3) then
        return true
    end
    if IsEntityPlayingAnim(ped, 'random@mugging3', 'handsup_standing_base', 3) then
        return true
    end
    
    return false
end

---Check if local player is restrained
---@return boolean
function IsLocalPlayerRestrained()
    return IsLocalPlayerHandcuffed() or IsLocalPlayerHandsUp()
end

---Check if another player is handcuffed
---@param playerId number Client player ID
---@return boolean
function IsPlayerHandcuffed(playerId)
    local playerState = Player(GetPlayerServerId(playerId)).state
    if playerState then
        if playerState.isHandcuffed or playerState.isCuffed or playerState.handcuffed then
            return true
        end
    end
    
    local ped = GetPlayerPed(playerId)
    if ped and DoesEntityExist(ped) then
        if IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
            return true
        end
        if IsEntityPlayingAnim(ped, 'anim@move_m@prisoner_cuffed', 'idle', 3) then
            return true
        end
    end
    
    return false
end

---Check if another player has hands up
---@param playerId number Client player ID
---@return boolean
function IsPlayerHandsUp(playerId)
    local playerState = Player(GetPlayerServerId(playerId)).state
    if playerState then
        if playerState.handsUp or playerState.handsup or playerState.isHandsUp then
            return true
        end
    end
    
    local ped = GetPlayerPed(playerId)
    if ped and DoesEntityExist(ped) then
        if IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3) then
            return true
        end
        if IsEntityPlayingAnim(ped, 'random@mugging3', 'handsup_standing_base', 3) then
            return true
        end
    end
    
    return false
end

---Check if another player is restrained
---@param playerId number Client player ID
---@return boolean
function IsPlayerRestrained(playerId)
    return IsPlayerHandcuffed(playerId) or IsPlayerHandsUp(playerId)
end

---Check if target ped is restrained
---@param ped number Entity handle
---@return boolean
function IsPedRestrained(ped)
    if not ped or not DoesEntityExist(ped) then return false end
    
    local playerId = NetworkGetPlayerIndexFromPed(ped)
    if playerId == -1 then return false end
    
    return IsPlayerRestrained(playerId)
end

-- Player state exports
exports('IsLocalPlayerHandcuffed', IsLocalPlayerHandcuffed)
exports('IsLocalPlayerHandsUp', IsLocalPlayerHandsUp)
exports('IsLocalPlayerRestrained', IsLocalPlayerRestrained)
exports('IsPlayerHandcuffed', IsPlayerHandcuffed)
exports('IsPlayerHandsUp', IsPlayerHandsUp)
exports('IsPlayerRestrained', IsPlayerRestrained)
exports('IsPedRestrained', IsPedRestrained)

-------------------------------------------------------------------------------
-- OX_TARGET INTEGRATION
-------------------------------------------------------------------------------

CreateThread(function()
    -- Wait for ox_target to be ready
    while GetResourceState('ox_target') ~= 'started' do
        Wait(100)
    end
    Wait(1000)
    
    -- Check if search system is enabled
    if not Config.Search or not Config.Search.enabled then
        print('[free-hoarder] Search system disabled in config')
        return
    end
    
    print('[free-hoarder] Registering ox_target player options...')
    
    -- Add search options to all players
    exports.ox_target:addGlobalPlayer({
        {
            name = 'hoarder_search_bags',
            icon = 'fas fa-magnifying-glass',
            label = 'Search Bags',
            distance = Config.Search.searchDistance or 2.0,
            canInteract = function(entity, distance, coords, name, bone)
                -- Only show if target is restrained
                return IsPedRestrained(entity)
            end,
            onSelect = function(data)
                local playerId = NetworkGetPlayerIndexFromPed(data.entity)
                local serverId = GetPlayerServerId(playerId)
                StartSearchPlayer(serverId)
            end
        },
        {
            name = 'hoarder_take_bag',
            icon = 'fas fa-hand-holding',
            label = 'Take Bag',
            distance = Config.Search.takeDistance or 1.5,
            canInteract = function(entity, distance, coords, name, bone)
                -- Only show if target is restrained
                return IsPedRestrained(entity)
            end,
            onSelect = function(data)
                local playerId = NetworkGetPlayerIndexFromPed(data.entity)
                local serverId = GetPlayerServerId(playerId)
                StartTakeBag(serverId)
            end
        }
    })
    
    print('[free-hoarder] ox_target player options registered')
end)

-------------------------------------------------------------------------------
-- SEARCH PLAYER
-------------------------------------------------------------------------------

---Start searching a player's bags
---@param targetServerId number Target player's server ID
function StartSearchPlayer(targetServerId)
    -- Request search from server (validates restraint state server-side)
    local success, bags, targetName, error = lib.callback.await('free_hoarder:searchPlayer', false, targetServerId)
    
    if not success then
        NotifyError(error or 'Cannot search this player')
        return
    end
    
    if not bags or not next(bags) then
        NotifyInfo(targetName .. ' has no bags')
        return
    end
    
    -- Show search results
    OpenSearchResultsMenu(targetServerId, targetName, bags)
end

---Open the search results menu
---@param targetServerId number
---@param targetName string
---@param bags table
function OpenSearchResultsMenu(targetServerId, targetName, bags)
    local options = {}
    
    -- Header info
    table.insert(options, {
        title = 'Searching: ' .. targetName,
        description = ('%d bag(s) found'):format(CountTable(bags)),
        icon = 'user',
        disabled = true
    })
    
    -- List each bag
    for slotName, bagData in pairs(bags) do
        local lockIcon = ''
        local lockDesc = ''
        
        if bagData.isLocked then
            lockIcon = ' 🔒'
            lockDesc = ' (Locked - ' .. (bagData.lockType or 'unknown') .. ')'
        end
        
        local durabilityDesc = ''
        if bagData.durability and bagData.durability < 100 then
            durabilityDesc = (' [%d%%]'):format(bagData.durability)
        end
        
        table.insert(options, {
            title = bagData.label .. lockIcon,
            description = ('Slot: %s%s%s'):format(FormatSlotLabel(slotName), lockDesc, durabilityDesc),
            icon = GetBagTypeIcon(bagData.type),
            onSelect = function()
                if bagData.isLocked then
                    -- Show lock bypass options
                    OpenSearchedBagLockMenu(targetServerId, slotName, bagData)
                else
                    -- View bag contents
                    ViewSearchedBagContents(targetServerId, slotName, bagData)
                end
            end
        })
    end
    
    -- Close button
    table.insert(options, {
        title = 'Stop Searching',
        icon = 'xmark',
        onSelect = function()
            NotifyInfo('Stopped searching')
        end
    })
    
    lib.registerContext({
        id = 'hoarder_search_results',
        title = 'Search Results',
        options = options
    })
    
    lib.showContext('hoarder_search_results')
end

---View contents of a searched bag
---@param targetServerId number
---@param slotName string
---@param bagData table
function ViewSearchedBagContents(targetServerId, slotName, bagData)
    -- Request to open the bag for viewing/taking items
    local success, error = lib.callback.await('free_hoarder:openSearchedBag', false, targetServerId, slotName)
    
    if not success then
        NotifyError(error or 'Cannot access this bag')
        return
    end
    
    -- Server will open the stash for us
    NotifyInfo('Searching ' .. bagData.label .. '...')
end

---Show lock options for a searched bag
---@param targetServerId number
---@param slotName string
---@param bagData table
function OpenSearchedBagLockMenu(targetServerId, slotName, bagData)
    local options = {}
    
    table.insert(options, {
        title = bagData.label .. ' is Locked',
        description = 'Lock type: ' .. (GetLockTypeName and GetLockTypeName(bagData.lockType) or bagData.lockType),
        icon = 'lock',
        disabled = true
    })
    
    -- Bypass options based on lock type
    if bagData.lockType == 'pin' then
        table.insert(options, {
            title = 'Hack Lock',
            description = 'Requires hacking device + laptop',
            icon = 'microchip',
            onSelect = function()
                AttemptSearchedBagBypass(targetServerId, slotName, bagData, 'pin')
            end
        })
    elseif bagData.lockType == 'key' or bagData.lockType == 'padlock' then
        table.insert(options, {
            title = 'Pick Lock',
            description = 'Requires lockpick or tools',
            icon = 'screwdriver',
            onSelect = function()
                AttemptSearchedBagBypass(targetServerId, slotName, bagData, 'key')
            end
        })
    elseif bagData.lockType == 'biometric' then
        table.insert(options, {
            title = 'Hack Biometric',
            description = 'Requires advanced hacking device + laptop',
            icon = 'fingerprint',
            onSelect = function()
                AttemptSearchedBagBypass(targetServerId, slotName, bagData, 'biometric')
            end
        })
    end
    
    -- Force open (destroys lock) - optional feature
    if Config.Search and Config.Search.allowForceOpen then
        table.insert(options, {
            title = 'Force Open',
            description = 'Break the lock (destroys it)',
            icon = 'hammer',
            onSelect = function()
                AttemptForceOpenBag(targetServerId, slotName, bagData)
            end
        })
    end
    
    table.insert(options, {
        title = 'Back',
        icon = 'arrow-left',
        onSelect = function()
            StartSearchPlayer(targetServerId)
        end
    })
    
    lib.registerContext({
        id = 'hoarder_searched_bag_lock',
        title = 'Locked Bag',
        options = options
    })
    
    lib.showContext('hoarder_searched_bag_lock')
end

---Attempt to bypass a lock on a searched bag
---@param targetServerId number
---@param slotName string
---@param bagData table
---@param bypassType string
function AttemptSearchedBagBypass(targetServerId, slotName, bagData, bypassType)
    -- Check if we can bypass (have items, etc)
    local canBypass, error, bypassData = lib.callback.await('free_hoarder:canBypassSearchedBag', false, targetServerId, slotName, bypassType)
    
    if not canBypass then
        NotifyError(error or 'Cannot bypass this lock')
        return
    end
    
    -- Show info about bypass
    if bypassData.item then
        NotifyInfo(('Using %s (%d%% success chance)'):format(bypassData.item, bypassData.successRate))
    end
    
    -- Progress bar
    local animDict = bypassType == 'key' and 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@' or 'anim@heists@ornate_bank@hack'
    local animClip = bypassType == 'key' and 'machinic_loop_mechandplayer' or 'hack_loop'
    
    if lib.progressBar({
        duration = bypassData.time or 10000,
        label = bypassType == 'key' and 'Picking lock...' or 'Bypassing security...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = animDict, clip = animClip }
    }) then
        -- Complete bypass
        local success, result = lib.callback.await('free_hoarder:completeSearchedBagBypass', false, targetServerId, slotName, bypassType, bypassData.item)
        
        if success then
            NotifySuccess(result or 'Lock bypassed')
            PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            -- Re-open search to show unlocked bag
            StartSearchPlayer(targetServerId)
        else
            NotifyError(result or 'Bypass failed')
        end
    else
        NotifyWarning('Bypass cancelled')
    end
end

---Attempt to force open a locked bag (destroys lock)
---@param targetServerId number
---@param slotName string
---@param bagData table
function AttemptForceOpenBag(targetServerId, slotName, bagData)
    local confirm = lib.alertDialog({
        header = 'Force Open Bag',
        content = 'This will destroy the lock. The bag owner will be notified. Continue?',
        centered = true,
        cancel = true
    })
    
    if confirm ~= 'confirm' then return end
    
    if lib.progressBar({
        duration = 5000,
        label = 'Breaking lock...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_0' }
    }) then
        local success, error = lib.callback.await('free_hoarder:forceOpenSearchedBag', false, targetServerId, slotName)
        
        if success then
            NotifySuccess('Lock broken')
            StartSearchPlayer(targetServerId)
        else
            NotifyError(error or 'Failed to break lock')
        end
    end
end

-------------------------------------------------------------------------------
-- TAKE BAG
-------------------------------------------------------------------------------

---Start taking a bag from a player
---@param targetServerId number Target player's server ID
function StartTakeBag(targetServerId)
    -- Get list of bags that can be taken
    local success, bags, targetName, error = lib.callback.await('free_hoarder:getPlayerBagsForTake', false, targetServerId)
    
    if not success then
        NotifyError(error or 'Cannot take bags from this player')
        return
    end
    
    if not bags or not next(bags) then
        NotifyInfo(targetName .. ' has no bags to take')
        return
    end
    
    -- Show bag selection menu
    OpenTakeBagMenu(targetServerId, targetName, bags)
end

---Open menu to select which bag to take
---@param targetServerId number
---@param targetName string
---@param bags table
function OpenTakeBagMenu(targetServerId, targetName, bags)
    local options = {}
    
    table.insert(options, {
        title = 'Take Bag From: ' .. targetName,
        description = 'Select a bag to take',
        icon = 'hand-holding',
        disabled = true
    })
    
    for slotName, bagData in pairs(bags) do
        local lockWarning = ''
        if bagData.isLocked then
            lockWarning = ' (Locked)'
        end
        
        table.insert(options, {
            title = 'Take ' .. bagData.label .. lockWarning,
            description = 'Slot: ' .. FormatSlotLabel(slotName),
            icon = GetBagTypeIcon(bagData.type),
            onSelect = function()
                ConfirmTakeBag(targetServerId, slotName, bagData)
            end
        })
    end
    
    table.insert(options, {
        title = 'Cancel',
        icon = 'xmark'
    })
    
    lib.registerContext({
        id = 'hoarder_take_bag_menu',
        title = 'Take Bag',
        options = options
    })
    
    lib.showContext('hoarder_take_bag_menu')
end

---Confirm and execute taking a bag
---@param targetServerId number
---@param slotName string
---@param bagData table
function ConfirmTakeBag(targetServerId, slotName, bagData)
    -- Show progress
    if lib.progressBar({
        duration = Config.Search and Config.Search.takeDuration or 3000,
        label = 'Taking ' .. bagData.label .. '...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'random@mugging4', clip = 'struggle_loop_b' }
    }) then
        -- Execute take
        local success, error = lib.callback.await('free_hoarder:takeBagFromPlayer', false, targetServerId, slotName)
        
        if success then
            NotifySuccess('Took ' .. bagData.label)
            PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        else
            NotifyError(error or 'Failed to take bag')
        end
    else
        NotifyWarning('Cancelled')
    end
end

-------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-------------------------------------------------------------------------------

---Count table entries
---@param t table
---@return number
function CountTable(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- FormatSlotLabel is defined in shared/utils.lua

---Get icon for bag type
---@param bagType string
---@return string
function GetBagTypeIcon(bagType)
    local icons = {
        ['backpack'] = 'backpack',
        ['shoulderbag'] = 'bag-shopping',
        ['handbag'] = 'briefcase',
        ['twohand'] = 'box',
        ['tucked'] = 'wallet'
    }
    return icons[bagType] or 'bag-shopping'
end

-------------------------------------------------------------------------------
-- EXPORTS
-------------------------------------------------------------------------------

exports('StartSearchPlayer', StartSearchPlayer)
exports('StartTakeBag', StartTakeBag)
