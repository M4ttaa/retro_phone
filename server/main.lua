local ESX = exports['es_extended']:getSharedObject()

local numberBySource     = {}   -- [src] = '5551234'
local sourceByNumber     = {}   -- ['5551234'] = src
local identifierBySource = {}   -- [src] = identifier
local missed             = {}   -- [number] = last missed caller number
local callBySource       = {}   -- [src] = call
local nextCallId         = 1000

local function dbg(...)
    if Config.Debug then print('[retro_phone]', ...) end
end

-------------------------------------------------------------------------------
-- Database / numbers
-------------------------------------------------------------------------------

local function generateNumber()
    local prefix = Config.NumberPrefix or ''
    for _ = 1, 50 do
        local n = prefix
        for _ = 1, Config.NumberLength - #prefix do
            n = n .. math.random(0, 9)
        end
        local exists = MySQL.scalar.await('SELECT 1 FROM retro_phone_numbers WHERE phone_number = ?', { n })
        if not exists then return n end
    end
end

local function loadNumber(src, force)
    if numberBySource[src] and not force then return numberBySource[src] end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local num = MySQL.scalar.await('SELECT phone_number FROM retro_phone_numbers WHERE identifier = ?', { xPlayer.identifier })
    if not num then
        num = generateNumber()
        if not num then return end
        MySQL.insert.await('INSERT INTO retro_phone_numbers (identifier, phone_number) VALUES (?, ?)', { xPlayer.identifier, num })
    end

    local old = numberBySource[src]
    if old and old ~= num then sourceByNumber[old] = nil end

    numberBySource[src] = num
    sourceByNumber[num] = src
    identifierBySource[src] = xPlayer.identifier
    return num
end

-- Finds the online player that owns `number`. Falls back to the database so a
-- number edited/added in SQL works without restarting anything.
local function findSource(number)
    local cached = sourceByNumber[number]
    if cached and GetPlayerName(cached) then return cached end

    local identifier = MySQL.scalar.await('SELECT identifier FROM retro_phone_numbers WHERE phone_number = ?', { number })
    if not identifier then return nil, 'number is not in retro_phone_numbers' end

    local xTarget = ESX.GetPlayerFromIdentifier(identifier)
    if not xTarget then return nil, 'number exists but its owner is offline (' .. identifier .. ')' end

    loadNumber(xTarget.source, true)
    return xTarget.source
end

local function hasPhone(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local item = xPlayer.getInventoryItem(Config.PhoneItem)
    return item ~= nil and (item.count or 0) > 0
end

CreateThread(function()
    math.randomseed(os.time() + GetGameTimer())

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `retro_phone_numbers` (
            `identifier` VARCHAR(60) NOT NULL,
            `phone_number` VARCHAR(15) NOT NULL,
            PRIMARY KEY (`identifier`),
            UNIQUE KEY `phone_number` (`phone_number`)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `retro_phone_contacts` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(60) NOT NULL,
            `name` VARCHAR(30) NOT NULL,
            `phone_number` VARCHAR(15) NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `owner_number` (`identifier`, `phone_number`)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `retro_phone_history` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(60) NOT NULL,
            `phone_number` VARCHAR(15) NOT NULL,
            `call_type` VARCHAR(10) NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `identifier` (`identifier`)
        )
    ]])

    -- resource restarted while players are online
    for _, id in ipairs(ESX.GetPlayers()) do
        loadNumber(tonumber(id))
    end
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    loadNumber(playerId)
end)

-------------------------------------------------------------------------------
-- Call history
-------------------------------------------------------------------------------

-- kind: 'outgoing' | 'incoming' | 'missed'
local function logCall(identifier, number, kind)
    if not identifier or not number then return end
    CreateThread(function()
        MySQL.insert.await('INSERT INTO retro_phone_history (identifier, phone_number, call_type) VALUES (?, ?, ?)',
            { identifier, number, kind })
        -- keep only the newest Config.MaxHistory rows per player
        MySQL.update.await([[
            DELETE FROM retro_phone_history
            WHERE identifier = ? AND id NOT IN (
                SELECT id FROM (
                    SELECT id FROM retro_phone_history WHERE identifier = ? ORDER BY id DESC LIMIT ?
                ) keep
            )
        ]], { identifier, identifier, Config.MaxHistory })
    end)
end

ESX.RegisterServerCallback('retro_phone:GetHistory', function(source, cb)
    local id = identifierBySource[source]
    if not id then return cb({}) end
    cb(MySQL.query.await(
        'SELECT phone_number, call_type FROM retro_phone_history WHERE identifier = ? ORDER BY id DESC LIMIT ?',
        { id, Config.MaxHistory }) or {})
end)

-------------------------------------------------------------------------------
-- Contacts
-------------------------------------------------------------------------------

local function getContacts(identifier)
    return MySQL.query.await(
        'SELECT id, name, phone_number FROM retro_phone_contacts WHERE identifier = ? ORDER BY name ASC',
        { identifier }) or {}
end

ESX.RegisterServerCallback('retro_phone:GetContacts', function(source, cb)
    local id = identifierBySource[source]
    cb(id and getContacts(id) or {})
end)

