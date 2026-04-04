-- ============================================================
--   pr_mileage — SERVER: PEÇAS INSTALADAS
-- ============================================================

local function randomInRange(min, max)
    return min + math.random() * (max - min)
end

local function sanitizePlate(plate)
    if not plate or plate == "" then return false end
    return plate:gsub("%s+", ""):upper()
end

-- Calcula quilômetros rodados pela peça — sempre inteiro (math.floor)
-- installedKm e vehicleKm chegam do banco como INT, mas garantimos floor aqui também
local function calcCurrentKm(installedKm, vehicleKm)
    local driven = math.floor(vehicleKm) - math.floor(installedKm)
    return driven > 0 and driven or 0
end

-- Calcula % restante (0.0–1.0)
local function calcPercent(currentKm, durability)
    if durability <= 0 then return 0.0 end
    local remaining = durability - currentKm
    if remaining < 0 then remaining = 0 end
    return remaining / durability
end

-- Resolve label de status a partir do percent
local function resolveStatus(percent)
    if percent >= WearConfig.StatusThresholds.good then
        return WearConfig.StatusLabels.good
    elseif percent >= WearConfig.StatusThresholds.fair then
        return WearConfig.StatusLabels.fair
    else
        return WearConfig.StatusLabels.bad
    end
end

-- Monta tabela de info completa de uma row do banco + km atual do veículo
local function buildPartInfo(row, vehicleKm)
    local currentKm  = calcCurrentKm(row.installed_km, vehicleKm)
    local percent    = calcPercent(currentKm, row.durability)
    local remaining  = row.durability - currentKm
    if remaining < 0 then remaining = 0.0 end

    return {
        id           = row.id,
        plate        = row.plate,
        part         = row.part,
        stage        = row.stage,
        installed_km = row.installed_km,
        durability   = row.durability,
        current_km   = currentKm,
        remaining_km = remaining,
        percent      = math.floor(percent * 1000) / 10,  -- ex: 73.5
        status       = resolveStatus(percent),
        citizen_id   = row.citizen_id,
        installed_at = row.installed_at,
    }
end

-- ============================================================
--   CALLBACKS (client → server)
-- ============================================================

-- Retorna todas as peças de uma placa com info calculada
lib.callback.register("pr_mileage:cb:getVehicleParts", function(_, plate, vehicleKm)
    plate = sanitizePlate(plate)
    if not plate then return false end

    local rows = MySQL.query.await(
        "SELECT * FROM vehicle_parts WHERE plate = ?",
        { plate }
    )
    if not rows or #rows == 0 then return {} end

    local result = {}
    for _, row in ipairs(rows) do
        result[row.part] = buildPartInfo(row, vehicleKm or 0)
    end
    return result
end)

-- Retorna uma peça específica de uma placa
lib.callback.register("pr_mileage:cb:getPart", function(_, plate, partName, vehicleKm)
    plate = sanitizePlate(plate)
    if not plate or not partName then return false end

    local row = MySQL.single.await(
        "SELECT * FROM vehicle_parts WHERE plate = ? AND part = ?",
        { plate, partName }
    )
    if not row then return false end

    return buildPartInfo(row, vehicleKm or 0)
end)

-- ============================================================
--   EVENTOS DE REDE
-- ============================================================

-- Instala uma peça (ou substitui se já existir)
RegisterNetEvent("pr_mileage:sv:installPart")
AddEventHandler("pr_mileage:sv:installPart", function(plate, partName, stage, vehicleKm, citizenId)
    local src = source
    plate = sanitizePlate(plate)
    if not plate or not partName then return end

    local partDef    = Parts.Items[partName]
    local durability = 0.0

    if partDef and partDef.durability then
        -- FIX: math.floor garante que durability e installed_km são sempre inteiros
        -- Consistente com INT UNSIGNED no banco — elimina os decimais que causavam
        -- falsos positivos no cálculo de desgaste das peças
        durability = math.floor(randomInRange(partDef.durability.min, partDef.durability.max))
    end

    local installedKmInt = math.floor(vehicleKm or 0)

    local affected = MySQL.update.await(
        [[
            INSERT INTO vehicle_parts (plate, part, stage, installed_km, durability, citizen_id)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                stage        = VALUES(stage),
                installed_km = VALUES(installed_km),
                durability   = VALUES(durability),
                citizen_id   = VALUES(citizen_id),
                installed_at = NOW()
        ]],
        { plate, partName, stage or 1, installedKmInt, durability, citizenId or nil }
    )
    if affected and affected > 0 then
        TriggerClientEvent("pr_mileage:cl:partInstalled", src, plate, partName, durability)
    end
end)

