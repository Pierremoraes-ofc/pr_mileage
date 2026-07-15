-------------------------------------------------------------------------
-- Scanner DUI Test — Client Logic
-- Resource standalone para testes de textura DUI no scanner forense
-------------------------------------------------------------------------

local scannerDui            = nil
local scannerDuiHandle      = nil
local scannerTxd            = nil
local scannerTxn            = nil
local isScannerActive       = false
local debugMode             = false
local propEntity            = nil
local scanVehicle           = nil

-- Estado do scanner (espelha o DUI)
local scannerState         = 'waiting'
local lastScannerData      = nil
local interactionMode      = false

-- Cantos da tela do prop em espaço local (TL, TR, BR, BL)
-- Extraídos do ZModeler — vector3(lx=X, ly=-Z_depth, lz=Y_up)
local SCREEN_CORNERS_LOCAL = {
    vector3(-0.1191, -0.0198, 0.0854),  -- TL (sup-esq)
    vector3(0.1402, -0.0198, 0.0884),   -- TR (sup-dir)
    vector3(0.1412, -0.0208, -0.0385),  -- BR (inf-dir)
    vector3(-0.1181, -0.0198, -0.0375), -- BL (inf-esq)
}

-- Configuração editável
local CONFIG               = {
    DUI_WIDTH    = 1024,
    DUI_HEIGHT   = 1024,
    -- Agora o alvo é a ARMA/PROP (stream):
    TEXTURE_DICT = "m24_1_prop_m41_orbital_term_01a",
    TEXTURE_NAME = "orbital_screen",
    TXD_NAME     = "scantest_txd",
    TXN_NAME     = "scantest_txn",
    ANIM_DICT    = "weapons@misc@digi_scanner",
    ANIM_NAME    = "aim_med_loop",


    PROP_MODEL    = "m24_1_prop_m41_orbital_term_01a",
    PROP_BONE     = 60309,   -- IK_L_Hand
    PROP_OFFSET   = vector3(-0.003, -0.04, 0.0),
    PROP_ROTATION = vector3(0.0, 0.0, 0.0),

    -- Animação de segurar o scanner
    EMOTE_DICT = "amb@world_human_tourist_mobile@male@base",
    EMOTE_NAME = "base",
    EMOTE_FLAG = 49,
}

-- =========================================================================
-- Notificação
-- =========================================================================

local function notify(msg, ntype)
    if lib and lib.notify then
        lib.notify({ title = "Scanner OBD", description = msg, type = ntype or "inform", position = Config.Notfy.position, duration = Config.Notfy.duration })
    else
        TriggerEvent("chat:addMessage", { color = {0,200,255}, args = {"[Scanner OBD]", msg} })
    end
end

-- =========================================================================
-- DUI Lifecycle
-- =========================================================================

local function destroyDui()
    if scannerDui then
        --  stop animation
        local ped = PlayerPedId()
        StopAnimTask(ped, CONFIG.EMOTE_DICT, CONFIG.EMOTE_NAME, 1.0)


        -- Fecha capô
        if scanVehicle and DoesEntityExist(scanVehicle) then
            SetVehicleDoorShut(scanVehicle, 4, false)
            scanVehicle = nil
        end

        Wait(300)

        -- Remove prop
        if propEntity and DoesEntityExist(propEntity) then
            DetachEntity(propEntity, true, true)
            DeleteObject(propEntity)
            propEntity = nil
        end

        --  destroy cam
        if ScannerCamera then ScannerCamera.TransitionBack() end

        --  destroy DUI
        RemoveReplaceTexture(CONFIG.TEXTURE_DICT, CONFIG.TEXTURE_NAME)
        DestroyDui(scannerDui)
        scannerDui = nil
        scannerDuiHandle = nil
        scannerTxd = nil
        scannerTxn = nil
        print("[scannerdui] DUI destroyed")
    end
end

local function createDui()
    if scannerDui then return scannerDui end

    local url = ("nui://%s/ui/scanner_ui/index.html?dui=1"):format(GetCurrentResourceName())
    scannerDui = CreateDui(url, CONFIG.DUI_WIDTH, CONFIG.DUI_HEIGHT)
    scannerDuiHandle = GetDuiHandle(scannerDui)

    scannerTxd = CreateRuntimeTxd(CONFIG.TXD_NAME)
    scannerTxn = CreateRuntimeTextureFromDuiHandle(scannerTxd, CONFIG.TXN_NAME, scannerDuiHandle)

    AddReplaceTexture(CONFIG.TEXTURE_DICT, CONFIG.TEXTURE_NAME, CONFIG.TXD_NAME, CONFIG.TXN_NAME)
    print("[scannerdui] DUI created (" .. CONFIG.DUI_WIDTH .. "x" .. CONFIG.DUI_HEIGHT .. ")")
    return scannerDui
