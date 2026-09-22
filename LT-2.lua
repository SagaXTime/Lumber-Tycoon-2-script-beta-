-- Lumber Tycoon 2 Automation Script
-- Delta Executor Compatible
-- "Lumber Key less" | by Saga
-- Version 5.1.0

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================
-- KEY SYSTEM CONFIG
-- ============================================

local KEY_CONFIG = {
    WordPool = {
        "saga", "ganteng", "sigma", "pro", "legend", "alpha", "omega",
        "dark", "fire", "frost", "storm", "shadow", "light", "nova",
        "quantum", "onyx", "vortex", "phoenix", "titan", "king",
        "epic", "prime", "ultra", "hyper", "mega", "cyber",
        "neon", "void", "abyss", "chaos", "zenith", "apex",
        "blaze", "glacier", "thunder", "spectre", "phantom", "wraith",
        "crimson", "azure", "emerald", "obsidian", "celestial", "astral",
        "royal", "mythic", "divine", "eternal", "infinity", "supreme",
    },
    Prefix = "saga ganteng ",
    ActiveKeys = {},
    HardcodedPremium = {
        ["saga ganteng xso001"] = true,
        ["saga ganteng xso002"] = true,
        ["saga ganteng xso003"] = true,
    },
}

-- ============================================
-- SESSION STATE
-- ============================================

local SESSION = {
    Key = nil,
    Tier = "free",
    Verified = false,
    HWID = nil,
}

pcall(function()
    local ok, hwid = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and hwid then
        SESSION.HWID = hwid:sub(1, 16)
    else
        SESSION.HWID = tostring(math.random(100000, 999999))
    end
end)

if not SESSION.HWID then
    SESSION.HWID = tostring(math.random(100000, 999999))
end

-- ============================================
-- KEY GENERATOR
-- ============================================

