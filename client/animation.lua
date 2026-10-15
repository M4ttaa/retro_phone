-- Native phone animation + prop. No emote menu / ExecuteCommand involved.
-- Globals used by client.lua:
--   StartPhoneAnim('hold' | 'call')   hold = looking at screen, call = phone at ear
--   StopPhoneAnim()
-- Set Config.Debug = true in config.lua to see what happens in the F8 console.

local phoneProp = 0
local activeMode = nil

local ANIMS = {
    ground  = { dict = 'cellphone@',               hold = 'cellphone_text_read_base', call = 'cellphone_call_listen_base' },
    vehicle = { dict = 'anim@cellphone@in_car@ps', hold = 'cellphone_text_read_base', call = 'cellphone_call_listen_base' },
}

local function dbg(...)
    if Config.Debug then print('[retro_phone:anim]', ...) end
end

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then
            print(('[retro_phone:anim] ERROR: animation dictionary "%s" failed to load'):format(dict))
            return false
        end
        Wait(0)
    end
    return true
end

local function getSet()
    return IsPedInAnyVehicle(PlayerPedId(), false) and ANIMS.vehicle or ANIMS.ground
end

local function deleteProp()
    if phoneProp ~= 0 then
        if DoesEntityExist(phoneProp) then DeleteEntity(phoneProp) end
        phoneProp = 0
    end
end

local function createProp()
    deleteProp()

    local model = GetHashKey(Config.PhoneProp)
    if not IsModelInCdimage(model) then
        print(('[retro_phone:anim] ERROR: prop "%s" does not exist (check Config.PhoneProp)'):format(tostring(Config.PhoneProp)))
        return
    end

    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then
            print('[retro_phone:anim] ERROR: phone prop model failed to load')
            return
        end
        Wait(0)
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    phoneProp = CreateObject(model, coords.x, coords.y, coords.z + 0.2, false, false, false)
    SetEntityCollision(phoneProp, false, false)

    local bone = GetPedBoneIndex(ped, 28422)
    AttachEntityToEntity(phoneProp, ped, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
    SetModelAsNoLongerNeeded(model)
    dbg('prop attached')
end

local function playAnim()
    if not activeMode then return end

    local set = getSet()
    if not loadDict(set.dict) then return end

    local ped = PlayerPedId()
    -- 50 = upper body only + player keeps control (can walk while holding the phone)
    TaskPlayAnim(ped, set.dict, set[activeMode], 3.0, 3.0, -1, 50, 0.0, false, false, false)
    dbg('playing', set.dict, set[activeMode])
end

function StartPhoneAnim(mode)
    activeMode = mode or 'hold'

    if phoneProp == 0 or not DoesEntityExist(phoneProp) then
        createProp()
    end
    playAnim()
end

function StopPhoneAnim()
    activeMode = nil

    local ped = PlayerPedId()
    for _, set in pairs(ANIMS) do
        StopAnimTask(ped, set.dict, set.hold, 1.0)
        StopAnimTask(ped, set.dict, set.call, 1.0)
    end
    deleteProp()
    dbg('stopped')
end

-- Re-apply if something interrupts it (vehicle enter/exit, other scripts)
CreateThread(function()
    while true do
        if activeMode then
            local set = getSet()
            if not IsEntityPlayingAnim(PlayerPedId(), set.dict, set[activeMode], 3) then
                playAnim()
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        StopPhoneAnim()
    end
end)

-- /phoneanim  -> toggles the hold animation without opening the phone (debug only)
if Config.Debug then
    local testing = false
    RegisterCommand('phoneanim', function()
        testing = not testing
        if testing then StartPhoneAnim('hold') else StopPhoneAnim() end
        print('[retro_phone:anim] test animation ' .. (testing and 'ON' or 'OFF'))
    end)
end
