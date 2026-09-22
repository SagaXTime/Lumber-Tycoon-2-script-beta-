-- Lumber Tycoon 2 Automation Script
-- Delta Executor Compatible
-- Version 3.0.0 - Full Critical Fix

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================
-- CONFIGURATION
-- ============================================

local CONFIG = {
    AutoChop = {
        Enabled = false,
        AttackSpeed = 0.05,
        MaxDistance = 200,
        CacheRefresh = 3,
        EquipCooldown = 1,
    },
    Teleport = {
        Locations = {
            {Name = "Spawn", CFrame = CFrame.new(93, 108, -1)},
            {Name = "Wood R Us", CFrame = CFrame.new(200, 108, -50)},
            {Name = "Safari Bridge", CFrame = CFrame.new(-200, 15, -800)},
            {Name = "Volcano", CFrame = CFrame.new(-1000, 200, -500)},
            {Name = "Taiga", CFrame = CFrame.new(500, 300, 1500)},
            {Name = "Swamp", CFrame = CFrame.new(-800, 50, 1200)},
            {Name = "Maze Entrance", CFrame = CFrame.new(1500, 100, -1500)},
            {Name = "End Times", CFrame = CFrame.new(2000, 200, -2000)},
        },
    },
    Visual = {
        Brightness = 3,
        Ambient = Color3.fromRGB(180, 180, 180),
        OutdoorAmbient = Color3.fromRGB(160, 160, 160),
    },
}

local ORDER = {
    SECTION_CHOP = 1,
    CHOP_TOGGLE = 2,
    SECTION_TP = 10,
    TP_PLOT = 11,
    TP_LOC_START = 12,
    SECTION_VIS = 100,
    VIS_BRIGHT = 101,
    VIS_FOG = 102,
    VIS_PERF = 103,
}

-- ============================================
-- STATE
-- ============================================

local ORIGINAL = {
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    ShadowSoftness = Lighting.ShadowSoftness,
    WaterWaveSize = nil,
    WaterWaveSpeed = nil,
    WaterTransparency = nil,
}

pcall(function()
    ORIGINAL.WaterWaveSize = Workspace.Terrain.WaterWaveSize
    ORIGINAL.WaterWaveSpeed = Workspace.Terrain.WaterWaveSpeed
    ORIGINAL.WaterTransparency = Workspace.Terrain.WaterTransparency
end)

local CONNECTIONS = {}
local chopConnection = nil
local charConnection = nil

local function trackConnection(conn)
    table.insert(CONNECTIONS, conn)
    return conn
end

local function cleanupConnections()
    for _, conn in ipairs(CONNECTIONS) do
        pcall(function() conn:Disconnect() end)
    end
    CONNECTIONS = {}
    if chopConnection then
        pcall(function() chopConnection:Disconnect() end)
        chopConnection = nil
    end
end

-- ============================================
-- UTILITY
-- ============================================

local function getCharacter()
    local char = player.Character
    if not char or not char.Parent then return nil end
    return char
end

local function getRoot()
    local char = getCharacter()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

-- Robust plot detection: scan Workspace for folders containing player-owned plots
local function getPlayerPlot()
    local char = getCharacter()
    if not char then return nil end
    
    -- Strategy 1: Check known folder names
    local candidateFolders = {"PlayerPlots", "Plots", "Land", "PlotsFolder", "Bases"}
    for _, folderName in ipairs(candidateFolders) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, plot in ipairs(folder:GetChildren()) do
                local owner = plot:FindFirstChild("Owner") 
                    or plot:FindFirstChild("OwnerName")
                    or plot:FindFirstChild("Player")
                if owner then
                    local val = owner.Value
                    if val == player or val == player.Name 
                       or tostring(val) == player.Name then
                        return plot
                    end
                end
                -- Fallback: check name match
                if plot.Name:lower():find(player.Name:lower(), 1, true) then
                    return plot
                end
            end
        end
    end
    
    -- Strategy 2: Scan direct children of Workspace
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Folder") or obj:IsA("Model") then
            local owner = obj:FindFirstChild("Owner")
            if owner then
                local val = owner.Value
                if val == player or val == player.Name 
                   or tostring(val) == player.Name then
                    return obj
                end
            end
        end
    end
    
    return nil
