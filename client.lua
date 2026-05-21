-- =====================================================================
--  TRANSPORTE DE MOTOS v1.1 — QBCore + qb-target
--  Carga motos/quads en la parte trasera de pick-ups
-- =====================================================================

-- ─── Notificación mínima lateral ────────────────────────────────────
local _miniMsg     = nil
local _miniExpires = 0

local function MiniNotify(msg)
    _miniMsg     = msg
    _miniExpires = GetGameTimer() + 2500
end

CreateThread(function()
    while true do
        if _miniMsg then
            if GetGameTimer() < _miniExpires then
                SetTextFont(4)
                SetTextScale(0.0, 0.26)
                SetTextColour(215, 215, 215, 140)
                SetTextEntry("STRING")
                AddTextComponentSubstringPlayerName(_miniMsg)
                DrawText(0.795, 0.925)
                Wait(0)
            else
                _miniMsg = nil
                Wait(100)
            end
        else
            Wait(100)
        end
    end
end)

-- Almacén de props de amarre (locales, no sincronizados): cargoVehHandle → { prop1, ... }
local ActiveProps = {}

-- Guard anti-doble-activación
local _loadingInProgress = {}

-- Índice de vehículos cargados por netId: cargoNetId → true
local _activeCargo = {}

-- Índice de cargo por transporte: transportNetId → { cargoNetId = true }
-- Evita iterar GetGamePool('CVehicle') en cada operación de carga/descarga.
local _cargoByTransport = {}

-- Caché de vehículos transportadores. Se refresca máximo una vez cada 5 s
-- para evitar iterar el pool completo en cada FindTransporter.
local _transporterCache    = {}
local _transporterCacheTick = 0
local TRANSPORTER_CACHE_TTL = 5000

-- Export para sistemas de Garajes (evita guardar si tiene carga)
exports("HasCargo", function(transportVeh)
    if not DoesEntityExist(transportVeh) then return false end
    return #GetCargo(transportVeh) > 0  -- definida más abajo
end)

-- =====================================================================
--  UTILIDADES INTERNAS
-- =====================================================================

local function EnsureAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local waited = 0
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        waited = waited + 10
        if waited > 5000 then
            print("[bedHauler] ERROR: No se pudo cargar animación: " .. dict)
            return false
        end
    end
    return true
end

local function TakeControl(entity)
    if not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    local attempts = 0
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) do
        Wait(100)
        attempts = attempts + 1
        if attempts > 20 then return false end  -- 2 s máx (era 3 s con 30 intentos)
        NetworkRequestControlOfEntity(entity)
    end
    return true
end

