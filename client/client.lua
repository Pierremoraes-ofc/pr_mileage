-- ============================================================
--   pr_mileage — CLIENT
-- ============================================================

-- O estado por veículo (quilometragem, origem e checkpoints) vive nos state bags.
-- Apenas o controle de execução da thread permanece local.
local threadRunning = false

local KM_TO_MILES = 0.621371

-- ============================================================
--   UTILITÁRIOS INTERNOS
-- ============================================================

local function convertUnit(km)
    if Config.Unit == "miles" then return km * KM_TO_MILES end
    return km
end

local function trimPlate(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate then return false end
    return string.gsub(plate, "^%s*(.-)%s*$", "%1")
end

local function randomInRange(min, max)
    return min + math.random() * (max - min)
end

local function rollInitialMileage(vehicle)
    local class = GetVehicleClass(vehicle)
    local range = Config.ClassKmRange[class]
    if not range or (range[1] == 0 and range[2] == 0) then return 0.0 end
    return randomInRange(range[1], range[2])
end

local function vehicleIsFresh(vehicle)
    return PRMileageFreshGet(vehicle)
end

local function consumeFreshFlag(vehicle)
    PRMileageFreshSet(vehicle, false, false, { force = true })
end

local function syncStatebag(value, vehicle)
    vehicle = vehicle or cache.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    return PRMileageSet(vehicle, value, false, { minIntervalMs = 75 })
end

-- A placa visível e o netId são validados no servidor antes de qualquer persistência.
local function pushToServer(plate, value, fresh, vehicle)
    vehicle = vehicle or cache.vehicle
    local validVehicle = vehicle and DoesEntityExist(vehicle)
    local netId = validVehicle and NetworkGetNetworkIdFromEntity(vehicle) or 0
    local vehicleClass = validVehicle and GetVehicleClass(vehicle) or nil
    TriggerServerEvent("pr_mileage:sv:saveMileage", plate, value, fresh or false, netId, vehicleClass)
end

-- ============================================================
--   LOOP DE DISTÂNCIA (1x por segundo, apenas motorista)
-- ============================================================

local function coordsToState(coords)
    return { x = coords.x, y = coords.y, z = coords.z }
end

local function coordsFromState(coords)
    if type(coords) ~= "table" then return nil end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return nil end
    return vector3(x, y, z)
end

local function tick()
    local vehicle = cache.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return false end

    local class = GetVehicleClass(vehicle)
    if Config.IgnoredClasses[class] then return false end
    if cache.seat ~= -1 then return false end

    local plate = trimPlate(vehicle)
    if not plate then return false end

    local tracking = PRMileageTrackingGet(vehicle)
    local currentCoords = GetEntityCoords(vehicle)
    local lastLocation = coordsFromState(tracking.lastLocation) or currentCoords

    if tracking.fetched ~= true then
        local serverMileage = -1
        local currentMileage
        local owned = false

        if vehicleIsFresh(vehicle) then
            owned = true
            currentMileage = 0.0
            consumeFreshFlag(vehicle)
            pushToServer(plate, 0.0, true, vehicle)
        else
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            local km, storage = pr_lib.callback.await("pr_mileage:cb:getMileage", 10000, plate, netId)
            if km == nil or km == false then return false end

            serverMileage = km
            local stateMileage = PRMileageGet(vehicle)

            if storage == "db" then
                owned = true
                currentMileage = (stateMileage ~= nil and stateMileage > km) and stateMileage or km
            elseif storage == "state" then
                currentMileage = (stateMileage ~= nil and stateMileage > km) and stateMileage or km
            else
                currentMileage = stateMileage ~= nil and stateMileage or rollInitialMileage(vehicle)
                pushToServer(plate, currentMileage, false, vehicle)
            end
        end

        syncStatebag(currentMileage, vehicle)
        PRMileageTrackingSet(vehicle, {
            fetched = true,
            owned = owned,
            lastSavedLocal = currentMileage,
            lastSavedServer = serverMileage ~= -1 and serverMileage or currentMileage,
            lastLocation = coordsToState(currentCoords),
        }, false, { force = true })
        return true
    end

    local distance = 0.0
    if IsVehicleOnAllWheels(vehicle) and not IsEntityInWater(vehicle) then
        distance = #(lastLocation - currentCoords)
    end

    local currentMileage = (PRMileageGet(vehicle, 0.0) or 0.0) + (distance / 1000.0)
    local rounded = tonumber(string.format("%.1f", currentMileage))
    syncStatebag(currentMileage, vehicle)

    tracking.lastLocation = coordsToState(currentCoords)
    if rounded ~= tracking.lastSavedLocal then
        tracking.lastSavedLocal = rounded
    end

    if not tracking.lastSavedServer
        or math.abs(rounded - tracking.lastSavedServer) >= Config.SaveThreshold then
        pushToServer(plate, rounded, false, vehicle)
        tracking.lastSavedServer = rounded
    end

    PRMileageTrackingSet(vehicle, tracking, false, { minIntervalMs = 75 })
    return true
end

local function startThread()
    if threadRunning then return end
    threadRunning = true

    CreateThread(function()
        while cache.vehicle do
            Wait(1000)
            if not tick() then break end
        end

        threadRunning = false
    end)
end

pr_lib.onCache("vehicle", function(vehicle, previousVehicle)
    if not vehicle and previousVehicle and DoesEntityExist(previousVehicle) then
        local plate = trimPlate(previousVehicle)
        local mileage = PRMileageGet(previousVehicle)
        if plate and mileage then pushToServer(plate, mileage, false, previousVehicle) end
        return
    end

    startThread()
end)

RegisterNetEvent("pr_mileage:cl:authoritativeMileage", function(netId, value, owned)
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    value = tonumber(value)
    if not value then return end
    syncStatebag(value, vehicle)

    if cache.vehicle == vehicle then
        local tracking = PRMileageTrackingGet(vehicle)
        tracking.fetched = true
        tracking.owned = owned == true
        tracking.lastSavedLocal = value
        tracking.lastSavedServer = value
        tracking.lastLocation = coordsToState(GetEntityCoords(vehicle))
        PRMileageTrackingSet(vehicle, tracking, false, { force = true })
    end
end)

CreateThread(function()
    if cache.vehicle then startThread() end
end)

-- ============================================================
--   HOOKS DE GARAGEM — marca veículo como fresh (km = 0)
-- ============================================================

local function applyFreshFlag(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    PRMileageFreshSet(vehicle, true, false, { force = true })
end

local function applyFreshByNetId(netId)
    if not netId then return end
    CreateThread(function()
        local elapsed, vehicle = 0, 0
        while vehicle == 0 and elapsed < 5000 do
            Wait(100); elapsed = elapsed + 100
            vehicle = NetToVeh(netId)
        end
        applyFreshFlag(vehicle)
    end)
end

AddEventHandler("esx_garages:vehicleOut",          function(v) applyFreshFlag(v) end)
AddEventHandler("esx:vehicleBought",               function(v) applyFreshFlag(v) end)
AddEventHandler("QBCore:Client:VehicleSpawned",    function(v) applyFreshFlag(v) end)
AddEventHandler("qb-garages:client:takeOutGarage", function(v) applyFreshFlag(v) end)
AddEventHandler("ox_garage:vehicleOut", function(data)
    local netId = type(data) == "table" and (data.netId or data.vehicle) or data
    applyFreshByNetId(netId)
end)

AddEventHandler("pr_mileage:fresh", function(v) applyFreshFlag(v) end)

-- ============================================================
--   EXPORTS CLIENT
-- ============================================================

-- Mileage do veículo que o player está dirigindo agora
---@return number|false
exports("getMileage", function()
    if not cache.vehicle then return false end
    return convertUnit(PRMileageGet(cache.vehicle, 0.0))
end)

-- Mileage de qualquer entidade veículo pelo handle
---@param ent integer
---@return number|false
exports("getMileageByEntity", function(ent)
    if not ent or ent == 0 then return false end
    if not DoesEntityExist(ent) or not IsEntityAVehicle(ent) then return false end
    return convertUnit(PRMileageGet(ent, 0))
end)

-- Mileage por placa — prioriza statebag (tempo real) se o veículo estiver na cena
-- Só faz callback ao servidor (banco/RAM) se o veículo não estiver ativo localmente
---@param plate string
---@return number|false
exports("getMileageByPlate", function(plate)
    if not plate or plate == "" then return false end

    -- Verifica se o veículo com essa placa está ativo na cena agora
    local allVehicles = GetGamePool("CVehicle")
    for _, veh in ipairs(allVehicles) do
        if DoesEntityExist(veh) then
            local vehPlate = string.gsub(GetVehicleNumberPlateText(veh) or "", "^%s*(.-)%s*$", "%1")
            if vehPlate == plate:gsub("%s+", ""):upper() then
                -- Veículo está na cena → usa statebag (valor em tempo real)
                local statebag = PRMileageGet(veh)
                if statebag then return convertUnit(statebag) end
            end
        end
    end

    -- Veículo não está na cena → busca no servidor (banco ou state bag ativo)
    local km, _ = pr_lib.callback.await("pr_mileage:cb:getMileage", 10000, plate)
    if not km or km == -1 then return false end
    return convertUnit(km)
end)

-- Unidade configurada
---@return string
exports("getUnit", function() return Config.Unit end)
exports("GetUnit", function() return Config.Unit end)

-- Alias de compatibilidade — retorna (mileage, unit)
-- Prioriza statebag (tempo real) se o veículo estiver na cena
---@param plate string
---@return number|false, string
exports("GetMileage", function(plate)
    if not plate or plate == "" then return false end

    -- Verifica se o veículo com essa placa está ativo na cena agora
    local allVehicles = GetGamePool("CVehicle")
    for _, veh in ipairs(allVehicles) do
        if DoesEntityExist(veh) then
            local vehPlate = string.gsub(GetVehicleNumberPlateText(veh) or "", "^%s*(.-)%s*$", "%1")
            if vehPlate == plate:gsub("%s+", ""):upper() then
                local statebag = PRMileageGet(veh)
                if statebag then return convertUnit(statebag), Config.Unit end
            end
        end
    end

    -- Veículo não está na cena → busca no servidor (banco ou state bag ativo)
    local km, _ = pr_lib.callback.await("pr_mileage:cb:getMileage", 10000, plate)
    if not km or km == -1 then return false end
    return convertUnit(km), Config.Unit
end)

-- Placa do veículo atual
---@return string|false
exports("getVehiclePlate", function()
    if not cache.vehicle then return false end
    return trimPlate(cache.vehicle)
end)

-- Handle do veículo atual
---@return integer|false
exports("getCurrentVehicle", function()
    return cache.vehicle or false
end)

-- Classe numérica do veículo atual
---@return integer|false
exports("getVehicleClass", function()
    if not cache.vehicle then return false end
    return GetVehicleClass(cache.vehicle)
end)

-- Nome da classe do veículo atual
---@return string|false
exports("getVehicleClassName", function()
    if not cache.vehicle then return false end
    return Config.ClassNames[GetVehicleClass(cache.vehicle)] or "Desconhecido"
end)

-- Nome da classe de qualquer entidade veículo
---@param ent integer
---@return string|false
exports("getVehicleClassNameByEntity", function(ent)
    if not ent or ent == 0 then return false end
    if not DoesEntityExist(ent) or not IsEntityAVehicle(ent) then return false end
    return Config.ClassNames[GetVehicleClass(ent)] or "Desconhecido"
end)

-- Se o player está atualmente no banco do motorista
---@return boolean
exports("isDriving", function()
    return cache.vehicle ~= nil and cache.seat == -1
end)

-- Se o veículo atual pertence a um player (vs carro da rua)
---@return boolean
exports("isOwnedVehicle", function()
    if not cache.vehicle then return false end
    return PRMileageTrackingGet(cache.vehicle).owned == true
end)

-- Marca manualmente um veículo como fresh (km = 0 ao entrar)
---@param vehicle integer
exports("markFresh", function(vehicle) applyFreshFlag(vehicle) end)

-- Zera km do veículo atual diretamente
exports("resetCurrentMileage", function()
    if not cache.vehicle then return end
    syncStatebag(0.0)
    local tracking = PRMileageTrackingGet(cache.vehicle)
    tracking.fetched = true
    tracking.owned = true
    tracking.lastSavedLocal = 0.0
    tracking.lastSavedServer = 0.0
    tracking.lastLocation = coordsToState(GetEntityCoords(cache.vehicle))
    PRMileageTrackingSet(cache.vehicle, tracking, false, { force = true })
    local plate = trimPlate(cache.vehicle)
    if plate then pushToServer(plate, 0.0, true) end
end)

-- ============================================================
--   COMANDOS DE TESTE
-- ============================================================

pr_lib.addCommand("km", {
    help = "Mostra a quilometragem do veículo atual",
}, function()
    if not cache.vehicle then
        TriggerEvent("chat:addMessage", { color = {255,80,80}, args = {"[pr_mileage]", "Você não está em um veículo!"} })
        return
    end
    local plate = trimPlate(cache.vehicle)
    local km = PRMileageGet(cache.vehicle, 0.0)
    local className = Config.ClassNames[GetVehicleClass(cache.vehicle)] or "Desconhecido"
    local unit = Config.Unit == "miles" and "mi" or "km"
    local tipo = PRMileageTrackingGet(cache.vehicle).owned == true and "Player" or "Rua"
    TriggerEvent("chat:addMessage", {
        color = {0, 200, 100},
        args = {"[pr_mileage]", ("🚗 %s | %s | %s | %.1f %s"):format(plate, className, tipo, convertUnit(km), unit)}
    })
end)

pr_lib.addCommand("kmplaca", {
    help = "Consulta a quilometragem por placa",
    params = {
        { name = "plate", type = "string", optional = true, help = "Placa original ou fria" },
    },
}, function(params)
    local plate = params.plate
    if not plate then
        TriggerEvent("chat:addMessage", { color = {255,80,80}, args = {"[pr_mileage]", "Uso: /kmplaca [PLACA]"} })
        return
    end

    plate = plate:upper()
    local km, _, originalPlate = pr_lib.callback.await("pr_mileage:cb:getMileage", 10000, plate)
    local unit = Config.Unit == "miles" and "mi" or "km"
    if not km or km == -1 then
        TriggerEvent("chat:addMessage", { color = {255,80,80}, args = {"[pr_mileage]", ("Placa %s não encontrada."):format(plate)} })
    else
        TriggerEvent("chat:addMessage", {
            color = {0,200,255},
            args = {"[pr_mileage]", ("🔍 %s | placa original %s | %.1f %s"):format(
                plate, originalPlate or plate, convertUnit(km), unit
            )}
        })
    end
end)
