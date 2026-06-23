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

local Configuration = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Configuration"))
local RollSeedsEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RollSeeds")
local RollAnimationDoneEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RollAnimationDone")
local BuySeedEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("BuySeed", 5)
local RaritiesConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Registry"):WaitForChild("Rarities"))
local PlantsConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Registry"):WaitForChild("Plants"))

local AutoRollEnabled = false
local currentRollId = nil
local isProcessingRoll = false
local lastSlotsData = nil

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

local function getSlotCrop(slot)
    for _, child in ipairs(slot:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "Lock" and child.Name ~= "Dirt" then
            return child
        end
    end
    local dirt = slot:FindFirstChild("Dirt")
    if dirt then
        for _, child in ipairs(dirt:GetChildren()) do
            if child:IsA("Model") then
                return child
            end
        end
    end
    return nil
end

local function isCropGrown(crop)
    if not crop then return false end
    if crop:GetAttribute("Grown") == true or crop:GetAttribute("IsGrown") == true or crop:GetAttribute("Harvestable") == true then
        return true
    end
    local stage = crop:GetAttribute("Stage")
    local maxStage = crop:GetAttribute("MaxStage")
    if stage and maxStage and stage >= maxStage then
        return true
    end
    local progress = crop:GetAttribute("Progress")
    if progress and progress >= 100 then
        return true
    end
    local state = crop:GetAttribute("CropState") or crop:GetAttribute("State")
    if state and (tostring(state):lower():find("grown") or tostring(state):lower():find("ready") or tostring(state):lower():find("harvest")) then
        return true
    end
    return false
end

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
                    task.wait(15)
                end
            end)
        end
    end,
})

MainTab:CreateButton({
    Name = "Delete Seed Inventory",
    Callback = function()
        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        local equipTool = remotes and remotes:FindFirstChild("EquipTool")
        local discardSeed = remotes and remotes:FindFirstChild("DiscardSeed")
        if equipTool and discardSeed then
            task.spawn(function()
                local failedAttempts = 0
                while true do
                    local foundTool = nil
                    for _, tool in ipairs(player.Backpack:GetChildren()) do
                        if tool:IsA("Tool") and tool:GetAttribute("InventoryCategory") == "Seeds" then
                            foundTool = tool
                            break
                        end
                    end
                    if not foundTool then
                        for _, tool in ipairs(player.Character:GetChildren()) do
                            if tool:IsA("Tool") and tool:GetAttribute("InventoryCategory") == "Seeds" then
                                foundTool = tool
                                break
                            end
                        end
                    end
                    if not foundTool then
                        break
                    end
                    local currentCount = tonumber(foundTool.Name:match("%[[xX](%d+)%]")) or 1
                    pcall(function()
                        equipTool:FireServer(foundTool)
                    end)
                    task.wait(0.05)
                    pcall(function()
                        discardSeed:FireServer()
                    end)
                    local start = tick()
                    local updated = false
                    while tick() - start < 0.5 do
                        if not foundTool.Parent then
                            updated = true
                            break
                        end
                        local newCount = tonumber(foundTool.Name:match("%[[xX](%d+)%]")) or 1
                        if newCount < currentCount then
                            updated = true
                            break
                        end
                        task.wait(0.01)
                    end
                    if updated then
                        failedAttempts = 0
                    else
                        failedAttempts = failedAttempts + 1
                        if failedAttempts >= 3 then
                            warn("[Alpha Hub] Failed to discard tool: " .. tostring(foundTool.Name))
                            break
                        end
                    end
                end
            end)
        end
    end,
})

MainTab:CreateSection("Plant Automation")

