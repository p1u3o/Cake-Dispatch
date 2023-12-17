local dispatch_ID = 0 -- Used for dispatch unique id
local tsunami = false
local Training = {}
local PoliceCount = nil
local EngagedCount = 0
local TsunamiTime = 0
local EnabledCCTV = {["23"] = true, ["24"] = true, ["22"] = true, ["21"] = true, ["20"] = true, ["19"] = true}

Citizen.CreateThread(function()
    TsunamiTime = math.random(1800000, 2200000)

    CountPolice()
end)

function CountPolice()
    local xPlayers = Cake.GetCharacters()

    local policeOnline = 0

    for k, v in pairs(xPlayers) do
		if v.job.name == 'police' and v.job.grade > 0 then
		   policeOnline = policeOnline + 1
		end
    end

    local busyCount = MySQL.Sync.fetchScalar('SELECT count(`character`) as count FROM granite_onduty WHERE status != "10-8" and job = "police"')

    if (policeOnline > 3 and GetGameTimer() < TsunamiTime) or tsunami then
        PoliceCount = 3
    else
        PoliceCount = policeOnline - busyCount
    end

    GlobalState.policeCount = PoliceCount
    Citizen.SetTimeout(120000, CountPolice)
end

--Police Online Check
function GetPoliceOnline(Raw)
    if Raw == nil then
        local CurrentPolice = PoliceCount - EngagedCount

        if CurrentPolice < 0 then
            CurrentPolice = 0
        end

        return CurrentPolice, tsunami
    else
        return PoliceCount, tsunami
    end
end

function ClampOfficers(Value)
    EngagedCount = EngagedCount + Value
    Citizen.SetTimeout(1900000, function()
        EngagedCount = EngagedCount - Value
        
        if EngagedCount < 0 then
            EngagedCount = 0
        end
    end)
end

Cake.RegisterServerCallback('prp-policedispatch:GetPoliceCount', function(source, cb, policeneeded, raw)
    local policeOnline = GetPoliceOnline(raw)
    
    if policeOnline >= policeneeded then
        cb(true)
    else
        cb(false)
    end
end)

--EMS Online Check
function emscheck()
    local xPlayer = Cake.GetPlayerFromId(source)
    local xPlayers = Cake.GetPlayers()
	local emsonline = 0

	for i = 1, #xPlayers, 1 do
		local xPlayer = Cake.GetPlayerFromId(xPlayers[i])
		if xPlayer.job.name == 'ambulance' then
		   emsonline = emsonline + 1
		end
    end
	return emsonline
end

Cake.RegisterServerCallback('prp-policedispatch:GetEMSCount', function(source, cb, emsneeded)
    local emsonline = emscheck()
    
    if emsonline >= emsneeded then
        cb(true)
    else
        cb(false)
    end
end)

AddEventHandler("TsunamiComming", function()
    tsunami = true
end)

--Retreive Name for callsign
Cake.RegisterServerCallback('prp-policedispatch:GetNameForCallsign', function(source, cb) 
    local xPlayer = Cake.GetPlayerFromId(source)
    cb(xPlayer.completename)
end)


RegisterServerEvent('prp-policedispatch:BrandishWeapon', function(data)
    dispatch_ID = dispatch_ID + 1
    if data.zone == nil then
        data.zone = "Unknown"
    end

    if data.vehicle == nil then
        SendToDispatch({
            id = dispatch_ID,
            job = "police",
			coords = data.coords,
			title = "10-32 Armed Subject",
			description = "Reports of a "..data.playergender.." carrying a possible firearm",
			location = data.road.." | "..data.zone,
			blip = {
                radiusblip = false,
				sprite = 156,
				color = 44, 
				scale = 1.0, 
				text = "10-32 - Armed Subject",
				time = (1*60*1000), -- 1 mins
			},
            notifysound = 1,
            priority = 0,
        })
    end

end)

--Gunshot Calls for in or out of a vehicle
RegisterServerEvent('prp-policedispatch:GunShotInProgress', function(data, weapon)
    dispatch_ID = dispatch_ID + 1

    if data.zone == nil then
        data.zone = "Unknown"
    end

    if data.vehicle == nil then
        SendToDispatch({
            id = dispatch_ID,
            job = "police",
			coords = data.coords,
			title = "10-13 Shots Fired",
			description = "Reports of shots fired, possibily <b>"..weapon .. "</b>",
			location = data.road.." | "..data.zone,
			blip = {
                radiusblip = false,
				sprite = 313,
				color = 1, 
				scale = 1.0, 
				text = "10-13 - Shots Fired",
				time = (1*60*1000), -- 1 mins
			},
            notifysound = 1,
            priority = 3,
		})
	elseif data.vehicle ~= nil then
		SendToDispatch({
            id = dispatch_ID,
            job = "police",
			coords = data.coords,
			title = "10-13 Driveby Shooting",
			description = "Reports of shots fired from a vehicle.<br>Description: <b>"..data.vehicle_label.."</b> | <b>"..data.vehicle_colour.."</b> | <b>"..data.vehicle_plate.."</b> possibily <b>"..weapon .. "</b>",
			location = data.road.." | "..data.zone,
			blip = {
                radiusblip = false,
				sprite = 229,
				colour = 1, 
				scale = 1.0, 
				text = "10-13 - Shots Fired",
				time = (1*60*1000), -- 1 mins
			},
            notifysound = 1,
            priority = 3,
		})
    end
    
    SendToDispatch({
        id = dispatch_ID,
        job = "weazel",
        coords = data.coords,
        title = "Shots Fired",
        description = "Loud bangs were heard in the area",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 229,
            colour = 1, 
            scale = 1.0, 
            text = "Shots Fired",
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 0,
    })
end)

