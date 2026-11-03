-- EZEK v20.2 - COMPLETO + MINIMIZAR
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Limpa lixo
for _, obj in pairs(player:WaitForChild("PlayerGui"):GetChildren()) do
    if obj:IsA("ScreenGui") and (string.find(obj.Name, "EZEK") or string.find(obj.Name, "Aimlock")) then
        obj:Destroy()
    end
end
pcall(function() RunService:UnbindFromRenderStep("EZEK_CAM") end)

local VERSAO = "v20.2"
local FOV_GRAUS = 120
local ativo, alvo, espAtivo = false, nil, false
local gyro = nil
local espEl = {}
local inclinacaoAtual = 2.5 

local filtros = {players=true, dummies=true, monstros=true, objetos=true}

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
    if m:FindFirstChildOfClass("Humanoid") or temVida(m) then return "monstros" end
    return "objetos"
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

    miraPos = miraPos + Vector3.new(0, inclinacaoAtual, 0)
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

-- PREVIEW (Quadrado Verde)
local espGui = Instance.new("ScreenGui", player.PlayerGui)
espGui.Name = "EZEK_ESP_Hub"; espGui.ResetOnSpawn = false; espGui.IgnoreGuiInset = true

local previewEl = nil
local previewAlvo = nil

local function limparPreview()
    if previewEl and previewEl.cont then previewEl.cont:Destroy() end
    previewEl = nil; previewAlvo = nil
end

local function criarPreview(m)
    limparPreview()
    local cont = Instance.new("Frame", espGui); cont.BackgroundTransparency = 1; cont.Visible = false
    local box = Instance.new("Frame", cont); box.BackgroundTransparency = 1
    local st = Instance.new("UIStroke", box); st.Color = Color3.fromRGB(0, 255, 0); st.Thickness = 2
    previewEl = {cont = cont, box = box}; previewAlvo = m
end

RunService.RenderStepped:Connect(function()
    if ativo then if previewEl then limparPreview() end return end
    local t = acharAlvo()
    if t ~= previewAlvo then
        if t then criarPreview(t) else limparPreview() end
    end
    if previewEl and previewAlvo and previewAlvo.Parent and previewAlvo ~= player.Character then
        local p = pegarParte(previewAlvo)
        if p then
            local top = camera:WorldToViewportPoint(p.Position + Vector3.new(0,2.5,0))
            local bot = camera:WorldToViewportPoint(p.Position - Vector3.new(0,2.5,0))
            if top.Z > 0 and bot.Z > 0 then
                local alt = math.abs(top.Y - bot.Y)
                if alt > 5 then
                    local lar = alt * 0.55; local cx = (top.X + bot.X) / 2; local cy = (top.Y + bot.Y) / 2
                    previewEl.cont.Visible = true
                    previewEl.box.Size = UDim2.new(0, lar, 0, alt)
                    previewEl.box.Position = UDim2.new(0, cx - lar/2, 0, cy - alt/2)
                else previewEl.cont.Visible = false end
            else previewEl.cont.Visible = false end
        end
    end
end)

-- ESP
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
                if not espEl[m] then
                    local cont = Instance.new("Frame", espGui); cont.BackgroundTransparency = 1
                    local box = Instance.new("Frame", cont); box.BackgroundTransparency = 1
                    local st = Instance.new("UIStroke", box); st.Color = Color3.fromRGB(0, 255, 255)
                    local nm = Instance.new("TextLabel", cont); nm.BackgroundTransparency = 1; nm.TextSize = 11; nm.TextColor3 = st.Color; nm.TextStrokeTransparency = 0; nm.Text = m.Name
                    local hp = Instance.new("TextLabel", cont); hp.BackgroundTransparency = 1; hp.TextSize = 10; hp.TextColor3 = Color3.fromRGB(0,255,0); hp.TextStrokeTransparency = 0
                    espEl[m] = {cont=cont, box=box, nm=nm, hp=hp}
                end
                local d = espEl[m]
                local top = camera:WorldToViewportPoint(p.Position + Vector3.new(0,2.5,0))
                local bot = camera:WorldToViewportPoint(p.Position - Vector3.new(0,2.5,0))
                if top.Z > 0 and bot.Z > 0 then
                    local alt = math.abs(top.Y - bot.Y)
                    if alt > 5 then
                        local lar = alt * 0.55; local cx = (top.X + bot.X) / 2; local cy = (top.Y + bot.Y) / 2
                        d.cont.Visible = true
                        d.box.Size = UDim2.new(0, lar, 0, alt); d.box.Position = UDim2.new(0, cx - lar/2, 0, cy - alt/2)
                        d.nm.Position = UDim2.new(0, cx - 75, 0, cy - alt/2 - 16); d.nm.Size = UDim2.new(0, 150, 0, 14)
                        d.hp.Position = UDim2.new(0, cx - 75, 0, cy + alt/2 + 2); d.hp.Size = UDim2.new(0, 150, 0, 14)
                        local hVal, hMax = getVida(m)
                        if hVal then d.hp.Text = string.format("%d/%d", math.floor(hVal), math.floor(hMax or 100)) end
                    else d.cont.Visible = false end
                else d.cont.Visible = false end
            else
                if espEl[m] then espEl[m].cont.Visible = false end
            end
        else
            if espEl[m] then espEl[m].cont.Visible = false end
        end
    end
