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
--  @param              → params                - tabela de parâmetros
--  @param              → params.dict           - diretorio do efeito particula
--  @param              → params.name           - nome da particula
--  @param              → params.bone           - osso do veiculo
--  @param              → params.scale          - tamanho do efeito
--  "particle"          → partícula loopada na entidade

--   @param             → params                - tabela de parâmetros
--   @param             → params                - tabela de parâmetros
--  "engine_health"     → define saúde do motor (0–1000)

--   @param             → params                - tabela de parâmetros
--   @param             → params.value          - define o valor para alterar a performance de força entre 0.0 e 1.0
--  "power_mult"        → multiplicador de potência (0.0–1.0)

--   @param             → params                - tabela de parâmetros
--   @param             → params.value          - define o valor para alterar a performance de torque entre 0.0 e 1.0
--  "torque_mult"       → multiplicador de torque (0.0–1.0)

--   @param             → params                - tabela de parâmetros
--   @param             → params.value          - Define true ou false para dirigir ou não
--  "undriveable"       → trava o veículo (true/false)

--   @param             → params                - tabela de parâmetros
--   @param             → params.value          - Define true ou false para ligar e desligar motor
--  "engine_on"         → liga/desliga motor (true/false)

--   @param             → params                - tabela de parâmetros
--   @param             → params.type           - tipo de efeito da camera
--   @param             → params.intensity      - intensidade do balanço da camera
--   @param             → params.speed          - a partir de qual velocidade
--   "shake_cam"        → vibração de câmera

--  @param              → params                - tabela de parâmetros
--  @param              → params.random         - randomiza a intensidade de efeitos
--  @param              → params.speed          - determina a partir de qual velocidade os efeitos começam
--  @param              → params.intensity      - define uma intensidade padrão para o efeito
--  "apply_force"       → aplica força ao veículo

--  @param              → params                - tabela de parâmetros
--  @param              → params.field          - determina nome do efeito aplicado na handling ex: "fSuspensionReboundDamp", "fBrakeForce", "fTractionLossMult"
--  @param              → params.speed          - determina a partir de qual velocidade os efeitos começam
--  @param              → params.value          - define o valor entre 0.0 e 1.0
--  "handling_float"    → altera float de handling

--  @param              → params                - tabela de parâmetros
--  @param              → params.state          - define a luz ( 0=off, 1=on, 2=flash )
--  "vehicle_lights"    → pisca faróis

--  @param              → params                - tabela de parâmetros
--  @param              → params.left           - Define a luz acesa esquerda true|false
--  @param              → params.right          - Define a luz acesa direita true|false
--  "indicator"         → pisca seta

--  @param              → params                - tabela de parâmetros
--  @param              → params.value          - define o valor entre 0.0 e 1.0
--  "rpm_override"      → força RPM do motor

--  @param              → params                - tabela de parâmetros
--  @param              → params.chance         - define o percentual de chance de executar
--  "stall"             → stall aleatório probabilidade de religar motor (sensasão de morrer e ligar)

--  @param              → params                - tabela de parâmetros
--  @param              → params.value          - define o valor de angulo máximo da roda
--  "steering_scale"    → limita ângulo de direção

--  @param              → params                - tabela de parâmetros
--  @param              → params.value          - define o valor da força aplicada
--  "lateral_force"     → força lateral constante

--  @param              → params                - tabela de parâmetros
--  @param              → params.wheel          - define a roda a ser aplicada efeito 
--  nil = randomiza a roda
--  0   = dianteira esquerda | dianteira de bicicleta, avião ou jato
--  1   = dianteira direita
--  2   = traseira esquerda | em reboque de 6 rodas, avião ou jato é a primeira à esquerda
--  3   = traseira direita | em reboque de 6 rodas, avião ou jato é a primeira à direita
--  4   = traseira de bicicleta | em reboque de 6 rodas, avião ou jato é a última à esquerda
--  5   = em reboque de 6 rodas, avião ou jato é a última à direita 
--  45  = roda central esquerda de reboque de 6 rodas
--  47  = roda central direita de reboque de 6 rodas
--  "tyre_burst"        → estoura pneu
-- ============================================================

Parts = {}


