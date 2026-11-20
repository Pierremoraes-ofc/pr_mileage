local Database = pr_lib.database

local fakePlateSupport

function PRMileageSanitizePlate(plate)
    if type(plate) ~= "string" or plate == "" then return nil end
    local normalized = plate:gsub("%s+", ""):upper()
    return normalized ~= "" and normalized or nil
end

local function supportsFakePlate()
    if fakePlateSupport ~= nil then return fakePlateSupport end
    if Framework.VehiclesTable ~= "player_vehicles" then
        fakePlateSupport = false
        return false
    end

    local count = Database.scalar([[
        SELECT COUNT(*)
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = 'fakeplate'
    ]], { Framework.VehiclesTable })

    fakePlateSupport = (tonumber(count) or 0) > 0
    return fakePlateSupport
end

function PRMileageResolvePlate(displayedPlate)
    displayedPlate = PRMileageSanitizePlate(displayedPlate)
    if not displayedPlate then return nil end

    local tableName = Framework.VehiclesTable
    local row

    if supportsFakePlate() then
        row = Database.single(([[
            SELECT plate, fakeplate
            FROM %s
            WHERE UPPER(REPLACE(plate, ' ', '')) = ?
               OR UPPER(REPLACE(COALESCE(fakeplate, ''), ' ', '')) = ?
            LIMIT 1
        ]]):format(tableName), { displayedPlate, displayedPlate })
    else
        row = Database.single(([[
            SELECT plate
            FROM %s
            WHERE UPPER(REPLACE(plate, ' ', '')) = ?
            LIMIT 1
        ]]):format(tableName), { displayedPlate })
    end

    if not row then
        return {
            plate = displayedPlate,
            displayedPlate = displayedPlate,
            fakeplate = nil,
            isFakePlate = false,
            owned = false,
        }
    end

    local originalPlate = PRMileageSanitizePlate(row.plate)
    local fakePlate = PRMileageSanitizePlate(row.fakeplate)
    if not originalPlate then return nil end

    return {
        plate = originalPlate,
        displayedPlate = displayedPlate,
        fakeplate = fakePlate,
        isFakePlate = fakePlate ~= nil and displayedPlate == fakePlate and displayedPlate ~= originalPlate,
        owned = true,
    }
end

local function identityFromGarageState(vehicle, displayedPlate)
    local garageIdentity = PRMileageState.get(vehicle, "garageVehicleIdentity")
    local original = type(garageIdentity) == "table"
        and PRMileageSanitizePlate(garageIdentity.originalPlate)
        or PRMileageSanitizePlate(PRMileageState.get(vehicle, "originalPlate"))
    local fake = type(garageIdentity) == "table"
        and PRMileageSanitizePlate(garageIdentity.fakePlate)
        or PRMileageSanitizePlate(PRMileageState.get(vehicle, "fakePlate"))

    if not original or (displayedPlate ~= original and displayedPlate ~= fake) then return nil end
    return {
        plate = original,
        displayedPlate = displayedPlate,
        fakeplate = fake,
        isFakePlate = fake ~= nil and displayedPlate == fake and displayedPlate ~= original,
        owned = true,
        vehicleId = type(garageIdentity) == "table" and tonumber(garageIdentity.vehicleId) or nil,
    }
end

function PRMileageResolveVehicle(sourceId, netId, displayedPlate, refreshIdentity)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil, nil, "invalid_net_id" end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle <= 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return nil, nil, "invalid_vehicle"
    end

    local actualPlate = PRMileageSanitizePlate(GetVehicleNumberPlateText(vehicle))
    local requestedPlate = PRMileageSanitizePlate(displayedPlate)
    if not actualPlate or not requestedPlate or actualPlate ~= requestedPlate then
        return nil, nil, "plate_mismatch"
    end

    sourceId = tonumber(sourceId)
    if sourceId and sourceId > 0 then
        local ped = GetPlayerPed(sourceId)
        if not ped or ped <= 0 or not DoesEntityExist(ped) then
            return nil, nil, "invalid_player"
        end
        if GetPedInVehicleSeat(vehicle, -1) ~= ped then
            local playerCoords = GetEntityCoords(ped)
            local vehicleCoords = GetEntityCoords(vehicle)
            if #(playerCoords - vehicleCoords) > 15.0 then
                return nil, nil, "vehicle_too_far"
            end
        end
    end

    local identity = not refreshIdentity and PRMileageIdentityGet(vehicle) or nil
    if type(identity) ~= "table"
        or PRMileageSanitizePlate(identity.displayedPlate) ~= actualPlate
        or not PRMileageSanitizePlate(identity.plate) then
        identity = not refreshIdentity and identityFromGarageState(vehicle, actualPlate) or nil
        identity = identity or PRMileageResolvePlate(actualPlate)
    end
    if not identity then return nil, nil, "identity_not_found" end

    PRMileageIdentitySet(vehicle, identity, true, { force = true })
    return vehicle, identity
end

exports("resolveVehiclePlate", function(plate)
    return PRMileageResolvePlate(plate)
end)