--Car Jacking
RegisterServerEvent('prp-policedispatch:CarJacking', function(data, carcolour, plate, vehicleLabel)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = "police",
        coords = data.coords,
        title = "10-99 Car Jacking",
        description = "A "..data.playergender.." was seen hijacking a "..carcolour.." "..vehicleLabel.." at gunpoint<br>Registration Number: "..plate,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 227,
            color = 57, 
            scale = 1.0, 
            text = "10-99 - Car Jacking",
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 0,
    })
end)

--Car Jacking
RegisterServerEvent('prp-policedispatch:CarTheft', function(data, carcolour, plate, vehicleLabel)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = "police",
        coords = data.coords,
        title = "10-99 Stolen Car",
        description = "A "..data.playergender.." was seen breaking into a "..carcolour.." "..vehicleLabel.."<br>Registration Number: "..plate,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 227,
            color = 57, 
            scale = 1.0, 
            text = "10-99 - Stolen Car",
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 0,
        maxUnits = 2,
    })
end)

--Heroin Plane PD Call
RegisterServerEvent('prp-policedispatch:HeroinPlaneCall', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data,
        title = 'Illegal Cargo Drop',
        description = 'A plane has just took off from LSIA and is heading up north with an illegal cargo',
        location = nil,
        blip = {
            radiusblip = true, -- If true then the icon blip will not be shown
            sprite = 514,
            color = 3, 
            scale = 1.0, 
            text = 'Illegal Cargo Drop',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
        maxUnits = 3,
    })
end)

RegisterServerEvent('prp-policedispatch:HeroinPlaneCall2', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data,
        title = 'Illegal Cargo Drop',
        description = 'A package has landed in this location!',
        location = nil,
        blip = {
            radiusblip = false, -- If true then the icon blip will not be shown
            sprite = 94,
            color = 2, 
            scale = 1.0, 
            text = 'Illegal Cargo Drop',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)

--Drug Sale
RegisterServerEvent('prp-policedispatch:DrugSale', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-100 Hand-to-Hand',
        description = 'A '..data.playergender..' was seen handing over a small suspicious package',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 514,
            color = 3, 
            scale = 1.0, 
            text = 'Drug Sale',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
    })
end)

--Gang Drug Sale
RegisterServerEvent('prp-policedispatch:GangDrugSale', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data,
        title = '10-100 Large Drug Sale',
        description = 'A large drug sale is about to take place somewhere in the area.',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 514,
            color = 30, 
            scale = 1.5, 
            text = 'Large Drug Sale',
            time = (2*60*1000), -- 2 mins
        },
        notifysound = 2,
        priority = 2,
    })
end)
--Gang Gold Sale
RegisterServerEvent('prp-policedispatch:GangGoldSale', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data,
        title = '10-100 Large Gold Sale',
        description = 'A large illegal gold sale is about to take place somewhere in the area.',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 514,
            color = 47, 
            scale = 1.5, 
            text = 'Large Gold Sale',
            time = (2*60*1000), -- 2 mins
        },
        notifysound = 2,
        priority = 2,
    })
end)

--Gang Drug Sale
RegisterServerEvent('prp-policedispatch:GangSale', function(data, spawnLoc)
    local src = source
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = spawnLoc,
        title = '10-60 Gang Related',
        description = 'Suspicious activity reported, possibly gang related',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 303,
            color = 27, 
            scale = 1.0, 
            text = '10-60 - Gang Related',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 1,
    })
    exports['prp-tab']:WebhookBasic("TestAbuse", "Test Abuse", '```[Name]: ['..GetPlayerName(src)..'] | Triggered prp-policedispatch:GangSale```')    
end)

--Gang Mission
RegisterServerEvent('prp-policedispatch:GangMission', function(data, spawnLoc)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = spawnLoc,
        title = '10-32 Armed Subject(s)',
        description = 'Suspicious activity reported, possibly gang related',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 303,
            color = 1, 
            scale = 1.2, 
            text = '10-32 - Armed Subject(s)',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 1,
    })
end)

--Cocaine plane
RegisterServerEvent('prp-policedispatch:CocainePlane', function(data, spawnLoc)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = spawnLoc,
        title = '10-32 Armed Subject(s)',
        description = 'A group of armed men with class 3\'s have been spotted at the location, approach with caution',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 303,
            color = 1, 
            scale = 1.2, 
            text = '10-32 - Armed Subject(s)',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 1,
    })
end)

--Container Mission
RegisterServerEvent('prp-policedispatch:ContainerAttack', function(data, spawnLoc)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = spawnLoc,
        title = 'Merry Weather Security - 10-32 Armed Subject(s)',
        description = 'URGERNT ASSISTANCE NEEDED | Armed suspects are trying to steal heavy equipment from our container!',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 303,
            color = 1, 
            scale = 1.2, 
            text = '10-32 - Armed Subject(s)',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
    })
end)

--Bobcat Mission
RegisterServerEvent('prp-policedispatch:BobcatAttack', function(data, spawnLoc)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = spawnLoc,
        title = '10-32 Bobcat Security',
        description = 'URGERNT ASSISTANCE NEEDED | Armed suspects are trying to steal heavy equipment from our premises!',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 303,
            color = 1, 
            scale = 1.2, 
            text = '10-32 - Armed Subject(s)',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
        maxUnits = 4,
    })
end)

--Gruppe
RegisterServerEvent('prp-policedispatch:GruppeAttack', function(coords)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = coords,
        title = '10-32 Gruppe 6 Security',
        description = 'URGERNT ASSISTANCE NEEDED | One of our trucks has been reported stolen, the truck will send a GPS becon when the engine is next turned on',
        location = nil,
        blip = {
            radiusblip = false,
            sprite = 205,
            color = 57, 
            scale = 1.2, 
            text = 'Call From MRPD Dispatch',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
        maxUnits = 4,
    })
end)

--Methvan
RegisterServerEvent('prp-policedispatch:Methvan', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-100 Smoking Van',
        description = 'A heavily smoking van with a chemical smell has been reported',
        location = data.road.." | "..data.zone.." ("..data.heading..")",
        blip = {
            radiusblip = false,
            sprite = 270,
            color = 31, 
            scale = 1.0, 
            text = 'Smoking Van',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 2,
        maxUnits = 2,
    })
