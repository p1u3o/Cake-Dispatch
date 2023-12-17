fx_version 'adamant'
games { 'gta5' }

author 'Pluto'
description 'Police Dispatch'
version '1.0'

ui_page 'html/ui.html'

shared_script 'config.lua'

client_scripts{
    '@prp-lib/client.lua',
    '@icon_menu/lib/IconMenu.lua',
    'client/client.lua',
    'client/functions.lua',
}

server_scripts{
    '@mysql-async/lib/MySQL.lua',
    'server/**/*.lua',
}

files {
    'html/*',
    'html/css/*.css',
    'html/js/*.js',
}

exports {
    'GetPlayerDetails',
    'TriggerEventWithDetails',
    'GetColourName',
    'GetPedDetails'
}

server_exports {
    'GetRoleplayInfo',
    'GetPoliceOnline',
    'ClampOfficers'
}

lua54 'yes'