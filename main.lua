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
    _G.AlphaWindow = Rayfield:CreateWindow({
        Name = "Alpha Hub",
        LoadingTitle = "Loading Game Features...",
        LoadingSubtitle = "by alphabjarne-os",
        ConfigurationSaving = {Enabled = false, FolderName = nil, FileName = "AlphaHub"},
        Discord = {Enabled = false, Invite = "noinvitelink", RememberJoins = true},
        KeySystem = false,
    })
    
    local runSuccess, runError = pcall(function()
        local func = loadstring(scriptContent)
        if func then
            func()
        else
            error("Failed to compile script")
        end
    end)
    
    if not runSuccess then
        warn("AlphaHub Error: " .. tostring(runError))
    end
end