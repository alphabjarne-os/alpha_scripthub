local function freshGet(url)
    local success, content = pcall(function()
        return game:HttpGet(url .. "?nocache=" .. math.random(1, 100000))
    end)
    if success then return content end
    return nil
end

if game:GetService("CoreGui"):FindFirstChild("Rayfield") then
    game:GetService("CoreGui").Rayfield:Destroy()
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local placeId = tostring(game.PlaceId)
local baseUrl = "https://raw.githubusercontent.com/alphabjarne-os/alpha_scripthub/refs/heads/main/games/"

local scriptContent = freshGet(baseUrl .. placeId .. ".lua")

if scriptContent and not scriptContent:find("404") and not scriptContent:find("Not Found") then
    task.wait(0.5)
    Rayfield:Destroy()
    
    local runSuccess, runError = pcall(function()
        local func = loadstring(scriptContent)
        if func then
            func()
        else
            error("Failed to compile script")
        end
    end)
    
    if not runSuccess then
        local ErrorRayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
        local Window = ErrorRayfield:CreateWindow({
            Name = "Error Hub",
            LoadingTitle = "Script Error",
            LoadingSubtitle = "by alphabjarne-os",
            ConfigurationSaving = {Enabled = false, FolderName = nil, FileName = "Error"},
            Discord = {Enabled = false, Invite = "noinvitelink", RememberJoins = true},
            KeySystem = false,
        })
        ErrorRayfield:Notify({
            Title = "Execution Error",
            Content = "Your game script has a syntax error!",
            Duration = 10,
            Image = 4483362458,
        })
        warn("AlphaHub Error: " .. tostring(runError))
    end
else
    local Window = Rayfield:CreateWindow({
        Name = "Universal Hub",
        LoadingTitle = "Rayfield Interface Suite",
        LoadingSubtitle = "by alphabjarne-os",
        ConfigurationSaving = {Enabled = false, FolderName = nil, FileName = "Universal"},
        Discord = {Enabled = false, Invite = "noinvitelink", RememberJoins = true},
    })
    
    local MainTab = Window:CreateTab("Universal", 4483362458)
    MainTab:CreateSection("Game ID: " .. placeId)
    MainTab:CreateSection("Status: Not Supported Yet")
    
    Rayfield:Notify({
        Title = "Universal Mode",
        Content = "Looking for: " .. placeId .. ".lua (Not found)",
        Duration = 7,
        Image = 4483362458,
    })
end