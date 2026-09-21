-- AIMLOCK DO EZEK v18.7 - WELDS DE BOSS SEM MATAR ACESSÓRIOS
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local DISTANCIA_CAMERA = 12
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============ DESATIVA AIMASSIST E COMBAT DO PS ============
task.spawn(function()
    while task.wait(0.2) do
        pcall(function()
            local CU = player.PlayerScripts:FindFirstChild("CU")
            if not CU then return end
            local aa = CU:FindFirstChild("AimAssist")
            if aa and aa:IsA("LocalScript") then aa.Disabled = true end
            local cb = CU:FindFirstChild("Combat")
            if cb then
                if cb:IsA("LocalScript") then cb.Disabled = true end
                local mc = cb:FindFirstChild("Main_Combat_Script_Client")
                if mc and mc:IsA("LocalScript") then mc.Disabled = true end
            end
        end)
    end
end)

-- ============ ESTADO ============
local locked = false
local target = nil
local espEnabled = false
local espHighlights = {}
local espLabels = {}
local espConnection = nil
local hpBarAlvo = nil
local cameraTypeAntigo = nil
local cameraModeAntigo = nil
local escalaW = 1.0
local escalaH = 1.0
local filtros = { players = true, dummies = true, monstros = true }
local ultimoHitTime = 0
local vidaAnterior = 100
local HIT_JANELA = 0.6
local STUN_DURACAO = 0.4
local espUltimoScan = 0
local espUltimaLabel = 0
local DEVE_RESETAR_ATE = 0

-- 🔥 DEBUG ANGULO
local debugAngulo = true

-- 🔥 Expõe pra debug externo
_G.EZEK_LOCKED = false
_G.EZEK_TARGET = nil

-- ============ DETECÇÃO VIA Last_Stunned ============
local function estaStunado()
    local ultimoStun = player:GetAttribute("Last_Stunned")
    if not ultimoStun then return false end
    local dif = workspace:GetServerTimeNow() - ultimoStun
    return dif >= 0 and dif < STUN_DURACAO
end

-- ============ MATA MOVERS ============
local moverAges = {}

local function matarMovers()
    local char = player.Character
    if not char then return end
    local agora = tick()
    local vistos = {}
    
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("AlignPosition") or obj:IsA("AlignOrientation")
           or obj:IsA("BodyGyro") or obj:IsA("BodyPosition")
           or obj:IsA("BodyVelocity") or obj:IsA("BodyAngularVelocity")
           or obj:IsA("LinearVelocity") or obj:IsA("AngularVelocity") then
            
            vistos[obj] = true
            
            if not moverAges[obj] then
                moverAges[obj] = agora
            end
            
            local idade = agora - moverAges[obj]
            
            if obj:IsA("LinearVelocity") or obj:IsA("AngularVelocity") then
                if idade > 0.5 then
                    pcall(function()
                        if obj.Enabled then obj.Enabled = false end
                        obj:Destroy()
                    end)
                    moverAges[obj] = nil
                end
            else
                pcall(function() obj:Destroy() end)
                moverAges[obj] = nil
            end
        end
    end
    
    for obj, _ in pairs(moverAges) do
        if not vistos[obj] or not obj.Parent then
            moverAges[obj] = nil
        end
    end
end

task.spawn(function() while task.wait(0.1) do pcall(matarMovers) end end)

-- ══════════════════════════════════════════════════
-- 🔥 MATA WELDS DE BOSS (v18.7 - filtro por nome, preserva acessórios)
-- ══════════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            local char = player.Character
            if not char then return end
            
            -- Partes do corpo (R6 e R15)
            local partesCorpo = {
                ["HumanoidRootPart"] = true,
                ["Torso"] = true, ["UpperTorso"] = true, ["LowerTorso"] = true,
                ["Head"] = true,
                ["Left Arm"] = true, ["Right Arm"] = true,
                ["Left Leg"] = true, ["Right Leg"] = true,
                ["LeftUpperArm"] = true, ["LeftLowerArm"] = true, ["LeftHand"] = true,
                ["RightUpperArm"] = true, ["RightLowerArm"] = true, ["RightHand"] = true,
                ["LeftUpperLeg"] = true, ["LeftLowerLeg"] = true, ["LeftFoot"] = true,
                ["RightUpperLeg"] = true, ["RightLowerLeg"] = true, ["RightFoot"] = true,
            }
            
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("Weld") or obj:IsA("WeldConstraint") then
                    local parent = obj.Parent
                    local parentNome = parent.Name
                    
                    -- Só age se NÃO é parte do corpo e NÃO é filho direto do char
                    if not partesCorpo[parentNome] and parent ~= char then
                        -- 🔥 Filtra por NOME suspeito (Welds de boss)
                        local nome = string.lower(obj.Name)
                        if nome:find("tang") or nome:find("boss") or nome:find("hit")
                           or nome:find("stun") or nome:find("root") or nome:find("knock")
                           or nome:find("pull") or nome:find("grab") or nome:find("trap") then
                            pcall(function()
                                obj:Destroy()
                            end)
                        end
                    end
                end
            end
        end)
    end
