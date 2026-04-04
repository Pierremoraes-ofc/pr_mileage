-- ============================================================
--   pr_mileage — PEÇAS E EFEITOS DE DESGASTE
--
--   Cada peça define:
--     durability  → { min, max } KM de vida útil (sorteado ao registrar)
--     symptoms    → lista de sintomas por nível de desgaste
--
--   Cada sintoma tem:
--     threshold   → % de durabilidade restante que ativa (ex: 0.30 = 30%)
--     effects     → lista de efeitos a aplicar (ver tabela de tipos abaixo)
--
--   TIPOS DE EFEITO DISPONÍVEIS:
--   ─────────────────────────────────────────────────────────
--   "particle"         → partícula loopada na entidade (StartParticleFxLoopedOnEntity)
--                        params: { dict, name, bone, scale, offset }
--   "engine_health"    → define saúde do motor
--                        params: { value }         (0–1000)
--   "power_mult"       → multiplicador de potência
--                        params: { value }         (0.0–1.0)
--   "torque_mult"      → multiplicador de torque
--                        params: { value }         (0.0–1.0)
--   "undriveable"      → trava o veículo
--                        params: { value }         (true/false)
--   "engine_on"        → liga/desliga motor
--                        params: { value }         (true/false)
--   "shake_cam"        → vibração de câmera
--                        params: { type, intensity }
--                        type: "ROAD_VIBRATION_SHAKE" | "SMALL_EXPLOSION_SHAKE" | etc.
--   "apply_force"      → aplica força ao veículo (micro trancos)
--                        params: { x, y, z, random } (random=true aplica direção aleatória)
--   "handling_float"   → altera float de handling
--                        params: { field, value }
--   "tyre_burst"       → estoura pneu
--                        params: { wheel }         (0=FL,1=FR,2=RL,3=RR,4=RM,5=LM)
--   "vehicle_lights"   → pisca faróis
--                        params: { state }         (0=off,1=on,2=flash)
--   "indicator"        → pisca seta
--                        params: { left, right }   (true/false)
--   "rpm_override"     → força RPM do motor
--                        params: { value }         (0.0–1.0)
--   "stall"            → stall aleatório (desliga motor brevemente)
--                        params: { chance }        (0.0–1.0, ex: 0.05 = 5% por tick)
--   "steering_scale"   → limita ângulo de direção
--                        params: { value }         (0.0–1.0)
--   "lateral_force"    → força lateral constante (direção desalinhada)
--                        params: { value }         (float, + = direita, - = esquerda)
-- ============================================================

Parts = {}

