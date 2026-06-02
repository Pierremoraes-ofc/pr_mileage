# pr\_mileage

[![pr_bridge](https://img.shields.io/badge/⚡_fivem__bridge-Standalone-green?style=for-the-badge)](https://github.com/Pierremoraes-ofc/pr_bridge)
[![GitBook](https://img.shields.io/badge/📖_Documentação-GitBook-blue?style=for-the-badge)](https://pierremoraes.gitbook.io/home/fivem/pr-mileage)

Sistema completo de **quilometragem** e **desgaste de peças** para servidores FiveM, totalmente **standalone** graças ao [pr_bridge](https://github.com/Pierremoraes-ofc/pr_bridge).

---

## O que é

`pr_mileage` rastreia os quilômetros rodados por cada veículo e aplica um sistema de desgaste real em peças instaladas. Conforme o veículo acumula KM, as peças se deterioram e passam a exibir sintomas físicos e visuais progressivos diretamente no jogo — fumaça no motor, vibração de câmera, pneus estourando, motor engasgando e muito mais.

O sistema foi construído para ser **modular e extensível**: qualquer script externo pode instalar peças, consultar estados e reagir ao desgaste via exports padronizados.

---

## Compatibilidade

O `pr_mileage` é **totalmente standalone** graças ao [pr_bridge](https://github.com/Pierremoraes-ofc/pr_bridge), que abstrai automaticamente o framework ativo no servidor. Não é necessário nenhuma configuração adicional — basta o `pr_bridge` estar instalado e iniciado antes do `pr_mileage`.

| Framework | Tabela de veículos usada | Detectado automaticamente |
|-----------|--------------------------|--------------------------|
| QBCore    | `player_vehicles`        | ✅ |
| QBox      | `player_vehicles`        | ✅ |
| ESX       | `owned_vehicles`         | ✅ |
| ox_core   | `player_vehicles`        | ✅ |
| NDCore    | `player_vehicles`        | ✅ |

**Dependências obrigatórias:** `oxmysql` · `ox_lib` · [`pr_bridge`](https://github.com/Pierremoraes-ofc/pr_bridge)

---

## Instalação

### 1. Instale as dependências

Certifique-se de que os seguintes recursos estão instalados e funcionando no seu servidor:

- [`oxmysql`](https://github.com/overextended/oxmysql)
- [`ox_lib`](https://github.com/overextended/ox_lib)
- [`pr_bridge`](https://github.com/Pierremoraes-ofc/pr_bridge) — responsável por tornar o script standalone

### 2. Copie a pasta

Coloque a pasta `pr_mileage` dentro de `resources/` (ou qualquer subpasta como `[custom]`).

### 3. Execute o SQL

Execute o arquivo do seu framework em `/install/qb.sql` ou `/install/esx.sql`. O SQL adiciona a coluna `mileage` na tabela de veículos e cria a tabela `vehicle_parts`.

### 4. Configure o `server.cfg`

A ordem de inicialização é importante:

```
ensure oxmysql
ensure ox_lib
ensure pr_bridge
ensure pr_mileage
```

> Se preferir executar o SQL manualmente, defina `Config.AutoRunSQL = false` em `config/config.lua`.

### Como o pr_bridge é integrado

O `pr_mileage` importa o bridge diretamente pelo `fxmanifest.lua`:

```lua
shared_scripts {
    "@ox_lib/init.lua",
    "@pr_bridge/bridge/config.lua",
    "@pr_bridge/bridge/init.lua",
    "config/config.lua",
    "config/parts_consumable.lua",
    "config/parts_wear.lua",
    "main.lua",
}
```

Isso disponibiliza a tabela global `Bridge` em todos os arquivos Lua do script, sem necessidade de `require` ou `exports`. O `main.lua` usa `Bridge.framework` para detectar automaticamente qual framework está ativo e determinar a tabela correta de veículos (`player_vehicles` ou `owned_vehicles`).

---

## Banco de Dados

### Coluna `mileage`

Adicionada diretamente na tabela nativa do framework (`player_vehicles` ou `owned_vehicles`). Não cria tabelas extras para o odômetro.

### Tabela `vehicle_parts`

Registra cada peça instalada em cada veículo:

| Coluna         | Tipo           | Descrição |
|----------------|----------------|-----------|
| `id`           | INT (PK)       | Identificador único |
| `plate`        | VARCHAR(10)    | Placa do veículo |
| `part`         | VARCHAR(64)    | Chave da peça (ex: `vela_ignicao`) |
| `stage`        | TINYINT        | Nível da peça (1 = stock, 2 = sport, 3 = race, ...) |
| `installed_km` | DOUBLE         | KM do veículo no momento da instalação |
| `durability`   | DOUBLE         | Durabilidade total sorteada em KM |
| `citizen_id`   | VARCHAR(64)    | CitizenID de quem instalou (NULL = NPC/sistema) |
| `installed_at` | DATETIME       | Data e hora da instalação |
| `updated_at`   | DATETIME       | Última atualização |

> **Por que não há coluna `current_km`?**
> O KM atual da peça é sempre calculado como `vehicle_km − installed_km`. Isso elimina a necessidade de atualizar o valor a cada tick, reduzindo queries ao banco.

---

## Configuração

### `config/config.lua`

```lua
Config.Framework    = "auto"        -- "auto" | "QBCore" | "Qbox" | "ESX"
Config.Unit         = "kilometers"  -- "kilometers" | "miles"
Config.AutoRunSQL   = true          -- executa SQL automaticamente ao iniciar
Config.SaveThreshold = 1.0          -- salva no banco a cada X km rodados
```

**`Config.ClassKmRange`** — define a faixa de KM aleatória para cada classe de veículo que ainda não tem registro no banco. Veículos da rua (sem dono) recebem um KM inicial sorteado dentro desta faixa ao serem descobertos pela primeira vez.

| Classe | Nome           | Faixa padrão (km) |
|--------|----------------|-------------------|
| 0      | Compacts       | 8.000 – 60.000    |
| 1      | Sedans         | 5.000 – 45.000    |
| 2      | SUVs           | 3.000 – 30.000    |
| 3      | Coupes         | 2.000 – 20.000    |
| 4      | Muscle         | 1.000 – 15.000    |
| 5      | Sports Classics| 500 – 10.000      |
| 6      | Sports         | 500 – 8.000       |
| 7      | Super          | 200 – 5.000       |
| 8      | Motorcycles    | 5.000 – 80.000    |
| 9      | Off-road       | 10.000 – 150.000  |
| 10     | Industrial     | 20.000 – 300.000  |
| 17     | Service        | 30.000 – 400.000  |
| 18     | Emergency      | 20.000 – 300.000  |

Classes ignoradas pelo tracker (não acumulam distância): Cycles (13), Boats (14), Helicopters (15), Planes (16), Trains (21), Open Wheel (22).

---

### `config/parts_wear.lua`

```lua
WearConfig.TickInterval  = 1000   -- ms entre cada tick do loop de desgaste
WearConfig.SaveThreshold = 1.0    -- km entre saves de estado das peças

WearConfig.StatusThresholds = {
    good = 0.60,   -- >= 60% → "Boa"
    fair = 0.30,   -- >= 30% → "Razoável"
    bad  = 0.00,   -- <  30% → "Ruim"
}
```

#### Toggles globais de efeitos

Cada efeito pode ser desligado globalmente sem precisar editar as peças:

```lua
WearConfig.Effects = {
    particle       = true,   -- fumaça, vapor, chamas via partículas
    shake_cam      = true,   -- vibração de câmera
    apply_force    = true,   -- força física aplicada ao veículo (trancos)
    handling_float = true,   -- alteração de tração, freio, suspensão
    engine_health  = true,   -- redução da saúde do motor
    power_mult     = true,   -- redução de potência
    torque_mult    = true,   -- redução de torque
    undriveable    = true,   -- bloqueia o veículo completamente
    engine_on      = true,   -- liga/desliga motor
    stall          = true,   -- motor engasga e desliga aleatoriamente
    tyre_burst     = true,   -- estouro de pneu
    vehicle_lights = true,   -- faróis piscando
    indicator      = true,   -- setas piscando com falha
    rpm_override   = true,   -- sobrescreve RPM do motor
    steering_scale = true,   -- limita ângulo de direção
    lateral_force  = true,   -- força lateral (carro puxando para um lado)
}
```

---

### `config/parts_consumable.lua`

Define todas as peças disponíveis, suas durabilidades e os sintomas por nível de desgaste.

**Estrutura de uma peça:**

```lua
Parts.Items = {
    ['vela_ignicao'] = {
        durability = { min = 15000, max = 30000 },  -- KM sorteado na instalação
        symptoms = {
            {
                threshold = 0.50,           -- ativa quando restar <= 50% da durabilidade
                label     = "Falha leve de ignição",
                effects   = {
                    { type = "particle",    params = { dict = "core", name = "ent_sht_steam", bone = "engine", scale = 0.3 } },
                    { type = "shake_cam",   params = { type = "ROAD_VIBRATION_SHAKE", intensity = 0.03 } },
                    { type = "torque_mult", params = { value = 0.90 } },
                },
            },
            -- mais sintomas para 25% e 5%...
        },
    },
}
```

Os sintomas são verificados em ordem crescente de gravidade. O sistema sempre aplica o **sintoma mais severo ativo** — se a peça está em 10%, aplica o sintoma de 10%, não o de 50%.

---

## Sistema de Efeitos

### Tipos disponíveis e como configurar

#### `particle` — Partícula loopada na entidade
```lua
{ type = "particle", params = {
    dict   = "core",           -- asset de partículas (ptfx dict)
    name   = "ent_sht_steam",  -- nome do efeito dentro do dict
    bone   = "engine",         -- bone do veículo onde spawna
    scale  = 0.5,              -- escala da partícula
    offset = vector3(0,0,0),   -- offset opcional
}}
```
**Bones comuns:** `engine`, `bonnet`, `exhaust`, `wheel_lf`, `wheel_rf`, `wheel_lr`, `wheel_rr`

> 🔗 Lista completa de partículas (ptfx): [https://ptfx.dev](https://ptfx.dev) · [Alloc8or PTFX List](https://github.com/alloc8or/gta5-nativedb/blob/master/particleEffects.json)

**Partículas úteis do dict `core`:**

| Nome | Efeito visual |
|------|--------------|
| `ent_sht_steam` | Vapor branco (superaquecimento leve) |
| `ent_amb_smoke_engine` | Fumaça cinza do motor |
| `ent_sht_flame` | Chamas (crítico) |
| `ent_amb_exhaust_smoke` | Fumaça preta no escapamento |
| `veh_backfire` | Backfire no escape |
| `ent_sht_smoke` | Fumaça nos freios/rodas |

---

#### `shake_cam` — Vibração de câmera
```lua
{ type = "shake_cam", params = {
    type      = "ROAD_VIBRATION_SHAKE",  -- tipo de shake
    intensity = 0.05,                    -- 0.0 a 1.0
}}
```

**Tipos de shake disponíveis:**

| Tipo | Sensação |
|------|----------|
| `ROAD_VIBRATION_SHAKE` | Vibração de estrada irregular (mais sutil) |
| `SMALL_EXPLOSION_SHAKE` | Explosão pequena (impacto brusco) |
| `MEDIUM_EXPLOSION_SHAKE` | Explosão média |
| `LARGE_EXPLOSION_SHAKE` | Explosão grande |
| `DRUNK_SHAKE` | Câmera bêbada (oscilatória) |
| `SKY_DIVING_SHAKE` | Turbulência de queda livre |
| `HAND_SHAKE` | Tremor de mão leve |

> 🔗 Referência completa de natives de câmera: [https://nativedb.dotindustries.dev/natives/#0x5C6A6B3B](https://nativedb.dotindustries.dev/natives/#0x5C6A6B3B)

---

#### `apply_force` — Força física no veículo (trancos, instabilidade)
```lua
{ type = "apply_force", params = {
    x         = 0.0,   -- força no eixo X
    y         = 0.0,   -- força no eixo Y
    z         = 0.0,   -- força no eixo Z
    random    = true,  -- aplica direção aleatória (ignora x/y se true)
    intensity = 0.5,   -- magnitude da força aleatória
}}
```
Usa `ApplyForceToEntity` internamente. Ideal para simular trancos de transmissão, instabilidade de suspensão e micro-solavancos.

> 🔗 Native: [ApplyForceToEntity](https://nativedb.dotindustries.dev/natives/#0xC5F68BE9613E2D18)

---

#### `handling_float` — Alteração de handling do veículo
```lua
{ type = "handling_float", params = {
    field = "fBrakeForce",   -- campo de handling a alterar
    value = 0.35,            -- novo valor
}}
```

**Campos úteis de handling:**

| Campo | Efeito |
|-------|--------|
| `fBrakeForce` | Força de frenagem (reduzir = freio ruim) |
| `fTractionLossMult` | Perda de tração (aumentar = escorregadia) |
| `fSuspensionReboundDamp` | Amortecimento da suspensão (rebote) |
| `fSuspensionCompDamp` | Compressão da suspensão |
| `fSuspensionRaise` | Altura da suspensão |

> 🔗 Lista completa de campos de handling: [https://gtamods.com/wiki/Handling.dat](https://gtamods.com/wiki/Handling.dat)

---

#### `tyre_burst` — Pneu furado
```lua
{ type = "tyre_burst", params = {
    wheel = 0,   -- índice da roda
}}
```

| Índice | Roda |
|--------|------|
| 0 | Dianteira esquerda |
| 1 | Dianteira direita |
| 2 | Traseira esquerda |
| 3 | Traseira direita |
| 4 | Roda do meio esquerda (trucks) |
| 5 | Roda do meio direita (trucks) |

---

#### `stall` — Motor engasga e desliga
```lua
{ type = "stall", params = {
    chance = 0.05,   -- probabilidade por tick (5% = ~1x a cada 20 ticks)
}}
```
Desliga o motor por 0.8 a 2 segundos e religar automaticamente. Simula motor falhando por ignição ruim, óleo zerado ou bateria fraca.

---

#### `power_mult` e `torque_mult` — Redução de performance
```lua
{ type = "power_mult",  params = { value = 0.70 } }  -- 70% da potência original
{ type = "torque_mult", params = { value = 0.65 } }  -- 65% do torque original
```
Valores entre `0.0` (sem potência) e `1.0` (potência total). São reaplicados a cada tick.

---

#### `lateral_force` — Direção puxando para um lado
```lua
{ type = "lateral_force", params = {
    value = 0.6,   -- força lateral (positivo = direita, negativo = esquerda)
}}
```
Só é aplicado acima de 2 m/s. Simula direção desalinhada ou desgaste assimétrico de pneus.

---

#### `steering_scale` — Direção travada / limitada
```lua
{ type = "steering_scale", params = {
    value = 0.75,   -- 0.0 = sem direção, 1.0 = normal
}}
```

---

#### `engine_health` — Saúde do motor
```lua
{ type = "engine_health", params = {
    value = 300,   -- 0 a 1000 (1000 = motor perfeito, 0 = destruído)
}}
```
Só reduz — nunca aumenta o valor atual se já estiver mais baixo.

---

#### `undriveable` — Bloqueia o veículo
```lua
{ type = "undriveable", params = { value = true } }
```
Trava completamente o veículo. Usar apenas em estados críticos.

---

#### `vehicle_lights` — Faróis piscando
```lua
{ type = "vehicle_lights", params = {
    state = 2,   -- 0=off, 1=on, 2=flash/pisca
}}
```

---

#### `engine_on` — Liga/desliga motor
```lua
{ type = "engine_on", params = { value = false } }
```

---

## Peças Pré-configuradas

| Peça | Categoria | Durabilidade |
|------|-----------|-------------|
| `vela_ignicao` | Motor | 15k – 30k km |
| `bobina` | Motor | 20k – 40k km |
| `cabo_vela` | Motor | 25k – 50k km |
| `junta_cabecote` | Motor | 60k – 120k km |
| `oil` | Fluidos | 8k – 15k km |
| `embreagem` | Transmissão | 40k – 80k km |
| `caixa_cambio` | Transmissão | 60k – 120k km |
| `pneu_dianteiro_esq` | Pneus | 20k – 50k km |
| `pneu_dianteiro_dir` | Pneus | 20k – 50k km |
| `pneu_traseiro_esq` | Pneus | 20k – 50k km |
| `pneu_traseiro_dir` | Pneus | 20k – 50k km |
| `amortecedor_dianteiro` | Suspensão | 30k – 70k km |
| `amortecedor_traseiro` | Suspensão | 30k – 70k km |
| `pastilha_freio` | Freios | 15k – 30k km |
| `bateria` | Elétrica | 20k – 60k km |
| `direcao` | Direção | 50k – 100k km |
| `filtro_combustivel` | Combustível | 20k – 40k km |
| `bico_injetor` | Combustível | 30k – 60k km |

Novas peças podem ser adicionadas livremente em `config/parts_consumable.lua` — basta seguir a estrutura existente. O `stage` é livre: você pode ter quantos níveis quiser (stock, sport, race, pro...).

---

## Exports

### Client-side

#### Odômetro

```lua
-- KM do veículo que o player está dirigindo agora
exports["pr_mileage"]:getMileage()
-- → number | false

-- KM de qualquer entidade veículo pelo handle
exports["pr_mileage"]:getMileageByEntity(vehicle)
-- → number | false

-- KM por placa (prioriza statebag se o veículo estiver na cena)
exports["pr_mileage"]:getMileageByPlate("ABC1234")
-- → number | false

-- Alias de compatibilidade — retorna (mileage, unit)
exports["pr_mileage"]:GetMileage("ABC1234")
-- → number | false, string

-- Unidade configurada
exports["pr_mileage"]:getUnit()
-- → "kilometers" | "miles"

-- Placa do veículo atual
exports["pr_mileage"]:getVehiclePlate()
-- → string | false

-- Handle do veículo atual
exports["pr_mileage"]:getCurrentVehicle()
-- → integer | false

-- Se o player está no banco do motorista
exports["pr_mileage"]:isDriving()
-- → boolean

-- Se o veículo pertence a um player (banco) ou é da rua (RAM)
exports["pr_mileage"]:isOwnedVehicle()
-- → boolean

-- Classe numérica do veículo atual
exports["pr_mileage"]:getVehicleClass()
-- → integer | false

-- Nome da classe do veículo atual
exports["pr_mileage"]:getVehicleClassName()
-- → string | false

-- Nome da classe de qualquer entidade
exports["pr_mileage"]:getVehicleClassNameByEntity(vehicle)
-- → string | false

-- Marca um veículo como "fresh" (km = 0 ao entrar)
exports["pr_mileage"]:markFresh(vehicle)

-- Zera km do veículo atual
exports["pr_mileage"]:resetCurrentMileage()
```

#### Peças

```lua
-- % restante de uma peça (0–100)
exports["pr_mileage"]:GetPartsPercent("vela_ignicao")
-- → number | false  (ex: 73.5)

-- KM restantes de uma peça
exports["pr_mileage"]:GetPartsMileage("vela_ignicao")
-- → number | false

-- Status de saúde de uma peça
exports["pr_mileage"]:GetPartsStatus("vela_ignicao")
-- → "Boa" | "Razoável" | "Ruim" | false

-- Informações completas de uma peça
exports["pr_mileage"]:GetParts("vela_ignicao")
-- → { part, stage, installed_km, durability, current_km, remaining_km, percent, status, citizen_id, installed_at }

-- Todas as peças do veículo atual
exports["pr_mileage"]:GetVehicleParts()
-- → { [partName] = { ... } }

-- Instala uma peça no veículo atual
exports["pr_mileage"]:installPart("vela_ignicao", 1, "citizenId")

-- Remove uma peça do veículo atual
exports["pr_mileage"]:removePart("vela_ignicao")

-- Força recarregar peças do banco
exports["pr_mileage"]:reloadParts()

-- Placa do veículo atual rastreado pelo sistema de peças
exports["pr_mileage"]:getCurrentPlate()
-- → string | nil
```

#### Peças externas (sem banco — para corridas, pit-stop etc.)

```lua
-- Passa uma tabela estática ou função callback
exports["pr_mileage"]:setExternalParts({
    ['pneu_corrida'] = { installed_km = 0, durability = 30, stage = 3 }
})

-- Ou via função (atualiza a cada tick)
exports["pr_mileage"]:setExternalParts(function()
    return myDynamicPartsTable
end)

-- Remove as peças externas
exports["pr_mileage"]:clearExternalParts()
```

#### Motor de efeitos

```lua
-- Inicia o loop de efeitos passando um callback (forma legada / externa)
exports["pr_mileage"]:startWearEffects(function()
    return { ['peca'] = { current = 800, max = 10000 } }
end)

-- Para todos os efeitos imediatamente
exports["pr_mileage"]:stopWearEffects()

-- Aplica um único efeito manualmente
exports["pr_mileage"]:applyEffect("shake_cam", { type = "ROAD_VIBRATION_SHAKE", intensity = 0.1 })
exports["pr_mileage"]:applyEffect("particle", { dict = "core", name = "ent_sht_steam", bone = "engine", scale = 0.5 }, "vela_ignicao")

-- Para a partícula de uma peça específica
exports["pr_mileage"]:stopPartParticle("vela_ignicao")

-- Definição completa de uma peça (sintomas, durabilidade, efeitos)
exports["pr_mileage"]:getPartDefinition("vela_ignicao")
-- → tabela Parts.Items["vela_ignicao"]

-- Todas as definições
exports["pr_mileage"]:getAllParts()
-- → Parts.Items completo
```

---

### Server-side

#### Odômetro

```lua
-- KM por placa (banco + RAM)
exports["pr_mileage"]:getMileageByPlate("ABC1234")
-- → number | false

-- KM por entidade via statebag
exports["pr_mileage"]:getMileageByEntity(entity)
-- → number | false

-- Unidade configurada
exports["pr_mileage"]:getUnit()
-- → "kilometers" | "miles"

-- Alias de compatibilidade
exports["pr_mileage"]:GetMileage("ABC1234")
-- → number | false, string

-- Verifica se placa existe no banco (veículo de player)
exports["pr_mileage"]:plateExists("ABC1234")
-- → boolean

-- Verifica se placa existe em qualquer lugar (banco ou RAM)
exports["pr_mileage"]:plateRegistered("ABC1234")
-- → boolean

-- Zera mileage de uma placa
exports["pr_mileage"]:resetMileage("ABC1234")

-- Define mileage de uma placa
exports["pr_mileage"]:setMileage("ABC1234", 50000)

-- Top N veículos com mais KM
exports["pr_mileage"]:getTopMileage(10)
-- → { { plate, mileage }, ... }

-- Todos os veículos de um player pelo identifier
exports["pr_mileage"]:getPlayerVehiclesMileage("citizenId123")
-- → { { plate, mileage }, ... }

-- Snapshot dos carros da rua na RAM
exports["pr_mileage"]:getWorldVehicles()
-- → { ["ABC1234"] = 15234.5, ... }

-- Nome da classe de qualquer entidade veículo
exports["pr_mileage"]:getVehicleClassNameByEntity(entity)
-- → string | false
```

#### Peças

```lua
-- % restante de uma peça
exports["pr_mileage"]:GetPartsPercent("ABC1234", "vela_ignicao", vehicleKm)
-- → number | false

-- KM restantes
exports["pr_mileage"]:GetPartsMileage("ABC1234", "vela_ignicao", vehicleKm)
-- → number | false

-- Status de saúde
exports["pr_mileage"]:GetPartsStatus("ABC1234", "vela_ignicao", vehicleKm)
-- → "Boa" | "Razoável" | "Ruim" | false

-- Informações completas de uma peça
exports["pr_mileage"]:GetParts("ABC1234", "vela_ignicao", vehicleKm)
-- → tabela completa | false

-- Todas as peças de um veículo
exports["pr_mileage"]:GetVehicleParts("ABC1234", vehicleKm)
-- → { [partName] = { ... } }

-- Instala uma peça server-side
exports["pr_mileage"]:installPart("ABC1234", "vela_ignicao", 1, vehicleKm, "citizenId")

-- Remove uma peça server-side
exports["pr_mileage"]:removePart("ABC1234", "vela_ignicao")
```

---

## Comandos de Teste

| Comando | Descrição |
|---------|-----------|
| `/km` | Exibe KM, classe e tipo (player/rua) do veículo atual |
| `/kmplaca [PLACA]` | Consulta KM de qualquer placa |
| `/installpeca [nome] [stage]` | Instala uma peça no veículo atual |
| `/removepeca [nome]` | Remove uma peça do veículo atual |
| `/pecas` | Lista todas as peças instaladas com status colorido |

---

## Integração com garagens próprias

Para garantir que veículos saindo da garagem comecem com km zerado, dispare um dos seguintes no seu script de garagem:

```lua
-- Client-side (ao spawnar o veículo)
TriggerEvent("pr_mileage:fresh", vehicle)
-- ou via export:
exports["pr_mileage"]:markFresh(vehicle)

-- Server-side (pela placa)
exports["pr_mileage"]:resetMileage("ABC1234")
```

Hooks automáticos já existem para: `esx_garages`, `esx:vehicleBought`, `QBCore:Client:VehicleSpawned`, `qb-garages:client:takeOutGarage`, `ox_garage:vehicleOut`.

---

## pr_bridge — Como funciona a integração

O [pr_bridge](https://github.com/Pierremoraes-ofc/pr_bridge) é uma biblioteca leve que abstrai a API de múltiplos frameworks, inventários, notificações e outros sistemas em uma interface unificada. Ao integrá-lo ao `pr_mileage`, o script deixa de ter dependência direta de qualquer framework específico.

### O que o bridge resolve no pr_mileage

| Responsabilidade | Sem bridge | Com bridge |
|-----------------|------------|------------|
| Detectar framework ativo | `GetResourceState("qb-core")` manual | `Bridge.framework` automático |
| Tabela de veículos correta | Configuração manual em `main.lua` | Detectada automaticamente |
| CitizenID do player | API diferente em cada framework | `Bridge.framework.GetIdentifier(source)` |
| Compatibilidade futura | Requer alteração de código | Atualizar o bridge resolve |

### Funções do bridge usadas pelo pr_mileage

```lua
-- Detecta o framework e define Framework.VehiclesTable automaticamente
-- (usado em main.lua)
Bridge.framework  -- tabela global disponível após importar o bridge

-- Obtém o CitizenID do player que instalou a peça
-- (usado em sv_parts.lua ao registrar citizen_id)
Bridge.framework.GetIdentifier(source)  -- → "citizenId123"
```

### Como importar o bridge em scripts próprios

Se você quer criar um script que interaja com o `pr_mileage` e também seja standalone, importe o bridge da mesma forma:

```lua
-- fxmanifest.lua do seu script
dependency 'pr_bridge'

shared_scripts {
    '@ox_lib/init.lua',
    '@pr_bridge/bridge/config.lua',
    '@pr_bridge/bridge/init.lua',
    -- seus arquivos de config aqui
}
```

A partir daí, `Bridge` estará disponível globalmente e você pode usar qualquer função — notificações, inventário, framework — sem se preocupar com qual sistema o servidor usa.

### Recursos suportados pelo pr_bridge

| Categoria | Recursos suportados |
|-----------|-------------------|
| Frameworks | NDCore, ox_core, ESX, QBCore, QBox |
| Inventários | ox_inventory, qs-inventory, codem-inventory, origen_inventory, qb-inventory |
| Notificações | ox_lib, ESX, QBCore, GTA Default |
| Targets | ox_target, qb-target |
| Telefones | qs-smartphone, lb-phone, okokPhone, yseries |
| Progressbars | ox_lib, QBCore, ESX |
| Combustível | cdn-fuel, lc_fuel, LegacyFuel |
| Chaves de veículo | mm_carkeys, mri_Qcarkeys, qb-vehiclekeys, qbx_vehiclekeys, wasabi_carlock |

---

## Recursos externos

| Recurso | Link |
|---------|------|
| pr_bridge (standalone) | [github.com/Pierremoraes-ofc/pr_bridge](https://github.com/Pierremoraes-ofc/pr_bridge) |
| Lista de partículas (ptfx) | [ptfx.dev](https://ptfx.dev) |
| NativeDB GTA V | [nativedb.dotindustries.dev](https://nativedb.dotindustries.dev) |
| Campos de handling | [gtamods.com/wiki/Handling.dat](https://gtamods.com/wiki/Handling.dat) |
| Bones de veículos | [GTAV Vehicle Bones](https://github.com/DurtyFree/gta-v-data-dumps/blob/master/vehicleBones.json) |
| Alloc8or PTFX JSON | [github.com/alloc8or/gta5-nativedb](https://github.com/alloc8or/gta5-nativedb/blob/master/particleEffects.json) |