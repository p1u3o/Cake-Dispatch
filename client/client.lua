local DispatchEnabled = false
local HidingDispatch = false
local LastBleep = 0
local CurrentJob = "unemployed"
local LastState = false
local RolePlayName = ""
local Talking = {}
local RadioThingy = true
local NUIReady = false

Citizen.CreateThread(function()
    if Cake.PlayerLoaded then
        CurrentJob = Cake.PlayerData.job.name
        if Config.Whitelisted[CurrentJob] ~= nil then
            if not DispatchEnabled then
                while not NUIReady do
                    Citizen.Wait(25)
                end

                TriggerEvent("prp-policedispatch:ToggleDispatch")

                if CurrentJob == "police" or CurrentJob == "ambulance" then
                    TriggerServerEvent("prp-policedispatch:RegisterAsCop")
                end
            end
        end
    end
end)

RegisterNetEvent('prp-core:Session:PlayerLoaded', function(xPlayer)
    CurrentJob = xPlayer.job.name
end)

RegisterNetEvent('prp-core:Session:JobChange', function(job)
    CurrentJob = job.name
    if Config.Whitelisted[CurrentJob] == nil then
        TriggerServerEvent("prp-policedispatch:DeregisterAsCop")
        if DispatchEnabled then
            TriggerEvent("prp-policedispatch:ToggleDispatch")
        end
    else        
        if not DispatchEnabled then
            TriggerEvent("prp-policedispatch:ToggleDispatch")
            
            if CurrentJob == "police" or CurrentJob == "ambulance" then
                TriggerServerEvent("prp-policedispatch:RegisterAsCop")
            end
        end
    end
end)

-- /closeall --
AddEventHandler('tab:closeUI', function()
    SendNUIMessage({
        type = "move",
        state = 0,
    })
    SetNuiFocus(false, false)
    TriggerScreenblurFadeOut(2000)
end)

AddEventHandler("prp-admin:HasLoadedIn", function()
    if Config.Whitelisted[CurrentJob] ~= nil then
        if not DispatchEnabled then
            TriggerEvent("prp-policedispatch:ToggleDispatch")
        end

        if CurrentJob == "police" or CurrentJob == "ambulance" then
            TriggerServerEvent("prp-policedispatch:RegisterAsCop")
        end
    end
end)

Cake.KeyBindings.RegisterKeyMapping("+DispatchUp", "Dispatch Up", "keyboard", "LEFT") --Removed Bind System and added standalone version
Cake.KeyBindings.RegisterCommand('+DispatchUp', function()
    if DispatchEnabled and not IsNuiFocused() then
        -- Up
        SendNUIMessage({
            type = "navigation",
            state = 0,
        })
    end
end)

Cake.KeyBindings.RegisterKeyMapping("+DispatchDown", "Dispatch Down", "keyboard", "RIGHT") --Removed Bind System and added standalone version
Cake.KeyBindings.RegisterCommand('+DispatchDown', function()
    if DispatchEnabled and not IsNuiFocused() then
        -- Down
        SendNUIMessage({
            type = "navigation",
            state = 1,
        })
    end
end)

Cake.KeyBindings.RegisterKeyMapping("+DispatchEnter", "Dispatch Details", "keyboard", "RETURN") --Removed Bind System and added standalone version
Cake.KeyBindings.RegisterCommand('+DispatchEnter', function()
    if DispatchEnabled and not IsNuiFocused() then
        -- Enter
        SendNUIMessage({
            type = "navigation",
            state = 2,
        })
    end
end)

AddEventHandler("prp-policedispatch:StartResize", function()
    if DispatchEnabled then
        -- K (move)
        SetNuiFocus(true, true)
        SendNUIMessage({
            type = "move",
            state = 1,
        })
        TriggerScreenblurFadeIn(2000)
    end
end)

local TrackingId = nil
local Blip = nil