end

local function sendToDui(data)
    if scannerDui then
        SendDuiMessage(scannerDui, json.encode(data))
        -- Espelha o estado para o Lua
        local action = data.action
        if action == 'showScannerApp' then
            scannerState = 'idle'
            if data.data then lastScannerData = data.data end
        elseif action == 'setScannerState' and data.data then
            scannerState = data.data.state or scannerState
        elseif action == 'setScannerResult' then
            scannerState = 'result'
        elseif action == 'hideScannerApp' then
            scannerState = 'waiting'
        end
    end
end

-- =========================================================================
-- Detecção automática de alvo (veículo / jogador mais próximo)
-- =========================================================================

local currentTarget = nil
local SCAN_RANGE    = 15.0 -- Aumentado para 15m (Raycast é mais preciso)
local interactCam   = nil

-- Raycast para detectar alvo na mira do scanner
local function GetTargetInView()
    local ped = PlayerPedId()
    local camCoord = GetGameplayCamCoords()
    local camRot = GetGameplayCamRot(0)

    local adjustedRotation = {
        x = (math.pi / 180) * camRot.x,
        y = (math.pi / 180) * camRot.y,
        z = (math.pi / 180) * camRot.z
    }
    local direction = vector3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )

    local targetCoord = camCoord + (direction * SCAN_RANGE)
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(camCoord.x, camCoord.y, camCoord.z, targetCoord.x,
        targetCoord.y, targetCoord.z, 3, ped, 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)

    if hit and entityHit ~= 0 then
        local dist = #(camCoord - endCoords)
        local entityType = GetEntityType(entityHit)

        if entityType == 2 then -- Veículo
            return {
                type     = 'vehicle',
                entity   = entityHit,
                netId    = VehToNet(entityHit),
                plate    = GetVehicleNumberPlateText(entityHit),
                model    = GetDisplayNameFromVehicleModel(GetEntityModel(entityHit)),
                distance = string.format("%.1f", dist),
            }
        elseif entityType == 1 then -- Player/Ped
            local playerIndex = NetworkGetPlayerIndexFromPed(entityHit)
            if playerIndex ~= -1 then
                return {
                    type     = 'person',
                    entity   = entityHit,
                    serverId = GetPlayerServerId(playerIndex),
                    targetId = GetPlayerServerId(playerIndex),
                    distance = string.format("%.1f", dist),
                }
            end
        end
    end
    return nil
end

CreateThread(function()
    while true do
        Wait(250)
        if not isScannerActive then
            currentTarget = nil
            goto skipTarget
        end

        -- Scanner ativo com veículo linkado: não deixa o raycast sobrescrever currentTarget
        if isScannerActive and currentTarget then
            goto skipTarget
        end

        if scannerState == 'scanning' or scannerState == 'result' then
            goto skipTarget
        end

        local newTarget = GetTargetInView()

        if newTarget then
            if not currentTarget or currentTarget.entity ~= newTarget.entity then
                currentTarget = newTarget
                if scannerState == 'waiting' or scannerState == 'idle' then
                    local duiData = { type = newTarget.type, distance = newTarget.distance }
                    if newTarget.type == 'vehicle' then
                        duiData.plate = newTarget.plate
                        duiData.model = newTarget.model
                    else
                        duiData.targetId = newTarget.targetId
                    end
                    sendToDui({ action = 'showScannerApp', data = duiData })
                end
            end
        else
            if currentTarget then
                currentTarget = nil
                sendToDui({ action = 'hideScannerApp' })
            end
        end

        ::skipTarget::
    end
end)

