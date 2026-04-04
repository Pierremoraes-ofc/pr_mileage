-- ============================================================
--   pr_mileage — CLIENT: PEÇAS E LOOP DE DESGASTE
-- ============================================================

-- Cache local das peças do veículo atual
-- Formato: { [partName] = { info do banco + current_km calculado } }
local cachedParts     = {}
local externalParts   = nil   -- tabela/callback passado por outro script (sem banco)
local loopRunning     = false
local lastSavedKm     = {}    -- { [partName] = km quando salvou por último }
local currentPlate    = nil
local currentVehicleKm = 0.0

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

local function loadPartsFromDB(plate, vehicleKm)
    local parts = lib.callback.await("pr_mileage:cb:getVehicleParts", false, plate, vehicleKm)
    if not parts then return end
    cachedParts = parts
    lastSavedKm = {}
    for partName, _ in pairs(cachedParts) do
        lastSavedKm[partName] = cachedParts[partName].current_km
    end
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
    currentVehicleKm = math.floor(Entity(vehicle).state.vehicleMileage or currentVehicleKm)

    -- ── Peças do banco (cachedParts) ──────────────────────
    for partName, entry in pairs(cachedParts) do
        -- current_km = quanto a peça já rodou desde instalação (ambos inteiros)
        local newCurrentKm = currentVehicleKm - math.floor(entry.installed_km or 0)
        if newCurrentKm < 0 then newCurrentKm = 0 end

        cachedParts[partName].current_km  = newCurrentKm
        cachedParts[partName].remaining_km = calcRemainingKm(newCurrentKm, entry.durability)

        -- Salva no banco a cada WearConfig.SaveThreshold km
        local lastSaved = lastSavedKm[partName] or newCurrentKm
        if math.abs(newCurrentKm - lastSaved) >= WearConfig.SaveThreshold then
            -- Atualiza installed_km de forma que current = vehicleKm - installed
            -- não há coluna current, então não salvamos (current é calculado sempre)
            -- Só salva se durabilidade mudou ou para auditoria futura
            lastSavedKm[partName] = newCurrentKm
        end
    end

    -- ── Peças externas (sem banco) ────────────────────────
    local extTable = type(externalParts) == "function" and externalParts() or externalParts
    if extTable then
        for partName, entry in pairs(extTable) do
            -- current_km vem de fora, não calculamos
            local driven    = currentVehicleKm - (entry.installed_km or 0)
            local current   = driven > 0 and driven or 0.0
            extTable[partName].current_km   = current
            extTable[partName].remaining_km = calcRemainingKm(current, entry.durability or 1)
        end
    end

    -- ── Aplica efeitos visuais/físicos ────────────────────
    local allParts = {}
    for k, v in pairs(cachedParts) do allParts[k] = v end
    if extTable then
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

lib.onCache("vehicle", function(vehicle)
    local prev = cache.vehicle

    if not vehicle then
        -- Saiu do veículo: limpa cache
        cachedParts    = {}
        lastSavedKm    = {}
        currentPlate   = nil
        loopRunning    = false
        return
    end

    -- Entrou em veículo: carrega peças do banco
    local plate = GetVehicleNumberPlateText(vehicle)
    if plate then
        plate = plate:gsub("^%s*(.-)%s*$", "%1"):upper()
        currentPlate     = plate
        -- FIX: math.floor — installed_km no banco é INT, então vehicleKm deve ser inteiro
        currentVehicleKm = math.floor(Entity(vehicle).state.vehicleMileage or 0)
        loadPartsFromDB(plate, currentVehicleKm)
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
        if cache.vehicle and Entity(cache.vehicle).state.vehicleMileage then
            break
        end
    end

    if not cache.vehicle then return end

    local plate = GetVehicleNumberPlateText(cache.vehicle)
    if not plate then return end

    plate = plate:gsub("^%s*(.-)%s*$", "%1"):upper()
    currentPlate     = plate
    currentVehicleKm = math.floor(Entity(cache.vehicle).state.vehicleMileage or 0)

    -- Força reload do banco (garante que mudanças manuais no banco sejam lidas)
    loadPartsFromDB(plate, currentVehicleKm)

    -- Garante que o loop está rodando mesmo após restart
    loopRunning = false
    startWearLoop()
end)

-- ============================================================
--   EVENTOS DE REDE — confirmações do servidor
-- ============================================================

RegisterNetEvent("pr_mileage:cl:partInstalled")
AddEventHandler("pr_mileage:cl:partInstalled", function(plate, partName, durability)
    if plate ~= currentPlate then return end
    -- Recarrega as peças do banco para atualizar o cache
    loadPartsFromDB(plate, currentVehicleKm)
end)

