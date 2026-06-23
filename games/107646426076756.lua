local Window = _G.AlphaWindow
local currentExecId = _G.AlphaScriptExecutionId
local player = game.Players.LocalPlayer
local myPlot = nil
local AntiAFKEnabled = false


local virtualUser = game:GetService("VirtualUser")
player.Idled:Connect(function()
    if AntiAFKEnabled then
        virtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        virtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end)

local function findMyPlot()
    local map = workspace:FindFirstChild("Map")
    local plots = map and map:FindFirstChild("Plots")
    if plots and player then
        for _, plot in ipairs(plots:GetChildren()) do
            if plot:GetAttribute("OwnerUserId") == player.UserId then
                return plot
            end
        end
    end
    return nil
end

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
        if not moneyObj then
            for _, child in ipairs(leaderstats:GetChildren()) do
                local name = child.Name:lower()
                if name:find("cash") or name:find("money") or name:find("coin") then
                    moneyObj = child
                    break
                end
            end
        end
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

MainTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = false,
    Flag = "AlphaMainAntiAFKToggle",
    Callback = function(Value)
        AntiAFKEnabled = Value
    end,
})

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

MainTab:CreateSection("Auto Upgrades")

MainTab:CreateToggle({
    Name = "Auto Upgrade Seed Rolls",
    CurrentValue = false,
    Flag = "AlphaMainAutoUpgradeSeedRolls",
    Callback = function(Value)
        AutoUpgradeSeedRolls = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto Upgrade Seed Luck",
    CurrentValue = false,
    Flag = "AlphaMainAutoUpgradeSeedLuck",
    Callback = function(Value)
        AutoUpgradeSeedLuck = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto Upgrade Farm",
    CurrentValue = false,
    Flag = "AlphaMainAutoUpgradeFarm",
    Callback = function(Value)
        AutoUpgradeFarm = Value
    end,
})

MainTab:CreateSection("Auto Roll")

local RollSeedsEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RollSeeds")
local RollAnimationDoneEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RollAnimationDone")
local BuySeedEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("BuySeed", 5)
local RaritiesConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Registry"):WaitForChild("Rarities"))
local PlantsConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Registry"):WaitForChild("Plants"))
local Configuration = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Configuration"))

local AutoRollEnabled = false
local currentRollId = nil
local isProcessingRoll = false
local lastSlotsData = nil
local AutoUpgradeSeedRolls = false
local AutoUpgradeSeedLuck = false
local AutoUpgradeFarm = false

local SelectedRarities = {}
local sortedRarities = {}
local seenRarities = {}

for name, data in pairs(RaritiesConfig) do
    if type(data) == "table" and data.Order then
        seenRarities[name:lower()] = true
        table.insert(sortedRarities, {Name = name, Order = data.Order})
    end
end

for _, plantData in pairs(PlantsConfig) do
    if type(plantData) == "table" and plantData.Rarity then
        local rarityName = plantData.Rarity
        if not seenRarities[rarityName:lower()] then
            seenRarities[rarityName:lower()] = true
            table.insert(sortedRarities, {Name = rarityName, Order = 999})
        end
    end
end

table.sort(sortedRarities, function(a, b)
    return a.Order < b.Order
end)

local function checkAndBuySeeds()
    if not lastSlotsData then return end
    if not myPlot then myPlot = findMyPlot() end
    local roller = myPlot and myPlot:FindFirstChild("SeedRoller")
    if not roller then return end
    
    local currentMoney = getMyMoney()
    for slotIndex, slot in ipairs(lastSlotsData) do
        local seedName = slot.Seed
        if seedName then
            local val = roller:GetAttribute("RolledSeed" .. tostring(slotIndex))
            if val == seedName then
                local plantData = PlantsConfig[seedName]
                if plantData then
                    local rarity = plantData.Rarity
                    local cost = plantData.Cost
                    
                    local rarityClean = rarity:match("^%s*(.-)%s*$")
                    local rarityLower = rarityClean:lower()
                    
                    local knownRarity = false
                    for _, rarityInfo in ipairs(sortedRarities) do
                        if rarityInfo.Name:lower() == rarityLower then
                            knownRarity = true
                            break
                        end
                    end
                    
                    local shouldBuy = false
                    if knownRarity then
                        shouldBuy = SelectedRarities[rarityLower] == true
                    else
                        shouldBuy = SelectedRarities["other"] == true
                    end
                    
                    if shouldBuy and currentMoney >= cost then
                        if BuySeedEvent then
                            pcall(function()
                                BuySeedEvent:FireServer(slotIndex)
                            end)
                            currentMoney = currentMoney - cost
                            local model = workspace:FindFirstChild(seedName)
                            if model then
                                model.Name = "ProcessedSeed"
                            end
                            task.wait(0.05)
                        else
                            warn("[Alpha Hub] BuySeed RemoteEvent not found!")
                        end
                    end
                end
            end
        end
    end