end)

-- ===================== UI COM MINIMIZAR =====================
local sg = Instance.new("ScreenGui", player.PlayerGui)
sg.Name = "EZEK_GUI_v20"; sg.ResetOnSpawn = false
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 330); main.Position = UDim2.new(0, 20, 0.5, -165)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30); main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

-- Barra de Título
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 36); title.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
title.Text = "🎯 EZEK " .. VERSAO; title.TextColor3 = Color3.fromRGB(0, 255, 255); title.Font = Enum.Font.GothamBold; title.TextSize = 14
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

-- Botão Fechar (X)
local closeBtn = Instance.new("TextButton", title)
closeBtn.Size = UDim2.new(0, 30, 1, 0); closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- 🔥 Botão Minimizar (-)
local minBtn = Instance.new("TextButton", title)
minBtn.Size = UDim2.new(0, 30, 1, 0); minBtn.Position = UDim2.new(1, -60, 0, 0)
minBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50); minBtn.Text = "-"; minBtn.TextColor3 = Color3.new(1,1,1)
minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 16
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 8)

-- 🔥 Botão Flutuante pra Reabrir
local floatingBtn = Instance.new("TextButton", sg)
floatingBtn.Size = UDim2.new(0, 44, 0, 44); floatingBtn.Position = UDim2.new(0, 20, 0, 100)
floatingBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30); floatingBtn.Text = "🎯"; floatingBtn.TextSize = 20
floatingBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
floatingBtn.Visible = false
Instance.new("UICorner", floatingBtn).CornerRadius = UDim.new(1,0)

minBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    floatingBtn.Visible = true
end)

floatingBtn.MouseButton1Click:Connect(function()
    main.Visible = true
    floatingBtn.Visible = false
end)

-- Arrastar Menu Principal
local dragging, dragStart, startPos
title.InputBegan:Connect(function(input)
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

-- Arrastar Botão Flutuante
local dragF, dragStartF, startPosF
floatingBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragF = true; dragStartF = input.Position; startPosF = floatingBtn.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragF = false end end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragF and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartF
        floatingBtn.Position = UDim2.new(startPosF.X.Scale, startPosF.X.Offset + delta.X, startPosF.Y.Scale, startPosF.Y.Offset + delta.Y)
    end
end)

local btnLock = Instance.new("TextButton", main)
btnLock.Size = UDim2.new(1, -20, 0, 35); btnLock.Position = UDim2.new(0, 10, 0, 46)
btnLock.BackgroundColor3 = Color3.fromRGB(40, 40, 50); btnLock.Text = "🔓 LOCK: OFF"
btnLock.TextColor3 = Color3.new(1,1,1); btnLock.Font = Enum.Font.GothamBold; btnLock.TextSize = 12
Instance.new("UICorner", btnLock).CornerRadius = UDim.new(0, 6)

local btnEsp = Instance.new("TextButton", main)
btnEsp.Size = UDim2.new(1, -20, 0, 35); btnEsp.Position = UDim2.new(0, 10, 0, 91)
btnEsp.BackgroundColor3 = Color3.fromRGB(40, 40, 50); btnEsp.Text = "👁️ ESP: OFF"
btnEsp.TextColor3 = Color3.new(1,1,1); btnEsp.Font = Enum.Font.GothamBold; btnEsp.TextSize = 12
Instance.new("UICorner", btnEsp).CornerRadius = UDim.new(0, 6)