RegisterNetEvent("pr_mileage:cl:partRemoved")
AddEventHandler("pr_mileage:cl:partRemoved", function(plate, partName)
    if plate ~= currentPlate then return end
    cachedParts[partName]  = nil
    lastSavedKm[partName]  = nil
end)

-- ============================================================
--   EXPORTS CLIENT
-- ============================================================

-- GetPartsPercent(partName) → % restante (0–100) | false
exports("GetPartsPercent", function(partName)
    if not partName then return false end
    local entry = cachedParts[partName]
    if not entry then
        -- Verifica peças externas
        local ext = type(externalParts) == "function" and externalParts() or externalParts
        entry = ext and ext[partName]
    end
    if not entry then return false end
    local percent = calcPercent(entry.current_km or 0, entry.durability or 1)
    return math.floor(percent * 1000) / 10
end)

-- GetPartsMileage(partName) → km restantes | false
exports("GetPartsMileage", function(partName)
    if not partName then return false end
    local entry = cachedParts[partName]
    if not entry then
        local ext = type(externalParts) == "function" and externalParts() or externalParts
        entry = ext and ext[partName]
    end
    if not entry then return false end
    return calcRemainingKm(entry.current_km or 0, entry.durability or 1)
end)

-- GetPartsStatus(partName) → "Boa" | "Razoável" | "Ruim" | false
exports("GetPartsStatus", function(partName)
    if not partName then return false end
    local entry = cachedParts[partName]
    if not entry then
        local ext = type(externalParts) == "function" and externalParts() or externalParts
        entry = ext and ext[partName]
    end
    if not entry then return false end
    local percent = calcPercent(entry.current_km or 0, entry.durability or 1)
    return resolveStatus(percent)
end)

-- GetParts(partName) → tabela completa | false
exports("GetParts", function(partName)
    if not partName then return false end
    local entry = cachedParts[partName]
    if not entry then
        local ext = type(externalParts) == "function" and externalParts() or externalParts
        entry = ext and ext[partName]
    end
    if not entry then return false end
    return buildInfo(partName, entry)
end)

-- GetVehicleParts() → tabela de TODAS as peças do veículo atual | {}
exports("GetVehicleParts", function()
    local result = {}
    local ext    = type(externalParts) == "function" and externalParts() or externalParts

    for partName, entry in pairs(cachedParts) do
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
        currentPlate, partName, stage or 1, math.floor(currentVehicleKm), citizenId or nil)
    return true
end)

-- Remove uma peça client-side
exports("removePart", function(partName)
    if not currentPlate then return false end
    TriggerServerEvent("pr_mileage:sv:removePart", currentPlate, partName)
    return true
end)

-- Força recarregar as peças do banco (útil após instalar via outro script)
exports("reloadParts", function()
    if not cache.vehicle or not currentPlate then return end
    currentVehicleKm = Entity(cache.vehicle).state.vehicleMileage or currentVehicleKm
    loadPartsFromDB(currentPlate, currentVehicleKm)
end)

-- ── Opção 2: peças externas (sem banco) ──────────────────
-- Aceita tabela estática ou função que retorna tabela
-- Formato: { [partName] = { installed_km=X, durability=Y, stage=Z } }
-- Uso: exports["pr_mileage"]:setExternalParts(myTable)
--      exports["pr_mileage"]:setExternalParts(function() return myTable end)
exports("setExternalParts", function(source)
    externalParts = source
end)

-- Limpa peças externas
exports("clearExternalParts", function()
    externalParts = nil
end)

-- Retorna placa do veículo atual rastreado
exports("getCurrentPlate", function()
    return currentPlate
end)

-- ============================================================
--   COMANDOS
-- ============================================================