end

local rollConnection
rollConnection = RollSeedsEvent.OnClientEvent:Connect(function(arg1, arg2)
    if _G.AlphaScriptExecutionId ~= currentExecId then
        if rollConnection then
            rollConnection:Disconnect()
        end
        return
    end
    
    local rollId = nil
    local slots = nil
    if type(arg1) == "table" then
        rollId = arg1.RollId
        slots = arg1.Slots
    elseif type(arg1) == "number" then
        rollId = arg1
        slots = arg2
    end
    
    if rollId then
        isProcessingRoll = true
        currentRollId = rollId
        lastSlotsData = slots
        
        pcall(function()
            task.wait(0.05)
            local prompt = nil
            if not myPlot then myPlot = findMyPlot() end
            local roller = myPlot and myPlot:FindFirstChild("SeedRoller")
            if roller then
                prompt = roller:FindFirstChildWhichIsA("ProximityPrompt", true)
            end
            
            if prompt then
                local startCheck = tick()
                while prompt.Enabled and tick() - startCheck < 0.5 do
                    task.wait()
                end
                if not prompt.Enabled then
                    local completed = false
                    local conn
                    conn = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                        if prompt.Enabled then
                            completed = true
                            if conn then conn:Disconnect() end
                        end
                    end)
                    local start = tick()
                    while not completed and tick() - start < 3 do
                        task.wait(0.05)
                    end
                    if conn then conn:Disconnect() end
                end
            else
                task.wait(1.5)
            end
            
            task.wait(0.2)
            
            if slots then
                local currentMoney = getMyMoney()
                for slotIndex, slot in ipairs(slots) do
                    local seedName = slot.Seed
                    if seedName then
                        local plantData = PlantsConfig[seedName]
                        if plantData then
                            local rarity = plantData.Rarity
                            local cost = plantData.Cost
                            
                            local rarityClean = rarity:match("^%s*(.-)%s*$")
                            local rarityLower = rarityClean:lower()
                            
                            local knownRarity = false
                            for _, rarityInfo in ipairs(sortedRarities) do
                                if rarityInfo.Name:lower() == rarityLower then
                                    knownRarity = true
                                    break
                                end
                            end
                            
                            local shouldBuy = false
                            if knownRarity then
                                shouldBuy = SelectedRarities[rarityLower] == true
                            else
                                shouldBuy = SelectedRarities["other"] == true
                            end
                            
                            if shouldBuy and currentMoney >= cost then
                                if BuySeedEvent then
                                    pcall(function()
                                        BuySeedEvent:FireServer(slotIndex)
                                    end)
                                    currentMoney = currentMoney - cost
                                    local model = workspace:FindFirstChild(seedName)
                                    if model then
                                        model.Name = "ProcessedSeed"
                                    end
                                    task.wait(0.05)
                                else
                                    warn("[Alpha Hub] BuySeed RemoteEvent not found!")
                                end
                            end
                        end
                    end
                end
            end
            
            pcall(function()
                RollAnimationDoneEvent:FireServer(rollId)
            end)
        end)
        isProcessingRoll = false
    end
end)

MainTab:CreateToggle({
    Name = "Auto Roll",
    CurrentValue = false,
    Flag = "AlphaAutoRollToggle",
    Callback = function(Value)
        AutoRollEnabled = Value
        if AutoRollEnabled then
            task.spawn(function()
                while AutoRollEnabled and _G.AlphaScriptExecutionId == currentExecId do
                    local lastRollId = currentRollId
                    
                    pcall(function()
                        RollSeedsEvent:FireServer()
                    end)
                    
                    local elapsed = 0
                    local lastRetry = tick()
                    while (currentRollId == lastRollId or isProcessingRoll) and elapsed < 8 and AutoRollEnabled and _G.AlphaScriptExecutionId == currentExecId do
                        task.wait(0.05)
                        elapsed = elapsed + 0.05
                        
                        if not isProcessingRoll and tick() - lastRetry > 0.5 then
                            pcall(function()
                                RollSeedsEvent:FireServer()
                            end)
                            lastRetry = tick()
                        end
                    end
                    
                    task.wait(0.1)
                end
            end)
        end
    end,
})

