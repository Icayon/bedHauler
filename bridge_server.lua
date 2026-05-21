-- =====================================================================
--  BRIDGE SERVER — Abstracción multi-framework
--  QBCore | QBox (qbx_core) | ESX (es_extended) | Standalone
-- =====================================================================

Bridge = {}

-- ─── Detección ──────────────────────────────────────────────────────

local _fw

if GetResourceState('qbx_core') == 'started' then
    _fw = 'qbox'
elseif GetResourceState('qb-core') == 'started' then
    _fw = 'qbcore'
elseif GetResourceState('es_extended') == 'started' then
    _fw = 'esx'
else
    _fw = 'standalone'
end

print(('[bedHauler] Framework (servidor): %s'):format(_fw))

-- ─── Objeto de framework ────────────────────────────────────────────

local _QBCore, _ESX

if _fw == 'qbcore' then
    _QBCore = exports['qb-core']:GetCoreObject()
elseif _fw == 'esx' then
    _ESX = exports['es_extended']:getSharedObject()
end
-- QBox usa exports directos, no necesita core object

-- ─── Validar jugador activo ──────────────────────────────────────────

function Bridge.GetPlayer(src)
    if _fw == 'qbcore' then
        return _QBCore.Functions.GetPlayer(src)
    elseif _fw == 'qbox' then
        return exports.qbx_core:GetPlayer(src)
    elseif _fw == 'esx' then
        return _ESX.GetPlayerFromId(src)
    else
        return GetPlayerName(src) and {} or nil
    end
end

-- ─── Registro de comandos ────────────────────────────────────────────

function Bridge.AddCommand(name, desc, params, cb, permission)
    RegisterCommand(name, function(source, args)
        if not Config.AdminOnly or IsPlayerAceAllowed(source, Config.AdminAce) then
            cb(source, args)
        end
    end, false)
end

-- ─── Notificación servidor → cliente ────────────────────────────────

function Bridge.Notify(src, message, notifType)
    if _fw == 'qbcore' then
        TriggerClientEvent('QBCore:Notify', src, message, notifType)
    elseif _fw == 'qbox' then
        TriggerClientEvent('ox_lib:notify', src, { description = message, type = notifType or 'inform' })
    elseif _fw == 'esx' then
        TriggerClientEvent('esx:showNotification', src, message)
    else
        TriggerClientEvent('chat:addMessage', src, {
            color = notifType == 'error' and {255, 80, 80} or {80, 255, 80},
            args  = {'BedHauler', message},
        })
    end
end
