fx_version "cerulean"
game "gta5"
lua54 "yes"

name        "pr_mileage"
description "Sistema de quilometragem e desgaste de peças"
version     "2.3.2"
author      "PierreMoraes"

dependencies {
    "oxmysql",
    "ox_lib",
}

shared_scripts {
    "@ox_lib/init.lua",
    "config/func_exported.lua",
    "config/config.lua",
    "config/parts_consumable.lua",
    "config/parts_wear.lua",
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
    "server/version.lua",
}