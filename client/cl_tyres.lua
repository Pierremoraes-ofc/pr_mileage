-- Client API for physical tyre damage, including callers outside the vehicle.
-- Networked vehicles must be changed by their current owner; this API never
-- requests control or changes the vehicle's mileage/installed-parts data.
local tyreIndexes = {
    [0] = true, [1] = true, [2] = true, [3] = true,
    [4] = true, [5] = true, [6] = true, [7] = true,
    [45] = true, [46] = true, [47] = true, [48] = true,
}

local function burstTyre(vehicle, index)
    if type(vehicle) ~= "number" or vehicle <= 0 or vehicle % 1 ~= 0
        or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then
        return false, "invalid_vehicle"
    end
    if type(index) ~= "number" or not tyreIndexes[index] then
        return false, "invalid_tyre"
    end
    if NetworkGetEntityIsNetworked(vehicle) and not NetworkHasControlOfEntity(vehicle) then
        return false, "owner_changed"
    end
    -- Idempotent: a second caller does not reapply damage to an already flat tyre.
    if IsVehicleTyreBurst(vehicle, index, false) then return true end
    if not GetVehicleTyresCanBurst(vehicle) then return false, "burst_disabled" end

    SetVehicleTyreBurst(vehicle, index, false, 1000.0)
    if not IsVehicleTyreBurst(vehicle, index, false) then return false, "sync_failed" end
    return true
end

exports("burstTyre", burstTyre)