end)

-- ══════════════════════════════════════════════════
-- 🔥 FORÇA ATUALIZAÇÃO CONSTANTE DA DIREÇÃO
-- ══════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local cam = Workspace.CurrentCamera
    if not hum or not cam then return end
    
    if locked then
        local camLook = cam.CFrame.LookVector
        local flat = Vector3.new(camLook.X, 0, camLook.Z)
        if flat.Magnitude > 0.01 then
            flat = flat.Unit
            pcall(function()
                hum.MoveDirection = flat + Vector3.new(0.001, 0, 0.001)
            end)
        end
    end
end)

-- ══════════════════════════════════════════════════
-- 🔥 AUTO-OFF DO LOCK NA MORTE
-- ══════════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.1) do
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if hum and hum.Health <= 0 and locked then
            pcall(function()
                unlockTarget()
            end)
            print("💀 Morreu! Lock desligado automaticamente")
        end
        
        if locked and (not target or not target.Parent) then
            pcall(function()
                unlockTarget()
            end)
            print("🎯 Target sumiu! Lock desligado")
        end
    end
end)

-- ============ MONITOR DE HIT ============
task.spawn(function()
    while task.wait(0.05) do
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then continue end
        if hum.Health < vidaAnterior - 0.5 then ultimoHitTime = tick() end
        vidaAnterior = hum.Health
        if estaStunado() then ultimoHitTime = tick() end
        if tick() - ultimoHitTime < HIT_JANELA then
            if hum.AutoRotate ~= true then hum.AutoRotate = true end
        end
    end
end)

-- ============ AUXILIARES ============
local getTipoAlvo

local function getHealth(model)
    if not model then return nil, nil end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then return hum.Health, hum.MaxHealth end
    for _, nome in ipairs({"Health","HP","health","CurrentHealth","hp"}) do
        local v = model:GetAttribute(nome)
        if v and type(v) == "number" then
            local maxV = model:GetAttribute("MaxHealth") or model:GetAttribute("MaxHP") or 100
            return v, maxV
        end
    end
    return nil, nil
end

local function getAimPart(model)
    if not model then return nil end
    return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
        or model:FindFirstChild("Root") or model.PrimaryPart
end

getTipoAlvo = function(model)
    if not model then return "monstros" end
    if Players:GetPlayerFromCharacter(model) then return "players" end
    local n = string.lower(model.Name)
    if n:find("dummy") or n:find("training") or n:find("test") or n:find("target") then
        return "dummies"
    end
    return "monstros"
end

-- ============ GUI ============
local CORES = {
    fundo = Color3.fromRGB(20,20,25), topo = Color3.fromRGB(30,30,40),
    botao = Color3.fromRGB(45,45,60), on = Color3.fromRGB(0,170,90),
    off = Color3.fromRGB(180,50,50), texto = Color3.fromRGB(240,240,240),
    textoFraco = Color3.fromRGB(160,160,170), borda = Color3.fromRGB(90,90,120),
    checkOn = Color3.fromRGB(0,170,90), checkOff = Color3.fromRGB(60,60,75),
    sliderBg = Color3.fromRGB(40,40,55), sliderFill = Color3.fromRGB(0,170,90),
    sliderKnob = Color3.fromRGB(220,220,230),
}

local sg = Instance.new("ScreenGui")
sg.Name = "AIMLOCK_EZEK_" .. tick()
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = player:WaitForChild("PlayerGui")
_G.EZEK_AIMLOCK_GUI = sg

local tamW, tamH = 240, 520
local tamanhoNormal = UDim2.new(0, tamW, 0, tamH)
local tamanhoMin = UDim2.new(0, tamW, 0, 40)

local main = Instance.new("Frame")
main.Size = tamanhoNormal
main.Position = UDim2.new(0, 20, 0, 80)
main.BackgroundColor3 = CORES.fundo
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local ms = Instance.new("UIStroke")
ms.Color = CORES.borda; ms.Thickness = 1.5; ms.Parent = main

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = CORES.topo
topBar.BorderSizePixel = 0
topBar.Parent = main
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🎯 EZEK v18.7"
title.TextColor3 = CORES.texto
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Position = UDim2.new(1, -70, 0, 5)
minBtn.BackgroundColor3 = CORES.botao
minBtn.Text = "—"; minBtn.TextColor3 = CORES.texto
minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 18
minBtn.Parent = topBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = CORES.off
closeBtn.Text = "✕"; closeBtn.TextColor3 = CORES.texto
closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 16
closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -10, 1, -50)
scroll.Position = UDim2.new(0, 5, 0, 45)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = CORES.borda
scroll.CanvasSize = UDim2.new(0, 0, 0, 560)
scroll.Parent = main

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -10, 0, 560)
content.BackgroundTransparency = 1
content.Parent = scroll

