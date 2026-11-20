-- ============================================================
--   pr_mileage — CLIENT: PEÇAS E LOOP DE DESGASTE
-- ============================================================

-- O estado persistente do veículo vive exclusivamente nos state bags.
local loopRunning = false
local currentPlate = nil -- placa original resolvida pelo servidor
local currentVehicleKm = 0.0

local function displayedPlate(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return nil end
    local plate = GetVehicleNumberPlateText(vehicle)
    return plate and plate:gsub("%s+", ""):upper() or nil
end

local function getStateParts(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return {} end
    return PRMileagePartsGet(vehicle)
end

local function getExternalParts(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return {} end
    return PRMileageExternalPartsGet(vehicle)
end

-- ============================================================
--   UTILITÁRIOS INTERNOS
-- ============================================================

local function calcPercent(currentKm, durability)
    if durability <= 0 then return 0.0 end
    -- FIX: math.floor garante que apenas km inteiros contam no desgaste
    local km = math.floor(currentKm)
    local remaining = durability - km
    if remaining < 0 then remaining = 0 end
    return remaining / durability
end

local function calcRemainingKm(currentKm, durability)
    -- FIX: math.floor — km restantes sempre inteiro
    local r = durability - math.floor(currentKm)
    return r > 0 and r or 0
end

local function resolveStatus(percent)
    if percent >= WearConfig.StatusThresholds.good then
        return WearConfig.StatusLabels.good
    elseif percent >= WearConfig.StatusThresholds.fair then
        return WearConfig.StatusLabels.fair
    else
        return WearConfig.StatusLabels.bad
    end
end

-- Monta tabela de info completa a partir de um item do cache
local function buildInfo(partName, entry)
    local currentKm  = entry.current_km  or 0.0
    local durability = entry.durability  or 1.0
    local percent    = calcPercent(currentKm, durability)
    return {
        part         = partName,
        stage        = entry.stage,
        installed_km = entry.installed_km,
        durability   = durability,
        current_km   = currentKm,
        remaining_km = calcRemainingKm(currentKm, durability),
        percent      = math.floor(percent * 1000) / 10,
        status       = resolveStatus(percent),
        citizen_id   = entry.citizen_id,
        installed_at = entry.installed_at,
    }
end

-- ============================================================
--   CARREGA PEÇAS DO BANCO AO ENTRAR NO VEÍCULO
-- ============================================================

local function loadPartsFromDB(plate, vehicleKm, vehicle)
    vehicle = vehicle or cache.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return false end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local parts, originalPlate, identity = pr_lib.callback.await(
        "pr_mileage:cb:getVehicleParts",
        10000,
        plate,
        vehicleKm,
        netId
    )
    if parts == false or type(parts) ~= "table" then return false end

    currentPlate = originalPlate or plate
    PRMileagePartsSet(vehicle, parts, false, { force = true })
    if type(identity) == "table" then
        PRMileageIdentitySet(vehicle, identity, false, { force = true })
    end
    return true
end

-- ============================================================
--   LOOP PRINCIPAL DE DESGASTE
--   Roda a cada WearConfig.TickInterval ms
--   Calcula desgaste, aplica efeitos, salva quando necessário
-- ============================================================

local function wearTick(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    if cache.seat ~= -1 then return true end -- não é motorista, mantém loop mas não degasta

    -- FIX: math.floor — vehicleKm inteiro para consistência com installed_km INT no banco
    currentVehicleKm = math.floor(PRMileageGet(vehicle, currentVehicleKm))

    -- As peças-base são lidas do state bag; os valores de desgaste são derivados.
    local vehicleParts = {}
    for partName, entry in pairs(getStateParts(vehicle)) do
        local derived = {}
        for key, value in pairs(entry) do derived[key] = value end
        local newCurrentKm = math.max(0, currentVehicleKm - math.floor(entry.installed_km or 0))
        derived.current_km = newCurrentKm
        derived.remaining_km = calcRemainingKm(newCurrentKm, entry.durability or 0)
        vehicleParts[partName] = derived
    end

    -- ── Peças externas (sem banco) ────────────────────────
    local extTable = getExternalParts(vehicle)
    if next(extTable) then
        for partName, entry in pairs(extTable) do
            local driven    = currentVehicleKm - (entry.installed_km or 0)
            local current   = driven > 0 and driven or 0.0
            entry.current_km   = current
            entry.remaining_km = calcRemainingKm(current, entry.durability or 1)
        end
    end

    -- ── Aplica efeitos visuais/físicos ────────────────────
    local allParts = {}
    for k, v in pairs(vehicleParts) do allParts[k] = v end
    if next(extTable) then
        for k, v in pairs(extTable) do allParts[k] = v end
    end

    if next(allParts) then
        -- Delega ao cl_wear.lua via evento local (evita acoplamento direto)
        TriggerEvent("pr_mileage:local:applyWear", vehicle, allParts)
    end

    return true
end

local function startWearLoop()
    if loopRunning then return end
    loopRunning = true

    CreateThread(function()
        while cache.vehicle do
            Wait(WearConfig.TickInterval)
            if not wearTick(cache.vehicle) then break end
        end

        loopRunning = false
    end)
end

-- ============================================================
--   EVENTO LOCAL → recebido pelo cl_wear.lua
--   (cl_wear.lua registra este handler e aplica os efeitos)
-- ============================================================

-- cl_wear.lua escuta "pr_mileage:local:applyWear" e chama applyWearEffects()
-- Isso mantém cl_wear totalmente desacoplado

-- ============================================================
--   HOOKS DE CACHE — entra/sai de veículo
-- ============================================================

pr_lib.onCache("vehicle", function(vehicle)
    if not vehicle then
        currentPlate = nil
        loopRunning = false
        return
    end

    -- Entrou em veículo: carrega peças do banco
    local plate = displayedPlate(vehicle)
    if plate then
        currentVehicleKm = math.floor(PRMileageGet(vehicle, 0))
        loadPartsFromDB(plate, currentVehicleKm, vehicle)
    end

    startWearLoop()
end)

-- Carrega ao iniciar o resource — aguarda statebag estar disponível
-- Isso cobre tanto o primeiro load quanto o restart do script com player já no veículo
CreateThread(function()
    -- Aguarda até o statebag estar populado (client.lua precisa ter rodado primeiro)
    local waited = 0
    while waited < 5000 do
        Wait(200)
        waited = waited + 200
        if cache.vehicle and PRMileageGet(cache.vehicle) then
            break
        end
    end

    if not cache.vehicle then return end

    local plate = displayedPlate(cache.vehicle)
    if not plate then return end

    currentVehicleKm = math.floor(PRMileageGet(cache.vehicle, 0))
    loadPartsFromDB(plate, currentVehicleKm, cache.vehicle)

    -- Garante que o loop está rodando mesmo após restart
    loopRunning = false
    startWearLoop()
end)

-- ============================================================
--   EVENTOS DE REDE — confirmações do servidor
-- ============================================================

-- Lista de itens que são pneus — ao instalar, repara os pneus físicos do veículo
local TYRE_PARTS = {
    tire_common   = true,
    tire_street   = true,
    tire_sport    = true,
    tire_race     = true,
    tire_semislick = true,
    tire_slick    = true,
    tire_drift    = true,
    tire_touring  = true,
}

local function RepairVehicleTyres(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local tyreIndexes = {0, 1, 2, 3, 4, 5, 45, 47}
    for _, tyreIndex in ipairs(tyreIndexes) do
        SetVehicleTyreFixed(vehicle, tyreIndex)
    end
end

RegisterNetEvent("pr_mileage:cl:partInstalled")
AddEventHandler("pr_mileage:cl:partInstalled", function(plate, partName, durability)
    if plate ~= currentPlate then return end
    loadPartsFromDB(displayedPlate(cache.vehicle), currentVehicleKm, cache.vehicle)
    -- Força reset imediato do handling para os valores originais do veículo
    if cache.vehicle and DoesEntityExist(cache.vehicle) then
        TriggerEvent("pr_mileage:local:resetHandling", cache.vehicle)
    end
    -- Se for pneu, repara os pneus físicos do veículo
    if TYRE_PARTS[partName] then
        local vehicle = cache.vehicle
        if not vehicle or not DoesEntityExist(vehicle) then
            -- Tenta pegar o veículo mais próximo
            local ped = PlayerPedId()
            vehicle = GetClosestVehicle(GetEntityCoords(ped), 5.0, 0, 71)
        end
        RepairVehicleTyres(vehicle)
    end
end)

RegisterNetEvent("pr_mileage:cl:partRemoved")
AddEventHandler("pr_mileage:cl:partRemoved", function(plate, partName)
    if plate ~= currentPlate then return end
    -- O servidor já publicou o novo state bag sem esta peça.
end)

-- ============================================================
--   EXPORTS CLIENT
-- ============================================================

-- GetPartsPercent(partName) → % restante (0–100) | false
exports("GetPartsPercent", function(partName)
    if not partName then return false end
    local entry = getStateParts(cache.vehicle)[partName]
    if not entry then
        -- Verifica peças externas
        local ext = getExternalParts(cache.vehicle)
        entry = ext and ext[partName]
    end
    if not entry then return false end
    local percent = calcPercent(entry.current_km or 0, entry.durability or 1)
    return math.floor(percent * 1000) / 10
end)

-- GetPartsMileage(partName) → km restantes | false
exports("GetPartsMileage", function(partName)
    if not partName then return false end
    local entry = getStateParts(cache.vehicle)[partName]
    if not entry then
        local ext = getExternalParts(cache.vehicle)
        entry = ext and ext[partName]
    end
    if not entry then return false end
    return calcRemainingKm(entry.current_km or 0, entry.durability or 1)
end)

-- GetPartsStatus(partName) → "Boa" | "Razoável" | "Ruim" | false
exports("GetPartsStatus", function(partName)
    if not partName then return false end
    local entry = getStateParts(cache.vehicle)[partName]
    if not entry then
        local ext = getExternalParts(cache.vehicle)
        entry = ext and ext[partName]
    end
    if not entry then return false end
    local percent = calcPercent(entry.current_km or 0, entry.durability or 1)
    return resolveStatus(percent)
end)

-- GetParts(partName) → tabela completa | false
exports("GetParts", function(partName)
    if not partName then return false end
    local entry = getStateParts(cache.vehicle)[partName]
    if not entry then
        local ext = getExternalParts(cache.vehicle)
        entry = ext and ext[partName]
    end
    if not entry then return false end
    return buildInfo(partName, entry)
end)

-- GetVehicleParts() → tabela de TODAS as peças do veículo atual | {}
exports("GetVehicleParts", function()
    local result = {}
    local ext    = getExternalParts(cache.vehicle)

    for partName, entry in pairs(getStateParts(cache.vehicle)) do
        result[partName] = buildInfo(partName, entry)
    end
    if ext then
        for partName, entry in pairs(ext) do
            if not result[partName] then
                result[partName] = buildInfo(partName, entry)
            end
        end
    end
    return result
end)

-- Instala uma peça client-side (dispara evento ao servidor)
-- installPart(partName, stage) — usa placa e km do veículo atual
exports("installPart", function(partName, stage, citizenId)
    if not cache.vehicle or not currentPlate then return false end
    -- FIX: math.floor — installed_km no banco é INT UNSIGNED
    TriggerServerEvent("pr_mileage:sv:installPart",
        displayedPlate(cache.vehicle), partName, stage or 1, math.floor(currentVehicleKm),
        citizenId or nil, NetworkGetNetworkIdFromEntity(cache.vehicle))
    return true
end)

-- Remove uma peça client-side
exports("removePart", function(partName)
    if not currentPlate then return false end
    TriggerServerEvent("pr_mileage:sv:removePart",
        displayedPlate(cache.vehicle), partName, NetworkGetNetworkIdFromEntity(cache.vehicle))
    return true
end)

-- Força recarregar as peças do banco (útil após instalar via outro script)
exports("reloadParts", function()
    if not cache.vehicle or not currentPlate then return end
    currentVehicleKm = PRMileageGet(cache.vehicle, currentVehicleKm)
    loadPartsFromDB(displayedPlate(cache.vehicle), currentVehicleKm, cache.vehicle)
end)

-- ── Opção 2: peças externas (sem banco) ──────────────────
-- A tabela também é guardada no state bag da entidade.
-- Formato: { [partName] = { installed_km=X, durability=Y, stage=Z } }
-- Uso: exports["pr_mileage"]:setExternalParts(myTable)
exports("setExternalParts", function(source)
    if not cache.vehicle or type(source) ~= "table" then return false end
    return PRMileageExternalPartsSet(cache.vehicle, source, true, { force = true })
end)

-- Limpa peças externas
exports("clearExternalParts", function()
    if not cache.vehicle then return false end
    return PRMileageExternalPartsSet(cache.vehicle, {}, true, { force = true })
end)

-- Retorna placa do veículo atual rastreado
exports("getCurrentPlate", function()
    return currentPlate
end)

-- ============================================================
--   COMANDOS (PR Bridge)
-- ============================================================

local function commandMessage(color, message)
    TriggerEvent("chat:addMessage", { color = color, args = {"[pr_mileage]", message} })
end

pr_lib.addCommand("installpeca", {
    help = "Instala uma peça no veículo atual",
    params = {
        { name = "part", type = "string", optional = true, help = "Nome da peça" },
        { name = "stage", type = "number", optional = true, help = "Estágio da peça" },
    },
}, function(params)
    if not cache.vehicle then
        commandMessage({255,80,80}, "Você não está em um veículo!")
        return
    end

    local partName = params.part
    if not partName then
        local list = {}
        for key in pairs(Parts.Items) do list[#list + 1] = key end
        table.sort(list)
        commandMessage({255,80,80}, "Uso: /installpeca [nome_da_peca] [stage]")
        commandMessage({200,200,200}, "Peças disponíveis: " .. table.concat(list, ", "))
        return
    end

    if not Parts.Items[partName] then
        commandMessage({255,80,80}, ("Peça '%s' não existe em Parts.Items!"):format(partName))
        return
    end

    local stage = math.floor(tonumber(params.stage) or 1)
    local vehicle = cache.vehicle
    local plate = displayedPlate(vehicle)
    TriggerServerEvent(
        "pr_mileage:sv:installPart",
        plate,
        partName,
        stage,
        math.floor(currentVehicleKm),
        nil,
        NetworkGetNetworkIdFromEntity(vehicle)
    )
    commandMessage(
        {0,200,100},
        ("Instalando '%s' (stage %d) na placa original %s..."):format(partName, stage, currentPlate or plate)
    )
end)

pr_lib.addCommand("reloadpecas", {
    help = "Recarrega as peças do veículo atual",
}, function()
    local vehicle = cache.vehicle
    if not vehicle then
        commandMessage({255,80,80}, "Você não está em um veículo!")
        return
    end

    local plate = displayedPlate(vehicle)
    if not plate then return end

    currentVehicleKm = math.floor(PRMileageGet(vehicle, 0))
    if not loadPartsFromDB(plate, currentVehicleKm, vehicle) then
        commandMessage({255,80,80}, "Não foi possível carregar as peças deste veículo.")
        return
    end

    loopRunning = false
    startWearLoop()
    commandMessage(
        {0,200,255},
        ("Peças recarregadas — placa original %s | odômetro %d km"):format(currentPlate or plate, currentVehicleKm)
    )
end)

pr_lib.addCommand("removepeca", {
    help = "Remove uma peça do veículo atual",
    params = {
        { name = "part", type = "string", optional = true, help = "Nome da peça" },
    },
}, function(params)
    local vehicle = cache.vehicle
    if not vehicle then
        commandMessage({255,80,80}, "Você não está em um veículo!")
        return
    end

    local partName = params.part
    if not partName then
        commandMessage({255,80,80}, "Uso: /removepeca [nome_da_peca]")
        return
    end

    TriggerServerEvent(
        "pr_mileage:sv:removePart",
        displayedPlate(vehicle),
        partName,
        NetworkGetNetworkIdFromEntity(vehicle)
    )
    commandMessage({255,150,0}, ("Removendo '%s' da placa original %s..."):format(partName, currentPlate or "?"))
end)

pr_lib.addCommand("pecas", {
    help = "Lista as peças instaladas no veículo atual",
}, function()
    local vehicle = cache.vehicle
    if not vehicle then
        commandMessage({255,80,80}, "Você não está em um veículo!")
        return
    end

    local parts = getStateParts(vehicle)
    if not next(parts) then
        commandMessage({200,200,200}, ("Nenhuma peça registrada na placa %s."):format(currentPlate or "?"))
        return
    end

    local liveKm = math.floor(PRMileageGet(vehicle, currentVehicleKm))
    commandMessage({0,200,255}, ("Peças instaladas — %s | Odômetro atual: %d km"):format(currentPlate or "?", liveKm))

    for partName, entry in pairs(parts) do
        local installedKm = math.floor(entry.installed_km or 0)
        local durability = math.floor(entry.durability or 1)
        local currentKm = math.max(0, liveKm - installedKm)
        local percent = calcPercent(currentKm, durability)
        local pct = math.floor(percent * 1000) / 10
        local status = resolveStatus(percent)
        local remaining = math.max(0, durability - currentKm)
        local ratio = durability > 0 and (1.0 - (currentKm / durability)) or 0.0
        local activeSymptom = "Nenhum"
        local partDef = Parts.Items[partName]

        if partDef and partDef.symptoms then
            local best
            for _, symptom in ipairs(partDef.symptoms) do
                if ratio <= symptom.threshold and (not best or symptom.threshold < best.threshold) then
                    best = symptom
                end
            end
            if best then activeSymptom = best.label end
        end

        local color = pct >= 60 and {0,200,100} or (pct >= 30 and {255,200,0} or {255,80,80})
        TriggerEvent("chat:addMessage", {
            color = color,
            args = {"[pr_mileage]", ("[%s] Stage %d | %.1f%% | %d/%d km | %s"):format(
                partName, entry.stage or 1, pct, currentKm, durability, status
            )}
        })
        TriggerEvent("chat:addMessage", {
            color = {150,150,150},
            args = {"[pr_mileage]", ("  ↳ instalado km=%d | rodou=%d | restam=%d | ratio=%.2f | sintoma: %s"):format(
                installedKm, currentKm, remaining, ratio, activeSymptom
            )}
        })
    end
end)
