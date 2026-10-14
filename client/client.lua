local QBCore = exports['qb-core']:GetCoreObject()

local phone_data = {
    current_phone = {},
    isOpen = false,
    someone_calling = false,
    calling_a_person = false,

    call_data = {};
}


--RegisterCommand('phone', function()
--
--end)
--
--RegisterKeyMapping('phone', 'Open Phone', 'keyboard', 'M')

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.TriggerCallback('sv_phonebooth:getConfig', function(result)
        TriggerServerEvent('retro_phone:getConfig', result)
    end)
end)


RegisterNetEvent('retro_phone:UsePhone')
AddEventHandler('retro_phone:UsePhone', function(info, misscall)
    phone_data.current_phone = info

    SendNUIMessage({
        action = "ACTION_SET_MISSINGCALL",
        value = {
            misscall = misscall,
        }
    })

    if(phone_data.someone_calling) then

        if(next(phone_data.call_data) ~= nil) then
            if(tonumber(phone_data.current_phone.phone_number) == tonumber(phone_data.call_data.receiver_number)) then
                DisplayPhone(true, "OnSomeoneCalling", phone_data.call_data.transmitter_number)
            else
                DisplayPhone(true, "NoNotificationToDisplay")
            end
        else


            if(misscall == 'no_misscall') then
                DisplayPhone(true, "NoNotificationToDisplay")
            else
                DisplayPhone(true, "MissingCall")
            end
        end
    else
        if(misscall == 'no_misscall') then

            DisplayPhone(true, "NoNotificationToDisplay")
        else


            DisplayPhone(true, "MissingCall")
        end
    end



end)


RegisterNetEvent('retro_phone:SetCallData')
AddEventHandler('retro_phone:SetCallData', function(call_data)
    if(call_data.is_receiver) then
        phone_data.someone_calling = true
    end

    if(call_data.is_transmitter) then
        phone_data.calling_a_person = true
    end

    phone_data.call_data = call_data
end)

RegisterNetEvent('retro_phone:giveConfig')
AddEventHandler('retro_phone:giveConfig', function()
    
end)




RegisterNetEvent('retro_phone:ReceiveCall')
AddEventHandler('retro_phone:ReceiveCall', function()


    phone_data.someone_calling = true

    if(phone_data.someone_calling) then
        TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 5, "call_receiver", 0.1)
        while phone_data.someone_calling do
            Citizen.Wait(3000)
            if(not phone_data.someone_calling) then
                break;
            end

            TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 5, "call_receiver", 0.1)
        end
    end
end)


RegisterNetEvent('retro_phone:ReceiveCallPhoneBooths')
AddEventHandler('retro_phone:ReceiveCallPhoneBooths', function()


    phone_data.someone_calling = true

    if(phone_data.someone_calling) then
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "call_receiver", 0.1)
        while phone_data.someone_calling do
            Citizen.Wait(3000)
            if(not phone_data.someone_calling) then
                break;
            end

            TriggerServerEvent("InteractSound_SV:PlayOnSource", "call_receiver", 0.1)
        end
    end
end)

RegisterNetEvent('retro_phone:PlayRing')
AddEventHandler('retro_phone:PlayRing', function()
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "call_transmitter", 0.1)
end)

RegisterNetEvent('retro_phone:EndCall')
AddEventHandler('retro_phone:EndCall', function()
    exports['pma-voice']:removePlayerFromCall()
    if(phone_data.someone_calling) then
        phone_data.someone_calling = false
    end

    if(phone_data.calling_a_person) then
        phone_data.calling_a_person = false
    end
    ClearPedTasks(PlayerPedId())
    DisplayPhone(false, "EndCall")
end)

RegisterNetEvent('retro_phone:EndCallPhonebooth')
AddEventHandler('retro_phone:EndCallPhonebooth', function()
    exports['pma-voice']:removePlayerFromCall()
end)

RegisterNetEvent('retro_phone:CancelCallClient')
AddEventHandler('retro_phone:CancelCallClient', function()

    if(phone_data.someone_calling) then
        phone_data.someone_calling = false
    end

    if(phone_data.calling_a_person) then
        phone_data.calling_a_person = false
    end

    DisplayPhone(false, "EndCall")
end)


RegisterNetEvent('retro_phone:SetSomeoneCalling')
AddEventHandler('retro_phone:SetSomeoneCalling', function(toggle)

    phone_data.someone_calling = toggle
end)


RegisterNetEvent('retro_phone:NotAvaliable')
AddEventHandler('retro_phone:NotAvaliable', function()
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "call_cant_reach", 0.1)
end)


RegisterNetEvent('retro_phone:EndSound')
AddEventHandler('retro_phone:EndSound', function()
    TriggerServerEvent("InteractSound_SV:PlayOnSource", "call_ended", 0.1)

end)


RegisterNetEvent('retro_phone:SetPlayerCall')
AddEventHandler('retro_phone:SetPlayerCall', function(id)
    DisplayPhone(true, 'InCall')
    if(phone_data.someone_calling) then
        phone_data.someone_calling = false
    end

    Citizen.Wait(500)
    ExecuteCommand('e phonecall')
    exports["pma-voice"]:addPlayerToCall(id)
end)

