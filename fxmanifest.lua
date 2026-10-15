fx_version 'cerulean'
game 'gta5'

description 'retro_phone (ESX)'
version '2.1.0'

lua54 'yes'

shared_script 'config.lua'

client_scripts {
  'client/*.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/*.lua'
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/css/*.css',
  'html/js/*.js',
  'html/assets/*.png',          -- phone.png lives here
  'html/assets/fonts/*.ttf',
  'html/assets/sounds/*.ogg',
}

dependencies {
  'es_extended',
  'oxmysql'
}
