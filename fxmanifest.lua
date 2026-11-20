fx_version "cerulean"
game "gta5"
lua54 "yes"

name        "pr_mileage"
description "Sistema de quilometragem e desgaste de peças"
version     "2.3.4"
author      "PierreMoraes"

dependencies {
    "pr_bridge",
}

shared_scripts {
    "@pr_bridge/init.lua",
    "shared/state.lua",
    "config/func_exported.lua",
    "config/config.lua",
    "config/parts_consumable.lua",
    "config/parts_wear.lua",
    "main.lua",
}

client_scripts {
    "client/client.lua",
    "client/cl_tyres.lua",
    "client/cl_wear.lua",
    "client/cl_parts.lua",
}

server_scripts {
    "server/vehicle_identity.lua",
    "server/server.lua",
    "server/sv_parts.lua",
    "server/version.lua",
}