end)

--OxySale
RegisterServerEvent('prp-policedispatch:OxySale', function(data, oxycoords)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = oxycoords,
        title = '10-100 Oxy Related',
        description = 'A '..data.playergender..' was seen handing over a small suspicious chemist bag',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = true,
            sprite = 403,
            color = 28, 
            scale = 1.0, 
            text = 'Oxy Related',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 0,
        maxUnits = 2,
    })
end)

--Grave Robbery
RegisterServerEvent('prp-policedispatch:GraveRobbery', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-14 Grave Disturbance',
        description = 'A '..data.playergender..' has been reported digging in a graveyard',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 40,
            color = 1, 
            scale = 1.0, 
            text = 'Grave Disturbance',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 2,
        maxUnits = 2,
    })
end)

RegisterServerEvent('prp-policedispatch:HouseRobbery', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-15 Burglary',
        description = 'A '..data.playergender..' has been reported breaking into a house, approach with caution',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 40,
            color = 1, 
            scale = 1.0, 
            text = 'House Burglary',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 0,
        maxUnits = 2,
    })
end)

--Shop Robbery
RegisterServerEvent('prp-policedispatch:ShopRobbery', function(data, type)
    _source = source

    message = "A shops panic button has been triggered"

    if type == "safe" then
        message = "The safe alarm at the current location has been triggered"
    elseif type == "till" then
        message = "A shops till alarm at the current location has been triggered"
    end

    local CCTVCamera = exports['prp-policejob']:GetNearestCCTV(data.coords)
    
    if message ~= nil and CCTVCamera ~= nil and CCTVCamera ~= false then
        message = message .. "<br>Nearest CCTV: #" .. CCTVCamera
        EnabledCCTV[tostring(CCTVCamera)] = true
    end

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-15 Store Robbery',
        description = message,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 431,
            color = 3, 
            scale = 1.0, 
            text = 'Store Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
        maxUnits = 3,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = data.coords,
        title = '10-15 Store Robbery',
        description = "Scared children were just seen running out of a store",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 431,
            color = 3, 
            scale = 1.0, 
            text = 'Store Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
    })
end)

--Bank Robbery
RegisterServerEvent('prp-policedispatch:BankRobbery', function(data, message)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-17 Armed Robbery',
        description = message..data.road,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 374,
            color = 1, 
            scale = 1.0, 
            text = 'Armed Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
        maxUnits = 4,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = data.coords,
        title = 'Armed Robbery',
        description = "A loud bang just woke a bunch of babies",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 374,
            color = 1, 
            scale = 1.0, 
            text = 'Armed Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)

--Paleto Bank Robbery
RegisterServerEvent('prp-policedispatch:PalteoRobbery', function(data, message)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-17 Paleto Bank Robbery',
        description = 'Paleto Bank is being robbed, urgent assistance is required',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 374,
            color = 1, 
            scale = 1.0, 
            text = 'Paleto Bank Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
        maxUnits = 4,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = data.coords,
        title = 'Paleto Bank Robbery',
        description = 'Weazel HQ found some information on the dark web about a possible robbery',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 374,
            color = 1, 
            scale = 1.0, 
            text = 'Paleto Bank Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)

--Vangellico
RegisterServerEvent('prp-policedispatch:Vangellico', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-17 Armed Robbery',
        description = "Vangelico jewelry store\'s security system has been tripped, urgent assistance needed",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 617,
            color = 46, 
            scale = 1.0, 
            text = 'Armed Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
        maxUnits = 4,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = data.coords,
        title = 'Armed Robbery',
        description = "Glass has been heard being smashed at Vangelico",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 617,
            color = 46, 
            scale = 1.0, 
            text = 'Armed Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)

--Bank Heist Robbery
RegisterServerEvent('prp-policedispatch:BankHeistRobbery', function(data, message)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-31 Pacific Standard Bank Robbery',
        description = message,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 374,
            color = 1, 
            scale = 2.0, 
            text = 'Pacific Standard Bank',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
        maxUnits = 7,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = data.coords,
        title = 'Pacific Standard Bank Robbery',
        description = message,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 374,
            color = 1, 
            scale = 2.0, 
            text = 'A female was heard screaming at the Pacific Bank',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)

--Fleeca Robbery
RegisterServerEvent('prp-policedispatch:FleecaRobbery', function(data, message)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-17 Bank Robbery',
        description = message,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 374,
            color = 1, 
            scale = 2.0, 
            text = 'Bank Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
        maxUnits = 4,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = data.coords,
        title = 'Bank Robbery',
        description = message,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 374,
            color = 1, 
            scale = 2.0, 
            text = 'A large wave of deranged cats were seen running away from a bank',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)

--Panic Button - Group message - URGENT
RegisterServerEvent('prp-policedispatch:PanicButtonA', function(data)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)
    local name = xPlayer.getCompleteName()

    if data.zone == nil then
        data.zone = ""
    end

    local RadioChannel = Player(_source).state['radioChannel']

    if RadioChannel == 0 then
        RadioChannel = "N/A"
    end

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-78A PANIC BUTTON',
        description = name..' activated their panic button, urgent assistance required<br><strong>Radio: </strong> '..RadioChannel,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 3, 
            scale = 1.0, 
            text = 'Panic Button',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 4,
        priority = 1,
        source = _source,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'ambulance',
        coords = data.coords,
        title = '10-78A PANIC BUTTON',
        description = name..' activated their panic button, urgent assistance required<br><strong>Radio: </strong> '..RadioChannel,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 3, 
            scale = 1.0, 
            text = 'Panic Button',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 4,
        priority = 1,
        source = _source,
    })
end)