local btnCam = Instance.new("TextButton", main)
btnCam.Size = UDim2.new(1, -20, 0, 35); btnCam.Position = UDim2.new(0, 10, 0, 136)
btnCam.BackgroundColor3 = Color3.fromRGB(40, 40, 50); btnCam.Text = "📷 INCLINAÇÃO: 2.5"
btnCam.TextColor3 = Color3.new(1,1,1); btnCam.Font = Enum.Font.GothamBold; btnCam.TextSize = 12
Instance.new("UICorner", btnCam).CornerRadius = UDim.new(0, 6)

local fTitle = Instance.new("TextLabel", main)
fTitle.Size = UDim2.new(1, -20, 0, 20); fTitle.Position = UDim2.new(0, 10, 0, 180)
fTitle.BackgroundTransparency = 1; fTitle.Text = "Filtros:"; fTitle.TextColor3 = Color3.fromRGB(150, 150, 150)
fTitle.Font = Enum.Font.GothamMedium; fTitle.TextSize = 11; fTitle.TextXAlignment = Enum.TextXAlignment.Left

local function mkCheckInContainer(txt, chave, y)
    local cf = Instance.new("Frame", main)
    cf.Size = UDim2.new(1, -20, 0, 24); cf.Position = UDim2.new(0, 10, 0, 200 + y); cf.BackgroundTransparency = 1
    
    local box = Instance.new("TextButton", cf)
    box.Size = UDim2.new(0, 20, 0, 20); box.Position = UDim2.new(0, 0, 0, 2)
    box.BackgroundColor3 = filtros[chave] and Color3.fromRGB(0, 170, 90) or Color3.fromRGB(60, 60, 75)
    box.Text = filtros[chave] and "✓" or ""; box.TextColor3 = Color3.new(1,1,1)
    box.Font = Enum.Font.GothamBold; box.TextSize = 12
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    
    local lb = Instance.new("TextLabel", cf)
    lb.Size = UDim2.new(1, -26, 1, 0); lb.Position = UDim2.new(0, 26, 0, 0)
    lb.BackgroundTransparency = 1; lb.Text = txt; lb.TextColor3 = Color3.new(1,1,1)
    lb.Font = Enum.Font.GothamMedium; lb.TextSize = 12; lb.TextXAlignment = Enum.TextXAlignment.Left

    box.MouseButton1Click:Connect(function()
        filtros[chave] = not filtros[chave]
        box.BackgroundColor3 = filtros[chave] and Color3.fromRGB(0, 170, 90) or Color3.fromRGB(60, 60, 75)
        box.Text = filtros[chave] and "✓" or ""
    end)
    lb.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then box:Activate() end end)
end

mkCheckInContainer("👤 Players", "players", 0)
mkCheckInContainer("🎯 Dummies", "dummies", 25)
mkCheckInContainer("👹 Monstros", "monstros", 50)
mkCheckInContainer("📦 Objetos", "objetos", 75)

btnLock.MouseButton1Click:Connect(function()
    toggleLock()
    btnLock.Text = ativo and "🔒 LOCK: ON" or "🔓 LOCK: OFF"
    btnLock.BackgroundColor3 = ativo and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(40, 40, 50)
end)

btnEsp.MouseButton1Click:Connect(function()
    toggleESP()
    btnEsp.Text = espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF"
    btnEsp.BackgroundColor3 = espAtivo and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(40, 40, 50)
end)

btnCam.MouseButton1Click:Connect(function()
    if inclinacaoAtual == 2.5 then inclinacaoAtual = 4.0
    elseif inclinacaoAtual == 4.0 then inclinacaoAtual = 1.0
    else inclinacaoAtual = 2.5 end
    btnCam.Text = "📷 INCLINAÇÃO: " .. tostring(inclinacaoAtual)
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.P then btnLock:Activate() end
    if input.KeyCode == Enum.KeyCode.O then btnEsp:Activate() end
end)

print("⚡ EZEK " .. VERSAO .. " Carregado! Minimizar Ativado.")