-- ============================================================
--   pr_mileage — MOTOR DE EFEITOS DE DESGASTE
--   Lê Parts.Items e aplica efeitos baseados na durabilidade
--   restante de cada peça
-- ============================================================

local activeParticles   = {}   -- { [partName] = handle }
local activeEffects     = {}   -- { [partName] = { type, ... } } efeitos persistentes ativos
local wearThreadRunning = false

-- ============================================================
--   APLICADORES DE EFEITO
--   Cada função recebe (vehicle, params) e aplica o efeito
-- ============================================================

local Appliers = {}

-- Partícula loopada na entidade
Appliers["particle"] = function(vehicle, params, partName)
    if activeParticles[partName] then return end
    print(("[pr_mileage][particle] Iniciando: part=%s | dict=%s | name=%s"):format(
        partName, params.dict or "?", params.name or "?"))

    RequestNamedPtfxAsset(params.dict)
    local timeout = 0
    while not HasNamedPtfxAssetLoaded(params.dict) and timeout < 3000 do
        Wait(100); timeout = timeout + 100
    end

    UseParticleFxAssetNextCall(params.dict)

    local boneIdx = GetEntityBoneIndexByName(vehicle, params.bone or "engine")
    local offset  = params.offset or vector3(0, 0, 0)
    local scale   = params.scale or 1.0

    local handle = StartParticleFxLoopedOnEntityBone(
        params.name,
        vehicle,
        offset.x or 0.0, offset.y or 0.0, offset.z or 0.0,
        0.0, 0.0, 0.0,
        boneIdx,
        scale,
        false, false, false
    )

    activeParticles[partName] = handle
end

-- Para partícula de uma peça
local function stopParticle(partName)
    if activeParticles[partName] then
        StopParticleFxLooped(activeParticles[partName], false)
        activeParticles[partName] = nil
    end
end

-- Saúde do motor
Appliers["engine_health"] = function(vehicle, params)
    local current = GetVehicleEngineHealth(vehicle)
    if current > params.value then
        SetVehicleEngineHealth(vehicle, params.value)
    end
end

-- Multiplicador de potência
Appliers["power_mult"] = function(vehicle, params)
    print(("[pr_mileage][power_mult] Aplicando: value=%.2f"):format(params.value))
    SetVehicleCheatPowerIncrease(vehicle, params.value)
end

-- Multiplicador de torque (via fDriveInertia)
Appliers["torque_mult"] = function(vehicle, params)
    print(("[pr_mileage][torque_mult] Aplicando: fDriveInertia=%.2f"):format(params.value))
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia", params.value)
end

-- Veículo inoperante
Appliers["undriveable"] = function(vehicle, params)
    SetVehicleUndriveable(vehicle, params.value)
end

-- Liga/desliga motor
Appliers["engine_on"] = function(vehicle, params)
    SetVehicleEngineOn(vehicle, params.value, true, true)
end

-- Vibração de câmera persistente
-- ShakeGameplayCam inicia o shake mas para sozinho após alguns frames
-- A combinação correta é: iniciar com ShakeGameplayCam e manter com SetGameplayCamShakeAmplitude
-- IsGameplayCamShaking verifica se já está ativo para não reiniciar desnecessariamente
Appliers["shake_cam"] = function(_, params)
    local shakeType = params.type or "ROAD_VIBRATION_SHAKE"
    local intensity = params.intensity or 0.05
    print(("[pr_mileage][shake_cam] Aplicando: type=%s | intensity=%.3f | jaShaking=%s"):format(
        shakeType, intensity, tostring(IsGameplayCamShaking())))
    if not IsGameplayCamShaking() then
        -- Inicia o shake (necessário para definir o tipo)
        ShakeGameplayCam(shakeType, intensity)
    end
    -- Mantém a amplitude atualizada a cada tick (garante persistência)
    SetGameplayCamShakeAmplitude(intensity)
end

