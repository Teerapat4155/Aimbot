-- // Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- // State & Settings (คงค่าเดิมครบถ้วน + ปรับ FOV เป็นพิมพ์ 20-300 และความสมูธ Aimbot เป็นพิมพ์ 0.1-1.0)
local Config = {
    AimbotEnabled = false,
    AimbotFOV = 100,          -- ค่าเริ่มต้นของ FOV (พิมพ์ได้ 20 - 300)
    AimbotWallCheck = false,  -- false = ไม่ล็อคหลังกำแพง (ล็อคเฉพาะตัวที่เห็น), true = ล็อคทะลุกำแพงได้
    AimbotSmoothness = 0.5,   -- ความลื่นในการหันกล้อง (พิมพ์ได้ 0.1 - 1.0)

    ESPEnabled = false,
    ESPShowName = false,
    ESPShowDistance = false,

    SpeedEnabled = false,
    SpeedValue = 16,          -- พิมพ์ได้เฉพาะ 16 - 50 (ค่าเริ่มต้น 16)
}

local DEFAULT_WALKSPEED = 16
local MIN_SPEED = 16
local MAX_SPEED = 50
local MIN_FOV = 20
local MAX_FOV = 300
local MIN_SMOOTH = 0.1
local MAX_SMOOTH = 1.0

local Connections = {}
local ESPObjects = {}
local IsDestroyed = false

-- // ฟังก์ชันดึงกล้องปัจจุบันเสมอ
local function GetCamera()
    return workspace.CurrentCamera
end

-- // ฟังก์ชันช่วยจัดการ Connection เพื่อให้ลบออกได้หมดจดตอนกด X
local function AddConnection(conn)
    table.insert(Connections, conn)
    return conn
end

-- // ฟังก์ชันตั้งค่าความเร็วเดินของตัวละครอย่างปลอดภัย
local function ApplyWalkSpeed(speedValue)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        pcall(function()
            hum.WalkSpeed = speedValue
        end)
    end
end

-- // สร้าง Parent สำหรับ UI (รองรับทั้ง CoreGui และ PlayerGui บนมือถือ)
local GuiParent
local success = pcall(function()
    local test = Instance.new("ScreenGui")
    test.Parent = CoreGui
    test:Destroy()
    GuiParent = CoreGui
end)
if not success or not GuiParent then
    GuiParent = LocalPlayer:WaitForChild("PlayerGui")
end

-- // ลบ UI เก่าถ้าเผลอรันซ้ำ
if GuiParent:FindFirstChild("CompactDeltaHub") then
    GuiParent.CompactDeltaHub:Destroy()
end

-- // สร้าง ScreenGui หลัก
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CompactDeltaHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = GuiParent

-- // Container สำหรับกล่อง ESP 2D
local ESPContainer = Instance.new("Folder")
ESPContainer.Name = "ESPContainer"
ESPContainer.Parent = ScreenGui

-- // วงกลม FOV กลางหน้าจอ
local FOVFrame = Instance.new("Frame")
FOVFrame.Name = "FOVCircle"
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.Size = UDim2.new(0, Config.AimbotFOV * 2, 0, Config.AimbotFOV * 2)
FOVFrame.BackgroundTransparency = 1
FOVFrame.Visible = false
FOVFrame.Parent = ScreenGui

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim2.new(1, 0)
FOVCorner.Parent = FOVFrame

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Color = Color3.fromRGB(0, 255, 120)
FOVStroke.Thickness = 1.2
FOVStroke.Transparency = 0.3
FOVStroke.Parent = FOVFrame

-- // ปุ่มลอยตอนย่อหน้าต่าง (🚀)
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingIcon"
FloatingBtn.Size = UDim2.new(0, 38, 0, 38)
FloatingBtn.Position = UDim2.new(0.05, 0, 0.25, 0)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
FloatingBtn.Text = "🚀"
FloatingBtn.TextSize = 20
FloatingBtn.Visible = false
FloatingBtn.AutoButtonColor = true
FloatingBtn.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(1, 0)
FloatCorner.Parent = FloatingBtn

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Color3.fromRGB(0, 255, 120)
FloatStroke.Thickness = 1.5
FloatStroke.Parent = FloatingBtn

