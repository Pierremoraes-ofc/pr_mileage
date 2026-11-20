-- ============================================================
--   pr_mileage — SERVER: PEÇAS INSTALADAS
--   Banco: placa original | Entidade: state bag do PR Bridge
-- ============================================================
local Database = pr_lib.database

local function randomInRange(min, max)
    return min + math.random() * (max - min)
end

local function calcCurrentKm(installedKm, vehicleKm)
    local driven = math.floor(tonumber(vehicleKm) or 0) - math.floor(tonumber(installedKm) or 0)
    return driven > 0 and driven or 0
end

local function calcPercent(currentKm, durability)
    durability = tonumber(durability) or 0
    if durability <= 0 then return 0.0 end
    return math.max(0, durability - currentKm) / durability
end

local function resolveStatus(percent)
    if percent >= WearConfig.StatusThresholds.good then
        return WearConfig.StatusLabels.good
    elseif percent >= WearConfig.StatusThresholds.fair then
        return WearConfig.StatusLabels.fair
    end
    return WearConfig.StatusLabels.bad
end

local function buildPartInfo(row, vehicleKm)
    local durability = tonumber(row.durability) or 0
    local currentKm = calcCurrentKm(row.installed_km, vehicleKm)
    local remaining = math.max(0, durability - currentKm)
    local percent = calcPercent(currentKm, durability)

    return {
        id = row.id,
        plate = PRMileageSanitizePlate(row.plate),
        part = row.part,
        stage = tonumber(row.stage) or 1,
        installed_km = math.floor(tonumber(row.installed_km) or 0),
        durability = math.floor(durability),
        current_km = currentKm,
        remaining_km = remaining,
        percent = math.floor(percent * 1000) / 10,
        status = resolveStatus(percent),
        citizen_id = row.citizen_id,
        installed_at = row.installed_at,
    }
end

local function resolveIdentity(plate)
    return PRMileageResolvePlate(plate)
end

local function resolveRequest(sourceId, displayedPlate, netId, refreshIdentity)
    if netId ~= nil then
        return PRMileageResolveVehicle(sourceId, netId, displayedPlate, refreshIdentity)
    end
    return nil, resolveIdentity(displayedPlate)
end

local function fetchVehicleParts(originalPlate, vehicleKm)
    originalPlate = PRMileageSanitizePlate(originalPlate)
    if not originalPlate then return {} end

    local rows = Database.query(
        "SELECT * FROM vehicle_parts WHERE UPPER(REPLACE(plate, ' ', '')) = ?",
        { originalPlate }
    ) or {}

    local result = {}
    for _, row in ipairs(rows) do
        result[row.part] = buildPartInfo(row, vehicleKm or 0)
    end
    return result
end

local function publishVehicleParts(vehicle, parts)
    if not vehicle then return end
    PRMileagePartsSet(vehicle, parts or {}, true, { force = true })
end

local function installPart(originalPlate, partName, stage, vehicleKm, citizenId)
    originalPlate = PRMileageSanitizePlate(originalPlate)
    if not originalPlate or type(partName) ~= "string" or partName == "" then return false end

    local partDef = Parts.Items[partName]
    if not partDef then return false end

    local durability = 0
    if partDef.durability then
        durability = math.floor(randomInRange(partDef.durability.min, partDef.durability.max))
    end

    local affected = Database.update([[
        INSERT INTO vehicle_parts (plate, part, stage, installed_km, durability, citizen_id)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            stage        = VALUES(stage),
            installed_km = VALUES(installed_km),
            durability   = VALUES(durability),
            citizen_id   = VALUES(citizen_id),
            installed_at = NOW()
    ]], {
        originalPlate,
        partName,
        tonumber(stage) or 1,
        math.floor(tonumber(vehicleKm) or 0),
        durability,
        citizenId,
    })

    return affected ~= nil and affected ~= false, durability
end

