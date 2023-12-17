GetVehicleProperties = function(vehicle)
    local vehicleLabel = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
    local primary, secondary = GetVehicleColours(vehicle)
    local carcolour = Cake.Utils.GetVehicleColour(vehicle)
    local vehicleplate = GetVehicleNumberPlateText(vehicle)
    local vehiclecoords = GetEntityCoords(vehicle)

    --Vehicle Label
    if vehicleLabel == 'null' or vehicleLabel == 'NULL' or vehicleLabel == 'Not Found' then
        vehicleLabel = 'Vehicle'
    end
    if vehicleLabel ~= 'null' or vehicleLabel ~= 'NULL' or vehicleLabel ~= 'Not Found' then
        local text = GetLabelText(vehicleLabel)
        if text == nil or text == 'null' or text == 'NULL' then
            vehicleLabel = vehicleLabel
        else
            vehicleLabel = text
        end
    end

    return{carcolour = carcolour, vehicleLabel = vehicleLabel, vehicleplate = vehicleplate, vehiclecoords = vehiclecoords}
end

GetStreetNames = function(Coords)
    local StreetNames = Cake.Utils.GetRoadName(Coords.x, Coords.y, Coords.z)

    return {roadname = StreetNames[1], zone = StreetNames[2]}
end

CardinalDirectionFromHeading = function(heading)
    if heading >= 315 or heading < 45 then
        return "North Bound"
    elseif heading >= 45 and heading < 135 then
        return "West Bound"
    elseif heading >=135 and heading < 225 then
        return "South Bound"
    elseif heading >= 225 and heading < 315 then
        return "East Bound"
    end
  end

local CoordsOverride = nil

--Main function that is requested
GetPlayerDetails = function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    if CoordsOverride ~= nil then
        coords = CoordsOverride
    end
    
    local location = GetStreetNames(coords)
    local playergender = Cake.Utils.GetPedGender(playerPed)
    local compass = CardinalDirectionFromHeading(math.floor(GetEntityHeading(playerPed) + 0.5))

    --Vehicle Checks
    if IsPedInAnyVehicle(playerPed, false) then
        vehicle = GetVehiclePedIsIn(playerPed, false)
        vehicleProperties = GetVehicleProperties(vehicle)
        vehicle_colour = vehicleProperties.carcolour
        vehicle_label = vehicleProperties.vehicleLabel
        vehicle_plate = vehicleProperties.vehicleplate
        vehicle_coords = vehicleProperties.vehiclecoords
    else
        vehicle = nil
        vehicle_label = nil
        vehicle_colour = nil
        vehicle_plate = nil
        vehicle_coords = nil
    end

    if location.zone == nil then
        location.zone = "Unknown"
    end

    if location.road == nil then
        location.road = "Unknown"
    end

    return {
        playergender = playergender,
        coords = coords,
        heading = compass,
        road = location.roadname:gsub("'", ""),
        zone = location.zone:gsub("'", ""),
        vehicle = vehicle,
        vehicle_colour =  vehicle_colour,
        vehicle_label = vehicle_label,
        vehicle_plate = vehicle_plate,
        vehicle_coords = vehicle_coords
    }
end

GetPedDetails = function(playerPed)
    local coords = GetEntityCoords(playerPed)

    if CoordsOverride ~= nil then
        coords = CoordsOverride
    end

    local location = GetStreetNames(coords)
    
    local playergender = Cake.Utils.GetPedGender(playerPed)
    local compass = CardinalDirectionFromHeading(math.floor(GetEntityHeading(playerPed) + 0.5))

    --Vehicle Checks
    if IsPedInAnyVehicle(playerPed, false) then
        vehicle = GetVehiclePedIsIn(playerPed, false)
        vehicleProperties = GetVehicleProperties(vehicle)
        vehicle_colour = vehicleProperties.carcolour
        vehicle_label = vehicleProperties.vehicleLabel
        vehicle_plate = vehicleProperties.vehicleplate
        vehicle_coords = vehicleProperties.vehiclecoords
    else
        vehicle = nil
        vehicle_label = nil
        vehicle_colour = nil
        vehicle_plate = nil
        vehicle_coords = nil
    end

    return {
        playergender = playergender,
        coords = coords,
        heading = compass,
        road = location.roadname,
        zone = location.zone,
        vehicle = vehicle,
        vehicle_colour =  vehicle_colour,
        vehicle_label = vehicle_label,
        vehicle_plate = vehicle_plate,
        vehicle_coords = vehicle_coords
    }
end

TriggerEventWithDetails = function(event)
    TriggerServerEvent(event, GetPlayerDetails())
end

GetColourName = function(color)
    --Vehicle Colour
    for k, v in pairs (CarColours) do
        if v.index == color then
            return string.gsub(" "..v.label, "%W%l", string.upper):sub(2)
        end
    end

    return "Unknown"
end

DoPanicAnimation = function(Time, Callback)
    local PlayerPed = Cake.Cache.PlayerPedId()

    TaskPlayAnim(PlayerPed, Config.Panic.Dict, Config.Panic.Anim, 1.0, -1.0, Time, 49, 1, false, false, false)

    exports['prp-cprogress']:Progress({
        duration = Time,
        label = 'Transmitting',
        icon = 'fas fa-exclamation-triangle',
        useWhileDead = false,
        canCancel = true,
        controlDisables = {
            lockinv = false,
            freezeplayer = false,
            shoot = false,
            disarm = false,
        },
    }, function(IsStopped)
        if not LocalPlayer.state.isDead then
            ClearPedTasks(PlayerPed)
        end

        UsingButton = false

        if IsStopped then
            Callback(false)
        else
            Callback(true)
        end
    end)                    
end

exports('OverrideCoords', function(Coords)
    CoordsOverride = Coords
end)