-- ─── Caché de transportadores ────────────────────────────────────────
-- GetGamePool solo se llama como mucho una vez cada TRANSPORTER_CACHE_TTL.
local function RefreshTransporterCache()
    local now = GetGameTimer()
    if now - _transporterCacheTick < TRANSPORTER_CACHE_TTL then return end
    _transporterCacheTick = now
    _transporterCache = {}
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and Config.TransporterVehicles[GetEntityModel(veh)] then
            _transporterCache[#_transporterCache + 1] = veh
        end
    end
end

-- ─── Índice de cargo ─────────────────────────────────────────────────
-- Devuelve todos los vehículos pegados a un transporte.
-- Usa _cargoByTransport como fuente primaria (O(cargo_activo) en vez de O(pool_total)).
-- Si hay entradas no indexadas en _activeCargo, las recupera como fallback
-- y actualiza el índice (auto-healing).
function GetCargo(transportVeh)
    if not DoesEntityExist(transportVeh) then return {} end
    local tNetId = NetworkGetNetworkIdFromEntity(transportVeh)
    if tNetId == 0 then return {} end

    local result = {}
    local set    = _cargoByTransport[tNetId]
    local seen   = {}

    if set then
        for cNetId in pairs(set) do
            local cVeh = NetworkGetEntityFromNetworkId(cNetId)
            if DoesEntityExist(cVeh) and GetEntityAttachedTo(cVeh) == transportVeh then
                result[#result + 1] = cVeh
                seen[cNetId] = true
            end
        end
    end

    -- Fallback: entidades en _activeCargo no presentes en el índice
    -- (cargadas por otros clientes antes de que el state bag handler las indexara)
    for cNetId in pairs(_activeCargo) do
        if not seen[cNetId] then
            local cVeh = NetworkGetEntityFromNetworkId(cNetId)
            if DoesEntityExist(cVeh) and GetEntityAttachedTo(cVeh) == transportVeh then
                result[#result + 1] = cVeh
                if not _cargoByTransport[tNetId] then _cargoByTransport[tNetId] = {} end
                _cargoByTransport[tNetId][cNetId] = true
            end
        end
    end

    return result
end

local function IsSlotTaken(transportVeh, slotId)
    for _, veh in ipairs(GetCargo(transportVeh)) do
        if Entity(veh).state.cargoSlot == slotId then return true end
    end
    return false
end

--- Busca la pick-up válida más cercana usando la caché de transportadores.
local function FindTransporter(playerCoords, excludeVeh)
    RefreshTransporterCache()
    local bestVeh, bestDist = 0, Config.SearchRadius
    for _, veh in ipairs(_transporterCache) do
        if veh ~= excludeVeh and DoesEntityExist(veh) then
            local dist = #(playerCoords - GetEntityCoords(veh))
            if dist < bestDist then
                bestVeh = veh
                bestDist = dist
            end
        end
    end
    return bestVeh
end

local function LockVehicle(veh, lock)
    if lock then
        SetVehicleDoorsLocked(veh, 4)
        SetVehicleDoorsLockedForAllPlayers(veh, true)
    else
        SetVehicleDoorsLocked(veh, 1)
        SetVehicleDoorsLockedForAllPlayers(veh, false)
    end
end

local TailgateVehicles = {
    [`bison`]    = true,
    [`dubsta3`]  = true,
    [`rebel`]    = true,
    [`slamvan`]  = true,
    [`yosemite`] = true,
    [`yosemite2`] = true,
    [`yosemite3`] = true,
}

local function SetTailgate(transportVeh, open)
    if not DoesEntityExist(transportVeh) then return end
    if not TailgateVehicles[GetEntityModel(transportVeh)] then return end
    if open then
        pcall(SetVehicleDoorOpen, transportVeh, 5, false, false)
    else
        pcall(SetVehicleDoorShut, transportVeh, 5, false)
    end
end

-- =====================================================================
--  SISTEMA DE PROPS DE AMARRE (locales, no sincronizados)
-- =====================================================================

local STRAP_MODEL = `dwk_moto_rope`

local function EnsureModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local waited = 0
    while not HasModelLoaded(model) do
        Wait(10)
        waited = waited + 10
        if waited > 5000 then
            print('[bedHauler] ERROR: No se pudo cargar modelo prop')
            return false
        end
    end
    return true
end

--- Crea un prop de amarre visual LOCAL (no de red) sobre la moto/quad cargada.
--- isNetwork=false → no consume slots de entidades de red ni RAM en otros clientes.
local function CreateStrapProp(cargoVeh, transportVeh, slotOffset)
    if not EnsureModel(STRAP_MODEL) then return end

    local props = {}
    local tPos  = GetEntityCoords(transportVeh)

    -- false, false, false → prop local, no sincronizado con otros clientes
    local prop = CreateObject(STRAP_MODEL, tPos.x, tPos.y, tPos.z + 1.0, false, false, false)

    if DoesEntityExist(prop) then
        SetEntityCollision(prop, false, false)
        AttachEntityToEntity(
            prop, cargoVeh, 0,
            0.0, 0.0, 0.2,
            0.0, 90.0, 0.0,
            false, false, false, false, 20, true
        )
        props[#props + 1] = prop
    end

    SetModelAsNoLongerNeeded(STRAP_MODEL)
    ActiveProps[cargoVeh] = props
end

--- Elimina los props de amarre locales de un vehículo cargado.
local function DeleteStrapProps(cargoVeh)
    if ActiveProps[cargoVeh] then
        for _, prop in ipairs(ActiveProps[cargoVeh]) do
            if DoesEntityExist(prop) then
                DetachEntity(prop, true, true)
                DeleteEntity(prop)
            end
        end
        ActiveProps[cargoVeh] = nil
    end
end

-- =====================================================================
--  FUNCIÓN: CARGAR VEHÍCULO EN LA PICK-UP
-- =====================================================================

local function CargarVehiculo(targetVeh)
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local cargoType = Config.CargoClasses[GetVehicleClass(targetVeh)]
    if not cargoType then
        Bridge.Notify("Este vehículo no se puede transportar", "error")
        return
    end

    local transportVeh = FindTransporter(coords, targetVeh)
    if transportVeh == 0 then
        Bridge.Notify("No hay una Pick-Up compatible cerca", "error")
        return
    end

    local transportData = Config.TransporterVehicles[GetEntityModel(transportVeh)]
    if not transportData then return end

    local cargo      = GetCargo(transportVeh)
    local selectedSlot = nil

    local slotTypeMap = {}
    for _, veh in ipairs(cargo) do
        local slotId = Entity(veh).state.cargoSlot
        if slotId then
            slotTypeMap[slotId] = Config.CargoClasses[GetVehicleClass(veh)]
        end
    end

    local function PlazaConflict(slotId, wantType)
        local plaza = math.ceil(slotId / 3)
        for sid, sType in pairs(slotTypeMap) do
            if math.ceil(sid / 3) == plaza then
                if wantType == "quad" and sType == "moto" then return true end
                if wantType == "moto" and sType == "quad" then return true end
            end
        end
        return false
    end

    local closestDist = 9999.0
    for _, slot in ipairs(transportData.slots) do
        if slot.type == cargoType
           and not IsSlotTaken(transportVeh, slot.id)
           and not PlazaConflict(slot.id, cargoType) then
            local slotCoords = GetOffsetFromEntityInWorldCoords(transportVeh, slot.offset.x, slot.offset.y, slot.offset.z)
            local dist = #(coords - slotCoords)
            if dist < closestDist then
                closestDist = dist
                selectedSlot = slot
            end
        end
    end

    if not selectedSlot then
        local blockedByPlaza = false
        for _, slot in ipairs(transportData.slots) do
            if slot.type == cargoType and not IsSlotTaken(transportVeh, slot.id) and PlazaConflict(slot.id, cargoType) then
                blockedByPlaza = true
                break
            end
        end
        if blockedByPlaza then
            if cargoType == "quad" then
                Bridge.Notify("La plaza tiene motos, debe estar vacía para subir un Quad", "error")
            else
                Bridge.Notify("La plaza tiene un Quad ocupando el espacio", "error")
            end
        else
            Bridge.Notify("No hay huecos disponibles en este vehículo", "error")
        end
        return
    end

    local transportDriver = GetPedInVehicleSeat(transportVeh, -1)
    local hasDriver = transportDriver ~= 0 and transportDriver ~= ped and DoesEntityExist(transportDriver)

    if _loadingInProgress[targetVeh] then return end
    _loadingInProgress[targetVeh] = true

    local ownsTransport = NetworkHasControlOfEntity(transportVeh)
    if ownsTransport then FreezeEntityPosition(transportVeh, true) end

    if hasDriver then
        TaskLookAtEntity(transportDriver, targetVeh, Config.LoadDuration + 3000, 2, 2)
    end

    local minDim, _ = GetModelDimensions(GetEntityModel(transportVeh))
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    AttachCamToEntity(cam, transportVeh, -2.5, minDim.y - 3.5, 1.5, true)
    PointCamAtEntity(cam, targetVeh, 0.0, 0.0, 0.0, true)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 1500, true, false)

    EnsureAnimDict(Config.Anim.dict)
    TaskPlayAnim(ped, Config.Anim.dict, Config.Anim.clip, 8.0, -8.0, -1, Config.Anim.flags, 0.0, false, false, false)

    Bridge.Progressbar("cargar_vehiculo", "Asegurando vehículo...", Config.LoadDuration, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    },
    function() -- COMPLETADO
        if ownsTransport then FreezeEntityPosition(transportVeh, false) end
        RenderScriptCams(false, true, 1000, true, false)
        DestroyCam(cam, false)
        StopAnimTask(ped, Config.Anim.dict, Config.Anim.clip, 1.0)
        ClearPedTasks(ped)

        if not TakeControl(targetVeh) then
            _loadingInProgress[targetVeh] = nil
            Bridge.Notify("Error de red. Inténtalo de nuevo", "error")
            return
        end

        local cargoNetId     = NetworkGetNetworkIdFromEntity(targetVeh)
        local transportNetId = NetworkGetNetworkIdFromEntity(transportVeh)

        -- Mantener la entidad viva en este cliente y en el servidor.
        -- NO se usa SetNetworkIdExistsOnAllMachines(true) para evitar forzar
        -- la entidad en los 400 clientes restantes. SetEntityAsMissionEntity
        -- es suficiente para evitar el despawn local.
        SetEntityAsMissionEntity(targetVeh, true, true)
        SetEntityAsMissionEntity(transportVeh, true, true)

        Entity(targetVeh).state:set('cargoSlot', selectedSlot.id, true)
        LockVehicle(targetVeh, true)
        SetTailgate(transportVeh, true)

        local zAdjust = Config.ClassHeightAdjust and Config.ClassHeightAdjust[GetVehicleClass(targetVeh)] or 0.0
        AttachEntityToEntity(
            targetVeh, transportVeh, 0,
            selectedSlot.offset.x,   selectedSlot.offset.y,   selectedSlot.offset.z + zAdjust,
            selectedSlot.rotation.x, selectedSlot.rotation.y, selectedSlot.rotation.z,
            false, false, true, false, 20, true
        )

        CreateStrapProp(targetVeh, transportVeh, selectedSlot.offset)

        PlaySoundFromEntity(-1, "Drill_Pin_Break", targetVeh, "DLC_HEIST_FLEECA_SOUNDSET", false, 0)
        Wait(280)
        PlaySoundFromEntity(-1, "Drill_Pin_Break", targetVeh, "DLC_HEIST_FLEECA_SOUNDSET", false, 0)

        local tPlate = GetVehicleNumberPlateText(transportVeh):gsub("%s+", "")
        local cPlate = GetVehicleNumberPlateText(targetVeh):gsub("%s+", "")
        TriggerServerEvent('bedHauler:server:NotifyLoad', tPlate, cPlate, selectedSlot.id, transportNetId, cargoNetId)

        -- Actualizar índices locales
        _activeCargo[cargoNetId] = true
        if not _cargoByTransport[transportNetId] then _cargoByTransport[transportNetId] = {} end
        _cargoByTransport[transportNetId][cargoNetId] = true

        _loadingInProgress[targetVeh] = nil
        MiniNotify("Vehículo cargado")
    end,
    function() -- CANCELADO
        if ownsTransport then FreezeEntityPosition(transportVeh, false) end
        RenderScriptCams(false, true, 1000, true, false)
        DestroyCam(cam, false)
        StopAnimTask(ped, Config.Anim.dict, Config.Anim.clip, 1.0)
        ClearPedTasks(ped)
        _loadingInProgress[targetVeh] = nil
        MiniNotify("Cancelado")
    end)
end

-- =====================================================================
--  FUNCIÓN: DESCARGAR VEHÍCULO DE LA PICK-UP
-- =====================================================================

local function DescargarVehiculo(targetVeh)
    local ped       = PlayerPedId()
    local parentVeh = GetEntityAttachedTo(targetVeh)

    if not DoesEntityExist(parentVeh) or parentVeh == 0 then
        Bridge.Notify("Este vehículo no está cargado en nada", "error")
        return
    end

    local transportDriver = GetPedInVehicleSeat(parentVeh, -1)
    local hasDriver = transportDriver ~= 0 and transportDriver ~= ped and DoesEntityExist(transportDriver)

    if _loadingInProgress[targetVeh] then return end
    _loadingInProgress[targetVeh] = true

    local ownsTransport = NetworkHasControlOfEntity(parentVeh)
    if ownsTransport then FreezeEntityPosition(parentVeh, true) end

    if hasDriver then
        TaskLookAtEntity(transportDriver, targetVeh, Config.UnloadDuration + 3000, 2, 2)
    end

    local minDim, _ = GetModelDimensions(GetEntityModel(parentVeh))
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    AttachCamToEntity(cam, parentVeh, -2.5, minDim.y - 3.5, 1.5, true)
    PointCamAtEntity(cam, targetVeh, 0.0, 0.0, 0.0, true)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 1500, true, false)

    EnsureAnimDict(Config.Anim.dict)
    TaskPlayAnim(ped, Config.Anim.dict, Config.Anim.clip, 8.0, -8.0, -1, Config.Anim.flags, 0.0, false, false, false)

    Bridge.Progressbar("descargar_vehiculo", "Bajando vehículo...", Config.UnloadDuration, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    },
    function() -- COMPLETADO
        if ownsTransport then FreezeEntityPosition(parentVeh, false) end
        RenderScriptCams(false, true, 1000, true, false)
        DestroyCam(cam, false)
        StopAnimTask(ped, Config.Anim.dict, Config.Anim.clip, 1.0)
        ClearPedTasks(ped)

        if not TakeControl(targetVeh) then
            _loadingInProgress[targetVeh] = nil
            Bridge.Notify("Error de red. Inténtalo de nuevo", "error")
            return
        end

        local slotId     = Entity(targetVeh).state.cargoSlot
        local cargoNetId = NetworkGetNetworkIdFromEntity(targetVeh)

        local tPlate = GetVehicleNumberPlateText(parentVeh):gsub("%s+", "")
        TriggerServerEvent('bedHauler:server:NotifyUnload', tPlate, slotId)

        Entity(targetVeh).state:set('cargoSlot', nil, true)
        TriggerServerEvent('bedHauler:server:BroadcastCleanupProps', cargoNetId)

        DetachEntity(targetVeh, true, true)

        local dropOff = nil
        local tData   = Config.TransporterVehicles[GetEntityModel(parentVeh)]
        if tData then
            for _, slot in ipairs(tData.slots) do
                if slot.id == slotId and slot.dropOffset then
                    dropOff = slot.dropOffset
                    break
                end
            end
        end
        if not dropOff then
            local offsetX   = 0.0
            local cargoType2 = Config.CargoClasses[GetVehicleClass(targetVeh)]
            if cargoType2 == "moto" then offsetX = (slotId % 2 ~= 0) and -1.5 or 1.5 end
            dropOff = vector3(offsetX, -5.0, 0.0)
        end
        local dropPos = GetOffsetFromEntityInWorldCoords(parentVeh, dropOff.x, dropOff.y, dropOff.z)
        SetEntityCoords(targetVeh, dropPos.x, dropPos.y, dropPos.z, false, false, false, false)
        SetVehicleOnGroundProperly(targetVeh)

        LockVehicle(targetVeh, false)

        -- Liberar la obligación de mantener la entidad en todos los clientes
        SetNetworkIdCanMigrate(cargoNetId, true)
        SetEntityAsMissionEntity(targetVeh, false, false)

        -- Actualizar índices locales
        _activeCargo[cargoNetId] = nil
        local tNetId = NetworkGetNetworkIdFromEntity(parentVeh)
        if _cargoByTransport[tNetId] then _cargoByTransport[tNetId][cargoNetId] = nil end

        if #GetCargo(parentVeh) == 0 then SetTailgate(parentVeh, false) end

        PlaySoundFromEntity(-1, "DOOR_CLOSE", targetVeh, "CABLE_CAR_SOUNDS", false, 0)

        _loadingInProgress[targetVeh] = nil
        MiniNotify("Vehículo descargado")
    end,
    function() -- CANCELADO
        if ownsTransport then FreezeEntityPosition(parentVeh, false) end
        RenderScriptCams(false, true, 1000, true, false)
        DestroyCam(cam, false)
        StopAnimTask(ped, Config.Anim.dict, Config.Anim.clip, 1.0)
        ClearPedTasks(ped)
        _loadingInProgress[targetVeh] = nil
        MiniNotify("Cancelado")
    end)