MainTab:CreateSection("Auto Buy Rarities")

local rarityOptions = {}
table.insert(rarityOptions, "Other")
for _, rarityInfo in ipairs(sortedRarities) do
    table.insert(rarityOptions, rarityInfo.Name)
end

MainTab:CreateDropdown({
    Name = "Auto Buy Rarities",
    Options = rarityOptions,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "AlphaAutoBuyRaritiesDropdown",
    Callback = function(Option)
        SelectedRarities = {}
        if type(Option) == "table" then
            for _, opt in ipairs(Option) do
                SelectedRarities[opt:lower()] = true
            end
        elseif type(Option) == "string" then
            SelectedRarities[Option:lower()] = true
        end
        task.spawn(checkAndBuySeeds)
    end,
})

local activeToggles = {}
local registeredUpgrades = {}
local AutoUnlockGroundToggles = {}

local function findFarmPlot(floorId)
    if not myPlot then myPlot = findMyPlot() end
    if not myPlot then return nil end
    local targetName = "FarmPlot"
    if floorId ~= "Floor1" then
        targetName = "FarmPlot_" .. floorId
    end
    local fp = myPlot:FindFirstChild(targetName)
    if fp then return fp end
    fp = myPlot:FindFirstChild("FarmPlot" .. floorId)
    if fp then return fp end
    fp = myPlot:FindFirstChild("FarmPlot")
    if fp then return fp end
    for _, child in ipairs(myPlot:GetChildren()) do
        local name = child.Name:lower()
        if name:find("farmplot") and name:find(floorId:lower()) then
            return child
        end
    end
    return nil
end