RegisterServerEvent('prp-policedispatch:CoffeePanic', function(data)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)
    local name = xPlayer.getCompleteName()

    if data.zone == nil then
        data.zone = ""
    end


    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-78C PANIC BUTTON',
        description = 'Bean Machine activated their panic button, urgent assistance required',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 3, 
            scale = 1.0, 
            text = 'Panic Button',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 4,
        priority = 1,
        source = _source,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'ambulance',
        coords = data.coords,
        title = '10-78C PANIC BUTTON',
        description = 'Bean Machine activated their panic button, urgent assistance required',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 3, 
            scale = 1.0, 
            text = 'Panic Button',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 4,
        priority = 1,
        source = _source,
    })
end)

--Panic Button - Group message - NOT SO URGENT
RegisterServerEvent('prp-policedispatch:PanicButtonB', function(data)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)
    local name = xPlayer.getCompleteName()

    if data.zone == nil then
        data.zone = ""
    end

    local RadioChannel = Player(_source).state['radioChannel']

    if RadioChannel == 0 then
        RadioChannel = "N/A"
    end

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-78B PANIC BUTTON',
        description = name..' activated their panic button, assistance required<br><strong>Radio: </strong> '..RadioChannel,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 3, 
            scale = 1.0, 
            text = 'Panic Button',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
        maxUnits = 2,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'ambulance',
        coords = data.coords,
        title = '10-78B PANIC BUTTON',
        description = name..' activated their panic button, assistance required<br><strong>Radio: </strong> '..RadioChannel,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 3, 
            scale = 1.0, 
            text = 'Panic Button',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)


--Panic Button - Group message - NOT SO URGENT
RegisterServerEvent('prp-policedispatch:PanicButtonDown', function(data)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)
    local name = xPlayer.getCompleteName()

    if data.zone == nil then
        data.zone = ""
    end

    local RadioChannel = Player(_source).state['radioChannel']

    if RadioChannel == 0 then
        RadioChannel = "N/A"
    end

    local JobName = "OFFICER"

    if xPlayer.job.name == "ambulance" then
        JobName = "PARAMEDIC"
    end

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-78B ' .. JobName .. ' DOWN',
        description = name..' activated their panic button, assistance required<br><strong>Radio: </strong> '..RadioChannel,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 3, 
            scale = 1.0, 
            text = 'Panic Button',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
        maxUnits = 2,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'ambulance',
        coords = data.coords,
        title = '10-78B ' .. JobName .. ' DOWN',
        description = name..' activated their panic button, assistance required<br><strong>Radio: </strong> '..RadioChannel,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 3, 
            scale = 1.0, 
            text = 'Panic Button',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)


--Panic Button - Group message - NOT SO URGENT
RegisterServerEvent('prp-policedispatch:PanicButtonDog', function(data, name)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-78D K9 DOWN',
        description = name..' has been fatally injured, assistance required',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 3, 
            scale = 1.0, 
            text = 'Panic Button',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)

--Panic Button - Group message - NOT SO URGENT
RegisterServerEvent('prp-policedispatch:PanicButtonHorse', function(data, name)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-78H HORSE DOWN',
        description = name..' has been fatally injured, assistance required',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 3, 
            scale = 1.0, 
            text = 'Panic Button',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)

--Send distress signal - EMS and Police
RegisterServerEvent('prp-policedispatch:SendDistressSignal', function(data)
    dispatch_ID = dispatch_ID + 1
    -- Send to EMS --
    SendToDispatch({
        id = dispatch_ID,
        job = "ambulance",
        coords = data.coords,
        title = '10-52 Ambulance Required',
        description = 'A '..data.playergender..' (#'..source..') needs urgent medical attention',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 305,
            color = 1, 
            scale = 1.0, 
            text = 'Ambulance Required',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
    })

    -- Send to PD --
    SendToDispatch({
        id = dispatch_ID,
        job = "police",
        coords = data.coords,
        title = '10-52 Ambulance Required',
        description = 'A '..data.playergender..' (#'..source..') needs urgent medical attention',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 305,
            color = 1, 
            scale = 1.0, 
            text = 'Ambulance Required',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
    })
end)

--Alert EMS
RegisterServerEvent('prp-policedispatch:NotifyEMS', function(data)
    local xPlayer = Cake.GetPlayerFromId(source)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'ambulance',
        coords = data.coords,
        title = '10-52 Hospital Call | Medic Required',
        description = 'A '..data.playergender..' (#'..source..') has checked into a hospital and needs urgent assistance',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 162,
            color = 3, 
            scale = 1.0, 
            text = 'Medic Required',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
    })
    exports['prp-tab']:WebhookBasic("CheckIn", "Pillbox Checkin", '```[Name]: ['..xPlayer.getCompleteName()..'] | Checked in```')    
end)

--Meth Cook
RegisterServerEvent('prp-policedispatch:MethCook', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data,
        title = '10-100 Suspicious Van',
        description = 'A local has reported a van that is parked up and looks to be cooking something causing a lot of smoke and polloution',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 465,
            color = 1, 
            scale = 2.0, 
            text = 'Suspicious Van',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
        maxUnits = 3,
    })
end)

RegisterServerEvent('prp-policedispatch:IndoorMethCook', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data,
        title = 'Suspicious Activity',
        description = 'A local has reported unsual activity in the area and stated there is a toxic smell in the air and that they are felling faint',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 465,
            color = 1, 
            scale = 2.5, 
            text = 'Suspicious Activity',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
        maxUnits = 3,
    })
end)

--Coke Brick Sale
RegisterServerEvent('prp-policedispatch:BoatCoke', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data,
        title = '10-100 Large Drug Sale',
        description = 'Reports of a suspicious looking boat potentially dropping off packages | Possible Air-1 needed',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 465,
            color = 1, 
            scale = 2.0, 
            text = 'Suspicious Boat',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
        maxUnits = 4,
    })
end)

RegisterServerEvent('prp-policedispatch:DiveBoatCoke', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data,
        title = '10-100 Large Drug Sale',
        description = 'Reports of a suspicious looking boat potentially picking up packages | Possible Air-1 needed',
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 465,
            color = 1, 
            scale = 2.0, 
            text = 'Suspicious Boat',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
        maxUnits = 4,
    })
