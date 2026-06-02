-- ============================================================
--   pr_mileage — Auto SQL
-- ============================================================
if false and Config.AutoRunSQL then
    if not pcall(function()
        local fw = ActiveBridges["frameworks"]
        local fileName = (fw == "qb" or fw == "qbx") and "qb.sql" or "esx.sql"
        local file = assert(io.open(GetResourcePath(GetCurrentResourceName()) .. "/install/" .. fileName, "rb"))
        local sql  = file:read("*all")
        file:close()
        MySQL.query.await(sql)
    end) then
        --print("^1[pr_mileage] Erro ao executar SQL automático. Execute manualmente o arquivo em /install. Se já executou, defina Config.AutoRunSQL = false^0")
    end
end

-- ============================================================
--   pr_mileage — SERVER
--   Framework.VehiclesTable e Framework.OwnerColumn são
--   definidos em main.lua via ActiveBridges["frameworks"]
--   Bridge.framework.GetIdentifier(source) resolve o identifier
--   do player correto para cada framework automaticamente
-- ============================================================

local function quoteIdentifier(identifier)
    return ("`%s`"):format(tostring(identifier):gsub("`", "``"))
end

local function columnExists(tableName, columnName)
    local exists = MySQL.scalar.await([[
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = ?
        LIMIT 1
    ]], { tableName, columnName })

    return exists ~= nil
end