Parts.Items = {

    -- ──────────────────────────────────────────────────────
    --   🔧 MOTOR
    -- ──────────────────────────────────────────────────────

    ['vela_ignicao'] = {
        durability = { min = 100, max = 100 },
        symptoms   = {
            {
                threshold = 0.50,
                label     = "Falha leve de ignição",
                effects   = {
                    { type = "particle",      params = { dict = "core", name = "ent_sht_steam",        bone = "engine", scale = 0.3 } },
                    { type = "shake_cam",     params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.8 } },
                    { type = "torque_mult",   params = { value = 0.90 } },
                },
            },
            {
                threshold = 0.25,
                label     = "Falha de ignição moderada",
                effects   = {
                    { type = "particle",      params = { dict = "core", name = "ent_amb_smoke_engine",  bone = "engine", scale = 0.9 } },
                    { type = "shake_cam",     params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.08 } },
                    { type = "torque_mult",   params = { value = 0.70 } },
                    { type = "power_mult",    params = { value = 0.80 } },
                    { type = "stall",         params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Falha crítica de ignição",
                effects   = {
                    { type = "particle",      params = { dict = "core", name = "ent_sht_flame",         bone = "engine", scale = 0.8 } },
                    { type = "shake_cam",     params = { type = "SMALL_EXPLOSION_SHAKE", intensity = 0.15 } },
                    { type = "engine_health", params = { value = 300 } },
                    { type = "torque_mult",   params = { value = 0.40 } },
                    { type = "power_mult",    params = { value = 0.40 } },
                    { type = "stall",         params = { chance = 0.08 } },
                },
            },
        },
    },
    ['turbo_garret_1'] = {
        durability = { min = 15000, max = 30000 },
        symptoms   = {
            {
                threshold = 0.50,
                label     = "Falha leve de ignição",
                effects   = {
                    { type = "particle",      params = { dict = "core", name = "ent_sht_steam",        bone = "engine", scale = 0.3 } },
                    { type = "shake_cam",     params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.03 } },
                    { type = "torque_mult",   params = { value = 0.90 } },
                },
            },
            {
                threshold = 0.25,
                label     = "Falha de ignição moderada",
                effects   = {
                    { type = "particle",      params = { dict = "core", name = "ent_amb_smoke_engine",  bone = "engine", scale = 0.5 } },
                    { type = "shake_cam",     params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.08 } },
                    { type = "torque_mult",   params = { value = 0.70 } },
                    { type = "power_mult",    params = { value = 0.80 } },
                    { type = "stall",         params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Falha crítica de ignição",
                effects   = {
                    { type = "particle",      params = { dict = "core", name = "ent_sht_flame",         bone = "engine", scale = 0.8 } },
                    { type = "shake_cam",     params = { type = "SMALL_EXPLOSION_SHAKE", intensity = 0.15 } },
                    { type = "engine_health", params = { value = 300 } },
                    { type = "torque_mult",   params = { value = 0.40 } },
                    { type = "power_mult",    params = { value = 0.40 } },
                    { type = "stall",         params = { chance = 0.08 } },
                },
            },
        },
    },

    ['bobina'] = {
        durability = { min = 20000, max = 40000 },
        symptoms   = {
            {
                threshold = 0.50,
                label     = "Bobina fraca",
                effects   = {
                    { type = "particle",    params = { dict = "core", name = "ent_sht_steam",       bone = "engine", scale = 0.2 } },
                    { type = "torque_mult", params = { value = 0.92 } },
                },
            },
            {
                threshold = 0.25,
                label     = "Bobina degradada",
                effects   = {
                    { type = "particle",    params = { dict = "core", name = "ent_amb_smoke_engine", bone = "engine", scale = 0.4 } },
                    { type = "torque_mult", params = { value = 0.72 } },
                    { type = "power_mult",  params = { value = 0.82 } },
                    { type = "stall",       params = { chance = 0.03 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Bobina falhando",
                effects   = {
                    { type = "particle",      params = { dict = "core", name = "ent_sht_flame",      bone = "engine", scale = 0.6 } },
                    { type = "engine_health", params = { value = 400 } },
                    { type = "torque_mult",   params = { value = 0.45 } },
                    { type = "power_mult",    params = { value = 0.45 } },
                    { type = "stall",         params = { chance = 0.10 } },
                },
            },
        },
    },

    ['cabo_vela'] = {
        durability = { min = 25000, max = 50000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Perda leve de ignição",
                effects   = {
                    { type = "torque_mult", params = { value = 0.88 } },
                    { type = "stall",       params = { chance = 0.01 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Cabo deteriorado",
                effects   = {
                    { type = "particle",    params = { dict = "core", name = "ent_sht_steam",       bone = "engine", scale = 0.3 } },
                    { type = "torque_mult", params = { value = 0.65 } },
                    { type = "power_mult",  params = { value = 0.75 } },
                    { type = "stall",       params = { chance = 0.06 } },
                },
            },
        },
    },

    ['junta_cabecote'] = {
        durability = { min = 60000, max = 120000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Superaquecimento leve",
                effects   = {
                    { type = "particle",    params = { dict = "core", name = "ent_sht_steam",        bone = "bonnet", scale = 0.5 } },
                    { type = "power_mult",  params = { value = 0.88 } },
                },
            },
            {
                threshold = 0.20,
                label     = "Superaquecimento moderado",
                effects   = {
                    { type = "particle",      params = { dict = "core", name = "ent_amb_smoke_engine", bone = "bonnet", scale = 0.9 } },
                    { type = "engine_health", params = { value = 500 } },
                    { type = "power_mult",    params = { value = 0.65 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Motor superaquecido crítico",
                effects   = {
                    { type = "particle",      params = { dict = "core", name = "ent_sht_flame",       bone = "bonnet", scale = 1.2 } },
                    { type = "engine_health", params = { value = 200 } },
                    { type = "power_mult",    params = { value = 0.30 } },
                    { type = "undriveable",   params = { value = true } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   🛢️ FLUIDOS
    -- ──────────────────────────────────────────────────────

    ['oil'] = {
        durability = { min = 8000, max = 15000 },
        symptoms   = {
            {
                threshold = 0.50,
                label     = "Óleo degradado",
                effects   = {
                    { type = "particle",    params = { dict = "core", name = "veh_backfire",          bone = "exhaust", scale = 0.3 } },
                    { type = "power_mult",  params = { value = 0.93 } },
                },
            },
            {
                threshold = 0.25,
                label     = "Óleo queimando",
                effects   = {
                    { type = "particle",    params = { dict = "core", name = "ent_amb_exhaust_smoke",  bone = "exhaust", scale = 0.7 } },
                    { type = "power_mult",  params = { value = 0.75 } },
                    { type = "torque_mult", params = { value = 0.80 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Sem óleo — motor destruindo",
                effects   = {
                    { type = "particle",      params = { dict = "core", name = "ent_sht_flame",       bone = "exhaust", scale = 1.0 } },
                    { type = "engine_health", params = { value = 150 } },
                    { type = "power_mult",    params = { value = 0.20 } },
                    { type = "stall",         params = { chance = 0.15 } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   ⚙️ TRANSMISSÃO
    -- ──────────────────────────────────────────────────────

    ['embreagem'] = {
        durability = { min = 40000, max = 80000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Embreagem patinando levemente",
                effects   = {
                    { type = "torque_mult",  params = { value = 0.85 } },
                    { type = "shake_cam",    params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.02 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Embreagem desgastada",
                effects   = {
                    { type = "torque_mult",  params = { value = 0.60 } },
                    { type = "power_mult",   params = { value = 0.70 } },
                    { type = "shake_cam",    params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.06 } },
                    { type = "apply_force",  params = { x = 0.0, y = 0.0, z = 0.0, random = true, intensity = 0.5 } },
                },
            },
        },
    },

    ['caixa_cambio'] = {
        durability = { min = 60000, max = 120000 },
        symptoms   = {
            {
                threshold = 0.30,
                label     = "Caixa com folga",
                effects   = {
                    { type = "shake_cam",   params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.04 } },
                    { type = "apply_force", params = { x = 0.0, y = 0.0, z = 0.0, random = true, intensity = 0.3 } },
                },
            },
            {
                threshold = 0.10,
                label     = "Caixa danificada",
                effects   = {
                    { type = "shake_cam",   params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.10 } },
                    { type = "apply_force", params = { x = 0.0, y = 0.0, z = 0.0, random = true, intensity = 1.0 } },
                    { type = "torque_mult", params = { value = 0.55 } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   🛞 PNEUS
    -- ──────────────────────────────────────────────────────

    ['tire_street'] = {
        durability = { min = 20000, max = 50000 },
        wheel      = 0,
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Pneu murcho (dianteiro esq)",
                effects   = {
                    { type = "handling_float", params = { field = "fTractionLossMult", value = 1.4 } },
                    { type = "shake_cam",      params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.03 } },
                },
            },
            {
                threshold = 0.10,
                label     = "Pneu furado (dianteiro esq)",
                effects   = {
                    { type = "tyre_burst",     params = { wheel = 0 } },
                },
            },
        },
    },

    ['tire_sport'] = {
        durability = { min = 20000, max = 50000 },
        wheel      = 1,
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Pneu murcho (dianteiro dir)",
                effects   = {
                    { type = "handling_float", params = { field = "fTractionLossMult", value = 1.4 } },
                    { type = "shake_cam",      params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.03 } },
                },
            },
            {
                threshold = 0.10,
                label     = "Pneu furado (dianteiro dir)",
                effects   = {
                    { type = "tyre_burst", params = { wheel = 1 } },
                },
            },
        },
    },

    ['tire_race'] = {
        durability = { min = 20000, max = 50000 },
        wheel      = 2,
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Pneu murcho (traseiro esq)",
                effects   = {
                    { type = "handling_float", params = { field = "fTractionLossMult", value = 1.3 } },
                },
            },
            {
                threshold = 0.10,
                label     = "Pneu furado (traseiro esq)",
                effects   = {
                    { type = "tyre_burst", params = { wheel = 2 } },
                },
            },
        },
    },

    ['tire_semislick'] = {
        durability = { min = 20000, max = 50000 },
        wheel      = 3,
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Pneu murcho (traseiro dir)",
                effects   = {
                    { type = "handling_float", params = { field = "fTractionLossMult", value = 1.3 } },
                },
            },
            {
                threshold = 0.10,
                label     = "Pneu furado (traseiro dir)",
                effects   = {
                    { type = "tyre_burst", params = { wheel = 3 } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   🛠️ SUSPENSÃO
    -- ──────────────────────────────────────────────────────

    ['amortecedor_dianteiro'] = {
        durability = { min = 30000, max = 70000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Amortecedor fraco",
                effects   = {
                    { type = "handling_float", params = { field = "fSuspensionReboundDamp", value = 0.3 } },
                    { type = "shake_cam",      params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.04 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Amortecedor crítico",
                effects   = {
                    { type = "handling_float", params = { field = "fSuspensionReboundDamp", value = 0.1 } },
                    { type = "handling_float", params = { field = "fSuspensionCompDamp",    value = 0.1 } },
                    { type = "shake_cam",      params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.12 } },
                },
            },
        },
    },

    ['amortecedor_traseiro'] = {
        durability = { min = 30000, max = 70000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Amortecedor traseiro fraco",
                effects   = {
                    { type = "handling_float", params = { field = "fSuspensionReboundDamp", value = 0.35 } },
                    { type = "shake_cam",      params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.03 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Amortecedor traseiro crítico",
                effects   = {
                    { type = "handling_float", params = { field = "fSuspensionReboundDamp", value = 0.12 } },
                    { type = "shake_cam",      params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.10 } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   🛑 FREIOS
    -- ──────────────────────────────────────────────────────

    ['brake_level_1'] = {
        durability = { min = 15000, max = 30000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Freio desgastado",
                effects   = {
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.65 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Freio superaquecido",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = "wheel_lf", scale = 0.4 } },
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.35 } },
                },
            },
            {
                threshold = 0.03,
                label     = "Sem freio",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = "wheel_lf", scale = 0.8 } },
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.10 } },
                },
            },
        },
    },
    ['brake_level_2'] = {
        durability = { min = 15000, max = 30000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Freio desgastado",
                effects   = {
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.65 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Freio superaquecido",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = "wheel_lf", scale = 0.4 } },
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.35 } },
                },
            },
            {
                threshold = 0.03,
                label     = "Sem freio",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = "wheel_lf", scale = 0.8 } },
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.10 } },
                },
            },
        },
    },
    ['brake_level_3'] = {
        durability = { min = 15000, max = 30000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Freio desgastado",
                effects   = {
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.65 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Freio superaquecido",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = "wheel_lf", scale = 0.4 } },
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.35 } },
                },
            },
            {
                threshold = 0.03,
                label     = "Sem freio",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = "wheel_lf", scale = 0.8 } },
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.10 } },
                },
            },
        },
    },
    ['brake_level_4'] = {
        durability = { min = 15000, max = 30000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Freio desgastado",
                effects   = {
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.65 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Freio superaquecido",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = "wheel_lf", scale = 0.4 } },
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.35 } },
                },
            },
            {
                threshold = 0.03,
                label     = "Sem freio",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = "wheel_lf", scale = 0.8 } },
                    { type = "handling_float", params = { field = "fBrakeForce", value = 0.10 } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   🔋 ELÉTRICA
    -- ──────────────────────────────────────────────────────

    ['bateria'] = {
        durability = { min = 20000, max = 60000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Bateria fraca",
                effects   = {
                    { type = "vehicle_lights", params = { state = 2 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Bateria crítica",
                effects   = {
                    { type = "vehicle_lights", params = { state = 2 } },
                    { type = "stall",          params = { chance = 0.04 } },
                },
            },
            {
                threshold = 0.03,
                label     = "Sem bateria",
                effects   = {
                    { type = "engine_on",      params = { value = false } },
                    { type = "vehicle_lights", params = { state = 0 } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   🧭 DIREÇÃO
    -- ──────────────────────────────────────────────────────

    ['direcao'] = {
        durability = { min = 50000, max = 100000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Direção vibrando",
                effects   = {
                    { type = "shake_cam",     params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.05 } },
                    { type = "lateral_force", params = { value = 0.2 } },
                },
            },
            {
                threshold = 0.20,
                label     = "Direção desalinhada",
                effects   = {
                    { type = "shake_cam",       params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.10 } },
                    { type = "lateral_force",   params = { value = 0.6 } },
                    { type = "steering_scale",  params = { value = 0.75 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Direção danificada",
                effects   = {
                    { type = "shake_cam",      params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.18 } },
                    { type = "lateral_force",  params = { value = 1.2 } },
                    { type = "steering_scale", params = { value = 0.50 } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   ⛽ INJEÇÃO / COMBUSTÍVEL
    -- ──────────────────────────────────────────────────────

    ['filtro_combustivel'] = {
        durability = { min = 20000, max = 40000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Filtro sujo — resposta lenta",
                effects   = {
                    { type = "torque_mult", params = { value = 0.85 } },
                    { type = "power_mult",  params = { value = 0.90 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Filtro entupido — injeção falhando",
                effects   = {
                    { type = "torque_mult", params = { value = 0.60 } },
                    { type = "power_mult",  params = { value = 0.65 } },
                    { type = "stall",       params = { chance = 0.04 } },
                },
            },
        },
    },

    ['bico_injetor'] = {
        durability = { min = 30000, max = 60000 },
        symptoms   = {
            {
                threshold = 0.40,
                label     = "Injeção suja",
                effects   = {
                    { type = "torque_mult", params = { value = 0.88 } },
                    { type = "power_mult",  params = { value = 0.88 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Injetor falhando",
                effects   = {
                    { type = "torque_mult", params = { value = 0.60 } },
                    { type = "power_mult",  params = { value = 0.62 } },
                    { type = "stall",       params = { chance = 0.05 } },
                    { type = "shake_cam",   params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.05 } },
                },
            },
        },
    },
}