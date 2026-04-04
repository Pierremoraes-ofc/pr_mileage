-- ============================================================
--   pr_mileage — Auto SQL
-- ============================================================
if Config.AutoRunSQL then
    if not pcall(function()
        local fw = ActiveBridges["frameworks"]
        local fileName = (fw == "qb" or fw == "qbx") and "qb.sql" or "esx.sql"
        local file = assert(io.open(GetResourcePath(GetCurrentResourceName()) .. "/install/" .. fileName, "rb"))
        local sql  = file:read("*all")
        file:close()
        MySQL.query.await(sql)
    end) then
        print("^1[pr_mileage] Erro ao executar SQL automático. Execute manualmente o arquivo em /install. Se já executou, defina Config.AutoRunSQL = false^0")
    end
end

-- ============================================================
--   pr_mileage — SERVER
--   Framework.VehiclesTable e Framework.OwnerColumn são
--   definidos em main.lua via ActiveBridges["frameworks"]
--   Bridge.framework.GetIdentifier(source) resolve o identifier
--   do player correto para cada framework automaticamente
-- ============================================================

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