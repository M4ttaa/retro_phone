fx_version 'cerulean'
game 'gta5'

description 'retro_phone'

version '1.1.0'

lua54 'yes' -- Add in case you want to use lua 5.4 (https://www.lua.org/manual/5.4/manual.html)




client_scripts {
  'config.lua',
  'client/*.lua' -- Globbing method for multiple files
}

server_scripts {
  'config.lua',
  'server/*.lua' -- Globbing method for multiple files
}


ui_page 'html/index.html'

files {
  'html/index.html',
  'html/css/*.css',
  'html/assets/fonts/*.ttf',
  'html/assets/sounds/*.ogg',

  'html/js/*.js',


}

dependency 'qb-core'