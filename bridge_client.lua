-- =====================================================================
--  BRIDGE CLIENT — Abstracción multi-framework
--  QBCore | QBox (qbx_core) | ESX (es_extended) | Standalone
-- =====================================================================

Bridge = {}

-- ─── Detección ──────────────────────────────────────────────────────

local _fw, _target

if GetResourceState('qbx_core') == 'started' then
    _fw = 'qbox'
elseif GetResourceState('qb-core') == 'started' then
    _fw = 'qbcore'
elseif GetResourceState('es_extended') == 'started' then
    _fw = 'esx'
else
    _fw = 'standalone'
end

if GetResourceState('ox_target') == 'started' then
    _target = 'ox_target'
elseif GetResourceState('qb-target') == 'started' then
    _target = 'qb-target'
elseif GetResourceState('bt-target') == 'started' then
    _target = 'bt-target'
else
    _target = 'none'
end

Bridge.HasTarget = _target ~= 'none'
Bridge.HasOxLib  = GetResourceState('ox_lib') == 'started'

print(('[bedHauler] Framework: %s | Target: %s | ox_lib: %s'):format(_fw, _target, tostring(Bridge.HasOxLib)))

-- ─── Objeto de framework ────────────────────────────────────────────

local _QBCore, _ESX

if _fw == 'qbcore' then
    _QBCore = exports['qb-core']:GetCoreObject()
elseif _fw == 'esx' then
    _ESX = exports['es_extended']:getSharedObject()
end
-- QBox usa ox_lib directamente, no necesita core object

-- ─── Notificaciones ─────────────────────────────────────────────────

function Bridge.Notify(message, notifType)
    if Bridge.HasOxLib then
        exports.ox_lib:notify({ description = message, type = notifType or 'inform' })
    elseif _fw == 'qbcore' then
        _QBCore.Functions.Notify(message, notifType)
    elseif _fw == 'esx' then
        _ESX.ShowNotification(message)
    else
        TriggerEvent('chat:addMessage', {
            color = notifType == 'error' and {255, 80, 80} or {80, 255, 80},
            args  = {'BedHauler', message},
        })
    end
end

-- ─── Barra de progreso ───────────────────────────────────────────────
-- options: { disableMovement, disableCarMovement, disableMouse, disableCombat }

function Bridge.Progressbar(name, label, duration, options, onComplete, onCancel)
    if not Config.UseProgressbar then
        CreateThread(function()
            Wait(duration)
            if onComplete then onComplete() end
        end)
        return
    end
    if _fw == 'qbcore' and _QBCore.Functions.Progressbar then
        _QBCore.Functions.Progressbar(name, label, duration, false, true, options, {}, {}, {}, onComplete, onCancel)
    elseif Bridge.HasOxLib then
        CreateThread(function()
            local ok = exports.ox_lib:progressBar({
                duration     = duration,
                label        = label,
                useWhileDead = false,
                canCancel    = true,
                disable = {
                    move   = options.disableMovement    or false,
                    car    = options.disableCarMovement or false,
                    mouse  = options.disableMouse       or false,
                    combat = options.disableCombat      or false,
                },
            })
            if ok then
                if onComplete then onComplete() end
            else
                if onCancel then onCancel() end
            end
        end)
    elseif GetResourceState('progressbar') == 'started' then
        exports['progressbar']:Progress({
            name = name, duration = duration, label = label,
            useWhileDead = false, canCancel = true,
            controlDisables = {
                disableMovement    = options.disableMovement    or false,
                disableCarMovement = options.disableCarMovement or false,
                disableMouse       = options.disableMouse       or false,
                disableCombat      = options.disableCombat      or false,
            },
        }, function(cancelled)
            if not cancelled then
                if onComplete then onComplete() end
            else
                if onCancel then onCancel() end
            end
        end)
    else
        -- Fallback sin barra visual
        CreateThread(function()
            Wait(duration)
            if onComplete then onComplete() end
        end)
    end
end

-- ─── Sistema de targeting ────────────────────────────────────────────

function Bridge.RegisterVehicleTarget(onLoad, onUnload, canLoad, canUnload, distance)
    if _target == 'qb-target' then
        exports['qb-target']:AddGlobalVehicle({
            options = {
                { type = 'client', icon = 'fas fa-truck-loading',  label = 'Subir a la Pick-Up',  action = onLoad,   canInteract = canLoad   },
                { type = 'client', icon = 'fas fa-truck-ramp-box', label = 'Bajar de la Pick-Up', action = onUnload, canInteract = canUnload },
            },
            distance = distance,
        })
    elseif _target == 'ox_target' then
        exports.ox_target:addGlobalVehicle({
            { icon = 'fas fa-truck-loading',  label = 'Subir a la Pick-Up',  onSelect = function(d) onLoad(d.entity)   end, canInteract = canLoad,   distance = distance },
            { icon = 'fas fa-truck-ramp-box', label = 'Bajar de la Pick-Up', onSelect = function(d) onUnload(d.entity) end, canInteract = canUnload, distance = distance },
        })
    elseif _target == 'bt-target' then
        exports['bt-target']:AddGlobalVehicle({
            options = {
                { type = 'client', icon = 'fas fa-truck-loading',  label = 'Subir a la Pick-Up',  action = onLoad,   canInteract = canLoad   },
                { type = 'client', icon = 'fas fa-truck-ramp-box', label = 'Bajar de la Pick-Up', action = onUnload, canInteract = canUnload },
            },
            distance = distance,
        })
    end
end

function Bridge.RemoveVehicleTarget()
    local labels = {'Subir a la Pick-Up', 'Bajar de la Pick-Up'}
    if _target == 'qb-target' then
        pcall(function() exports['qb-target']:RemoveGlobalVehicle(labels) end)
    elseif _target == 'ox_target' then
        pcall(function() exports.ox_target:removeGlobalVehicle(labels) end)
    elseif _target == 'bt-target' then
        pcall(function() exports['bt-target']:RemoveGlobalVehicle(labels) end)
    end
end