-- Aplica força ao veículo (micro trancos)
Appliers["apply_force"] = function(vehicle, params)
    local x, y, z = params.x or 0.0, params.y or 0.0, params.z or 0.0
    local intensity = params.intensity or 0.5
    if params.random then
        x = (math.random() - 0.5) * intensity
        y = (math.random() - 0.5) * intensity
    end
    ApplyForceToEntity(vehicle, 1, x, y, z, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
end

-- Altera float de handling
Appliers["handling_float"] = function(vehicle, params)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", params.field, params.value)
end

-- Estoura pneu
Appliers["tyre_burst"] = function(vehicle, params)
    if not IsVehicleTyreBurst(vehicle, params.wheel, false) then
        SetVehicleTyreBurst(vehicle, params.wheel, true, 1000.0)
    end
end

-- Controla faróis
Appliers["vehicle_lights"] = function(vehicle, params)
    SetVehicleLights(vehicle, params.state)
end

-- Pisca setas
Appliers["indicator"] = function(vehicle, params)
    SetVehicleIndicatorLights(vehicle, 0, params.left  or false)
    SetVehicleIndicatorLights(vehicle, 1, params.right or false)
end

-- Força RPM
Appliers["rpm_override"] = function(vehicle, params)
    SetVehicleCurrentRpm(vehicle, params.value)
end

-- Stall aleatório (desliga motor por 1-2 segundos)
Appliers["stall"] = function(vehicle, params)
    local chance = params.chance or 0.05
    print(("[pr_mileage][stall] Rolando chance: %.0f%% (chance=%.2f)"):format(chance * 100, chance))
    if math.random() < chance then
        SetVehicleEngineOn(vehicle, false, true, true)
        Wait(math.random(800, 2000))
        if DoesEntityExist(vehicle) then
            SetVehicleEngineOn(vehicle, true, true, true)
        end
    end
end

-- Limita ângulo de direção
Appliers["steering_scale"] = function(vehicle, params)
    SetVehicleSteeringScale(vehicle, params.value)
end

-- Força lateral constante (direção desalinhada)
Appliers["lateral_force"] = function(vehicle, params)
    local speed = GetEntitySpeed(vehicle)
    if speed > 2.0 then
        ApplyForceToEntity(vehicle, 1, params.value or 0.3, 0.0, 0.0,
            0.0, 0.0, 0.0, 0, false, true, true, false, true)
    end
end

-- ============================================================
--   RESOLVE SINTOMA ATIVO PARA UMA PEÇA
--   Dado o ratio de durabilidade (0.0–1.0), retorna o
--   sintoma mais severo que foi ativado (menor threshold)
-- ============================================================

-- Retorna o sintoma MAIS SEVERO ativo para o ratio de durabilidade dado
-- ratio = percentual RESTANTE (0.0 = peça destruída, 1.0 = peça nova)
-- threshold = percentual restante que ativa o sintoma (ex: 0.50 = ativa quando restam <= 50%)
-- "mais severo" = menor threshold (ex: 0.05 é mais severo que 0.50)
-- Se ratio=0.20: threshold 0.50 ativa (0.20<=0.50✓), threshold 0.25 ativa (0.20<=0.25✓),
--               threshold 0.05 NÃO ativa (0.20<=0.05✗) → retorna threshold=0.25
local function resolveActiveSympom(partData, ratio)
    local active = nil
    for _, symptom in ipairs(partData.symptoms) do
        if ratio <= symptom.threshold then
            -- Ativa o mais severo (menor threshold) entre os elegíveis
            if not active or symptom.threshold < active.threshold then
                active = symptom
            end
        end
    end
    return active
end

-- ============================================================
--   LIMPA TODOS OS EFEITOS ATIVOS
-- ============================================================

local function clearAllEffects(vehicle)
    -- Para partículas
    for partName, _ in pairs(activeParticles) do
        stopParticle(partName)
    end

    -- Reseta multiplicadores usando os natives corretos
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleCheatPowerIncrease(vehicle, 1.0)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia", 1.0)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleSteeringScale(vehicle, 1.0)
    end
    -- Para o shake da câmera ao limpar efeitos
    StopGameplayCamShaking(true)

    activeEffects = {}
end

-- ============================================================
--   TICK DE DESGASTE
--   Chamado a cada segundo enquanto o player dirige.
--   Recebe a tabela de peças do veículo atual (durabilidade atual de cada peça)
--   { [partName] = { current = X, max = Y }, ... }
-- ============================================================

local function applyWearEffects(vehicle, vehicleParts)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    for partName, partState in pairs(vehicleParts) do
        local partDef = Parts.Items[partName]
        if not partDef or not partDef.symptoms then goto continue end

        -- current = km já rodados pela peça | max = durabilidade total
        -- ratio = percentual RESTANTE (0.0–1.0)
        -- resolveActiveSympom ativa quando ratio <= threshold
        -- ex: threshold=0.50 → ativa quando restam <= 50%
        local currentKm = math.floor(partState.current or 0)
        local maxKm     = partState.max or 1
        local ratio     = maxKm > 0 and (1.0 - (currentKm / maxKm)) or 0.0
        if ratio < 0.0 then ratio = 0.0 end

        local symptom = resolveActiveSympom(partDef, ratio)

        if symptom then
            for _, effect in ipairs(symptom.effects) do
                local applier = Appliers[effect.type]
                if applier then
                    applier(vehicle, effect.params, partName)
                end
            end
        else
            stopParticle(partName)
        end

        ::continue::
    end
end

-- ============================================================
--   INTERFACE PÚBLICA — chamada pelo sistema de peças externo
-- ============================================================

-- Inicia o loop de efeitos de desgaste.
-- @param getPartsState function — callback que retorna a tabela de peças atual
--   Formato: { [partName] = { current = km_restante, max = km_total } }
-- Uso: exports["pr_mileage"]:startWearEffects(function() return myPartsTable end)
exports("startWearEffects", function(getPartsState)
    if wearThreadRunning then return end
    wearThreadRunning = true

    CreateThread(function()
        while cache.vehicle do
            Wait(1000)

            if cache.seat ~= -1 then goto continue end
            if not cache.vehicle or not DoesEntityExist(cache.vehicle) then break end

            local parts = getPartsState()
            if parts then
                applyWearEffects(cache.vehicle, parts)
            end

            ::continue::
        end

        clearAllEffects(cache.vehicle)
        wearThreadRunning = false
    end)
end)

-- Para todos os efeitos imediatamente
exports("stopWearEffects", function()
    clearAllEffects(cache.vehicle)
    wearThreadRunning = false
end)

-- Aplica um único efeito manualmente (útil para testes ou outros scripts)
-- @param effectType string — tipo do efeito (ex: "particle", "shake_cam")
-- @param params     table  — parâmetros do efeito
-- @param partName   string — nome da peça (usado como chave de partícula)
exports("applyEffect", function(effectType, params, partName)
    if not cache.vehicle or not DoesEntityExist(cache.vehicle) then return end
    local applier = Appliers[effectType]
    if applier then
        applier(cache.vehicle, params, partName or "manual")
    end
end)

-- Para a partícula de uma peça específica
exports("stopPartParticle", function(partName)
    stopParticle(partName)
end)

-- Retorna a definição de uma peça (sintomas, durabilidade, efeitos)
exports("getPartDefinition", function(partName)
    return Parts.Items[partName]
end)

-- Retorna todas as definições de peças
exports("getAllParts", function()
    return Parts.Items
end)

-- Limpa tudo (ao trocar de veículo, morrer etc)
lib.onCache("vehicle", function(vehicle)
    if not vehicle then
        clearAllEffects(nil)
        wearThreadRunning = false
    end
end)

-- ============================================================
--   HANDLER DO LOOP INTERNO (cl_parts.lua → cl_wear.lua)
--   Converte o formato do cl_parts para o formato esperado
--   por applyWearEffects { current, max } e aplica os efeitos
--   respeitando os toggles de WearConfig.Effects
-- ============================================================

AddEventHandler("pr_mileage:local:applyWear", function(vehicle, allParts)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    -- Aplica com filtro de toggles
    -- FIX: usa math.floor no current_km para ignorar frações de km (os decimais do odômetro
    -- não devem influenciar o desgaste — só km inteiros contam)
    -- FIX: ratio = percentual RESTANTE = 1.0 - (currentKm / durability)
    -- resolveActiveSympom: ativa se ratio <= threshold (ex: restam <= 50%)
    for partName, entry in pairs(allParts) do
        local partDef = Parts.Items[partName]
        if not partDef or not partDef.symptoms then goto continue end

        -- current_km = km já rodados | durability = vida total da peça (ambos inteiros)
        -- ratio = percentual RESTANTE = 1.0 - (rodados / total)
        local currentKm  = math.floor(entry.current_km or 0)
        local durability = math.floor(entry.durability or 1)
        local ratio      = durability > 0 and (1.0 - (currentKm / durability)) or 0.0
        if ratio < 0.0 then ratio = 0.0 end

        print(("[pr_mileage][wear] %s | rodados=%dkm | durability=%dkm | restante=%.1f%%"):format(
            partName, currentKm, durability, ratio * 100))

        local symptom = resolveActiveSympom(partDef, ratio)

        if symptom then
            print(("[pr_mileage][wear] %s → sintoma ATIVO: %s (threshold=%.0f%%)"):format(
                partName, symptom.label or "?", (symptom.threshold or 0) * 100))
            for _, effect in ipairs(symptom.effects) do
                local toggled = WearConfig.Effects[effect.type]
                if toggled ~= false then
                    local applier = Appliers[effect.type]
                    if applier then
                        print(("[pr_mileage][wear] %s → executando efeito: %s"):format(partName, effect.type))
                        applier(vehicle, effect.params, partName)
                    else
                        print(("[pr_mileage][wear] %s → EFEITO SEM APPLIER: %s"):format(partName, effect.type))
                    end
                else
                    print(("[pr_mileage][wear] %s → efeito DESABILITADO em WearConfig: %s"):format(partName, effect.type))
                end
            end
        else
            print(("[pr_mileage][wear] %s → nenhum sintoma ativo (restante=%.1f%%)"):format(partName, ratio * 100))
            stopParticle(partName)
            -- Para o shake da câmera se estava ativo por esta peça
            StopGameplayCamShaking(false)
        end

        ::continue::
    end
end)