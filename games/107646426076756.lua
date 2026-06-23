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
        K = 10^3, 
        M = 10^6, 
        B = 10^9, 
        T = 10^12,
        Q = 10^15, 
        Qa = 10^15, 
        Qi = 10^18, 
        Sx = 10^21,
        Sp = 10^24, 
        Oc = 10^27, 
        No = 10^30
    }
    
    local mult = multipliers[suffix] or 1
    return num * mult
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
    task.spawn(function()
        while not myPlot and _G.AlphaScriptExecutionId == currentExecId do
            myPlot = findMyPlot()
            task.wait(0.5)
        end
        
        if not myPlot then return end
        
        local floorObj = myPlot:WaitForChild(floorId, 5)
        local sign = floorObj and floorObj:WaitForChild("PlotUpgradeSign", 5)
        local screen = sign and sign:WaitForChild("Screen", 5)
        local surfaceGui = screen and screen:WaitForChild("SurfaceGui", 5)
        
        if not surfaceGui then return end
        
        MainTab:CreateSection("Auto Upgrade (" .. displayName .. ")")
        
        for _, child in ipairs(surfaceGui:GetChildren()) do
            if child:IsA("GuiObject") and child:FindFirstChild("Btn") and child.Btn:FindFirstChild("Txt") then
                local uiFrameName = child.Name
                
                local remoteUpgradeName = uiFrameName
                if not remoteUpgradeName:find("^Extra") then
                    remoteUpgradeName = "Extra" .. remoteUpgradeName
                end
                
                local toggleKey = floorId .. "_" .. remoteUpgradeName
                activeToggles[toggleKey] = false
                
                MainTab:CreateToggle({
                    Name = "Auto " .. remoteUpgradeName .. " Upgrade",
                    CurrentValue = false,
                    Flag = "Flag_" .. toggleKey,
                    Callback = function(Value)
                        activeToggles[toggleKey] = Value
                        if Value then
                            task.spawn(function()
                                while activeToggles[toggleKey] and _G.AlphaScriptExecutionId == currentExecId do
                                    if not myPlot then myPlot = findMyPlot() end
                                    if myPlot then
                                        local currentFloorObj = myPlot:FindFirstChild(floorId)
                                        local currentSign = currentFloorObj and currentFloorObj:FindFirstChild("PlotUpgradeSign")
                                        local currentGui = currentSign and currentSign:FindFirstChild("Screen") and currentSign.Screen:FindFirstChild("SurfaceGui")
                                        local currentFrame = currentGui and currentGui:FindFirstChild(uiFrameName)
                                        
                                        if currentFrame and currentFrame:FindFirstChild("Btn") and currentFrame.Btn:FindFirstChild("Txt") then
                                            local price = parseShortenedNumber(currentFrame.Btn.Txt.Text)
                                            local currentMoney = getMyMoney()
                                            
                                            if price > 0 and currentMoney >= price then
                                                local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                                                local remote = remotes and remotes:FindFirstChild("PlotUpgradeTransaction")
                                                if remote then
                                                    remote:InvokeServer(remoteUpgradeName, floorId)
                                                    task.wait(1.5)
                                                end
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
    end)
end

addFloorSection("Floor1", "Floor 1")
addFloorSection("Floor2", "Floor 2")
addFloorSection("Floor3", "Floor 3")
addFloorSection("Floor4", "Floor 4")