task.spawn(function()
    while _G.AlphaScriptExecutionId == currentExecId do
        local anyActive = false
        for _, active in pairs(AutoUnlockGroundToggles) do
            if active then
                anyActive = true
                break
            end
        end
        if anyActive then
            if not myPlot then myPlot = findMyPlot() end
            if myPlot then
                local currentMoney = getMyMoney()
                local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                local unlockPlot = remotes and remotes:FindFirstChild("UnlockPlot")
                if unlockPlot then
                    for floorId, active in pairs(AutoUnlockGroundToggles) do
                        if active and _G.AlphaScriptExecutionId == currentExecId then
                            local farmPlot = findFarmPlot(floorId)
                            if farmPlot then
                                local children = farmPlot:GetChildren()
                                table.sort(children, function(a, b)
                                    local numA = tonumber(a.Name:match("%d+")) or 0
                                    local numB = tonumber(b.Name:match("%d+")) or 0
                                    return numA < numB
                                end)
                                for _, child in ipairs(children) do
                                    local dirt = child:FindFirstChild("Dirt")
                                    if dirt then
                                        local isLocked = child:GetAttribute("Locked")
                                        if isLocked == nil then
                                            isLocked = child:GetAttribute("IsLocked")
                                        end
                                        if isLocked == nil then
                                            isLocked = child:FindFirstChild("Lock") ~= nil or (dirt.Transparency > 0.1)
                                        end
                                        if isLocked then
                                            local cost = child:GetAttribute("Cost") or child:GetAttribute("Price") or child:GetAttribute("UnlockCost")
                                            if not cost then
                                                local floorIndex = tonumber(floorId:match("%d+")) or 1
                                                local floorData = Configuration and Configuration.FloorConfig and Configuration.FloorConfig[floorIndex]
                                                if floorData then
                                                    local bases = floorData.PlotUnlockBase
                                                    local growth = floorData.PlotUnlockGrowth or 1.4
                                                    local idx = tonumber(child.Name:match("%d+")) or 1
                                                    local stage = myPlot:GetAttribute("FarmPlotStage_" .. floorId) or myPlot:GetAttribute("FarmPlotStage") or 1
                                                    local base = bases and (bases[stage] or bases[#bases] or 25) or 25
                                                    cost = base * (growth ^ (idx - 1))
                                                else
                                                    cost = 0
                                                end
                                            end
                                            if currentMoney >= cost then
                                                pcall(function()
                                                    unlockPlot:FireServer(dirt)
                                                end)
                                                currentMoney = currentMoney - cost
                                                task.wait(0.1)
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

local function getUpgradePrice(floorId, remoteUpgradeName, uiFrameName, currentLevel)
    if myPlot then
        local sign = myPlot:FindFirstChild("PlotUpgradeSign")
        local screen = sign and sign:FindFirstChild("Screen")
        local surfaceGui = screen and screen:FindFirstChild("SurfaceGui")
        if surfaceGui then
            local frame = surfaceGui:FindFirstChild(uiFrameName)
            local btn = frame and frame:FindFirstChild("Btn")
            local txt = btn and btn:FindFirstChild("Txt")
            if txt then
                local price = parseShortenedNumber(txt.Text)
                if price > 0 then
                    return price
                end
            end
        end
    end
    
    local floorIndex = tonumber(floorId:match("%d+")) or 1
    local floorData = Configuration and Configuration.FloorConfig and Configuration.FloorConfig[floorIndex]
    if floorData then
        local base = 80
        local growth = Configuration.ExtraPowerGrowth or 1.35
        
        if remoteUpgradeName:find("Yield") then
            base = floorData.BaseExtraYieldUpgradeCost or 80
        elseif remoteUpgradeName:find("Power") then
            base = floorData.BaseExtraPowerUpgradeCost or 80
        elseif remoteUpgradeName:find("SawRange") or remoteUpgradeName:find("Range") then
            local costs = floorData.ExtraSawRangeCosts
            return costs and costs[currentLevel + 1] or 0
        elseif remoteUpgradeName:find("SprinklerRange") then
            local costs = floorData.ExtraSprinklerRangeCosts
            return costs and costs[currentLevel + 1] or 0
        end
        
        return math.floor(base * (growth ^ (currentLevel or 0)))
    end
    
    return 0
end

task.spawn(function()
    while _G.AlphaScriptExecutionId == currentExecId do
        local anyActive = false
        for _, active in pairs(activeToggles) do
            if active then
                anyActive = true
                break
            end
        end
        
        if anyActive then
            if not myPlot then myPlot = findMyPlot() end
            if myPlot then
                local currentMoney = getMyMoney()
                local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                local remote = remotes and remotes:FindFirstChild("PlotUpgradeTransaction")
                
                if remote then
                    for toggleKey, active in pairs(activeToggles) do
                        if active and _G.AlphaScriptExecutionId == currentExecId then
                            local upgradeInfo = registeredUpgrades[toggleKey]
                            if upgradeInfo then
                                local currentLevel = 0
                                local searchPattern = ""
                                if upgradeInfo.remoteUpgradeName:find("Yield") then
                                    searchPattern = "Yield"
                                elseif upgradeInfo.remoteUpgradeName:find("Power") then
                                    searchPattern = "Power"
                                elseif upgradeInfo.remoteUpgradeName:find("SawRange") or upgradeInfo.remoteUpgradeName:find("Range") then
                                    searchPattern = "SawRange"
                                elseif upgradeInfo.remoteUpgradeName:find("SprinklerRange") then
                                    searchPattern = "SprinklerRange"
                                end
                                
                                if searchPattern ~= "" then
                                    for attrName, value in pairs(myPlot:GetAttributes()) do
                                        if attrName:lower():find(searchPattern:lower()) and attrName:lower():find(upgradeInfo.floorId:lower()) then
                                            currentLevel = value
                                            break
                                        end
                                    end
                                end
                                
                                local price = getUpgradePrice(upgradeInfo.floorId, upgradeInfo.remoteUpgradeName, upgradeInfo.uiFrameName, currentLevel)
                                if price > 0 and currentMoney >= price then
                                    local success, err = pcall(function()
                                        remote:InvokeServer(upgradeInfo.remoteUpgradeName, upgradeInfo.floorId)
                                    end)
                                    if success then
                                        currentMoney = currentMoney - price
                                        task.wait(0.1)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while _G.AlphaScriptExecutionId == currentExecId do
        if AutoUpgradeSeedRolls or AutoUpgradeSeedLuck or AutoUpgradeFarm then
            if not myPlot then myPlot = findMyPlot() end
            if myPlot then
                local currentMoney = getMyMoney()
                local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                
                if AutoUpgradeSeedRolls then
                    local rollsLevel = 1
                    for attrName, value in pairs(myPlot:GetAttributes()) do
                        if attrName:lower():find("rolls") then
                            rollsLevel = value
                            break
                        end
                    end
                    local cost = Configuration and Configuration.ExtraSeedRollsCosts and Configuration.ExtraSeedRollsCosts[rollsLevel + 1] or 0
                    if cost > 0 and currentMoney >= cost then
                        local remote = remotes and remotes:FindFirstChild("UpgradeSeedRolls")
                        if remote then
                            local success = pcall(function()
                                remote:InvokeServer()
                            end)
                            if success then
                                currentMoney = currentMoney - cost
                                task.wait(0.1)
                            end
                        end
                    end
                end
                
                if AutoUpgradeSeedLuck then
                    local luckLevel = 1
                    for attrName, value in pairs(myPlot:GetAttributes()) do
                        if attrName:lower():find("luck") then
                            luckLevel = value
                            break
                        end
                    end
                    local cost = math.floor(60 * (1.35 ^ (luckLevel - 1)))
                    if currentMoney >= cost then
                        local remote = remotes and remotes:FindFirstChild("UpgradeSeedLuck")
                        if remote then
                            local success = pcall(function()
                                remote:InvokeServer()
                            end)
                            if success then
                                currentMoney = currentMoney - cost
                                task.wait(0.1)
                            end
                        end
                    end
                end
                
                if AutoUpgradeFarm then
                    local farmStage = myPlot:GetAttribute("FarmPlotStage") or 1
                    local cost = Configuration and Configuration.FarmExpandCosts and Configuration.FarmExpandCosts[farmStage + 1] or 0
                    if cost > 0 and currentMoney >= cost then
                        local remote = remotes and remotes:FindFirstChild("UpgradeFarm")
                        if remote then
                            local success = pcall(function()
                                remote:InvokeServer()
                            end)
                            if success then
                                currentMoney = currentMoney - cost
                                task.wait(0.1)
                            end
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

local function addFloorSection(floorId, displayName)
    task.spawn(function()
        while _G.AlphaScriptExecutionId == currentExecId do
            myPlot = findMyPlot()
            if myPlot then break end
            task.wait(0.5)
        end
        
        if _G.AlphaScriptExecutionId ~= currentExecId or not myPlot then return end
        
        local sign = myPlot:WaitForChild("PlotUpgradeSign", 10)
        local screen = sign and sign:WaitForChild("Screen", 10)
        local surfaceGui = screen and screen:WaitForChild("SurfaceGui", 10)
        
        if not surfaceGui then return end
        
        local FloorTab = Window:CreateTab(displayName, 4483362458)
        FloorTab:CreateSection("Auto Upgrades")
        
        FloorTab:CreateToggle({
            Name = "Auto Buy Ground",
            CurrentValue = false,
            Flag = "AlphaAutoBuyGround_" .. floorId,
            Callback = function(Value)
                AutoUnlockGroundToggles[floorId] = Value
            end,
        })
        
        task.wait(0.5)
        
        for _, child in ipairs(surfaceGui:GetChildren()) do
            if child:IsA("GuiObject") then
                local btn = child:FindFirstChild("Btn")
                local txt = btn and btn:FindFirstChild("Txt")
                
                if txt then
                    local uiFrameName = child.Name
                    local remoteUpgradeName = uiFrameName
                    if remoteUpgradeName:find("Yield") then
                        remoteUpgradeName = "ExtraYield"
                    elseif remoteUpgradeName:find("Power") then
                        remoteUpgradeName = "ExtraPower"
                    elseif not remoteUpgradeName:find("^Extra") then
                        remoteUpgradeName = "Extra" .. remoteUpgradeName
                    end
                    
                    local titleObj = child:FindFirstChild("Title")
                    local cleanDisplayName = ""
                    
                    if titleObj and titleObj:IsA("TextLabel") and titleObj.Text ~= "" then
                        cleanDisplayName = "Auto Upgrade " .. titleObj.Text
                    else
                        local baseName = remoteUpgradeName:gsub("^Extra", "")
                        baseName = baseName:gsub("(%u)", " %1"):gsub("^%s+", "")
                        cleanDisplayName = "Auto Upgrade " .. baseName
                    end
                    
                    local toggleKey = floorId .. "_" .. remoteUpgradeName
                    activeToggles[toggleKey] = false
                    
                    registeredUpgrades[toggleKey] = {
                        uiFrameName = uiFrameName,
                        remoteUpgradeName = remoteUpgradeName,
                        floorId = floorId
                    }
                    
                    FloorTab:CreateToggle({
                        Name = cleanDisplayName,
                        CurrentValue = false,
                        Flag = "Flag_" .. toggleKey,
                        Callback = function(Value)
                            activeToggles[toggleKey] = Value
                        end
                    })
                end
            end
        end
    end)
end

addFloorSection("Floor1", "Floor 1")