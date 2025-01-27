--- @param source number Player source ID
RegisterServerEvent("LSC:AntiAFK:kick")
AddEventHandler("LSC:AntiAFK:kick", function()
    local playerName = GetPlayerName(source)
    
    TriggerClientEvent('chat:addMessage', -1, {
        color = {255, 99, 71},
        multiline = true,
        args = {"[Auto-Kick]", ("%s has been kicked for being AFK."):format(playerName)}
    })

    DropPlayer(source, "You have been kicked for being AFK.")
end)