--- @class Config
--- @field afkTimeMinutes number Minutes of inactivity before CAPTCHA appears
--- @field kickTime number Seconds to complete CAPTCHA before kick
--- @field captchaLength number Length of the CAPTCHA string
--- @field debug boolean Whether to show debug messages
Config = {
    afkTimeMinutes = 1,
    kickTime = 60,
    captchaLength = 6,
    debug = false
}
