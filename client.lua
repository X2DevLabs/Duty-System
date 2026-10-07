-- Set to true if you run ox_lib and want its notifications.
-- Otherwise messages show in the default chat, so the script stays standalone.
local USE_OX_LIB = false

local BLIP_SPRITE, BLIP_COLOUR, BLIP_SCALE = 1, 3, 0.9

local blips = {}

local NOTIFY_COLORS = {
    error   = { 255, 80, 80 },
    success = { 80, 220, 120 },
    warning = { 255, 190, 60 },
    inform  = { 100, 170, 255 },
}

RegisterNetEvent('duty:notify', function(data)
    if USE_OX_LIB and GetResourceState('ox_lib') == 'started' then
        TriggerEvent('ox_lib:notify', data)
        return
    end

    TriggerEvent('chat:addMessage', {
        color = NOTIFY_COLORS[data.type] or NOTIFY_COLORS.inform,
        multiline = true,
        args = { data.title or 'Duty', data.description or '' }
    })
end)

local function CreateOfficerBlip(entry)
    local blip = AddBlipForCoord(entry.x, entry.y, entry.z)
    SetBlipSprite(blip, BLIP_SPRITE)
    SetBlipColour(blip, BLIP_COLOUR)
    SetBlipScale(blip, BLIP_SCALE)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(entry.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

RegisterNetEvent('duty:syncBlips', function(list)
    local myId = GetPlayerServerId(PlayerId())
    local seen = {}

    for _, entry in ipairs(list) do
        if entry.id ~= myId then
            seen[entry.id] = true
            local blip = blips[entry.id]
            if blip and DoesBlipExist(blip) then
                SetBlipCoords(blip, entry.x, entry.y, entry.z)
            else
                blips[entry.id] = CreateOfficerBlip(entry)
            end
        end
    end

    for id, blip in pairs(blips) do
        if not seen[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            blips[id] = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
