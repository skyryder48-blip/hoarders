--[[
    Server Discord Webhooks - free-hoarder
    Logs significant events to Discord for admin monitoring
]]

local webhookUrl = nil

-- Initialize webhook from config
CreateThread(function()
    Wait(500) -- Wait for config to load
    if Config and Config.Discord and Config.Discord.enabled then
        webhookUrl = Config.Discord.webhookUrl
        if webhookUrl and webhookUrl ~= '' and webhookUrl ~= 'YOUR_WEBHOOK_URL_HERE' then
            print('[free-hoarder] Discord webhook logging enabled')
        else
            webhookUrl = nil
            print('[free-hoarder] Discord webhook URL not configured')
        end
    end
end)

-------------------------------------------------------------------------------
-- WEBHOOK SENDING
-------------------------------------------------------------------------------

---Send a message to Discord webhook
---@param title string
---@param description string
---@param color number Decimal color value
---@param fields table|nil Array of {name, value, inline} objects
local function SendToDiscord(title, description, color, fields)
    if not webhookUrl then return end
    
    local embed = {
        {
            title = title,
            description = description,
            color = color or 3447003, -- Default blue
            fields = fields or {},
            footer = {
                text = 'free-hoarder • ' .. os.date('%Y-%m-%d %H:%M:%S')
            }
        }
    }
    
    PerformHttpRequest(webhookUrl, function(err, text, headers)
        if err ~= 200 and err ~= 204 then
            print('[free-hoarder] Discord webhook error:', err)
        end
    end, 'POST', json.encode({ embeds = embed }), { ['Content-Type'] = 'application/json' })
end

-------------------------------------------------------------------------------
-- LOGGING FUNCTIONS
-------------------------------------------------------------------------------

-- Colors
local Colors = {
    GREEN = 3066993,
    RED = 15158332,
    ORANGE = 15105570,
    BLUE = 3447003,
    YELLOW = 16776960,
    PURPLE = 10181046,
}

---Log bag equipped event
---@param source number Player server ID
---@param bagName string
---@param slotName string
---@param capacity table {weight, slots}
function LogBagEquipped(source, bagName, slotName, capacity)
    if not Config.Discord or not Config.Discord.logEquip then return end
    
    local playerName = GetPlayerName(source) or 'Unknown'
    local identifiers = GetPlayerIdentifiers(source)
    local steam = 'N/A'
    local license = 'N/A'
    
    for _, id in ipairs(identifiers) do
        if string.find(id, 'steam:') then steam = id end
        if string.find(id, 'license:') then license = id end
    end
    
    SendToDiscord(
        '🎒 Bag Equipped',
        ('**%s** equipped a bag'):format(playerName),
        Colors.GREEN,
        {
            { name = 'Player', value = playerName, inline = true },
            { name = 'Server ID', value = tostring(source), inline = true },
            { name = 'Bag', value = bagName, inline = true },
            { name = 'Slot', value = slotName, inline = true },
            { name = 'Capacity', value = ('+%dg / +%d slots'):format(capacity.weight or 0, capacity.slots or 0), inline = true },
            { name = 'License', value = license, inline = false },
        }
    )
end

---Log bag dropped to ground event
---@param source number Player server ID
---@param bagName string
---@param coords vector3
---@param reason string Why it was dropped
function LogBagDropped(source, bagName, coords, reason)
    if not Config.Discord or not Config.Discord.logDrop then return end
    
    local playerName = GetPlayerName(source) or 'Unknown'
    
    SendToDiscord(
        '📦 Bag Dropped',
        ('**%s** dropped a bag to the ground'):format(playerName),
        Colors.ORANGE,
        {
            { name = 'Player', value = playerName, inline = true },
            { name = 'Server ID', value = tostring(source), inline = true },
            { name = 'Bag', value = bagName, inline = true },
            { name = 'Reason', value = reason or 'Unknown', inline = true },
            { name = 'Location', value = ('%.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z), inline = false },
        }
    )
end

---Log bag unequipped event
---@param source number Player server ID
---@param bagName string
---@param slotName string
function LogBagUnequipped(source, bagName, slotName)
    if not Config.Discord or not Config.Discord.logUnequip then return end
    
    local playerName = GetPlayerName(source) or 'Unknown'
    
    SendToDiscord(
        '🎒 Bag Unequipped',
        ('**%s** unequipped a bag'):format(playerName),
        Colors.BLUE,
        {
            { name = 'Player', value = playerName, inline = true },
            { name = 'Server ID', value = tostring(source), inline = true },
            { name = 'Bag', value = bagName, inline = true },
            { name = 'Slot', value = slotName, inline = true },
        }
    )
end

---Log suspicious activity
---@param source number Player server ID
---@param activity string Description of suspicious activity
---@param details table Additional details
function LogSuspiciousActivity(source, activity, details)
    if not Config.Discord or not Config.Discord.logSuspicious then return end
    
    local playerName = GetPlayerName(source) or 'Unknown'
    local identifiers = GetPlayerIdentifiers(source)
    local steam = 'N/A'
    local license = 'N/A'
    
    for _, id in ipairs(identifiers) do
        if string.find(id, 'steam:') then steam = id end
        if string.find(id, 'license:') then license = id end
    end
    
    local fields = {
        { name = 'Player', value = playerName, inline = true },
        { name = 'Server ID', value = tostring(source), inline = true },
        { name = 'Activity', value = activity, inline = false },
        { name = 'License', value = license, inline = false },
    }
    
    if details then
        for k, v in pairs(details) do
            table.insert(fields, { name = tostring(k), value = tostring(v), inline = true })
        end
    end
    
    SendToDiscord(
        '⚠️ Suspicious Activity',
        ('Potential exploit detected for **%s**'):format(playerName),
        Colors.RED,
        fields
    )
end

---Log admin action
---@param adminSource number Admin server ID
---@param action string What action was taken
---@param targetSource number|nil Target player if applicable
---@param details string Additional details
function LogAdminAction(adminSource, action, targetSource, details)
    if not Config.Discord or not Config.Discord.logAdmin then return end
    
    local adminName = GetPlayerName(adminSource) or 'Console'
    local targetName = targetSource and GetPlayerName(targetSource) or 'N/A'
    
    SendToDiscord(
        '🔧 Admin Action',
        ('**%s** performed an admin action'):format(adminName),
        Colors.PURPLE,
        {
            { name = 'Admin', value = adminName, inline = true },
            { name = 'Action', value = action, inline = true },
            { name = 'Target', value = targetName, inline = true },
            { name = 'Details', value = details or 'None', inline = false },
        }
    )
end

---Log bag durability break
---@param source number Player server ID
---@param bagName string
function LogBagBroken(source, bagName)
    if not Config.Discord or not Config.Discord.logDurability then return end
    
    local playerName = GetPlayerName(source) or 'Unknown'
    
    SendToDiscord(
        '💔 Bag Broken',
        ('**%s**\'s bag broke from wear'):format(playerName),
        Colors.RED,
        {
            { name = 'Player', value = playerName, inline = true },
            { name = 'Bag', value = bagName, inline = true },
        }
    )
end