-- Remove uma peça
RegisterNetEvent("pr_mileage:sv:removePart")
AddEventHandler("pr_mileage:sv:removePart", function(plate, partName)
    local src = source
    plate = sanitizePlate(plate)
    if not plate or not partName then return end

    -- FIX: MySQL.update.await para DELETE — retorna rows affected (number)
    local affected = MySQL.update.await(
        "DELETE FROM vehicle_parts WHERE plate = ? AND part = ?",
        { plate, partName }
    )
    if affected and affected > 0 then
        TriggerClientEvent("pr_mileage:cl:partRemoved", src, plate, partName)
    end
end)

-- ============================================================
--   EXPORTS SERVER
-- ============================================================

-- Retorna info de uma peça pelo banco (síncrono)
-- GetPartsPercent(plate, partName, vehicleKm) → number (0–100) | false
exports("GetPartsPercent", function(plate, partName, vehicleKm)
    plate = sanitizePlate(plate)
    if not plate or not partName then return false end
    local row = MySQL.single.await(
        "SELECT * FROM vehicle_parts WHERE plate = ? AND part = ?",
        { plate, partName }
    )
    if not row then return false end
    local currentKm = calcCurrentKm(row.installed_km, vehicleKm or 0)
    local percent   = calcPercent(currentKm, row.durability)
    return math.floor(percent * 1000) / 10
end)

-- GetPartsMileage(plate, partName, vehicleKm) → number (km restantes) | false
exports("GetPartsMileage", function(plate, partName, vehicleKm)
    plate = sanitizePlate(plate)
    if not plate or not partName then return false end
    local row = MySQL.single.await(
        "SELECT * FROM vehicle_parts WHERE plate = ? AND part = ?",
        { plate, partName }
    )
    if not row then return false end
    local currentKm  = calcCurrentKm(row.installed_km, vehicleKm or 0)
    local remaining  = row.durability - currentKm
    return remaining > 0 and remaining or 0.0
end)

-- GetPartsStatus(plate, partName, vehicleKm) → string ("Boa"|"Razoável"|"Ruim") | false
exports("GetPartsStatus", function(plate, partName, vehicleKm)
    plate = sanitizePlate(plate)
    if not plate or not partName then return false end
    local row = MySQL.single.await(
        "SELECT * FROM vehicle_parts WHERE plate = ? AND part = ?",
        { plate, partName }
    )
    if not row then return false end
    local currentKm = calcCurrentKm(row.installed_km, vehicleKm or 0)
    local percent   = calcPercent(currentKm, row.durability)
    return resolveStatus(percent)
end)

-- GetParts(plate, partName, vehicleKm) → tabela completa | false
exports("GetParts", function(plate, partName, vehicleKm)
    plate = sanitizePlate(plate)
    if not plate or not partName then return false end
    local row = MySQL.single.await(
        "SELECT * FROM vehicle_parts WHERE plate = ? AND part = ?",
        { plate, partName }
    )
    if not row then return false end
    return buildPartInfo(row, vehicleKm or 0)
end)

-- GetVehicleParts(plate, vehicleKm) → tabela de todas as peças | {}
exports("GetVehicleParts", function(plate, vehicleKm)
    plate = sanitizePlate(plate)
    if not plate then return {} end
    local rows = MySQL.query.await(
        "SELECT * FROM vehicle_parts WHERE plate = ?",
        { plate }
    )
    if not rows or #rows == 0 then return {} end
    local result = {}
    for _, row in ipairs(rows) do
        result[row.part] = buildPartInfo(row, vehicleKm or 0)
    end
    return result
end)

-- Instala uma peça server-side (sem precisar de evento do client)
-- installPart(plate, partName, stage, vehicleKm, citizenId)
exports("installPart", function(plate, partName, stage, vehicleKm, citizenId)
    plate = sanitizePlate(plate)
    if not plate or not partName then return false end

    local partDef    = Parts.Items[partName]
    local durability = 0
    if partDef and partDef.durability then
        -- FIX: math.floor — durability e installed_km sempre inteiros no banco
        durability = math.floor(randomInRange(partDef.durability.min, partDef.durability.max))
    end

    local installedKmInt = math.floor(vehicleKm or 0)

    MySQL.update.await(
        [[
            INSERT INTO vehicle_parts (plate, part, stage, installed_km, durability, citizen_id)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                stage        = VALUES(stage),
                installed_km = VALUES(installed_km),
                durability   = VALUES(durability),
                citizen_id   = VALUES(citizen_id),
                installed_at = NOW()
        ]],
        { plate, partName, stage or 1, installedKmInt, durability, citizenId or nil }
    )
    return true
end)

-- Remove uma peça server-side
exports("removePart", function(plate, partName)
    plate = sanitizePlate(plate)
    if not plate or not partName then return false end
    -- FIX: MySQL.update.await para DELETE — retorna rows affected (number)
    MySQL.update.await(
        "DELETE FROM vehicle_parts WHERE plate = ? AND part = ?",
        { plate, partName }
    )
    return true
end)