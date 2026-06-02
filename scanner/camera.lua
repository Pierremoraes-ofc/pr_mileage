-- ============================================================
--   pr_mileage — SCANNER CAMERA (scanner/camera.lua)
--
--   Sistema de câmera rente ao prop do scanner OBD.
--   Projeta os 4 cantos da tela do prop para coordenadas
--   de tela (0-1) e envia ao HTML via SendNUIMessage,
--   permitindo que o HTML converta cliques em UV da textura.
--
--   Baseado na abordagem do osm-atmdui (benite-atm).
-- ============================================================

local ScannerCamera = {}

ScannerCamera.handle     = nil
ScannerCamera.isActive   = false
ScannerCamera.propEntity = nil   -- o prop na mão do jogador

-- =========================================================================
-- Configuração da câmera
-- Ajuste esses valores para enquadrar bem a tela do seu prop
-- =========================================================================

local CAM_CFG = {
    -- Distância da câmera em relação ao prop (meters)
    distance     = 0.30,
    -- Offset vertical (altura relativa ao osso do prop)
    heightOffset = 0.1,
    -- Offset lateral
    sideOffset   = 0.0,
    -- FOV (graus) — menor = mais zoom
    fov          = 45.0,
    -- Tempo de transição (ms)
    transitionTime = 400,
    -- Pitch inicial (negativo = câmera olhando levemente para baixo)
    initialPitch = -25.0,
    -- Sensibilidade do mouse para ajuste de câmera
    mouseSensitivity = 1.5,
    -- Limites de pitch (quanto pode olhar para cima/baixo)
    pitchUp   = 10.0,
    pitchDown = 10.0,
    -- Limites de yaw (quanto pode girar esquerda/direita)
    yawRange  = 10.0,
}

-- =========================================================================
-- Cantos 3D da tela do prop (offsets locais relativos ao prop)
-- Ordem: TL, TR, BR, BL (sentido horário começando pelo canto superior esquerdo)
-- AJUSTE esses offsets de acordo com o modelo do seu prop!
-- Você pode usar o painel de calibração do HTML (/scancal) para ajustar.
-- =========================================================================

local SCREEN_CORNERS_LOCAL = {
    { x = -0.09, y = 0.001, z =  0.065 },  -- TL (superior esquerdo)
    { x =  0.09, y = 0.001, z =  0.065 },  -- TR (superior direito)
    { x =  0.09, y = 0.001, z = -0.065 },  -- BR (inferior direito)
    { x = -0.09, y = 0.001, z = -0.065 },  -- BL (inferior esquerdo)
}

-- =========================================================================
-- Helpers de quaternion (rotação de vetor pelo heading do prop)
-- =========================================================================

local function quatFromHeading(heading)
    return quat(heading, vector3(0, 0, 1))
end

local function rotateByQuat(v, q)
    local vq = quat(0, v.x, v.y, v.z)
    local r  = q * vq * inv(q)
    return vector3(r.x, r.y, r.z)
end

-- =========================================================================
-- Calcula os 4 cantos da tela do prop em coordenadas de mundo
-- =========================================================================

local function getScreenCornersWorld(propEnt)
    local propCoords  = GetEntityCoords(propEnt)
    local propHeading = GetEntityHeading(propEnt)
    local propQuat    = quatFromHeading(propHeading)

    local corners = {}
    for _, c in ipairs(SCREEN_CORNERS_LOCAL) do
        local rotated = rotateByQuat(vector3(c.x, c.y, c.z), propQuat)
        corners[#corners + 1] = vector3(
            propCoords.x + rotated.x,
            propCoords.y + rotated.y,
            propCoords.z + rotated.z
        )
    end
    return corners
end

-- =========================================================================
-- Projeta os cantos 3D → coordenadas de tela normalizadas (0-1)
-- Retorna nil se algum canto estiver fora da tela
-- =========================================================================