Parts.VehicleBones = {
    -- ============================================================
    -- Estrutura
    -- ============================================================
    carroceria            = "chassis",
    carroceria_dummy      = "chassis_dummy",
    casco                 = "bodyshell",

    -- ============================================================
    -- Motor / transmissão
    -- ============================================================
    motor                 = "engine",
    transmissao_frontal   = "transmission_f",
    transmissao_traseira  = "transmission_r",

    -- ============================================================
    -- Capô / porta malas
    -- ============================================================
    capo                  = "bonnet",
    porta_malas           = "boot",

    -- ============================================================
    -- Rodas
    -- ============================================================
    roda_dianteira_esquerda = "wheel_lf",
    roda_dianteira_direita  = "wheel_rf",
    roda_traseira_esquerda  = "wheel_lr",
    roda_traseira_direita   = "wheel_rr",

    roda_meio_esquerda_1    = "wheel_lm1",
    roda_meio_direita_1     = "wheel_rm1",
    roda_meio_esquerda_2    = "wheel_lm2",
    roda_meio_direita_2     = "wheel_rm2",

    -- ============================================================
    -- Suspensão
    -- ============================================================
    suspensao_dianteira_esquerda = "suspension_lf",
    suspensao_dianteira_direita  = "suspension_rf",
    suspensao_traseira_esquerda  = "suspension_lr",
    suspensao_traseira_direita   = "suspension_rr",

    -- ============================================================
    -- Portas
    -- ============================================================
    porta_motorista_dianteira = "door_dside_f",
    porta_motorista_traseira  = "door_dside_r",

    porta_passageiro_dianteira = "door_pside_f",
    porta_passageiro_traseira  = "door_pside_r",

    -- ============================================================
    -- Bancos
    -- ============================================================
    banco_motorista_dianteiro = "seat_dside_f",
    banco_passageiro_dianteiro = "seat_pside_f",

    banco_motorista_traseiro = "seat_dside_r",
    banco_passageiro_traseiro = "seat_pside_r",

    -- ============================================================
    -- Faróis
    -- ============================================================
    farol_dianteiro_esquerdo = "headlight_l",
    farol_dianteiro_direito  = "headlight_r",

    lanterna_esquerda = "taillight_l",
    lanterna_direita  = "taillight_r",

    luz_freio_esquerda = "brakelight_l",
    luz_freio_direita  = "brakelight_r",

    -- ============================================================
    -- Escape
    -- ============================================================
    escape      = "exhaust",
    escape_2    = "exhaust_2",
    escape_3    = "exhaust_3",

    -- ============================================================
    -- Vidros
    -- ============================================================
    vidro_dianteiro_esquerdo = "window_lf",
    vidro_dianteiro_direito  = "window_rf",

    vidro_traseiro_esquerdo = "window_lr",
    vidro_traseiro_direito  = "window_rr",

    para_brisa = "windscreen",

    -- ============================================================
    -- Combustível
    -- ============================================================
    tanque = "petrolcap",

    -- ============================================================
    -- Volante
    -- ============================================================
    volante = "steeringwheel",

    -- ============================================================
    -- Neon
    -- ============================================================
    neon_esquerdo = "neon_l",
    neon_direito  = "neon_r",
    neon_frontal  = "neon_f",
    neon_traseiro = "neon_b",
}