-- Recebe resultado do servidor e exibe na DUI
RegisterNetEvent('pr_mileage:scanResult', function(result)
    -- Se for um veículo, adicionamos dados reais de telemetria/diagnóstico
    if result.type == 'vehicle' and currentTarget and currentTarget.entity then
        local veh = currentTarget.entity
        if DoesEntityExist(veh) then
            result.bodyHealth = math.floor(GetVehicleBodyHealth(veh) / 10) -- 0-100%
            result.engineHealth = math.floor(GetVehicleEngineHealth(veh) / 10)
            result.fuelLevel = math.floor(GetVehicleFuelLevel(veh) or 0)

            -- Velocidade Máxima teórica
            local topSpeedKmH = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveMaxFlatVel') * 3.6
            result.topSpeed = math.floor(topSpeedKmH)
        end
    end

    sendToDui({ action = 'setScannerResult', data = result })
end)

-- =========================================================================
-- Animação de conectar o scanner ao veículo
-- =========================================================================

local function hasScanner()
    if GetResourceState("ox_inventory") == "started" then
        local count = exports.ox_inventory:GetItemCount("scanner_odb")
        return count and count > 0
    elseif GetResourceState("qs-inventory") == "started" then
        local items = exports["qs-inventory"]:GetInventory()
        if items then
            for _, item in ipairs(items) do
                if item.name == "scanner_odb" and item.amount > 0 then return true end
            end
        end
        return false
    elseif GetResourceState("qb-core") == "started" then
        local QBCore = exports["qb-core"]:GetCoreObject()
        local player = QBCore.Functions.GetPlayerData()
        if player and player.items then
            for _, item in pairs(player.items) do
                if item and item.name == "scanner_odb" and item.amount > 0 then return true end
            end
        end
        return false
    end
    return true
end

local function loadModel(model)
    local hash = type(model) == "number" and model or GetHashKey(model)
    if not IsModelValid(hash) then
        print("^1[scanner] Modelo inválido: " .. tostring(model) .. "^0")
        return nil
    end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) do
        Wait(50); t = t + 50
        if t > 5000 then
            print("^1[scanner] Timeout ao carregar modelo^0")
            return nil
        end
    end
    return hash
end

local function spawnProp()
    local ped  = PlayerPedId()
    local hash = loadModel(CONFIG.PROP_MODEL)
    if not hash then return nil end
    local prop = CreateObject(hash, 0, 0, 0, true, true, false)
    AttachEntityToEntity(
        prop, ped,
        GetPedBoneIndex(ped, CONFIG.PROP_BONE),
        CONFIG.PROP_OFFSET.x, CONFIG.PROP_OFFSET.y, CONFIG.PROP_OFFSET.z,
        CONFIG.PROP_ROTATION.x, CONFIG.PROP_ROTATION.y, CONFIG.PROP_ROTATION.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(hash)
    return prop
end

local function loadAnimDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) do
        Wait(50); t = t + 50
        if t > 5000 then return false end
    end
    return true
end

