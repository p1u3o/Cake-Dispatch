Cake = exports['prp-core']:getSharedObject()

Config = {}

--[[ Only these job can use dispatch ]] --
Config.Whitelisted = {
    ["police"] = true,
    ["agency"] = true,
    ["ambulance"] = true,
    ["mechanic"] = true,
    ["weazel"] = true,
}

--[[ Request callsigns for these jobs ]] --
Config.CallSigns = {
    ["police"] = true,
    ["ambulance"] = true,
}

--[[ Agency role will also see police things ]]--
Config.Agency = "agency"

--[[ Input here function to detect if K9 is active, PlayerPed is passed as only argument ]] --
Config.IsK9Active = function(PlayerPed) 
    return exports["prp-policejob"]:IsK9Active()
end

--[[ Input here function to detect if Bike is active, PlayerPed is passed as only argument ]] --
Config.IsBikeActive = function(PlayerPed) 
    local CurrentPants = GetPedDrawableVariation(PlayerPed, 4)

    if CurrentPants == 190 then 
        return true
    else
        return false
    end
end

--[[ Input here function to detect if Eagle is active, PlayerPed is passed as only argument ]] --
Config.IsEagleActive = function(PlayerPed) 
    local CurrentHat = GetPedPropIndex(PlayerPed, 0)

    if CurrentHat == 192 then 
        return true
    else
        return false
    end
end

--[[ Input here function to detect if Eagle is active, PlayerPed is passed as only argument ]] --
Config.IsHeatActive = function(PlayerPed) 
    local CurrentCar = GetVehiclePedIsIn(PlayerPed, true)

    if CurrentCar == nil or CurrentCar == false then
        return false
    else
        local Model = GetEntityModel(CurrentCar)
        
        if Model == `POLVETTE` then
            return true
        else
            return false
        end
    end
end

--[[ Jobs here do not network responses.. ]] --
Config.NoNetwork = {
    ["weazel"] = true,
    ["agency"] = true,
}

-- [[ Weazel.. ]]
Config.Weazel = "weazel"

-- [[ Emergency Services ]] --
Config.Government = {
    ["police"] = true,
    ["ambulance"] = true,
    ["agency"] = true,
}

Config.Panic = {
    Item = "radio",
    Dict = "random@arrests",
    Anim = "generic_radio_chatter",
    Duration = 3000
}