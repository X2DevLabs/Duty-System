local onDuty = {}
local onDutyCount = 0
local last911 = {}

local deptByName, deptNames = {}, {}
for _, dept in ipairs(Config.AllowedDepartments) do
    deptByName[dept.name:lower()] = dept
    deptNames[#deptNames + 1] = dept.name
end

local function FormatDuration(totalSeconds)
    local h = math.floor(totalSeconds / 3600)
    local m = math.floor((totalSeconds % 3600) / 60)
    local s = totalSeconds % 60
    return string.format('%02d:%02d:%02d', h, m, s)
end

local function Notify(src, title, description, ntype)
    if src == 0 then
        print(('[duty] %s: %s'):format(title, description))
        return
    end
    TriggerClientEvent('duty:notify', src, {
        title = title,
        description = description,
        type = ntype or 'inform',
        duration = 5000
    })
end

local function GetDiscordId(src)
    local id = GetPlayerIdentifierByType(src, 'discord')
    if not id then return nil end
    return (id:gsub('discord:', ''))
end

local function Mention(discordId)
    return discordId and ('<@%s>'):format(discordId) or 'Not linked'
end

local function Clean(str)
    str = tostring(str):gsub('%c', '')
    return str:sub(1, Config.MaxFieldLength)
end

local function Log(embed)
    if not Config.WEBHOOK_URL or Config.WEBHOOK_URL == '' then return end
    embed.footer = embed.footer or { text = Config.ServerName .. ' - Logged by FiveM Server' }
    embed.timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    PerformHttpRequest(Config.WEBHOOK_URL, function() end, 'POST', json.encode({
        embeds = { embed },
        allowed_mentions = { parse = {} }
    }), { ['Content-Type'] = 'application/json' })
end

local function SyncBlips()
    if onDutyCount == 0 then return end

    local list = {}
    for src, data in pairs(onDuty) do
        local c = GetEntityCoords(GetPlayerPed(src))
        list[#list + 1] = { id = src, x = c.x, y = c.y, z = c.z, label = data.label }
    end

    for src in pairs(onDuty) do
        TriggerClientEvent('duty:syncBlips', src, list)
    end
end

if Config.BlipsEnabled then
    CreateThread(function()
        while true do
            Wait(Config.BlipRefreshMs)
            SyncBlips()
        end
    end)
end

local function ClockOut(src, mode, kickedBy)
    local data = onDuty[src]
    if not data then return nil end

    local duration = FormatDuration(os.time() - data.startTime)
    onDuty[src] = nil
    onDutyCount = onDutyCount - 1

    if mode ~= 'disconnect' then
        TriggerClientEvent('duty:syncBlips', src, {})
    end
    SyncBlips()

    local name = GetPlayerName(src) or 'Unknown'
    local discordId = GetDiscordId(src)

    local title, extra = ':red_circle: Clock-Out Notification', ''
    if mode == 'disconnect' then
        title = ':red_circle: Automatic Clock-Out'
        extra = '\nDisconnected while on duty.'
    elseif mode == 'kick' then
        title = ':red_circle: Kicked Off Duty Notification'
        extra = ('\nKicked by **%s**'):format(kickedBy or 'Unknown')
    end

    local fields = {
        { name = 'Player Name', value = name, inline = true },
        { name = 'Player ID', value = tostring(src), inline = true },
        { name = 'Discord', value = Mention(discordId), inline = true },
        { name = 'Department', value = data.department, inline = true },
        { name = 'Badge Number', value = data.badge, inline = true },
        { name = 'Callsign', value = data.callsign, inline = true },
        { name = 'Duty Time', value = duration, inline = true },
        { name = 'Clock-Out Time', value = ('<t:%d:t>'):format(os.time()), inline = true },
    }
    if mode == 'kick' then
        fields[#fields + 1] = { name = 'Kicked By', value = kickedBy or 'Unknown', inline = true }
    end

    Log({
        title = title,
        description = ('**%s** (Callsign: %s, Badge: %s) is no longer on duty.%s'):format(
            name, data.callsign, data.badge, extra),
        color = 16711680,
        fields = fields
    })

    return duration
end

RegisterCommand('clockin', function(source, args)
    if source == 0 then return Notify(0, 'Error', 'This command is in-game only.') end

    local deptArg, badge, callsign = args[1], args[2], args[3]
    if not deptArg or not badge or not callsign then
        return Notify(source, 'Error', 'Usage: /clockin [department] [badge] [callsign]', 'error')
    end

    local dept = deptByName[deptArg:lower()]
    if not dept then
        return Notify(source, 'Error',
            'Invalid department. Allowed: ' .. table.concat(deptNames, ', '), 'error')
    end

    if not IsPlayerAceAllowed(source, dept.dutyAce) then
        return Notify(source, 'Error', 'You do not have permission for ' .. dept.name .. ' duty.', 'error')
    end

    if onDuty[source] then
        return Notify(source, 'Error', 'You are already on duty.', 'error')
    end

    badge, callsign = Clean(badge), Clean(callsign)

    onDuty[source] = {
        department = dept.name,
        badge = badge,
        callsign = callsign,
        ace = dept.dutyAce,
        startTime = os.time(),
        label = ('%s (%s, Badge %s)'):format(dept.name, callsign, badge)
    }
    onDutyCount = onDutyCount + 1
    SyncBlips()

    Notify(source, 'Success',
        ('You have clocked in as %s (Callsign: %s, Badge: %s).'):format(dept.name, callsign, badge), 'success')

    local name = GetPlayerName(source)
    Log({
        title = ':green_circle: Clock-In Notification',
        description = ('**%s** (Callsign: %s, Badge: %s) has clocked in.'):format(name, callsign, badge),
        color = 65280,
        fields = {
            { name = 'Player ID', value = tostring(source), inline = true },
            { name = 'Discord', value = Mention(GetDiscordId(source)), inline = true },
            { name = 'Department', value = dept.name, inline = true },
            { name = 'Badge Number', value = badge, inline = true },
            { name = 'Callsign', value = callsign, inline = true },
            { name = 'Clock-In Time', value = ('<t:%d:t>'):format(os.time()), inline = true },
        }
    })
end, false)

RegisterCommand('clockout', function(source)
    if source == 0 then return Notify(0, 'Error', 'This command is in-game only.') end

    local duration = ClockOut(source, 'clockout')
    if not duration then
        return Notify(source, 'Error', 'You are not currently on duty.', 'error')
    end
    Notify(source, 'Success', 'You have clocked out. Duration: ' .. duration, 'success')
end, false)

RegisterCommand('911', function(source, args)
    if source == 0 then return Notify(0, 'Error', 'This command is in-game only.') end

    local reason = table.concat(args, ' ')
    if reason == '' then
        return Notify(source, 'Error', 'Usage: /911 [reason]', 'error')
    end
    reason = reason:gsub('%c', ''):sub(1, 300)

    local now = os.time()
    if last911[source] and now - last911[source] < Config.Call911Cooldown then
        return Notify(source, 'Error', 'Please wait before sending another 911 call.', 'error')
    end
    last911[source] = now

    local postal = Config.GetPostal(GetEntityCoords(GetPlayerPed(source))) or 'Unknown'
    local name = GetPlayerName(source)

    local recipients = 0
    for target in pairs(onDuty) do
        recipients = recipients + 1
        TriggerClientEvent('duty:notify', target, {
            title = '911 Call',
            description = ('%s | Postal: %s'):format(reason, postal),
            type = 'inform',
            duration = 10000
        })
    end

    if recipients > 0 then
        Notify(source, 'Success', 'Your 911 call has been sent.', 'success')
    else
        Notify(source, 'Notice', 'Your call was logged, but nobody is on duty right now.', 'warning')
    end

    Log({
        title = ':rotating_light: 911 Call Notification',
        description = ('**%s** has reported an emergency.\n\n**Reason:** %s\n**Nearest Postal:** %s'):format(
            name, reason, postal),
        color = 16711680,
        fields = {
            { name = 'Reported By', value = name, inline = true },
            { name = 'Officers Alerted', value = tostring(recipients), inline = true },
            { name = 'Time', value = ('<t:%d:t>'):format(now), inline = true },
        }
    })
end, false)

RegisterCommand('dutytime', function(source)
    if source == 0 then return Notify(0, 'Error', 'This command is in-game only.') end

    local data = onDuty[source]
    if not data then
        return Notify(source, 'Error', 'You are not on duty.', 'error')
    end
    Notify(source, 'Duty Time', 'You have been on duty for ' .. FormatDuration(os.time() - data.startTime) .. '.')
end, false)

RegisterCommand('kickoffduty', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, Config.KickAce) then
        return Notify(source, 'Error', 'You do not have permission to use this command.', 'error')
    end

    local target = tonumber(args[1])
    if not target then
        return Notify(source, 'Error', 'Usage: /kickoffduty [targetPlayerID]', 'error')
    end

    if not GetPlayerName(target) then
        return Notify(source, 'Error', ('Player %d is not online.'):format(target), 'error')
    end

    local kickedByName = source == 0 and 'Console' or GetPlayerName(source)
    local targetName = GetPlayerName(target)

    if not ClockOut(target, 'kick', kickedByName) then
        return Notify(source, 'Error', ('%s (ID: %d) is not currently on duty.'):format(targetName, target), 'error')
    end

    Notify(source, 'Success', ('You have kicked %s (ID: %d) off duty.'):format(targetName, target), 'success')
    Notify(target, 'Duty', 'You were taken off duty by ' .. kickedByName .. '.', 'warning')
end, false)

RegisterCommand('onduty', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(source, Config.ViewAce) then
        return Notify(source, 'Error', 'You do not have permission to use this command.', 'error')
    end

    local lines = {}
    for id, data in pairs(onDuty) do
        lines[#lines + 1] = ('%s (%s, Badge %s, Callsign %s) (ID: %d)'):format(
            GetPlayerName(id) or 'Unknown', data.department, data.badge, data.callsign, id)
    end

    if #lines == 0 then
        return Notify(source, 'On-Duty Players', 'Nobody is on duty.')
    end
    table.sort(lines)
    Notify(source, 'On-Duty Players', table.concat(lines, '\n'))
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    last911[src] = nil
    ClockOut(src, 'disconnect')
end)

exports('GetOnDutyOfficers', function()
    local copy = {}
    for id, d in pairs(onDuty) do
        copy[id] = { department = d.department, badge = d.badge, callsign = d.callsign, startTime = d.startTime }
    end
    return copy
end)

exports('IsOnDuty', function(src)
    return onDuty[src] ~= nil
end)