Parts.Items = {

    -- ──────────────────────────────────────────────────────
    --   🔧 SENSORES
    -- ──────────────────────────────────────────────────────
    ['sensor_maf'] = {
        durability = { min = 300, max = 360 },
        labelItem = 'Sensor MAF',
        symptoms = {
            {
                threshold = 0.40,
                label = "Leitura imprecisa do fluxo de ar",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor MAF degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor MAF falhando",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_map'] = {
        durability = { min = 360, max = 430 },
        labelItem = 'Sensor MAP',
        symptoms = {
            {
                threshold = 0.40,
                label = "Leitura imprecisa de pressão",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor MAP degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor MAP crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_iat'] = {
        durability = { min = 430, max = 510 },
        labelItem = 'Sensor IAT',
        symptoms = {
            {
                threshold = 0.40,
                label = "Leitura incorreta de temperatura",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor IAT degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.35 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor IAT falhando",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.55 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_tps'] = {
        durability = { min = 510, max = 590 },
        labelItem = 'Sensor TPS',
        symptoms = {
            {
                threshold = 0.40,
                label = "Resposta lenta do acelerador",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor TPS degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor TPS crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.5 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_app'] = {
        durability = { min = 590, max = 670 },
        labelItem = 'Sensor APP',
        symptoms = {
            {
                threshold = 0.40,
                label = "Pedal com resposta irregular",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor APP degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor APP falhando",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_ckp'] = {
        durability = { min = 670, max = 750 },
        labelItem = 'Sensor CKP',
        symptoms = {
            {
                threshold = 0.40,
                label = "Leitura irregular do virabrequim",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.08 } },
                    { type = "stall", params = { chance = 0.04 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor CKP degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.5 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.15 } },
                    { type = "stall", params = { chance = 0.10 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor CKP crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.25 } },
                    { type = "stall", params = { chance = 0.30 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_cmp'] = {
        durability = { min = 750, max = 830 },
        labelItem = 'Sensor CMP',
        symptoms = {
            {
                threshold = 0.40,
                label = "Sincronismo irregular",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor CMP degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.45 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor CMP crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.65 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_knock'] = {
        durability = { min = 830, max = 910 },
        labelItem = 'Sensor de Detonação',
        symptoms = {
            {
                threshold = 0.40,
                label = "Detecção imprecisa de detonação",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor knock degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 500 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor knock falhando - risco de dano",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.7 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 150 } },
                },
            },
        },
    },
    ['sensor_ect'] = {
        durability = { min = 910, max = 990 },
        labelItem = 'Sensor ECT',
        symptoms = {
            {
                threshold = 0.40,
                label = "Leitura incorreta de temperatura",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.3 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor ECT degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 500 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor ECT crítico - superaquecimento",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.8 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 100 } },
                },
            },
        },
    },
    ['sensor_temp_oleo'] = {
        durability = { min = 990, max = 1070 },
        labelItem = 'Sensor Temp Óleo',
        symptoms = {
            {
                threshold = 0.40,
                label = "Monitoramento impreciso",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.3 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.5 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 500 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor crítico - óleo superaquecido",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.7 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 250 } },
                },
            },
        },
    },
    ['sensor_press_oleo'] = {
        durability = { min = 1070, max = 1150 },
        labelItem = 'Sensor Press Óleo',
        symptoms = {
            {
                threshold = 0.40,
                label = "Leitura imprecisa de pressão",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.05 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.5 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.12 } },
                    { type = "engine_health", params = { value = 550 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor crítico - baixa pressão",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.7 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.35 } },
                    { type = "engine_health", params = { value = 100 } },
                },
            },
        },
    },
    ['sensor_press_comb'] = {
        durability = { min = 1150, max = 1230 },
        labelItem = 'Sensor Press Combustível',
        symptoms = {
            {
                threshold = 0.40,
                label = "Pressão irregular",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.08 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.escape, scale = 0.5 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.18 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor crítico - falha de combustível",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.escape, scale = 0.7 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.40 } },
                    { type = "engine_health", params = { value = 150 } },
                },
            },
        },
    },
    ['sensor_o2_pre'] = {
        durability = { min = 1230, max = 1300 },
        labelItem = 'Sensor Lambda Pré',
        symptoms = {
            {
                threshold = 0.40,
                label = "Mistura ar/combustível irregular",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.escape, scale = 0.3 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor O2 degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_exhaust_smoke", bone = Parts.VehicleBones.escape, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor O2 crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.escape, scale = 0.7 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_o2_pos'] = {
        durability = { min = 1300, max = 1370 },
        labelItem = 'Sensor Lambda Pós',
        symptoms = {
            {
                threshold = 0.40,
                label = "Monitoramento impreciso",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.escape, scale = 0.25 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_exhaust_smoke", bone = Parts.VehicleBones.escape, scale = 0.55 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.escape, scale = 0.65 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_egt'] = {
        durability = { min = 340, max = 420 },
        labelItem = 'Sensor EGT',
        symptoms = {
            {
                threshold = 0.40,
                label = "Leitura imprecisa de temperatura",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.escape, scale = 0.3 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_exhaust_smoke", bone = Parts.VehicleBones.escape, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor crítico - gases superaquecidos",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.escape, scale = 0.8 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_evap'] = {
        durability = { min = 1370, max = 1440 },
        labelItem = 'Sensor Press Canister',
        symptoms = {
            {
                threshold = 0.40,
                label = "Pressão EVAP irregular",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_egr_flow'] = {
        durability = { min = 470, max = 550 },
        labelItem = 'Sensor Fluxo EGR',
        symptoms = {
            {
                threshold = 0.40,
                label = "Fluxo EGR irregular",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.3 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.55 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_egr_pos'] = {
        durability = { min = 620, max = 700 },
        labelItem = 'Sensor Posição EGR',
        symptoms = {
            {
                threshold = 0.40,
                label = "Posição EGR imprecisa",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.65 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_press_exh'] = {
        durability = { min = 780, max = 860 },
        labelItem = 'Sensor Pressão Escape',
        symptoms = {
            {
                threshold = 0.40,
                label = "Leitura imprecisa",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.escape, scale = 0.3 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_exhaust_smoke", bone = Parts.VehicleBones.escape, scale = 0.55 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.escape, scale = 0.65 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },
    ['sensor_baro'] = {
        durability = { min = 1440, max = 1500 },
        labelItem = 'Sensor BARO',
        symptoms = {
            {
                threshold = 0.40,
                label = "Leitura atmosférica imprecisa",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Sensor degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                    { type = "engine_health", params = { value = 600 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sensor crítico",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "stall", params = { chance = 0.20 } },
                    { type = "engine_health", params = { value = 300 } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   🔧 PEÇAS DE MOTOR E MANUTENÇÃO
    -- ──────────────────────────────────────────────────────
    ['turbo_garret_1'] = {
        durability = { min = 999999999, max = 999999999 },
        labelItem = 'Garrett GT1548',
        symptoms = {
            {
                threshold = 0.00,
                label = "Garrett GT1548",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
    ['turbo_garret_2'] = {
        durability = { min = 999999999, max = 999999999 },
        labelItem = 'Garrett GT2056',
        symptoms = {
            {
                threshold = 0.00,
                label = "Garrett GT2056",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
    ['turbo_garret_3'] = {
        durability = { min = 999999999, max = 999999999 },
        labelItem = 'Garrett GT3071R',
        symptoms = {
            {
                threshold = 0.00,
                label = "Garrett GT3071R",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
    ['turbo_garret_4'] = {
        durability = { min = 999999999, max = 999999999 },
        labelItem = 'Garrett GTX3582R',
        symptoms = {
            {
                threshold = 0.00,
                label = "Garrett GTX3582R",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
    ['nitro_kit'] = {
        durability = { min = 999999999, max = 999999999 },
        labelItem = 'Kit Nitro',
        symptoms = {
            {
                threshold = 0.00,
                label = "Kit Nitro",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
    ['oleo_motor'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Óleo do Motor',
        symptoms = {
            {
                threshold = 0.40,
                label = "Óleo degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_exhaust_smoke", bone = Parts.VehicleBones.escape, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Óleo queimando",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_exhaust_smoke", bone = Parts.VehicleBones.escape, scale = 0.8 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "engine_health", params = { value = 400 } },
                    { type = "stall", params = { chance = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label = "Sem óleo — motor destruindo",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.escape, scale = 1.2 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.30 } },
                    { type = "engine_health", params = { value = 0 } },
                    { type = "stall", params = { chance = 0.50 } },
                    { type = "undriveable", params = { value = true } },
                },
            },
        },
    },
    ['filtro_oleo'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Filtro de Óleo',
        symptoms = {
            {
                threshold = 0.40,
                label = "Filtro sujo",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.3 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Filtro entupido",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.6 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.08 } },
                    { type = "engine_health", params = { value = 500 } },
                    { type = "stall", params = { chance = 0.06 } },
                },
            },
            {
                threshold = 0.05,
                label = "Filtro crítico — motor sem lubrificação",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.8 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.20 } },
                    { type = "engine_health", params = { value = 100 } },
                    { type = "stall", params = { chance = 0.30 } },
                },
            },
        },
    },
    ['filtro_ar'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Filtro de Ar',
        symptoms = {
            {
                threshold = 0.40,
                label = "Filtro sujo",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.04 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Filtro entupido",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.06 } },
                },
            },
            {
                threshold = 0.05,
                label = "Filtro crítico — motor sufocando",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.7 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "engine_health", params = { value = 300 } },
                    { type = "stall", params = { chance = 0.20 } },
                },
            },
        },
    },
    ['filtro_combustivel'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Filtro de Combustível',
        symptoms = {
            {
                threshold = 0.40,
                label = "Filtro sujo",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.04 } },
                    { type = "stall", params = { chance = 0.03 } },
                },
            },
            {
                threshold = 0.25,
                label = "Filtro entupido",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.escape, scale = 0.5 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "stall", params = { chance = 0.10 } },
                },
            },
            {
                threshold = 0.05,
                label = "Filtro crítico — sem combustível",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_exhaust_smoke", bone = Parts.VehicleBones.escape, scale = 0.8 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.18 } },
                    { type = "engine_health", params = { value = 200 } },
                    { type = "stall", params = { chance = 0.35 } },
                },
            },
        },
    },
    ['vela_ignicao'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Vela de Ignição',
        symptoms = {
            {
                threshold = 0.40,
                label = "Falha leve de ignição",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.3 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.06 } },
                    { type = "stall", params = { chance = 0.03 } },
                },
            },
            {
                threshold = 0.25,
                label = "Falha de ignição moderada",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.5 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.12 } },
                    { type = "engine_health", params = { value = 500 } },
                    { type = "stall", params = { chance = 0.10 } },
                },
            },
            {
                threshold = 0.05,
                label = "Falha crítica de ignição",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.8 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.25 } },
                    { type = "engine_health", params = { value = 200 } },
                    { type = "stall", params = { chance = 0.30 } },
                },
            },
        },
    },
    ['cabos_vela'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Cabos de Vela',
        symptoms = {
            {
                threshold = 0.40,
                label = "Perda leve de ignição",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.03 } },
                },
            },
            {
                threshold = 0.15,
                label = "Cabo deteriorado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.5 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.12 } },
                    { type = "engine_health", params = { value = 400 } },
                    { type = "stall", params = { chance = 0.15 } },
                },
            },
        },
    },
    ['bobina_ignicao'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Bobina de Ignição',
        symptoms = {
            {
                threshold = 0.40,
                label = "Bobina fraca",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.3 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Bobina degradada",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.5 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.10 } },
                    { type = "engine_health", params = { value = 500 } },
                    { type = "stall", params = { chance = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label = "Bobina falhando",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 0.7 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.20 } },
                    { type = "engine_health", params = { value = 200 } },
                    { type = "stall", params = { chance = 0.25 } },
                },
            },
        },
    },
    ['correia_dentada'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Correia Dentada',
        symptoms = {
            {
                threshold = 0.40,
                label = "Correia desgastada",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.08 } },
                    { type = "stall", params = { chance = 0.03 } },
                },
            },
            {
                threshold = 0.25,
                label = "Correia crítica",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.5 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.15 } },
                    { type = "engine_health", params = { value = 400 } },
                    { type = "stall", params = { chance = 0.10 } },
                },
            },
            {
                threshold = 0.05,
                label = "Correia rompendo — motor destruindo",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 1.0 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.35 } },
                    { type = "engine_health", params = { value = 0 } },
                    { type = "stall", params = { chance = 0.60 } },
                    { type = "undriveable", params = { value = true } },
                },
            },
        },
    },
    ['correia_alternador'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Correia do Alternador',
        symptoms = {
            {
                threshold = 0.40,
                label = "Correia patinando",
                effects = {
                    { type = "vehicle_lights", params = { state = 2 } },
                },
            },
            {
                threshold = 0.25,
                label = "Correia desgastada",
                effects = {
                    { type = "vehicle_lights", params = { state = 2 } },
                    { type = "stall", params = { chance = 0.03 } },
                },
            },
            {
                threshold = 0.05,
                label = "Correia rompida",
                effects = {
                    { type = "engine_on", params = { value = false } },
                    { type = "vehicle_lights", params = { state = 0 } },
                },
            },
        },
    },
    ['tensor_correia'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Tensor da Correia',
        symptoms = {
            {
                threshold = 0.40,
                label = "Tensor fraco",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.02 } },
                    { type = "power_mult", params = { value = 0.94 } },
                },
            },
            {
                threshold = 0.25,
                label = "Tensor degradado",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.06 } },
                    { type = "power_mult", params = { value = 0.82 } },
                },
            },
            {
                threshold = 0.05,
                label = "Tensor crítico",
                effects = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.12 } },
                    { type = "power_mult", params = { value = 0.65 } },
                    { type = "stall", params = { chance = 0.06 } },
                },
            },
        },
    },
    ['bomba_combustivel'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Bomba de Combustível',
        symptoms = {
            {
                threshold = 0.40,
                label = "Bomba fraca",
                effects = {
                    { type = "torque_mult", params = { value = 0.88 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Bomba degradada",
                effects = {
                    { type = "torque_mult", params = { value = 0.68 } },
                    { type = "power_mult", params = { value = 0.75 } },
                    { type = "stall", params = { chance = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label = "Bomba falhando",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.6 } },
                    { type = "torque_mult", params = { value = 0.40 } },
                    { type = "power_mult", params = { value = 0.45 } },
                    { type = "stall", params = { chance = 0.20 } },
                },
            },
        },
    },
    ['bomba_agua'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Bomba de Água',
        symptoms = {
            {
                threshold = 0.40,
                label = "Arrefecimento reduzido",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Superaquecimento moderado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.8 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.12 } },
                    { type = "engine_health", params = { value = 350 } },
                    { type = "stall", params = { chance = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label = "Motor superaquecido — quebrou",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 1.2 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.35 } },
                    { type = "engine_health", params = { value = 0 } },
                    { type = "stall", params = { chance = 0.60 } },
                    { type = "undriveable", params = { value = true } },
                },
            },
        },
    },
    ['mangueiras_radiador'] = {
        durability = { min = 200, max = 300 },
        labelItem = 'Mangueiras do Radiador',
        symptoms = {
            {
                threshold = 0.40,
                label = "Mangueira ressecada",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_steam", bone = Parts.VehicleBones.motor, scale = 0.4 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.05 } },
                    { type = "stall", params = { chance = 0.02 } },
                },
            },
            {
                threshold = 0.25,
                label = "Vazamento de líquido",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_amb_smoke_engine", bone = Parts.VehicleBones.motor, scale = 0.8 } },
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.12 } },
                    { type = "engine_health", params = { value = 350 } },
                    { type = "stall", params = { chance = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label = "Mangueira rompida — superaquecimento",
                effects = {
                    { type = "particle", params = { dict = "core", name = "ent_sht_flame", bone = Parts.VehicleBones.motor, scale = 1.0 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.30 } },
                    { type = "engine_health", params = { value = 0 } },
                    { type = "stall", params = { chance = 0.50 } },
                    { type = "undriveable", params = { value = true } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   🛞 SUSPENSÃO
    -- ──────────────────────────────────────────────────────
    ['amortecedor'] = {
        durability = { min = 350, max = 430 },
        labelItem = 'Amortecedor',
        symptoms = {
            {
                threshold = 0.40,
                label = "Amortecedor fraco",
                effects = {
                    { type = "handling_float", params = { field = "fSuspensionReboundDamp", speed = 10, value = 0.5 } },
                    { type = "handling_float", params = { field = "fSuspensionCompDamp", speed = 10, value = 0.5 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 0.6 } },
                },
            },
            {
                threshold = 0.15,
                label = "Amortecedor crítico",
                effects = {
                    { type = "handling_float", params = { field = "fSuspensionReboundDamp", speed = 10, value = 0.2 } },
                    { type = "handling_float", params = { field = "fSuspensionCompDamp", speed = 10, value = 0.2 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 1.0 } },
                },
            },
        },
    },
    ['mola'] = {
        durability = { min = 3, max = 3 },
        labelItem = 'Mola',
        symptoms = {
            {
                threshold = 0.40,
                label = "Mola enfraquecida",
                effects = {
                    { type = "handling_float", params = { field = "fSuspensionReboundDamp", speed = 10, value = 0.5 } },
                    { type = "handling_float", params = { field = "fSuspensionCompDamp", speed = 10, value = 0.5 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 0.6 } },
                },
            },
            {
                threshold = 0.15,
                label = "Mola crítica",
                effects = {
                    { type = "handling_float", params = { field = "fSuspensionReboundDamp", speed = 10, value = 0.2 } },
                    { type = "handling_float", params = { field = "fSuspensionCompDamp", speed = 10, value = 0.2 } },
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 1.0 } },
                },
            },
        },
    },
    ['bucha'] = {
        durability = { min = 600, max = 680 },
        labelItem = 'Bucha',
        symptoms = {
            {
                threshold = 0.40,
                label = "Bucha com folga",
                effects = {
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "lateral_force", params = { value = 8.0 } },
                    { type = "steering_scale", params = { value = 0.25 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 2.0 } },
                },
            },
            {
                threshold = 0.15,
                label = "Bucha crítica",
                effects = {
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "lateral_force", params = { value = 15.0 } },
                    { type = "steering_scale", params = { value = 0.10 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 4.0 } },
                },
            },
        },
    },
    ['bandeja'] = {
        durability = { min = 700, max = 780 },
        labelItem = 'Bandeja',
        symptoms = {
            {
                threshold = 0.40,
                label = "Bandeja com folga",
                effects = {
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "lateral_force", params = { value = 8.0 } },
                    { type = "steering_scale", params = { value = 0.25 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 2.0 } },
                },
            },
            {
                threshold = 0.15,
                label = "Bandeja danificada",
                effects = {
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "lateral_force", params = { value = 15.0 } },
                    { type = "steering_scale", params = { value = 0.10 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 4.0 } },
                },
            },
        },
    },
    ['pivo'] = {
        durability = { min = 430, max = 560 },
        labelItem = 'Pivô',
        symptoms = {
            {
                threshold = 0.40,
                label = "Pivô com folga",
                effects = {
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "lateral_force", params = { value = 8.0 } },
                    { type = "steering_scale", params = { value = 0.25 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 2.0 } },
                },
            },
            {
                threshold = 0.15,
                label = "Pivô crítico",
                effects = {
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "lateral_force", params = { value = 15.0 } },
                    { type = "steering_scale", params = { value = 0.10 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 4.0 } },
                },
            },
        },
    },
    ['barra_estabilizadora'] = {
        durability = { min = 850, max = 950 },
        labelItem = 'Barra Estabilizadora',
        symptoms = {
            {
                threshold = 0.40,
                label = "Estabilidade reduzida",
                effects = {
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "lateral_force", params = { value = 8.0 } },
                    { type = "steering_scale", params = { value = 0.25 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 2.0 } },
                },
            },
            {
                threshold = 0.15,
                label = "Barra danificada",
                effects = {
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "lateral_force", params = { value = 15.0 } },
                    { type = "steering_scale", params = { value = 0.10 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 4.0 } },
                },
            },
        },
    },
    ['bieleta'] = {
        durability = { min = 750, max = 820 },
        labelItem = 'Bieleta',
        symptoms = {
            {
                threshold = 0.40,
                label = "Bieleta com folga",
                effects = {
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "lateral_force", params = { value = 8.0 } },
                    { type = "steering_scale", params = { value = 0.25 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 2.0 } },
                },
            },
            {
                threshold = 0.15,
                label = "Bieleta crítica",
                effects = {
                    { type = "shake_cam", params = { type = "SMALL_EXPLOSION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "lateral_force", params = { value = 15.0 } },
                    { type = "steering_scale", params = { value = 0.10 } },
                    { type = "apply_force", params = { random = true, speed = 50, intensity = 4.0 } },
                },
            },
        },
    },

    -- ──────────────────────────────────────────────────────
    --   🛞 RODA
    -- ──────────────────────────────────────────────────────
    ['tire_common'] = {
        durability = { min = 20000, max = 50000 },
        labelItem = 'Pneus Standard',
        symptoms   = {
            {
                threshold = 0.20,
                label     = "Pneu desgastado",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Pneu no limite",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.20 } },
                    { type = "tyre_burst", params = { wheel = nil } },
                },
            },
        },
    },
    ['tire_street'] = {
        durability = { min = 20000, max = 50000 },
        labelItem = 'Pneus Street',
        symptoms   = {
            {
                threshold = 0.20,
                label     = "Pneu desgastado",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Pneu no limite",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.20 } },
                    { type = "tyre_burst", params = { wheel = nil } },
                },
            },
        },
    },
    ['tire_sport'] = {
        durability = { min = 20000, max = 50000 },
        labelItem = 'Pneus Sport',
        symptoms   = {
            {
                threshold = 0.20,
                label     = "Pneu desgastado",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Pneu no limite",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.20 } },
                    { type = "tyre_burst", params = { wheel = nil } },
                },
            },
        },
    },
    ['tire_race'] = {
        durability = { min = 20000, max = 50000 },
        labelItem = 'Pneus Race',
        symptoms   = {
            {
                threshold = 0.20,
                label     = "Pneu desgastado",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Pneu no limite",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.20 } },
                    { type = "tyre_burst", params = { wheel = nil } },
                },
            },
        },
    },
    ['tire_semislick'] = {
        durability = { min = 20000, max = 50000 },
        labelItem = 'Pneus Semi-slick',
        symptoms   = {
            {
                threshold = 0.20,
                label     = "Pneu desgastado",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Pneu no limite",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.20 } },
                    { type = "tyre_burst", params = { wheel = nil } },
                },
            },
        },
    },
    ['tire_slick'] = {
        durability = { min = 20000, max = 50000 },
        labelItem = 'Pneus Slick',
        symptoms   = {
            {
                threshold = 0.20,
                label     = "Pneu desgastado",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Pneu no limite",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.20 } },
                    { type = "tyre_burst", params = { wheel = nil } },
                },
            },
        },
    },
    ['tire_drift'] = {
        durability = { min = 20, max = 25 },
        labelItem = 'Pneus Drift',
        symptoms   = {
            {
                threshold = 0.20,
                label     = "Pneu desgastado",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.01 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Pneu no limite",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.01 } },
                    { type = "tyre_burst", params = { wheel = 4 } },
                },
            },
        },
    },
    ['tire_touring'] = {
        durability = { min = 20000, max = 50000 },
        labelItem = 'Pneus Touring',
        symptoms   = {
            {
                threshold = 0.20,
                label     = "Pneu desgastado",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.08 } },
                },
            },
            {
                threshold = 0.05,
                label     = "Pneu no limite",
                effects   = {
                    { type = "shake_cam", params = { type = "ROAD_VIBRATION_SHAKE", speed = 50, intensity = 0.20 } },
                    { type = "tyre_burst", params = { wheel = nil } },
                },
            },
        },
    },
    ['brake_level_1'] = {
        durability = { min = 999999999, max = 999999999 },
        labelItem = 'Freio Ferodoz',
        symptoms = {
            {
                threshold = 0.00,
                label = "Óleo degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
    ['brake_level_2'] = {
        durability = { min = 999999999, max = 999999999 },
        labelItem = 'Freio StoptechX',
        symptoms = {
            {
                threshold = 0.00,
                label = "Óleo degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
    ['brake_level_3'] = {
        durability = { min = 999999999, max = 999999999 },
        labelItem = 'Freio Wilhood',
        symptoms = {
            {
                threshold = 0.00,
                label = "Óleo degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
    ['brake_level_4'] = {
        durability = { min = 999999999, max = 999999999 },
        labelItem = 'Freio Brempo',
        symptoms = {
            {
                threshold = 0.00,
                label = "Óleo degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
    ['disco_freio'] = {
        durability = { min = 150, max = 200 },
        labelItem = 'Disco de Freio',
        symptoms = {
            {
                threshold = 0.40,
                label     = "Disco de Freio desgastado",
                effects   = {
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.65 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Disco de Freio superaquecido",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = Parts.VehicleBones.roda_dianteira_esquerda, scale = 0.4 } },
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.35 } },
                },
            },
            {
                threshold = 0.03,
                label     = "Sem freio",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = Parts.VehicleBones.roda_dianteira_esquerda, scale = 0.8 } },
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.05 } },
                },
            },
            {
                threshold = 0.00,
                label     = "Freio queimado",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.roda_dianteira_esquerda, scale = 1.0 } },
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.00 } },
                },
            },
        },
    },
    ['fluido_freio'] = {
        durability = { min = 150, max = 200 },
        labelItem = 'Fluido de Freio',
        symptoms = {
            {
                threshold = 0.40,
                label     = "Fluido de Freio seco",
                effects   = {
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.65 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Fluido de Freio superaquecido",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = Parts.VehicleBones.roda_dianteira_esquerda, scale = 0.4 } },
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.35 } },
                },
            },
            {
                threshold = 0.03,
                label     = "Sem freio",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = Parts.VehicleBones.roda_dianteira_esquerda, scale = 0.8 } },
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.05 } },
                },
            },
            {
                threshold = 0.00,
                label     = "Freio queimado",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.roda_dianteira_esquerda, scale = 1.0 } },
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.00 } },
                },
            },
        },
    },
    ['pastilha_freio'] = {
        durability = { min = 150, max = 200 },
        labelItem = 'Pastilha de Freio',
        symptoms = {
            {
                threshold = 0.40,
                label     = "Pastilha de Freio desgastado",
                effects   = {
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.65 } },
                },
            },
            {
                threshold = 0.15,
                label     = "Pastilha de Freio superaquecido",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = Parts.VehicleBones.roda_dianteira_esquerda, scale = 0.4 } },
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.35 } },
                },
            },
            {
                threshold = 0.03,
                label     = "Sem freio",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "ent_sht_smoke", bone = Parts.VehicleBones.roda_dianteira_esquerda, scale = 0.8 } },
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.05 } },
                },
            },
            {
                threshold = 0.00,
                label     = "Freio queimado",
                effects   = {
                    { type = "particle",       params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.roda_dianteira_esquerda, scale = 1.0 } },
                    { type = "handling_float", params = { field = "fBrakeForce", speed = 10, value = 0.00 } },
                },
            },
        },
    },
    
    -- ──────────────────────────────────────────────────────
    --   TUNING - PECAS SEM DESGASTE
    -- ──────────────────────────────────────────────────────
    ['ventoinha_airforce_fan_quebrada'] = {
        durability = { min = 99999999999, max = 99999999999 },
        labelItem = 'Bobina Pro race',
        symptoms = {
            {
                threshold = 0.00,
                label = "Óleo degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
    ['bobina_pro_race'] = {
        durability = { min = 99999999999, max = 99999999999 },
        labelItem = 'Bobina Pro race',
        symptoms = {
            {
                threshold = 0.00,
                label = "Óleo degradado",
                effects = {
                    { type = "particle", params = { dict = "core", name = "veh_backfire", bone = Parts.VehicleBones.escape, scale = 0.00 } },
                    { type = "power_mult", params = { value = 0.00 } },
                },
            },
        },
    },
}
