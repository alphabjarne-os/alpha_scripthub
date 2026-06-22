local function freshGet(url)
    return game:HttpGet(url .. "?nocache=" .. math.random(1, 100000))
end

if game:GetService("CoreGui"):FindFirstChild("Rayfield") then
    game:GetService("CoreGui").Rayfield:Destroy()
end

local placeId = tostring(game.PlaceId)
local baseUrl = "https://raw.githubusercontent.com/alphabjarne-os/alpha_scripthub/refs/heads/main/games/"

local success, scriptContent = pcall(function()
    return freshGet(baseUrl .. placeId .. ".lua")
end)

if success and scriptContent and not scriptContent:find("404: Not Found") then
    loadstring(scriptContent)()
else
    local Rayfield = loadstring(freshGet('https://sirius.menu/rayfield'))()
    local Window = Rayfield:CreateWindow({
        Name = "Universal Hub",
        LoadingTitle = "Rayfield Interface Suite",
        LoadingSubtitle = "by Sirius",
        ConfigurationSaving = {Enabled = false, FolderName = nil, FileName = "Universal"},
        Discord = {Enabled = false, Invite = "noinvitelink", RememberJoins = true},
        KeySystem = false,
    })
    
    local MainTab = Window:CreateTab("General", 4483362458)
    MainTab:CreateSection("Game not supported. Running Universal.")
    
    Rayfield:Notify({
        Title = "Warning",
        Content = "No specific script found for this Game ID. Loaded universal features.",
        Duration = 5,
        Image = 4483362458,
    })
end