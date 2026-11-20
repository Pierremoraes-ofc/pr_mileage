-- ============================================================
--   pr_mileage — Auto SQL
-- ============================================================
local Database = pr_lib.database
local function quoteIdentifier(identifier)
    if type(identifier) ~= "string" or not identifier:match("^[%w_]+$") then
        error(("Identificador SQL invalido: %s"):format(tostring(identifier)))
    end

    return ("`%s`"):format(identifier)
end

local function scalarNumber(query, params)
    local value = Database.scalar(query, params)
    return tonumber(value or 0) or 0
end

local function columnExists(tableName, columnName)
    return scalarNumber([[
        SELECT COUNT(*)
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = ?
    ]], { tableName, columnName }) > 0
end

local function indexExists(tableName, indexName)
    return scalarNumber([[
        SELECT COUNT(*)
        FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND INDEX_NAME = ?
    ]], { tableName, indexName }) > 0
end

local function addColumnIfMissing(tableName, columnName, definition)
    if columnExists(tableName, columnName) then return end

    Database.query(("ALTER TABLE %s ADD COLUMN %s"):format(
        quoteIdentifier(tableName),
        definition
    ))
end

local function addIndexIfMissing(tableName, indexName, definition)
    if indexExists(tableName, indexName) then return end

    Database.query(("ALTER TABLE %s ADD %s"):format(
        quoteIdentifier(tableName),
        definition
    ))
end

local function ensureMileageColumn()
    local vehiclesTable = Framework and Framework.VehiclesTable or "player_vehicles"
    addColumnIfMissing(vehiclesTable, "mileage", "`mileage` FLOAT NOT NULL DEFAULT 0")
end