-- /installpeca [nome_da_peca] [stage=1]
-- Instala uma peça no veículo atual. citizenId = null (NPC/sistema)
RegisterCommand("installpeca", function(_, args)
    local msg = function(color, text)
        TriggerEvent("chat:addMessage", { color = color, args = {"[pr_mileage]", text} })
    end

    if not cache.vehicle then
        msg({255,80,80}, "Você não está em um veículo!")
        return
    end

    local partName = args[1]
    if not partName then
        msg({255,80,80}, "Uso: /installpeca [nome_da_peca] [stage]")
        msg({200,200,200}, "Peças disponíveis: " .. table.concat((function()
            local list = {}
            for k in pairs(Parts.Items) do list[#list+1] = k end
            table.sort(list)
            return list
        end)(), ", "))
        return
    end

    if not Parts.Items[partName] then
        msg({255,80,80}, ("Peça '%s' não existe em Parts.Items!"):format(partName))
        return
    end

    local stage = tonumber(args[2]) or 1

    -- FIX: math.floor — installed_km no banco é INT UNSIGNED
    TriggerServerEvent("pr_mileage:sv:installPart",
        currentPlate,
        partName,
        stage,
        math.floor(currentVehicleKm),
        nil  -- citizenId = null (NPC)
    )

    msg({0,200,100}, ("✅ Instalando '%s' (stage %d) na placa %s..."):format(partName, stage, currentPlate))
end, false)

-- /reloadpecas — força recarregar todas as peças do banco (útil após mudar no banco manualmente)
RegisterCommand("reloadpecas", function()
    local msg = function(color, text)
        TriggerEvent("chat:addMessage", { color = color, args = {"[pr_mileage]", text} })
    end

    if not cache.vehicle then
        msg({255,80,80}, "Você não está em um veículo!")
        return
    end

    local plate = GetVehicleNumberPlateText(cache.vehicle)
    if not plate then return end
    plate = plate:gsub("^%s*(.-)%s*$", "%1"):upper()
    currentPlate     = plate
    currentVehicleKm = math.floor(Entity(cache.vehicle).state.vehicleMileage or 0)

    loadPartsFromDB(plate, currentVehicleKm)

    -- Reinicia o loop de desgaste para aplicar os novos valores imediatamente
    loopRunning = false
    startWearLoop()

    msg({0,200,255}, ("🔄 Peças recarregadas do banco — placa %s | odômetro %d km"):format(plate, currentVehicleKm))
end, false)

-- /removepeca [nome_da_peca]
RegisterCommand("removepeca", function(_, args)
    local msg = function(color, text)
        TriggerEvent("chat:addMessage", { color = color, args = {"[pr_mileage]", text} })
    end

    if not cache.vehicle then
        msg({255,80,80}, "Você não está em um veículo!")
        return
    end

    local partName = args[1]
    if not partName then
        msg({255,80,80}, "Uso: /removepeca [nome_da_peca]")
        return
    end

    TriggerServerEvent("pr_mileage:sv:removePart", currentPlate, partName)
    msg({255,150,0}, ("🗑️ Removendo '%s' da placa %s..."):format(partName, currentPlate))
end, false)

-- /pecas — lista todas as peças instaladas no veículo atual
RegisterCommand("pecas", function()
    local msg = function(color, text)
        TriggerEvent("chat:addMessage", { color = color, args = {"[pr_mileage]", text} })
    end

    if not cache.vehicle then
        msg({255,80,80}, "Você não está em um veículo!")
        return
    end

    if not next(cachedParts) then
        msg({200,200,200}, ("Nenhuma peça registrada na placa %s."):format(currentPlate or "?"))
        return
    end

    local liveKm = math.floor(Entity(cache.vehicle).state.vehicleMileage or currentVehicleKm)
    msg({0,200,255}, ("🔧 Peças instaladas — %s | Odômetro atual: %d km"):format(currentPlate or "?", liveKm))

    for partName, entry in pairs(cachedParts) do
        -- Recalcula com o odômetro atual (não o do momento de entrada no veículo)
        local installedKm = math.floor(entry.installed_km or 0)
        local durability  = math.floor(entry.durability or 1)
        local currentKm   = math.max(0, liveKm - installedKm)
        local percent     = calcPercent(currentKm, durability)
        local pct         = math.floor(percent * 1000) / 10
        local status      = resolveStatus(percent)
        local remaining   = math.max(0, durability - currentKm)

        -- Calcula qual sintoma está ativo agora
        local ratio = durability > 0 and (1.0 - (currentKm / durability)) or 0.0
        local activeSyntom = "Nenhum"
        local partDef = Parts.Items[partName]
        if partDef and partDef.symptoms then
            local best = nil
            for _, s in ipairs(partDef.symptoms) do
                if ratio <= s.threshold then
                    if not best or s.threshold < best.threshold then best = s end
                end
            end
            if best then activeSyntom = best.label end
        end

        local color = pct >= 60 and {0,200,100} or (pct >= 30 and {255,200,0} or {255,80,80})

        -- Linha principal: status e km
        TriggerEvent("chat:addMessage", {
            color = color,
            args  = {"[pr_mileage]", ("[%s] Stage %d | %.1f%% | %d/%d km | %s"):format(
                partName, entry.stage or 1, pct, currentKm, durability, status
            )}
        })
        -- Linha de debug: valores raw e sintoma ativo
        TriggerEvent("chat:addMessage", {
            color = {150,150,150},
            args  = {"[pr_mileage]", ("  ↳ instalado km=%d | rodou=%d | restam=%d | ratio=%.2f | sintoma: %s"):format(
                installedKm, currentKm, remaining, ratio, activeSyntom
            )}
        })
    end
end, false)