end)

--EMS Emergency Call / 911ems
RegisterServerEvent('prp-policedispatch:EMSEmergencyCall', function(data, msg)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'ambulance',
        coords = data.coords,
        title = '10-68 911 Emergency Phone Call',
        description = '<strong>Message from : </strong> '..xPlayer.getCompleteName()..'<br>'..msg..'<br><strong>Number: </strong> '..xPlayer.phone..' | <strong>ID: </strong>'..source,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 305,
            color = 1, 
            scale = 1.0, 
            text = '911 - Emergency Call',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 2,
    })
end)

--Anonymous 911
RegisterServerEvent('prp-policedispatch:AnonPoliceEmergencyCall', function(data, msg)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = 'Anonymous 911 Phone Call',
        description = '<strong>Message from : </strong> Anonymous <br>'..msg..'<br><strong>Number: </strong> Withheld | <strong>ID: </strong>'..source,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 66,
            color = 38, 
            scale = 1.0, 
            text = 'Anonymous 911 Phone Call',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
    })
end)

--Police Emergency Call / 911
RegisterServerEvent('prp-policedispatch:PoliceEmergencyCall', function(data, msg)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)

    if data.zone == nil then
        data.zone = ""
    end

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-68 911 Emergency Phone Call',
        description = '<strong>Message from : </strong> '..xPlayer.getCompleteName()..'<br>'..msg..'<br><strong>Number: </strong> '..xPlayer.phone..' | <strong>ID: </strong>'..source,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 487,
            color = 38, 
            scale = 1.0, 
            text = '911 - Emergency Call',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 3,
    })

    exports['prp-tab']:WebhookBasic("PD911Calls", "911 Call", '```[Name]: '..xPlayer.completename..'\n[ID]: ' .. _source .. '\n[Message]: ' .. msg .. '```')    
end)

RegisterServerEvent('prp-policedispatch:WeazelCall', function(data, msg)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)

    if data.zone == nil then
        data.zone = ""
    end

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = data.coords,
        title = 'Phone Call',
        description = '<strong>Message from : </strong> '..xPlayer.getCompleteName()..'<br>'..msg..'<br><strong>Number: </strong> '..xPlayer.phone..' | <strong>ID: </strong>'..source,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 487,
            color = 38, 
            scale = 1.0, 
            text = 'Phone Call',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 3,
    })
end)

RegisterServerEvent('prp-policedispatch:AnonWeazelCall', function(data, msg)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = data.coords,
        title = 'Anonymous Phone Call',
        description = '<strong>Message from : </strong> Anonymous <br>'..msg..'<br><strong>Number: </strong> Withheld | <strong>ID: </strong>'..source,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 66,
            color = 38, 
            scale = 1.0, 
            text = 'Anonymous Phone Call',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
    })
end)

--Mechanic Call
RegisterServerEvent('prp-policedispatch:MechanicCall', function(data, msg)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'mechanic',
        coords = data.coords,
        title = 'Incoming call request',
        description = '<strong>Message: </strong> '..msg..'<br><strong>Number: </strong> '..xPlayer.phone..' | <strong>ID: </strong>'..source,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 544,
            color = 44, 
            scale = 1.0, 
            text = 'Mechanic Call',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 0,
    })
end)

--Money truck
RegisterServerEvent('prp-policedispatch:MoneyTruck', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-18 Money Truck Robbery',
        description = "A money truck is under attack, urgent assistance needed.",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 67,
            color = 1, 
            scale = 1.0, 
            text = 'Money Truck Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
        maxUnits = 3,
    })
end)

--Wash truck
RegisterServerEvent('prp-policedispatch:WashTruck', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-85 Dagerous Vehicle',
        description = "A dangerous truck has been seen speeding and leaking water.",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 67,
            color = 1, 
            scale = 1.0, 
            text = 'Money Truck Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
        maxUnits = 3,
    })
end)

--Safe Cracking
RegisterServerEvent('prp-policedispatch:SafeCracking', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-15 Safe Alarm Triggered',
        description = "A shop alarm has been triggered due to someone trying to breach the safe",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 1, 
            scale = 1.0, 
            text = 'Shop Safe Breach',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
        maxUnits = 3,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = data.coords,
        title = 'Safe Alarm Triggered',
        description = "A passing civilian has alerted you to some strange behaviour.",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 58,
            color = 1, 
            scale = 1.0, 
            text = 'Shop Safe Breach',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
    })
end)

--Safe Cracking
RegisterServerEvent('prp-policedispatch:TressPassing', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-64 Trespass',
        description = "A "..data.playergender.." has been spotted tresspassing at a chemical storage facility",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 478,
            color = 3, 
            scale = 1.0, 
            text = '10-64 - Trespass',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 0,
        maxUnits = 2,
    })
end)

RegisterServerEvent('prp-policedispatch:WeedSmell', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-100 Strange Smell',
        description = "A resident has reported a strong smell of cannabis in the area",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = true,
            sprite = 478,
            color = 3, 
            scale = 1.0, 
            text = 'Strange Smell',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 0,
        maxUnits = 2,
    })
end)

RegisterServerEvent('prp-policedispatch:MoonShine', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-100 Toxic Smell',
        description = "A resident has reported a strong toxic smell coming from the lake",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = true,
            sprite = 478,
            color = 3, 
            scale = 1.0, 
            text = 'Toxic Smell',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 0,
        maxUnits = 2,
    })
end)

RegisterServerEvent('prp-policedispatch:MoonShineSale', function(data, location)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = location,
        title = '10-100 Illegal Liquor Sale',
        description = "A resident has reported hearing someone close by arrange the purchase of moonshine",
        location = nil,
        blip = {
            radiusblip = true,
            sprite = 459,
            color = 56, 
            scale = 1.0, 
            text = 'Illegal Liquor Sale',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
        maxUnits = 3,
    })
