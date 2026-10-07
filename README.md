# FiveM Duty System

A standalone duty system for roleplay servers. Players clock in and out by department, their shift time is tracked, and everything is logged to a Discord channel.

## Features
- **Clock in / out** with a department, badge number and callsign
- **Discord logging** for clock-ins, clock-outs, kicks, disconnects and 911 calls
- **911 calls** that alert everyone who is on duty (with a cooldown so it can't be spammed)
- **Live blips** so on-duty players can see each other on the map
- **Kick off duty** for admins
- **Duty time** check for players
- **Auto clock-out** when someone disconnects

## Installation
1. Drop the folder into your resources and add `ensure <folder name>` to your `server.cfg`.
2. Open `config.lua` and set your webhook URL and server name.
3. Give your staff and departments their permissions (see below).

## Permissions
Everything runs on ACE permissions. Example for `server.cfg`:

```cfg
add_ace group.police duty.lapd allow
add_ace group.sheriff duty.bcso allow
add_ace group.admin duty.kickoff allow
add_ace group.admin duty.view allow
```

Each department in `config.lua` has its own `dutyAce`, so add or rename departments there. `duty.kickoff` allows `/kickoffduty` and `duty.view` allows `/onduty`. You can change both names in the config too.

## Commands
| Command | What it does |
|---|---|
| `/clockin [department] [badge] [callsign]` | Start your shift |
| `/clockout` | End your shift |
| `/911 [reason]` | Send a call to everyone on duty |
| `/dutytime` | See how long you've been on duty |
| `/onduty` | List who is on duty (needs `duty.view`) |
| `/kickoffduty [id]` | Take someone off duty (needs `duty.kickoff`) |

`/kickoffduty` and `/onduty` also work from the server console.

## Config
All of this is in `config.lua`:
- `ServerName` and `WEBHOOK_URL` (leave the webhook empty to turn logging off)
- `Call911Cooldown`: seconds between 911 calls per player
- `MaxFieldLength`: max length for badge and callsign
- `BlipsEnabled` and `BlipRefreshMs`: turn the map blips on or off and set how often they update
- `GetPostal`: hook for your postal resource, so 911 calls include a postal. Without it, calls show "Unknown".

The config file is server-only on purpose. Don't make it a shared script, or players will be able to read your webhook URL.

## Notifications
Messages show up in the default chat, so nothing else is needed. If you use [ox_lib](https://github.com/overextended/ox_lib) and want proper pop-up notifications, set `USE_OX_LIB = true` at the top of `client.lua`.

## Exports (server)
```lua
exports['your-resource-name']:GetOnDutyOfficers() -- table of [playerId] = { department, badge, callsign, startTime }
exports['your-resource-name']:IsOnDuty(playerId)  -- true / false
```

## Requirements
- OneSync (the server needs it to read player positions for blips and 911 calls)
- ox_lib is **optional**
