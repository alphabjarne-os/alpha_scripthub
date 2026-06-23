local Window = _G.AlphaWindow
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

local function parseShortenedNumber(str)
    if not str then return 0 end
    
    local clean = str:gsub("[$,]", "")
    local suffix = clean:match("%a+$")
    
    if not suffix then
        return tonumber(clean) or 0
    end
    
    local numStr = clean:gsub("%a+$", "")
    local num = tonumber(numStr) or 0
    
    local multipliers = {
        K = 1e3,
        M = 1e6,
        B = 1e9,
        T = 1e12,
        Q = 1e15,
        Qa = 1e15,
        Qi = 1e18,
        Sx = 1e21,
        Sp = 1e24,
        Oc = 1e27,
        No = 1e30
    }
    
    local mult = multipliers[suffix] or 1
    return num * mult
end

local function getPrice(floor, upgrade)
    if not myPlot then return 0 end
    local floorObj = myPlot:FindFirstChild(floor)
    if floorObj then
        local upgradeObj = floorObj:FindFirstChild(upgrade)
        if upgradeObj and upgradeObj:FindFirstChild("UpgradeSign") and upgradeObj.UpgradeSign:FindFirstChild("Display") and upgradeObj.UpgradeSign.Display:FindFirstChild("SurfaceGui") then
            local mainFrame = upgradeObj.UpgradeSign.Display.SurfaceGui:FindFirstChild("MainFrame")
            if mainFrame and mainFrame:FindFirstChild("Price") and mainFrame.Price:FindFirstChild("Txt") then
                return parseShortenedNumber(mainFrame.Price.Txt.Text)
            end
        end
    end
    return 0
end

local function getMyMoney()
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local money = leaderstats:FindFirstChild("Money") or leaderstats:FindFirstChild("Cash")
        if money then 
            if type(money.Value) == "string" then
                return parseShortenedNumber(money.Value)
            end
            return money.Value 
        end
    end
    
    local attrMoney = player:GetAttribute("Money") or player:GetAttribute("Cash")
    if type(attrMoney) == "string" then
        return parseShortenedNumber(attrMoney)
    end
    return attrMoney or 0
end

local MainTab = Window:CreateTab("Main", 4483362458)
MainTab:CreateSection("Automation")

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

local function addFloorSection(floorId, displayName)
    MainTab:CreateSection("Auto Upgrade (" .. displayName .. ")")
    
    local toggles = {
        ExtraYield = false,
        ExtraSawRange = false,
        ExtraPower = false,
        ExtraSprinklerRange = false
    }
    
    local upgradeOrder = {"ExtraYield", "ExtraSawRange", "ExtraPower", "ExtraSprinklerRange"}
    
    for _, upgradeName in ipairs(upgradeOrder) do
        MainTab:CreateToggle({
            Name = "Auto " .. upgradeName .. " Upgrade",
            CurrentValue = false,
            Flag = floorId .. upgradeName .. "Toggle",
            Callback = function(Value)
                toggles[upgradeName] = Value
                if Value then
                    task.spawn(function()
                        while toggles[upgradeName] do
                            if not myPlot then myPlot = findMyPlot() end
                            if myPlot then
                                local price = getPrice(floorId, upgradeName)
                                local currentMoney = getMyMoney()
                                if currentMoney >= price then
                                    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") 
                                        and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("PlotUpgradeTransaction")
                                    if remote then
                                        remote:InvokeServer(upgradeName, floorId)
                                    end
                                end
                            end
                            task.wait(1)
                        end
                    end)
                end
            end
        })
    end
end

addFloorSection("Floor1", "Floor 1")
addFloorSection("Floor2", "Floor 2")
addFloorSection("Floor3", "Floor 3")
addFloorSection("Floor4", "Floor 4")