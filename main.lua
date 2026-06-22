local function freshGet(url)
    return game:HttpGet(url .. "?nocache=" .. math.random(1, 100000))
end

if game:GetService("CoreGui"):FindFirstChild("Rayfield") then
    game:GetService("CoreGui").Rayfield:Destroy()
end

local Rayfield = loadstring(freshGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Alpha Hub",
    LoadingTitle = "Checking Game ID...",
    LoadingSubtitle = "by alphabjarne-os",
    ConfigurationSaving = {Enabled = false, FolderName = nil, FileName = "AlphaHub"},
    Discord = {Enabled = false, Invite = "noinvitelink", RememberJoins = true},
    KeySystem = false,
})

local placeId = tostring(game.PlaceId)
local baseUrl = "https://raw.githubusercontent.com/alphabjarne-os/alpha_scripthub/refs/heads/main/games/"

local success, scriptContent = pcall(function()
    return freshGet(baseUrl .. placeId .. ".lua")
end)

if success and scriptContent and not scriptContent:find("404: Not Found") then
    task.wait(1)
    Window:Destroy()
    loadstring(scriptContent)()
else
    local MainTab = Window:CreateTab("Universal", 4483362458)
    MainTab:CreateSection("Game Not Supported")
    
    Rayfield:Notify({
        Title = "Universal Mode",
        Content = "No specific script found for this game. Running universal features.",
        Duration = 5,
        Image = 4483362458,
    })
end