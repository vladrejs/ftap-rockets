-- ============================================================================
-- FTAP ROCKET SYSTEM (PC + MOBILE ROUND BUTTONS + 100% WORKING TOUCH DRAG)
-- Клавиши на ПК: [V] Захват | [B] Обычный выстрел | [N] Самонаводка
-- На телефоне: Круглые кнопки, рабочее перетаскивание пальцем, размер, прозрачность
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================================
-- 1. АВТО-ОЧИСТКА СТАРОГО СКРИПТА ПРИ ПЕРЕЗАПУСКЕ
-- ============================================================================
local env = (getgenv and getgenv()) or _G
if env.FtapRocketCleanup then
    pcall(env.FtapRocketCleanup)
end

local rockets = {}
local homingMissiles = {}
local maxSlots = 2
local isDestroyed = false

-- Состояние интерфейса и редактора
local touchButtonsEnabled = true
local editModeEnabled = false
local buttonScale = 1.0
local minScale = 0.55
local maxScale = 1.9
local buttonTransparency = 0.15

-- ============================================================================
-- 2. ЛОГИКА РАКЕТ (ЗАХВАТ, ВЫСТРЕЛ, САМОНАВЕДЕНИЕ)
-- ============================================================================
local function getLocalRootPart()
    local char = player.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function getAimedBombMissile()
    local mouseRay = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    if player.Character then
        raycastParams.FilterDescendantsInstances = {player.Character}
    end

    local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 60, raycastParams)
    if raycastResult and raycastResult.Instance then
        local hitInstance = raycastResult.Instance
        local current = hitInstance
        while current and current ~= workspace do
            if current.Name == "BombMissile" and current:IsA("Model") then
                return current
            end
            current = current.Parent
        end
        if hitInstance.Name == "BombMissile" then
            return hitInstance
        end
    end
    return nil
end

local function getBestTargetPlayer()
    local mouseRay = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    if player.Character then
        raycastParams.FilterDescendantsInstances = {player.Character}
    end

    local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 500, raycastParams)
    if raycastResult and raycastResult.Instance then
        local current = raycastResult.Instance
        while current and current ~= workspace do
            local foundPlayer = Players:GetPlayerFromCharacter(current)
            if foundPlayer and foundPlayer ~= player then
                return current
            end
            current = current.Parent
        end
    end

    local closestTarget = nil
    local shortestDistance = math.huge
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local targetRoot = p.Character.HumanoidRootPart
            local screenPos, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                if dist < 150 and dist < shortestDistance then
                    shortestDistance = dist
                    closestTarget = p.Character
                end
            end
        end
    end

    return closestTarget
end

