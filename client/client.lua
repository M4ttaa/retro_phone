local ESX = exports['es_extended']:getSharedObject()

local phone_data = {
    current_phone = {},
    isOpen = false,
    someone_calling = false,
    calling_a_person = false,
    call_data = {},
}

local function isNotepadOpen()
    if GetResourceState('lucid-notepad') ~= 'started' then return false end
    local ok, res = pcall(function() return exports['lucid-notepad']:isNotePadOpen() end)
    return ok and res or false
end

local function closeInventory()
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:closeInventory()
    end
end

-- Plays a sound from html/assets/sounds/<name>.ogg inside the phone UI
function PlaySoundLocal(name)
    SendNUIMessage({ action = "ACTION_PLAY_SOUND", value = { sound = name, volume = Config.SoundVolume or 0.5 } })
end

RegisterNUICallback('SoundError', function(data, cb)
    print(('[retro_phone] ERROR: could not play sound "%s" - is html/assets/sounds/%s.ogg present and listed in fxmanifest?'):format(data.sound, data.sound))
    cb('ok')
end)

local function removeFromCall()
    if GetResourceState('pma-voice') == 'started' then
        exports['pma-voice']:removePlayerFromCall()
    end
end

-------------------------------------------------------------------------------
-- Opening the phone
-------------------------------------------------------------------------------

RegisterNetEvent('retro_phone:UsePhone', function(info, misscall)
    phone_data.current_phone = info

    SendNUIMessage({ action = "ACTION_SET_MISSINGCALL", value = { misscall = misscall } })
    SendNUIMessage({ action = "ACTION_SET_OWNNUMBER", value = info and info.phone_number or '' })

    if phone_data.someone_calling and next(phone_data.call_data) ~= nil then
        if tostring(phone_data.current_phone.phone_number) == tostring(phone_data.call_data.receiver_number) then
            DisplayPhone(true, "OnSomeoneCalling", phone_data.call_data.transmitter_number)
        else
            DisplayPhone(true, "NoNotificationToDisplay")
        end
    else
        if misscall == 'no_misscall' then
            DisplayPhone(true, "NoNotificationToDisplay")
        else
            DisplayPhone(true, "MissingCall")
        end
    end
end)

RegisterCommand('phone', function()
    if isNotepadOpen() or phone_data.isOpen or IsEntityDead(PlayerPedId()) then return end

    ESX.TriggerServerCallback('retro_phone:HasPhone', function(result)
        if not result.has_phone then
            ESX.ShowNotification('You don\'t have a phone.')
            return
        end

        if phone_data.someone_calling then
            ESX.TriggerServerCallback('retro_phone:GetRingingPhone', function(data)
                ESX.TriggerServerCallback('retro_phone:GetMissingCall', function(misscall)
                    TriggerEvent('retro_phone:UsePhone', data, misscall)
                end)
            end)
        else
            ESX.TriggerServerCallback('retro_phone:GetMissingCall', function(misscall)
                TriggerEvent('retro_phone:UsePhone', result.info, misscall)
            end)
        end
    end)
end)

RegisterKeyMapping('phone', 'Open Phone', 'keyboard', 'M')

-------------------------------------------------------------------------------
-- Call state (server -> client)
-------------------------------------------------------------------------------

RegisterNetEvent('retro_phone:SetCallData', function(call_data)
    if call_data.is_receiver then
        phone_data.someone_calling = true
        if phone_data.isOpen then
            -- phone already open: update the screen to "X Calling You..."
            SendNUIMessage({ action = "ACTION_INCOMING_CALL", value = { number = call_data.transmitter_number } })
        end
    end
    if call_data.is_transmitter then phone_data.calling_a_person = true end
    phone_data.call_data = call_data
end)

RegisterNetEvent('retro_phone:ReceiveCall', function()
    -- ringing sound is sent by the server every 3s (also to players standing nearby)
    phone_data.someone_calling = true
end)

RegisterNetEvent('retro_phone:ReceiveCallPhoneBooths', function()
    phone_data.someone_calling = true
    while phone_data.someone_calling do
        PlaySoundLocal('call_receiver')
        Wait(3000)
    end
end)

-- generic sound event (server -> client)
RegisterNetEvent('retro_phone:PlaySound', function(name)
    PlaySoundLocal(name)
end)

RegisterNetEvent('retro_phone:PlayRing', function()
    PlaySoundLocal('call_transmitter')
end)

RegisterNetEvent('retro_phone:EndCall', function()
    removeFromCall()
    phone_data.someone_calling = false
    phone_data.calling_a_person = false
    phone_data.call_data = {}
    DisplayPhone(false, "EndCall")
end)

RegisterNetEvent('retro_phone:EndCallPhonebooth', removeFromCall)

RegisterNetEvent('retro_phone:CancelCallClient', function()
    phone_data.someone_calling = false
    phone_data.calling_a_person = false
    phone_data.call_data = {}
    DisplayPhone(false, "EndCall")
end)

RegisterNetEvent('retro_phone:SetSomeoneCalling', function(toggle)
    phone_data.someone_calling = toggle
end)

RegisterNetEvent('retro_phone:NotAvaliable', function()
    PlaySoundLocal("call_cant_reach")
end)

RegisterNetEvent('retro_phone:EndSound', function()
    PlaySoundLocal("call_ended")
end)