local AutoUnlockGround = false
MainTab:CreateToggle({
    Name = "Auto Buy Ground",
    CurrentValue = false,
    Flag = "AlphaAutoBuyGround_Floor1",
    Callback = function(Value)
        AutoUnlockGround = Value
        if AutoUnlockGround then
            task.spawn(function()
                while AutoUnlockGround and _G.AlphaScriptExecutionId == currentExecId do
                    if not myPlot then myPlot = findMyPlot() end
                    if myPlot then
                        local currentMoney = getMyMoney()
                        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                        local unlockPlot = remotes and remotes:FindFirstChild("UnlockPlot")
                        if unlockPlot then
                            local farmPlot = myPlot:FindFirstChild("FarmPlot")
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
                                        local isUnlocked = child:GetAttribute("Unlocked")
                                        local isLocked
                                        if isUnlocked ~= nil then
                                            isLocked = not isUnlocked
                                        else
                                            isLocked = child:GetAttribute("Locked")
                                            if isLocked == nil then
                                                isLocked = child:GetAttribute("IsLocked")
                                            end
                                            if isLocked == nil then
                                                isLocked = child:FindFirstChild("Lock") ~= nil or (dirt.Transparency > 0.1)
                                            end
                                        end
                                        if isLocked then
                                            local plotKey = child:GetAttribute("PlotKey") or tonumber(child.Name:match("%d+")) or 1
                                            local ring = math.floor((plotKey - 1) / 10) + 1
                                            local farmPlotStage = farmPlot:GetAttribute("FarmPlotStage") or farmPlot:GetAttribute("Stage") or myPlot:GetAttribute("FarmPlotStage_Floor1") or myPlot:GetAttribute("Stage_Floor1") or farmPlot:GetAttribute("FarmPlotStage_Floor1") or 1
                                            if ring <= farmPlotStage then
                                                local cost = nil
                                                local rawCost = child:GetAttribute("Cost") or child:GetAttribute("Price") or child:GetAttribute("UnlockCost") or dirt:GetAttribute("Cost") or dirt:GetAttribute("Price") or dirt:GetAttribute("UnlockCost")
                                                if type(rawCost) == "number" then
                                                    cost = rawCost
                                                elseif type(rawCost) == "string" then
                                                    cost = parseShortenedNumber(rawCost)
                                                end
                                                if not cost or cost <= 0 then
                                                    local lock = child:FindFirstChild("Lock")
                                                    if lock then
                                                        local textLabel = lock:FindFirstChildWhichIsA("TextLabel", true)
                                                        if textLabel then
                                                            local parsed = parseShortenedNumber(textLabel.Text)
                                                            if parsed > 0 then
                                                                 cost = parsed
                                                            end
                                                        end
                                                    end
                                                end
                                                if not cost or cost <= 0 then
                                                    local floorIndex = 1
                                                    local floorData = Configuration and Configuration.FloorConfig and Configuration.FloorConfig[floorIndex]
                                                    if floorData then
                                                        local bases = floorData.PlotUnlockBase
                                                        local growth = floorData.PlotUnlockGrowth or 1.4
                                                        local idx = plotKey
                                                        local base = bases and (bases[farmPlotStage] or bases[#bases] or 25) or 25
                                                        cost = base * (growth ^ (idx - 1))
                                                    else
                                                        cost = 0
                                                    end
                                                end
                                                if cost and cost > 0 and currentMoney >= cost then
                                                    print(cost)
                                                    pcall(function()
                                                        unlockPlot:FireServer(dirt)
                                                    end)
                                                    currentMoney = getMyMoney()
                                                    task.wait(0.1)
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
        end
    end,
})

local AutoPlantBest = false
MainTab:CreateToggle({
    Name = "Auto Plant Best",
    CurrentValue = false,
    Flag = "AlphaAutoPlantBest_Floor1",
    Callback = function(Value)
        AutoPlantBest = Value
        if AutoPlantBest then
            task.spawn(function()
                while AutoPlantBest and _G.AlphaScriptExecutionId == currentExecId do
                    if not myPlot then myPlot = findMyPlot() end
                    if myPlot then
                        local farmPlot = myPlot:FindFirstChild("FarmPlot")
                        if farmPlot then
                            local children = farmPlot:GetChildren()
                            local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                            local plantSeed = remotes and remotes:FindFirstChild("PlantSeed")
                            local removePlant = remotes and remotes:FindFirstChild("RemovePlant")
                            local equipTool = remotes and remotes:FindFirstChild("EquipTool")
                            if plantSeed and removePlant then
                                local lastTargetDirt = nil
                                local targetAttempts = 0
                                while AutoPlantBest and _G.AlphaScriptExecutionId == currentExecId do
                                    local bestTool = nil
                                    local bestCost = -1
                                    local toolsToSearch = {}
                                    for _, t in ipairs(player.Backpack:GetChildren()) do
                                        table.insert(toolsToSearch, t)
                                    end
                                    for _, t in ipairs(player.Character:GetChildren()) do
                                        table.insert(toolsToSearch, t)
                                    end
                                    for _, tool in ipairs(toolsToSearch) do
                                        if tool:IsA("Tool") and tool:GetAttribute("InventoryCategory") == "Seeds" then
                                            local plantName = tool:GetAttribute("Plant")
                                            local plantData = PlantsConfig[plantName]
                                            local cost = plantData and plantData.Cost or 0
                                            if cost > bestCost then
                                                bestCost = cost
                                                bestTool = tool
                                            end
                                        end
                                    end
                                    if not bestTool then
                                        break
                                    end
                                    local slots = {}
                                    for _, slot in ipairs(children) do
                                        local dirt = slot:FindFirstChild("Dirt")
                                        local isUnlocked = slot:GetAttribute("Unlocked") == true
                                        if dirt and isUnlocked then
                                            local crop = getSlotCrop(slot)
                                            local cropName = crop and (crop:GetAttribute("Plant") or crop.Name) or nil
                                            local plantData = cropName and PlantsConfig[cropName]
                                            local cropCost = plantData and plantData.Cost or 0
                                            local isGrown = crop and isCropGrown(crop) or false
                                            table.insert(slots, {
                                                dirt = dirt,
                                                crop = crop,
                                                cropCost = cropCost,
                                                isGrown = isGrown
                                            })
                                        end
                                    end
                                    table.sort(slots, function(a, b)
                                        local prioA = (not a.crop or a.isGrown) and 1 or 2
                                        local prioB = (not b.crop or b.isGrown) and 1 or 2
                                        if prioA ~= prioB then
                                            return prioA < prioB
                                        end
                                        return a.cropCost < b.cropCost
                                    end)
                                    local target = slots[1]
                                    if not target then
                                        break
                                    end
                                    if target.dirt == lastTargetDirt then
                                        targetAttempts = targetAttempts + 1
                                        if targetAttempts > 5 then
                                            task.wait(0.1)
                                            if targetAttempts > 10 then
                                                break
                                            end
                                        end
                                    else
                                        lastTargetDirt = target.dirt
                                        targetAttempts = 1
                                    end
                                    if not target.crop or target.isGrown then
                                        if target.isGrown then
                                            pcall(function()
                                                removePlant:FireServer(target.dirt)
                                            end)
                                            task.wait(0.02)
                                        end
                                        if bestTool.Parent ~= player.Character and equipTool then
                                            pcall(function()
                                                equipTool:FireServer(bestTool)
                                            end)
                                            task.wait(0.02)
                                        end
                                        pcall(function()
                                            plantSeed:FireServer(target.dirt)
                                        end)
                                        task.wait(0.02)
                                    else
                                        if bestCost > target.cropCost then
                                            pcall(function()
                                                removePlant:FireServer(target.dirt)
                                            end)
                                            task.wait(0.02)
                                            if bestTool.Parent ~= player.Character and equipTool then
                                                pcall(function()
                                                    equipTool:FireServer(bestTool)
                                                end)
                                                task.wait(0.02)
                                            end
                                            pcall(function()
                                                plantSeed:FireServer(target.dirt)
                                            end)
                                            task.wait(0.02)
                                        else
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.2)
                end
            end)
        end
    end,
})

MainTab:CreateSection("Auto Upgrades")

local AutoUpgradeSeedRolls = false
MainTab:CreateToggle({
    Name = "Auto Upgrade Seed Rolls",
    CurrentValue = false,
    Flag = "AlphaMainAutoUpgradeSeedRolls",
    Callback = function(Value)
        AutoUpgradeSeedRolls = Value
        if AutoUpgradeSeedRolls then
            task.spawn(function()
                while AutoUpgradeSeedRolls and _G.AlphaScriptExecutionId == currentExecId do
                    if not myPlot then myPlot = findMyPlot() end
                    if myPlot then
                        local currentMoney = getMyMoney()
                        local level = myPlot:GetAttribute("SeedStands") or 1
                        local price = Configuration and Configuration.ExtraSeedRollsCosts and Configuration.ExtraSeedRollsCosts[level + 1] or 0
                        if price > 0 and currentMoney >= price then
                            local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                            local remote = remotes and remotes:FindFirstChild("UpgradeSeedRolls")
                            if remote then
                                local success, err = pcall(function()
                                    return remote:InvokeServer()
                                end)
                                if not success then
                                    warn("[Alpha Hub] Failed to upgrade Seed Rolls: " .. tostring(err))
                                end
                            end
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end,
})

local AutoUpgradeSeedLuck = false
MainTab:CreateToggle({
    Name = "Auto Upgrade Seed Luck",
    CurrentValue = false,
    Flag = "AlphaMainAutoUpgradeSeedLuck",
    Callback = function(Value)
        AutoUpgradeSeedLuck = Value
        if AutoUpgradeSeedLuck then
            task.spawn(function()
                while AutoUpgradeSeedLuck and _G.AlphaScriptExecutionId == currentExecId do
                    if not myPlot then myPlot = findMyPlot() end
                    if myPlot then
                        local currentMoney = getMyMoney()
                        local level = 1
                        local price = 0
                        local sign = myPlot:FindFirstChild("UpgradeSign")
                        local screen = sign and sign:FindFirstChild("Screen")
                        local surfaceGui = screen and screen:FindFirstChild("SurfaceGui")
                        if surfaceGui then
                            local seedLuck = surfaceGui:FindFirstChild("SeedLuck", true)
                            if seedLuck then
                                local desc = seedLuck:FindFirstChild("Desc", true)
                                if desc then
                                    level = tonumber(desc.Text:match("(%d+)")) or 1
                                end
                                local btn = seedLuck:FindFirstChild("Btn", true)
                                local txt = btn and btn:FindFirstChild("Txt", true)
                                if txt then
                                    price = parseShortenedNumber(txt.Text)
                                end
                            end
                        end
                        if price <= 0 then
                            local base = Configuration and Configuration.BaseSeedLuckUpgradeCost or 60
                            local growth = Configuration and Configuration.ExtraPowerGrowth or 1.35
                            price = math.floor(base * (growth ^ (level - 1)))
                        end
                        if price > 0 and currentMoney >= price then
                            local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                            local remote = remotes and remotes:FindFirstChild("UpgradeSeedLuck")
                            if remote then
                                local success, err = pcall(function()
                                    return remote:InvokeServer()
                                end)
                                if not success then
                                    warn("[Alpha Hub] Failed to upgrade Seed Luck: " .. tostring(err))
                                end
                            end
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end,
})

local AutoUpgradeFarm = false
MainTab:CreateToggle({
    Name = "Auto Upgrade Farm",
    CurrentValue = false,
    Flag = "AlphaMainAutoUpgradeFarm",
    Callback = function(Value)
        AutoUpgradeFarm = Value
        if AutoUpgradeFarm then
            task.spawn(function()
                while AutoUpgradeFarm and _G.AlphaScriptExecutionId == currentExecId do
                    if not myPlot then myPlot = findMyPlot() end
                    if myPlot then
                        local currentMoney = getMyMoney()
                        local farmPlot = myPlot:FindFirstChild("FarmPlot")
                        local level = farmPlot and (farmPlot:GetAttribute("FarmPlotStage") or farmPlot:GetAttribute("Stage")) or 1
                        local price = Configuration and Configuration.FarmExpandCosts and Configuration.FarmExpandCosts[level + 1] or 0
                        if price > 0 and currentMoney >= price then
                            local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                            local remote = remotes and remotes:FindFirstChild("UpgradeFarm")
                            if remote then
                                local success, err = pcall(function()
                                    return remote:InvokeServer()
                                end)
                                if not success then
                                    warn("[Alpha Hub] Failed to upgrade Farm: " .. tostring(err))
                                end
                            end
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end,
})

MainTab:CreateSection("Auto Roll")

local function checkAndBuySeeds()
    if not lastSlotsData then return end
    if not myPlot then myPlot = findMyPlot() end
    local roller = myPlot and myPlot:FindFirstChild("SeedRoller")
    if not roller then return end
    
    local currentMoney = getMyMoney()
    for slotIndexKey, slot in pairs(lastSlotsData) do
        local slotIndex = tonumber(slotIndexKey) or slotIndexKey
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
                for slotIndexKey, slot in pairs(slots) do
                    local slotIndex = tonumber(slotIndexKey) or slotIndexKey
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
    
    local FloorTab = Window:CreateTab("Floor 1", 4483362458)
    FloorTab:CreateSection("Auto Upgrades")
    
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
                
                local toggleKey = "Floor1_" .. remoteUpgradeName
                local autoUpgradeActive = false
                FloorTab:CreateToggle({
                    Name = cleanDisplayName,
                    CurrentValue = false,
                    Flag = "Flag_" .. toggleKey,
                    Callback = function(Value)
                        autoUpgradeActive = Value
                        if autoUpgradeActive then
                            task.spawn(function()
                                while autoUpgradeActive and _G.AlphaScriptExecutionId == currentExecId do
                                    if not myPlot then myPlot = findMyPlot() end
                                    if myPlot then
                                        local currentMoney = getMyMoney()
                                        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                                        local remote = remotes and remotes:FindFirstChild("PlotUpgradeTransaction")
                                        if remote then
                                            local currentLevel = 0
                                            local searchPattern = ""
                                            if remoteUpgradeName:find("Yield") then
                                                searchPattern = "Yield"
                                            elseif remoteUpgradeName:find("Power") then
                                                searchPattern = "Power"
                                            elseif remoteUpgradeName:find("SawRange") or remoteUpgradeName:find("Range") then
                                                searchPattern = "SawRange"
                                            elseif remoteUpgradeName:find("SprinklerRange") then
                                                searchPattern = "SprinklerRange"
                                            end
                                            if searchPattern ~= "" then
                                                for attrName, val in pairs(myPlot:GetAttributes()) do
                                                    if attrName:lower():find(searchPattern:lower()) and attrName:lower():find("floor1") then
                                                        currentLevel = val
                                                        break
                                                    end
                                                end
                                            end
                                            local price = getUpgradePrice("Floor1", remoteUpgradeName, uiFrameName, currentLevel)
                                            if price > 0 and currentMoney >= price then
                                                local success, err = pcall(function()
                                                    remote:InvokeServer(remoteUpgradeName, "Floor1")
                                                end)
                                                if success then
                                                    currentMoney = currentMoney - price
                                                    task.wait(0.1)
                                                end
                                            end
                                        end
                                    end
                                    task.wait(0.5)
                                end
                            end)
                        end
                    end,
                })
            end
        end
    end
end)