function InitDui(vehicle)
    if vehicle then
        sleep = 500
        createDui()
        if not isScannerActive then
            isScannerActive = true

            local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+", ""):upper()
            local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))

            -- Trava currentTarget no veículo conectado
            currentTarget = {
                type     = 'vehicle',
                entity   = vehicle,
                netId    = VehToNet(vehicle),
                plate    = plate,
                model    = model,
                distance = '2.0',
            }

            -- Busca peças e envia loading em thread separada para não bloquear a câmera
            CreateThread(function()
                -- Aguarda DUI carregar
                Wait(1500)

                -- Busca km e peças do veículo conectado
                local vehicleKm = 0
                local km = lib.callback.await("pr_mileage:cb:getMileage", false, plate)
                if km and km > 0 then vehicleKm = km end

                local partsLabels = {}  -- só labels para o loading animation
                local partsData   = {}  -- label + percent/status para a tela de status

                -- Monta lookup da blacklist para filtragem O(1)
                local blacklist = {}
                if Config.BacklistItemDesgaste then
                    for _, itemName in ipairs(Config.BacklistItemDesgaste) do
                        blacklist[itemName] = true
                    end
                end

                local parts = lib.callback.await("pr_mileage:cb:getVehicleParts", false, plate, vehicleKm)
                if parts and type(parts) == "table" then
                    for partKey, info in pairs(parts) do
                        -- Ignora peças que estão na blacklist
                        if not blacklist[partKey] then
                            local label = Parts.Items[partKey] and Parts.Items[partKey].labelItem or partKey
                            partsLabels[#partsLabels + 1] = label
                            partsData[#partsData + 1] = {
                                label   = label,
                                percent = info.percent or 0,
                                status  = info.status  or "",
                            }
                        end
                    end
                end

                local displayMode = (Config.Scanner and Config.Scanner.DisplayMode) or 'progress'

                sendToDui({ action = 'startLoading', data = {
                    plate       = plate,
                    model       = model,
                    parts       = partsLabels,
                    partsData   = partsData,
                    duration    = Config.Scanner and Config.Scanner.ScanDuration or 10,
                    displayMode = displayMode,
                }})
                print("[scannerdui] Scanner conectado ao veículo " .. plate .. " (" .. model .. ") — " .. #partsLabels .. " peças")
            end)
        end
    else
        if isScannerActive then
            isScannerActive = false
            currentTarget   = nil
            sendToDui({ action = 'hideScannerApp' })
            destroyDui()
        end
    end
end

local function animConnect(vehicle)
    scanVehicle     = vehicle

    -- verifica o player tem o item
    if not hasScanner() then
        SetVehicleDoorShut(vehicle, 4, false)
        isScannerActive = false
        scannerVehicle  = nil
        notify("Você não possui o Scanner OBD-II.", "error")
        return
    end

    SetVehicleDoorOpen(scanVehicle, 4, false, false)
    Wait(800)
    local ped  = PlayerPedId()
    local dict = "mini@repair"
    local name = "fixing_a_ped"
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 3000 do Wait(100); t = t + 100 end
    if not HasAnimDictLoaded(dict) then return end
    TaskPlayAnim(ped, dict, name, 8.0, -8.0, 3000, 0, 0, false, false, false)
    Wait(3200)
    StopAnimTask(ped, dict, name, 4.0)

    -- 2. Animação de segurar
    if loadAnimDict(CONFIG.EMOTE_DICT) then
        TaskPlayAnim(ped, CONFIG.EMOTE_DICT, CONFIG.EMOTE_NAME, 2.0, -1.0, -1, CONFIG.EMOTE_FLAG, 0, false, false, false)
    end

    Wait(400)
    -- 3. Spawna prop na mão
    propEntity = spawnProp()
    if not propEntity then
        print("^1[scanner] Falha ao spawnar prop^0")
        StopAnimTask(ped, CONFIG.EMOTE_DICT, CONFIG.EMOTE_NAME, 1.0)
        SetVehicleDoorShut(scanVehicle, 4, false)
        return
    end

    --  Inicia a Dui
    InitDui(scanVehicle)

    --  Camera rente ao prop
    if ScannerCamera then
        ScannerCamera.TransitionTo(propEntity)
    end
end
-- =========================================================================
-- Auto-detection loop (detecta o prop na mão)
-- =========================================================================

CreateThread(function()
    Wait(1000)
    local added = false

    if GetResourceState("ox_target") == "started" then
        exports.ox_target:addGlobalVehicle({
            {
                name        = "pr_scanner_obd",
                icon        = "fas fa-stethoscope",
                label       = "Conectar Scanner OBD",
                distance    = 2.0,
                bones       = { "bonnet" },
                canInteract = function() return not isScannerActive end,
                onSelect    = function(data)
                    --  animacao no veiculo
                    animConnect(data.entity)
                end,
            }
        })
        added = true
        print("^2[scanner] Target → ox_target^0")

    elseif GetResourceState("qb-target") == "started" then
        exports["qb-target"]:AddGlobalVehicle({
            options = {{
                num         = 1,
                label       = "Conectar Scanner OBD",
                icon        = "fas fa-stethoscope",
                action      = function(entity)
                    --  animacao no veiculo
                    animConnect(entity)
                end,
                canInteract = function(_, dist)
                    return dist < 2.0 and not isScannerActive
                end,
            }},
            distance = 2.0,
        })
        added = true
        print("^2[scanner] Target → qb-target^0")
    end
    if not added then
        print("^3[scanner] Sem target → usando [E]^0")
        while true do
            Wait(0)
            if isScannerActive then Wait(500) goto cont end
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)
            for _, veh in ipairs(GetGamePool("CVehicle")) do
                if DoesEntityExist(veh) and not IsEntityDead(veh) then
                    local bi  = GetEntityBoneIndexByName(veh, "bonnet")
                    local pos = bi ~= -1
                        and GetWorldPositionOfEntityBone(veh, bi)
                        or  GetOffsetFromEntityInWorldCoords(veh, 0, 2.0, 0.5)
                    if #(coords - pos) < 2.5 then
                        BeginTextCommandDisplayHelp("STRING")
                        AddTextComponentSubstringPlayerName("~INPUT_CONTEXT~ Conectar Scanner OBD")
                        EndTextCommandDisplayHelp(0, false, true, -1)
                        if IsControlJustPressed(0, 51) then
                            local v = veh
                            CreateThread(function() animConnect(v) end)
                        end
                        break
                    end
                end
            end
            ::cont::
        end
    end
end)

-- =========================================================================
-- Comandos de Teste
-- =========================================================================

-- /givescanner — Te dá a arma do scanner e a seleciona automaticamente
RegisterCommand('givescanner', function()
    local ped = PlayerPedId()
    local hash = CONFIG.WEAPON_HASH

    -- Dá a "arma" ao jogador (1 bala é o suficiente)
    GiveWeaponToPed(ped, hash, 1, false, true)

    -- Força o personagem a equipar a arma agora
    SetCurrentPedWeapon(ped, hash, true)

    print("[scannerdui] Scanner entregue e selecionado!")
end, false)

-- /scantest [state] — Força um estado na DUI
RegisterCommand('scantest', function(_, args)
    local state = args[1] or 'idle'

    createDui()
    isScannerActive = true

    if state == 'idle' then
        sendToDui({
            action = 'showScannerApp',
            data = { type = 'vehicle', distance = '1.5', plate = 'BRA2E19', model = 'SULTAN' }
        })
    elseif state == 'person' then
        sendToDui({
            action = 'showScannerApp',
            data = { type = 'person', distance = '0.8', targetId = 42 }
        })
    elseif state == 'scan' then
        sendToDui({
            action = 'setScannerState',
            data = { state = 'scanning' }
        })
    elseif state == 'result_pos' then
        sendToDui({
            action = 'setScannerResult',
            data = { type = 'person', gsr = true, targetName = 'John Doe', dateTime = '05/04/2026 01:23' }
        })
    elseif state == 'result_neg' then
        sendToDui({
            action = 'setScannerResult',
            data = { type = 'person', gsr = false, targetName = 'Jane Doe', dateTime = '05/04/2026 01:23' }
        })
    elseif state == 'result_veh' then
        sendToDui({
            action = 'setScannerResult',
            data = { type = 'vehicle', dna = 'DNA-MATCH-001', plate = 'BRA2E19', model = 'SULTAN', dateTime = '05/04/2026 01:23' }
        })
    elseif state == 'error' then
        sendToDui({
            action = 'setScannerResult',
            data = { type = 'vehicle', error = 'Veículo não sincronizado', dateTime = '05/04/2026 01:23' }
        })
    end

    print("[scannerdui] Estado forçado: " .. state)
end, false)

-- /scanstop — Destrói a DUI
RegisterCommand('scanstop', function()
    isScannerActive = false
    destroyDui()
    print("[scannerdui] DUI parada")
end, false)

-- /scandebug — Abre os controles de debug via NUI overlay
RegisterCommand('scandebug', function()
    debugMode = not debugMode
    if debugMode then
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'toggleDebugPanel', data = { visible = true } })
        print("[scannerdui] Debug panel ABERTO (NUI focus ativo)")
    else
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'toggleDebugPanel', data = { visible = false } })
        print("[scannerdui] Debug panel FECHADO")
    end