local statusFrame = Instance.new("Frame")
statusFrame.Size = UDim2.new(1, 0, 0, 60)
statusFrame.BackgroundColor3 = CORES.topo
statusFrame.BorderSizePixel = 0
statusFrame.Parent = content
Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0, 8)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 1, -12)
statusLabel.Position = UDim2.new(0, 8, 0, 6)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "🔓 Lock: OFF\n👁️ ESP: OFF"
statusLabel.TextColor3 = CORES.textoFraco
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 13
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = statusFrame

local function criarBotao(txt, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 42)
    b.Position = UDim2.new(0, 0, 0, y)
    b.BackgroundColor3 = CORES.botao
    b.Text = txt; b.TextColor3 = CORES.texto
    b.Font = Enum.Font.GothamBold; b.TextSize = 15
    b.Parent = content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local lockBtn = criarBotao("🔓 LOCK: OFF", 70)
local espBtn = criarBotao("👁️ ESP: OFF", 120)

-- 🔥 DEBUG ANGULO FRAME
local debugFrame = Instance.new("Frame")
debugFrame.Size = UDim2.new(1, 0, 0, 90)
debugFrame.Position = UDim2.new(0, 0, 0, 170)
debugFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
debugFrame.BackgroundTransparency = 0.3
debugFrame.BorderSizePixel = 0
debugFrame.Parent = content
Instance.new("UICorner", debugFrame).CornerRadius = UDim.new(0, 8)
local dbgStroke = Instance.new("UIStroke")
dbgStroke.Color = Color3.fromRGB(0, 200, 100)
dbgStroke.Thickness = 1
dbgStroke.Parent = debugFrame

local debugLabel = Instance.new("TextLabel")
debugLabel.Size = UDim2.new(1, -16, 1, -12)
debugLabel.Position = UDim2.new(0, 8, 0, 6)
debugLabel.BackgroundTransparency = 1
debugLabel.Text = "📐 DEBUG\naguardando..."
debugLabel.TextColor3 = Color3.fromRGB(0, 255, 120)
debugLabel.Font = Enum.Font.Code
debugLabel.TextSize = 11
debugLabel.TextXAlignment = Enum.TextXAlignment.Left
debugLabel.TextYAlignment = Enum.TextYAlignment.Top
debugLabel.Parent = debugFrame

-- FILTROS
local filtroFrame = Instance.new("Frame")
filtroFrame.Size = UDim2.new(1, 0, 0, 110)
filtroFrame.Position = UDim2.new(0, 0, 0, 270)
filtroFrame.BackgroundColor3 = CORES.topo
filtroFrame.BorderSizePixel = 0
filtroFrame.Parent = content
Instance.new("UICorner", filtroFrame).CornerRadius = UDim.new(0, 8)

local fTitulo = Instance.new("TextLabel")
fTitulo.Size = UDim2.new(1, -12, 0, 18)
fTitulo.Position = UDim2.new(0, 8, 0, 4)
fTitulo.BackgroundTransparency = 1
fTitulo.Text = "🎛️ Filtros do ESP"
fTitulo.TextColor3 = CORES.textoFraco
fTitulo.Font = Enum.Font.GothamBold
fTitulo.TextSize = 11
fTitulo.TextXAlignment = Enum.TextXAlignment.Left
fTitulo.Parent = filtroFrame

local function criarCheck(texto, chave, y)
    local cf = Instance.new("Frame")
    cf.Size = UDim2.new(1, -16, 0, 26)
    cf.Position = UDim2.new(0, 8, 0, y)
    cf.BackgroundTransparency = 1
    cf.Parent = filtroFrame
    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0, 22, 0, 22)
    box.Position = UDim2.new(0, 0, 0, 2)
    box.BackgroundColor3 = filtros[chave] and CORES.checkOn or CORES.checkOff
    box.Text = filtros[chave] and "✓" or ""
    box.TextColor3 = CORES.texto
    box.Font = Enum.Font.GothamBold
    box.TextSize = 14
    box.Parent = cf
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)
    local lb = Instance.new("TextLabel")
    lb.Size = UDim2.new(1, -30, 1, 0)
    lb.Position = UDim2.new(0, 30, 0, 0)
    lb.BackgroundTransparency = 1
    lb.Text = texto
    lb.TextColor3 = CORES.texto
    lb.Font = Enum.Font.GothamMedium
    lb.TextSize = 13
    lb.TextXAlignment = Enum.TextXAlignment.Left
    lb.Parent = cf
    local function toggle()
        filtros[chave] = not filtros[chave]
        box.BackgroundColor3 = filtros[chave] and CORES.checkOn or CORES.checkOff
        box.Text = filtros[chave] and "✓" or ""
        espUltimoScan = 0
    end
    box.MouseButton1Click:Connect(toggle)
    lb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then toggle() end
    end)