-- // หน้าต่าง UI หลัก (ขนาดเล็กกะทัดรัดสำหรับมือถือ)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 210, 0, 255)
MainFrame.Position = UDim2.new(0.5, -105, 0.5, -127)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(55, 55, 65)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

-- // แถบด้านบน (TopBar) + ปุ่มย่อ (-) และปุ่มปิด (X)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 26)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 8)
TopCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -55, 1, 0)
TitleLabel.Position = UDim2.new(0, 8, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Menu v1.5"
TitleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
TitleLabel.TextSize = 12
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

-- ปุ่มย่อ (-)
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 22, 0, 20)
MinBtn.Position = UDim2.new(1, -48, 0, 3)
MinBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = TopBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 4)

-- ปุ่มกากบาท (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 22, 0, 20)
CloseBtn.Position = UDim2.new(1, -24, 0, 3)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 11
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

-- // ระบบลาก UI ทั่วไป (สำหรับ TopBar)
local function MakeDraggable(dragHandle, targetFrame)
    local dragging = false
    local dragInput, dragStart, startPos

    AddConnection(dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end))

    AddConnection(dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end))
end

MakeDraggable(TopBar, MainFrame)

-- // ระบบลากและคลิกปุ่มลอย 🚀 แบบแยกขาดกัน
do
    local dragging = false
    local movedFar = false
    local dragInput, dragStart, startPos
    local DRAG_THRESHOLD = 6

    AddConnection(FloatingBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            movedFar = false
            dragStart = input.Position
            startPos = FloatingBtn.Position
            dragInput = input
        end
    end))

    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > DRAG_THRESHOLD then
                movedFar = true
            end
            FloatingBtn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end))

    AddConnection(UserInputService.InputEnded:Connect(function(input)
        if dragging and input == dragInput then
            local wasClick = not movedFar
            dragging = false
            dragInput = nil

            if wasClick and not IsDestroyed then
                FloatingBtn.Visible = false
                local cam = GetCamera()
                local viewSize = cam and cam.ViewportSize or Vector2.new(1280, 720)
                local padding = 16
                local targetX = math.clamp(FloatingBtn.AbsolutePosition.X, padding, math.max(padding, viewSize.X - MainFrame.AbsoluteSize.X - padding))
                local targetY = math.clamp(FloatingBtn.AbsolutePosition.Y, padding, math.max(padding, viewSize.Y - MainFrame.AbsoluteSize.Y - padding))
                MainFrame.Position = UDim2.new(0, targetX, 0, targetY)
                MainFrame.Visible = true
            end
        end
    end))
end

-- // พื้นที่ใส่เมนูแบบเลื่อนขึ้นลงได้ (ScrollingFrame)
local Container = Instance.new("ScrollingFrame")
Container.Name = "MenuContainer"
Container.Size = UDim2.new(1, -10, 1, -32)
Container.Position = UDim2.new(0, 5, 0, 29)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.ScrollBarThickness = 2
Container.CanvasSize = UDim2.new(0, 0, 0, 0)
Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
Container.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 5)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Parent = Container

-- // ฟังก์ชันสร้าง Toggle Switch ขนาดเล็ก
local function CreateToggle(text, defaultState, isSubMenu, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -4, 0, 24)
    Row.BackgroundColor3 = isSubMenu and Color3.fromRGB(26, 26, 32) or Color3.fromRGB(32, 32, 40)
    Row.BorderSizePixel = 0
    Row.Parent = Container
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 5)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -45, 1, 0)
    Label.Position = UDim2.new(0, isSubMenu and 14 or 8, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = (isSubMenu and "↳ " or "") .. text
    Label.TextColor3 = isSubMenu and Color3.fromRGB(195, 195, 205) or Color3.fromRGB(240, 240, 240)
    Label.TextSize = 11
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local SwitchBg = Instance.new("TextButton")
    SwitchBg.Size = UDim2.new(0, 32, 0, 16)
    SwitchBg.Position = UDim2.new(1, -38, 0.5, -8)
    SwitchBg.BackgroundColor3 = defaultState and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(65, 65, 75)
    SwitchBg.Text = ""
    SwitchBg.AutoButtonColor = false
    SwitchBg.Parent = Row
    Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 12, 0, 12)
    Knob.Position = defaultState and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.Parent = SwitchBg
    Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local state = defaultState
    AddConnection(SwitchBg.MouseButton1Click:Connect(function()
        state = not state
        SwitchBg.BackgroundColor3 = state and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(65, 65, 75)
        Knob.Position = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        pcall(callback, state)
    end))

    return Row
