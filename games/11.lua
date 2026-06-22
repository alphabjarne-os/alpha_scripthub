local function freshGet(url)
    return game:HttpGet(url .. "?nocache=" .. math.random(1, 100000))
end

local Rayfield = loadstring(freshGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Game Hub",
    LoadingTitle = "Loading Features...",
    LoadingSubtitle = "by alphabjarne-os",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil, 
        FileName = "GameConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 4483362458)
local Section = MainTab:CreateSection("Movement")

local Slider = MainTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 150},
    Increment = 1,
    Suffix = " studs/s",
    CurrentValue = 16,
    Flag = "SpeedSlider",
    Callback = function(Value)
        local player = game.Players.LocalPlayer
        if player and player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid.WalkSpeed = Value
        end
    end,
})

local InfiniteJumpEnabled = false
local Toggle = MainTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "JumpToggle",
    Callback = function(Value)
        InfiniteJumpEnabled = Value
    end,
})

game:GetService("UserInputService").JumpRequest:Connect(function()
    if InfiniteJumpEnabled then
        local player = game.Players.LocalPlayer
        if player and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
            player.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
        end
    end
end)

Rayfield:Notify({
    Title = "Success",
    Content = "Game script initialized perfectly.",
    Duration = 5,
    Image = 4483362458,
})