end, false)

-- /scanres WxH — Muda a resolução da DUI em tempo real
RegisterCommand('scanres', function(_, args)
    local w = tonumber(args[1]) or 1024
    local h = tonumber(args[2]) or 1024

    CONFIG.DUI_WIDTH = w
    CONFIG.DUI_HEIGHT = h

    -- Recria a DUI com nova resolução
    destroyDui()
    Wait(100)
    createDui()

    -- Re-envia estado idle
    sendToDui({
        action = 'showScannerApp',
        data = { type = 'vehicle', distance = '1.5', plate = 'TST1234', model = 'SULTAN' }
    })

    print("[scannerdui] Resolução alterada para " .. w .. "x" .. h)
end, false)

-- /scantexture dict name — Muda a textura alvo em tempo real
RegisterCommand('scantexture', function(_, args)
    local dict = args[1] or CONFIG.TEXTURE_DICT
    local name = args[2] or CONFIG.TEXTURE_NAME

    destroyDui()
    Wait(100)

    CONFIG.TEXTURE_DICT = dict
    CONFIG.TEXTURE_NAME = name

    createDui()
    sendToDui({
        action = 'showScannerApp',
        data = { type = 'vehicle', distance = '1.5', plate = 'TST1234', model = 'SULTAN' }
    })

    print("[scannerdui] Textura alvo: " .. dict .. " / " .. name)
end, false)