local function generateRandomKey()
    local pool = KEY_CONFIG.WordPool
    local word1 = pool[math.random(1, #pool)]
    local word2 = pool[math.random(1, #pool)]
    
    while word2 == word1 do
        word2 = pool[math.random(1, #pool)]
    end
    
    local digits = ""
    local chars = "0123456789abcdefghijklmnopqrstuvwxyz"
    for i = 1, 4 do
        local idx = math.random(1, #chars)
        digits = digits .. chars:sub(idx, idx)
    end
    
    return "saga ganteng " .. word1 .. word2 .. digits
end

local function generate50Keys()
    local keys = {}
    local seen = {}
    local attempts = 0
    while #keys < 50 and attempts < 500 do
        local key = generateRandomKey()
        if not seen[key] and not KEY_CONFIG.ActiveKeys[key] then
            seen[key] = true
            table.insert(keys, key)
        end
        attempts = attempts + 1
    end
    return keys
end

local GENERATED_KEYS = generate50Keys()

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
            {Name = "Spawn", CFrame = CFrame.new(93, 108, -1), Premium = false},
            {Name = "Wood R Us", CFrame = CFrame.new(200, 108, -50), Premium = false},
            {Name = "Safari Bridge", CFrame = CFrame.new(-200, 15, -800), Premium = true},
            {Name = "Volcano", CFrame = CFrame.new(-1000, 200, -500), Premium = true},
            {Name = "Taiga", CFrame = CFrame.new(500, 300, 1500), Premium = true},
            {Name = "Swamp", CFrame = CFrame.new(-800, 50, 1200), Premium = true},
            {Name = "Maze Entrance", CFrame = CFrame.new(1500, 100, -1500), Premium = true},
            {Name = "End Times", CFrame = CFrame.new(2000, 200, -2000), Premium = true},
        },
    },
    Visual = {
        Brightness = 3,
        Ambient = Color3.fromRGB(180, 180, 180),
        OutdoorAmbient = Color3.fromRGB(160, 160, 160),
    },
    Premium = {
        FastAttackSpeed = 0.02,
    },
    Free = {
        AutoChopSpeed = 0.15,
    },
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
-- KEY VALIDATION
-- ============================================

local function isPremium()
    return SESSION.Verified and SESSION.Tier == "premium"
end

local function setKey(key)
    key = tostring(key or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if key == "" then
        return false, "Key kosong"
    end
    
    if KEY_CONFIG.HardcodedPremium[key] then
        SESSION.Key = key
        SESSION.Tier = "premium"
        SESSION.Verified = true
        KEY_CONFIG.ActiveKeys[key] = { tier = "premium", used = true }
        return true, "Premium aktif"
    end
    
    if KEY_CONFIG.ActiveKeys[key] then
        SESSION.Key = key
        SESSION.Tier = KEY_CONFIG.ActiveKeys[key].tier or "premium"
        SESSION.Verified = true
        KEY_CONFIG.ActiveKeys[key].used = true
        return true, "Premium aktif"
    end
    
    if key:sub(1, 13) == "saga ganteng " then
        SESSION.Key = key
        SESSION.Tier = "premium"
        SESSION.Verified = true
        KEY_CONFIG.ActiveKeys[key] = { tier = "premium", used = true }
        return true, "Premium aktif"
    end
    
    return false, "Key tidak valid"
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

local function getPlayerPlot()
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
                if plot.Name:lower():find(player.Name:lower(), 1, true) then
                    return plot
                end
            end
        end
    end
    
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

local function getCurrentVehicle()
    local char = getCharacter()
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or not humanoid.SeatPart then return nil end
    
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

local function isAxe(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local n = tool.Name:lower()
    
    if n:match("pickaxe") or n:match("saw") or n:match("drill") then
        return false
    end
    
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
    
    if tool:FindFirstChild("ToolTip") or tool:FindFirstChild("Tooltip") then
        local tip = tool:FindFirstChild("ToolTip") or tool:FindFirstChild("Tooltip")
        if tip.Value and tostring(tip.Value):lower():find("axe") then
            return true
        end
    end
    
    local ok, attr = pcall(function() return tool:GetAttribute("IsAxe") end)
    if ok and attr then return true end
    
    return false
end

-- ============================================
-- NOTIFICATION
-- ============================================

local function notify(title, text, duration)
    duration = duration or 3
    local gui = playerGui:FindFirstChild("LT2Notify")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "LT2Notify"
        gui.ResetOnSpawn = false
        gui.Parent = playerGui
    end
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 70)
    frame.Position = UDim2.new(1, 20, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.BackgroundColor3 = Color3.fromRGB(140, 100, 255)
    accent.BorderSizePixel = 0
    accent.Parent = frame
    
    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(0, 8)
    accentCorner.Parent = accent
    
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 25)
    titleLbl.Position = UDim2.new(0, 15, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = Color3.fromRGB(140, 100, 255)
    titleLbl.TextSize = 14
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = frame
    
    local textLbl = Instance.new("TextLabel")
    textLbl.Size = UDim2.new(1, -20, 0, 30)
    textLbl.Position = UDim2.new(0, 15, 0, 33)
    textLbl.BackgroundTransparency = 1
    textLbl.Text = text
    textLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    textLbl.TextSize = 12
    textLbl.Font = Enum.Font.Gotham
    textLbl.TextXAlignment = Enum.TextXAlignment.Left
    textLbl.TextWrapped = true
    textLbl.Parent = frame
    
    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Position = UDim2.new(1, -320, 0, 20)
    }):Play()
    
    task.delay(duration, function()
        TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Position = UDim2.new(1, 20, 0, 20)
        }):Play()
        task.wait(0.35)
        frame:Destroy()
    end)
end

-- ============================================
-- GEAR ICON
-- ============================================

local function createGearIcon(screenGui, onClick)
    local iconBtn = Instance.new("TextButton")
    iconBtn.Name = "GearIcon"
    iconBtn.Size = UDim2.new(0, 50, 0, 50)
    iconBtn.Position = UDim2.new(0, 20, 0, 20)
    iconBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    iconBtn.BorderSizePixel = 0
    iconBtn.Text = ""
    iconBtn.AutoButtonColor = false
    iconBtn.Parent = screenGui
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(1, 0)
    iconCorner.Parent = iconBtn
    
    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = Color3.fromRGB(140, 100, 255)
    iconStroke.Thickness = 2
    iconStroke.Transparency = 0.2
    iconStroke.Parent = iconBtn
    
    local gearLbl = Instance.new("TextLabel")
    gearLbl.Size = UDim2.new(1, 0, 1, 0)
    gearLbl.BackgroundTransparency = 1
    gearLbl.Text = "⚙"
    gearLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    gearLbl.TextSize = 28
    gearLbl.Font = Enum.Font.GothamBold
    gearLbl.Parent = iconBtn
    
    iconBtn.MouseEnter:Connect(function()
        TweenService:Create(iconBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(35, 25, 55)
        }):Play()
        TweenService:Create(gearLbl, TweenInfo.new(0.2), {
            TextColor3 = Color3.fromRGB(140, 100, 255)
        }):Play()
    end)
    
    iconBtn.MouseLeave:Connect(function()
        TweenService:Create(iconBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(15, 15, 22)
        }):Play()
        TweenService:Create(gearLbl, TweenInfo.new(0.2), {
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
    end)
    
    iconBtn.MouseButton1Click:Connect(onClick)
    return iconBtn
end

-- ============================================
-- MAIN UI
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
    mainFrame.Size = UDim2.new(0, 600, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 15, 28)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 14)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(80, 55, 140)
    mainStroke.Thickness = 1.5
    mainStroke.Transparency = 0.3
    mainStroke.Parent = mainFrame
    
    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 150, 1, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(14, 11, 22)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 14)
    sidebarCorner.Parent = sidebar
    
    -- Logo
    local logoFrame = Instance.new("Frame")
    logoFrame.Size = UDim2.new(1, 0, 0, 65)
    logoFrame.BackgroundColor3 = Color3.fromRGB(22, 17, 35)
    logoFrame.BorderSizePixel = 0
    logoFrame.Parent = sidebar
    
    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 14)
    logoCorner.Parent = logoFrame
    
    local logoLabel = Instance.new("TextLabel")
    logoLabel.Size = UDim2.new(1, -20, 0, 22)
    logoLabel.Position = UDim2.new(0, 10, 0, 8)
    logoLabel.BackgroundTransparency = 1
    logoLabel.Text = "Lumber Key less"
    logoLabel.TextColor3 = Color3.fromRGB(140, 100, 255)
    logoLabel.TextSize = 14
    logoLabel.Font = Enum.Font.GothamBold
    logoLabel.TextXAlignment = Enum.TextXAlignment.Left
    logoLabel.Parent = logoFrame
    
    local creditLabel = Instance.new("TextLabel")
    creditLabel.Size = UDim2.new(1, -20, 0, 16)
    creditLabel.Position = UDim2.new(0, 10, 0, 28)
    creditLabel.BackgroundTransparency = 1
    creditLabel.Text = "by Saga"
    creditLabel.TextColor3 = Color3.fromRGB(160, 140, 200)
    creditLabel.TextSize = 10
    creditLabel.Font = Enum.Font.Gotham
    creditLabel.TextXAlignment = Enum.TextXAlignment.Left
    creditLabel.Parent = logoFrame
    
    local tierLabel = Instance.new("TextLabel")
    tierLabel.Name = "TierLabel"
    tierLabel.Size = UDim2.new(1, -20, 0, 16)
    tierLabel.Position = UDim2.new(0, 10, 0, 44)
    tierLabel.BackgroundTransparency = 1
    tierLabel.Text = "TIER: FREE"
    tierLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    tierLabel.TextSize = 10
    tierLabel.Font = Enum.Font.GothamBold
    tierLabel.TextXAlignment = Enum.TextXAlignment.Left
    tierLabel.Parent = logoFrame
    
    -- Tab Container
    local tabContainer = Instance.new("Frame")
    tabContainer.Name = "TabContainer"
    tabContainer.Size = UDim2.new(1, 0, 1, -65)
    tabContainer.Position = UDim2.new(0, 0, 0, 65)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = sidebar
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabContainer
    
    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingTop = UDim.new(0, 10)
    tabPadding.PaddingLeft = UDim.new(0, 10)
    tabPadding.PaddingRight = UDim.new(0, 10)
    tabPadding.Parent = tabContainer
    
    -- Content Area
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -150, 1, 0)
    contentArea.Position = UDim2.new(0, 150, 0, 0)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame
    
    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 55)
    header.BackgroundColor3 = Color3.fromRGB(22, 17, 35)
    header.BorderSizePixel = 0
    header.Parent = contentArea
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 14)
    headerCorner.Parent = header
    
    local headerTitle = Instance.new("TextLabel")
    headerTitle.Name = "HeaderTitle"
    headerTitle.Size = UDim2.new(1, -120, 1, 0)
    headerTitle.Position = UDim2.new(0, 20, 0, 0)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "Dashboard"
    headerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    headerTitle.TextSize = 16
    headerTitle.Font = Enum.Font.GothamBold
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    headerTitle.Parent = header
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -38, 0, 13)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
    minimizeBtn.Position = UDim2.new(1, -72, 0, 13)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
    minimizeBtn.Text = "—"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.TextSize = 14
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.Parent = header
    
    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 6)
    minimizeCorner.Parent = minimizeBtn
    
    -- Page Container
    local pageContainer = Instance.new("Frame")
    pageContainer.Name = "PageContainer"
    pageContainer.Size = UDim2.new(1, -20, 1, -75)
    pageContainer.Position = UDim2.new(0, 10, 0, 65)
    pageContainer.BackgroundTransparency = 1
    pageContainer.Parent = contentArea
    
    local pages = {}
    local tabButtons = {}
    
    local function showPage(pageName)
        for name, page in pairs(pages) do
            page.Visible = (name == pageName)
        end
        for name, btn in pairs(tabButtons) do
            if name == pageName then
                TweenService:Create(btn, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(45, 30, 75)
                }):Play()
                btn.TextColor3 = Color3.fromRGB(180, 140, 255)
            else
                TweenService:Create(btn, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(22, 17, 35)
                }):Play()
                btn.TextColor3 = Color3.fromRGB(180, 180, 200)
            end
        end
        headerTitle.Text = pageName
    end
    
    local function createTab(name, icon)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 38)
        btn.BackgroundColor3 = Color3.fromRGB(22, 17, 35)
        btn.Text = "  " .. icon .. "  " .. name
        btn.TextColor3 = Color3.fromRGB(180, 180, 200)
        btn.TextSize = 13
        btn.Font = Enum.Font.GothamBold
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.LayoutOrder = #tabButtons + 1
        btn.Parent = tabContainer
        
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            showPage(name)
        end)
        
        tabButtons[name] = btn
        
        local page = Instance.new("ScrollingFrame")
        page.Name = name
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Color3.fromRGB(100, 70, 180)
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = false
        page.Parent = pageContainer
        
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page
        
        pages[name] = page
        return page
    end
    
    local function createSection(parent, text, order)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 24)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(140, 100, 255)
        label.TextSize = 13
        label.Font = Enum.Font.GothamBold
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.LayoutOrder = order
        label.Parent = parent
        return label
    end
    
    local function createToggle(parent, text, initial, callback, order, premiumOnly)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = initial and Color3.fromRGB(80, 50, 150) or Color3.fromRGB(35, 28, 55)
        btn.Text = text .. (initial and "  [ON]" or "  [OFF]")
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 13
        btn.Font = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.LayoutOrder = order
        btn.Parent = parent
        
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
        
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 12)
        padding.Parent = btn
        
        if premiumOnly then
            local lockIcon = Instance.new("TextLabel")
            lockIcon.Size = UDim2.new(0, 80, 1, 0)
            lockIcon.Position = UDim2.new(1, -85, 0, 0)
            lockIcon.BackgroundTransparency = 1
            lockIcon.Text = "🔒 PREMIUM"
            lockIcon.TextColor3 = Color3.fromRGB(255, 200, 80)
            lockIcon.TextSize = 10
            lockIcon.Font = Enum.Font.GothamBold
            lockIcon.TextXAlignment = Enum.TextXAlignment.Right
            lockIcon.Parent = btn
        end
        
        local state = initial
        btn.MouseButton1Click:Connect(function()
            if premiumOnly and not isPremium() then
                notify("🔒 Premium Feature", "Fitur ini butuh key premium. Buka tab KEY untuk generate key.", 4)
                return
            end
            state = not state
            btn.BackgroundColor3 = state and Color3.fromRGB(80, 50, 150) or Color3.fromRGB(35, 28, 55)
            btn.Text = text .. (state and "  [ON]" or "  [OFF]")
            if callback then
                task.spawn(function()
                    local ok, err = pcall(callback, state)
                    if not ok then warn("[LKL] Toggle error:", err) end
                end)
            end
        end)
        return btn
    end
    
    local function createButton(parent, text, callback, order, premiumOnly)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = Color3.fromRGB(35, 28, 55)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 13
        btn.Font = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.LayoutOrder = order
        btn.Parent = parent
        
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
        
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 12)
        padding.Parent = btn
        
        if premiumOnly then
            local lockIcon = Instance.new("TextLabel")
            lockIcon.Size = UDim2.new(0, 80, 1, 0)
            lockIcon.Position = UDim2.new(1, -85, 0, 0)
            lockIcon.BackgroundTransparency = 1
            lockIcon.Text = "🔒 PREMIUM"
            lockIcon.TextColor3 = Color3.fromRGB(255, 200, 80)
            lockIcon.TextSize = 10
            lockIcon.Font = Enum.Font.GothamBold
            lockIcon.TextXAlignment = Enum.TextXAlignment.Right
            lockIcon.Parent = btn
        end
        
        btn.MouseButton1Click:Connect(function()
            if premiumOnly and not isPremium() then
                notify("🔒 Premium Feature", "Fitur ini butuh key premium. Buka tab KEY untuk generate key.", 4)
                return
            end
            btn.BackgroundColor3 = Color3.fromRGB(80, 50, 150)
            task.wait(0.1)
            btn.BackgroundColor3 = Color3.fromRGB(35, 28, 55)
            if callback then
                task.spawn(function()
                    local ok, err = pcall(callback)
                    if not ok then warn("[LKL] Button error:", err) end
                end)
            end
        end)
        return btn
    end
    
    -- TAB 1: DASHBOARD
    local dashPage = createTab("Dashboard", "🏠")
    
    createSection(dashPage, "⚡ AUTO CHOP", 1)
    createToggle(dashPage, "Auto Chop Trees", false, function(state)
        CONFIG.AutoChop.Enabled = state
        if state then
            CONFIG.AutoChop.AttackSpeed = isPremium() 
                and CONFIG.Premium.FastAttackSpeed 
                or CONFIG.Free.AutoChopSpeed
        end
    end, 2, false)
    
    createToggle(dashPage, "Turbo Attack Speed", false, function(state)
        CONFIG.AutoChop.AttackSpeed = state 
            and CONFIG.Premium.FastAttackSpeed 
            or CONFIG.Free.AutoChopSpeed
    end, 3, true)
    
    -- TAB 2: TELEPORT
    local tpPage = createTab("Teleport", "📍")
    
    createSection(tpPage, "🏠 PLOT", 10)
    createButton(tpPage, "Teleport to My Plot", function()
        local root = getRoot()
        if not root then return end
        local plot = getPlayerPlot()
        if not plot then
            notify("⚠️ Plot Not Found", "Plot kamu tidak ditemukan. Coba berdiri di plot dulu.", 3)
            return
        end
        
        local targetCF = nil
        local ok, pivot = pcall(function() return plot:GetPivot() end)
        if ok and pivot then
            targetCF = pivot
        elseif plot.PrimaryPart then
            targetCF = plot.PrimaryPart.CFrame
        end
        
        if targetCF then
            root.CFrame = targetCF * CFrame.new(0, 5, 0)
            notify("✅ Teleported", "Kamu di plot kamu.", 2)
        end
    end, 11, false)
    
    createSection(tpPage, "🌲 LOCATIONS", 20)
    
    local locOrder = 21
    for _, loc in ipairs(CONFIG.Teleport.Locations) do
        createButton(tpPage, "🌲 " .. loc.Name, function()
            local root = getRoot()
            if not root then return end
            
            local vehicle = getCurrentVehicle()
            if vehicle and vehicle.PrimaryPart then
                if not isPremium() then
                    notify("🔒 Vehicle Teleport", "Teleport kendaraan butuh premium. Kendaraan ditinggal.", 3)
                    root.CFrame = loc.CFrame * CFrame.new(0, 5, 0)
                    return
                end
                local ok = pcall(function() vehicle:PivotTo(loc.CFrame) end)
                if not ok then
                    root.CFrame = loc.CFrame * CFrame.new(0, 5, 0)
                end
            else
                root.CFrame = loc.CFrame * CFrame.new(0, 5, 0)
            end
            notify("✅ Teleported", "Ke " .. loc.Name, 2)
        end, locOrder, loc.Premium)
        locOrder = locOrder + 1
    end
    
    -- TAB 3: VISUAL
    local visPage = createTab("Visual", "🎨")
    
    createSection(visPage, "🎨 LIGHTING", 100)
    createToggle(visPage, "Bright World", false, function(state)
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
    end, 101, true)
    
    createToggle(visPage, "Remove Fog", false, function(state)
        if state then
            Lighting.FogEnd = 100000
            Lighting.FogStart = 100000
        else
            Lighting.FogEnd = ORIGINAL.FogEnd
            Lighting.FogStart = ORIGINAL.FogStart
        end
    end, 102, false)
    
    createToggle(visPage, "Performance Mode", false, function(state)
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
    end, 103, true)
    
    -- TAB 4: KEY SYSTEM
    local keyPage = createTab("Key System", "🔑")
    
    createSection(keyPage, "🔑 STATUS", 200)
    
    local keyInfoLbl = Instance.new("TextLabel")
    keyInfoLbl.Size = UDim2.new(1, 0, 0, 50)
    keyInfoLbl.BackgroundTransparency = 1
    keyInfoLbl.Text = "Status: FREE TIER\nHWID: " .. SESSION.HWID
    keyInfoLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
    keyInfoLbl.TextSize = 12
    keyInfoLbl.Font = Enum.Font.Gotham
    keyInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
    keyInfoLbl.TextYAlignment = Enum.TextYAlignment.Top
    keyInfoLbl.TextWrapped = true
    keyInfoLbl.LayoutOrder = 201
    keyInfoLbl.Parent = keyPage
    
    createSection(keyPage, "🎲 GENERATED KEYS (50+)", 210)
    
    local keyListFrame = Instance.new("Frame")
    keyListFrame.Size = UDim2.new(1, 0, 0, 180)
    keyListFrame.BackgroundColor3 = Color3.fromRGB(28, 22, 45)
    keyListFrame.BorderSizePixel = 0
    keyListFrame.LayoutOrder = 211
    keyListFrame.Parent = keyPage
    
    local klfCorner = Instance.new("UICorner")
    klfCorner.CornerRadius = UDim.new(0, 8)
    klfCorner.Parent = keyListFrame
    
    local keyListScroll = Instance.new("ScrollingFrame")
    keyListScroll.Size = UDim2.new(1, -10, 1, -10)
    keyListScroll.Position = UDim2.new(0, 5, 0, 5)
    keyListScroll.BackgroundTransparency = 1
    keyListScroll.BorderSizePixel = 0
    keyListScroll.ScrollBarThickness = 4
    keyListScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 70, 180)
    keyListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    keyListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    keyListScroll.Parent = keyListFrame
    
    local keyListLayout = Instance.new("UIListLayout")
    keyListLayout.Padding = UDim.new(0, 4)
    keyListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    keyListLayout.Parent = keyListScroll
    
    local function populateKeyList()
        for _, child in ipairs(keyListScroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for i, key in ipairs(GENERATED_KEYS) do
            local keyBtn = Instance.new("TextButton")
            keyBtn.Size = UDim2.new(1, -8, 0, 28)
            keyBtn.BackgroundColor3 = Color3.fromRGB(35, 28, 55)
            keyBtn.Text = "  " .. key
            keyBtn.TextColor3 = Color3.fromRGB(180, 140, 255)
            keyBtn.TextSize = 11
            keyBtn.Font = Enum.Font.Code
            keyBtn.TextXAlignment = Enum.TextXAlignment.Left
            keyBtn.LayoutOrder = i
            keyBtn.Parent = keyListScroll
            
            local kc = Instance.new("UICorner")
            kc.CornerRadius = UDim.new(0, 4)
            kc.Parent = keyBtn
            
            keyBtn.MouseButton1Click:Connect(function()
                local success, msg = setKey(key)
                if success then
                    notify("✅ Key Valid", msg, 3)
                    keyInfoLbl.Text = "Status: PREMIUM TIER ✅\nKey: " .. key .. "\nHWID: " .. SESSION.HWID
                    keyInfoLbl.TextColor3 = Color3.fromRGB(140, 255, 150)
                    tierLabel.Text = "TIER: PREMIUM"
                    tierLabel.TextColor3 = Color3.fromRGB(180, 140, 255)
                    CONFIG.AutoChop.AttackSpeed = CONFIG.Premium.FastAttackSpeed
                else
                    notify("❌ Key Invalid", msg, 3)
                end
            end)
        end
    end
    
    populateKeyList()
    
    createButton(keyPage, "🎲 Generate 50 Key Baru", function()
        GENERATED_KEYS = generate50Keys()
        populateKeyList()
        notify("🎲 Generated", "50 key baru siap dipakai. Klik salah satu untuk aktivasi.", 3)
    end, 212, false)
    
    createSection(keyPage, "🔓 MANUAL INPUT", 220)
    
    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(1, 0, 0, 38)
    keyBox.BackgroundColor3 = Color3.fromRGB(35, 28, 55)
    keyBox.Text = ""
    keyBox.PlaceholderText = "saga ganteng xxxx"
    keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyBox.PlaceholderColor3 = Color3.fromRGB(120, 100, 160)
    keyBox.TextSize = 13
    keyBox.Font = Enum.Font.Code
    keyBox.ClearTextOnFocus = false
    keyBox.LayoutOrder = 221
    keyBox.Parent = keyPage
    
    local keyBoxCorner = Instance.new("UICorner")
    keyBoxCorner.CornerRadius = UDim.new(0, 6)
    keyBoxCorner.Parent = keyBox
    
    local keyPad = Instance.new("UIPadding")
    keyPad.PaddingLeft = UDim.new(0, 12)
    keyPad.PaddingRight = UDim.new(0, 12)
    keyPad.Parent = keyBox
    
    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(1, 0, 0, 38)
    submitBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 150)
    submitBtn.Text = "🔓 Aktifkan Key"
    submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitBtn.TextSize = 13
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.LayoutOrder = 222
    submitBtn.Parent = keyPage
    
    local submitCorner = Instance.new("UICorner")
    submitCorner.CornerRadius = UDim.new(0, 6)
    submitCorner.Parent = submitBtn
    
    submitBtn.MouseButton1Click:Connect(function()
        local key = keyBox.Text
        local success, msg = setKey(key)
        if success then
            notify("✅ Key Valid", msg, 3)
            keyInfoLbl.Text = "Status: PREMIUM TIER ✅\nKey: " .. key .. "\nHWID: " .. SESSION.HWID
            keyInfoLbl.TextColor3 = Color3.fromRGB(140, 255, 150)
            tierLabel.Text = "TIER: PREMIUM"
            tierLabel.TextColor3 = Color3.fromRGB(180, 140, 255)
            CONFIG.AutoChop.AttackSpeed = CONFIG.Premium.FastAttackSpeed
        else
            notify("❌ Key Invalid", msg, 3)
        end
    end)
    
    showPage("Dashboard")
    
    createGearIcon(screenGui, function()
        mainFrame.Visible = not mainFrame.Visible
        if mainFrame.Visible then
            mainFrame.Size = UDim2.new(0, 600, 0, 20)
            TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
                Size = UDim2.new(0, 600, 0, 400)
            }):Play()
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        CONFIG.AutoChop.Enabled = false
        cleanupConnections()
        if screenGuiRef then
            pcall(function() screenGuiRef:Destroy() end)
            screenGuiRef = nil
        end
    end)
    
    minimizeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
    end)
    
    return screenGui
end

-- ============================================
-- TREE CACHE
-- ============================================

local treeCache = {}
local lastScan = 0

local function refreshTreeCache()
    local newCache = {}
    local seen = {}
    
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
-- AUTO CHOP
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
        
        if now - lastScan > CONFIG.AutoChop.CacheRefresh then
            task.spawn(refreshTreeCache)
        end
        
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

task.delay(1, function()
    notify("🌲 Lumber Key less", "by Saga — Tekan icon gear ⚙ untuk buka menu.", 4)
end)
