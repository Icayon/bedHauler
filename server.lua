-- Tabla en memoria: { tPlate → { slotId → cPlate } }
local activeCargoMap = {}

local function LogOperation(op, playerId, tPlate, cPlate, slotId)
    local line = string.format("[%s] %s | player:%d | transport:%s | cargo:%s | slot:%s",
        os.date("%Y-%m-%d %H:%M:%S"), op, playerId or 0,
        tPlate or "?", cPlate or "?", tostring(slotId or "?"))
    print('[bedHauler] ' .. line)
    local f = io.open(GetResourcePath(GetCurrentResourceName()) .. '/bedHauler_log.txt', 'a')
    if f then f:write(line .. '\n'); f:close() end
end

local function SaveCargo(tPlate, cPlate, slotId)
    if not activeCargoMap[tPlate] then activeCargoMap[tPlate] = {} end
    activeCargoMap[tPlate][slotId] = cPlate
end

local function DeleteCargo(tPlate, slotId)
    if activeCargoMap[tPlate] then
        activeCargoMap[tPlate][slotId] = nil
        local empty = true
        for _ in pairs(activeCargoMap[tPlate]) do empty = false; break end
        if empty then activeCargoMap[tPlate] = nil end
    end
end

RegisterNetEvent('bedHauler:server:NotifyLoad', function(tPlate, cPlate, slotId, transportNetId, cargoNetId)
    local src = source
    if not Bridge.GetPlayer(src) then return end

    if transportNetId and cargoNetId then
        local tEnt = NetworkGetEntityFromNetworkId(transportNetId)
        local cEnt = NetworkGetEntityFromNetworkId(cargoNetId)
        if DoesEntityExist(tEnt) and DoesEntityExist(cEnt) then
            local dist = #(GetEntityCoords(tEnt) - GetEntityCoords(cEnt))
            if dist > (Config.SearchRadius + 10.0) then
                Bridge.Notify(src, "Error: distancia inválida en carga", "error")
                print(string.format('[bedHauler] Distancia inválida: player %d, dist=%.1f', src, dist))
                return
            end
        end
    end

    SaveCargo(tPlate, cPlate, slotId)
    LogOperation('LOAD', src, tPlate, cPlate, slotId)
end)

RegisterNetEvent('bedHauler:server:NotifyUnload', function(tPlate, slotId)
    local src = source
    if not Bridge.GetPlayer(src) then return end
    local cPlate = activeCargoMap[tPlate] and activeCargoMap[tPlate][slotId] or '?'
    LogOperation('UNLOAD', src, tPlate, cPlate, slotId)
    DeleteCargo(tPlate, slotId)
end)

-- =====================================================================
--  COMANDO ADMIN: /ajustar_slot <slot>
-- =====================================================================
Bridge.AddCommand("ajustar_slot", "Ajustar posición de carga y descarga de un slot (Admin)", {{name="slot", help="ID del slot (1-9)"}}, function(source, args)
    local slotId = tonumber(args[1])
    if not slotId then
        Bridge.Notify(source, "Uso: /ajustar_slot <número>  Ej: /ajustar_slot 1", "error")
        return
    end
    local cargoType = (slotId % 3 == 0) and "quad" or "moto"
    TriggerClientEvent('bedHauler:client:ToggleEditor', source, slotId, cargoType)
end, "admin")

-- =====================================================================
--  COMANDO ADMIN: /forzar_descarga [matricula]
-- =====================================================================
Bridge.AddCommand("forzar_descarga", "Fuerza la descarga de una moto por matrícula (Admin)",
    {{name="matricula", help="Matrícula del transporte (opcional — vacío = todos)"}},
    function(src, args)
        local plate = args[1] and args[1]:upper() or nil
        TriggerClientEvent('bedHauler:client:ForceUnload', src, plate)
        LogOperation('FORCE_UNLOAD', src, plate or 'ALL', '*', '*')
    end, "admin")

-- =====================================================================
--  GUARDAR OFFSET
-- =====================================================================