end

criarCheck("👤 Players", "players", 26)
criarCheck("🎯 Dummies", "dummies", 56)
criarCheck("👹 Monstros", "monstros", 86)

-- SLIDERS
local slidersFrame = Instance.new("Frame")
slidersFrame.Size = UDim2.new(1, 0, 0, 130)
slidersFrame.Position = UDim2.new(0, 0, 0, 390)
slidersFrame.BackgroundColor3 = CORES.topo
slidersFrame.BorderSizePixel = 0
slidersFrame.Parent = content
Instance.new("UICorner", slidersFrame).CornerRadius = UDim.new(0, 8)

local sTitulo = Instance.new("TextLabel")
sTitulo.Size = UDim2.new(1, -12, 0, 18)
sTitulo.Position = UDim2.new(0, 8, 0, 4)
sTitulo.BackgroundTransparency = 1
sTitulo.Text = "📐 Tamanho da UI"
sTitulo.TextColor3 = CORES.textoFraco
sTitulo.Font = Enum.Font.GothamBold
sTitulo.TextSize = 11
sTitulo.TextXAlignment = Enum.TextXAlignment.Left
sTitulo.Parent = slidersFrame

local function criarSlider(label, minV, maxV, valorInicial, y, cb)
    local linha = Instance.new("Frame")
    linha.Size = UDim2.new(1, -16, 0, 42)
    linha.Position = UDim2.new(0, 8, 0, y)
    linha.BackgroundTransparency = 1
    linha.Parent = slidersFrame
    local titulo = Instance.new("TextLabel")
    titulo.Size = UDim2.new(1, 0, 0, 14)
    titulo.BackgroundTransparency = 1
    titulo.Text = label .. ": " .. math.floor(valorInicial * 100) .. "%"
    titulo.TextColor3 = CORES.texto
    titulo.Font = Enum.Font.GothamMedium
    titulo.TextSize = 12
    titulo.TextXAlignment = Enum.TextXAlignment.Left
    titulo.Parent = linha
    local trilha = Instance.new("Frame")
    trilha.Size = UDim2.new(1, 0, 0, 12)
    trilha.Position = UDim2.new(0, 0, 0, 22)
    trilha.BackgroundColor3 = CORES.sliderBg
    trilha.BorderSizePixel = 0
    trilha.Parent = linha
    Instance.new("UICorner", trilha).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((valorInicial - minV) / (maxV - minV), 0, 1, 0)
    fill.BackgroundColor3 = CORES.sliderFill
    fill.BorderSizePixel = 0
    fill.Parent = trilha
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((valorInicial - minV) / (maxV - minV), 0, 0.5, 0)
    knob.BackgroundColor3 = CORES.sliderKnob
    knob.BorderSizePixel = 0
    knob.ZIndex = 2
    knob.Parent = trilha
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 0, 24)
    hit.Position = UDim2.new(0, 0, 0, 16)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 3
    hit.Parent = linha
    local arrastando = false
    local function processar(input)
        local w = trilha.AbsoluteSize.X
        if w <= 0 then return end
        local pct = math.clamp((input.Position.X - trilha.AbsolutePosition.X) / w, 0, 1)
        local v = minV + (maxV - minV) * pct
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        titulo.Text = label .. ": " .. math.floor(v * 100) .. "%"
        cb(v)
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            arrastando = true; processar(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if arrastando and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            processar(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            arrastando = false
        end
    end)
end

local minimized = false

local function aplicarTam()
    local w = math.floor(tamW * escalaW)
    local h = math.floor(tamH * escalaH)
    tamanhoNormal = UDim2.new(0, w, 0, h)
    tamanhoMin = UDim2.new(0, w, 0, 40)
    if not minimized then
        TweenService:Create(main, TweenInfo.new(0.15), {Size = tamanhoNormal}):Play()
    else
        main.Size = tamanhoMin
    end
end

criarSlider("↔️ Largura", 0.7, 1.6, escalaW, 26, function(v) escalaW = v; aplicarTam() end)
criarSlider("↕️ Altura", 0.7, 1.6, escalaH, 74, function(v) escalaH = v; aplicarTam() end)

local infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1, 0, 0, 60)
infoBox.Position = UDim2.new(0, 0, 0, 530)
infoBox.BackgroundColor3 = CORES.topo
infoBox.BorderSizePixel = 0
infoBox.Visible = false
infoBox.Parent = content
Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 8)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -16, 1, -12)
infoLabel.Position = UDim2.new(0, 8, 0, 6)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = ""
infoLabel.TextColor3 = CORES.texto
infoLabel.Font = Enum.Font.GothamMedium
infoLabel.TextSize = 12
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextWrapped = true
infoLabel.Parent = infoBox

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