end

-- =====================================================================
--  QB-TARGET — EL OJITO (ALT)
-- =====================================================================

CreateThread(function()
    Bridge.RemoveVehicleTarget()

    if Bridge.HasTarget then
        Bridge.RegisterVehicleTarget(
            function(entity) CargarVehiculo(entity) end,
            function(entity) DescargarVehiculo(entity) end,
            function(entity)
                if not DoesEntityExist(entity) then return false end
                local class = GetVehicleClass(entity)
                return Config.CargoClasses[class] ~= nil and not IsEntityAttachedToAnyVehicle(entity)
            end,
            function(entity)
                if not DoesEntityExist(entity) then return false end
                local class = GetVehicleClass(entity)
                return Config.CargoClasses[class] ~= nil and IsEntityAttachedToAnyVehicle(entity)
            end,
            Config.TargetDistance
        )
    else
        -- Fallback con tecla E cuando no hay target system instalado.
        -- Intervalo subido a 500ms (era 200ms) para reducir iteraciones del pool.
        CreateThread(function()
            local _shownFor = nil
            while true do
                Wait(500)
                local ped    = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local found, foundLoaded = 0, false

                for _, veh in ipairs(GetGamePool('CVehicle')) do
                    if DoesEntityExist(veh) and veh ~= GetVehiclePedIsIn(ped, false) then
                        local class = GetVehicleClass(veh)
                        if Config.CargoClasses[class] then
                            local dist = #(coords - GetEntityCoords(veh))
                            if dist < Config.TargetDistance then
                                found      = veh
                                foundLoaded = IsEntityAttachedToAnyVehicle(veh)
                                break
                            end
                        end
                    end
                end

                if found ~= 0 then
                    local hint = foundLoaded and '[E] Bajar de la Pick-Up' or '[E] Subir a la Pick-Up'
                    if _shownFor ~= found then
                        _shownFor = found
                        if Bridge.HasOxLib then lib.showTextUI(hint) end
                    end
                    if not Bridge.HasOxLib then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName(hint)
                        EndTextCommandDisplayHelp(0, false, true, -1)
                    end
                    if IsControlJustPressed(0, 38) then
                        if foundLoaded then DescargarVehiculo(found) else CargarVehiculo(found) end
                    end
                elseif _shownFor ~= nil then
                    _shownFor = nil
                    if Bridge.HasOxLib then lib.hideTextUI() end
                end
            end
        end)
    end
end)