AddEventHandler("prp-policedispatch:GetCops", function(StartIndex)
    if DispatchEnabled then
        if TrackingId == nil then
            Cake.TriggerServerCallback("prp-policedispatch:GetCops", function(Cops)
                table.sort(Cops, function (k1, k2) 
                    return k1.CallSign < k2.CallSign 
                end)

                local MenuItems = {}
                local CurrentCoords = Cake.Cache.GetCurrentCoords()

                for k, v in pairs(Cops) do
                    local Distance = #(CurrentCoords - v.Coords)
                    Distance  = Cake.Math.Round(Distance * 0.00062137, 2) .. " mi"


                    if v.CallSign ~= nil then                        
                        table.insert(MenuItems, {
                            img = "user.png",
                            text = v.CallSign .. " | " .. v.Officer[1],
                            text2 =  Distance .. " away",
                            callBack = function()
                                OpenOfficerMenu(k, v)
                            end
                        }) 
                    else
                        table.insert(MenuItems, {
                            img = "user.png",
                            text = v.Officer[2],
                            text2 =  Distance .. " away",
                            callBack = function()
                                OpenOfficerMenu(k, v)
                            end
                        }) 
                    end 
                end

                if #MenuItems == 0 then
                    exports['prp-notify']:DoNewHudText('error', 'No other units on frequency', 8000, 0, 1, 'Dispatch', 'location-arrow')
                else
                    IconMenu.OpenMenu(MenuItems, nil, nil, StartIndex)
                end
            end) 
        else
            exports['prp-notify']:DoNewHudText('error', 'Tracking cancelled', 8000, 0, 1, 'Dispatch', 'location-arrow')
            TrackingId = nil
        end
    end
end)

OpenOfficerMenu = function(k, v)
    local MenuItems = {}
    local CurrentCoords = Cake.Cache.GetCurrentCoords()

    local Distance = #(CurrentCoords - v.Coords)

    Distance  = Cake.Math.Round(Distance * 0.00062137, 2) .. " mi"

    MenuItems = 
    {
        {
            img = "user.png",
            text = v.CallSign .. " | " .. v.Officer[1],
            text2 = Distance,
            callBack = function()
                OpenOfficerMenu(k, v)
            end
        },
        {
            text = "Set GPS",
            callBack = function()
                SetNewWaypoint(v.Coords.x, v.Coords.y)
                exports['prp-notify']:DoNewHudText('info', 'GPS set to ' .. v.Officer[1], 8000, 0, 1, 'Dispatch', 'location-arrow')
                IconMenu.ForceCloseMenu()
            end
        },
        {
            text = "Track",
            callBack = function()
                SetNewWaypoint(v.Coords.x, v.Coords.y)
                exports['prp-notify']:DoNewHudText('info', 'Tracking ' .. v.Officer[1] .. " for 60 seconds", 8000, 0, 1, 'Dispatch', 'location-arrow')
                IconMenu.ForceCloseMenu()
                TrackingId = v.Id

                Citizen.CreateThread( function()
                    local StartTime = GetGameTimer()

                    while TrackingId ~= nil and DispatchEnabled do
                        TriggerServerEvent("prp-policedispatch:LocationUpdate", TrackingId)

                        if StartTime + 60000 < GetGameTimer() then
                            TrackingId = nil
                        end

                        Citizen.Wait(10000)
                    end
                    
                    if DoesBlipExist(Blip) then
                        RemoveBlip(Blip)
                    end
                    TrackingId = nil
                end)
            end
        }, 
    }

    IconMenu.OpenMenu(MenuItems, nil, function()
        TriggerEvent("prp-policedispatch:GetCops", k)
    end, 2)
end