local function buildOffsetFile(data)
    local out = {
        "-- Generado automáticamente por /ajustar_slot — NO editar a mano.",
        "-- Se sobreescribe con cada guardado desde el editor en juego.",
        "",
        "_TM_Offsets = {",
    }
    for modelHash, slots in pairs(data) do
        out[#out + 1] = string.format("    [%d] = {", modelHash)
        for slotId, d in pairs(slots) do
            if d.dx then
                out[#out + 1] = string.format(
                    "        [%d] = { ox=%.4f, oy=%.4f, oz=%.4f, rx=%.4f, ry=%.4f, rz=%.4f, t=%q, dx=%.4f, dy=%.4f, dz=%.4f },",
                    slotId, d.ox, d.oy, d.oz, d.rx, d.ry, d.rz, d.t, d.dx, d.dy, d.dz
                )
            else
                out[#out + 1] = string.format(
                    "        [%d] = { ox=%.4f, oy=%.4f, oz=%.4f, rx=%.4f, ry=%.4f, rz=%.4f, t=%q },",
                    slotId, d.ox, d.oy, d.oz, d.rx, d.ry, d.rz, d.t
                )
            end
        end
        out[#out + 1] = "    },"
    end
    out[#out + 1] = "}"
    out[#out + 1] = ""
    out[#out + 1] = "-- Fusionar offsets guardados en Config.TransporterVehicles"
    out[#out + 1] = "for modelHash, slots in pairs(_TM_Offsets) do"
    out[#out + 1] = "    if not Config.TransporterVehicles[modelHash] then"
    out[#out + 1] = "        Config.TransporterVehicles[modelHash] = { slots = {} }"
    out[#out + 1] = "    end"
    out[#out + 1] = "    for slotId, d in pairs(slots) do"
    out[#out + 1] = "        local applied = false"
    out[#out + 1] = "        for _, s in ipairs(Config.TransporterVehicles[modelHash].slots) do"
    out[#out + 1] = "            if s.id == slotId then"
    out[#out + 1] = "                s.offset     = vector3(d.ox, d.oy, d.oz)"
    out[#out + 1] = "                s.rotation   = vector3(d.rx, d.ry, d.rz)"
    out[#out + 1] = "                s.type       = d.t"
    out[#out + 1] = "                if d.dx then s.dropOffset = vector3(d.dx, d.dy, d.dz) end"
    out[#out + 1] = "                applied = true"
    out[#out + 1] = "                break"
    out[#out + 1] = "            end"
    out[#out + 1] = "        end"
    out[#out + 1] = "        if not applied then"
    out[#out + 1] = "            table.insert(Config.TransporterVehicles[modelHash].slots, {"
    out[#out + 1] = "                id         = slotId,"
    out[#out + 1] = "                type       = d.t,"
    out[#out + 1] = "                offset     = vector3(d.ox, d.oy, d.oz),"
    out[#out + 1] = "                rotation   = vector3(d.rx, d.ry, d.rz),"
    out[#out + 1] = "                dropOffset = d.dx and vector3(d.dx, d.dy, d.dz) or nil,"
    out[#out + 1] = "            })"
    out[#out + 1] = "        end"
    out[#out + 1] = "    end"
    out[#out + 1] = "end"
    return table.concat(out, "\n")
end

RegisterNetEvent('bedHauler:server:SaveOffset', function(modelHash, slotId, offset, rot, cargoType, dropOffset)
    local src = source
    if not Bridge.GetPlayer(src) then return end

    if not modelHash or not slotId or not offset or not rot then
        Bridge.Notify(src, "Error: parámetros inválidos en SaveOffset", "error")
        return
    end

    local cType = cargoType or "moto"

    local existingData = {}
    local fileContent  = LoadResourceFile(GetCurrentResourceName(), "custom_offsets.lua") or ""
    if fileContent ~= "" then
        local tableOnly = fileContent:match("^(.-)%s*%-%-%s*Fusionar")
        if not tableOnly then tableOnly = fileContent end
        local env = setmetatable({ _TM_Offsets = {} }, { __index = _G })
        local fn = load(tableOnly, "@custom_offsets_read", "t", env)
        if fn then
            local ok, err = pcall(fn)
            if ok and type(env._TM_Offsets) == "table" then
                existingData = env._TM_Offsets
            else
                print("[bedHauler] Aviso al leer offsets: " .. tostring(err))
            end
        end
    end

    if not existingData[modelHash] then existingData[modelHash] = {} end
    existingData[modelHash][slotId] = {
        ox = offset.x,   oy = offset.y,   oz = offset.z,
        rx = rot.x,      ry = rot.y,      rz = rot.z,
        t  = cType,
        dx = dropOffset and dropOffset.x or nil,
        dy = dropOffset and dropOffset.y or nil,
        dz = dropOffset and dropOffset.z or nil,
    }

    SaveResourceFile(GetCurrentResourceName(), "custom_offsets.lua", buildOffsetFile(existingData), -1)
    print(string.format("[bedHauler] Slot %d (%s) guardado para modelo %d por player %d", slotId, cType, modelHash, src))

    -- Solo al admin que guardó: evita broadcast a los 400 clientes por cada ajuste
    TriggerClientEvent('bedHauler:client:SyncOffset', src,
        modelHash, slotId,
        offset.x, offset.y, offset.z,
        rot.x, rot.y, rot.z,
        cType,
        dropOffset and dropOffset.x or nil,
        dropOffset and dropOffset.y or nil,
        dropOffset and dropOffset.z or nil)
    Bridge.Notify(src, "Slot " .. slotId .. " (" .. cType .. ") guardado.", "success")
end)

-- =====================================================================
--  BROADCAST: eliminar props de amarre en todos los clientes
-- =====================================================================
RegisterNetEvent('bedHauler:server:BroadcastCleanupProps', function(cargoNetId)
    if not Bridge.GetPlayer(source) then return end
    TriggerClientEvent('bedHauler:client:CleanupProps', -1, cargoNetId)
end)