end

-- Vehicle detection: any Model with PrimaryPart that player is sitting in
local function getCurrentVehicle()
    local char = getCharacter()
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or not humanoid.SeatPart then return nil end
    
    -- Walk up from seat to find vehicle model
    local seat = humanoid.SeatPart
    local ancestor = seat
    while ancestor and ancestor ~= Workspace do
        if ancestor:IsA("Model") and ancestor.PrimaryPart then
            return ancestor
        end
        ancestor = ancestor.Parent
    end
    return nil
end

-- Axe detection: whitelist specific names + fallback on tooltip
local function isAxe(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local n = tool.Name:lower()
    
    -- Reject known non-axe tools
    if n:match("pickaxe") or n:match("saw") or n:match("drill") then
        return false
    end
    
    -- Whitelist exact axe names
    local axeNames = {
        "axe", "hatchet", "chopper", "basic axe", "steel axe",
        "beta axe", "alpha axe", "gold axe", "candy axe",
        "hardened axe", "many axe", "ender axe", "chicken axe",
        "amber axe", "frost axe", "birch axe", "fire axe",
        "rukiryaxe", "silver axe", "golden axe", "cursed axe",
    }
    for _, name in ipairs(axeNames) do
        if n == name or n:find(name, 1, true) then
            return true
        end
    end
    
    -- Fallback: check tooltip
    if tool:FindFirstChild("ToolTip") or tool:FindFirstChild("Tooltip") then
        local tip = tool:FindFirstChild("ToolTip") or tool:FindFirstChild("Tooltip")
        if tip.Value and tostring(tip.Value):lower():find("axe") then
            return true
        end
    end
    
    -- Fallback: attribute check
    local ok, attr = pcall(function() return tool:GetAttribute("IsAxe") end)
    if ok and attr then return true end
    
    return false
end

-- ============================================
-- UI CREATION
-- ============================================

local screenGuiRef = nil

local function createUI()
    local existing = playerGui:FindFirstChild("LT2Automation")
    if existing then existing:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LT2Automation"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    screenGuiRef = screenGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 320, 0, 480)
    mainFrame.Position = UDim2.new(0, 20, 0, 100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -80, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "LT2 Automation Hub v3"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    minimizeBtn.Position = UDim2.new(1, -70, 0, 5)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    minimizeBtn.Text = "—"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.TextSize = 16
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.Parent = titleBar
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minimizeBtn
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, -20, 1, -50)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.Parent = contentFrame
    
    local scrollLayout = Instance.new("UIListLayout")
    scrollLayout.Padding = UDim.new(0, 8)
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.Parent = scrollFrame
    
    local function createSection(text, order)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 28)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(100, 180, 255)
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.LayoutOrder = order
        label.Parent = scrollFrame
        return label
    end
    
    local function createToggle(text, initial, callback, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = initial and Color3.fromRGB(50, 150, 80) or Color3.fromRGB(50, 50, 60)
        btn.Text = text .. (initial and " [ON]" or " [OFF]")
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 13
        btn.Font = Enum.Font.Gotham
        btn.LayoutOrder = order
        btn.Parent = scrollFrame
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
        
        local state = initial
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.BackgroundColor3 = state and Color3.fromRGB(50, 150, 80) or Color3.fromRGB(50, 50, 60)
            btn.Text = text .. (state and " [ON]" or " [OFF]")
            if callback then
                task.spawn(function()
                    local ok, err = pcall(callback, state)
                    if not ok then warn("[LT2] Toggle error:", err) end
                end)
            end
        end)
        return btn
    end
    
    local function createButton(text, callback, order)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 13
        btn.Font = Enum.Font.Gotham
        btn.LayoutOrder = order
        btn.Parent = scrollFrame
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(30, 100, 200)
            task.wait(0.1)
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
            if callback then
                task.spawn(function()
                    local ok, err = pcall(callback)
                    if not ok then warn("[LT2] Button error:", err) end
                end)
            end
        end)
        return btn
    end
    
    -- AUTO CHOP
    createSection("⚡ AUTO CHOP", ORDER.SECTION_CHOP)
    createToggle("Auto Chop Trees", false, function(state)
        CONFIG.AutoChop.Enabled = state
    end, ORDER.CHOP_TOGGLE)
    
    -- TELEPORT
    createSection("📍 TELEPORT", ORDER.SECTION_TP)
    
    createButton("🏠 Teleport to My Plot", function()
        local root = getRoot()
        if not root then return end
        
        local plot = getPlayerPlot()
        if not plot then return end
        
        local targetCF = nil
        local ok, pivot = pcall(function() return plot:GetPivot() end)
        if ok and pivot then
            targetCF = pivot
        elseif plot.PrimaryPart then
            targetCF = plot.PrimaryPart.CFrame
        end
        
        if targetCF then
            root.CFrame = targetCF * CFrame.new(0, 5, 0)
        end
    end, ORDER.TP_PLOT)
    
    local locOrder = ORDER.TP_LOC_START
    for _, loc in ipairs(CONFIG.Teleport.Locations) do
        createButton("🌲 " .. loc.Name, function()
            local root = getRoot()
            if not root then return end
            
            local vehicle = getCurrentVehicle()
            if vehicle and vehicle.PrimaryPart then
                -- Teleport vehicle only; root follows automatically via weld
                local ok = pcall(function() vehicle:PivotTo(loc.CFrame) end)
                if not ok then
                    root.CFrame = loc.CFrame * CFrame.new(0, 5, 0)
                end
            else
                root.CFrame = loc.CFrame * CFrame.new(0, 5, 0)
            end
        end, locOrder)
        locOrder = locOrder + 1
    end
    
    -- VISUAL
    createSection("🎨 VISUAL", ORDER.SECTION_VIS)
    
    createToggle("Bright World", false, function(state)
        if state then
            Lighting.Brightness = CONFIG.Visual.Brightness
            Lighting.Ambient = CONFIG.Visual.Ambient
            Lighting.OutdoorAmbient = CONFIG.Visual.OutdoorAmbient
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = ORIGINAL.Brightness
            Lighting.Ambient = ORIGINAL.Ambient
            Lighting.OutdoorAmbient = ORIGINAL.OutdoorAmbient
            Lighting.GlobalShadows = ORIGINAL.GlobalShadows
        end
    end, ORDER.VIS_BRIGHT)
    
    createToggle("Remove Fog", false, function(state)
        if state then
            Lighting.FogEnd = 100000
            Lighting.FogStart = 100000
        else
            Lighting.FogEnd = ORIGINAL.FogEnd
            Lighting.FogStart = ORIGINAL.FogStart
        end
    end, ORDER.VIS_FOG)
    
    createToggle("Performance Mode", false, function(state)
        if state then
            pcall(function()
                Workspace.Terrain.WaterWaveSize = 0
                Workspace.Terrain.WaterWaveSpeed = 0
                Workspace.Terrain.WaterTransparency = 1
            end)
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                    pcall(function() obj.Enabled = false end)
                end
            end
            Lighting.GlobalShadows = false
            Lighting.ShadowSoftness = 0
        else
            if ORIGINAL.WaterWaveSize ~= nil then
                pcall(function()
                    Workspace.Terrain.WaterWaveSize = ORIGINAL.WaterWaveSize
                    Workspace.Terrain.WaterWaveSpeed = ORIGINAL.WaterWaveSpeed
                    Workspace.Terrain.WaterTransparency = ORIGINAL.WaterTransparency
                end)
            end
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                    pcall(function() obj.Enabled = true end)
                end
            end
            Lighting.GlobalShadows = ORIGINAL.GlobalShadows
            Lighting.ShadowSoftness = ORIGINAL.ShadowSoftness
        end
    end, ORDER.VIS_PERF)
    
    minimizeBtn.MouseButton1Click:Connect(function()
        contentFrame.Visible = not contentFrame.Visible
        mainFrame.Size = contentFrame.Visible and UDim2.new(0, 320, 0, 480) or UDim2.new(0, 320, 0, 40)
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        CONFIG.AutoChop.Enabled = false
        cleanupConnections()
        if screenGuiRef then
            pcall(function() screenGuiRef:Destroy() end)
            screenGuiRef = nil
        end
    end)
    
    return screenGui