end)

RegisterServerEvent('prp-policedispatch:HotwireCall', function(data)
    if data.vehicle_plate == nil then
        data.vehicle_plate = "Unknown"
    end
    if data.vehicle_label == nil then
        data.vehicle_label = "Unknown"
    end
    if data.vehicle_colour == nil then
        data.vehicle_colour = "Unknown"
    end
    if data.zone == nil then
        data.zone = ""
    end
    
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-99 Vehicle Hotwire',
        description = "A local has reported seeing a "..data.playergender.." trying to hotwire a " .. data.vehicle_colour .. " " .. data.vehicle_label .."<br><strong>Plate: </strong> ".. data.vehicle_plate,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = true,
            sprite = 225,
            color = 1, 
            scale = 1.0, 
            text = '10-99 - Vehicle Hotwire',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 0,
        maxUnits = 1,
    })
end)

RegisterServerEvent('prp-policedispatch:EmergencyHotwireCall', function(data)
    if data.vehicle_plate == nil then
        data.vehicle_plate = "Unknown"
    end
    if data.vehicle_label == nil then
        data.vehicle_label = "Unknown"
    end
    if data.vehicle_colour == nil then
        data.vehicle_colour = "Unknown"
    end
    if data.zone == nil then
        data.zone = ""
    end
    
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-99 Emergency Vehicle Hotwire',
        description = "A local has reported seeing a "..data.playergender.." trying to hotwire a " .. data.vehicle_colour .. " " .. data.vehicle_label .."<br><strong>Plate: </strong> ".. data.vehicle_plate,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = true,
            sprite = 225,
            color = 1, 
            scale = 1.0, 
            text = '10-99 - Vehicle Hotwire',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 1,
        maxUnits = 3,
    })
end)


RegisterServerEvent('prp-policedispatch:SpeedTrap', function(data)
    if data.vehicle_plate == nil then
        data.vehicle_plate = "Unknown"
    elseif data.zone == nil then
        data.zone = ""
    end

    dispatch_ID = dispatch_ID + 1

    if exports['wk_wars2x']:IsPlateBolo(data.vehicle_plate) then
        SendToDispatch({
            id = dispatch_ID,
            job = 'police',
            coords = data.coords,
            title = '10-29 Wanted Vehicle',
            description = "A " .. data.vehicle_colour .. " " .. data.vehicle_label .. " with an active BOLO was seen going <b>" .. data.speed .. "mph</b><br><strong>Plate: </strong> "..data.vehicle_plate.." | <strong>Direction: </strong>"..data.compass,
            location = data.road.." | "..data.zone,
            blip = {
                radiusblip = false,
                sprite = 184,
                color = 1, 
                scale = 1.0, 
                text = '10-29 - Wanted Vehicle',
                time = (1*60*1000), -- 1 mins
            },
            notifysound = 0,
            priority = 1,
        })
    else
        SendToDispatch({
            id = dispatch_ID,
            job = 'police',
            coords = data.coords,
            title = '10-49 Speed Trap',
            description = "A " .. data.vehicle_colour .. " " .. data.vehicle_label .. " was seen going <b>" .. data.speed .. "mph</b><br><strong>Plate: </strong> "..data.vehicle_plate.." | <strong>Direction: </strong>"..data.compass,
            location = data.road.." | "..data.zone,
            blip = {
                radiusblip = false,
                sprite = 184,
                color = 1, 
                scale = 1.0, 
                text = '10-49 - Speed Trap',
                time = (1*60*1000), -- 1 mins
            },
            notifysound = 0,
            priority = 0,
        })
    end
end)

RegisterServerEvent('prp-policedispatch:SpeedTrapCharged', function(data)
    if data.vehicle_plate == nil then
        data.vehicle_plate = "Unknown"
    elseif data.zone == nil then
        data.zone = ""
    end

    dispatch_ID = dispatch_ID + 1

    if exports['wk_wars2x']:IsPlateBolo(data.vehicle_plate) then
        SendToDispatch({
            id = dispatch_ID,
            job = 'police',
            coords = data.coords,
            title = '10-29 Wanted Vehicle',
            description = "A " .. data.vehicle_colour .. " " .. data.vehicle_label .. " with an active BOLO was clocked going <b>" .. data.speed .. "mph</b> and <b>ticketed</b><br><strong>Plate: </strong> "..data.vehicle_plate.." | <strong>Direction: </strong>"..data.compass,
            location = data.road.." | "..data.zone,
            blip = {
                radiusblip = false,
                sprite = 184,
                color = 1, 
                scale = 1.0, 
                text = '10-29 - Wanted Vehicle',
                time = (1*60*1000), -- 1 mins
            },
            notifysound = 0,
            priority = 1,
        })
    else
        SendToDispatch({
            id = dispatch_ID,
            job = 'police',
            coords = data.coords,
            title = '10-49 Speed Trap',
            description = "A " .. data.vehicle_colour .. " " .. data.vehicle_label .. " was clocked going <b>" .. data.speed .. "mph</b> and <b>ticketed</b><br><strong>Plate: </strong> "..data.vehicle_plate.." | <strong>Direction: </strong>"..data.compass,
            location = data.road.." | "..data.zone,
            blip = {
                radiusblip = false,
                sprite = 184,
                color = 1, 
                scale = 1.0, 
                text = '10-49 - Speed Trap',
                time = (1*60*1000), -- 1 mins
            },
            notifysound = 0,
            priority = 0,
        })
    end
end)

RegisterServerEvent('prp-policedispatch:SupplyRun', function(data, shipment)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-37 Illegal Cargo',
        description = "An encrypted message was sent out to all citizens, the Cyber Division at MRPD has located its position, get there and collect the cargo",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = true,
            sprite = 478,
            color = 3, 
            scale = 1.0, 
            text = 'Illegal Shipment',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
        maxUnits = 3,
    })