RegisterNetEvent("prp-policedispatch:LocationUpdate", function(Coords)
    if Coords ~= nil then
        if DoesBlipExist(Blip) then
            RemoveBlip(Blip)
        end
        
        Blip = AddBlipForCoord(Coords)
        SetBlipSprite(Blip, 161)
        SetBlipColour(Blip, 1)
        SetBlipScale(Blip, 1.0)
        SetBlipAsShortRange(Blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString('Tracked Officer')
        EndTextCommandSetBlipName(Blip)

        SetNewWaypoint(Coords.x, Coords.y)
    else
        TrackingId = nil
    end
end)

Cake.KeyBindings.RegisterKeyMapping("+DispatchRespond", "Dispatch Respond", "keyboard", "G") --Removed Bind System and added standalone version
Cake.KeyBindings.RegisterCommand('+DispatchRespond', function()
    if DispatchEnabled then
        -- G (respond)
        SendNUIMessage({
            type = "navigation",
            state = 3,
        })
    end
end)

Cake.KeyBindings.RegisterKeyMapping("+DispatchUnRespond", "Dispatch Unrespond", "keyboard", "Y") --Removed Bind System and added standalone version
Cake.KeyBindings.RegisterCommand('+DispatchUnRespond', function()
    if DispatchEnabled then
        -- Y (unrespond)
        SendNUIMessage({
            type = "navigation",
            state = 4,
        })
    end
end)

--Linked to the menu under police actions
AddEventHandler('prp-policedispatch:ToggleDispatch', function()
    if not DispatchEnabled then  
        RolePlayName = Cake.GetPlayerData().completename

        if GetResourceKvpString("RadioThingy") == "off" then
            RadioThingy = false
        end

        DispatchEnabled = true
        SendNUIMessage({
            type = "state",
            state = 1,
        })
        Citizen.CreateThread(function()
            while DispatchEnabled do
                Citizen.Wait(1000)
                if IsPauseMenuActive() then
                    if not HidingDispatch then
                        HidingDispatch = true
                        SendNUIMessage({
                            type = "visible",
                            state = 0                   
                        })
                    end
                else
                    if HidingDispatch then
                        HidingDispatch = false
                        SendNUIMessage({
                            type = "visible",
                            state = 1                   
                        })
                    end
                end

                --[[
                local MyChannel = LocalPlayer.state.radioChannel

                for k, v in pairs(Talking) do
                    if Player(k).state.radioChannel ~= MyChannel then
                        Talking[k] = nil
                        SendNUIMessage({
                            type = "removeRadioPerson",
                            id = k,
                        })
                    end
                end
                ]]
            end
        end) 
    else
        DispatchEnabled = false
        SendNUIMessage({
            type = "state",
            state = 0,
        })
    end
end)


RegisterCommand('addbolo', function(source, args)
    if CurrentJob == 'police' or CurrentJob == 'agency' then
        TriggerServerEvent("wk:RegisterBolo", args[1])
    end
end)

RegisterNUICallback('syncState', function(data)
    DispatchEnabled = data.enabled
end)

RegisterNUICallback('focusoff', function(data)
    SendNUIMessage({
        type = "move",
        state = 0,
    })
    SetNuiFocus(data.focus, data.focus)
    TriggerScreenblurFadeOut(2000)
end)

RegisterNUICallback('respond', function(data)
    SetNewWaypoint(data.event.coords.x, data.event.coords.y)

    if Config.NoNetwork[CurrentJob] == nil then
        local PlayerPed = PlayerPedId()
        local CurrentCallSign = LocalPlayer.state.callsign
        local RolePlayName = RolePlayName

        if CurrentCallSign ~= nil then
            if Config.IsK9Active(PlayerPed) then 
                CurrentCallSign = CurrentCallSign .. "K"
            elseif Config.IsBikeActive(PlayerPed) then
                CurrentCallSign = CurrentCallSign .. "B"
            elseif Config.IsEagleActive(PlayerPed) then
                CurrentCallSign = CurrentCallSign .. "E"
            elseif Config.IsHeatActive(PlayerPed) then
                CurrentCallSign = CurrentCallSign .. "H"
            end
        else
            CurrentCallSign = ""
        end

        local RadioChannel = exports['prp-radio']:GetRadioChannel()

        if RadioChannel ~= nil and RadioChannel ~= 0 then
            RolePlayName = RolePlayName .. " [" .. RadioChannel .. "]"
        end

        -- ID and JOB need to be sent with respond first for this
        TriggerServerEvent('prp-policedispatch:UpdateRespond', CurrentCallSign, data.event.uniqueid, RolePlayName) 
    end
end)

RegisterNUICallback('unrespond', function(data)
    DeleteWaypoint()

    if Config.NoNetwork[CurrentJob] == nil then
        local PlayerPed = PlayerPedId()
        local CurrentCallSign = LocalPlayer.state.callsign
        local RolePlayName = RolePlayName

        if CurrentCallSign ~= nil then
            if Config.IsK9Active(PlayerPed) then 
                CurrentCallSign = CurrentCallSign .. "K"
            elseif Config.IsBikeActive(PlayerPed) then
                CurrentCallSign = CurrentCallSign .. "B"
            elseif Config.IsEagleActive(PlayerPed) then
                CurrentCallSign = CurrentCallSign .. "E"
            elseif Config.IsHeatActive(PlayerPed) then
                CurrentCallSign = CurrentCallSign .. "H"
            end
        else
            CurrentCallSign = ""
        end

        local RadioChannel = exports['prp-radio']:GetRadioChannel()

        if RadioChannel ~= nil and RadioChannel ~= 0 then
            RolePlayName = RolePlayName .. " [" .. RadioChannel .. "]"
        end

        -- ID and JOB need to be sent with respond first for this
        TriggerServerEvent('prp-policedispatch:UpdateRespondRemove', CurrentCallSign, data.event.uniqueid, RolePlayName) 
    end
end)

RegisterNUICallback('setGPS', function(data)
    SetNewWaypoint(data.event.coords.x, data.event.coords.y)
end)

RegisterNUICallback('nuiReady', function(data)
    NUIReady = true
end)

RegisterNetEvent('prp-policedispatch:UpdateRespond', function(callSign, uniqueid, roleplayName)
    if Config.Whitelisted[CurrentJob] ~= nil and CurrentJob ~= Config.Weazel then
        if callSign ~= "" then
            SendNUIMessage({
                type = "response",
                uniqueid = uniqueid,
                callSign = callSign.." "..roleplayName,
            })
        else
            SendNUIMessage({
                type = "response",
                uniqueid = uniqueid,
                callSign = roleplayName,
            })
        end
    end
end)

RegisterNetEvent('prp-policedispatch:UpdateRespondRemove', function(callSign, uniqueid, roleplayName)
    if Config.Whitelisted[CurrentJob] ~= nil and CurrentJob ~= Config.Weazel then
        if callSign ~= "" then
            SendNUIMessage({
                type = "unresponse",
                uniqueid = uniqueid,
                callSign = callSign.." "..roleplayName,
            })
        else
            SendNUIMessage({
                type = "unresponse",
                uniqueid = uniqueid,
                callSign = roleplayName,
            })
        end
    end
end)

RegisterNetEvent('prp-policedispatch:SendDispatchMessage', function(data, myname)
    if data.job == CurrentJob or CurrentJob == Config.Agency then
        if data.notifysound == 4 or not exports['prp-pdalerts']:IsInIgnoreZone(data.coords) then
            local playerPed = PlayerPedId()
            local myCoords = GetEntityCoords(playerPed)
            --local travelDistance = CalculateTravelDistanceBetweenPoints(myCoords.x, myCoords.y, myCoords.z, data.coords.x, data.coords.y, data.coords.z)
            local travelDistance = #(myCoords - vector3(data.coords.x, data.coords.y, data.coords.z))
            local secondaryDistance = math.abs( myCoords.x - data.coords.x) + math.abs( myCoords.y - data.coords.y) + math.abs( myCoords.z - data.coords.z)
            
            if secondaryDistance > travelDistance then
                travelDistance =  secondaryDistance
            end

            if data.location == nil then 
                data.location = "Unknown"
            end

            local distance = Cake.Math.Round(travelDistance * 0.00062137, 2) .. "mi"

            if data.coords.y > 950 then
                data.department = "BC"
            else
                if data.coords.x > -300 then
                    data.department = "LS-E"
                else
                    data.department = "LS-W"
                end
            end

            SendNUIMessage({
                uniqueid = data.id,
                job = data.job,
                coords = data.coords,
                type = "event",
                title = data.title,
                location = data.location,
                description = data.description,
                priority = data.priority,
                department = data.department,
                distance = distance,
                maxUnits = data.maxUnits
            })


            --Notification Sound
            if data.notifysound ~= 0 then
                if data.notifysound <= 3 then 
                    local CurrentTime = GetGameTimer()
                    if LastBleep + 2000 < CurrentTime then
                        for i = 1, data.notifysound do
                            PlaySoundFrontend(-1, "Bomb_Disarmed", "GTAO_Speed_Convoy_Soundset", 0)
                            LastBleep = CurrentTime
                            Wait(500)
                        end
                    end
                else
                    --TriggerServerEvent('prp-sounds:Server:PlayWithinRange', 2.0, 'panicorig', 0.2)
                    if data.source == nil or data.source ~= GetPlayerServerId(PlayerId()) then
                        TriggerServerEvent('prp-sounds:Server:PlayOnNetId', PedToNet(PlayerPedId()), 5.0, 'panicorig', 0.20)

                        exports['prp-notify']:DoNewHudTextBlink('info', 'A panic button has been pressed, please respond.', 30000, 0, 1, 'Panic Button', 'broadcast-tower')
                    end
                end
            end

            --Blip Data
            math.randomseed(GetGameTimer())
            local randomBlipValue = math.random(1, 9999)

            if data.blip.radiusblip == false then
                randomBlipValue = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
                SetBlipSprite(randomBlipValue, data.blip.sprite)
                SetBlipScale(randomBlipValue, data.blip.scale)
                SetBlipColour(randomBlipValue, data.blip.color)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(data.blip.text)
                EndTextCommandSetBlipName(randomBlipValue)
            else
                randomBlipValue = AddBlipForRadius(data.coords.x, data.coords.y, data.coords.z, 100.0 * data.blip.scale)
                SetBlipHighDetail(randomBlipValue, true)
                SetBlipColour(randomBlipValue, data.blip.color)
                SetBlipAlpha(randomBlipValue, 180)
            end

            local blipTime = tonumber(data.blip.time*0.1)
            SetBlipFade(randomBlipValue, 250, data.blip.time)
            Wait(blipTime)
            SetBlipFade(randomBlipValue, 230, 20000)
            Wait(blipTime)
            SetBlipFade(randomBlipValue, 210, 20000)
            Wait(blipTime)
            SetBlipFade(randomBlipValue, 190, 20000)
            Wait(blipTime)
            SetBlipFade(randomBlipValue, 170, 20000)
            Wait(blipTime)
            SetBlipFade(randomBlipValue, 150, 20000)
            Wait(blipTime)
            SetBlipFade(randomBlipValue, 130, 20000)
            Wait(blipTime)
            SetBlipFade(randomBlipValue, 110, 20000)
            Wait(blipTime)
            SetBlipFade(randomBlipValue, 90, 20000)
            Wait(blipTime)
            SetBlipFade(randomBlipValue, 70, 20000)
            Wait(blipTime)
            RemoveBlip(randomBlipValue)
        end
    end
end)

AddEventHandler('prp-core:Death:PlayerDead', function()
    if DispatchEnabled then
        LastState = DispatchEnabled
        TriggerEvent("prp-policedispatch:ToggleDispatch")
    end
end)

AddEventHandler('prp-core:Death:PlayerAlive', function()
    if not DispatchEnabled and LastState then
        TriggerEvent("prp-policedispatch:ToggleDispatch")
        LastState = false
    end
end)

RegisterNetEvent('pma-voice:setTalkingOnRadio', function(playerId, talking, name)
    if DispatchEnabled then
        if not talking and Talking[playerId] ~= nil then
            SendNUIMessage({
                type = "removeRadioPerson",
                id = playerId,
            })
            Talking[playerId] = nil
        elseif LocalPlayer.state.radioChannel <= 10 and talking and Talking[playerId] == nil and RadioThingy then
            if Talking[playerId] == nil then
                Talking[playerId] = LocalPlayer.state.radioChannel
                SendNUIMessage({
                    type = "addRadioPerson",
                    id = playerId,
                    name = name
                })
            end
        end
    end
end)

RegisterNetEvent('prp-tab:setTalkingOnRadio', function(playerId, talking, name)
    if DispatchEnabled then
        if not talking and Talking[playerId] ~= nil then
            SendNUIMessage({
                type = "removeRadioPerson",
                id = playerId,
            })
            Talking[playerId] = nil
        elseif LocalPlayer.state.radioChannel <= 10 and talking and Talking[playerId] == nil and RadioThingy then
            if Talking[playerId] == nil then
                Talking[playerId] = LocalPlayer.state.radioChannel
                SendNUIMessage({
                    type = "addRadioPerson",
                    id = playerId,
                    name = name
                })
            end
        end
    end
end)

AddEventHandler('prp-policedispatch:ClearSpeakers', function()
    Talking = {}
    SendNUIMessage({
        type = "clearSpeakers",
    })
end)

RegisterCommand('RadioThingy', function()
    if RadioThingy then
        exports['prp-notify']:DoNewHudText('error', 'Disabled live radio view', 8000, 0, 1, 'Dispatch', 'location-arrow')
        RadioThingy = false
        SetResourceKvp("RadioThingy", "off")
    else
        exports['prp-notify']:DoNewHudText('success', 'Enabled live radio view', 8000, 0, 1, 'Dispatch', 'location-arrow')
        RadioThingy = true
        SetResourceKvp("RadioThingy", "on")
    end
end)

-- Panic Buttons --
local PanicCooldown = false

AddEventHandler('prp-policedispatch:PanicButton1', function()
    if Cake.Net.TriggerServerCallback("prp-core:Inventory:HasItem", Config.Panic.Item, 1) then 
        if not PanicCooldown then
            PanicCooldown = true

            if LocalPlayer.state.isDead then
                TriggerEventWithDetails("prp-policedispatch:PanicButtonA")

                SetTimeout(60000, function()
                    PanicCooldown = false
                end)
            else
                DoPanicAnimation(Config.Panic.Duration, function(Success)
                    if Success then
                        TriggerEventWithDetails("prp-policedispatch:PanicButtonA")

                        SetTimeout(30000, function()
                            PanicCooldown = false
                        end)
                    end
                end)
            end
        else
            exports['prp-notify']:DoNewHudText('error', 'Panic button is on cooldown, stay calm', 8000, 0, 0, 'Panic Button', 'exclamation-triangle')   
        end
    else
        exports['prp-notify']:DoNewHudText('error', 'If you had a radio then this might work!', 8000, 0, 0, 'Panic Button', 'exclamation-triangle')   
    end
end)

AddEventHandler('prp-policedispatch:PanicButton2', function()
    if Cake.Net.TriggerServerCallback("prp-core:Inventory:HasItem", Config.Panic.Item, 1) then 
        if not PanicCooldown then
            PanicCooldown = true

            if LocalPlayer.state.isDead then
                TriggerEventWithDetails("prp-policedispatch:PanicButtonB")

                SetTimeout(60000, function()
                    PanicCooldown = false
                end)
            else
                DoPanicAnimation(Config.Panic.Duration, function(Success)
                    if Success then
                        TriggerEventWithDetails("prp-policedispatch:PanicButtonB")

                        SetTimeout(30000, function()
                            PanicCooldown = false
                        end)
                    end
                end)
            end
        else
            exports['prp-notify']:DoNewHudText('error', 'Panic button is on cooldown, stay calm', 8000, 0, 0, 'Panic Button', 'exclamation-triangle')   
        end
    else
        exports['prp-notify']:DoNewHudText('error', 'If you had a radio then this might work!', 8000, 0, 0, 'Panic Button', 'exclamation-triangle')   
    end
end)

AddEventHandler('prp-policedispatch:PanicButtonDown', function()
    if not exports["prp-policejob"]:CheckCuffed() then
        if Cake.Net.TriggerServerCallback("prp-core:Inventory:HasItem", Config.Panic.Item, 1) then 
            TriggerEventWithDetails("prp-policedispatch:PanicButtonDown")
        end
    end
end)

AddEventHandler('prp-policedispatch:PanicButton3', function()
    if Cake.Net.TriggerServerCallback("prp-core:Inventory:HasItem", Config.Panic.Item, 1) then 
        if LocalPlayer.state.isDead then
            TriggerEventWithDetails("prp-policedispatch:BackupRequest")
        else
            DoPanicAnimation(Config.Panic.Duration * 0.50, function(Success)
                if Success then
                    TriggerEventWithDetails("prp-policedispatch:BackupRequest")
                end
            end)
        end
    else
        exports['prp-notify']:DoNewHudText('error', 'If you had a radio then this might work!', 8000, 0, 0, 'Panic Button', 'exclamation-triangle')   
    end
end)

RegisterNetEvent("prp-food:DidFire", function()
    exports['prp-policedispatch']:TriggerEventWithDetails("prp-policedispatch:Fire")
end)
