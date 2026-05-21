fx_version 'cerulean'
game 'gta5'

author 'SKIZO (Universal Version)'
description 'BedHauler — Load motorcycles & quads onto pickup trucks | Universal (QBCore/ESX/VRP/Standalone)'
version '1.0.0'

shared_scripts {
    'config.lua',
    'custom_offsets.lua'
}

client_scripts {
    'bridge_client.lua',
    'client.lua'
}

server_scripts {
    'bridge_server.lua',
    'server.lua'
}

data_file 'DLC_ITYP_REQUEST' 'stream/dwk_moto_rope.ytyp'