end

-- // ฟังก์ชันสร้างช่องพิมพ์ตัวเลขจำนวนเต็มแบบจำกัดช่วง (เช่น Speed 16-50, FOV 20-300)
local function CreateClampedNumberInput(text, minVal, maxVal, defaultVal, isSubMenu, maxDigits, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -4, 0, 24)
    Row.BackgroundColor3 = isSubMenu and Color3.fromRGB(26, 26, 32) or Color3.fromRGB(32, 32, 40)
    Row.BorderSizePixel = 0
    Row.Parent = Container
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 5)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -70, 1, 0)
    Label.Position = UDim2.new(0, isSubMenu and 14 or 8, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = (isSubMenu and "↳ " or "") .. text .. " (" .. tostring(minVal) .. "-" .. tostring(maxVal) .. ")"
    Label.TextColor3 = isSubMenu and Color3.fromRGB(195, 195, 205) or Color3.fromRGB(230, 230, 235)
    Label.TextSize = 10
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(0, 48, 0, 18)
    InputBox.Position = UDim2.new(1, -54, 0.5, -9)
    InputBox.BackgroundColor3 = Color3.fromRGB(45, 45, 56)
    InputBox.Text = tostring(defaultVal)
    InputBox.TextColor3 = Color3.fromRGB(0, 255, 120)
    InputBox.TextSize = 11
    InputBox.Font = Enum.Font.GothamBold
    InputBox.ClearTextOnFocus = false
    InputBox.Parent = Row
    Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 4)

    local currentVal = math.clamp(tonumber(defaultVal) or minVal, minVal, maxVal)
    local digitLimit = maxDigits or 3

    AddConnection(InputBox:GetPropertyChangedSignal("Text"):Connect(function()
        local digitsOnly = InputBox.Text:gsub("[^%d]", "")
        if #digitsOnly > digitLimit then
            digitsOnly = string.sub(digitsOnly, 1, digitLimit)
        end
        if InputBox.Text ~= digitsOnly then
            InputBox.Text = digitsOnly
        end
    end))

    AddConnection(InputBox.FocusLost:Connect(function()
        local num = tonumber(InputBox.Text)
        if num then
            currentVal = math.clamp(math.floor(num), minVal, maxVal)
        end
        InputBox.Text = tostring(currentVal)
        pcall(callback, currentVal)
    end))

    return Row
end