makeDraggable(main, topBar)

minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(main, TweenInfo.new(0.25), {Size = minimized and tamanhoMin or tamanhoNormal}):Play()
    scroll.Visible = not minimized
    minBtn.Text = minimized and "+" or "—"
end)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    local reopen = Instance.new("TextButton")
    reopen.Size = UDim2.new(0, 50, 0, 50)
    reopen.Position = UDim2.new(1, -70, 0, 20)
    reopen.BackgroundColor3 = CORES.topo
    reopen.Text = "🎯"
    reopen.TextSize = 24
    reopen.Parent = sg
    Instance.new("UICorner", reopen).CornerRadius = UDim.new(1, 0)
    makeDraggable(reopen)
    reopen.MouseButton1Click:Connect(function()
        main.Visible = true
        reopen:Destroy()
    end)
end)

-- ============ CANDIDATOS ============
local function getCandidatos()
    local lista, vistos = {}, {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local mesmoTime = player.Team and plr.Team and player.Team == plr.Team
            if not mesmoTime then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and getAimPart(plr.Character) then
                    table.insert(lista, plr.Character)
                    vistos[plr.Character] = true
                end
            end
        end
    end
    local function proc(pasta, prof)
        if prof > 6 then return end
        for _, obj in ipairs(pasta:GetChildren()) do
            if obj:IsA("Model") and not vistos[obj] then
                if obj ~= player.Character and getHealth(obj) and getAimPart(obj) and #obj:GetChildren() >= 2 then
                    table.insert(lista, obj)
                    vistos[obj] = true
                end
            end
            if obj:IsA("Folder") or obj:IsA("Model") then proc(obj, prof + 1) end
        end
    end
    proc(Workspace, 0)
    return lista
end

local function acharAlvo()
    local camPos = camera.CFrame.Position
    local camLook = camera.CFrame.LookVector
    local melhor, melhorScore = nil, math.huge
    for _, model in ipairs(getCandidatos()) do
        local part = getAimPart(model)
        if part then
            local dir = (part.Position - camPos).Unit
            local ang = math.acos(math.clamp(camLook:Dot(dir), -1, 1))
            local score = ang + ((part.Position - camPos).Magnitude * 0.001)
            if score < melhorScore then melhor = model; melhorScore = score end
        end
    end
    if melhor then
        local part = getAimPart(melhor)
        if part then
            local dir = (part.Position - camera.CFrame.Position).Unit
            local ang = math.acos(math.clamp(camera.CFrame.LookVector:Dot(dir), -1, 1))
            if ang < math.rad(25) then return melhor end
        end
    end
    return nil
end

local function updateInfo()
    if not target or not target.Parent then return end
    local hp, maxHp = getHealth(target)
    if not hp then return end
    local char = player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local tRoot = getAimPart(target)
    local pct = math.floor((hp / math.max(maxHp or 100, 1)) * 100)
    local dist = myRoot and tRoot and math.floor((tRoot.Position - myRoot.Position).Magnitude) or 0
    local tName = target.Name
    local tPlr = Players:GetPlayerFromCharacter(target)
    if tPlr then tName = tPlr.Name end
    infoLabel.Text = string.format("%s\n%d/%d (%d%%) 📏 %dm", tName, math.floor(hp), math.floor(maxHp or 100), pct, dist)
end

local function criarHPBar(model)
    if hpBarAlvo and hpBarAlvo.Parent then hpBarAlvo:Destroy() end
    if not model or not model.Parent then return end
    local root = getAimPart(model)
    if not root then return end
    local bb = Instance.new("BillboardGui")
    bb.Adornee = root
    bb.Size = UDim2.new(0, 140, 0, 42)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 1000
    bb.Parent = model
    hpBarAlvo = bb
    local bg = Instance.new("Frame")
    bg.Name = "BarBg"
    bg.Size = UDim2.new(1, 0, 0, 14)
    bg.Position = UDim2.new(0, 0, 0, 20)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bg.BorderSizePixel = 0
    bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 7)
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    fill.BorderSizePixel = 0
    fill.Parent = bg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 7)
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Lbl"
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = model.Name
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.Parent = bb
end