ESX.RegisterServerCallback('retro_phone:AddContact', function(source, cb, name, number)
    local id = identifierBySource[source]
    if not id then return cb({ ok = false, error = 'Error' }) end

    name = tostring(name or ''):gsub('[%c<>&"\'`]', '')
    name = name:match('^%s*(.-)%s*$'):sub(1, 14)
    number = tostring(number or ''):gsub('%D', '')

    if #name == 0 or #number == 0 or #number > 15 then
        return cb({ ok = false, error = 'Invalid data' })
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM retro_phone_contacts WHERE identifier = ?', { id }) or 0
    if count >= Config.MaxContacts then
        return cb({ ok = false, error = 'Contacts full' })
    end

    local exists = MySQL.scalar.await('SELECT 1 FROM retro_phone_contacts WHERE identifier = ? AND phone_number = ?', { id, number })
    if exists then
        return cb({ ok = false, error = 'Already saved' })
    end

    MySQL.insert.await('INSERT INTO retro_phone_contacts (identifier, name, phone_number) VALUES (?, ?, ?)', { id, name, number })
    cb({ ok = true, contacts = getContacts(id) })
end)

ESX.RegisterServerCallback('retro_phone:DeleteContact', function(source, cb, contactId)
    local id = identifierBySource[source]
    if not id then return cb({ ok = false }) end

    MySQL.update.await('DELETE FROM retro_phone_contacts WHERE id = ? AND identifier = ?', { tonumber(contactId) or 0, id })
    cb({ ok = true, contacts = getContacts(id) })
end)

-------------------------------------------------------------------------------
-- Call helpers
-------------------------------------------------------------------------------

local function otherParty(call, src)
    return (src == call.transmitter) and call.receiver or call.transmitter
end

local function destroyCall(call)
    call.status = 'ended'
    if callBySource[call.transmitter] == call then callBySource[call.transmitter] = nil end
    if callBySource[call.receiver] == call then callBySource[call.receiver] = nil end
end

local function missedCall(call)
    destroyCall(call)
    missed[call.receiverNumber] = call.transmitterNumber
    logCall(call.receiverId, call.transmitterNumber, 'missed')
    TriggerClientEvent('retro_phone:CancelCallClient', call.receiver)
    TriggerClientEvent('retro_phone:EndSound', call.transmitter)
    TriggerClientEvent('retro_phone:CancelCallClient', call.transmitter)
end

-- play a sound for `src` and every player within Config.RingDistance of them
local function playSoundNear(src, sound)
    TriggerClientEvent('retro_phone:PlaySound', src, sound)
    local pos = GetEntityCoords(GetPlayerPed(src))
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src and #(pos - GetEntityCoords(GetPlayerPed(id))) <= Config.RingDistance then
            TriggerClientEvent('retro_phone:PlaySound', id, sound)
        end
    end
end

local function rejectCall(src, reason)
    if Config.Debug then print(('[retro_phone] call from %s rejected: %s'):format(src, reason or 'unknown')) end
    TriggerClientEvent('retro_phone:NotAvaliable', src)
    SetTimeout(Config.UnavailableDelay * 1000, function()
        TriggerClientEvent('retro_phone:CancelCallClient', src)
    end)
end

-------------------------------------------------------------------------------
-- Callbacks (client -> server)
-------------------------------------------------------------------------------

ESX.RegisterServerCallback('retro_phone:HasPhone', function(source, cb)
    local has = hasPhone(source)
    local num = has and loadNumber(source, true) or nil
    cb({
        has_phone = has and num ~= nil,
        info = { phone_number = num }
    })
end)

ESX.RegisterServerCallback('retro_phone:GetRingingPhone', function(source, cb)
    local call = callBySource[source]
    if call and call.receiver == source and call.status == 'ringing' then
        cb({ phone_number = call.receiverNumber })
    else
        cb({ phone_number = numberBySource[source] })
    end
end)

ESX.RegisterServerCallback('retro_phone:GetMissingCall', function(source, cb)
    local num = numberBySource[source]
    local caller = num and missed[num]
    if caller then
        missed[num] = nil -- show once
        cb(caller)
    else
        cb('no_misscall')
    end
end)

-- text shown on the "You Calling ..." screen (the UI swaps it for a contact name)
ESX.RegisterServerCallback('retro_phone:GetPlayerInfoByPhoneNumber', function(source, cb, number)
    cb(tostring(number or ''))
end)

-------------------------------------------------------------------------------
-- Calling
-------------------------------------------------------------------------------