local function ensureMileageSchema()
    local vehiclesTable = Framework and Framework.VehiclesTable

    if vehiclesTable and vehiclesTable ~= "" and not columnExists(vehiclesTable, "mileage") then
        MySQL.query.await(("ALTER TABLE %s ADD COLUMN `mileage` FLOAT NOT NULL DEFAULT 0"):format(quoteIdentifier(vehiclesTable)))
    end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vehicle_parts` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `plate` VARCHAR(10) NOT NULL COMMENT 'Placa do veiculo',
            `part` VARCHAR(64) NOT NULL COMMENT 'Identificador da peca',
            `stage` TINYINT NOT NULL DEFAULT 1 COMMENT 'Nivel/estagio da peca',
            `installed_km` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'KM inteiro do veiculo no momento da instalacao',
            `durability` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Durabilidade total da peca em KM inteiro',
            `citizen_id` VARCHAR(64) NULL DEFAULT NULL COMMENT 'CitizenID de quem instalou',
            `installed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Data e hora da instalacao',
            `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_plate_part` (`plate`, `part`),
            INDEX `idx_plate` (`plate`),
            INDEX `idx_citizen_id` (`citizen_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        ALTER TABLE `vehicle_parts`
            MODIFY COLUMN `installed_km` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'KM inteiro do veiculo no momento da instalacao',
            MODIFY COLUMN `durability` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Durabilidade total da peca em KM inteiro'
    ]])
end

if Config.AutoRunSQL then
    local ok, err = pcall(ensureMileageSchema)

    if ok then
        print("^2[pr_mileage] Banco de dados verificado/criado com sucesso.^0")
    else
        print(("^1[pr_mileage] Erro ao executar SQL automatico: %s^0"):format(err))
        print("^1[pr_mileage] Execute manualmente /install/qb.sql ou /install/esx.sql, ou corrija a permissao do usuario MySQL.^0")
    end
end

local KM_TO_MILES = 0.621371

-- Tabela em memória: plate → km (carros da rua — sem dono no banco)
local worldVehicles = {}

-- ============================================================
--   UTILITÁRIOS INTERNOS
-- ============================================================

local function convertUnit(km)
    if Config.Unit == "miles" then return km * KM_TO_MILES end
    return km
end

local function sanitizePlate(plate)
    if not plate or plate == "" then return false end
    return plate:gsub("%s+", ""):upper()
end

local function isOwnedVehicle(plate)
    local result = MySQL.scalar.await(
        "SELECT 1 FROM " .. Framework.VehiclesTable .. " WHERE plate = ? LIMIT 1",
        { plate }
    )
    return result ~= nil
end

local function fetchFromDB(plate)
    local result = MySQL.scalar.await(
        "SELECT mileage FROM " .. Framework.VehiclesTable .. " WHERE plate = ?",
        { plate }
    )
    if result == nil then return -1 end
    return result or 0.0
end

local function fetchFromRAM(plate)
    if worldVehicles[plate] == nil then return -1 end
    return worldVehicles[plate]
end

local function resolveMileage(plate)
    plate = sanitizePlate(plate)
    if not plate then return false end

    local dbKm = fetchFromDB(plate)
    if dbKm ~= -1 then return dbKm, "db" end

    local ramKm = fetchFromRAM(plate)
    if ramKm ~= -1 then return ramKm, "ram" end

    return -1, nil
end

-- UPDATE condicional — anti-regressão no SQL, sem query de leitura prévia
local function writeToDB(plate, value)
    MySQL.update.await(
        "UPDATE " .. Framework.VehiclesTable ..
        " SET mileage = ? WHERE plate = ? AND (mileage IS NULL OR mileage < ?)",
        { value, plate, value }
    )
end

local function writeToRAM(plate, value)
    worldVehicles[plate] = value
end

-- ============================================================
--   CALLBACK — busca mileage (client chama ao entrar no veículo)
-- ============================================================

lib.callback.register("pr_mileage:cb:getMileage", function(_, plate)
    local km, source = resolveMileage(plate)
    return km, source
end)

-- ============================================================
--   EVENTO — salva mileage vindo do client
-- ============================================================

RegisterNetEvent("pr_mileage:sv:saveMileage")
AddEventHandler("pr_mileage:sv:saveMileage", function(plate, mileage, isFresh, isOwned)
    if not plate or plate == "" then return end
    plate = sanitizePlate(plate)

    if isFresh then
        if isOwnedVehicle(plate) then
            writeToDB(plate, 0.0)
        end
        worldVehicles[plate] = nil
        return
    end

    if isOwned then
        writeToDB(plate, mileage)
    else
        local current = worldVehicles[plate]
        if current and mileage <= current then return end
        writeToRAM(plate, mileage)
    end
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
    local km = Entity(ent).state.vehicleMileage
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
    if isOwnedVehicle(plate) then
        writeToDB(plate, 0.0)
    else
        writeToRAM(plate, 0.0)
    end
end)

exports("setMileage", function(plate, value)
    plate = sanitizePlate(plate)
    if not plate or type(value) ~= "number" then return end
    local km = Config.Unit == "miles" and (value / KM_TO_MILES) or value
    if isOwnedVehicle(plate) then
        writeToDB(plate, km)
    else
        writeToRAM(plate, km)
    end
end)

exports("getTopMileage", function(limit)
    limit = limit or 10
    local rows = MySQL.query.await(
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
    local identifier
    if type(src) == "number" then
        -- Resolve o identifier do player pelo framework ativo
        -- Replica a lógica do Bridge.framework.GetIdentifier sem depender de globals externas
        local res = Framework.ActiveResource
        if res == "qb-core" then
            local QBCore = exports["qb-core"]:GetCoreObject()
            local player = QBCore.Functions.GetPlayer(src)
            identifier = player and player.PlayerData.citizenid or nil
        elseif res == "qbx-core" then
            local player = exports["qbx-core"]:GetPlayer(src)
            identifier = player and player.PlayerData.citizenid or nil
        elseif res == "es_extended" then
            local ESX = exports["es_extended"]:getSharedObject()
            local xPlayer = ESX.GetPlayerFromId(src)
            identifier = xPlayer and xPlayer.getIdentifier() or nil
        elseif res == "ox_core" then
            local Ox = exports["ox_core"]
            local player = Ox:GetPlayer(src)
            identifier = player and player.charId or nil
        else
            -- ND Core ou fallback — tenta pegar license
            identifier = GetPlayerIdentifierByType(tostring(src), "license")
        end
    else
        identifier = src
    end
    if not identifier or identifier == "" then return {} end

    local rows = MySQL.query.await(
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
    for plate, km in pairs(worldVehicles) do
        result[plate] = convertUnit(km)
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
if lib and lib.callback then
    lib.callback.register('pr_mileage:getSavedData', function(source)
        return loadSavedOffsets()
    end)
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
lib.addCommand(Config.command, {
    help = 'Inicia o modo de ajuste de animação',
    restricted = Config.adminOnly and Config.acePermission or nil
}, function(source, args, raw)
    if Config.adminOnly and not Config.isAdmin(source) then
        TriggerClientEvent('pr_mileage:notify', source, Config.Translations['no_permission'])
        return
    end

    TriggerClientEvent('pr_mileage:startAdjust', source)
end)