local function atualizarHPBar()
    if not hpBarAlvo or not hpBarAlvo.Parent or not target or not target.Parent then return end
    local hp, maxHp = getHealth(target)
    if not hp then return end
    local pct = math.clamp(hp / math.max(maxHp or 100, 1), 0, 1)
    local bg = hpBarAlvo:FindFirstChild("BarBg")
    if bg then
        local fill = bg:FindFirstChild("Fill")
        if fill then
            fill.Size = UDim2.new(pct, 0, 1, 0)
            if pct > 0.6 then fill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
            elseif pct > 0.3 then fill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
            else fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50) end
        end
    end
end

-- ============ RESET CÂMERA ============
local function resetarCamera()
    pcall(function()
        local cam = Workspace.CurrentCamera
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then cam.CameraSubject = hum end
        end
        player.CameraMode = Enum.CameraMode.Classic
    end)
end

-- ============ UPDATE CÂMERA ============
local function updateCamera()
    if tick() < DEVE_RESETAR_ATE then return end
    if not locked or not target or not target.Parent then return end
    
    camera = Workspace.CurrentCamera
    if not camera then return end
    
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    
    local part = getAimPart(target)
    if not part then return end

    local bonecoPos = myRoot.Position
    local alvoPos = part.Position
    if part.Name == "Head" then alvoPos = alvoPos + Vector3.new(0, -0.3, 0) end

    local eyePos = bonecoPos + Vector3.new(0, 3.5, 0)
    local dir = alvoPos - eyePos
    if dir.Magnitude < 0.1 then return end
    dir = dir.Unit

    local camPos = eyePos - dir * DISTANCIA_CAMERA
    
    if camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
    end
    
    camera.CFrame = CFrame.lookAt(camPos, alvoPos)
    camera.Focus = CFrame.new(alvoPos)
    
    updateInfo()
    atualizarHPBar()
end

-- ============ UPDATE CORPO ============
local function updateBody()
    if tick() < DEVE_RESETAR_ATE then return end
    if not locked or not target or not target.Parent then return end
    local char = player.Character
    if not char then return end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not myRoot or not hum or hum.Health <= 0 then return end
    
    matarMovers()
    
    if estaStunado() or tick() - ultimoHitTime < HIT_JANELA then
        if hum.AutoRotate ~= true then hum.AutoRotate = true end
        return
    end
    
    if hum.AutoRotate ~= false then hum.AutoRotate = false end
    
    camera = Workspace.CurrentCamera
    if not camera then return end
    
    local camLook = camera.CFrame.LookVector
    local flat = Vector3.new(camLook.X, 0, camLook.Z)
    if flat.Magnitude < 0.01 then return end
    flat = flat.Unit
    
    local destino = myRoot.Position + flat
    myRoot.CFrame = myRoot.CFrame:Lerp(
        CFrame.lookAt(myRoot.Position, destino),
        0.35
    )
end

-- ============ DEBUG ANGULO LOOP ============
task.spawn(function()
    while task.wait(0.1) do
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        
        if root and cam and hum then
            local bLook = root.CFrame.LookVector
            local cLook = cam.CFrame.LookVector
            local bF = Vector3.new(bLook.X, 0, bLook.Z)
            local cF = Vector3.new(cLook.X, 0, cLook.Z)
            
            if bF.Magnitude > 0.01 and cF.Magnitude > 0.01 then
                local ang = math.deg(math.acos(math.clamp(bF.Unit:Dot(cF.Unit), -1, 1)))
                local status = ang < 15 and "✅ OK" or (ang < 45 and "⚠️ MEDIO" or "🚨 TRAVADO")
                
                local lockIcon = locked and "🔒" or "🔓"
                debugLabel.Text = string.format(
                    "📐 DEBUG %s\nBody: X=%.2f Z=%.2f\nCam:  X=%.2f Z=%.2f\nAngulo: %.0f° %s",
                    lockIcon, bLook.X, bLook.Z, cLook.X, cLook.Z, ang, status
                )
                debugLabel.TextColor3 = ang < 15 and Color3.fromRGB(0, 255, 120) or (ang < 45 and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(255, 60, 60))
            end
        end
    end
end)

-- ============ ESP ============
local function createESP(model)
    if espHighlights[model] then return end
    local root = getAimPart(model)
    if not root then return end
    local tipo = getTipoAlvo(model)
    local cor
    if tipo == "players" then cor = Color3.fromRGB(255, 70, 70)
    elseif tipo == "dummies" then cor = Color3.fromRGB(255, 200, 0)
    else cor = Color3.fromRGB(70, 150, 255) end
    local hl = Instance.new("Highlight")
    hl.FillColor = cor
    hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0.2
    hl.Parent = model
    espHighlights[model] = hl
    local bb = Instance.new("BillboardGui")
    bb.Adornee = root
    bb.Size = UDim2.new(0, 180, 0, 45)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 250
    bb.Parent = model
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.7
    lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextWrapped = true
    lbl.Parent = bb
    espLabels[model] = lbl
