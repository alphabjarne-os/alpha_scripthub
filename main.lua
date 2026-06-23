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

_G.AlphaScriptExecutionId = (_G.AlphaScriptExecutionId or 0) + 1

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
    
    local func, compileError = loadstring(scriptContent)
    
    if func then
        local runSuccess, runError = pcall(func)
        if not runSuccess then
            warn("!!! ALPHAHUB RUNTIME ERROR !!!")
            print(tostring(runError))
            Rayfield:Notify({
                Name = "Runtime Error",
                Content = "Script crashed during execution! Check F9 Console.",
                Duration = 10,
                Image = 4483362458,
            })
        end
    else
        warn("!!! ALPHAHUB COMPILATION ERROR (SYNTAX FEHLER) !!!")
        print(tostring(compileError))
        Rayfield:Notify({
            Name = "Syntax Error",
            Content = "Failed to compile game script! Check F9 Console for details.",
            Duration = 10,
            Image = 4483362458,
        })
    end
end