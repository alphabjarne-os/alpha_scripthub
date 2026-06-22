local Window = _G.AlphaWindow
local MainTab = Window:CreateTab("Main", 4483362458)
local SectionSell = MainTab:CreateSection("Automation")

local player = game.Players.LocalPlayer
local myPlot = nil

local function findMyPlot()
    local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
    if plots and player then
        for _, plot in ipairs(plots:GetChildren()) do
            if plot:GetAttribute("OwnerUserId") == player.UserId then
                return plot
            end
        end
    end
    return nil
end

myPlot = findMyPlot()

local AutoSellEnabled = false

local AutoSell = MainTab:CreateToggle({
    Name = "AutoSell",
    CurrentValue = false,
    Flag = "AutoSellToggle",
    Callback = function(Value)
        AutoSellEnabled = Value
        
        if AutoSellEnabled then
            task.spawn(function()
                while AutoSellEnabled do
                    if not myPlot then
                        myPlot = findMyPlot()
                    end
                    
                    if myPlot then
                        local sellCrates = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") 
                            and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("SellCrates")
                            
                        if sellCrates then
                            sellCrates:FireServer()
                        end
                    end
                    
                    task.wait(1)
                end
            end)
        end
    end,
})