end

local function updateESP()
    if not espEnabled then return end
    local agora = tick()
    if agora - espUltimoScan >= 0.5 then
        espUltimoScan = agora
        local candidatos = getCandidatos()
        local vistos = {}
        for _, model in ipairs(candidatos) do
            vistos[model] = true
            if filtros[getTipoAlvo(model)] and not espHighlights[model] then createESP(model) end
        end
        for model, hl in pairs(espHighlights) do
            if not vistos[model] or not filtros[getTipoAlvo(model)] then
                if hl and hl.Parent then hl:Destroy() end
                espHighlights[model] = nil
                if espLabels[model] and espLabels[model].Parent then espLabels[model].Parent:Destroy() end
                espLabels[model] = nil
            end
        end
    end
    if agora - espUltimaLabel < 0.15 then return end
    espUltimaLabel = agora
    local char = player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    for model, lbl in pairs(espLabels) do
        if model.Parent and lbl.Parent then
            local hp, maxHp = getHealth(model)
            local root = getAimPart(model)
            if hp and root and hp > 0 then
                local dist = myRoot and math.floor((root.Position - myRoot.Position).Magnitude) or 0
                local tName = model.Name
                local tPlr = Players:GetPlayerFromCharacter(model)
                if tPlr then tName = tPlr.Name end
                local pct = (hp / math.max(maxHp or 100, 1)) * 100
                local cor = Color3.fromRGB(0, 255, 0)
                if pct < 30 then cor = Color3.fromRGB(255, 0, 0)
                elseif pct < 60 then cor = Color3.fromRGB(255, 255, 0) end
                lbl.TextColor3 = cor
                lbl.Text = string.format("%s\n%d/%d 📏 %dm", tName, math.floor(hp), math.floor(maxHp or 100), dist)
            else
                if espHighlights[model] then espHighlights[model]:Destroy() espHighlights[model] = nil end
                if lbl then lbl:Destroy() end
                espLabels[model] = nil
            end
        end
    end
end

function atualizarStatus()
    statusLabel.Text = (locked and "🔒 Lock: ON" or "🔓 Lock: OFF") .. "\n" .. (espEnabled and "👁️ ESP: ON" or "👁️ ESP: OFF")
    statusLabel.TextColor3 = (locked or espEnabled) and CORES.on or CORES.textoFraco
end

local function toggleESP()
    espEnabled = not espEnabled
    if espEnabled then
        espBtn.Text = "👁️ ESP: ON"
        espBtn.BackgroundColor3 = CORES.on
        espUltimoScan = 0
        for _, m in ipairs(getCandidatos()) do
            if filtros[getTipoAlvo(m)] then createESP(m) end
        end
        if espConnection then espConnection:Disconnect() end
        espConnection = RunService.Heartbeat:Connect(updateESP)
    else
        espBtn.Text = "👁️ ESP: OFF"
        espBtn.BackgroundColor3 = CORES.botao
        for _, hl in pairs(espHighlights) do if hl then hl:Destroy() end end
        espHighlights = {}
        for _, l in pairs(espLabels) do if l and l.Parent then l.Parent:Destroy() end end
        espLabels = {}
        if espConnection then espConnection:Disconnect() espConnection = nil end
    end
    atualizarStatus()
end

function lockTarget(novoAlvo)
    DEVE_RESETAR_ATE = 0
    matarMovers()
    target = novoAlvo
    locked = true
    _G.EZEK_LOCKED = true
    _G.EZEK_TARGET = novoAlvo
    lockBtn.Text = "🔒 LOCK: ON"
    lockBtn.BackgroundColor3 = CORES.on
    infoBox.Visible = true
    updateInfo()
    criarHPBar(novoAlvo)
    cameraTypeAntigo = camera.CameraType
    cameraModeAntigo = player.CameraMode
    camera.CameraType = Enum.CameraType.Scriptable
    pcall(function()
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = false end
    end)
    RunService:UnbindFromRenderStep("EZEK_Cam")
    RunService:BindToRenderStep("EZEK_Cam", Enum.RenderPriority.Camera.Value + 1, updateCamera)
    RunService:UnbindFromRenderStep("EZEK_Body")
    RunService:BindToRenderStep("EZEK_Body", Enum.RenderPriority.Character.Value + 10, updateBody)
    atualizarStatus()
end

