--- @class AFKSystem
local AFKSystem = {
    --- @type string Characters used in CAPTCHA generation
    captchaChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
    --- @type boolean Whether CAPTCHA is currently active
    captchaActive = false,
    --- @type any Current zone instance
    currentZone = nil,
    --- @type any Current timer instance
    currentTimer = nil
}

--- @param length number Length of the CAPTCHA
--- @return string captcha The generated CAPTCHA string
local function generateCaptcha(length)
    if length < 1 then length = 6 end
    local captcha = {}
    for i = 1, length do
        local rand = math.random(1, #AFKSystem.captchaChars)
        captcha[i] = AFKSystem.captchaChars:sub(rand, rand)
    end
    return table.concat(captcha)
end

--- @param title string Title of the notification
--- @param description string Description of the notification
--- @param type string Type of notification ('success', 'error', 'inform')
local function showNotification(title, description, type)
    lib.notify({
        title = title,
        description = description,
        type = type
    })
end

local function checkAFK()
    if AFKSystem.captchaActive then return end
    AFKSystem.captchaActive = true

    local captcha = generateCaptcha(Config.captchaLength)
    local kickTimer = Config.kickTime
    local responded = false

    Citizen.CreateThread(function()
        while kickTimer > 0 and not responded do
            Wait(1000)
            kickTimer = kickTimer - 1
        end

        if not responded then
            TriggerServerEvent('LSC:AntiAFK:kick')
        end
    end)

    local input = lib.inputDialog('Anti-AFK Verification', {
        {
            type = 'input',
            label = 'CAPTCHA: ' .. captcha,
            description = 'Complete verification to avoid being kicked',
            required = true,
            min = Config.captchaLength,
            max = Config.captchaLength,
        }
    })
    

    if input and input[1] then
        if input[1] == captcha then
            responded = true
            AFKSystem.captchaActive = false
            showNotification(
                'AFK System',
                'CAPTCHA verified successfully',
                'success'
            )
            createNewZone()
        else
            showNotification(
                'AFK System',
                'Incorrect CAPTCHA. Please try again',
                'error'
            )
            AFKSystem.captchaActive = false
            checkAFK()
        end
    else
        TriggerServerEvent('LSC:AntiAFK:kick')
    end
end

local function onZoneExit(self)
    if AFKSystem.currentTimer and AFKSystem.currentTimer.destroy then
        AFKSystem.currentTimer:destroy()
        AFKSystem.currentTimer = nil
    end

    SetTimeout(10000, function()
        createNewZone()
    end)

    if AFKSystem.currentZone and AFKSystem.currentZone.destroy then
        AFKSystem.currentZone:destroy()
        AFKSystem.currentZone = nil
    end
end

function createNewZone()
    local playerPed = PlayerPedId()
    if not playerPed then return end

    local coords = GetEntityCoords(playerPed)

    AFKSystem.currentZone = lib.zones.sphere({
        coords = coords,
        radius = 2,
        debug = false,
        onExit = onZoneExit
    })

    AFKSystem.currentTimer = SetTimeout(Config.afkTimeMinutes * 60 * 1000, function()
        checkAFK()
    end)
end

CreateThread(function()
    while not DoesEntityExist(cache.ped) do
        Wait(250)
    end
    Wait(1000)
    createNewZone()
end)

RegisterCommand('testafk', function()
    checkAFK()
end, false)