RegisterNetEvent('retro_phone:SetPlayerPhoneboothCall')
AddEventHandler('retro_phone:SetPlayerPhoneboothCall', function(id)
    exports["pma-voice"]:addPlayerToCall(id)
end)

RegisterNetEvent('retro_phone:CallAnim')
AddEventHandler('retro_phone:CallAnim', function()
    ExecuteCommand('e phonecall')

end)

RegisterNUICallback('CloseCall', function(data)
    TriggerServerEvent('retro_phone:EndCall')
end)

RegisterNetEvent('retro_phone:CloseCall')
AddEventHandler('retro_phone:CloseCall', function()

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    exports['pma-voice']:setCallChannel(0)

end)


RegisterNUICallback('DeclineCall', function()
    TriggerServerEvent('retro_phone:DeclineCall')
end)

RegisterNUICallback('AnswerCall', function()
    TriggerServerEvent('retro_phone:AnswerCall')
end)


RegisterNUICallback('CancelCall', function()
    TriggerServerEvent('retro_phone:CancelCall')
end)


RegisterCommand('phone', function()

    if(not exports['lucid-notepad']:isNotePadOpen()) then
        if(not phone_data.isOpen) then
            QBCore.Functions.TriggerCallback('retro_phone:HasPhone', function(result)
                if(result.has_phone) then
                    if(phone_data.someone_calling) then
                        QBCore.Functions.TriggerCallback('retro_phone:GetRingingPhone', function(data)
                             QBCore.Functions.TriggerCallback('retro_phone:GetMissingCall', function(missccall)
                                TriggerEvent('retro_phone:UsePhone', data, missccall)
                            end)
                        end)
                    else
                        QBCore.Functions.TriggerCallback('retro_phone:GetMissingCall', function(misscall)
                            TriggerEvent('retro_phone:UsePhone', result.info, misscall)
                        end)
                    end
                end
            end)
        end
    end
end)

RegisterKeyMapping('phone', 'Open Phone', 'keyboard', 'M')


RegisterNUICallback('CallPerson', function(data, cb)
    local number = data.number;
    QBCore.Functions.TriggerCallback('retro_phone:GetPlayerInfoByPhoneNumber', function(result)

        TriggerServerEvent('retro_phone:CallNumber', number, phone_data.current_phone.phone_number )
        cb({person = result})
    end, number)
end)


RegisterNUICallback('InsertPhoneInfo', function(data, cb)
    local number = data.number;
    TriggerEvent('ls1975:InsertPhoneInfo', { number = number})
end)




RegisterNetEvent('ls1975:InsertPhoneInfo')
AddEventHandler('ls1975:InsertPhoneInfo', function(data)
    local number = data.number;
    QBCore.Functions.Notify('Open the phone that you want to make the call', 'primary', 3000)
    SendNUIMessage({
        action = "INSERT_DIAL_INFO",
        value = number,
    })

    --TriggerServerEvent('retro_phone:CallNumber', number, phone_data.current_phone.phone_number)
end)


RegisterNUICallback('GivePhoneNumber', function(data, cb)
    if(phone_data.current_phone.phone_number) then
        TriggerEvent('qb-phone:client:GiveContactDetails', phone_data.current_phone.phone_number)
    end

end)

RegisterCommand('stuckui', function()

    DisplayPhone(false, "NoNotificationToDisplay");
    TriggerEvent('lucid-notepad:Close');
    TriggerEvent('inventory:client:close')
end)


function DisplayPhone(toggle, type, number)
    SetNuiFocus(toggle, toggle)

    phone_data.isOpen = toggle;

    SendNUIMessage({
        action = "ACTION_DISPLAY",
        value = {
            show = toggle,
            type = type,
            number = number and number or ''
        }
    })

    Citizen.Wait(800)
    SetNuiFocusKeepInput(toggle)
    if (not toggle) then
        EnableAllControlActions(0, true)
        ExecuteCommand('e c')
        ClearPedTasks(PlayerPedId())

    else
        ExecuteCommand('e phone')
    end
end


RegisterNUICallback('close', function(data, cb)
    DisplayPhone(false, "NoNotificationToDisplay")
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if phone_data.isOpen then
            DisableAllControlActions(0, true)
            EnableControlAction(0, 30, true) -- D
            EnableControlAction(0, 31, true) -- S
            EnableControlAction(0, 32, true) -- W
            EnableControlAction(0, 33, true) -- S
            EnableControlAction(0, 34, true) -- A
            EnableControlAction(0, 35, true) -- D
            EnableControlAction(0, 59, true) -- D
            EnableControlAction(0, 64, true) -- D
            EnableControlAction(0, 75, true) -- F
			EnableControlAction(0, 249, true) -- N
            EnableControlAction(0, 76, true) -- SPACEBAR
            EnableControlAction(0, 79, true) -- C
            EnableControlAction(0, 23, true) -- F
            EnableControlAction(0, 72, true) -- S
            EnableControlAction(0, 71, true) -- W
            DisablePlayerFiring(PlayerPedId(), true) -- Disable weapon firing
        end
    end
end)