function unlockTarget()
    locked = false
    target = nil
    _G.EZEK_LOCKED = false
    _G.EZEK_TARGET = nil
    lockBtn.Text = "🔓 LOCK: OFF"
    lockBtn.BackgroundColor3 = CORES.botao
    infoBox.Visible = false
    if hpBarAlvo then hpBarAlvo:Destroy(); hpBarAlvo = nil end
    RunService:UnbindFromRenderStep("EZEK_Cam")
    RunService:UnbindFromRenderStep("EZEK_Body")
    resetarCamera()
    pcall(function()
        if cameraTypeAntigo and cameraTypeAntigo ~= Enum.CameraType.Scriptable then
            if Workspace.CurrentCamera then Workspace.CurrentCamera.CameraType = cameraTypeAntigo end
        end
        if cameraModeAntigo then player.CameraMode = cameraModeAntigo end
    end)
    pcall(function()
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
    end)
    atualizarStatus()
end

local function toggleLock()
    DEVE_RESETAR_ATE = 0
    if locked then unlockTarget()
    else
        local t = acharAlvo()
        if t then lockTarget(t) else print("❌ Nenhum alvo!") end
    end
end

lockBtn.MouseButton1Click:Connect(toggleLock)
espBtn.MouseButton1Click:Connect(toggleESP)

-- ============ TECLAS ============
local r1, r2, l1, l2 = false, false, false, false
local ultLock, ultEsp = 0, 0

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Q then toggleLock()
    elseif input.KeyCode == Enum.KeyCode.E then toggleESP() end
    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1 = true end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2 = true end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1 = true end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2 = true end
    if r1 and r2 then
        local a = tick()
        if a - ultLock > 0.8 then toggleLock(); ultLock = a end
    end
    if l1 and l2 then
        local a = tick()
        if a - ultEsp > 0.8 then toggleESP(); ultEsp = a end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1 = false end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2 = false end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1 = false end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2 = false end
end)

-- ============ MORTE E RESPAWN ============
player.CharacterRemoving:Connect(function()
    DEVE_RESETAR_ATE = tick() + 3
    locked = false
    target = nil
    _G.EZEK_LOCKED = false
    _G.EZEK_TARGET = nil
    pcall(function()
        RunService:UnbindFromRenderStep("EZEK_Cam")
        RunService:UnbindFromRenderStep("EZEK_Body")
    end)
    resetarCamera()
    pcall(function()
        if lockBtn then
            lockBtn.Text = "🔓 LOCK: OFF"
            lockBtn.BackgroundColor3 = CORES.botao
        end
        if infoBox then infoBox.Visible = false end
        if hpBarAlvo then hpBarAlvo:Destroy(); hpBarAlvo = nil end
    end)
end)

player.CharacterAdded:Connect(function(newChar)
    task.wait(0.3)
    DEVE_RESETAR_ATE = 0
    locked = false
    target = nil
    _G.EZEK_LOCKED = false
    _G.EZEK_TARGET = nil
    if Workspace.CurrentCamera then camera = Workspace.CurrentCamera end
    resetarCamera()
    task.wait(0.3)
    resetarCamera()
    local hum = newChar:WaitForChild("Humanoid", 5)
    if hum then
        hum.AutoRotate = true
        hum.CameraOffset = Vector3.new(0, 0, 0)
    end
    pcall(function() atualizarStatus() end)
end)

-- ══════════════════════════════════════════════════
-- 🔥 RESET FORÇADO CONTÍNUO PÓS-MORTE
-- ══════════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.1) do
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then
                DEVE_RESETAR_ATE = tick() + 3
            end
        end
        
        if tick() < DEVE_RESETAR_ATE then
            pcall(function()
                local cam = Workspace.CurrentCamera
                if cam and cam.CameraType == Enum.CameraType.Scriptable then
                    cam.CameraType = Enum.CameraType.Custom
                end
            end)
            
            pcall(function()
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        if hum.AutoRotate ~= true then hum.AutoRotate = true end
                        if hum.CameraOffset ~= Vector3.new(0, 0, 0) then
                            hum.CameraOffset = Vector3.new(0, 0, 0)
                        end
                    end
                end
            end)
            
            if locked then
                locked = false
                target = nil
                _G.EZEK_LOCKED = false
                _G.EZEK_TARGET = nil
                pcall(function()
                    RunService:UnbindFromRenderStep("EZEK_Cam")
                    RunService:UnbindFromRenderStep("EZEK_Body")
                end)
                pcall(function()
                    if lockBtn then
                        lockBtn.Text = "🔓 LOCK: OFF"
                        lockBtn.BackgroundColor3 = CORES.botao
                    end
                    if infoBox then infoBox.Visible = false end
                    if hpBarAlvo then hpBarAlvo:Destroy(); hpBarAlvo = nil end
                end)
            end
        end
    end
end)

atualizarStatus()
print("✅ AIMLOCK DO EZEK v18.7!")
print("🔗 Welds de boss filtrados por nome (preserva acessórios)")
print("🎮 Q = Lock | E = ESP | R1+R2 = Lock | L1+L2 = ESP")