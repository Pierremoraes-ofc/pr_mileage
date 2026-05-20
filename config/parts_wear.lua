-- ============================================================
--   pr_mileage — CONFIGURAÇÃO DO SISTEMA DE DESGASTE
-- ============================================================

WearConfig = {}

-- Intervalo do loop de desgaste no client (em ms)
-- Recomendado: 1000 (1 segundo) a 5000 (5 segundos)
WearConfig.TickInterval = 1000

-- Salva o desgaste no banco a cada quantos KM rodados com a peça
-- (evita queries excessivas ao banco)
WearConfig.SaveThreshold = 1.0

-- Status de saúde por faixa de % restante
-- Usado nos exports GetPartsStatus / GetParts / GetVehicleParts
WearConfig.StatusThresholds = {
    good     = 0.60,   -- >= 60% → "Boa"
    fair     = 0.30,   -- >= 30% → "Razoável"
    bad      = 0.00,   -- <  30% → "Ruim"
}

WearConfig.StatusLabels = {
    good  = "Boa",
    fair  = "Razoável",
    bad   = "Ruim",
}

-- ============================================================
--   TOGGLES GLOBAIS DE EFEITOS
--   false = efeito desabilitado para TODAS as peças
--   true  = habilitado (cada peça ainda pode não usar o efeito)
-- ============================================================
WearConfig.Effects = {
    particle       = true,   -- Partículas (fumaça, vapor, chamas)
    shake_cam      = true,   -- Vibração de câmera
    apply_force    = true,   -- Força aplicada ao veículo (trancos)
    engine_health  = true,   -- Redução da saúde do motor
    undriveable    = true,   -- Bloquear veículo
    engine_on      = true,   -- Ligar/desligar motor
    stall          = true,   -- Stall aleatório
    tyre_burst     = true,   -- Estouro de pneu
    vehicle_lights = true,   -- Piscar faróis
    indicator      = true,   -- Piscar setas
    rpm_override   = true,   -- Sobrescrever RPM
    steering_scale = true,   -- Limitar direção
    lateral_force  = true,   -- Força lateral (direção puxando)
    -- Caso use script de performance é recomendado desativar esses efeitos ou adaptar para uso de forma eficiente sem gerar conflitos
    handling_float = true,   -- Alterações de handling (tração, freio, suspensão)
    power_mult     = true,   -- Redução de potência
    torque_mult    = true,   -- Redução de torque                                       
}