local function projectCornersToScreen(worldCorners)
    local screenCorners = {}
    for _, wc in ipairs(worldCorners) do
        local visible, sx, sy = GetScreenCoordFromWorldCoord(wc.x, wc.y, wc.z)
        if not visible then return nil end
        screenCorners[#screenCorners + 1] = { x = sx, y = sy }
    end
    return screenCorners
end

-- =========================================================================
-- Envia os cantos ao HTML e ativa o modo de interação
-- =========================================================================

local function sendCornersToNUI(screenCorners)
    SendNUIMessage({
        action  = "updatePropCorners",
        corners = screenCorners,
    })
end

local function setInteractionMode(active)
    SendNUIMessage({
        action = "setInteractionMode",
        active = active,
    })
end

-- =========================================================================
-- Cria a câmera attachada ao prop — segue o prop automaticamente
-- sem congelar o player, permitindo movimentação livre
-- =========================================================================

function ScannerCamera.TransitionTo(propEnt)
    if ScannerCamera.isActive then return end
    ScannerCamera.propEntity = propEnt

    local propHeading = GetEntityHeading(propEnt)

    ScannerCamera.handle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamFov(ScannerCamera.handle, CAM_CFG.fov)

    -- FIX: Attacha a câmera ao prop com offset local.
    -- Dessa forma ela segue o prop (e o player) automaticamente,
    -- sem precisar congelar o ped ou recalcular a posição a cada frame.
    -- Parâmetros: cam, entity, offsetX, offsetY, offsetZ, isRelative
    AttachCamToEntity(
        ScannerCamera.handle,
        propEnt,
        CAM_CFG.sideOffset,      -- X lateral
        -CAM_CFG.distance,        -- Y = distância à frente/atrás do prop
        CAM_CFG.heightOffset,     -- Z = altura
        true                      -- offset relativo ao prop (local space)
    )

    local initRot = vec3(CAM_CFG.initialPitch, 0.0, propHeading)
    SetCamRot(ScannerCamera.handle, initRot.x, initRot.y, initRot.z, 2)
    SetCamActive(ScannerCamera.handle, true)
    RenderScriptCams(true, true, CAM_CFG.transitionTime, true, true)

    -- FIX: Removido FreezeEntityPosition — o player pode se mover livremente.
    -- A câmera segue via AttachCamToEntity acima.

    ScannerCamera.isActive = true
    ScannerCamera._initRot = initRot
    ScannerCamera._curRot  = initRot

    -- Ativa o modo de interação no HTML (mostra o overlay de clique)
    setInteractionMode(true)

    -- Inicia o loop da câmera
    ScannerCamera.StartLoop()
end

-- =========================================================================
-- Loop da câmera: atualiza rotação com mouse e projeta cantos ao HTML
-- =========================================================================

function ScannerCamera.StartLoop()
    CreateThread(function()
        while ScannerCamera.isActive and DoesCamExist(ScannerCamera.handle) do

            -- FIX: Desabilita apenas os controles de câmera do GTA (mouse look),
            -- mas mantém WASD/movimento do player funcionando.
            -- Controles 1 (look left/right) e 2 (look up/down) = mouse da câmera nativa.
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)

            -- Lê o mouse para ajuste fino da câmera script
            local mx = GetDisabledControlNormal(0, 1) * CAM_CFG.mouseSensitivity
            local my = GetDisabledControlNormal(0, 2) * CAM_CFG.mouseSensitivity

            -- Atualiza heading de referência com o heading atual do prop,
            -- para que os limites de yaw sempre sejam relativos à orientação do prop
            local currentHeading = GetEntityHeading(ScannerCamera.propEntity)
            ScannerCamera._initRot = vec3(ScannerCamera._initRot.x, ScannerCamera._initRot.y, currentHeading)
            local ir = ScannerCamera._initRot

            ScannerCamera._curRot = vec3(
                math.max(ir.x - CAM_CFG.pitchDown, math.min(ir.x + CAM_CFG.pitchUp,  ScannerCamera._curRot.x - my)),
                ScannerCamera._curRot.y,
                math.max(ir.z - CAM_CFG.yawRange,  math.min(ir.z + CAM_CFG.yawRange, ScannerCamera._curRot.z - mx))
            )
            SetCamRot(ScannerCamera.handle,
                ScannerCamera._curRot.x,
                ScannerCamera._curRot.y,
                ScannerCamera._curRot.z, 2)

            -- Projeta os cantos da tela do prop e envia ao HTML a cada frame
            if ScannerCamera.propEntity and DoesEntityExist(ScannerCamera.propEntity) then
                local worldCorners  = getScreenCornersWorld(ScannerCamera.propEntity)
                local screenCorners = projectCornersToScreen(worldCorners)
                if screenCorners then
                    sendCornersToNUI(screenCorners)
                end
            end

            Wait(0)
        end
    end)
end

-- =========================================================================
-- Volta para a câmera normal
-- =========================================================================

function ScannerCamera.TransitionBack()
    if not ScannerCamera.isActive then return end
    ScannerCamera.isActive = false

    setInteractionMode(false)

    if DoesCamExist(ScannerCamera.handle) then
        RenderScriptCams(false, true, CAM_CFG.transitionTime, true, true)
        DestroyCam(ScannerCamera.handle, false)
        ScannerCamera.handle = nil
    end

    -- FIX: Removido FreezeEntityPosition(false) — não congelamos mais,
    -- então não precisa descongelar.

    ScannerCamera.propEntity = nil
end

-- =========================================================================
-- Cleanup ao parar o resource
-- =========================================================================

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    ScannerCamera.TransitionBack()
end)

-- Exporta globalmente para o scanner.lua usar
_G.ScannerCamera = ScannerCamera