end)

RegisterServerEvent('prp-policedispatch:Chopshop', function(data, shipment)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-84 BOLO: Intercepted Transmission',
        description = "Officers on the dark web have traced the phone of an individual looking to steal a " .. data.model ,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = true,
            sprite = 478,
            color = 2, 
            scale = 2.0, 
            text = 'Intercepted Transmission',
            time = (2*60*1000), -- 2 mins
        },
        notifysound = 2,
        priority = 2,
    })
end)

RegisterServerEvent('prp-policedispatch:PaletoBank', function()
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = shipment,
        title = '10-17 Paleto Bank Robbery',
        description = "Bank alarms have been triggered at Paleto Bank - Urgent assistance required",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 374,
            color = 3, 
            scale = 1.0, 
            text = 'Bank Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
        maxUnits = 4,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = shipment,
        title = 'Paleto Bank Robbery',
        description = "Sounds of alarms have been heard coming from Paleto Bank",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 374,
            color = 3, 
            scale = 1.0, 
            text = 'Bank Robbery',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)

RegisterServerEvent('prp-policedispatch:PrisonBreak', function(data, message)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-98 Prison Escape',
        description = message,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 126,
            color = 1, 
            scale = 2.0, 
            text = 'Prison Escape',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
        maxUnits = 3,
    })
end)

RegisterServerEvent('prp-policedispatch:CornerSelling', function(data, shipment)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-100 Hand-to-Hand',
        description = 'A '..data.playergender..' is reported to be selling drugs in the area',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = true,
            sprite = 478,
            color = 2, 
            scale = 2.0, 
            text = 'Drug Sale',
            time = (2*60*1000), -- 2 mins
        },
        notifysound = 2,
        priority = 2,
        maxUnits = 2,
    })
end)

RegisterServerEvent('prp-policedispatch:EMSCabinetAlarm', function(MyCoords)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'ambulance',
        coords = MyCoords,
        title = 'Emergency Cabinet Alarm',
        description = '<strong>Automated Message:</strong> Cabinet alarm has been triggered - Please investigate'..source,
        location = 'Base',
        blip = {
            radiusblip = false,
            sprite = 465,
            color = 1, 
            scale = 1.0, 
            text = 'Emergency Alarm',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 2,
    })
end)
----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------
--Main function to send dispatch alert to client to individual jobs
function SendToDispatch(data)
    TriggerClientEvent('prp-policedispatch:SendDispatchMessage', -1, data, myname)

    if data.job == "police" then
        exports['prp-tab']:Webhook("DevDispatch", data.title, data.description, 0)
    end
end

--Get Roleplay name
function GetRoleplayInfo(identifier)
    local xPlayer = Cake.GetPlayerFromIdentifier(identifier)

    return xPlayer.completename
end

--Dispatch Respond | Send response 
Cake.Net.RegisterJobEvent("prp-policedispatch:UpdateRespond", function(xPlayer, CallSign, Uniqueid, RoleplayName)
    TriggerClientEvent('prp-policedispatch:UpdateRespond', -1, CallSign, Uniqueid, RoleplayName)
end, {"police", "ambulance", "agency", "mechanic", "weazel", "offmechanic", "offambulance", "offpolice"})

Cake.Net.RegisterJobEvent("prp-policedispatch:UpdateRespondRemove", function(xPlayer, CallSign, Uniqueid, RoleplayName)
    TriggerClientEvent('prp-policedispatch:UpdateRespondRemove', -1, CallSign, Uniqueid, RoleplayName)
end, {"police", "ambulance", "agency", "mechanic", "weazel", "offmechanic", "offambulance", "offpolice"})

----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------




-- --------------------------------------------------TEST FUNCTION - /trigger
-- local randomCalls = {
--     {Call = "10-1 | Shooting", Coords = vector3(1222.59, 1899.97, 77.92), Message = "Shooting of a kitten up a tree"},
--     {Call = "10-12 | Driveby", Coords = vector3(1029.93, 2461.35, 45.98), Message = "Some mofo shot out his car window"},
--     {Call = "10-2 | Bank Robbery", Coords = vector3(-2080.24, 2611.38, 3.08), Message = "Robbing a bank in his underpants"},
--     {Call = "10-10 | Assault", Coords = vector3(-2187.32, 4250.87, 48.94), Message = "Someone just kicked a granny in the balls, do they have balls?"}
-- }
-- local randomJob = {
--     {Name = 'police'}, 
--     {Name = 'ambulance'},
-- }