local function ActionGrabRocket()
    if isDestroyed then return end
    local target = getAimedBombMissile()
    local rootPart = getLocalRootPart()

    if target and rootPart then
        local alreadyTaken = false
        for _, r in ipairs(rockets) do
            if r == target or target:IsDescendantOf(r) then
                alreadyTaken = true
                break
            end
        end

        if not alreadyTaken then
            if #rockets < maxSlots then
                table.insert(rockets, target)
                print("BombMissile захвачена! В арсенале:", #rockets)
            else
                print("Слоты заполнены (максимум 2)!")
            end
        else
            print("Эта ракета уже у тебя!")
        end
    else
        print("Наведи центр экрана на BombMissile!")
    end
end

local function ActionNormalFire()
    if isDestroyed then return end
    if #rockets > 0 then
        local firedRocket = table.remove(rockets, 1)
        if firedRocket and firedRocket.Parent then
            for _, part in ipairs(firedRocket:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end

            local spawnPos = camera.CFrame + (camera.CFrame.LookVector * 10)
            local shootCFrame = spawnPos * CFrame.Angles(-math.rad(90), 0, 0)

            if firedRocket:IsA("Model") then
                firedRocket:PivotTo(shootCFrame)
                if firedRocket.PrimaryPart then
                    firedRocket.PrimaryPart.AssemblyLinearVelocity = camera.CFrame.LookVector * 400
                else
                    for _, part in ipairs(firedRocket:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.AssemblyLinearVelocity = camera.CFrame.LookVector * 400
                        end
                    end
                end
            else
                firedRocket.CFrame = shootCFrame
                firedRocket.AssemblyLinearVelocity = camera.CFrame.LookVector * 400
            end

            task.delay(0.5, function()
                if firedRocket and firedRocket.Parent then
                    for _, part in ipairs(firedRocket:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = true
                        end
                    end
                end
            end)
            print("Обычный выстрел!")
        end
    else
        print("Нет ракет в арсенале!")
    end
end

local function ActionHomingFire()
    if isDestroyed then return end
    if #rockets > 0 then
        local firedRocket = table.remove(rockets, 1)
        local targetChar = getBestTargetPlayer()

        if firedRocket and firedRocket.Parent then
            for _, part in ipairs(firedRocket:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end

            local spawnPos = camera.CFrame.Position + (camera.CFrame.LookVector * 10)
            local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            local initialCF = camera.CFrame * CFrame.Angles(-math.rad(90), 0, 0)
            if targetRoot then
                initialCF = CFrame.new(spawnPos, targetRoot.Position) * CFrame.Angles(-math.rad(90), 0, 0)
            end

            if firedRocket:IsA("Model") then
                firedRocket:PivotTo(initialCF)
            else
                firedRocket.CFrame = initialCF
            end

            table.insert(homingMissiles, {
                rocket = firedRocket,
                target = targetChar,
                speed = 180,
                initialDir = camera.CFrame.LookVector
            })

            task.delay(0.6, function()
                if firedRocket and firedRocket.Parent then
                    for _, part in ipairs(firedRocket:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = true
                        end
                    end
                end
            end)

            if targetChar and targetChar:FindFirstChild("Humanoid") then
                print("Самонаводящаяся ракета летит за игроком:", targetChar.Name)
            else
                print("Игрок не найден вблизи прицела, ракета летит прямо.")
            end
        end
    else
        print("Нет ракет в арсенале!")
    end
end

-- ============================================================================
-- 3. ЖЕЛЕЗОБЕТОННОЕ ПЕРЕТАСКИВАНИЕ ЧЕРЕЗ GETMOUSELOCATION()
-- ============================================================================
local activeConnections = {}
local function TrackConn(conn)
    table.insert(activeConnections, conn)
    return conn
end

local dragControllers = {}

local function AttachDrag(dragSource, targetFrame, canDragChecker, onClickCallback)
    local controller = {
        dragging = false,
        startMouse = Vector2.zero,
        startPos = UDim2.new(),
        moved = 0
    }

    TrackConn(dragSource.InputBegan:Connect(function(input)
        if isDestroyed then return end
        local isTouch = input.UserInputType == Enum.UserInputType.Touch
        local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
        if not (isTouch or isMouse) then return end

        controller.dragging = true
        controller.startMouse = UserInputService:GetMouseLocation()
        controller.startPos = targetFrame.Position
        controller.moved = 0
    end))

    TrackConn(UserInputService.InputEnded:Connect(function(input)
        if not controller.dragging then return end
        local isTouch = input.UserInputType == Enum.UserInputType.Touch
        local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
        if not (isTouch or isMouse) then return end

        local wasTap = controller.moved < 10
        controller.dragging = false

        if wasTap and onClickCallback then
            local allowed = (not canDragChecker) or (not canDragChecker())
            if allowed then
                onClickCallback()
            end
        end
    end))

    controller.Update = function()
        if not controller.dragging or isDestroyed then return end
        if canDragChecker and not canDragChecker() then return end

        local nowMouse = UserInputService:GetMouseLocation()
        local delta = nowMouse - controller.startMouse
        controller.moved = delta.Magnitude

        targetFrame.Position = UDim2.new(
            controller.startPos.X.Scale,
            controller.startPos.X.Offset + delta.X,
            controller.startPos.Y.Scale,
            controller.startPos.Y.Offset + delta.Y
        )
    end

    table.insert(dragControllers, controller)
end

-- ============================================================================
-- 4. ИНТЕРФЕЙС: МЕНЮ + КРУГЛЫЕ КНОПКИ + РЕДАКТОР
-- ============================================================================
local function RemoveOldGui(parentObj)
    if not parentObj then return end
    for _, child in ipairs(parentObj:GetChildren()) do
        if child.Name == "FtapRocketMobileGui" then
            child:Destroy()
        end
    end
end

RemoveOldGui(CoreGui)
if player then
    RemoveOldGui(player:FindFirstChildOfClass("PlayerGui"))
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FtapRocketMobileGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local attached = pcall(function()
    screenGui.Parent = CoreGui
end)
if not attached and player then
    screenGui.Parent = player:WaitForChild("PlayerGui")
end

-- Главное меню
local mainMenu = Instance.new("Frame")
mainMenu.Name = "MainMenu"
mainMenu.Size = UDim2.new(0, 248, 0, 250)
mainMenu.Position = UDim2.new(0, 14, 0.18, 0)
mainMenu.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
mainMenu.BackgroundTransparency = 0.12
mainMenu.BorderSizePixel = 0
mainMenu.Active = true
mainMenu.Parent = screenGui

Instance.new("UICorner", mainMenu).CornerRadius = UDim.new(0, 14)
local menuStroke = Instance.new("UIStroke")
menuStroke.Color = Color3.fromRGB(255, 255, 255)
menuStroke.Transparency = 0.85
menuStroke.Thickness = 1
menuStroke.Parent = mainMenu

local menuTitle = Instance.new("TextButton")
menuTitle.Size = UDim2.new(1, -68, 0, 26)
menuTitle.Position = UDim2.new(0, 10, 0, 5)
menuTitle.BackgroundTransparency = 1
menuTitle.Text = "🚀 Ракеты • Слоты: 0/2"
menuTitle.TextColor3 = Color3.fromRGB(245, 248, 255)
menuTitle.TextSize = 13
menuTitle.Font = Enum.Font.GothamBold
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Parent = mainMenu

AttachDrag(menuTitle, mainMenu, function() return true end, nil)

local hideMenuBtn = Instance.new("TextButton")
hideMenuBtn.Size = UDim2.new(0, 26, 0, 24)
hideMenuBtn.Position = UDim2.new(1, -58, 0, 6)
hideMenuBtn.BackgroundColor3 = Color3.fromRGB(42, 46, 58)
hideMenuBtn.Text = "—"
hideMenuBtn.TextColor3 = Color3.fromRGB(235, 240, 250)
hideMenuBtn.TextSize = 14
hideMenuBtn.Font = Enum.Font.GothamBold
hideMenuBtn.Parent = mainMenu
Instance.new("UICorner", hideMenuBtn).CornerRadius = UDim.new(0, 7)

local closeAllBtn = Instance.new("TextButton")
closeAllBtn.Size = UDim2.new(0, 24, 0, 24)
closeAllBtn.Position = UDim2.new(1, -29, 0, 6)
closeAllBtn.BackgroundColor3 = Color3.fromRGB(165, 42, 48)
closeAllBtn.Text = "✕"
closeAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeAllBtn.TextSize = 13
closeAllBtn.Font = Enum.Font.GothamBold
closeAllBtn.Parent = mainMenu
Instance.new("UICorner", closeAllBtn).CornerRadius = UDim.new(0, 7)

local toggleBtnsBtn = Instance.new("TextButton")
toggleBtnsBtn.Size = UDim2.new(1, -20, 0, 36)
toggleBtnsBtn.Position = UDim2.new(0, 10, 0, 38)
toggleBtnsBtn.BackgroundColor3 = Color3.fromRGB(46, 155, 86)
toggleBtnsBtn.Text = "Кнопки на экране: ВКЛ"
toggleBtnsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtnsBtn.TextSize = 13
toggleBtnsBtn.Font = Enum.Font.GothamBold
toggleBtnsBtn.Parent = mainMenu
Instance.new("UICorner", toggleBtnsBtn).CornerRadius = UDim.new(0, 9)

local editModeBtn = Instance.new("TextButton")
editModeBtn.Size = UDim2.new(1, -20, 0, 36)
editModeBtn.Position = UDim2.new(0, 10, 0, 80)
editModeBtn.BackgroundColor3 = Color3.fromRGB(52, 98, 215)
editModeBtn.Text = "Редактор кнопок: ВЫКЛ"
editModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
editModeBtn.TextSize = 13
editModeBtn.Font = Enum.Font.GothamBold
editModeBtn.Parent = mainMenu
Instance.new("UICorner", editModeBtn).CornerRadius = UDim.new(0, 9)

local sizeLabel = Instance.new("TextLabel")
sizeLabel.Size = UDim2.new(0.56, 0, 0, 34)
sizeLabel.Position = UDim2.new(0, 10, 0, 122)
sizeLabel.BackgroundColor3 = Color3.fromRGB(32, 36, 46)
sizeLabel.Text = "Размер: 100%"
sizeLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
sizeLabel.TextSize = 12
sizeLabel.Font = Enum.Font.GothamBold
sizeLabel.Parent = mainMenu
Instance.new("UICorner", sizeLabel).CornerRadius = UDim.new(0, 9)

local sizeMinusBtn = Instance.new("TextButton")
sizeMinusBtn.Size = UDim2.new(0, 44, 0, 34)
sizeMinusBtn.Position = UDim2.new(0.58, 4, 0, 122)
sizeMinusBtn.BackgroundColor3 = Color3.fromRGB(165, 58, 66)
sizeMinusBtn.Text = "−"
sizeMinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeMinusBtn.TextSize = 18
sizeMinusBtn.Font = Enum.Font.GothamBold
sizeMinusBtn.Parent = mainMenu
Instance.new("UICorner", sizeMinusBtn).CornerRadius = UDim.new(0, 9)

local sizePlusBtn = Instance.new("TextButton")
sizePlusBtn.Size = UDim2.new(0, 44, 0, 34)
sizePlusBtn.Position = UDim2.new(0.58, 52, 0, 122)
sizePlusBtn.BackgroundColor3 = Color3.fromRGB(48, 155, 88)
sizePlusBtn.Text = "+"
sizePlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sizePlusBtn.TextSize = 16
sizePlusBtn.Font = Enum.Font.GothamBold
sizePlusBtn.Parent = mainMenu
Instance.new("UICorner", sizePlusBtn).CornerRadius = UDim.new(0, 9)

local alphaLabel = Instance.new("TextLabel")
alphaLabel.Size = UDim2.new(0.56, 0, 0, 34)
alphaLabel.Position = UDim2.new(0, 10, 0, 162)
alphaLabel.BackgroundColor3 = Color3.fromRGB(32, 36, 46)
alphaLabel.Text = "Прозрачность: 15%"
alphaLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
alphaLabel.TextSize = 12
alphaLabel.Font = Enum.Font.GothamBold
alphaLabel.Parent = mainMenu
Instance.new("UICorner", alphaLabel).CornerRadius = UDim.new(0, 9)

local alphaMinusBtn = Instance.new("TextButton")
alphaMinusBtn.Size = UDim2.new(0, 44, 0, 34)
alphaMinusBtn.Position = UDim2.new(0.58, 4, 0, 162)
alphaMinusBtn.BackgroundColor3 = Color3.fromRGB(55, 62, 78)
alphaMinusBtn.Text = "−"
alphaMinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
alphaMinusBtn.TextSize = 18
alphaMinusBtn.Font = Enum.Font.GothamBold
alphaMinusBtn.Parent = mainMenu
Instance.new("UICorner", alphaMinusBtn).CornerRadius = UDim.new(0, 9)

local alphaPlusBtn = Instance.new("TextButton")
alphaPlusBtn.Size = UDim2.new(0, 44, 0, 34)
alphaPlusBtn.Position = UDim2.new(0.58, 52, 0, 162)
alphaPlusBtn.BackgroundColor3 = Color3.fromRGB(55, 62, 78)
alphaPlusBtn.Text = "+"
alphaPlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
alphaPlusBtn.TextSize = 16
alphaPlusBtn.Font = Enum.Font.GothamBold
alphaPlusBtn.Parent = mainMenu
Instance.new("UICorner", alphaPlusBtn).CornerRadius = UDim.new(0, 9)

local resetLayoutBtn = Instance.new("TextButton")
resetLayoutBtn.Size = UDim2.new(1, -20, 0, 34)
resetLayoutBtn.Position = UDim2.new(0, 10, 0, 204)
resetLayoutBtn.BackgroundColor3 = Color3.fromRGB(68, 74, 92)
resetLayoutBtn.Text = "Сбросить вид кнопок"
resetLayoutBtn.TextColor3 = Color3.fromRGB(240, 244, 252)
resetLayoutBtn.TextSize = 12
resetLayoutBtn.Font = Enum.Font.GothamBold
resetLayoutBtn.Parent = mainMenu
Instance.new("UICorner", resetLayoutBtn).CornerRadius = UDim.new(0, 9)

local reopenMenuBtn = Instance.new("TextButton")
reopenMenuBtn.Size = UDim2.new(0, 122, 0, 36)
reopenMenuBtn.Position = UDim2.new(0, 14, 0.18, 0)
reopenMenuBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
reopenMenuBtn.BackgroundTransparency = 0.12
reopenMenuBtn.Text = "🚀 Меню ракет"
reopenMenuBtn.TextColor3 = Color3.fromRGB(245, 248, 255)
reopenMenuBtn.TextSize = 13
reopenMenuBtn.Font = Enum.Font.GothamBold
reopenMenuBtn.Visible = false
reopenMenuBtn.Parent = screenGui

Instance.new("UICorner", reopenMenuBtn).CornerRadius = UDim.new(0, 10)
local reopenStroke = Instance.new("UIStroke")
reopenStroke.Color = Color3.fromRGB(255, 255, 255)
reopenStroke.Transparency = 0.85
reopenStroke.Thickness = 1
reopenStroke.Parent = reopenMenuBtn

AttachDrag(reopenMenuBtn, reopenMenuBtn, function() return true end, function()
    mainMenu.Position = reopenMenuBtn.Position
    reopenMenuBtn.Visible = false
    mainMenu.Visible = true
end)

-- ============================================================================
-- 5. КРУГЛЫЕ КРАСИВЫЕ КНОПКИ ДЛЯ ТЕЛЕФОНА
-- ============================================================================
local actionButtons = {}
local baseCircleSize = 72

local function ApplyButtonVisuals()
    local newPx = math.floor(baseCircleSize * buttonScale)
    local sizePercent = math.floor(buttonScale * 100)
    local alphaPercent = math.floor((buttonTransparency / 0.85) * 100)

    sizeLabel.Text = "Размер: " .. tostring(sizePercent) .. "%"
    alphaLabel.Text = "Прозрачность: " .. tostring(alphaPercent) .. "%"

    for _, item in ipairs(actionButtons) do
        item.Holder.Size = UDim2.new(0, newPx, 0, newPx)
        item.Holder.BackgroundTransparency = buttonTransparency
        item.Holder.Visible = touchButtonsEnabled
        item.Minus.Visible = editModeEnabled and touchButtonsEnabled
        item.Plus.Visible = editModeEnabled and touchButtonsEnabled

        item.Button.TextSize = math.clamp(math.floor(13 * buttonScale), 10, 22)
        item.Button.TextTransparency = math.clamp(buttonTransparency * 0.45, 0, 0.55)

        if editModeEnabled then
            item.Stroke.Color = Color3.fromRGB(255, 230, 75)
            item.Stroke.Transparency = 0.05
        else
            item.Stroke.Color = item.DefaultStrokeColor
            item.Stroke.Transparency = math.clamp(buttonTransparency * 0.65, 0, 0.75)
        end
    end
end

local function CreateRoundActionButton(name, titleText, keyHint, defaultPos, baseColor, strokeColor, callback)
    local holder = Instance.new("Frame")
    holder.Name = name
    holder.Size = UDim2.new(0, baseCircleSize, 0, baseCircleSize)
    holder.Position = defaultPos
    holder.BackgroundColor3 = baseColor
    holder.BackgroundTransparency = buttonTransparency
    holder.BorderSizePixel = 0
    holder.Parent = screenGui

    Instance.new("UICorner", holder).CornerRadius = UDim.new(1, 0)

    local stroke = Instance.new("UIStroke")
    stroke.Color = strokeColor
    stroke.Thickness = 2.5
    stroke.Transparency = math.clamp(buttonTransparency * 0.6, 0, 0.7)
    stroke.Parent = holder

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 195, 215))
    })
    grad.Rotation = 90
    grad.Parent = holder

    local btn = Instance.new("TextButton")
    btn.Name = "Trigger"
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = titleText .. "\n" .. keyHint
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Parent = holder

    AttachDrag(btn, holder, function()
        return editModeEnabled
    end, function()
        if not editModeEnabled then
            callback()
        end
    end)

    local minusBtn = Instance.new("TextButton")
    minusBtn.Name = "Minus"
    minusBtn.Size = UDim2.new(0, 26, 0, 26)
    minusBtn.Position = UDim2.new(0, -6, 0, -8)
    minusBtn.BackgroundColor3 = Color3.fromRGB(205, 55, 65)
    minusBtn.Text = "−"
    minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minusBtn.TextSize = 17
    minusBtn.Font = Enum.Font.GothamBold
    minusBtn.Visible = false
    minusBtn.ZIndex = 6
    minusBtn.Parent = holder
    Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(1, 0)

    local plusBtn = Instance.new("TextButton")
    plusBtn.Name = "Plus"
    plusBtn.Size = UDim2.new(0, 26, 0, 26)
    plusBtn.Position = UDim2.new(1, -20, 0, -8)
    plusBtn.BackgroundColor3 = Color3.fromRGB(48, 175, 95)
    plusBtn.Text = "+"
    plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    plusBtn.TextSize = 16
    plusBtn.Font = Enum.Font.GothamBold
    plusBtn.Visible = false
    plusBtn.ZIndex = 6
    plusBtn.Parent = holder
    Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(1, 0)

    minusBtn.MouseButton1Click:Connect(function()
        buttonScale = math.clamp(buttonScale - 0.15, minScale, maxScale)
        ApplyButtonVisuals()
    end)

    plusBtn.MouseButton1Click:Connect(function()
        buttonScale = math.clamp(buttonScale + 0.15, minScale, maxScale)
        ApplyButtonVisuals()
    end)

    table.insert(actionButtons, {
        Holder = holder,
        Button = btn,
        Stroke = stroke,
        Minus = minusBtn,
        Plus = plusBtn,
        DefaultPos = defaultPos,
        DefaultStrokeColor = strokeColor
    })
end

CreateRoundActionButton(
    "GrabRoundBtn",
    "ЗАХВАТ",
    "[V]",
    UDim2.new(1, -242, 1, -98),
    Color3.fromRGB(32, 95, 165),
    Color3.fromRGB(115, 205, 255),
    ActionGrabRocket
)

CreateRoundActionButton(
    "FireRoundBtn",
    "ОГОНЬ",
    "[B]",
    UDim2.new(1, -162, 1, -154),
    Color3.fromRGB(175, 92, 28),
    Color3.fromRGB(255, 185, 85),
    ActionNormalFire
)

CreateRoundActionButton(
    "HomingRoundBtn",
    "НАВОДКА",
    "[N]",
    UDim2.new(1, -86, 1, -98),
    Color3.fromRGB(165, 34, 52),
    Color3.fromRGB(255, 105, 125),
    ActionHomingFire
)

-- ============================================================================
-- 6. ОБРАБОТЧИКИ МЕНЮ И РЕДАКТОРА
-- ============================================================================
local function RefreshMenuState()
    if touchButtonsEnabled then
        toggleBtnsBtn.Text = "Кнопки на экране: ВКЛ"
        toggleBtnsBtn.BackgroundColor3 = Color3.fromRGB(46, 155, 86)
    else
        toggleBtnsBtn.Text = "Кнопки на экране: ВЫКЛ"
        toggleBtnsBtn.BackgroundColor3 = Color3.fromRGB(95, 102, 118)
    end

    if editModeEnabled then
        editModeBtn.Text = "Редактор кнопок: ВКЛ (тяни)"
        editModeBtn.BackgroundColor3 = Color3.fromRGB(215, 155, 35)
    else
        editModeBtn.Text = "Редактор кнопок: ВЫКЛ"
        editModeBtn.BackgroundColor3 = Color3.fromRGB(52, 98, 215)
    end

    ApplyButtonVisuals()
end

toggleBtnsBtn.MouseButton1Click:Connect(function()
    touchButtonsEnabled = not touchButtonsEnabled
    if not touchButtonsEnabled then
        editModeEnabled = false
    end
    RefreshMenuState()
end)

editModeBtn.MouseButton1Click:Connect(function()
    if not touchButtonsEnabled then
        touchButtonsEnabled = true
    end
    editModeEnabled = not editModeEnabled
    RefreshMenuState()
end)

sizeMinusBtn.MouseButton1Click:Connect(function()
    buttonScale = math.clamp(buttonScale - 0.15, minScale, maxScale)
    ApplyButtonVisuals()
end)

sizePlusBtn.MouseButton1Click:Connect(function()
    buttonScale = math.clamp(buttonScale + 0.15, minScale, maxScale)
    ApplyButtonVisuals()
end)

alphaMinusBtn.MouseButton1Click:Connect(function()
    buttonTransparency = math.clamp(buttonTransparency - 0.12, 0.0, 0.85)
    ApplyButtonVisuals()
end)

alphaPlusBtn.MouseButton1Click:Connect(function()
    buttonTransparency = math.clamp(buttonTransparency + 0.12, 0.0, 0.85)
    ApplyButtonVisuals()
end)

resetLayoutBtn.MouseButton1Click:Connect(function()
    buttonScale = 1.0
    buttonTransparency = 0.15
    for _, item in ipairs(actionButtons) do
        item.Holder.Position = item.DefaultPos
    end
    ApplyButtonVisuals()
end)

hideMenuBtn.MouseButton1Click:Connect(function()
    reopenMenuBtn.Position = mainMenu.Position
    mainMenu.Visible = false
    reopenMenuBtn.Visible = true
end)

local renderConnection
local inputConnection

local function DestroyAllCompletely()
    if isDestroyed then return end
    isDestroyed = true

    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end
    for _, conn in ipairs(activeConnections) do
        if conn then
            conn:Disconnect()
        end
    end
    table.clear(activeConnections)

    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end

    table.clear(rockets)
    table.clear(homingMissiles)
    print("🧹 Скрипт ракет и меню полностью удалены!")
end

env.FtapRocketCleanup = DestroyAllCompletely
closeAllBtn.MouseButton1Click:Connect(DestroyAllCompletely)

RefreshMenuState()

-- ============================================================================
-- 7. КЛАВИШИ НА ПК (V, B, N)
-- ============================================================================
inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or isDestroyed then return end

    if input.KeyCode == Enum.KeyCode.V then
        ActionGrabRocket()
    elseif input.KeyCode == Enum.KeyCode.B then
        ActionNormalFire()
    elseif input.KeyCode == Enum.KeyCode.N then
        ActionHomingFire()
    end
end)

-- ============================================================================
-- 8. ГЛАВНЫЙ ЦИКЛ: ПЕРЕТАСКИВАНИЕ, УДЕРЖАНИЕ И ПОЛЕТ РАКЕТ
-- ============================================================================
renderConnection = RunService.RenderStepped:Connect(function()
    if isDestroyed then return end

    -- Обновляем перетаскивание меню и кнопок
    for _, ctrl in ipairs(dragControllers) do
        ctrl.Update()
    end

    menuTitle.Text = "🚀 Ракеты • Слоты: " .. tostring(#rockets) .. "/" .. tostring(maxSlots)
    local rootPart = getLocalRootPart()

    if rootPart then
        for i = #rockets, 1, -1 do
            local rocket = rockets[i]
            if rocket and rocket.Parent then
                for _, part in ipairs(rocket:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end

                local xOffset = (i == 1) and -4.5 or 4.5
                local offsetPos = Vector3.new(xOffset, -0.5, -1)
                local targetCFrame = camera.CFrame * CFrame.new(offsetPos) * CFrame.Angles(-math.rad(90), 0, 0)

                if rocket:IsA("Model") then
                    rocket:PivotTo(targetCFrame)
                    if rocket.PrimaryPart then
                        rocket.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        rocket.PrimaryPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                else
                    rocket.CFrame = targetCFrame
                    rocket.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    rocket.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            else
                table.remove(rockets, i)
            end
        end
    end

    for i = #homingMissiles, 1, -1 do
        local data = homingMissiles[i]
        local rocket = data.rocket
        local target = data.target

        if rocket and rocket.Parent then
            local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
            local currentPos = rocket:IsA("Model") and rocket:GetPivot().Position or rocket.Position

            if targetRoot then
                local targetPos = targetRoot.Position
                local direction = (targetPos - currentPos).Unit

                if rocket:IsA("Model") then
                    if rocket.PrimaryPart then
                        rocket.PrimaryPart.AssemblyLinearVelocity = direction * data.speed
                    else
                        for _, p in ipairs(rocket:GetDescendants()) do
                            if p:IsA("BasePart") then
                                p.AssemblyLinearVelocity = direction * data.speed
                            end
                        end
                    end
                    local lookCF = CFrame.new(currentPos, targetPos) * CFrame.Angles(-math.rad(90), 0, 0)
                    rocket:PivotTo(lookCF)
                else
                    rocket.AssemblyLinearVelocity = direction * data.speed
                    rocket.CFrame = CFrame.new(currentPos, targetPos) * CFrame.Angles(-math.rad(90), 0, 0)
                end
            else
                local forwardDir = data.initialDir
                if rocket:IsA("Model") then
                    if rocket.PrimaryPart then
                        rocket.PrimaryPart.AssemblyLinearVelocity = forwardDir * data.speed
                    end
                    rocket:PivotTo(rocket:GetPivot() + (forwardDir * (data.speed * 0.016)))
                else
                    rocket.AssemblyLinearVelocity = forwardDir * data.speed
                end
            end
        else
            table.remove(homingMissiles, i)
        end
    end
end)

print("🚀 Перетаскивание кнопок исправлено через RenderStepped + GetMouseLocation()!")