-- NUI Callback — Fecha debug panel
RegisterNUICallback('closeDebugPanel', function(_, cb)
    debugMode = false
    SetNuiFocus(false, false)
    -- Esconde as linhas azuis de calibração na NUI
    SendNUIMessage({ action = 'setInteractionLines', visible = false })
    cb('ok')
end)

-- NUI Callback — Sincroniza clique na engrenagem da arma com as linhas da NUI
RegisterNUICallback('onInternalDebugToggle', function(data, cb)
    SendNUIMessage({ action = 'setInteractionLines', visible = data.visible })
    cb('ok')
end)

RegisterNUICallback('updateDuiTransform', function(data, cb)
    if scannerDui then
        SendDuiMessage(scannerDui, json.encode({ action = 'applyTransform', data = data }))
    end

    -- Ajuste de Zoom (FOV) EM TEMPO REAL via Scandebug
    if data.fov then
        Config.interactFov = data.fov + 0.0
        if interactCam and DoesCamExist(interactCam) then
            SetCamFov(interactCam, Config.interactFov)
            -- Força atualização do estado da câmera para aplicar o novo FOV na hora
            SetCamActive(interactCam, true)
        end
    end
    cb('ok')
end)

-- NUI Callback — Troca de estado via debug panel
RegisterNUICallback('debugSetState', function(data, cb)
    if scannerDui then
        SendDuiMessage(scannerDui, json.encode(data))
    end
    cb('ok')
end)
-- NUI Callback — Recebe aviso de config copiada
RegisterNUICallback('copyConfig', function(data, cb)
    lib.notify({
        title = 'Scanner Debug',
        description = 'Configuração copiada para o Clipboard!',
        type = 'success'
    })
    print("^2[Scanner] Configuração copiada:^7 " .. (data.config or "{}"))
    cb('ok')
end)

-- =========================================================================
-- Interação por clique no prop (projeção 3D → 2D)
-- =========================================================================

local function localToWorld(f, r, u, pos, lx, ly, lz)
    return
        pos.x + r.x * lx + f.x * ly + u.x * lz,
        pos.y + r.y * lx + f.y * ly + u.y * lz,
        pos.z + r.z * lx + f.z * ly + u.z * lz
end

local function findOrbitalProp()
    local ped = PlayerPedId()
    local handle, prop = FindFirstObject()
    local success
    repeat
        if GetEntityAttachedTo(prop) == ped then
            local model = GetEntityModel(prop)
            if model == GetHashKey("m24_1_prop_m41_orbital_term_01a") or model == GetHashKey("obd") then
                EndFindObject(handle)
                return prop
            end
        end
        success, prop = FindNextObject(handle)
    until not success
    EndFindObject(handle)
    return nil
end

local function setInteractionMode(state)
    interactionMode = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action = 'setInteractionMode', active = state })

    if state then
        -- CRIA CÂMERA DE INSPEÇÃO (ZOOM)
        local ped = PlayerPedId()
        if not interactCam then
            interactCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        end

        -- Posição da câmera: Um pouco à frente da cabeça do player
        local coords = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
        local forward = GetEntityForwardVector(ped)
        local camPos = coords + (forward * 0.35) + vector3(0.0, 0.0, 0.05)

        SetCamCoord(interactCam, camPos.x, camPos.y, camPos.z)
        local rot = GetGameplayCamRot(2)
        SetCamRot(interactCam, rot.x, rot.y, rot.z, 2)
        -- Usa o FOV configurado ou 40.0 de padrão
        local zoomVal = Config.interactFov or 40.0
        SetCamFov(interactCam, zoomVal + 0.0)
        SetCamActive(interactCam, true)
        RenderScriptCams(true, true, 500, true, true) -- Transição suave de 500ms
    else
        -- VOLTA PARA CÂMERA NORMAL
        RenderScriptCams(false, true, 500, true, true)
        if interactCam then
            DestroyCam(interactCam, false)
            interactCam = nil
        end
    end

    print("[scanner] Interaction mode: " .. tostring(state) .. (state and " (ZOOM ATIVO)" or " (ZOOM OFF)"))
end

