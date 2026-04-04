Config = {}

-- Framework detectado automaticamente pelo Fivem_bridge
-- Config.Framework foi removido — não é mais necessário configurar

-- Unidade de exibição: "kilometers" ou "miles"
-- Afeta o valor retornado pelos exports getMileage / getMileageByPlate etc.
Config.Unit = "kilometers" -- "kilometers" | "miles"

-- Executa o SQL automaticamente ao iniciar (adiciona coluna mileage na tabela do framework)
Config.AutoRunSQL = false

-- A cada quantos KM (ou milhas) salva no banco enquanto rodando
Config.SaveThreshold = 1.0

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