end

-- ============================================
-- TREE CACHE (Optimized - folder-first, CollectionService-aware)
-- ============================================

local treeCache = {}
local lastScan = 0

local function refreshTreeCache()
    local newCache = {}
    local seen = {}
    
    -- Strategy 1: CollectionService tags
    local ok, tagged = pcall(function()
        return CollectionService:GetTagged("Tree")
    end)
    if ok and tagged and #tagged > 0 then
        for _, obj in ipairs(tagged) do
            if obj:IsA("Model") and obj.PrimaryPart and obj.Parent then
                if not seen[obj] then
                    seen[obj] = true
                    table.insert(newCache, obj)
                end
            end
        end
        if #newCache > 0 then
            treeCache = newCache
            lastScan = tick()
            return
        end
    end
    
    -- Strategy 2: Scan known tree folders
    local treeFolders = {"Trees", "TreeFolder", "Wood", "Forest"}
    for _, folderName in ipairs(treeFolders) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("Model") and obj.PrimaryPart and obj.Parent and not seen[obj] then
                    seen[obj] = true
                    table.insert(newCache, obj)
                end
            end
        end
    end
    
    -- Strategy 3: Fallback - scan top-level Workspace children only (cheap)
    if #newCache == 0 then
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and obj.PrimaryPart and not seen[obj] then
                local n = obj.Name:lower()
                if n:match("tree") and not n:match("wood r us") 
                   and not n:match("treehouse") then
                    seen[obj] = true
                    table.insert(newCache, obj)
                end
            end
        end
    end
    
    treeCache = newCache
    lastScan = tick()