-- Projeção dos cantos a cada 100ms → envia ao NUI overlay
CreateThread(function()
    while true do
        Wait(100)
        if not isScannerActive then goto continue end

        local prop = findOrbitalProp()
        if not prop then goto continue end

        local f, r, u, pos = GetEntityMatrix(prop)
        local corners = {}
        for _, c in ipairs(SCREEN_CORNERS_LOCAL) do
            local wx, wy, wz = localToWorld(f, r, u, pos, c.x, c.y, c.z)
            local vis, sx, sy = GetScreenCoordFromWorldCoord(wx, wy, wz)
            corners[#corners + 1] = { x = sx, y = sy, visible = vis and 1 or 0 }
        end

        SendNUIMessage({ action = 'updatePropCorners', corners = corners })
        ::continue::
    end
end)

-- =========================================================================
-- Loop de teclas do Scanner OBD
-- E=38  Q=44  ↑=172  ↓=173  BSP=194  ESC=200
-- =========================================================================

local KEY_E   = 38
local KEY_Q   = 44
local KEY_UP  = 172
local KEY_DN  = 173
local KEY_BSP = 194
local KEY_ESC = 200

CreateThread(function()
    while true do
        Wait(0)
        if not isScannerActive then goto skipKeys end

        -- Desabilita as teclas para o jogo enquanto scanner ativo
        DisableControlAction(0, KEY_E,   true)
        DisableControlAction(0, KEY_Q,   true)
        DisableControlAction(0, KEY_UP,  true)
        DisableControlAction(0, KEY_DN,  true)
        DisableControlAction(0, KEY_BSP, true)
        DisableControlAction(0, KEY_ESC, true)

        if IsDisabledControlJustPressed(0, KEY_E) then
            sendToDui({ action = 'keyPress', data = { key = 'E' } })

        elseif IsDisabledControlJustPressed(0, KEY_Q) then
            sendToDui({ action = 'keyPress', data = { key = 'Q' } })

        elseif IsDisabledControlJustPressed(0, KEY_UP) then
            sendToDui({ action = 'keyPress', data = { key = 'UP' } })

        elseif IsDisabledControlJustPressed(0, KEY_DN) then
            sendToDui({ action = 'keyPress', data = { key = 'DOWN' } })

        elseif IsDisabledControlJustPressed(0, KEY_BSP) or IsDisabledControlJustPressed(0, KEY_ESC) then
            -- Fecha o scanner
            isScannerActive = false
            currentTarget   = nil
            scannerState    = 'waiting'
            sendToDui({ action = 'hideScannerApp' })
            destroyDui()
        end

        ::skipKeys::
    end
end)

-- =========================================================================
-- /scancalibrate — calibração interativa dos cantos da tela
-- =========================================================================

local calibrateMode   = false
local calibrateCorner = 1 -- 1=TL 2=TR 3=BR 4=BL

local function cornersToTable()
    local t = {}
    for i, c in ipairs(SCREEN_CORNERS_LOCAL) do
        t[i] = { x = c.x, y = c.y, z = c.z }
    end
    return t
end

local function printCalibratedCorners()
    print("^2[Scanner] Cole os valores abaixo em SCREEN_CORNERS_LOCAL no scanner.lua:^7")
    print("local SCREEN_CORNERS_LOCAL = {")
    local names = { "TL (sup-esq)", "TR (sup-dir)", "BR (inf-dir)", "BL (inf-esq)" }
    for i, c in ipairs(SCREEN_CORNERS_LOCAL) do
        print(string.format("    vector3(%7.4f, %7.4f, %7.4f),  -- %s", c.x, c.y, c.z, names[i]))
    end
    print("}")
end

local function sendCalibrateUpdate()
    local prop = findOrbitalProp()
    if not prop then return end
    local f, r, u, pos = GetEntityMatrix(prop)
    local corners = {}
    for _, c in ipairs(SCREEN_CORNERS_LOCAL) do
        local wx, wy, wz = localToWorld(f, r, u, pos, c.x, c.y, c.z)
        local sx, sy, vis = GetScreenCoordFromWorldCoord(wx, wy, wz)
        corners[#corners + 1] = { x = sx, y = sy, visible = vis and 1 or 0 }
    end
    SendNUIMessage({
        action      = 'updateCalibrateState',
        corners     = corners,
        cornerIndex = calibrateCorner,
        cornerLocal = cornersToTable(),
    })
end

RegisterCommand('scancalibrate', function()
    if not isScannerActive then
        print("^1[Scanner] Use /playemote scanner primeiro!^7")
        return
    end
    calibrateMode = not calibrateMode
    if calibrateMode then calibrateCorner = 1 end
    SendNUIMessage({
        action      = 'setCalibrateMode',
        active      = calibrateMode,
        cornerIndex = calibrateCorner,
        cornerLocal = cornersToTable(),
    })
    if calibrateMode then sendCalibrateUpdate() end
    print("[scanner] Calibração: " .. (calibrateMode and "ATIVA" or "DESATIVADA"))
end, false)

CreateThread(function()
    local KEY_W     = 32  -- Z+
    local KEY_S     = 33  -- Z-
    local KEY_A     = 34  -- X-
    local KEY_D     = 35  -- X+
    local KEY_Q     = 44  -- Y-
    local KEY_E     = 38  -- Y+
    local KEY_Y     = 246 -- próximo canto
    local KEY_ENTER = 191 -- salvar
    local KEY_X     = 73  -- cancelar
    local KEY_SHIFT = 21  -- rápido

    while true do
        Wait(0)
        if not calibrateMode then goto skipCal end

        local step    = IsControlJustPressed(0, KEY_SHIFT) and 0.005 or 0.001
        local c       = SCREEN_CORNERS_LOCAL[calibrateCorner]
        local changed = false

        if IsControlJustPressed(0, KEY_Y) then
            calibrateCorner = (calibrateCorner % 4) + 1
            changed = true
        end

        if IsControlJustPressed(0, KEY_A) then
            SCREEN_CORNERS_LOCAL[calibrateCorner] = vector3(c.x - step, c.y, c.z); changed = true
        elseif IsControlJustPressed(0, KEY_D) then
            SCREEN_CORNERS_LOCAL[calibrateCorner] = vector3(c.x + step, c.y, c.z); changed = true
        end
        c = SCREEN_CORNERS_LOCAL[calibrateCorner]

        if IsControlJustPressed(0, KEY_W) then
            SCREEN_CORNERS_LOCAL[calibrateCorner] = vector3(c.x, c.y, c.z + step); changed = true
        elseif IsControlJustPressed(0, KEY_S) then
            SCREEN_CORNERS_LOCAL[calibrateCorner] = vector3(c.x, c.y, c.z - step); changed = true
        end
        c = SCREEN_CORNERS_LOCAL[calibrateCorner]

        if IsControlJustPressed(0, KEY_Q) then
            SCREEN_CORNERS_LOCAL[calibrateCorner] = vector3(c.x, c.y - step, c.z); changed = true
        elseif IsControlJustPressed(0, KEY_E) then
            SCREEN_CORNERS_LOCAL[calibrateCorner] = vector3(c.x, c.y + step, c.z); changed = true
        end

        if IsControlJustPressed(0, KEY_ENTER) then
            printCalibratedCorners()
            calibrateMode = false
            SendNUIMessage({ action = 'setCalibrateMode', active = false })
        elseif IsControlJustPressed(0, KEY_X) then
            calibrateMode = false
            SendNUIMessage({ action = 'setCalibrateMode', active = false })
        end

        for _, k in ipairs({ KEY_W, KEY_S, KEY_A, KEY_D, KEY_Q, KEY_E, KEY_Y, KEY_ENTER }) do
            --DisableControlAction(0, k, true)
        end

        if changed then sendCalibrateUpdate() end
        ::skipCal::
    end
end)

-- /scancorners — marcadores 3D simples
local showCornerDebug = false
RegisterCommand('scancorners', function()
    showCornerDebug = not showCornerDebug
    print("[scanner] Corner debug: " .. tostring(showCornerDebug))
end, false)

CreateThread(function()
    while true do
        Wait(0)
        if not showCornerDebug or not isScannerActive then goto skip end
        local prop = findOrbitalProp()
        if prop then
            local f, r, u, pos = GetEntityMatrix(prop)
            for i, c in ipairs(SCREEN_CORNERS_LOCAL) do
                local wx, wy, wz = localToWorld(f, r, u, pos, c.x, c.y, c.z)
                DrawMarker(28, wx, wy, wz, 0, 0, 0, 0, 0, 0, 0.008, 0.008, 0.008,
                    255, i == 1 and 255 or 0, i == 1 and 255 or 0, 200,
                    false, true, 2, false, nil, nil, false)
            end
        end
        ::skip::
    end
end)
