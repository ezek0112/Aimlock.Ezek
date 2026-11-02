-- EZEK v18.0 - APENAS LOCK E ESP (Câmera Fixa, Sem Extras)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Variáveis
local ativo, alvo, espAtivo = false, nil, false
local gyro = nil
local FOV_GRAUS = 120
local filtros = {players=true, dummies=true, monstros=true, objetos=true}
local espEl = {}

-- Funções Base
local function getVida(m)
    local h = m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildWhichIsA("Humanoid",true)
    if h then return h.Health, h.MaxHealth end
    local hp = m:GetAttribute("Health") or m:GetAttribute("HP") or m:GetAttribute("Vida")
    if type(hp) == "number" then return hp, 100 end
    return nil,nil
end

local function temVida(m) local hp = getVida(m) return hp and hp > 0 end

local function pegarParte(m)
    if not m then return nil end
    return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
end

local function getTipo(m)
    if Players:GetPlayerFromCharacter(m) then return "players" end
    local n = string.lower(m.Name)
    if n:find("dummy") or n:find("training") then return "dummies" end
    return "monstros"
end

local function getTodos()
    local lista = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and temVida(p.Character) then table.insert(lista, p.Character) end
    end
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Model") and v ~= player.Character and temVida(v) and pegarParte(v) then table.insert(lista, v) end
    end
    return lista
end

-- LOCK
local function acharAlvo()
    local melhor, angMin = nil, math.rad(FOV_GRAUS)
    local cp = camera.CFrame.Position
    local cl = camera.CFrame.LookVector
    for _, m in pairs(getTodos()) do
        if filtros[getTipo(m)] and temVida(m) then
            local p = pegarParte(m)
            if p then
                local dist = (p.Position - cp).Magnitude
                if dist > 2 then
                    local ang = math.acos(math.clamp(cl:Dot((p.Position - cp).Unit), -1, 1))
                    if ang < angMin then angMin = ang; melhor = m end
                end
            end
        end
    end
    return melhor
end

local function pararLock()
    if not ativo then return end
    ativo = false; alvo = nil
    RunService:UnbindFromRenderStep("EZEK_CAM")
    if gyro then gyro:Destroy(); gyro = nil end
    local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if h then h.AutoRotate = true; h.CameraOffset = Vector3.new(0,0,0) end
    camera.CameraType = Enum.CameraType.Custom
    if h then camera.CameraSubject = h end
end

local function atualizarLock()
    if not ativo or not alvo or not alvo.Parent or not temVida(alvo) then pararLock() return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local p = pegarParte(alvo)
    if not root or not h or not p then pararLock() return end

    if gyro then
        local targetPos = Vector3.new(p.Position.X, root.Position.Y, p.Position.Z)
        if (targetPos - root.Position).Magnitude > 0.1 then gyro.CFrame = CFrame.lookAt(root.Position, targetPos) end
    end

    h.AutoRotate = false
    if camera.CameraType ~= Enum.CameraType.Custom then camera.CameraType = Enum.CameraType.Custom end
    if camera.CameraSubject ~= h then camera.CameraSubject = h end

    local cabeca = alvo:FindFirstChild("Head")
    local peito = alvo:FindFirstChild("UpperTorso") or alvo:FindFirstChild("Torso")
    local miraPos = p.Position

    if cabeca and peito then
        if camera.CFrame.Position.Y > cabeca.Position.Y then miraPos = cabeca.Position else miraPos = peito.Position end
    elseif cabeca then miraPos = cabeca.Position
    elseif peito then miraPos = peito.Position end

    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, miraPos)
end

local function toggleLock()
    if ativo then pararLock() else
        local t = acharAlvo()
        if not t then return end
        alvo = t; ativo = true
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            if gyro then gyro:Destroy() end
            gyro = Instance.new("BodyGyro", root)
            gyro.P = 100000; gyro.D = 1000; gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        end
        RunService:UnbindFromRenderStep("EZEK_CAM")
        RunService:BindToRenderStep("EZEK_CAM", Enum.RenderPriority.Camera.Value + 1, atualizarLock)
    end
end

-- ESP
local espGui = Instance.new("ScreenGui", player.PlayerGui)
espGui.Name = "EZEK_ESP_Hub"; espGui.ResetOnSpawn = false; espGui.IgnoreGuiInset = true