-- RegisterServerEvent('prp-policedispatch:Test')
-- AddEventHandler('prp-policedispatch:Test', function(data)
--     dispatch_ID = dispatch_ID + 1
--     local randomCall = math.random(1, #randomCalls)
--     local getJob = math.random(1, #randomJob)
--     SendToDispatch({
--         id = dispatch_ID,
--         job = randomJob[getJob].Name,
--         coords = randomCalls[randomCall].Coords,
--         title = randomCalls[randomCall].Call,
--         description = randomCalls[randomCall].Message,
--         location = data.road.." | "..data.zone,
--         blip = {
--             sprite = 313,
--             color = 1, 
--             scale = 1.0, 
--             text = randomCalls[randomCall].Call,
--             time = (1*60*1000), -- 1 mins
--         },
--         notifysound = 1, 
--         priority = 0, -- 1 is flashy thing for prio such as panic and big bank
--     })
--     -- SendToDispatchGroup({
--     --     id = dispatch_ID,
--     --     job = 'ambulance',
--     --     coords = randomCalls[randomCall].Coords,
--     --     title = randomCalls[randomCall].Call,
--     --     description = randomCalls[randomCall].Message,
--     --     location = data.road.." | "..data.zone,
--     --     blip = {
--     --         sprite = 313,
--     --         color = 1, 
--     --         scale = 1.0, 
--     --         text = randomCalls[randomCall].Call,
--     --         time = (1*60*1000), -- 1 mins
--     --     },
--     --     notifysound = 1, 
--     --     priority = 0, -- 1 is flashy thing for prio such as panic and big bank
--     -- })
-- end)
-- --------------------------------------------------END TEST FUNCTION

RegisterServerEvent('prp-policedispatch:BackupRequest', function(data, type)
    local _source = source
    local xPlayer = Cake.GetPlayerFromId(_source)
    local name = xPlayer.getCompleteName()

    if data.zone == nil then
        data.zone = ""
    end

    local RadioChannel = Player(_source).state['radioChannel']

    if RadioChannel == 0 then
        RadioChannel = "N/A"
    end

    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-36 Backup Request (Radio: ' .. RadioChannel .. ")",
        description = name..' has requested backup at their location<br><strong>Radio: </strong> '..RadioChannel,
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 306,
            color = 3, 
            scale = 1.0, 
            text = 'Backup Request',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 1,
        priority = 3,
        maxUnits = 2,
    })
end)

RegisterServerEvent('prp-policedispatch:SendExplosion', function(data)
    dispatch_ID = dispatch_ID + 1
    -- Send to EMS --
    SendToDispatch({
        id = dispatch_ID,
        job = "ambulance",
        coords = data.coords,
        title = '10-54 Loud Explosion',
        description = 'A large vehicle explosion has been heard',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 380,
            color = 1, 
            scale = 1.0, 
            text = 'Loud Explosion',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
    })

    -- Send to PD --
    SendToDispatch({
        id = dispatch_ID,
        job = "police",
        coords = data.coords,
        title = '10-54 Loud Explosion',
        description = 'A large vehicle explosion has been heard',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 380,
            color = 1, 
            scale = 1.0, 
            text = 'Loud Explosion',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
    })

    -- Send to Weazel --
    SendToDispatch({
        id = dispatch_ID,
        job = "weazel",
        coords = data.coords,
        title = 'Big Bang',
        description = 'A large explosion has been heard',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 380,
            color = 1, 
            scale = 1.0, 
            text = 'Loud Explosion',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 0,
    })
end)

RegisterServerEvent('prp-policedispatch:Fire', function(data)
    dispatch_ID = dispatch_ID + 1
    -- Send to EMS --
    SendToDispatch({
        id = dispatch_ID,
        job = "ambulance",
        coords = data.coords,
        title = '10-54 Fire',
        description = 'A large fire has been reported',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 380,
            color = 1, 
            scale = 1.0, 
            text = 'Fire',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
    })

    -- Send to PD --
    SendToDispatch({
        id = dispatch_ID,
        job = "police",
        coords = data.coords,
        title = '10-54 Fire',
        description = 'A large fire has been reported',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 380,
            color = 1, 
            scale = 1.0, 
            text = 'Fire',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
    })

    -- Send to Weazel --
    SendToDispatch({
        id = dispatch_ID,
        job = "weazel",
        coords = data.coords,
        title = 'Fire Spotted',
        description = 'A large fire has been reported',
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 380,
            color = 1, 
            scale = 1.0, 
            text = 'Fire',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 2,
        priority = 1,
    })
end)

local Cops = {}

Cake.Net.RegisterJobEvent("prp-policedispatch:RegisterAsCop", function(xPlayer)
    local Src = xPlayer.source

    Cops[Src] = {xPlayer.getCompleteName()}    
end, {"police", "ambulance", "agency", "mechanic", "weazel", "offpolice", "offambulance"})

RegisterNetEvent("prp-policedispatch:DeregisterAsCop", function()
    local Src = source

    Cops[Src] = nil
end)

AddEventHandler('playerDropped', function()
    Cops[source] = nil
end)

Cake.RegisterServerCallback("prp-policedispatch:GetCops", function(Source, Cb)
    local Results = {}
    local MyRadioChannel = Player(Source).state['radioChannel']

    for k, v in pairs(Cops) do
        if Source ~= k then
            local RadioChannel = Player(k).state['radioChannel']

            if RadioChannel == MyRadioChannel then
                local PlayerPed = GetPlayerPed(k)
                local Coords = GetEntityCoords(PlayerPed)

                table.insert(Results, { Id = k, Officer = v, Coords = Coords, Radio = RadioChannel, CallSign = Player(k).state.callsign})
            end
        end
    end

    Cb(Results)
end)

Cake.Net.RegisterJobEvent("prp-policedispatch:LocationUpdate", function(xPlayer, Id)
    local Source = xPlayer.source

    if Cops[Id] ~= nil then
        local PlayerPed = GetPlayerPed(Id)
        local Coords = GetEntityCoords(PlayerPed)

        TriggerClientEvent("prp-policedispatch:LocationUpdate", Source, Coords)
    else
        TriggerClientEvent("prp-policedispatch:LocationUpdate", Source, nil)
    end
end, {"police", "ambulance", "agency", "mechanic", "weazel"})

Cake.Net.RegisterServerCallback("prp-policedispatch:IsCCTVEnabled", function(Source, Camera)
    return EnabledCCTV[tostring(Camera)] ~= nil
end)

--Door Alarm
RegisterServerEvent('prp-policedispatch:DoorBreached', function(data)
    dispatch_ID = dispatch_ID + 1
    SendToDispatch({
        id = dispatch_ID,
        job = 'police',
        coords = data.coords,
        title = '10-94 Door Alarm',
        description = "A loud door alarm has been heard",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 622,
            color = 1, 
            scale = 2.0, 
            text = 'Door Alarm',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
    SendToDispatch({
        id = dispatch_ID,
        job = 'weazel',
        coords = data.coords,
        title = 'Loud Alarm',
        description = "A loud alarm has been heard",
        location = data.road.." | "..data.zone,
        blip = {
            radiusblip = false,
            sprite = 622,
            color = 1, 
            scale = 2.0, 
            text = 'Door Alarm',
            time = (1*60*1000), -- 1 mins
        },
        notifysound = 3,
        priority = 1,
    })
end)