local function ensureVehiclePartsTable()
    Database.query([[
        CREATE TABLE IF NOT EXISTS `vehicle_parts` (
            `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `plate`           VARCHAR(10)  NOT NULL COMMENT 'Placa do veiculo',
            `part`            VARCHAR(64)  NOT NULL COMMENT 'Identificador da peca',
            `stage`           TINYINT      NOT NULL DEFAULT 1,
            `installed_km`    INT UNSIGNED NOT NULL DEFAULT 0,
            `durability`      INT UNSIGNED NOT NULL DEFAULT 0,
            `citizen_id`      VARCHAR(64)  NULL DEFAULT NULL,
            `installed_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_plate_part` (`plate`, `part`),
            INDEX `idx_plate` (`plate`),
            INDEX `idx_citizen_id` (`citizen_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    addColumnIfMissing("vehicle_parts", "stage", "`stage` TINYINT NOT NULL DEFAULT 1")
    addColumnIfMissing("vehicle_parts", "installed_km", "`installed_km` INT UNSIGNED NOT NULL DEFAULT 0")
    addColumnIfMissing("vehicle_parts", "durability", "`durability` INT UNSIGNED NOT NULL DEFAULT 0")
    addColumnIfMissing("vehicle_parts", "citizen_id", "`citizen_id` VARCHAR(64) NULL DEFAULT NULL")
    addColumnIfMissing("vehicle_parts", "installed_at", "`installed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP")
    addColumnIfMissing("vehicle_parts", "updated_at", "`updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP")

    Database.query([[
        ALTER TABLE `vehicle_parts`
            MODIFY COLUMN `installed_km` INT UNSIGNED NOT NULL DEFAULT 0,
            MODIFY COLUMN `durability` INT UNSIGNED NOT NULL DEFAULT 0
    ]])

    addIndexIfMissing("vehicle_parts", "uq_plate_part", "UNIQUE KEY `uq_plate_part` (`plate`, `part`)")
    addIndexIfMissing("vehicle_parts", "idx_plate", "INDEX `idx_plate` (`plate`)")
    addIndexIfMissing("vehicle_parts", "idx_citizen_id", "INDEX `idx_citizen_id` (`citizen_id`)")
end

if Config.AutoRunSQL then
    CreateThread(function()
        local ok, err = pcall(function()
            ensureMileageColumn()
            ensureVehiclePartsTable()
        end)

        if not ok then
            print(("^1[pr_mileage] Erro ao executar SQL automatico: %s^0"):format(err))
            print("^3[pr_mileage] Execute manualmente o arquivo em /install ou defina Config.AutoRunSQL = false.^0")
        end
    end)
end

-- ============================================================
--   pr_mileage — SERVER
--   Framework.VehiclesTable e Framework.OwnerColumn são
--   definidos em main.lua via ActiveBridges["frameworks"]
--   Bridge.framework.GetIdentifier(source) resolve o identifier
--   do player correto para cada framework automaticamente
-- ============================================================

local KM_TO_MILES = 0.621371

-- ============================================================
--   UTILITÁRIOS INTERNOS
-- ============================================================

local function convertUnit(km)
    if Config.Unit == "miles" then return km * KM_TO_MILES end
    return km
end

local sanitizePlate = PRMileageSanitizePlate

local function resolveIdentity(plate)
    return PRMileageResolvePlate(plate)
end

local function isOwnedVehicle(plate)
    local identity = resolveIdentity(plate)
    return identity ~= nil and identity.owned == true
end

local function fetchFromDB(plate)
    local result = Database.scalar(
        "SELECT mileage FROM " .. Framework.VehiclesTable ..
        " WHERE UPPER(REPLACE(plate, ' ', '')) = ? LIMIT 1",
        { sanitizePlate(plate) }
    )
    if result == nil then return -1 end
    return tonumber(result) or 0.0
end

local function findVehicleByPlate(plate)
    plate = sanitizePlate(plate)
    if not plate then return nil end

    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and GetEntityType(vehicle) == 2 then
            local displayed = sanitizePlate(GetVehicleNumberPlateText(vehicle))
            local identity = PRMileageIdentityGet(vehicle)
            local original = type(identity) == "table" and sanitizePlate(identity.plate) or nil
            if displayed == plate or original == plate then return vehicle end
        end
    end
end

local function resolveMileage(plate, vehicle)
    local identity = resolveIdentity(plate)
    if not identity then return false end

    if identity.owned then
        local dbKm = fetchFromDB(identity.plate)
        if dbKm ~= -1 then return dbKm, "db", identity end
    end

    vehicle = vehicle or findVehicleByPlate(identity.plate)
    local stateKm = vehicle and PRMileageGet(vehicle)
    if stateKm ~= nil then return stateKm, "state", identity end

    return -1, nil, identity
end

-- UPDATE condicional — anti-regressão no SQL, sem query de leitura prévia
local function writeToDB(plate, value)
    Database.update(
        "UPDATE " .. Framework.VehiclesTable ..
        " SET mileage = ? WHERE UPPER(REPLACE(plate, ' ', '')) = ? AND (mileage IS NULL OR mileage < ?)",
        { value, sanitizePlate(plate), value }
    )
end

local function forceWriteToDB(plate, value)
    Database.update(
        "UPDATE " .. Framework.VehiclesTable ..
        " SET mileage = ? WHERE UPPER(REPLACE(plate, ' ', '')) = ?",
        { value, sanitizePlate(plate) }
    )
end

-- ============================================================
--   CALLBACK — busca mileage (client chama ao entrar no veículo)
local function validMileage(value)
    value = tonumber(value)
    if not value or value ~= value or value < 0.0 or value > 1000000000.0 then return nil end
    return value
end

local function publishMileage(sourceId, vehicle, mileage, owned)
    PRMileageSet(vehicle, mileage, true, { force = true })
    TriggerClientEvent(
        "pr_mileage:cl:authoritativeMileage",
        sourceId,
        NetworkGetNetworkIdFromEntity(vehicle),
        mileage,
        owned == true
    )
end

-- ============================================================

pr_lib.callback.register("pr_mileage:cb:getMileage", function(sourceId, plate, netId)
    local identity
    if netId then
        local vehicle
        vehicle, identity = PRMileageResolveVehicle(sourceId, netId, plate, false)
        if not vehicle or not identity then return false, nil end
    else
        identity = resolveIdentity(plate)
        if not identity then return false, nil end
    end

    local km, storage = resolveMileage(identity.plate, vehicle)
    return km, storage, identity.plate, identity
end)

-- ============================================================
--   EVENTO — salva mileage vindo do client
-- ============================================================

RegisterNetEvent("pr_mileage:sv:saveMileage")
AddEventHandler("pr_mileage:sv:saveMileage", function(plate, mileage, isFresh, netId, vehicleClass)
    local sourceId = source
    if not plate or plate == "" then return end
    plate = sanitizePlate(plate)
    mileage = validMileage(mileage)
    if not plate or not mileage then return end

    local vehicle, identity = PRMileageResolveVehicle(sourceId, netId, plate, false)
    if not vehicle or not identity then return end

    plate = identity.plate
    local current, storage = resolveMileage(plate, vehicle)
    local owned = identity.owned == true

    if isFresh then
        if current == -1 then
            current = 0.0
            if owned then writeToDB(plate, current) end
        end
        publishMileage(sourceId, vehicle, current, owned)
        return
    end

    vehicleClass = tonumber(vehicleClass)
    if vehicleClass then vehicleClass = math.floor(vehicleClass) end
    if not vehicleClass or vehicleClass < 0 or vehicleClass > 22 then return end

    if current == -1 then
        local range = Config.ClassKmRange[vehicleClass]
        local maximumInitial = range and tonumber(range[2]) or 0.0
        if mileage > maximumInitial + (tonumber(Config.MaxSyncAdvance) or 10.0) then return end
    end

    if current ~= -1 then
        if mileage < current then
            publishMileage(sourceId, vehicle, current, owned)
            return
        end
        if mileage - current > (tonumber(Config.MaxSyncAdvance) or 10.0) then return end
    end

    if owned then
        writeToDB(plate, mileage)
    end
    publishMileage(sourceId, vehicle, mileage, owned)
end)

-- ============================================================
--   EXPORTS SERVER
-- ============================================================

exports("getMileageByPlate", function(plate)
    local km = resolveMileage(plate)
    if not km or km == -1 then return false end
    return convertUnit(km)
end)

exports("getMileageByEntity", function(ent)
    if not ent or ent == 0 then return false end
    if not DoesEntityExist(ent) then return false end
    local km = PRMileageGet(ent)
    if not km then return false end
    return convertUnit(km)
end)

exports("getUnit", function() return Config.Unit end)
exports("GetUnit", function() return Config.Unit end)

exports("GetMileage", function(plate)
    local km = resolveMileage(plate)
    if not km or km == -1 then return false end
    return convertUnit(km), Config.Unit
end)

exports("getVehicleClassNameByEntity", function(ent)
    if not ent or ent == 0 then return false end
    if not DoesEntityExist(ent) then return false end
    return Config.ClassNames[GetVehicleType(ent)] or false
end)

exports("plateExists", function(plate)
    plate = sanitizePlate(plate)
    if not plate then return false end
    return isOwnedVehicle(plate)
end)

exports("plateRegistered", function(plate)
    plate = sanitizePlate(plate)
    if not plate then return false end
    local km = resolveMileage(plate)
    return km ~= -1 and km ~= false
end)

exports("resetMileage", function(plate)
    plate = sanitizePlate(plate)
    if not plate then return end
    local identity = resolveIdentity(plate)
    if identity and identity.owned then
        forceWriteToDB(identity.plate, 0.0)
    else
        local vehicle = findVehicleByPlate(identity and identity.plate or plate)
        if vehicle then PRMileageSet(vehicle, 0.0, true, { force = true }) end
    end
end)

exports("setMileage", function(plate, value)
    plate = sanitizePlate(plate)
    if not plate or type(value) ~= "number" then return end
    local km = Config.Unit == "miles" and (value / KM_TO_MILES) or value
    local identity = resolveIdentity(plate)
    if identity and identity.owned then
        forceWriteToDB(identity.plate, km)
    else
        local vehicle = findVehicleByPlate(identity and identity.plate or plate)
        if vehicle then PRMileageSet(vehicle, km, true, { force = true }) end
    end
end)

exports("getTopMileage", function(limit)
    limit = limit or 10
    local rows = Database.query(
        "SELECT plate, mileage FROM " .. Framework.VehiclesTable ..
        " WHERE mileage > 0 ORDER BY mileage DESC LIMIT ?",
        { limit }
    )
    if not rows then return {} end
    for _, row in ipairs(rows) do
        row.mileage = convertUnit(row.mileage)
    end
    return rows
end)

-- Aceita source (player online) ou identifier string (lookup offline)
-- Resolve o identifier diretamente pelo framework detectado no main.lua
exports("getPlayerVehiclesMileage", function(src)
    local identifier = type(src) == "number" and pr_lib.framework.GetIdentifier(src) or src
    if not identifier or identifier == "" then return {} end

    local rows = Database.query(
        "SELECT plate, mileage FROM " .. Framework.VehiclesTable ..
        " WHERE " .. Framework.OwnerColumn .. " = ? ORDER BY mileage DESC",
        { identifier }
    )
    if not rows then return {} end
    for _, row in ipairs(rows) do
        row.mileage = convertUnit(row.mileage)
    end
    return rows
end)

exports("getWorldVehicles", function()
    local result = {}
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and GetEntityType(vehicle) == 2 then
            local identity = PRMileageIdentityGet(vehicle)
            if type(identity) ~= "table" or identity.owned ~= true then
                local plate = sanitizePlate(GetVehicleNumberPlateText(vehicle))
                local km = PRMileageGet(vehicle)
                if plate and km ~= nil then result[plate] = convertUnit(km) end
            end
        end
    end
    return result
end)










--  =======================================================================
--  SCANNER
--  =======================================================================
local saved_offsets_path = "data/saved_offsets.json"

-- Funções de suporte (RESTAURADAS)
local function loadSavedOffsets()
    local content = LoadResourceFile(GetCurrentResourceName(), saved_offsets_path)
    if not content or content == "" then return {} end
    return json.decode(content) or {}
end

local function saveOffsetsToFile(data)
    SaveResourceFile(GetCurrentResourceName(), saved_offsets_path, json.encode(data, { indent = true }), -1)
end

-- Registro da Callback
pr_lib.callback.register('pr_mileage:getSavedData', function(source)
    return loadSavedOffsets()
end)
if Config.Debug then
    print("^2[pr_mileage] Callback 'getSavedData' registrada com sucesso!^7")
end



-- Evento para salvar o ajuste feito pelo jogador no JSON
RegisterNetEvent('pr_mileage:saveToJSON', function(data)
    local source = source

    -- Se restrição de admin estiver ativa, valida a permissão
    if Config.adminOnly and not Config.isAdmin(source) then
        print("^1[AdjustAnimations] Jogador " .. source .. " tentou salvar offsets sem permissão!^7")
        return
    end

    local savedData = loadSavedOffsets()

    -- Cria uma chave única baseada no Dicionário, Animação e Modelo do Objeto
    local key = string.format("%s_%s_%s", data.dict, data.anim, data.model or "no_model")

    -- Organiza os dados para o JSON
    savedData[key] = {
        dict = data.dict,
        anim = data.anim,
        model = data.model,
        bone = data.bone,
        offset = { x = data.offset.x, y = data.offset.y, z = data.offset.z },
        rotation = { x = data.rotation.x, y = data.rotation.y, z = data.rotation.z },
        interactFov = data.interactFov -- Persistência do Zoom Forense
    }

    saveOffsetsToFile(savedData)
    print("^2[AdjustAnimations] Offset salvo com sucesso para:^7 " .. key)
end)

-- =========================================================================
-- Scanner Forense — Lógica de Scan
-- =========================================================================

-- Rastreia última vez que cada jogador disparou (para GSR)
local lastShot = {}

AddEventHandler('weaponDamageEvent', function(data)
    if data and data.sender then
        lastShot[data.sender] = os.time()
    end
end)

local function formatDateTime()
    return os.date('%d/%m/%Y %H:%M')
end

local function checkGSR(serverId)
    local t = lastShot[serverId]
    if not t then return false end
    -- GSR positivo se atirou nos últimos 10 minutos
    return (os.time() - t) < 600
end

RegisterNetEvent('pr_mileage:startScan', function(targetData)
    local source = source
    if not targetData then
        TriggerClientEvent('pr_mileage:scanResult', source, {
            type     = 'vehicle',
            error    = 'Nenhum alvo detectado',
            dateTime = formatDateTime()
        })
        return
    end

    -- Simula tempo de processamento (2.5 segundos)
    CreateThread(function()
        Wait(2500)

        local result = {}

        if targetData.type == 'vehicle' then
            -- Tenta pegar o último motorista via network entity
            local dnaFound = math.random() > 0.45 -- 55% chance de DNA
            result = {
                type     = 'vehicle',
                plate    = targetData.plate or 'N/A',
                model    = targetData.model or 'N/A',
                dna      = dnaFound and ('DNA-' .. string.format('%04d', math.random(1000, 9999))) or false,
                dateTime = formatDateTime(),
            }
        elseif targetData.type == 'person' then
            local targetId   = targetData.serverId
            local targetName = targetId and GetPlayerName(targetId) or 'Desconhecido'
            local gsr        = checkGSR(targetId)

            result           = {
                type       = 'person',
                targetName = targetName,
                gsr        = gsr,
                dateTime   = formatDateTime(),
            }
        end

        TriggerClientEvent('pr_mileage:scanResult', source, result)
        print(string.format("[Scanner] Scan concluído para player %d — tipo: %s", source, targetData.type or '?'))
    end)
end)

-- Comando principal /adjust
pr_lib.addCommand(Config.command, {
    help = 'Inicia o modo de ajuste de animação',
    restricted = Config.adminOnly and Config.acePermission or nil
}, function(source, args, raw)
    if Config.adminOnly and not Config.isAdmin(source) then
        TriggerClientEvent('pr_mileage:notify', source, Config.Translations['no_permission'])
        return
    end

    TriggerClientEvent('pr_mileage:startAdjust', source)
end)