-- // ฟังก์ชันสร้างช่องพิมพ์ตัวเลขทศนิยม 1 ตำแหน่งแบบจำกัดช่วง (เช่น Smooth 0.1-1.0)
local function CreateClampedDecimalInput(text, minVal, maxVal, defaultVal, isSubMenu, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -4, 0, 24)
    Row.BackgroundColor3 = isSubMenu and Color3.fromRGB(26, 26, 32) or Color3.fromRGB(32, 32, 40)
    Row.BorderSizePixel = 0
    Row.Parent = Container
    Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 5)

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -70, 1, 0)
    Label.Position = UDim2.new(0, isSubMenu and 14 or 8, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = (isSubMenu and "↳ " or "") .. text .. " (" .. string.format("%.1f", minVal) .. "-" .. string.format("%.1f", maxVal) .. ")"
    Label.TextColor3 = isSubMenu and Color3.fromRGB(195, 195, 205) or Color3.fromRGB(230, 230, 235)
    Label.TextSize = 10
    Label.Font = Enum.Font.Gotham
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Row

    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(0, 48, 0, 18)
    InputBox.Position = UDim2.new(1, -54, 0.5, -9)
    InputBox.BackgroundColor3 = Color3.fromRGB(45, 45, 56)
    InputBox.Text = string.format("%.1f", math.clamp(tonumber(defaultVal) or minVal, minVal, maxVal))
    InputBox.TextColor3 = Color3.fromRGB(0, 255, 120)
    InputBox.TextSize = 11
    InputBox.Font = Enum.Font.GothamBold
    InputBox.ClearTextOnFocus = false
    InputBox.Parent = Row
    Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 4)

    local currentVal = tonumber(string.format("%.1f", math.clamp(tonumber(defaultVal) or minVal, minVal, maxVal))) or minVal

    AddConnection(InputBox:GetPropertyChangedSignal("Text"):Connect(function()
        local raw = InputBox.Text:gsub("[^%d%.]", "")
        local seenDot = false
        local cleaned = {}
        for i = 1, #raw do
            local ch = string.sub(raw, i, i)
            if ch == "." then
                if not seenDot then
                    seenDot = true
                    table.insert(cleaned, ch)
                end
            else
                table.insert(cleaned, ch)
            end
        end
        local resultText = table.concat(cleaned)
        if #resultText > 4 then
            resultText = string.sub(resultText, 1, 4)
        end
        if InputBox.Text ~= resultText then
            InputBox.Text = resultText
        end
    end))

    AddConnection(InputBox.FocusLost:Connect(function()
        local num = tonumber(InputBox.Text)
        if num and num == num then
            local clamped = math.clamp(num, minVal, maxVal)
            local rounded = tonumber(string.format("%.1f", clamped))
            if rounded then
                currentVal = math.clamp(rounded, minVal, maxVal)
            end
        end
        InputBox.Text = string.format("%.1f", currentVal)
        pcall(callback, currentVal)
    end))

    return Row
end

-- ==========================================
-- // สร้างรายการเมนูตามลำดับเดิม + FOV พิมพ์ 20-300 + ความสมูธ Aimbot พิมพ์ 0.1-1.0
-- ==========================================

-- เมนู 1: Aimbot + ปรับ FOV (พิมพ์ 20-300) + ความสมูธ Aimbot (พิมพ์ 0.1-1.0) + สวิตช์ล็อคหลังกำแพง
CreateToggle("1. Aimbot (ล็อคใกล้กลางจอ)", Config.AimbotEnabled, false, function(val)
    Config.AimbotEnabled = val
    FOVFrame.Visible = val
end)

CreateToggle("ล็อคหลังกำแพง (Wallbang)", Config.AimbotWallCheck, true, function(val)
    Config.AimbotWallCheck = val
end)

CreateClampedNumberInput("ขนาด FOV", MIN_FOV, MAX_FOV, Config.AimbotFOV, true, 3, function(val)
    Config.AimbotFOV = val
    FOVFrame.Size = UDim2.new(0, val * 2, 0, val * 2)
end)

CreateClampedDecimalInput("ความสมูธ", MIN_SMOOTH, MAX_SMOOTH, Config.AimbotSmoothness, true, function(val)
    Config.AimbotSmoothness = val
end)

-- เมนู 2: ESP กล่องสีเขียว + เมนูย่อย
CreateToggle("2. ESP (กล่องสีเขียว)", Config.ESPEnabled, false, function(val)
    Config.ESPEnabled = val
end)

CreateToggle("แสดงชื่อผู้เล่น", Config.ESPShowName, true, function(val)
    Config.ESPShowName = val
end)

CreateToggle("แสดงระยะทาง (m)", Config.ESPShowDistance, true, function(val)
    Config.ESPShowDistance = val
end)

-- เมนู 3: วิ่งเร็วขึ้น (เปิด/ปิด + ช่องพิมพ์ตัวเลขได้เฉพาะ 16 - 50)
CreateToggle("3. วิ่งเร็วขึ้น (Speed)", Config.SpeedEnabled, false, function(val)
    Config.SpeedEnabled = val
    if val then
        ApplyWalkSpeed(Config.SpeedValue)
    else
        ApplyWalkSpeed(DEFAULT_WALKSPEED)
    end
end)