end

-- ============================================
-- AUTO CHOP (Heartbeat-safe, no yield)
-- ============================================

local lastSwing = 0
local lastEquip = 0
local pendingEquip = false

local function tryEquipAxe()
    if pendingEquip then return end
    pendingEquip = true
    
    task.spawn(function()
        local char = getCharacter()
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local backpack = player:FindFirstChild("Backpack")
        
        if humanoid and backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if isAxe(item) then
                    local ok = pcall(function() humanoid:EquipTool(item) end)
                    if ok then break end
                end
            end
        end
        
        task.wait(CONFIG.AutoChop.EquipCooldown)
        pendingEquip = false
    end)
end

local function startAutoChop()
    if chopConnection then
        pcall(function() chopConnection:Disconnect() end)
        chopConnection = nil
    end
    
    chopConnection = RunService.Heartbeat:Connect(function()
        if not CONFIG.AutoChop.Enabled then return end
        
        local now = tick()
        if now - lastSwing < CONFIG.AutoChop.AttackSpeed then return end
        
        local char = getCharacter()
        if not char then return end
        
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid then return end
        
        -- Don't chop while sitting in vehicle (would break weld)
        if humanoid.Sit then return end
        
        local tool = char:FindFirstChildOfClass("Tool")
        
        if not tool then
            if now - lastEquip > CONFIG.AutoChop.EquipCooldown then
                lastEquip = now
                tryEquipAxe()
            end
            return
        end
        
        if not isAxe(tool) then return end
        if not tool.Enabled then return end
        
        -- Refresh cache
        if now - lastScan > CONFIG.AutoChop.CacheRefresh then
            task.spawn(refreshTreeCache)
        end
        
        -- Find nearest from cache
        local nearest, shortest = nil, CONFIG.AutoChop.MaxDistance
        for _, tree in ipairs(treeCache) do
            if tree.Parent and tree.PrimaryPart then
                local d = (tree.PrimaryPart.Position - root.Position).Magnitude
                if d < shortest then
                    shortest = d
                    nearest = tree
                end
            end
        end
        
        if nearest and nearest.PrimaryPart then
            pcall(function()
                root.CFrame = CFrame.new(root.Position, nearest.PrimaryPart.Position)
            end)
            pcall(function() tool:Activate() end)
            lastSwing = now
        end
    end)
end

-- ============================================
-- INITIALIZATION
-- ============================================

-- Cleanup previous session if re-executed
cleanupConnections()
if screenGuiRef then
    pcall(function() screenGuiRef:Destroy() end)
    screenGuiRef = nil
end

local ui = createUI()
startAutoChop()

charConnection = trackConnection(player.CharacterAdded:Connect(function()
    task.wait(1)
    task.spawn(refreshTreeCache)
end))

task.spawn(function()
    task.wait(2)
    refreshTreeCache()
end)
