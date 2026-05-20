-- ============================================================
--   pr_mileage — MOTOR DE EFEITOS DE DESGASTE
--   Lê Parts.Items e aplica efeitos baseados na durabilidade
--   restante de cada peça
-- ============================================================

local activeParticles   = {}   -- { [partName] = handle }
local activeEffects     = {}   -- { [partName] = { type, ... } } efeitos persistentes ativos
local wearThreadRunning = false
local originalHandling  = {}   -- valores originais do handling do veículo atual

-- Controle de estado para efeitos que sincronizam pela rede
local engineOnState    = nil
local rpmOverrideState = nil
local stallingActive   = false

-- Controle de estado do handling — evita SetVehicleHandlingFloat a cada tick
local handlingApplied  = false  -- true = handling degradado está ativo
local lastSymptomKey   = {}     -- { [partName] = symptom.label } último sintoma por peça

-- ============================================================
--   UTILITÁRIOS INTERNOS
-- ============================================================
local function toGameSpeed(unitSpeed)
    -- unitSpeed vem em KM/H ou MPH dependendo da config

    if Config.Unit == "miles" then
        -- MPH -> m/s
        return unitSpeed / 2.236936
    end

    -- KM/H -> m/s
    return unitSpeed / 3.6
end


-- Captura os valores originais do handling ao entrar no veículo
-- Spawna um clone local temporário (invisível, sem colisão, sem rede) para ler os valores originais
local function captureOriginalHandling(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local model = GetEntityModel(vehicle)

    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 3000 do
        Wait(100)
        timeout = timeout + 100
    end
    if not HasModelLoaded(model) then return end

    -- false, false = não é missão, não é rede (local only — nenhum player vê)
    local tempVeh = CreateVehicle(model, 0.0, 0.0, -1000.0, 0.0, false, false)

    if tempVeh and DoesEntityExist(tempVeh) then
        SetEntityVisible(tempVeh, false, false)
        SetEntityCollision(tempVeh, false, false)

        originalHandling = {
            fSuspensionForce       = GetVehicleHandlingFloat(tempVeh, "CHandlingData", "fSuspensionForce"),
            fSuspensionReboundDamp = GetVehicleHandlingFloat(tempVeh, "CHandlingData", "fSuspensionReboundDamp"),
            fSuspensionCompDamp    = GetVehicleHandlingFloat(tempVeh, "CHandlingData", "fSuspensionCompDamp"),
            fTractionLossMult      = GetVehicleHandlingFloat(tempVeh, "CHandlingData", "fTractionLossMult"),
            fBrakeForce            = GetVehicleHandlingFloat(tempVeh, "CHandlingData", "fBrakeForce"),
            fDriveInertia          = GetVehicleHandlingFloat(tempVeh, "CHandlingData", "fDriveInertia"),
            fSuspensionRaise       = GetVehicleHandlingFloat(tempVeh, "CHandlingData", "fSuspensionRaise"),
            fSuspensionUpperLimit  = GetVehicleHandlingFloat(tempVeh, "CHandlingData", "fSuspensionUpperLimit"),
            fSuspensionLowerLimit  = GetVehicleHandlingFloat(tempVeh, "CHandlingData", "fSuspensionLowerLimit"),
        }

        DeleteVehicle(tempVeh)
    end

    SetModelAsNoLongerNeeded(model)
end

-- ============================================================
--   APLICADORES DE EFEITO
--   Cada função recebe (vehicle, params) e aplica o efeito
-- ============================================================

local Appliers = {}

-- Partícula loopada na entidade
Appliers["particle"] = function(vehicle, params, partName)
    if activeParticles[partName] then return end
    --print(("[pr_mileage][particle] Iniciando: part=%s | dict=%s | name=%s"):format(partName, params.dict or "?", params.name or "?"))

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

-- Multiplicador de potência — só aplica se mudou
Appliers["power_mult"] = function(vehicle, params)
    local current = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce")
    -- SetVehicleCheatPowerIncrease não tem getter, usa estado local
    if not Appliers._powerState then Appliers._powerState = 1.0 end
    if math.abs(Appliers._powerState - params.value) < 0.001 then return end
    Appliers._powerState = params.value
    Exported.powerMult(vehicle, params)
end

-- Multiplicador de torque — só aplica se mudou
Appliers["torque_mult"] = function(vehicle, params)
    local current = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia")
    if math.abs(current - params.value) < 0.001 then return end
    Exported.torqueMult(vehicle, params)
end

-- Veículo inoperante
Appliers["undriveable"] = function(vehicle, params)
    SetVehicleUndriveable(vehicle, params.value)
end

-- Liga/desliga motor — só aplica se o estado mudou (evita sync de rede a cada tick)
Appliers["engine_on"] = function(vehicle, params)
    local desired = params.value
    if engineOnState == desired then return end  -- estado não mudou, não sincroniza
    engineOnState = desired
    SetVehicleEngineOn(vehicle, desired, true, true)
end

-- Vibração de câmera persistente
-- ShakeGameplayCam inicia o shake mas para sozinho após alguns frames
-- A combinação correta é: iniciar com ShakeGameplayCam e manter com SetGameplayCamShakeAmplitude
-- IsGameplayCamShaking verifica se já está ativo para não reiniciar desnecessariamente
Appliers["shake_cam"] = function(vehicle, params)
    local speed = GetEntitySpeed(vehicle)
    
    -- converte params.speed para velocidade interna do GTA
    local minSpeed = toGameSpeed(params.speed)
    if speed < minSpeed then return end  -- só aplica acima do km definido em param.speed
    local shakeType = params.type or "ROAD_VIBRATION_SHAKE"
    local intensity = params.intensity or 0.05
    if not IsGameplayCamShaking() then
        ShakeGameplayCam(shakeType, intensity)
    end
    SetGameplayCamShakeAmplitude(intensity)
end

-- Aplica força ao veículo (micro trancos) — só aplica se este client tem controle do veículo
Appliers["apply_force"] = function(vehicle, params)
    -- Só aplica se este client é o dono da entidade (evita sync para outros players)
    if not NetworkHasControlOfEntity(vehicle) then return end
    -- Só aplica se o player está no banco do motorista
    if cache.seat ~= -1 then return end
    local speed = GetEntitySpeed(vehicle)
    
    -- converte params.speed para velocidade interna do GTA
    local minSpeed = toGameSpeed(params.speed)
    if speed < minSpeed then return end  -- só aplica acima do km definido em param.speed
    local x, y, z = params.x or 0.0, params.y or 0.0, params.z or 0.0
    local intensity = params.intensity or 0.5
    if params.random then
        x = (math.random() - 0.5) * intensity
        y = (math.random() - 0.5) * intensity
    end
    ApplyForceToEntity(vehicle, 1, x, y, z, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
end

-- Altera float de handling — aplica a partir de 10 km/h (2.78 m/s)
Appliers["handling_float"] = function(vehicle, params)
    local speed = GetEntitySpeed(vehicle)
    
    -- converte params.speed para velocidade interna do GTA
    local minSpeed = toGameSpeed(params.speed)
    if speed < minSpeed then return end  -- só aplica acima do km definido em param.speed
    local current = GetVehicleHandlingFloat(vehicle, "CHandlingData", params.field)
    if math.abs(current - params.value) < 0.001 then return end
    Exported.handlingFloat(vehicle, params)
end

-- Estoura pneu
Appliers["tyre_burst"] = function(vehicle, params)
    local wheel = params.wheel
    if wheel == nil then
        wheel = math.random(0, 3)
    end
    if not IsVehicleTyreBurst(vehicle, wheel, false) then
        SetVehicleTyreBurst(vehicle, wheel, true, 1000.0)
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

-- Força RPM — só aplica se o valor mudou (evita sync de rede a cada tick)
Appliers["rpm_override"] = function(vehicle, params)
    local desired = params.value
    if rpmOverrideState == desired then return end  -- valor não mudou
    rpmOverrideState = desired
    Exported.rpmOverride(vehicle, params)
end

-- Stall aleatório — só executa se não há stall em andamento (evita stalls simultâneos)
Appliers["stall"] = function(vehicle, params)
    if stallingActive then return end  -- já está em stall, não inicia outro
    local chance = params.chance or 0.05
    if math.random() < chance then
        stallingActive = true
        SetVehicleEngineOn(vehicle, false, true, true)
        Wait(math.random(800, 2000))
        if DoesEntityExist(vehicle) then
            SetVehicleEngineOn(vehicle, true, true, true)
        end
        stallingActive = false
    end
end

-- Limita ângulo de direção
Appliers["steering_scale"] = function(vehicle, params)
    SetVehicleSteeringScale(vehicle, params.value)
end

-- Força lateral constante (direção desalinhada) — só aplica se tem controle do veículo
Appliers["lateral_force"] = function(vehicle, params)
    if not NetworkHasControlOfEntity(vehicle) then return end
    -- Só aplica se o player está no banco do motorista
    if cache.seat ~= -1 then return end
    local speed = GetEntitySpeed(vehicle)
    
    -- converte params.speed para velocidade interna do GTA
    local minSpeed = toGameSpeed(params.speed)
    if speed < minSpeed then return end  -- só aplica acima do km definido em param.speed
    ApplyForceToEntity(vehicle, 1, params.value or 0.3, 0.0, 0.0,
        0.0, 0.0, 0.0, 0, false, true, true, false, true)
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
        -- Só ativa efeitos quando a peça está RUIM (threshold < 0.30)
        -- Peça boa/razoável (>= 30% restante) = sem efeitos
        if ratio <= symptom.threshold and symptom.threshold < 0.30 then
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

    -- Reseta TODOS os efeitos físicos
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleCheatPowerIncrease(vehicle, 1.0)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleSteeringScale(vehicle, 1.0)  -- reseta direção
        
        Exported.setOriginalHandling(vehicle, originalHandling)
    end
    -- Para o shake da câmera
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
local lastVehicleRef = nil

lib.onCache("vehicle", function(vehicle)
    if not vehicle then
        -- Reseta handling diretamente no veículo antes de ele sumir
        if lastVehicleRef and DoesEntityExist(lastVehicleRef) then

            Exported.setOriginalHandling(lastVehicleRef, originalHandling)

            SetVehicleSteeringScale(lastVehicleRef, 1.0)
            SetVehicleCheatPowerIncrease(lastVehicleRef, 1.0)
            SetVehicleUndriveable(lastVehicleRef, false)
        end
        clearAllEffects(lastVehicleRef)
        lastVehicleRef   = nil
        originalHandling = {}
        wearThreadRunning = false
        engineOnState    = nil
        rpmOverrideState = nil
        stallingActive   = false
        lastSymptomKey   = {}
        handlingApplied  = false
        StopGameplayCamShaking(true)
    else
        lastVehicleRef = vehicle
        -- Captura valores originais imediatamente ao entrar no veículo
        CreateThread(function()
            captureOriginalHandling(vehicle)
        end)
        -- Reseta estados de controle para forçar reavaliação das peças
        engineOnState    = nil
        rpmOverrideState = nil
        lastSymptomKey   = {}
        -- Garante que o veículo está funcional ao entrar (reseta efeitos residuais)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineHealth(vehicle, 1000.0)
        -- Repara pneus fisicamente (o loop vai estourar de novo se a peça estiver ruim)
        for _, idx in ipairs({0,1,2,3,4,5,45,47}) do
            SetVehicleTyreFixed(vehicle, idx)
        end
    end
end)

-- Reset imediato ao instalar peça nova
AddEventHandler("pr_mileage:local:resetHandling", function(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    StopGameplayCamShaking(true)
    SetVehicleUndriveable(vehicle, false)
    -- Religa o motor se o player está no banco do motorista
    if cache.seat == -1 then
        SetVehicleEngineOn(vehicle, true, false, true)
    end
    engineOnState = nil  -- reseta o estado para reaplicar se necessário
    SetVehicleSteeringScale(vehicle, 1.0)
    SetVehicleCheatPowerIncrease(vehicle, 1.0)

    Exported.resetPartsInstalled(vehicle, originalHandling)

    for partName, _ in pairs(activeParticles) do
        stopParticle(partName)
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

        --print(("[pr_mileage][wear] %s | rodados=%dkm | durability=%dkm | restante=%.1f%%"):format(partName, currentKm, durability, ratio * 100))

        local symptom = resolveActiveSympom(partDef, ratio)

        if symptom then
            -- Atualiza o rastreamento do sintoma ativo
            lastSymptomKey[partName] = symptom.label or "?"
            -- Aplica os efeitos a cada tick (necessário para stall, shake_cam, etc.)
            for _, effect in ipairs(symptom.effects) do
                local toggled = WearConfig.Effects[effect.type]
                if toggled ~= false then
                    local applier = Appliers[effect.type]
                    if applier then
                        applier(vehicle, effect.params, partName)
                    else
                        print(("[pr_mileage][wear] %s → EFEITO SEM APPLIER: %s"):format(partName, effect.type))
                    end
                end
            end
        else
            -- Peça está boa — só reseta se havia sintoma ativo antes
            if lastSymptomKey[partName] then
                lastSymptomKey[partName] = nil
                stopParticle(partName)
                if vehicle and DoesEntityExist(vehicle) then
                    
                    Exported.resetPartsInstalled(vehicle, originalHandling)
                    
                    SetVehicleCheatPowerIncrease(vehicle, 1.0)
                    SetVehicleSteeringScale(vehicle, 1.0)
                    SetVehicleUndriveable(vehicle, false)
                    -- Religa o motor se estava desligado por efeito de peça ruim
                    if engineOnState == false then
                        engineOnState = nil
                        if cache.seat == -1 then
                            SetVehicleEngineOn(vehicle, true, false, true)
                        end
                    end
                    local tyreParts = {tire_common=true,tire_street=true,tire_sport=true,tire_race=true,tire_semislick=true,tire_slick=true,tire_drift=true,tire_touring=true}
                    if tyreParts[partName] then
                        for _, idx in ipairs({0,1,2,3,4,5,45,47}) do
                            SetVehicleTyreFixed(vehicle, idx)
                        end
                    end
                end
                StopGameplayCamShaking(false)
            end
        end

        ::continue::
    end
end)