RegisterNetEvent('retro_phone:SetPlayerCall', function(id)
    phone_data.someone_calling = false
    SendNUIMessage({ action = "ACTION_STOP_SOUNDS" })
    DisplayPhone(true, 'InCall') -- switches to the "phone at ear" animation
    if GetResourceState('pma-voice') == 'started' then
        exports["pma-voice"]:addPlayerToCall(id)
    end
end)

RegisterNetEvent('retro_phone:SetPlayerPhoneboothCall', function(id)
    exports["pma-voice"]:addPlayerToCall(id)
end)

RegisterNetEvent('retro_phone:CallAnim', function()
    StartPhoneAnim('call')
end)

RegisterNetEvent('retro_phone:CloseCall', function()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    if GetResourceState('pma-voice') == 'started' then
        exports['pma-voice']:setCallChannel(0)
    end
end)

-------------------------------------------------------------------------------
-- NUI callbacks: calls
-------------------------------------------------------------------------------

RegisterNUICallback('CloseCall', function(_, cb)
    TriggerServerEvent('retro_phone:EndCall')
    cb('ok')
end)

RegisterNUICallback('DeclineCall', function(_, cb)
    TriggerServerEvent('retro_phone:DeclineCall')
    cb('ok')
end)

RegisterNUICallback('AnswerCall', function(_, cb)
    TriggerServerEvent('retro_phone:AnswerCall')
    cb('ok')
end)

RegisterNUICallback('CancelCall', function(_, cb)
    TriggerServerEvent('retro_phone:CancelCall')
    cb('ok')
end)

RegisterNUICallback('CallPerson', function(data, cb)
    local number = data.number
    ESX.TriggerServerCallback('retro_phone:GetPlayerInfoByPhoneNumber', function(result)
        TriggerServerEvent('retro_phone:CallNumber', number)
        cb({ person = result })
    end, number)
end)

RegisterNUICallback('InsertPhoneInfo', function(data, cb)
    TriggerEvent('ls1975:InsertPhoneInfo', { number = data.number })
    cb('ok')
end)

RegisterNetEvent('ls1975:InsertPhoneInfo', function(data)
    ESX.ShowNotification('Open the phone that you want to make the call')
    SendNUIMessage({ action = "INSERT_DIAL_INFO", value = data.number })
end)

-------------------------------------------------------------------------------
-- NUI callbacks: contacts / history / misc
-------------------------------------------------------------------------------

RegisterNUICallback('GetContacts', function(_, cb)
    ESX.TriggerServerCallback('retro_phone:GetContacts', cb)
end)

RegisterNUICallback('AddContact', function(data, cb)
    ESX.TriggerServerCallback('retro_phone:AddContact', cb, data.name, data.number)
end)

RegisterNUICallback('DeleteContact', function(data, cb)
    ESX.TriggerServerCallback('retro_phone:DeleteContact', cb, data.id)
end)

RegisterNUICallback('GetHistory', function(_, cb)
    ESX.TriggerServerCallback('retro_phone:GetHistory', cb)
end)

RegisterNUICallback('GivePhoneNumber', function(_, cb)
    local player, distance = ESX.Game.GetClosestPlayer()
    if player ~= -1 and distance <= Config.GiveNumberDistance then
        TriggerServerEvent('retro_phone:GiveNumber', GetPlayerServerId(player))
    else
        ESX.ShowNotification('Nobody nearby.')
    end
    cb('ok')
end)

-- While typing in a text field the game must not receive the key presses
RegisterNUICallback('InputFocus', function(data, cb)
    SetNuiFocusKeepInput(phone_data.isOpen and not data.state)
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    DisplayPhone(false, "NoNotificationToDisplay")
    cb('ok')
end)

RegisterCommand('stuckui', function()
    DisplayPhone(false, "NoNotificationToDisplay")
    TriggerEvent('lucid-notepad:Close')
end)

-------------------------------------------------------------------------------
-- UI display
-------------------------------------------------------------------------------

function DisplayPhone(toggle, type, number)
    SetNuiFocus(toggle, toggle)
    phone_data.isOpen = toggle

    if toggle then
        closeInventory()
    end

    if StartPhoneAnim and StopPhoneAnim then
        if toggle then
            StartPhoneAnim(type == 'InCall' and 'call' or 'hold')
        else
            StopPhoneAnim()
        end
    else
        print('[retro_phone] ERROR: animation.lua is missing or outdated (StartPhoneAnim not found)')
    end

    SendNUIMessage({
        action = "ACTION_DISPLAY",
        value = {
            show = toggle,
            type = type,
            number = number or ''
        }
    })

    Wait(800)
    SetNuiFocusKeepInput(toggle)
    if not toggle then
        EnableAllControlActions(0)
    end
end

CreateThread(function()
    while true do
        Wait(0)
        if phone_data.isOpen then
            DisableAllControlActions(0)
            for _, ctrl in ipairs({ 30, 31, 32, 33, 34, 35, 59, 64, 75, 249, 76, 79, 23, 72, 71 }) do
                EnableControlAction(0, ctrl, true)
            end
            DisablePlayerFiring(PlayerPedId(), true)
            DisableControlAction(0, 199, true) -- pause menu
            DisableControlAction(0, 200, true) -- pause menu (ESC)

            if IsEntityDead(PlayerPedId()) then
                DisplayPhone(false, "NoNotificationToDisplay")
            end
        end
    end
end)
