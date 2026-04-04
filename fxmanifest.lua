fx_version "cerulean"
game "gta5"
lua54 "yes"

name        "pr_mileage"
description "Sistema de quilometragem e desgaste de peças — integrado ao Fivem_bridge"
version     "2.0.0"
author      "PierreMoraes"

dependencies {
    "oxmysql",
    "ox_lib",
    "Fivem_bridge",
}

shared_scripts {
    "@ox_lib/init.lua",

    -- Configs do pr_mileage
    "config/config.lua",
    "config/parts_consumable.lua",
    "config/parts_wear.lua",

    -- main.lua lê ActiveBridges e Bridge que o Fivem_bridge já expõe como globals
    "main.lua",
}

client_scripts {
    "client/client.lua",
    "client/cl_wear.lua",
    "client/cl_parts.lua",
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/server.lua",
    "server/sv_parts.lua",
}