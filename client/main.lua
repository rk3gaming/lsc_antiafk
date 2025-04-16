--- @class AFKSystem
local AFKSystem = {
    --- @type string Characters used in CAPTCHA generation
    captchaChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
    --- @type boolean Whether CAPTCHA is currently active
    captchaActive = false,
    --- @type any Current zone instance
    currentZone = nil,
    --- @type any Current timer instance
    currentTimer = nil,
    --- @type number Last time CAPTCHA was successfully verified
    lastVerificationTime = 0
}

--- @param message string The debug message to print
local function debugPrint(message)
    if Config.debug then
        lib.print.debug('[LSC Anti-AFK] ' .. message)
    end
end

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
    debugPrint('checkAFK function started')
    local currentTime = GetGameTimer()
    local cooldownMs = (Config.afkTimeMinutes or 1) * 60 * 1000
    debugPrint(string.format('Current time: %d, Last verification: %d, Cooldown: %d', currentTime, AFKSystem.lastVerificationTime, cooldownMs))
    
    if AFKSystem.lastVerificationTime > 0 and currentTime - AFKSystem.lastVerificationTime < cooldownMs then
        debugPrint('Still in cooldown period')
        createNewZone()
        return
    end

    if AFKSystem.captchaActive then 
        debugPrint('CAPTCHA already active')
        return 
    end
    
    debugPrint('Starting CAPTCHA verification')
    AFKSystem.captchaActive = true

    local captcha = generateCaptcha(Config.captchaLength)
    local kickTimer = Config.kickTime
    local responded = false

    debugPrint('Created CAPTCHA: ' .. captcha)
    debugPrint('Starting kick timer: ' .. kickTimer .. ' seconds')

    Citizen.CreateThread(function()
        while kickTimer > 0 and not responded do
            Wait(1000)
            kickTimer = kickTimer - 1
            debugPrint('Kick timer: ' .. kickTimer .. ' seconds remaining')
        end

        if not responded then
            debugPrint('No response received, triggering kick')
            TriggerServerEvent('LSC:AntiAFK:kick')
        end
    end)

    debugPrint('Opening CAPTCHA dialog')
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

    debugPrint('Dialog result: ' .. (input and 'received' or 'none'))
    if input and input[1] then
        debugPrint('User input: ' .. input[1])
        if input[1] == captcha then
            debugPrint('CAPTCHA verification successful')
            responded = true
            AFKSystem.captchaActive = false
            AFKSystem.lastVerificationTime = GetGameTimer()
    
            if AFKSystem.currentZone and AFKSystem.currentZone.remove then
                AFKSystem.currentZone:remove()
                AFKSystem.currentZone = nil
            end
    
            showNotification(
                'AFK System',
                'CAPTCHA verified successfully',
                'success'
            )
    
            SetTimeout(1000, function()
                createNewZone()
            end)
    
        else
            debugPrint('Incorrect CAPTCHA entered')
            showNotification(
                'AFK System',
                'Incorrect CAPTCHA. Please try again',
                'error'
            )
            AFKSystem.captchaActive = false
            checkAFK()
        end
    else
        debugPrint('No input received or dialog cancelled')
        TriggerServerEvent('LSC:AntiAFK:kick')
    end
end

local function onZoneExit(self)
    if AFKSystem.currentTimer then
        ClearTimeout(AFKSystem.currentTimer)
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
    if AFKSystem.currentZone and AFKSystem.currentZone.remove then
        AFKSystem.currentZone:remove()
        AFKSystem.currentZone = nil
    end

    local playerPed = PlayerPedId()
    if not playerPed then return end

    local coords = GetEntityCoords(playerPed)

    AFKSystem.currentZone = lib.zones.sphere({
        coords = coords,
        radius = 0.1,
        debug = false,
        onExit = onZoneExit
    })

    if AFKSystem.currentTimer then
        ClearTimeout(AFKSystem.currentTimer)
        AFKSystem.currentTimer = nil
    end

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
    debugPrint('/testafk command triggered')
    checkAFK()
end, false)

debugPrint('Anti-AFK Started')
