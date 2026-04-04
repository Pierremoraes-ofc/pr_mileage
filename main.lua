-- ============================================================
--   pr_mileage — detecção de framework (espelha lógica do Fivem_bridge)
--   Usa GetResourceState para detectar qual framework está ativo,
--   na mesma ordem de prioridade do Fivem_bridge/bridge/config.lua
--   Globals de outros resources não são acessíveis em FiveM —
--   por isso replicamos a detecção aqui localmente.
-- ============================================================

Framework = {}

-- Ordem de prioridade idêntica ao Fivem_bridge
local frameworkPriority = {
    { resource = "ND_Core",     table = "player_vehicles", column = "citizenid" },
    { resource = "ox_core",     table = "vehicles",        column = "charId"    },
    { resource = "es_extended", table = "owned_vehicles",  column = "owner"     },
    { resource = "qbx-core",    table = "player_vehicles", column = "citizenid" },
    { resource = "qb-core",     table = "player_vehicles", column = "citizenid" },
}

local detected = false
for _, fw in ipairs(frameworkPriority) do
    if GetResourceState(fw.resource):find("start") then
        Framework.VehiclesTable = fw.table
        Framework.OwnerColumn   = fw.column
        Framework.ActiveResource = fw.resource
        detected = true
        print(("^2[pr_mileage] Framework detectado: '%s' → tabela: '%s' | coluna: '%s'^0"):format(
            fw.resource, fw.table, fw.column
        ))
        break
    end
end

if not detected then
    -- Fallback seguro
    Framework.VehiclesTable  = "player_vehicles"
    Framework.OwnerColumn    = "citizenid"
    Framework.ActiveResource = "unknown"
    print("^3[pr_mileage] Nenhum framework detectado — usando fallback player_vehicles/citizenid^0")
end