local function removePart(originalPlate, partName)
    originalPlate = PRMileageSanitizePlate(originalPlate)
    if not originalPlate or type(partName) ~= "string" or partName == "" then return false end

    local affected = Database.update(
        "DELETE FROM vehicle_parts WHERE UPPER(REPLACE(plate, ' ', '')) = ? AND part = ?",
        { originalPlate, partName }
    )
    return affected ~= nil and affected ~= false
end

-- O callback resolve a placa visual, consulta sempre pela placa original e
-- publica a lista na entidade. O retorno serve somente como confirmação imediata.
pr_lib.callback.register("pr_mileage:cb:getVehicleParts", function(sourceId, plate, vehicleKm, netId)
    local vehicle, identity = resolveRequest(sourceId, plate, netId, false)
    if not identity then return false end

    vehicleKm = vehicle and PRMileageGet(vehicle, vehicleKm) or vehicleKm
    local parts = fetchVehicleParts(identity.plate, vehicleKm)
    publishVehicleParts(vehicle, parts)
    return parts, identity.plate, identity
end)

pr_lib.callback.register("pr_mileage:cb:getPart", function(sourceId, plate, partName, vehicleKm, netId)
    local vehicle, identity = resolveRequest(sourceId, plate, netId, false)
    if not identity or not partName then return false end

    vehicleKm = vehicle and PRMileageGet(vehicle, vehicleKm) or vehicleKm
    local parts = fetchVehicleParts(identity.plate, vehicleKm)
    publishVehicleParts(vehicle, parts)
    return parts[partName] or false, identity.plate, identity
end)

RegisterNetEvent("pr_mileage:sv:installPart", function(displayedPlate, partName, stage, vehicleKm, citizenId, netId)
    local sourceId = source
    local vehicle, identity = resolveRequest(sourceId, displayedPlate, netId, true)
    if not vehicle or not identity then return end

    local authoritativeKm = PRMileageGet(vehicle, tonumber(vehicleKm) or 0)
    local ok, durability = installPart(identity.plate, partName, stage, authoritativeKm, citizenId)
    if not ok then return end

    local parts = fetchVehicleParts(identity.plate, authoritativeKm)
    publishVehicleParts(vehicle, parts)
    TriggerClientEvent("pr_mileage:cl:partInstalled", sourceId, identity.plate, partName, durability)
end)

RegisterNetEvent("pr_mileage:sv:removePart", function(displayedPlate, partName, netId)
    local sourceId = source
    local vehicle, identity = resolveRequest(sourceId, displayedPlate, netId, true)
    if not vehicle or not identity or not removePart(identity.plate, partName) then return end

    local vehicleKm = PRMileageGet(vehicle, 0)
    local parts = fetchVehicleParts(identity.plate, vehicleKm)
    publishVehicleParts(vehicle, parts)
    TriggerClientEvent("pr_mileage:cl:partRemoved", sourceId, identity.plate, partName)
end)

local function getPart(plate, partName, vehicleKm)
    local identity = resolveIdentity(plate)
    if not identity or not partName then return false end
    return fetchVehicleParts(identity.plate, vehicleKm)[partName] or false
end

exports("GetPartsPercent", function(plate, partName, vehicleKm)
    local part = getPart(plate, partName, vehicleKm)
    return part and part.percent or false
end)

exports("GetPartsMileage", function(plate, partName, vehicleKm)
    local part = getPart(plate, partName, vehicleKm)
    return part and part.remaining_km or false
end)

exports("GetPartsStatus", function(plate, partName, vehicleKm)
    local part = getPart(plate, partName, vehicleKm)
    return part and part.status or false
end)

exports("GetParts", getPart)

exports("GetVehicleParts", function(plate, vehicleKm)
    local identity = resolveIdentity(plate)
    if not identity then return {} end
    return fetchVehicleParts(identity.plate, vehicleKm)
end)

exports("installPart", function(plate, partName, stage, vehicleKm, citizenId)
    local identity = resolveIdentity(plate)
    if not identity then return false end
    return installPart(identity.plate, partName, stage, vehicleKm, citizenId)
end)

exports("removePart", function(plate, partName)
    local identity = resolveIdentity(plate)
    if not identity then return false end
    return removePart(identity.plate, partName)
end)
