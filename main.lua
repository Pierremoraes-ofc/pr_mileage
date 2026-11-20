-- O PR Bridge é a única fonte de detecção de framework deste recurso.
Framework = {}

local frameworkName = pr_lib.framework.GetResourceName()
local storageByFramework = {
    ND_Core      = { table = "player_vehicles", column = "citizenid" },
    ox_core      = { table = "vehicles", column = "charId" },
    es_extended  = { table = "owned_vehicles", column = "owner" },
    qbx_core     = { table = "player_vehicles", column = "citizenid" },
    ["qb-core"] = { table = "player_vehicles", column = "citizenid" },
}

local storage = storageByFramework[frameworkName] or storageByFramework.qbx_core
Framework.VehiclesTable = storage.table
Framework.OwnerColumn = storage.column
Framework.ActiveResource = frameworkName

if Config.Debug then
    print(("^2[pr_mileage] Framework via PR Bridge: '%s' | tabela: '%s' | coluna: '%s'^0"):format(
        tostring(frameworkName), Framework.VehiclesTable, Framework.OwnerColumn
    ))
end