-- =====================================================================
--  STATE BAG HANDLER — sincronización cross-cliente sin pool
-- =====================================================================
-- Cuando otro cliente carga o descarga, el state bag 'cargoSlot' cambia.
-- Esto mantiene _activeCargo actualizado sin escanear GetGamePool cada 10 s.
AddStateBagChangeHandler('cargoSlot', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or not DoesEntityExist(entity) then return end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then return end
    if value ~= nil then
        _activeCargo[netId] = true
        -- _cargoByTransport se actualizará lazy la próxima vez que GetCargo lo necesite
    else
        _activeCargo[netId] = nil
        for _, set in pairs(_cargoByTransport) do
            set[netId] = nil
        end
    end
end)

-- =====================================================================
--  HERRAMIENTA DE ADMIN: EDITOR DE POSICIÓN
-- =====================================================================
local editingVeh       = 0
local editParent       = 0
local editingSlotId    = 0
local editingCargoType = "moto"
local editOffset       = vector3(0.0, -1.0, 0.5)
local editRot          = vector3(0.0, 0.0, 0.0)
local editPhase        = 1
local editDropOffset   = vector3(0.0, -5.0, 0.0)
local savedLoadOffset  = nil
local savedLoadRot     = nil

local editorKeys = {
    forward   = false, backward  = false,
    left      = false, right     = false,
    up        = false, down      = false,
    rotL      = false, rotR      = false,
    pitchUp   = false, pitchDown = false,
    rollL     = false, rollR     = false,
    fast      = false,
}

