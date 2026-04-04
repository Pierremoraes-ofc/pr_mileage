-- ============================================================
--   pr_mileage — CLIENT
-- ============================================================

local lastLocation    = nil
local currentMileage  = 0.0
local lastSavedLocal  = nil
local lastSavedServer = nil
local mileageFetched  = false
local threadRunning   = false
local vehicleIsOwned  = false  -- true = pertence a um player (banco), false = carro da rua (RAM)

local DECOR_FRESH = "pr_mileage_fresh"
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

local function registerDecor()
    if not DecorExistOn(0, DECOR_FRESH) then
        DecorRegister(DECOR_FRESH, 2)
    end
end

local function vehicleIsFresh(vehicle)
    return DecorExistOn(vehicle, DECOR_FRESH) and DecorGetBool(vehicle, DECOR_FRESH)
end

local function consumeFreshFlag(vehicle)
    if DecorExistOn(vehicle, DECOR_FRESH) then
        DecorSetBool(vehicle, DECOR_FRESH, false)
    end
end

local function syncStatebag(value)
    Entity(cache.vehicle).state:set("vehicleMileage", value, true)
end

-- isOwned: true = carro de player (banco) | false = carro da rua (RAM)
local function pushToServer(plate, value, fresh)
    TriggerServerEvent("pr_mileage:sv:saveMileage", plate, value, fresh or false, vehicleIsOwned)
end

-- ============================================================
--   LOOP DE DISTÂNCIA (1x por segundo, apenas motorista)
-- ============================================================

local function tick()
    if not cache.vehicle then return false end

    local class = GetVehicleClass(cache.vehicle)
    if Config.IgnoredClasses[class] then return false end
    if cache.seat ~= -1 then return false end

    if not lastLocation then
        lastLocation = GetEntityCoords(cache.vehicle)
    end

    local plate = trimPlate(cache.vehicle)
    if not plate then return false end

    -- Primeira vez neste veículo: resolve valor inicial
    if not mileageFetched then

        if vehicleIsFresh(cache.vehicle) then
            -- Saiu de garagem / comprado → sempre é carro de player → banco
            vehicleIsOwned = true
            currentMileage = 0.0
            consumeFreshFlag(cache.vehicle)
            pushToServer(plate, 0.0, true)

        else
            -- ================================================================
            --   SEMPRE consulta o servidor para determinar a origem correta
            --   (banco = player, ram = rua, nil = placa nova)
            --   Isso corrige o bug onde o statebag existia mas vehicleIsOwned
            --   ficava false, fazendo saves de carros de player irem para RAM.
            -- ================================================================
            local km, src = lib.callback.await("pr_mileage:cb:getMileage", false, plate)
            if km == nil then return false end

            local statebag = Entity(cache.vehicle).state.vehicleMileage

            if src == "db" then
                -- Carro de player encontrado no banco
                vehicleIsOwned = true
                -- Prefere o statebag se mais recente que o banco (outro player dirigiu antes)
                currentMileage = (statebag ~= nil and statebag > km) and statebag or km

            elseif src == "ram" then
                -- Carro da rua já registrado na RAM do servidor
                vehicleIsOwned = false
                -- Prefere o statebag se mais recente que a RAM
                currentMileage = (statebag ~= nil and statebag > km) and statebag or km

            else
                -- Placa nova — não existe em banco nem RAM
                vehicleIsOwned = false
                -- Usa statebag se existir; caso contrário gera km aleatório
                currentMileage = statebag ~= nil and statebag or rollInitialMileage(cache.vehicle)
                pushToServer(plate, currentMileage, false)
            end
        end

        syncStatebag(currentMileage)
        mileageFetched  = true
        -- FIX: lastSavedServer usa o valor do servidor (banco/RAM) como base do threshold
        -- Evita que o save seguinte seja bloqueado por threshold calculado errado
        lastSavedServer = km ~= -1 and km or currentMileage
        return true
    end

    -- Acumula distância (somente com rodas no chão e fora d'água)
    local dist = 0.0
    if IsVehicleOnAllWheels(cache.vehicle) and not IsEntityInWater(cache.vehicle) then
        dist = #(lastLocation - GetEntityCoords(cache.vehicle))
    end

    currentMileage = currentMileage + (dist / 1000.0)
    lastLocation   = GetEntityCoords(cache.vehicle)

    local rounded = tonumber(string.format("%.1f", currentMileage))

    if rounded ~= lastSavedLocal then
        syncStatebag(rounded)
        lastSavedLocal = rounded
    end

    if not lastSavedServer or math.abs(rounded - lastSavedServer) >= Config.SaveThreshold then
        pushToServer(plate, rounded, false)
        lastSavedServer = rounded
    end

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

        threadRunning  = false
        mileageFetched = false
        vehicleIsOwned = false
        lastSavedLocal = nil
        lastLocation   = nil
    end)
