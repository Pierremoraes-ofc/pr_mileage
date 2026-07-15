Config = {}

-- Framework detectado automaticamente pelo Fivem_bridge
-- Config.Framework foi removido — não é mais necessário configurar

-- Unidade de exibição: "kilometers" ou "miles"
-- Afeta o valor retornado pelos exports getMileage / getMileageByPlate etc.
Config.Unit = "kilometers" -- "kilometers" | "miles"

-- Executa o SQL automaticamente ao iniciar (adiciona coluna mileage na tabela do framework)
Config.AutoRunSQL = true

-- Mostra logs informativos de inicializacao/debug
Config.Debug = false

--  Executa a verificação de novas versões do script "não baixa, ele apenas avisa!"
Config.Version = false

-- A cada quantos KM (ou milhas) salva no banco enquanto rodando
Config.SaveThreshold = 1.0

Config.Notfy = {
    position = 'center-left',        --  'top' or 'top-right' or 'top-left' or 'bottom' or 'bottom-right' or 'bottom-left' or 'center-right' or 'center-left'
    duration = 3000,
}
-- ============================================================
--   KM ALEATÓRIO POR CLASSE — para veículos sem registro no banco
--   Sempre em KM internamente; convertido para miles nos exports
--   se Config.Unit == "miles"
--   Faixas: { min, max } em KM · Classe 0–22 (GetVehicleClass)
-- ============================================================
Config.ClassKmRange = {
    [0]  = { 8000,  60000  }, -- Compacts
    [1]  = { 5000,  45000  }, -- Sedans
    [2]  = { 3000,  30000  }, -- SUVs
    [3]  = { 2000,  20000  }, -- Coupes
    [4]  = { 1000,  15000  }, -- Muscle
    [5]  = { 500,   10000  }, -- Sports Classics
    [6]  = { 500,   8000   }, -- Sports
    [7]  = { 200,   5000   }, -- Super
    [8]  = { 5000,  80000  }, -- Motorcycles
    [9]  = { 10000, 150000 }, -- Off-road
    [10] = { 20000, 300000 }, -- Industrial
    [11] = { 15000, 200000 }, -- Utility
    [12] = { 5000,  80000  }, -- Vans
    [13] = { 0,     0      }, -- Cycles        (ignorado pelo tracker)
    [14] = { 0,     0      }, -- Boats         (ignorado)
    [15] = { 0,     0      }, -- Helicopters   (ignorado)
    [16] = { 0,     0      }, -- Planes        (ignorado)
    [17] = { 30000, 400000 }, -- Service
    [18] = { 20000, 300000 }, -- Emergency
    [19] = { 10000, 200000 }, -- Military
    [20] = { 5000,  100000 }, -- Commercial
    [21] = { 0,     0      }, -- Trains        (ignorado)
    [22] = { 0,     0      }, -- Open Wheel    (ignorado)
}

Config.ClassNames = {
    [0]  = "Compacts",      [1]  = "Sedans",          [2]  = "SUVs",
    [3]  = "Coupes",        [4]  = "Muscle",           [5]  = "Sports Classics",
    [6]  = "Sports",        [7]  = "Super",            [8]  = "Motorcycles",
    [9]  = "Off-road",      [10] = "Industrial",       [11] = "Utility",
    [12] = "Vans",          [13] = "Cycles",           [14] = "Boats",
    [15] = "Helicopters",   [16] = "Planes",           [17] = "Service",
    [18] = "Emergency",     [19] = "Military",         [20] = "Commercial",
    [21] = "Trains",        [22] = "Open Wheel",
}

-- Classes que o tracker ignora completamente (não acumula distância)
Config.IgnoredClasses = {
    [13] = true, -- Cycles
    [14] = true, -- Boats
    [15] = true, -- Helicopters
    [16] = true, -- Planes
    [21] = true, -- Trains
    [22] = true, -- Open Wheel
}

-- ============================================================
--   SCANNER OBD — Configurações da tela de loading
-- ============================================================
Config.Scanner = {
    -- Duração total da tela de loading em segundos
    ScanDuration = 10,              --  10 = 10 segundos
    DisplayMode = 'stats'           --  progress = progress bar com valor de porcentagem / stats = mostra apenas status das peças de acordo com WearConfig.StatusLabels e WearConfig.StatusThresholds
}