local function criarESP(m)
    if espEl[m] then return end
    local cont = Instance.new("Frame", espGui); cont.BackgroundTransparency = 1
    local box = Instance.new("Frame", cont); box.BackgroundTransparency = 1
    local st = Instance.new("UIStroke", box); st.Color = Color3.fromRGB(0, 255, 255); st.Thickness = 1.5
    local nm = Instance.new("TextLabel", cont); nm.BackgroundTransparency = 1; nm.Font = Enum.Font.GothamBold; nm.TextSize = 11; nm.TextColor3 = st.Color; nm.TextStrokeTransparency = 0; nm.Text = m.Name
    local hp = Instance.new("TextLabel", cont); hp.BackgroundTransparency = 1; hp.Font = Enum.Font.GothamBold; hp.TextSize = 10; hp.TextColor3 = Color3.fromRGB(0,255,0); hp.TextStrokeTransparency = 0
    espEl[m] = {cont=cont, box=box, st=st, nm=nm, hp=hp}
end

local function toggleESP()
    espAtivo = not espAtivo
    if not espAtivo then 
        for _, d in pairs(espEl) do d.cont:Destroy() end
        espEl = {}
    end
end

RunService.RenderStepped:Connect(function()
    if not espAtivo then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    for _, m in pairs(getTodos()) do
        if filtros[getTipo(m)] and temVida(m) then
            local p = pegarParte(m)
            if p then
                if not espEl[m] then criarESP(m) end
                local d = espEl[m]
                local top = camera:WorldToViewportPoint(p.Position + Vector3.new(0,2.5,0))
                local bot = camera:WorldToViewportPoint(p.Position - Vector3.new(0,2.5,0))
                
                if top.Z > 0 and bot.Z > 0 then
                    local alt = math.abs(top.Y - bot.Y)
                    if alt > 5 then
                        local lar = alt * 0.55
                        local cx = (top.X + bot.X) / 2
                        local cy = (top.Y + bot.Y) / 2
                        d.cont.Visible = true
                        d.box.Size = UDim2.new(0, lar, 0, alt)
                        d.box.Position = UDim2.new(0, cx - lar/2, 0, cy - alt/2)
                        d.nm.Position = UDim2.new(0, cx - 75, 0, cy - alt/2 - 16); d.nm.Size = UDim2.new(0, 150, 0, 14)
                        d.hp.Position = UDim2.new(0, cx - 75, 0, cy + alt/2 + 2); d.hp.Size = UDim2.new(0, 150, 0, 14)
                        local hVal, hMax = getVida(m)
                        if hVal then d.hp.Text = string.format("%d/%d | %dm", math.floor(hVal), math.floor(hMax or 100), math.floor((p.Position - root.Position).Magnitude)) end
                    else d.cont.Visible = false end
                else d.cont.Visible = false end
            end
        end
    end
end)

-- UI (SÓ LOCK E ESP)
local sg = Instance.new("ScreenGui", player.PlayerGui)
sg.Name = "EZEK_HUB_v18"; sg.ResetOnSpawn = false
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 130)
main.Position = UDim2.new(0, 20, 0.5, -65)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
main.BorderSizePixel = 0
main.Active = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local topBar = Instance.new("Frame", main)
topBar.Size = UDim2.new(1, 0, 0, 30); topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.new(1, 0, 1, 0); title.BackgroundTransparency = 1
title.Text = "EZEK v18.0"; title.TextColor3 = Color3.fromRGB(0, 255, 255); title.Font = Enum.Font.Code; title.TextSize = 14

local closeBtn = Instance.new("TextButton", topBar)
closeBtn.Size = UDim2.new(0, 30, 1, 0); closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- Arrastar
local dragging, dragInput, dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local function createToggle(text, yPos, callback)
    local state = false
    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(1, -20, 0, 35)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.Text = text .. " [OFF]"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.Code
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = text .. (state and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(45, 45, 45)
        callback(state)
    end)
end

createToggle("🔒 LOCK (AIMBOT)", 40, function(state) if state ~= ativo then toggleLock() end end)
createToggle("👁️ ESP COMPLETO", 80, function(state) if state ~= espAtivo then toggleESP() end end)

-- Teclas de Atalho
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.P then toggleLock() end
    if input.KeyCode == Enum.KeyCode.O then toggleESP() end
end)

print("⚡ EZEK v18.0 Carregado! Só Lock e ESP.")