end

lib.onCache("vehicle", function(vehicle)
    local prev = cache.vehicle

    if not vehicle and prev and currentMileage then
        local plate = trimPlate(prev)
        if plate then pushToServer(plate, currentMileage, false) end
        return
    end

    startThread()
end)

CreateThread(function()
    registerDecor()
    if cache.vehicle then startThread() end
end)

-- ============================================================
--   HOOKS DE GARAGEM — marca veículo como fresh (km = 0)
-- ============================================================

local function applyFreshFlag(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    registerDecor()
    DecorSetBool(vehicle, DECOR_FRESH, true)
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
    return convertUnit(Entity(cache.vehicle).state.vehicleMileage or currentMileage)
end)

-- Mileage de qualquer entidade veículo pelo handle
---@param ent integer
---@return number|false
exports("getMileageByEntity", function(ent)
    if not ent or ent == 0 then return false end
    if not DoesEntityExist(ent) or not IsEntityAVehicle(ent) then return false end
    return convertUnit(Entity(ent).state.vehicleMileage or 0)
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
                local statebag = Entity(veh).state.vehicleMileage
                if statebag then return convertUnit(statebag) end
            end
        end
    end

    -- Veículo não está na cena → busca no servidor (banco ou RAM)
    local km, _ = lib.callback.await("pr_mileage:cb:getMileage", false, plate)
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
                local statebag = Entity(veh).state.vehicleMileage
                if statebag then return convertUnit(statebag), Config.Unit end
            end
        end
    end

    -- Veículo não está na cena → busca no servidor (banco ou RAM)
    local km, _ = lib.callback.await("pr_mileage:cb:getMileage", false, plate)
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
    return vehicleIsOwned
end)

-- Marca manualmente um veículo como fresh (km = 0 ao entrar)
---@param vehicle integer
exports("markFresh", function(vehicle) applyFreshFlag(vehicle) end)

-- Zera km do veículo atual diretamente
exports("resetCurrentMileage", function()
    if not cache.vehicle then return end
    currentMileage = 0.0
    syncStatebag(0.0)
    local plate = trimPlate(cache.vehicle)
    if plate then pushToServer(plate, 0.0, true) end
end)

-- ============================================================
--   COMANDOS DE TESTE
-- ============================================================

RegisterCommand("km", function()
    if not cache.vehicle then
        TriggerEvent("chat:addMessage", { color = {255,80,80}, args = {"[pr_mileage]", "Você não está em um veículo!"} })
        return
    end
    local plate     = trimPlate(cache.vehicle)
    local km        = Entity(cache.vehicle).state.vehicleMileage or currentMileage
    local className = Config.ClassNames[GetVehicleClass(cache.vehicle)] or "Desconhecido"
    local unit      = Config.Unit == "miles" and "mi" or "km"
    local tipo      = vehicleIsOwned and "Player" or "Rua"
    TriggerEvent("chat:addMessage", {
        color = {0, 200, 100},
        args  = {"[pr_mileage]", ("🚗 %s | %s | %s | %.1f %s"):format(plate, className, tipo, convertUnit(km), unit)}
    })
end, false)

RegisterCommand("kmplaca", function(_, args)
    local plate = args[1]
    if not plate then
        TriggerEvent("chat:addMessage", { color = {255,80,80}, args = {"[pr_mileage]", "Uso: /kmplaca [PLACA]"} })
        return
    end
    local km, _  = lib.callback.await("pr_mileage:cb:getMileage", false, plate:upper())
    local unit   = Config.Unit == "miles" and "mi" or "km"
    if not km or km == -1 then
        TriggerEvent("chat:addMessage", { color = {255,80,80}, args = {"[pr_mileage]", ("Placa %s não encontrada."):format(plate:upper())} })
    else
        TriggerEvent("chat:addMessage", { color = {0,200,255}, args = {"[pr_mileage]", ("🔍 %s | %.1f %s"):format(plate:upper(), convertUnit(km), unit)} })
    end
end, false)