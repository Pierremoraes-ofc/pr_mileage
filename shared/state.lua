local vehicleState = pr_lib and pr_lib.fivem and pr_lib.fivem.vehicleState

if not vehicleState or not vehicleState.raw then
    error("[pr_mileage] pr_bridge vehicleState indisponivel. Inicie pr_bridge antes de pr_mileage.")
end

PRMileageState = vehicleState.raw

local function getNumber(vehicle, key, fallback)
    local value = tonumber(PRMileageState.get(vehicle, key))
    if value == nil then return fallback end
    return value
end

local function setState(vehicle, key, value, replicated, options)
    options = type(options) == "table" and options or {}
    options.replicated = replicated == true
    options.authority = IsDuplicityVersion() and "server" or "owner"
    options.maxPayloadBytes = options.maxPayloadBytes or 8192
    return PRMileageState.set(vehicle, key, value, options)
end

function PRMileageGet(vehicle, fallback)
    return getNumber(vehicle, "vehicleMileage", fallback)
end

function PRMileageSet(vehicle, value, replicated, options)
    options = type(options) == "table" and options or {}
    options.maxPayloadBytes = 128
    return setState(vehicle, "vehicleMileage", tonumber(value) or 0.0, replicated, options)
end

function PRMileageFreshGet(vehicle)
    return PRMileageState.get(vehicle, "vehicleMileageFresh") == true
end

function PRMileageFreshSet(vehicle, fresh, replicated, options)
    options = type(options) == "table" and options or {}
    options.maxPayloadBytes = 64
    return setState(vehicle, "vehicleMileageFresh", fresh == true, replicated, options)
end

function PRMileageIdentityGet(vehicle)
    local identity = PRMileageState.get(vehicle, "vehicleMileageIdentity")
    return type(identity) == "table" and identity or nil
end

function PRMileageIdentitySet(vehicle, identity, replicated, options)
    if type(identity) ~= "table" then return false, "invalid_identity" end
    options = type(options) == "table" and options or {}
    options.maxPayloadBytes = 1024
    return setState(vehicle, "vehicleMileageIdentity", identity, replicated, options)
end

function PRMileagePartsGet(vehicle)
    local parts = PRMileageState.get(vehicle, "vehicleMileageParts")
    return type(parts) == "table" and parts or {}
end

function PRMileagePartsSet(vehicle, parts, replicated, options)
    if type(parts) ~= "table" then return false, "invalid_parts" end
    options = type(options) == "table" and options or {}
    options.maxPayloadBytes = 8192
    return setState(vehicle, "vehicleMileageParts", parts, replicated, options)
end

function PRMileageExternalPartsGet(vehicle)
    local parts = PRMileageState.get(vehicle, "vehicleMileageExternalParts")
    return type(parts) == "table" and parts or {}
end

function PRMileageExternalPartsSet(vehicle, parts, replicated, options)
    if type(parts) ~= "table" then return false, "invalid_external_parts" end
    options = type(options) == "table" and options or {}
    options.maxPayloadBytes = 8192
    return setState(vehicle, "vehicleMileageExternalParts", parts, replicated, options)
end

function PRMileageOriginalHandlingGet(vehicle)
    local handling = PRMileageState.get(vehicle, "vehicleMileageOriginalHandling")
    return type(handling) == "table" and handling or {}
end

function PRMileageOriginalHandlingSet(vehicle, handling, replicated, options)
    if type(handling) ~= "table" then return false, "invalid_original_handling" end
    options = type(options) == "table" and options or {}
    options.maxPayloadBytes = 2048
    return setState(vehicle, "vehicleMileageOriginalHandling", handling, replicated, options)
end

function PRMileageTrackingGet(vehicle)
    local tracking = PRMileageState.get(vehicle, "vehicleMileageTracking")
    return type(tracking) == "table" and tracking or {}
end

function PRMileageTrackingSet(vehicle, tracking, replicated, options)
    if type(tracking) ~= "table" then return false, "invalid_tracking" end
    options = type(options) == "table" and options or {}
    options.maxPayloadBytes = 2048
    return setState(vehicle, "vehicleMileageTracking", tracking, replicated, options)
end
