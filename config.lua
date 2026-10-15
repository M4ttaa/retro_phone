Config = {}

-- Inventory item a player must own to use the phone
Config.PhoneItem = 'phone'

-- Prints animation info to the F8 console and enables /phoneanim (set to false when done)
Config.Debug = true

-- Prop held in hand while the phone is open
Config.PhoneProp = 'prop_npc_phone_02'

-- Phone number generation (total length incl. prefix)
Config.NumberLength = 7
Config.NumberPrefix = '55'

-- Seconds a call rings before it becomes a missed call
Config.RingTimeout = 30

-- Seconds the "can't reach" tone plays before the phone closes
Config.UnavailableDelay = 3

-- Max distance (meters) for giving your number to someone
Config.GiveNumberDistance = 3.0

-- Limits per player
Config.MaxContacts = 50
Config.MaxHistory = 20

-- Sounds (html/assets/sounds/*.ogg: call_receiver, call_transmitter, call_cant_reach, call_ended)
Config.SoundVolume = 0.5      -- 0.0 - 1.0
Config.RingDistance = 5.0     -- other players this close hear the ringtone
