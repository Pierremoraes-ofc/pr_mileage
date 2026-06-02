fx_version "cerulean"
game "gta5"
lua54 "yes"

name        "pr_mileage"
description "Sistema de quilometragem e desgaste de peças"
version     "2.3.3"
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
    -- Scanner: dui.lua DEVE vir antes do scanner.lua
    -- pois scanner.lua usa o global ScannerDUI definido no dui.lua
    "scanner/camera.lua",
    --"scanner/dui.lua",
    "scanner/scanner.lua",
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/server.lua",
    "server/sv_parts.lua",
    "server/version.lua",
}


ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/scanner_ui/index.html',
    'ui/scanner_ui/scanner.js',
    'ui/scanner_ui/scanner.css',
}

data_file 'DLC_ITYP_REQUEST' 'stream/obd.ytyp'