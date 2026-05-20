--======================================================
--   pr_mileage — FUNÇÕES EXPORTADAS
--   Funções exportadas para o client de outros scripts
--======================================================
Exported = {}

Exported.rpmOverride_bool = false                       -- true = on exports de outro script via client | false = off usa funcoes internas
Exported.handlingFloat_bool = false                     -- true = on exports de outro script via client | false = off usa funcoes internas
Exported.powerMult_bool = false                         -- true = on exports de outro script via client | false = off usa funcoes internas
Exported.torqueMult_bool = false                        -- true = on exports de outro script via client | false = off usa funcoes internas
Exported.setOriginalHandling_bool = false               -- true = on exports de outro script via client | false = off usa funcoes internas
Exported.resetPartsInstalled_bool = false               -- true = on exports de outro script via client | false = off usa funcoes internas

-- ============================================================
--   RPM OVERRIDE
--   Força RPM do motor
--   @param vehicle - veículo
--   @param params - tabela de parâmetros
--   @param params.value - valor do RPM
--   @return void
-- ============================================================
Exported.rpmOverride = function(vehicle, params)
    if Exported.rpmOverride_bool then
        -- aplique seu exports de rpm override aqui
        --exports["pr_mileage"]:rpmOverride(vehicle, params.value)
    else
        SetVehicleCurrentRpm(vehicle, params.value)
    end
end

-- ============================================================
--   HANDLING FLOAT
--   Altera float de handling
--   @param vehicle - veículo
--   @param params - tabela de parâmetros
--   @param params.field - campo de handling
--   @param params.value - valor do campo
--   @return void
-- ============================================================
Exported.handlingFloat = function(vehicle, params)
    if Exported.handlingFloat_bool then
        -- aplique seu exports de handling float aqui
        --exports["pr_mileage"]:handlingFloat(vehicle, params.field, params.value)
        -- Mola arrebentada (assimétrico — sobe mais do que desce)
exports.pr_stance:ApplySuspensionProfile(vehicle, 0)
exports.pr_stance:BounceSuspension(vehicle, 0.14, -0.14, 750)
    else
        SetVehicleHandlingFloat(vehicle, "CHandlingData", params.field, params.value)
    end
end

-- ============================================================
--   POWER MULT
--   Multiplica potência do motor
--   @param vehicle - veículo
--   @param params - tabela de parâmetros
--   @param params.value - valor da potência
--   @return void
-- ============================================================
Exported.powerMult = function(vehicle, params)
    if Exported.powerMult_bool then
        -- aplique seu exports de power mult aqui
        --exports["pr_mileage"]:powerMult(vehicle, params.value)
    else
        SetVehicleCheatPowerIncrease(vehicle, params.value)
    end
end

-- ============================================================
--   TORQUE MULT
--   Multiplica torque do motor
--   @param vehicle - veículo
--   @param params - tabela de parâmetros
--   @param params.value - valor do torque
--   @return void
-- ============================================================
Exported.torqueMult = function(vehicle, params)
    if Exported.torqueMult_bool then
        -- aplique seu exports de torque mult aqui
        --exports["pr_mileage"]:torqueMult(vehicle, params.value)
    else
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia", params.value)
    end
end


-- ============================================================
--   SET ORIGINAL HANDLING
--   Reseta handling para valores originais
--   @param vehicle - veículo
--   @param params - tabela de parâmetros
--   @param params.fDriveInertia - valor do fDriveInertia
--   @param params.fSuspensionReboundDamp - valor do fSuspensionReboundDamp
--   @param params.fSuspensionCompDamp - valor do fSuspensionCompDamp
--   @param params.fSuspensionForce - valor do fSuspensionForce
--   @param params.fTractionLossMult - valor do fTractionLossMult
--   @param params.fBrakeForce - valor do fBrakeForce
--   @return void
-- ============================================================
Exported.setOriginalHandling = function(vehicle, params)
    if Exported.setOriginalHandling_bool then
        -- aplique seu exports de handling float aqui
        --exports["pr_mileage"]:setOriginalHandling(vehicle, params.field, params.value)
    else
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia", params.fDriveInertia or 1.0)
        -- Reseta suspensão para valores originais do veículo
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionReboundDamp", params.fSuspensionReboundDamp or 2.0)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionCompDamp", params.fSuspensionCompDamp or 1.5)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionForce", params.fSuspensionForce or 1.0)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionLossMult", params.fTractionLossMult or 1.0)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", params.fBrakeForce or 0.7)
    end
end

-- ============================================================
--   RESET PARTS INSTALLED
--   Reseta partes instaladas para valores originais
--   @param vehicle - veículo
--   @param params - tabela de parâmetros
--   @param params.fSuspensionForce - valor do fSuspensionForce
--   @param params.fSuspensionReboundDamp - valor do fSuspensionReboundDamp
--   @param params.fSuspensionCompDamp - valor do fSuspensionCompDamp
--   @param params.fSuspensionRaise - valor do fSuspensionRaise
--   @param params.fSuspensionUpperLimit - valor do fSuspensionUpperLimit
--   @param params.fSuspensionLowerLimit - valor do fSuspensionLowerLimit
--   @param params.fTractionLossMult - valor do fTractionLossMult
--   @param params.fBrakeForce - valor do fBrakeForce
--   @param params.fDriveInertia - valor do fDriveInertia
--   @return void
-- ============================================================
Exported.resetPartsInstalled = function(vehicle, params)
    if Exported.resetPartsInstalled_bool then
        -- aplique seu exports de reset parts installed aqui
        --exports["pr_mileage"]:resetPartsInstalled(vehicle)
    else
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionForce",       params.fSuspensionForce      or 1.0)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionReboundDamp", params.fSuspensionReboundDamp or 2.0)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionCompDamp",    params.fSuspensionCompDamp   or 1.5)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionRaise",       params.fSuspensionRaise      or 0.0)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionUpperLimit",  params.fSuspensionUpperLimit or 0.1)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionLowerLimit",  params.fSuspensionLowerLimit or -0.1)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionLossMult",      params.fTractionLossMult     or 1.0)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce",            params.fBrakeForce           or 0.7)
        SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia",          params.fDriveInertia         or 1.0)

        --exports.pr_stance:StopBounce(vehicle)
    end
end