CreateClampedNumberInput("ความเร็วเดิน", MIN_SPEED, MAX_SPEED, Config.SpeedValue, true, 2, function(val)
    Config.SpeedValue = val
    if Config.SpeedEnabled then
        ApplyWalkSpeed(Config.SpeedValue)
    end
end)

-- รองรับตอนตัวละครเกิดใหม่ (CharacterAdded) หากเปิดวิ่งเร็วขึ้นค้างไว้
AddConnection(LocalPlayer.CharacterAdded:Connect(function(newChar)
    if IsDestroyed then return end
    task.spawn(function()
        local hum = newChar:WaitForChild("Humanoid", 5)
        if hum and Config.SpeedEnabled and not IsDestroyed then
            pcall(function()
                hum.WalkSpeed = Config.SpeedValue
            end)
        end
    end)
end))

-- ==========================================
-- // ฟังก์ชันช่วยคำนวณขอบเขตตัวละคร & เช็กกำแพง
-- ==========================================
local function GetCharacterBounds(char)
    local ok, cf, size = pcall(function()
        return char:GetBoundingBox()
    end)
    if ok and cf and size then
        return cf, size
    end

    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        local extOk, extSize = pcall(function()
            return char:GetExtentsSize()
        end)
        if extOk and extSize then
            return root.CFrame, extSize
        end
        return root.CFrame, Vector3.new(3, 5, 2)
    end
    return nil, nil
end

local function IsNonBlockingPart(part)
    if not part or not part:IsA("BasePart") then
        return true
    end
    if part.Transparency >= 0.9 or (not part.CanCollide and part.Transparency > 0.35) then
        return true
    end
    return false
end

local function IsTargetVisible(camera, targetPart, targetChar)
    if Config.AimbotWallCheck then
        return true
    end

    local origin = camera.CFrame.Position
    local fullVector = targetPart.Position - origin
    local totalDist = fullVector.Magnitude
    if totalDist <= 0.1 then
        return true
    end

    local dirUnit = fullVector.Unit
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true

    local ignoreList = {}
    if LocalPlayer.Character then
        table.insert(ignoreList, LocalPlayer.Character)
    end

    local currentOrigin = origin
    local remainingDist = totalDist

    for _ = 1, 6 do
        rayParams.FilterDescendantsInstances = ignoreList
        local result = workspace:Raycast(currentOrigin, dirUnit * remainingDist, rayParams)
        if not result then
            return true
        end

        local hitPart = result.Instance
        if targetChar and hitPart:IsDescendantOf(targetChar) then
            return true
        end

        if IsNonBlockingPart(hitPart) then
            table.insert(ignoreList, hitPart)
            local stepDist = (result.Position - currentOrigin).Magnitude + 0.05
            if stepDist >= remainingDist then
                return true
            end
            currentOrigin = origin + dirUnit * stepDist
            remainingDist = totalDist - stepDist
        else
            return false
        end
    end

    return false
end

-- ==========================================
-- // ระบบการทำงานของ ESP (กรอบ 2D ครอบพอดีตัว & ทะลุกำแพง)
-- ==========================================
local function RemoveESP(player)
    if ESPObjects[player] then
        pcall(function()
            if ESPObjects[player].Box then
                ESPObjects[player].Box:Destroy()
            end
            if ESPObjects[player].Label then
                ESPObjects[player].Label:Destroy()
            end
        end)
        ESPObjects[player] = nil
    end
end

local function CreateESPForPlayer(player)
    if player == LocalPlayer then return end
    RemoveESP(player)

    local boxFrame = Instance.new("Frame")
    boxFrame.Name = "ESPBox_" .. player.Name
    boxFrame.BackgroundTransparency = 1
    boxFrame.BorderSizePixel = 0
    boxFrame.Visible = false
    boxFrame.Parent = ESPContainer

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 0)
    stroke.Thickness = 1.6
    stroke.Parent = boxFrame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "ESPInfo_" .. player.Name
    infoLabel.AnchorPoint = Vector2.new(0.5, 1)
    infoLabel.Size = UDim2.new(0, 160, 0, 16)
    infoLabel.BackgroundTransparency = 1
    infoLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    infoLabel.TextStrokeTransparency = 0.35
    infoLabel.TextSize = 11
    infoLabel.Font = Enum.Font.GothamBold
    infoLabel.Text = ""
    infoLabel.Visible = false
    infoLabel.Parent = ESPContainer

    ESPObjects[player] = {
        Box = boxFrame,
        Label = infoLabel
    }
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        CreateESPForPlayer(p)
    end
