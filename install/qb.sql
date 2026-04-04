ALTER TABLE player_vehicles ADD COLUMN IF NOT EXISTS mileage FLOAT DEFAULT 0 NOT NULL;
-- ============================================================
--   pr_mileage — Tabela de peças instaladas nos veículos
-- ============================================================

CREATE TABLE IF NOT EXISTS `vehicle_parts` (
    `id`              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `plate`           VARCHAR(10)     NOT NULL                    COMMENT 'Placa do veículo',
    `part`            VARCHAR(64)     NOT NULL                    COMMENT 'Identificador da peça (ex: vela_ignicao)',
    `stage`           TINYINT         NOT NULL DEFAULT 1          COMMENT 'Nível/estágio da peça (1=stock, 2=sport, 3=race, ...)',
    `installed_km`    INT UNSIGNED    NOT NULL DEFAULT 0          COMMENT 'KM inteiro do veículo no momento da instalação',
    `durability`      INT UNSIGNED    NOT NULL DEFAULT 0          COMMENT 'Durabilidade total da peça em KM inteiro (sorteado ao instalar)',
    `citizen_id`      VARCHAR(64)     NULL      DEFAULT NULL      COMMENT 'CitizenID de quem instalou (NULL = NPC/sistema)',
    `installed_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Data e hora da instalação',
    `updated_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 
    PRIMARY KEY (`id`),
    UNIQUE KEY  `uq_plate_part` (`plate`, `part`),
    INDEX `idx_plate`      (`plate`),
    INDEX `idx_citizen_id` (`citizen_id`)
 
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
 
-- Se a tabela já existir, migra as colunas de DOUBLE para INT UNSIGNED
ALTER TABLE `vehicle_parts`
    MODIFY COLUMN `installed_km` INT UNSIGNED NOT NULL DEFAULT 0  COMMENT 'KM inteiro do veículo no momento da instalação',
    MODIFY COLUMN `durability`   INT UNSIGNED NOT NULL DEFAULT 0  COMMENT 'Durabilidade total da peça em KM inteiro';