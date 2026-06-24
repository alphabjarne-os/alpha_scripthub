local Window = _G.AlphaWindow
local currentExecId = _G.AlphaScriptExecutionId

local virtualUser = game:GetService("VirtualUser")
player.Idled:Connect(function()
    if AntiAFKEnabled then
        virtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        virtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end)


local MainTab = Window:CreateTab("Main", 4483362458)
MainTab:CreateSection("Automation")

MainTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = false,
    Flag = "AlphaMainAntiAFKToggle",
    Callback = function(Value)
        AntiAFKEnabled = Value
    end,
})