RegisterNetEvent('retro_phone:CallNumber', function(number)
    local src = source
    number = tostring(number or ''):gsub('%s', '')

    dbg(('CallNumber from %s to "%s"'):format(src, number))

    if callBySource[src] then return dbg('ignored: caller is already in a call') end
    if not hasPhone(src) then return dbg('ignored: caller has no "' .. Config.PhoneItem .. '" item') end

    local myNumber = loadNumber(src)
    if not myNumber then return dbg('ignored: caller has no phone number') end

    logCall(identifierBySource[src], number, 'outgoing')

    local target, why = findSource(number)

    if not target then return rejectCall(src, why or ('number not found: ' .. number)) end
    if target == src then return rejectCall(src, 'called own number') end
    if callBySource[target] then return rejectCall(src, 'target is busy') end
    if not hasPhone(target) then return rejectCall(src, 'target has no "' .. Config.PhoneItem .. '" item') end

    nextCallId = nextCallId + 1
    local call = {
        id = nextCallId,
        transmitter = src,
        receiver = target,
        transmitterNumber = myNumber,
        receiverNumber = number,
        transmitterId = identifierBySource[src],
        receiverId = identifierBySource[target],
        status = 'ringing',
    }
    callBySource[src] = call
    callBySource[target] = call
    dbg(('call %d started: %s (%s) -> %s (%s)'):format(call.id, src, myNumber, target, number))

    TriggerClientEvent('retro_phone:SetCallData', src, {
        is_transmitter = true,
        is_receiver = false,
        transmitter_number = myNumber,
        receiver_number = number,
    })
    TriggerClientEvent('retro_phone:SetCallData', target, {
        is_transmitter = false,
        is_receiver = true,
        transmitter_number = myNumber,
        receiver_number = number,
    })
    TriggerClientEvent('retro_phone:ReceiveCall', target)

    CreateThread(function()
        local started = GetGameTimer()
        while call.status == 'ringing' do
            TriggerClientEvent('retro_phone:PlayRing', src)
            playSoundNear(target, 'call_receiver')
            Wait(3000)
            if call.status ~= 'ringing' then break end
            if GetGameTimer() - started >= Config.RingTimeout * 1000 then
                missedCall(call)
                break
            end
        end
    end)
end)

RegisterNetEvent('retro_phone:AnswerCall', function()
    local src = source
    local call = callBySource[src]
    if not call or call.receiver ~= src or call.status ~= 'ringing' then return end

    call.status = 'active'
    logCall(call.receiverId, call.transmitterNumber, 'incoming')
    TriggerClientEvent('retro_phone:SetPlayerCall', call.transmitter, call.id)
    TriggerClientEvent('retro_phone:SetPlayerCall', call.receiver, call.id)
end)

RegisterNetEvent('retro_phone:DeclineCall', function()
    local src = source
    local call = callBySource[src]
    if not call or call.receiver ~= src or call.status ~= 'ringing' then return end

    destroyCall(call)
    TriggerClientEvent('retro_phone:CancelCallClient', call.receiver)
    TriggerClientEvent('retro_phone:EndSound', call.transmitter)
    TriggerClientEvent('retro_phone:CancelCallClient', call.transmitter)
end)

RegisterNetEvent('retro_phone:CancelCall', function()
    local src = source
    local call = callBySource[src]
    if not call or call.transmitter ~= src or call.status ~= 'ringing' then return end

    -- caller hung up before answer -> receiver gets a missed call
    missedCall(call)
end)

RegisterNetEvent('retro_phone:EndCall', function()
    local src = source
    local call = callBySource[src]

    if not call or call.status ~= 'active' then
        TriggerClientEvent('retro_phone:EndCall', src)
        return
    end

    local other = otherParty(call, src)
    destroyCall(call)

    TriggerClientEvent('retro_phone:EndCall', src)
    TriggerClientEvent('retro_phone:EndCall', other)
    TriggerClientEvent('retro_phone:EndSound', other)
end)

-------------------------------------------------------------------------------
-- Give your number to the closest player
-------------------------------------------------------------------------------

RegisterNetEvent('retro_phone:GiveNumber', function(target)
    local src = source
    target = tonumber(target)

    local num = numberBySource[src]
    local xPlayer = ESX.GetPlayerFromId(src)
    if not num or not xPlayer or not target or not GetPlayerName(target) then return end

    local a = GetEntityCoords(GetPlayerPed(src))
    local b = GetEntityCoords(GetPlayerPed(target))
    if #(a - b) > Config.GiveNumberDistance + 2.0 then return end

    TriggerClientEvent('esx:showNotification', target, ('Phone number from %s: %s'):format(xPlayer.getName(), num))
    TriggerClientEvent('esx:showNotification', src, 'You gave your phone number.')
end)

-------------------------------------------------------------------------------
-- Cleanup
-------------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local src = source
    local call = callBySource[src]

    if call then
        local other = otherParty(call, src)
        local wasActive = call.status == 'active'
        destroyCall(call)

        if wasActive then
            TriggerClientEvent('retro_phone:EndCall', other)
            TriggerClientEvent('retro_phone:EndSound', other)
        else
            if src == call.transmitter then
                missed[call.receiverNumber] = call.transmitterNumber
                logCall(call.receiverId, call.transmitterNumber, 'missed')
            end
            TriggerClientEvent('retro_phone:CancelCallClient', other)
        end
    end

    local num = numberBySource[src]
    if num then sourceByNumber[num] = nil end
    numberBySource[src] = nil
    identifierBySource[src] = nil
end)