Config.BacklistItemDesgaste = {
    -- Nitro
    'nitro_50',
    'nitro_100',
    'nitro_200',

    -- Turbinas
    'turbo_garret_1',
    'turbo_garret_2',
    'turbo_garret_3',
    'turbo_garret_4',

    -- Freios de tuning
    'brake_level_1',
    'brake_level_2',
    'brake_level_3',
    'brake_level_4',

    -- Diferencial / Coilover
    'diferencial_pro',
    'coilover',

    -- Stage 1 — Bloco do motor
    'pistao_racing_forged',
    'biela_street_performance',
    'anel_pistao_high_compression',
    'bronzina_biela_powerline',
    'bronzina_mancal_prodrive',
    'parafuso_biela_ultrabolt',
    'parafuso_cabecote_headlock',
    'junta_cabecote_multiseal',
    'correia_dentada_powerbelt',
    'bomba_oleo_highflow_oil',

    -- Stage 2 — Combustível e admissão
    'bico_injetor_megaflow',
    'bomba_combustivel_fuelmax_pro',
    'regulador_pressao_fuelcontrol_x',
    'mangueira_combustivel_flexfuel',
    'linha_combustivel_steelflow',
    'flauta_fuel_rail_performance',
    'corpo_borboleta_airflow_70mm',
    'coletor_admissao_air_intake_pro',
    'filtro_ar_powerfilter',
    'duto_admissao_cold_air_pipe',
    'mangote_admissao_turboflex',
    'abracadeira_lockclamp_pro',
    'retentor_motor_oilguard',
    'tensor_correia_autotension_pro',
    'polia_virabrequim_lightspin',

    -- Stage 3 — Arrefecimento e escapamento
    'intercooler_megacooler',
    'tubulacao_intercooler_boostpipe',
    'mangueira_pressao_hyperflow',
    'conexao_aluminio_alloylink',
    'radiador_agua_cooling_pro_x',
    'reservatorio_expansao_cooltank',
    'tampa_radiador_pressure_cap_x',
    'ventoinha_airforce_fan',
    'radiador_oleo_oilcooler_racing',
    'mangueira_oleo_oilline_pro',
    'coletor_escape_turbo_header',
    'downpipe_powerdown_x',
    'escape_esportivo_fullflow',
    'catalisador_racecat',
    'wastegate_boostcontrol',
    'valvula_blowoff_turborelease',
    'pescador_oleo_deepflow',
    'carter_oilpan_performance',
    'defletor_oleo_oilbaffle_pro',
    'tampa_valvulas_valvecover_x',

    -- Stage 4 — Transmissão e embreagem
    'embreagem_stagex_racing',
    'plato_pressureforce',
    'disco_ceramico_ceramicgrip',
    'volante_motor_lightflywheel_pro',
    'garfo_embreagem_shiftfork_x',
    'atuador_embreagem_hydroclutch',
    'rolamento_embreagem_spinlock',
    'trambulador_shortshift_pro',
    'cabo_engate_gearlink',
    'engrenagem_cambio_gearset',
    'sincronizadores_syncrotech',
    'diferencial_lockdiff_pro',
    'semieixo_torqueshaft',
    'homocinetica_drivejoint_x',
    'coxin_motor_powermounts',
    'coxin_cambio_gearmount_pro',
    'suporte_cambio_transbracket_x',
    'tampa_cambio_gearcover_pro',
    'eixo_primario_input_shaft_pro',
    'eixo_secundario_output_shaft_x',
    'rolamento_cambio_gearbearings',
    'kit_reparo_cambio_rebuild_kit',
    'flange_cambio_driveflange_x',
    'junta_carter_oilseal_pro',
    'junta_tampa_valvulas_sealcover_x',
    'prisioneiro_cabecote_headstuds',
    'guia_valvula_valveguide_x',
    'sede_valvula_valveseat_pro',
    'mola_valvula_valvespring_racing',
    'retentor_valvula_valveseal_pro',
}
