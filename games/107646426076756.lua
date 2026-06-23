local Window = _G.AlphaWindow
local currentExecId = _G.AlphaScriptExecutionId
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
    local clean = str:gsub("[$,%s]", "")
    if clean:lower():find("max") then return -1 end
    
    local suffix = clean:match("%a+$")
    if not suffix then
        return tonumber(clean) or 0
    end
    
    local numStr = clean:gsub("%a+$", "")
    local num = tonumber(numStr) or 0
    
    local multipliers = {
        K = 1e3, M = 1e6, B = 1e9, T = 1e12,
        Q = 1e15, Qa = 1e15, Qi = 1e18, Sx = 1e21,
        Sp = 1e24, Oc = 1e27, No = 1e30
    }
    
    local mult = multipliers[suffix] or 1
    return num * mult
end

local function getPrice(floor, upgrade)
    if not myPlot then return -1 end
    local floorObj = myPlot:FindFirstChild(floor)
    if floorObj then
        local sign = floorObj:FindFirstChild("PlotUpgradeSign")
        if sign and sign:FindFirstChild("Screen") and sign.Screen:FindFirstChild("SurfaceGui") then
            local upgradeFrame = sign.Screen.SurfaceGui:FindFirstChild(upgrade)
            if upgradeFrame and upgradeFrame:FindFirstChild("Btn") and upgradeFrame.Btn:FindFirstChild("Txt") then
                local priceText = upgradeFrame.Btn.Txt.Text
                return parseShortenedNumber(priceText)
            end
        end
    end
    return -1
end

local function getMyMoney()
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local moneyObj = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Money")
        if moneyObj then 
            local val = moneyObj.Value
            if type(val) == "string" then
                return parseShortenedNumber(val)
            elseif type(val) == "number" then
                return val
            end
        end
    end
    return 0
end

local MainTab = Window:CreateTab("Main", 4483362458)
MainTab:CreateSection("Automation")

local AutoSellEnabled = false
MainTab:CreateToggle({
    Name = "AutoSell",
    CurrentValue = false,
    Flag = "AlphaMainAutoSellToggle",
    Callback = function(Value)
        AutoSellEnabled = Value
        if AutoSellEnabled then
            task.spawn(function()
                while AutoSellEnabled and _G.AlphaScriptExecutionId == currentExecId do
                    if not myPlot then myPlot = findMyPlot() end
                    if myPlot then
                        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                        local sellCrates = remotes and remotes:FindFirstChild("SellCrates")
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

local activeToggles = {}

local function addFloorSection(floorId, displayName)
    MainTab:CreateSection("Auto Upgrade (" .. displayName .. ")")
    
    local upgradeOrder = {"ExtraYield", "ExtraSawRange", "ExtraPower", "ExtraSprinklerRange"}
    
    local internalNames = {
        ExtraYield = "ExtraYield",
        ExtraSawRange = "SawRange",
        ExtraPower = "ExtraPower",
        ExtraSprinklerRange = "ExtraSprinklerRange"
    }
    
    for _, upgradeName in ipairs(upgradeOrder) do
        local toggleKey = floorId .. "_" .. upgradeName
        activeToggles[toggleKey] = false
        
        local internalUiName = internalNames[upgradeName]
        
        MainTab:CreateToggle({
            Name = "Auto " .. upgradeName .. " Upgrade",
            CurrentValue = false,
            Flag = "Flag_" .. toggleKey,
            Callback = function(Value)
                activeToggles[toggleKey] = Value
                if Value then
                    task.spawn(function()
                        while activeToggles[toggleKey] and _G.AlphaScriptExecutionId == currentExecId do
                            if not myPlot then myPlot = findMyPlot() end
                            if myPlot then
                                local price = getPrice(floorId, internalUiName)
                                local currentMoney = getMyMoney()
                                
                                if price > 0 and currentMoney >= price then
                                    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                                    local remote = remotes and remotes:FindFirstChild("PlotUpgradeTransaction")
                                    if remote then
                                        remote:InvokeServer(upgradeName, floorId)
                                        task.wait(2)
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