local function resetEditorKeys()
    for k in pairs(editorKeys) do editorKeys[k] = false end
end

-- =====================================================================
--  MOTOS FANTASMA (previsualización de slots llenos)
-- =====================================================================
local GHOST_MODEL_MOTO = `sanchez`
local GHOST_MODEL_QUAD = `blazer`
local ghostVehicles = {}

local function SpawnGhostVehicles()
    if editingVeh == 0 or editParent == 0 then return end
    local transportData = Config.TransporterVehicles[GetEntityModel(editParent)]
    if not transportData then return end

    local modelsNeeded = {}
    for _, slot in ipairs(transportData.slots) do
        if slot.id ~= editingSlotId then
            modelsNeeded[slot.type == "quad" and GHOST_MODEL_QUAD or GHOST_MODEL_MOTO] = true
        end
    end
    for model in pairs(modelsNeeded) do EnsureModel(model) end

    for _, slot in ipairs(transportData.slots) do
        if slot.id ~= editingSlotId then
            local model = slot.type == "quad" and GHOST_MODEL_QUAD or GHOST_MODEL_MOTO
            if HasModelLoaded(model) then
                local sp = GetOffsetFromEntityInWorldCoords(
                    editParent, slot.offset.x, slot.offset.y, slot.offset.z)
                local ghost = CreateVehicle(model, sp.x, sp.y, sp.z, 0.0, false, false)
                if DoesEntityExist(ghost) then
                    SetEntityAlpha(ghost, 140, false)
                    SetEntityCollision(ghost, false, false)
                    FreezeEntityPosition(ghost, true)
                    AttachEntityToEntity(ghost, editParent, 0,
                        slot.offset.x, slot.offset.y, slot.offset.z,
                        slot.rotation.x, slot.rotation.y, slot.rotation.z,
                        false, false, true, false, 20, true)
                    ghostVehicles[#ghostVehicles + 1] = ghost
                end
            end
        end
    end

    for model in pairs(modelsNeeded) do SetModelAsNoLongerNeeded(model) end

    if #ghostVehicles > 0 then
        Bridge.Notify(
            "Previsualización ON — " .. #ghostVehicles .. " slot(s). Pulsa la misma tecla para desactivar.",
            "success", 5000)
    else
        Bridge.Notify("No hay más slots que mostrar en este vehículo.", "error")
    end
end

local function RemoveGhostVehicles()
    for _, ghost in ipairs(ghostVehicles) do
        if DoesEntityExist(ghost) then
            DetachEntity(ghost, false, false)
            DeleteVehicle(ghost)
        end
    end
    ghostVehicles = {}
end

local function regHeld(cmd, label, defaultKey, field)
    RegisterCommand('+tm_' .. cmd, function() editorKeys[field] = true  end, false)
    RegisterCommand('-tm_' .. cmd, function() editorKeys[field] = false end, false)
    RegisterKeyMapping('+tm_' .. cmd, 'Editor Motos: ' .. label, 'keyboard', defaultKey)
end

regHeld('fwd',      'Mover adelante (Y+)',           'UP',    'forward')
regHeld('back',     'Mover atrás (Y-)',              'DOWN',  'backward')
regHeld('left',     'Mover izquierda (X+)',          'LEFT',  'left')
regHeld('right',    'Mover derecha (X-)',            'RIGHT', 'right')
regHeld('up',       'Subir (Z+)',                    'PRIOR', 'up')
regHeld('down',     'Bajar (Z-)',                    'NEXT',  'down')
regHeld('rotl',    'Yaw izquierda (U)',              'U', 'rotL')
regHeld('rotr',    'Yaw derecha (O)',                'O', 'rotR')
regHeld('pitchup', 'Pitch adelante — morro sube (I)','I', 'pitchUp')
regHeld('pitchdn', 'Pitch atrás — morro baja (K)',   'K', 'pitchDown')
regHeld('rolll',   'Roll izquierda (J)',             'J', 'rollL')
regHeld('rollr',   'Roll derecha (L)',               'L', 'rollR')
regHeld('fast',    'Velocidad rápida x5 (SHIFT)',    'LSHIFT', 'fast')

RegisterCommand('tm_save', function()
    if editingVeh == 0 then return end

    if editPhase == 1 then
        savedLoadOffset = editOffset
        savedLoadRot    = editRot

        local dropOff = vector3(
            (editingCargoType == "moto") and ((editingSlotId % 2 ~= 0) and -1.5 or 1.5) or 0.0,
            -5.0, 0.0)
        local vData = Config.TransporterVehicles[GetEntityModel(editParent)]
        if vData then
            for _, s in ipairs(vData.slots) do
                if s.id == editingSlotId and s.type == editingCargoType and s.dropOffset then
                    dropOff = s.dropOffset
                    break
                end
            end
        end
        editDropOffset = dropOff
        editPhase = 2
        RemoveGhostVehicles()

        DetachEntity(editingVeh, false, false)
        Wait(0)
        SetEntityCollision(editingVeh, false, false)
        FreezeEntityPosition(editingVeh, true)
        AttachEntityToEntity(editingVeh, editParent, 0,
            editDropOffset.x, editDropOffset.y, editDropOffset.z,
            0.0, 0.0, 0.0,
            false, false, false, false, 20, true)

        Bridge.Notify(
            "FASE 2 — DESCARGA | Slot " .. editingSlotId ..
            " | Flechas/RePag/AvPag para mover | ENTER=Guardar todo | BACK=Cancelar",
            "primary", 18000)
        return
    end

    local modelHash = GetEntityModel(editParent)
    local slotSaved = editingSlotId
    local savedType = editingCargoType
    local parentRef = editParent
    local vehToDel  = editingVeh
    local finalDrop = editDropOffset

    TriggerServerEvent('bedHauler:server:SaveOffset', modelHash, slotSaved, savedLoadOffset, savedLoadRot, savedType, finalDrop)
    RemoveGhostVehicles()
    DetachEntity(vehToDel, false, false)
    if DoesEntityExist(vehToDel) then DeleteVehicle(vehToDel) end

    editPhase        = 1
    editingVeh       = 0
    editingSlotId    = 0
    editingCargoType = "moto"
    savedLoadOffset  = nil
    savedLoadRot     = nil
    resetEditorKeys()
    Bridge.Notify("Slot " .. slotSaved .. " (" .. savedType .. ") guardado.", "success", 5000)
end, false)
RegisterKeyMapping('tm_save', 'Editor Motos: Confirmar / Guardar', 'keyboard', 'RETURN')

RegisterCommand('tm_cancel', function()
    if editingVeh == 0 then return end
    RemoveGhostVehicles()
    local vehToDel = editingVeh
    editingVeh       = 0
    editingCargoType = "moto"
    editPhase        = 1
    savedLoadOffset  = nil
    savedLoadRot     = nil
    resetEditorKeys()
    DetachEntity(vehToDel, false, false)
    if DoesEntityExist(vehToDel) then DeleteVehicle(vehToDel) end
    Bridge.Notify("Editor cancelado", "error")
end, false)
RegisterKeyMapping('tm_cancel', 'Editor Motos: Cancelar editor', 'keyboard', 'BACK')

RegisterCommand('tm_ghost', function()
    if editingVeh == 0 then return end
    if editPhase == 2 then
        Bridge.Notify("Previsualización solo disponible en Fase 1 (carga)", "error")
        return
    end
    if #ghostVehicles > 0 then
        RemoveGhostVehicles()
        Bridge.Notify("Previsualización OFF", "error")
    else
        CreateThread(SpawnGhostVehicles)
    end
end, false)
RegisterKeyMapping('tm_ghost', 'Editor Motos: Motos fantasma (preview slots)', 'keyboard', 'G')

RegisterNetEvent('bedHauler:client:ToggleEditor', function(slotId, cargoType)
    local ped = PlayerPedId()

    if editingVeh ~= 0 then
        RemoveGhostVehicles()
        local vehToDel = editingVeh
        editingVeh       = 0
        editingSlotId    = 0
        editingCargoType = "moto"
        editPhase        = 1
        savedLoadOffset  = nil
        savedLoadRot     = nil
        resetEditorKeys()
        DetachEntity(vehToDel, false, false)
        if DoesEntityExist(vehToDel) then DeleteVehicle(vehToDel) end
        Bridge.Notify("Editor cancelado", "error")
        return
    end

    -- Buscar el transporte más cercano usando la caché (sin pool completo)
    local transportVeh = 0
    local bestDist = 15.0
    RefreshTransporterCache()
    for _, v in ipairs(_transporterCache) do
        if DoesEntityExist(v) then
            local dist = #(GetEntityCoords(ped) - GetEntityCoords(v))
            if dist < bestDist then
                transportVeh = v
                bestDist = dist
            end
        end
    end

    if transportVeh == 0 then
        Bridge.Notify("No hay Pick-Up/Camión cerca para editar", "error")
        return
    end

    local spawnModel = (cargoType == "quad") and `blazer4` or `sanchez`
    EnsureModel(spawnModel)
    local spawnPos = GetOffsetFromEntityInWorldCoords(transportVeh, 0.0, -8.0, 0.5)
    local veh = CreateVehicle(spawnModel, spawnPos.x, spawnPos.y, spawnPos.z, GetEntityHeading(transportVeh), false, false)
    SetModelAsNoLongerNeeded(spawnModel)

    if not DoesEntityExist(veh) then
        Bridge.Notify("Error al crear el vehículo de edición", "error")
        return
    end

    editPhase        = 1
    editingVeh       = veh
    editParent       = transportVeh
    editingSlotId    = slotId
    editingCargoType = cargoType or "moto"
    savedLoadOffset  = nil
    savedLoadRot     = nil

    local initialOffset = vector3(0.0, -1.0, 0.5)
    local initialRot    = vector3(0.0, 0.0, 0.0)
    local vData = Config.TransporterVehicles[GetEntityModel(transportVeh)]
    if vData and vData.slots then
        for _, s in ipairs(vData.slots) do
            if s.id == slotId and s.type == editingCargoType then
                initialOffset = s.offset
                initialRot    = s.rotation
                break
            end
        end
    end

    editOffset = initialOffset
    editRot    = initialRot

    SetEntityCollision(veh, false, false)
    FreezeEntityPosition(veh, true)
    AttachEntityToEntity(veh, transportVeh, 0,
        editOffset.x, editOffset.y, editOffset.z,
        editRot.x,    editRot.y,    editRot.z,
        false, false, false, false, 20, true)

    local slotIds = {}
    if vData and vData.slots then
        for _, s in ipairs(vData.slots) do
            if s.type == editingCargoType then slotIds[#slotIds + 1] = s.id end
        end
    end
    local slotInfo = #slotIds > 0
        and (editingCargoType .. " slots: " .. table.concat(slotIds, ", "))
        or  ("Sin slots de tipo " .. editingCargoType)

    Bridge.Notify(
        "FASE 1 — CARGA | " .. slotInfo .. " | Slot " .. slotId ..
        " | Flechas/RePag/AvPag=Pos | U/O I/K J/L=Rot | SHIFT=rapido | ENTER=Siguiente | BACK=Cancelar",
        "success", 18000)

    CreateThread(function()
        while editingVeh ~= 0 do
            if not DoesEntityExist(editingVeh) or not DoesEntityExist(editParent) then
                RemoveGhostVehicles()
                if DoesEntityExist(editingVeh) then DeleteVehicle(editingVeh) end
                editingVeh       = 0
                editingSlotId    = 0
                editingCargoType = "moto"
                editPhase        = 1
                savedLoadOffset  = nil
                savedLoadRot     = nil
                resetEditorKeys()
                Bridge.Notify("Editor cancelado: el vehículo desapareció", "error")
                break
            end

            local phaseLabel = editPhase == 1 and "FASE 1: CARGA" or "FASE 2: DESCARGA"
            DrawRect(0.155, 0.057, 0.310, 0.115, 0, 0, 0, 170)
            SetTextFont(4); SetTextScale(0.0, 0.33); SetTextColour(255, 220, 0, 255)
            SetTextEntry("STRING")
            AddTextComponentSubstringPlayerName(phaseLabel .. "  —  " .. string.upper(editingCargoType) .. "  Slot " .. editingSlotId)
            DrawText(0.015, 0.010)
            SetTextFont(0); SetTextScale(0.0, 0.27); SetTextColour(160, 220, 255, 255)
            SetTextEntry("STRING")
            if editPhase == 1 then
                AddTextComponentSubstringPlayerName(string.format("Offset  X:%.3f  Y:%.3f  Z:%.3f", editOffset.x, editOffset.y, editOffset.z))
                DrawText(0.015, 0.043)
                SetTextFont(0); SetTextScale(0.0, 0.27); SetTextColour(160, 255, 190, 255)
                SetTextEntry("STRING")
                AddTextComponentSubstringPlayerName(string.format("Rot  Pitch:%.1f  Roll:%.1f  Yaw:%.1f", editRot.x, editRot.y, editRot.z))
                DrawText(0.015, 0.066)
            else
                AddTextComponentSubstringPlayerName(string.format("Descarga  X:%.3f  Y:%.3f  Z:%.3f", editDropOffset.x, editDropOffset.y, editDropOffset.z))
                DrawText(0.015, 0.043)
            end
            Wait(0)

            local posChanged = false
            local rotChanged = false
            local speed    = editorKeys.fast and 0.05 or 0.01
            local rotSpeed = editorKeys.fast and 5.0  or 1.0

            if editPhase == 1 then
                if editorKeys.forward  then editOffset = editOffset + vector3(0, speed, 0); posChanged = true end
                if editorKeys.backward then editOffset = editOffset - vector3(0, speed, 0); posChanged = true end
                if editorKeys.left     then editOffset = editOffset + vector3(speed, 0, 0); posChanged = true end
                if editorKeys.right    then editOffset = editOffset - vector3(speed, 0, 0); posChanged = true end
                if editorKeys.up       then editOffset = editOffset + vector3(0, 0, speed); posChanged = true end
                if editorKeys.down     then editOffset = editOffset - vector3(0, 0, speed); posChanged = true end
                if editorKeys.rotL      then editRot = editRot + vector3(0, 0, rotSpeed); rotChanged = true end
                if editorKeys.rotR      then editRot = editRot - vector3(0, 0, rotSpeed); rotChanged = true end
                if editorKeys.pitchUp   then editRot = editRot + vector3(rotSpeed, 0, 0); rotChanged = true end
                if editorKeys.pitchDown then editRot = editRot - vector3(rotSpeed, 0, 0); rotChanged = true end
                if editorKeys.rollL     then editRot = editRot + vector3(0, rotSpeed, 0); rotChanged = true end
                if editorKeys.rollR     then editRot = editRot - vector3(0, rotSpeed, 0); rotChanged = true end
            else
                if editorKeys.forward  then editDropOffset = editDropOffset + vector3(0, speed, 0); posChanged = true end
                if editorKeys.backward then editDropOffset = editDropOffset - vector3(0, speed, 0); posChanged = true end
                if editorKeys.left     then editDropOffset = editDropOffset + vector3(speed, 0, 0); posChanged = true end
                if editorKeys.right    then editDropOffset = editDropOffset - vector3(speed, 0, 0); posChanged = true end
                if editorKeys.up       then editDropOffset = editDropOffset + vector3(0, 0, speed); posChanged = true end
                if editorKeys.down     then editDropOffset = editDropOffset - vector3(0, 0, speed); posChanged = true end
            end

            if posChanged or rotChanged then
                DetachEntity(editingVeh, false, false)
                Wait(0)
                SetEntityCollision(editingVeh, false, false)
                FreezeEntityPosition(editingVeh, true)
                if editPhase == 1 then
                    AttachEntityToEntity(editingVeh, editParent, 0,
                        editOffset.x, editOffset.y, editOffset.z,
                        editRot.x,    editRot.y,    editRot.z,
                        false, false, false, false, 20, true)
                else
                    AttachEntityToEntity(editingVeh, editParent, 0,
                        editDropOffset.x, editDropOffset.y, editDropOffset.z,
                        0.0, 0.0, 0.0,
                        false, false, false, false, 20, true)
                end
            end
        end
    end)
end)

-- =====================================================================
--  HILO: DESENGANCHE POR CHOQUE
--  Solo itera _activeCargo (O(cargo_activo)), nunca el pool completo.
--  El state bag handler mantiene _activeCargo al día sin rescan.
-- =====================================================================
CreateThread(function()
    while true do
        Wait(500)

        for cNetId in pairs(_activeCargo) do
            local cVeh = NetworkGetEntityFromNetworkId(cNetId)
            if not DoesEntityExist(cVeh) or not Entity(cVeh).state.cargoSlot then
                _activeCargo[cNetId] = nil
            else
                local parent = GetEntityAttachedTo(cVeh)
                if DoesEntityExist(parent) and math.abs(GetEntityRoll(parent)) > 75.0 then
                    if NetworkHasControlOfEntity(parent) or NetworkHasControlOfEntity(cVeh) then
                        local tPlate = GetVehicleNumberPlateText(parent):gsub("%s+", "")
                        local slotId = Entity(cVeh).state.cargoSlot
                        local ptNetId = NetworkGetNetworkIdFromEntity(parent)

                        DetachEntity(cVeh, true, true)
                        SetEntityAsMissionEntity(cVeh, false, false)
                        LockVehicle(cVeh, false)
                        Entity(cVeh).state:set('cargoSlot', nil, true)

                        TriggerServerEvent('bedHauler:server:NotifyUnload', tPlate, slotId)
                        TriggerServerEvent('bedHauler:server:BroadcastCleanupProps', cNetId)

                        _activeCargo[cNetId] = nil
                        if ptNetId ~= 0 and _cargoByTransport[ptNetId] then
                            _cargoByTransport[ptNetId][cNetId] = nil
                        end

                        SetVehicleEngineHealth(cVeh, 250.0)
                        SmashVehicleWindow(cVeh, 0)
                        SmashVehicleWindow(cVeh, 1)
                    end
                end
            end
        end
    end
end)

-- =====================================================================
--  LIMPIEZA AL REINICIAR SCRIPT
-- =====================================================================


RegisterNetEvent('bedHauler:client:CleanupProps', function(cargoNetId)
    local cargoVeh = NetworkGetEntityFromNetworkId(cargoNetId)
    if DoesEntityExist(cargoVeh) then
        DeleteStrapProps(cargoVeh)
    end
end)

RegisterNetEvent('bedHauler:client:ForceUnload', function(plate)
    for _, cVeh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(cVeh) and Entity(cVeh).state.cargoSlot then
            local parent = GetEntityAttachedTo(cVeh)
            if DoesEntityExist(parent) then
                local tPlate = GetVehicleNumberPlateText(parent):gsub("%s+", "")
                if not plate or tPlate == plate then
                    if TakeControl(cVeh) then
                        local slotId  = Entity(cVeh).state.cargoSlot
                        local cNetId  = NetworkGetNetworkIdFromEntity(cVeh)
                        local ptNetId = NetworkGetNetworkIdFromEntity(parent)
                        Entity(cVeh).state:set('cargoSlot', nil, true)
                        DetachEntity(cVeh, true, true)
                        SetEntityAsMissionEntity(cVeh, false, false)
                        LockVehicle(cVeh, false)
                        TriggerServerEvent('bedHauler:server:NotifyUnload', tPlate, slotId)
                        TriggerServerEvent('bedHauler:server:BroadcastCleanupProps', cNetId)
                        _activeCargo[cNetId] = nil
                        if ptNetId ~= 0 and _cargoByTransport[ptNetId] then
                            _cargoByTransport[ptNetId][cNetId] = nil
                        end
                        local dropPos = GetOffsetFromEntityInWorldCoords(parent, 0.0, -5.0, 0.0)
                        SetEntityCoords(cVeh, dropPos.x, dropPos.y, dropPos.z, false, false, false, false)
                        SetVehicleOnGroundProperly(cVeh)
                        if #GetCargo(parent) == 0 then SetTailgate(parent, false) end
                        MiniNotify("Vehículo forzado a descargar")
                    end
                end
            end
        end
    end
end)

-- =====================================================================
--  SINCRONIZACIÓN DE OFFSETS EN TIEMPO REAL
-- =====================================================================
RegisterNetEvent('bedHauler:client:SyncOffset', function(modelHash, slotId, ox, oy, oz, rx, ry, rz, cargoType, dx, dy, dz)
    if not Config.TransporterVehicles[modelHash] then
        Config.TransporterVehicles[modelHash] = { slots = {} }
    end
    local applied = false
    for _, s in ipairs(Config.TransporterVehicles[modelHash].slots) do
        if s.id == slotId then
            s.offset     = vector3(ox, oy, oz)
            s.rotation   = vector3(rx, ry, rz)
            s.type       = cargoType
            if dx then s.dropOffset = vector3(dx, dy, dz) end
            applied = true
            break
        end
    end
    if not applied then
        table.insert(Config.TransporterVehicles[modelHash].slots, {
            id         = slotId,
            type       = cargoType,
            offset     = vector3(ox, oy, oz),
            rotation   = vector3(rx, ry, rz),
            dropOffset = dx and vector3(dx, dy, dz) or nil,
        })
    end
    -- Invalidar caché de transportadores para que el nuevo modelo sea detectado
    _transporterCacheTick = 0
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(500)

    CreateThread(function()
        EnsureModel(STRAP_MODEL)
        SetModelAsNoLongerNeeded(STRAP_MODEL)
        EnsureModel(GHOST_MODEL_MOTO)
        SetModelAsNoLongerNeeded(GHOST_MODEL_MOTO)
        EnsureModel(GHOST_MODEL_QUAD)
        SetModelAsNoLongerNeeded(GHOST_MODEL_QUAD)
    end)

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and Entity(veh).state.cargoSlot then
            if NetworkHasControlOfEntity(veh) then
                DetachEntity(veh, true, true)
                SetEntityAsMissionEntity(veh, false, false)
                local netId = NetworkGetNetworkIdFromEntity(veh)
                SetNetworkIdCanMigrate(netId, true)
                LockVehicle(veh, false)
                Entity(veh).state:set('cargoSlot', nil, false)
            end
        end
    end

end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    RemoveGhostVehicles()
    if editingVeh ~= 0 then
        DetachEntity(editingVeh, true, true)
        editingVeh = 0
    end

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and Entity(veh).state.cargoSlot then
            if NetworkHasControlOfEntity(veh) then
                DetachEntity(veh, true, true)
                SetEntityAsMissionEntity(veh, false, false)
                local netId = NetworkGetNetworkIdFromEntity(veh)
                SetNetworkIdCanMigrate(netId, true)
                LockVehicle(veh, false)
                Entity(veh).state:set('cargoSlot', nil, false)
            end
        end
    end

    for cargoVeh, props in pairs(ActiveProps) do
        for _, prop in ipairs(props) do
            if DoesEntityExist(prop) then
                DetachEntity(prop, true, true)
                DeleteEntity(prop)
            end
        end
    end
    ActiveProps = {}

    RenderScriptCams(false, false, 0, true, false)
    Bridge.RemoveVehicleTarget()
end)