end

AddConnection(Players.PlayerAdded:Connect(function(p)
    if not IsDestroyed then
        CreateESPForPlayer(p)
    end
end))

AddConnection(Players.PlayerRemoving:Connect(function(p)
    RemoveESP(p)
end))

-- ==========================================
-- // ระบบคำนวณ Aimbot (หาตัวที่ใกล้กลางจอที่สุดในวง FOV)
-- ==========================================
local function GetClosestTargetToCenter(camera)
    if not camera then return nil end

    local closestTarget = nil
    local shortestDistance = Config.AimbotFOV
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            local targetPart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")

            if humanoid and humanoid.Health > 0 and targetPart then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                if onScreen and screenPos.Z > 0 then
                    local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if distFromCenter <= shortestDistance and IsTargetVisible(camera, targetPart, char) then
                        shortestDistance = distFromCenter
                        closestTarget = targetPart
                    end
                end
            end
        end
    end

    return closestTarget
end

-- ==========================================
-- // Main Loop (RenderStepped)
-- ==========================================
AddConnection(RunService.RenderStepped:Connect(function(dt)
    if IsDestroyed then return end

    -- คงค่าความเร็วเดินไว้หากเปิดใช้งานอยู่ (กันบางแมพตั้ง WalkSpeed กลับเป็น 16 เอง)
    if Config.SpeedEnabled then
        local myChar = LocalPlayer.Character
        local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        if myHum and myHum.Health > 0 and myHum.WalkSpeed ~= Config.SpeedValue then
            pcall(function()
                myHum.WalkSpeed = Config.SpeedValue
            end)
        end
    end

    local camera = GetCamera()
    if not camera then return end

    -- 1. อัปเดต Aimbot
    if Config.AimbotEnabled then
        local target = GetClosestTargetToCenter(camera)
        if target then
            local camPos = camera.CFrame.Position
            local desiredCFrame = CFrame.new(camPos, target.Position)
            local alpha = math.clamp(1 - math.exp(-Config.AimbotSmoothness * 22 * math.max(dt, 0.001)), 0.05, 0.95)
            camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
        end
    end

    -- 2. อัปเดต ESP
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local viewSize = camera.ViewportSize
    local camCFrame = camera.CFrame
    local nearPlaneZ = -0.35

    for player, data in pairs(ESPObjects) do
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if Config.ESPEnabled and char and hum and hum.Health > 0 then
            local cf, size = GetCharacterBounds(char)
            if cf and size then
                local halfX = size.X * 0.45
                local halfY = size.Y * 0.5
                local halfZ = size.Z * 0.45

                local worldCorners = {
                    cf * Vector3.new(-halfX, -halfY, -halfZ),
                    cf * Vector3.new(-halfX, -halfY,  halfZ),
                    cf * Vector3.new(-halfX,  halfY, -halfZ),
                    cf * Vector3.new(-halfX,  halfY,  halfZ),
                    cf * Vector3.new( halfX, -halfY, -halfZ),
                    cf * Vector3.new( halfX, -halfY,  halfZ),
                    cf * Vector3.new( halfX,  halfY, -halfZ),
                    cf * Vector3.new( halfX,  halfY,  halfZ),
                }

                local camSpacePoints = {}
                local frontCount = 0
                for i, wPt in ipairs(worldCorners) do
                    local cPt = camCFrame:PointToObjectSpace(wPt)
                    camSpacePoints[i] = cPt
                    if cPt.Z < nearPlaneZ then
                        frontCount += 1
                    end
                end

                local minX, minY = math.huge, math.huge
                local maxX, maxY = -math.huge, -math.huge

                if frontCount > 0 then
                    for i, cPt in ipairs(camSpacePoints) do
                        local clippedPt = cPt
                        if clippedPt.Z >= nearPlaneZ then
                            local bestFront = nil
                            local bestDist = math.huge
                            for j, otherPt in ipairs(camSpacePoints) do
                                if j ~= i and otherPt.Z < nearPlaneZ then
                                    local d = (otherPt - cPt).Magnitude
                                    if d < bestDist then
                                        bestDist = d
                                        bestFront = otherPt
                                    end
                                end
                            end
                            if bestFront then
                                local dz = bestFront.Z - cPt.Z
                                if math.abs(dz) > 1e-4 then
                                    local t = math.clamp((nearPlaneZ - cPt.Z) / dz, 0, 1)
                                    clippedPt = cPt:Lerp(bestFront, t)
                                else
                                    clippedPt = Vector3.new(bestFront.X, bestFront.Y, nearPlaneZ)
                                end
                            end
                        end

                        local screenPos = camera:WorldToViewportPoint(camCFrame:PointToWorldSpace(clippedPt))
                        if screenPos.Z > 0 then
                            local sx = math.clamp(screenPos.X, -viewSize.X, viewSize.X * 2)
                            local sy = math.clamp(screenPos.Y, -viewSize.Y, viewSize.Y * 2)
                            if sx < minX then minX = sx end
                            if sx > maxX then maxX = sx end
                            if sy < minY then minY = sy end
                            if sy > maxY then maxY = sy end
                        end
                    end
                end

                local overlapsScreen = frontCount > 0
                    and maxX >= 0
                    and minX <= viewSize.X
                    and maxY >= 0
                    and minY <= viewSize.Y

                if overlapsScreen and maxX > minX and maxY > minY then
                    local boxWidth = math.clamp(maxX - minX, 8, viewSize.X * 2)
                    local boxHeight = math.clamp(maxY - minY, 14, viewSize.Y * 2)

                    data.Box.Visible = true
                    data.Box.Position = UDim2.fromOffset(minX, minY)
                    data.Box.Size = UDim2.fromOffset(boxWidth, boxHeight)

                    local textParts = {}
                    if Config.ESPShowName then
                        table.insert(textParts, player.DisplayName or player.Name)
                    end
                    if Config.ESPShowDistance and myRoot then
                        local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
                        if rootPart then
                            local dist = math.floor((myRoot.Position - rootPart.Position).Magnitude)
                            table.insert(textParts, "[" .. tostring(dist) .. "m]")
                        end
                    end

                    if #textParts > 0 then
                        data.Label.Visible = true
                        data.Label.Text = table.concat(textParts, " ")
                        local centerX = math.clamp((minX + maxX) * 0.5, 80, math.max(80, viewSize.X - 80))
                        local topY = math.clamp(minY - 2, 18, math.max(18, viewSize.Y - 4))
                        data.Label.Position = UDim2.fromOffset(centerX, topY)
                    else
                        data.Label.Visible = false
                    end
                else
                    data.Box.Visible = false
                    data.Label.Visible = false
                end
            else
                data.Box.Visible = false
                data.Label.Visible = false
            end
        else
            data.Box.Visible = false
            data.Label.Visible = false
        end
    end
end))

-- ==========================================
-- // ปุ่มย่อหน้าต่าง (-) และปุ่มปิดถาวร (X)
-- ==========================================
AddConnection(MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatingBtn.Visible = true
end))

AddConnection(CloseBtn.MouseButton1Click:Connect(function()
    IsDestroyed = true
    Config.AimbotEnabled = false
    Config.ESPEnabled = false
    Config.SpeedEnabled = false

    -- คืนค่าความเร็วเดินกลับเป็นปกติก่อนปิดสคริปต์
    ApplyWalkSpeed(DEFAULT_WALKSPEED)

    for _, conn in ipairs(Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(Connections)

    for player, _ in pairs(ESPObjects) do
        RemoveESP(player)
    end
    table.clear(ESPObjects)

    pcall(function()
        ScreenGui:Destroy()
    end)
end))
