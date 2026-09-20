-- AIMLOCK DO EZEK v16.15 - MOBILE + CONSOLE + CONTROLE
-- Solta câmera + AutoRotate quando toma hit; monitor contínuo agressivo

-- ============ PROTEÇÃO ============
local PROTECAO = {}
PROTECAO.chave = tostring(math.random(100000, 999999)) .. tostring(tick())

local function verificarAmbiente()
    local checks = {
        game ~= nil, game.GetService ~= nil, Instance ~= nil,
        Instance.new ~= nil, task ~= nil, task.wait ~= nil, pcall ~= nil,
    }
    for _, check in ipairs(checks) do
        if not check then return false end
    end
    return true
end

if not verificarAmbiente() then
    warn("❌ [EZEK] Ambiente inválido!")
    return
end

if _G.EZEK_AIMLOCK_LOADED then
    pcall(function()
        if _G.EZEK_AIMLOCK_GUI then _G.EZEK_AIMLOCK_GUI:Destroy() end
    end)
end
_G.EZEK_AIMLOCK_LOADED = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local DISTANCIA_CAMERA = 12
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============ ESTADO ============
local locked = false
local target = nil
local espEnabled = false
local espHighlights = {}
local espLabels = {}
local espUpdateConnection = nil
local targetHealthESP = nil
local cameraTypeAntigo = nil
local cameraModeAntigo = nil

local espUltimoScan = 0
local ESP_SCAN_INTERVALO = 0.5
local espUltimaAtualizacaoLabel = 0
local ESP_LABEL_INTERVALO = 0.15

local candidatosCache = {}
local candidatosCacheTime = 0
local CANDIDATOS_CACHE_INTERVALO = 0.3

local escalaW = 1.0
local escalaH = 1.0
local ESCALA_MIN = 0.7
local ESCALA_MAX = 1.6

local filtros = { players = true, dummies = true, monstros = true }

-- ============ HIT DETECTION ============
local ultimoHitTime = 0
local vidaAnterior = 100
local HIT_JANELA = 0.6

-- ============ RESET CÂMERA ============
local function resetarCamera()
    pcall(function()
        local cam = Workspace.CurrentCamera
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                if hum then
                    cam.CameraSubject = hum
                elseif root then
                    cam.CameraSubject = root
                end
            end
        end
        player.CameraMode = Enum.CameraMode.Classic
    end)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then
        camera = Workspace.CurrentCamera
        if not locked then resetarCamera() end
    end
end)

task.spawn(function()
    while task.wait(1) do
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and not hum:GetAttribute("EZEK_HOOKED") then
                hum:SetAttribute("EZEK_HOOKED", true)
                hum.Died:Connect(function()
                    task.wait(0.2)
                    resetarCamera()
                end)
            end
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

        if hum.Health < vidaAnterior - 0.5 then
            ultimoHitTime = tick()
        end
        vidaAnterior = hum.Health

        local attrs = {"Stunned","Stun","Knocked","Knockback","Frozen","Grabbed",
                       "Staggered","Paralyzed","Locked","CombatLock","InCombat","Hit"}
        for _, nome in ipairs(attrs) do
            if hum:GetAttribute(nome) or char:GetAttribute(nome) then
                ultimoHitTime = tick()
                break
            end
        end

        -- Solta AutoRotate se tomou hit
        if tick() - ultimoHitTime < HIT_JANELA then
            if hum.AutoRotate ~= true then
                hum.AutoRotate = true
            end
        end
    end
end)

-- ============ DETECÇÃO DE STUN ============
local function estaSobEfeitoDeSkill(char, hum)
    if not char or not hum then return true end

    local estado = hum:GetState()
    if estado == Enum.HumanoidStateType.Physics
       or estado == Enum.HumanoidStateType.Ragdoll
       or estado == Enum.HumanoidStateType.PlatformStanding
       or hum.PlatformStand == true then
        return true
    end

    local attrs = {"Stunned","Stun","Knocked","Knockback","Frozen","Grabbed",
                   "Staggered","Paralyzed","Locked","CombatLock","InCombat"}
    for _, nome in ipairs(attrs) do
        if hum:GetAttribute(nome) or char:GetAttribute(nome) then
            return true
        end
    end

    if tick() - ultimoHitTime < HIT_JANELA then
        return true
    end

    return false
end

-- ============ CORES ============
local CORES = {
    fundo      = Color3.fromRGB(20, 20, 25),
    topo       = Color3.fromRGB(30, 30, 40),
    botao      = Color3.fromRGB(45, 45, 60),
    on         = Color3.fromRGB(0, 170, 90),
    off        = Color3.fromRGB(180, 50, 50),
    texto      = Color3.fromRGB(240, 240, 240),
    textoFraco = Color3.fromRGB(160, 160, 170),
    borda      = Color3.fromRGB(90, 90, 120),
    checkOn    = Color3.fromRGB(0, 170, 90),
    checkOff   = Color3.fromRGB(60, 60, 75),
    scroll     = Color3.fromRGB(70, 70, 90),
    sliderBg   = Color3.fromRGB(40, 40, 55),
    sliderFill = Color3.fromRGB(0, 170, 90),
    sliderKnob = Color3.fromRGB(220, 220, 230),
}

-- ============ GUI ============
local sg = Instance.new("ScreenGui")
sg.Name = "AIMLOCK_DO_EZEK_" .. PROTECAO.chave
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = player:WaitForChild("PlayerGui")
_G.EZEK_AIMLOCK_GUI = sg

local tamWbase = 240
local tamHbase = 520
local tamHmin  = 40

local tamanhoNormal = UDim2.new(0, math.floor(tamWbase * escalaW), 0, math.floor(tamHbase * escalaH))
local tamanhoMin    = UDim2.new(0, math.floor(tamWbase * escalaW), 0, tamHmin)

local main = Instance.new("Frame")
main.Name = "EZEK_Main_" .. PROTECAO.chave
main.Size = tamanhoNormal
main.Position = UDim2.new(0, 20, 0, 80)
main.BackgroundColor3 = CORES.fundo
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
main.Parent = sg

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = CORES.borda
mainStroke.Thickness = 1.5
mainStroke.Parent = main

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = CORES.topo
topBar.BorderSizePixel = 0
topBar.Parent = main
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 10)
topFix.Position = UDim2.new(0, 0, 1, -10)
topFix.BackgroundColor3 = CORES.topo
topFix.BorderSizePixel = 0
topFix.Parent = topBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -150, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🎯 AIMLOCK DO EZEK v16.15"
title.TextColor3 = CORES.texto
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Position = UDim2.new(1, -70, 0, 5)
minBtn.BackgroundColor3 = CORES.botao
minBtn.Text = "—"
minBtn.TextColor3 = CORES.texto
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 18
minBtn.Parent = topBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = CORES.off
closeBtn.Text = "✕"
closeBtn.TextColor3 = CORES.texto
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Scroll"
scroll.Size = UDim2.new(1, -10, 1, -50)
scroll.Position = UDim2.new(0, 5, 0, 45)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = CORES.scroll
scroll.ScrollBarImageTransparency = 0.3
scroll.CanvasSize = UDim2.new(0, 0, 0, 540)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
scroll.Parent = main

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingLeft = UDim.new(0, 5)
scrollPadding.PaddingRight = UDim.new(0, 5)
scrollPadding.PaddingBottom = UDim.new(0, 5)
scrollPadding.Parent = scroll

local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -10, 0, 540)
content.Position = UDim2.new(0, 0, 0, 0)
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

local function criarBotao(textoInicial, posY)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.Position = UDim2.new(0, 0, 0, posY)
    btn.BackgroundColor3 = CORES.botao
    btn.Text = textoInicial
    btn.TextColor3 = CORES.texto
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 15
    btn.Parent = content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke")
    s.Color = CORES.borda
    s.Thickness = 1
    s.Transparency = 0.5
    s.Parent = btn
    return btn
end

local lockBtn = criarBotao("🔓 LOCK: OFF", 70)
local espBtn  = criarBotao("👁️ ESP: OFF",  120)

-- ============ AUXILIARES ============
local getTipoAlvo

local function getHealth(model)
    if not model then return nil, nil, nil end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        return hum.Health, hum.MaxHealth, "Humanoid"
    end
    local atributos = {"Health", "HP", "health", "CurrentHealth", "hp"}
    for _, nome in ipairs(atributos) do
        local v = model:GetAttribute(nome)
        if v and type(v) == "number" then
            local maxV = model:GetAttribute("MaxHealth") or model:GetAttribute("MaxHP") or model:GetAttribute("maxHealth") or 100
            return v, maxV, "Attribute"
        end
    end
    for _, nome in ipairs({"Health", "HP", "health"}) do
        local hpVal = model:FindFirstChild(nome, true)
        if hpVal and hpVal:IsA("NumberValue") then
            return hpVal.Value, 100, "NumberValue"
        end
    end
    return nil, nil, nil
end

local function getAimPart(model)
    if not model then return nil end
    return model:FindFirstChild("Head")
        or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Root")
        or model:FindFirstChild("Body")
        or model.PrimaryPart
end

getTipoAlvo = function(model)
    if not model then return "monstros" end
    if Players:GetPlayerFromCharacter(model) then return "players" end
    local n = string.lower(model.Name)
    if n:find("dummy") or n:find("training") or n:find("test") or n:find("practice") or n:find("target") then
        return "dummies"
    end
    local parent = model.Parent
    if parent then
        local pn = string.lower(parent.Name)
        if pn:find("dummy") or pn:find("training") or pn:find("test") or pn:find("practice") then
            return "dummies"
        end
    end
    return "monstros"
end

-- ============ FILTROS ============
local filtroFrame = Instance.new("Frame")
filtroFrame.Size = UDim2.new(1, 0, 0, 110)
filtroFrame.Position = UDim2.new(0, 0, 0, 170)
filtroFrame.BackgroundColor3 = CORES.topo
filtroFrame.BorderSizePixel = 0
filtroFrame.Parent = content
Instance.new("UICorner", filtroFrame).CornerRadius = UDim.new(0, 8)

local filtroTitulo = Instance.new("TextLabel")
filtroTitulo.Size = UDim2.new(1, -12, 0, 18)
filtroTitulo.Position = UDim2.new(0, 8, 0, 4)
filtroTitulo.BackgroundTransparency = 1
filtroTitulo.Text = "🎛️ Filtros do ESP"
filtroTitulo.TextColor3 = CORES.textoFraco
filtroTitulo.Font = Enum.Font.GothamBold
filtroTitulo.TextSize = 11
filtroTitulo.TextXAlignment = Enum.TextXAlignment.Left
filtroTitulo.Parent = filtroFrame

local function criarCheckbox(texto, chave, posY)
    local checkFrame = Instance.new("Frame")
    checkFrame.Size = UDim2.new(1, -16, 0, 26)
    checkFrame.Position = UDim2.new(0, 8, 0, posY)
    checkFrame.BackgroundTransparency = 1
    checkFrame.Parent = filtroFrame

    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0, 22, 0, 22)
    box.Position = UDim2.new(0, 0, 0, 2)
    box.BackgroundColor3 = filtros[chave] and CORES.checkOn or CORES.checkOff
    box.Text = filtros[chave] and "✓" or ""
    box.TextColor3 = CORES.texto
    box.Font = Enum.Font.GothamBold
    box.TextSize = 14
    box.Parent = checkFrame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -30, 1, 0)
    label.Position = UDim2.new(0, 30, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = texto
    label.TextColor3 = CORES.texto
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = checkFrame

    local function toggle()
        filtros[chave] = not filtros[chave]
        box.BackgroundColor3 = filtros[chave] and CORES.checkOn or CORES.checkOff
        box.Text = filtros[chave] and "✓" or ""
        if not filtros[chave] and espEnabled then
            for model, hl in pairs(espHighlights) do
                if getTipoAlvo(model) == chave then
                    if hl then hl:Destroy() end
                    espHighlights[model] = nil
                    if espLabels[model] and espLabels[model].Parent then
                        espLabels[model].Parent:Destroy()
                    end
                    espLabels[model] = nil
                end
            end
        end
        espUltimoScan = 0
    end

    box.MouseButton1Click:Connect(toggle)
    label.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            toggle()
        end
    end)
end

criarCheckbox("👤 Players", "players", 26)
criarCheckbox("🎯 Dummies", "dummies", 56)
criarCheckbox("👹 Monstros / NPCs", "monstros", 86)

-- ============ SLIDERS ============
local slidersFrame = Instance.new("Frame")
slidersFrame.Size = UDim2.new(1, 0, 0, 130)
slidersFrame.Position = UDim2.new(0, 0, 0, 290)
slidersFrame.BackgroundColor3 = CORES.topo
slidersFrame.BorderSizePixel = 0
slidersFrame.Parent = content
Instance.new("UICorner", slidersFrame).CornerRadius = UDim.new(0, 8)

local slidersTitulo = Instance.new("TextLabel")
slidersTitulo.Size = UDim2.new(1, -12, 0, 18)
slidersTitulo.Position = UDim2.new(0, 8, 0, 4)
slidersTitulo.BackgroundTransparency = 1
slidersTitulo.Text = "📐 Tamanho da UI"
slidersTitulo.TextColor3 = CORES.textoFraco
slidersTitulo.Font = Enum.Font.GothamBold
slidersTitulo.TextSize = 11
slidersTitulo.TextXAlignment = Enum.TextXAlignment.Left
slidersTitulo.Parent = slidersFrame

local function criarSlider(textoLabel, minVal, maxVal, valorInicial, posY, callback)
    local linha = Instance.new("Frame")
    linha.Size = UDim2.new(1, -16, 0, 42)
    linha.Position = UDim2.new(0, 8, 0, posY)
    linha.BackgroundTransparency = 1
    linha.Parent = slidersFrame

    local titulo = Instance.new("TextLabel")
    titulo.Size = UDim2.new(1, 0, 0, 14)
    titulo.Position = UDim2.new(0, 0, 0, 0)
    titulo.BackgroundTransparency = 1
    titulo.Text = textoLabel .. ": " .. math.floor(valorInicial * 100) .. "%"
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
    fill.Size = UDim2.new((valorInicial - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = CORES.sliderFill
    fill.BorderSizePixel = 0
    fill.Parent = trilha
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((valorInicial - minVal) / (maxVal - minVal), 0, 0.5, 0)
    knob.BackgroundColor3 = CORES.sliderKnob
    knob.BorderSizePixel = 0
    knob.ZIndex = 2
    knob.Parent = trilha
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local hitArea = Instance.new("TextButton")
    hitArea.Size = UDim2.new(1, 0, 0, 24)
    hitArea.Position = UDim2.new(0, 0, 0, 16)
    hitArea.BackgroundTransparency = 1
    hitArea.Text = ""
    hitArea.ZIndex = 3
    hitArea.Parent = linha

    local valor = valorInicial
    local arrastando = false

    local function setarValor(v)
        v = math.clamp(v, minVal, maxVal)
        valor = v
        local pct = (v - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        titulo.Text = textoLabel .. ": " .. math.floor(v * 100) .. "%"
        callback(v)
    end

    local function processar(input)
        local absX = trilha.AbsolutePosition.X
        local width = trilha.AbsoluteSize.X
        if width <= 0 then return end
        local pct = (input.Position.X - absX) / width
        local v = minVal + (maxVal - minVal) * pct
        setarValor(v)
    end

    hitArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            arrastando = true
            processar(input)
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

local function aplicarTamanho()
    local w = math.floor(tamWbase * escalaW)
    local h = math.floor(tamHbase * escalaH)
    tamanhoNormal = UDim2.new(0, w, 0, h)
    tamanhoMin    = UDim2.new(0, w, 0, tamHmin)
    if not minimized then
        TweenService:Create(main, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Size = tamanhoNormal }):Play()
    else
        main.Size = tamanhoMin
    end
end

criarSlider("↔️ Largura", ESCALA_MIN, ESCALA_MAX, escalaW, 26, function(v) escalaW = v; aplicarTamanho() end)
criarSlider("↕️ Altura", ESCALA_MIN, ESCALA_MAX, escalaH, 74, function(v) escalaH = v; aplicarTamanho() end)

local infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1, 0, 0, 60)
infoBox.Position = UDim2.new(0, 0, 0, 430)
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

local creditos = Instance.new("TextLabel")
creditos.Size = UDim2.new(1, 0, 0, 18)
creditos.Position = UDim2.new(0, 0, 0, 498)
creditos.BackgroundTransparency = 1
creditos.Text = "R1+R2 = Lock | L1+L2 = ESP"
creditos.TextColor3 = CORES.textoFraco
creditos.Font = Enum.Font.GothamMedium
creditos.TextSize = 11
creditos.Parent = content

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
    TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = minimized and tamanhoMin or tamanhoNormal }):Play()
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
    local rs = Instance.new("UIStroke")
    rs.Color = CORES.borda
    rs.Thickness = 1.5
    rs.Parent = reopen
    makeDraggable(reopen)
    reopen.MouseButton1Click:Connect(function()
        main.Visible = true
        reopen:Destroy()
    end)
end)

local function setAutoRotate(state)
    pcall(function()
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.AutoRotate = state end
        end
    end)
end

-- ============ KILL LOCK NATIVO ============
local function matarLockNativo()
    pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, gui in ipairs(pg:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                local n = string.lower(gui.Name)
                if n:find("lock") or n:find("target") or n:find("combat") 
                   or n:find("aim") or n:find("focus") then
                    gui.Enabled = false
                end
            end
        end
    end)
end

-- ============ CANDIDATOS ============
local function isValidTarget(model)
    if not model or not model.Parent then return false end
    if model == player.Character then return false end
    if not model:IsA("Model") then return false end
    local hp = getHealth(model)
    if not hp or hp <= 0 then return false end
    if not getAimPart(model) then return false end
    if #model:GetChildren() < 2 then return false end
    return true
end

local function getCandidates()
    local lista = {}
    local vistos = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local mesmoTime = false
            if player.Team and plr.Team and player.Team == plr.Team then
                mesmoTime = true
            end
            if not mesmoTime then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and getAimPart(plr.Character) then
                    table.insert(lista, plr.Character)
                    vistos[plr.Character] = true
                end
            end
        end
    end
    local function procurar(pasta, profundidade)
        if profundidade > 6 then return end
        for _, obj in ipairs(pasta:GetChildren()) do
            if obj:IsA("Model") and not vistos[obj] then
                if isValidTarget(obj) then
                    table.insert(lista, obj)
                    vistos[obj] = true
                end
            end
            if obj:IsA("Folder") or obj:IsA("Model") then
                procurar(obj, profundidade + 1)
            end
        end
    end
    procurar(Workspace, 0)
    return lista
end

local function getCandidatesCacheado()
    local agora = tick()
    if agora - candidatosCacheTime >= CANDIDATOS_CACHE_INTERVALO then
        candidatosCache = getCandidates()
        candidatosCacheTime = agora
    end
    return candidatosCache
end

-- ============ FIND TARGET ============
local function findTarget()
    local character = player.Character
    if not character then return nil end
    local camPos = camera.CFrame.Position
    local camLook = camera.CFrame.LookVector
    local bestTarget, bestScore = nil, math.huge
    for _, model in ipairs(getCandidatesCacheado()) do
        local part = getAimPart(model)
        if part then
            local dir = (part.Position - camPos).Unit
            local ang = math.acos(math.clamp(camLook:Dot(dir), -1, 1))
            local dist = (part.Position - camPos).Magnitude
            local score = ang + (dist * 0.001)
            if score < bestScore then
                bestTarget = model
                bestScore = score
            end
        end
    end
    if bestTarget then
        local part = getAimPart(bestTarget)
        if part then
            local dir = (part.Position - camera.CFrame.Position).Unit
            local ang = math.acos(math.clamp(camera.CFrame.LookVector:Dot(dir), -1, 1))
            if ang < math.rad(20) then
                return bestTarget
            end
        end
    end
    return nil
end

local function updateTargetInfo()
    if not target or not target.Parent then return end
    local hp, maxHp = getHealth(target)
    if not hp then return end
    local char = player.Character
    local myRoot = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    local tRoot = getAimPart(target)
    local pct = math.floor((hp / math.max(maxHp or 100, 1)) * 100)
    local dist = 0
    if myRoot and tRoot then dist = math.floor((tRoot.Position - myRoot.Position).Magnitude) end
    local tName = target.Name
    local tagTipo = "🤖 NPC"
    local tPlr = Players:GetPlayerFromCharacter(target)
    if tPlr then tName = tPlr.Name; tagTipo = "👤 Player" end
    local col = "🟢"
    if pct < 30 then col = "🔴" elseif pct < 60 then col = "🟡" end
    infoLabel.Text = string.format("%s %s\n%s %d/%d (%d%%) 📏 %dm", tagTipo, tName, col, math.floor(hp), math.floor(maxHp or 100), pct, dist)
end

local function criarHPBarDoAlvo(model)
    if targetHealthESP and targetHealthESP.Parent then targetHealthESP:Destroy() end
    if not model or not model.Parent then return end
    local root = getAimPart(model)
    if not root then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "EZEK_TargetHP_" .. PROTECAO.chave
    bb.Adornee = root
    bb.Size = UDim2.new(0, 140, 0, 42)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 1000
    bb.Parent = model
    targetHealthESP = bb
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(1, 0, 0, 14)
    barBg.Position = UDim2.new(0, 0, 0, 20)
    barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    barBg.BorderSizePixel = 0
    barBg.Parent = bb
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 7)
    local bgStroke = Instance.new("UIStroke")
    bgStroke.Color = Color3.fromRGB(255, 255, 255)
    bgStroke.Thickness = 1
    bgStroke.Transparency = 0.3
    bgStroke.Parent = barBg
    local barFill = Instance.new("Frame")
    barFill.Name = "Fill"
    barFill.Size = UDim2.new(1, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 7)
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 0, 18)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = model.Name
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Parent = bb
end

local function atualizarHPBarDoAlvo()
    if not targetHealthESP or not targetHealthESP.Parent then return end
    if not target or not target.Parent then return end
    local hp, maxHp = getHealth(target)
    if not hp then return end
    local pct = math.clamp(hp / math.max(maxHp or 100, 1), 0, 1)
    local barBg = targetHealthESP:FindFirstChild("BarBg")
    if barBg then
        local fill = barBg:FindFirstChild("Fill")
        if fill then
            fill.Size = UDim2.new(pct, 0, 1, 0)
            if pct > 0.6 then fill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
            elseif pct > 0.3 then fill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
            else fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50) end
        end
    end
    local label = targetHealthESP:FindFirstChild("Label")
    if label then
        local tName = target.Name
        local tPlr = Players:GetPlayerFromCharacter(target)
        if tPlr then tName = tPlr.Name end
        label.Text = string.format("%s %d/%d", tName, math.floor(hp), math.floor(maxHp or 100))
    end
end

local function removerHPBarDoAlvo()
    if targetHealthESP then
        targetHealthESP:Destroy()
        targetHealthESP = nil
    end
end

local function forcarOrientacao() return end

-- ============ UPDATE CAMERA ============
local ultimaForcadaCamera = 0
local function updateCamera()
    if not locked or not target or not target.Parent then return end
    if Workspace.CurrentCamera and camera ~= Workspace.CurrentCamera then
        camera = Workspace.CurrentCamera
    end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then task.defer(unlockTarget); return end
    local myRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not myRoot then return end
    local hp = getHealth(target)
    if not hp or hp <= 0 then task.defer(unlockTarget); return end
    local part = getAimPart(target)
    if not part then return end

    -- 🔥 TOMOU HIT: devolve câmera pro Roblox e espera
    if tick() - ultimoHitTime < HIT_JANELA then
        if camera.CameraType == Enum.CameraType.Scriptable then
            pcall(function() camera.CameraType = Enum.CameraType.Custom end)
        end
        return
    end

    local agora = tick()
    local tempoEspera = IS_MOBILE and 1.5 or 0.5
    if camera.CameraType ~= Enum.CameraType.Scriptable then
        if agora - ultimaForcadaCamera > tempoEspera then
            camera.CameraType = Enum.CameraType.Scriptable
            ultimaForcadaCamera = agora
        else
            return
        end
    end
    local aimPos = part.Position
    if part.Name == "Head" then aimPos = aimPos + Vector3.new(0, -0.3, 0) end
    local eyePos = myRoot.Position + Vector3.new(0, 3.5, 0)
    local dir = aimPos - eyePos
    if dir.Magnitude < 0.1 then return end
    dir = dir.Unit
    local camPos = eyePos - dir * DISTANCIA_CAMERA
    local cfAlvo = CFrame.lookAt(camPos, aimPos)
    camera.CFrame = camera.CFrame:Lerp(cfAlvo, 0.4)
    camera.Focus = CFrame.new(aimPos)
    updateTargetInfo()
    atualizarHPBarDoAlvo()
end

-- ============ UPDATE BODY ============
local function updateBody()
    if not locked or not target or not target.Parent then return end
    local char = player.Character
    if not char then return end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.Health <= 0 then return end
    if estaSobEfeitoDeSkill(char, hum) then
        if hum.AutoRotate ~= true then hum.AutoRotate = true end
        return
    end
    local hp = getHealth(target)
    if not hp or hp <= 0 then return end
    local part = getAimPart(target)
    if not part then return end
    local moveDir = hum.MoveDirection
    if moveDir.Magnitude > 0.1 then
        if hum.AutoRotate ~= true then hum.AutoRotate = true end
        return
    end
    if hum.AutoRotate ~= false then hum.AutoRotate = false end
    local flat = Vector3.new(part.Position.X, myRoot.Position.Y, part.Position.Z)
    local lookDir = flat - myRoot.Position
    if lookDir.Magnitude > 0.5 then
        local alvo = CFrame.lookAt(myRoot.Position, myRoot.Position + lookDir.Unit)
        myRoot.CFrame = myRoot.CFrame:Lerp(alvo, 0.15)
    end
end

-- ============ ESP ============
local function createESP(model)
    if espHighlights[model] then return end
    local root = getAimPart(model)
    if not root then return end
    local tipo = getTipoAlvo(model)
    local fillColor
    if tipo == "players" then fillColor = Color3.fromRGB(255, 70, 70)
    elseif tipo == "dummies" then fillColor = Color3.fromRGB(255, 200, 0)
    else fillColor = Color3.fromRGB(70, 150, 255) end
    local hl = Instance.new("Highlight")
    hl.FillColor = fillColor
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
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 0.7
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextWrapped = true
    label.Parent = bb
    espLabels[model] = label
end

local function updateESP()
    if not espEnabled then return end
    local agora = tick()
    if agora - espUltimoScan >= ESP_SCAN_INTERVALO then
        espUltimoScan = agora
        local candidatos = getCandidates()
        local vistos = {}
        for _, model in ipairs(candidatos) do
            vistos[model] = true
            local tipo = getTipoAlvo(model)
            if filtros[tipo] then
                if not espHighlights[model] then createESP(model) end
            end
        end
        for model, hl in pairs(espHighlights) do
            if not vistos[model] or not filtros[getTipoAlvo(model)] then
                if hl and hl.Parent then hl:Destroy() end
                espHighlights[model] = nil
                if espLabels[model] and espLabels[model].Parent then
                    espLabels[model].Parent:Destroy()
                end
                espLabels[model] = nil
            end
        end
    end
    if agora - espUltimaAtualizacaoLabel < ESP_LABEL_INTERVALO then return end
    espUltimaAtualizacaoLabel = agora
    local char = player.Character
    local myRoot = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    for model, label in pairs(espLabels) do
        if model.Parent and label.Parent then
            local hp, maxHp = getHealth(model)
            local root = getAimPart(model)
            if hp and root and hp > 0 then
                local dist = 0
                if myRoot then dist = math.floor((root.Position - myRoot.Position).Magnitude) end
                local tName = model.Name
                local tag = "🤖"
                local tPlr = Players:GetPlayerFromCharacter(model)
                if tPlr then tName = tPlr.Name; tag = "👤" end
                local pct = (hp / math.max(maxHp or 100, 1)) * 100
                local col = Color3.fromRGB(0, 255, 0)
                if pct < 30 then col = Color3.fromRGB(255, 0, 0)
                elseif pct < 60 then col = Color3.fromRGB(255, 255, 0) end
                label.TextColor3 = col
                label.Text = string.format("%s %s\n❤️ %d/%d 📏 %dm", tag, tName, math.floor(hp), math.floor(maxHp or 100), dist)
            else
                if espHighlights[model] then espHighlights[model]:Destroy() espHighlights[model] = nil end
                if label then label:Destroy() end
                espLabels[model] = nil
            end
        else
            if espHighlights[model] then espHighlights[model]:Destroy() espHighlights[model] = nil end
            espLabels[model] = nil
        end
    end
end

local function atualizarStatus()
    local lockTxt = locked and "🔒 Lock: ON" or "🔓 Lock: OFF"
    local espTxt = espEnabled and "👁️ ESP: ON" or "👁️ ESP: OFF"
    statusLabel.Text = lockTxt .. "\n" .. espTxt
    statusLabel.TextColor3 = (locked or espEnabled) and CORES.on or CORES.textoFraco
end

local function toggleESP()
    espEnabled = not espEnabled
    if espEnabled then
        espBtn.Text = "👁️ ESP: ON"
        espBtn.BackgroundColor3 = CORES.on
        espUltimoScan = 0
        espUltimaAtualizacaoLabel = 0
        for _, model in ipairs(getCandidates()) do
            local tipo = getTipoAlvo(model)
            if filtros[tipo] then createESP(model) end
        end
        if espUpdateConnection then espUpdateConnection:Disconnect() end
        espUpdateConnection = RunService.Heartbeat:Connect(updateESP)
    else
        espBtn.Text = "👁️ ESP: OFF"
        espBtn.BackgroundColor3 = CORES.botao
        for _, hl in pairs(espHighlights) do if hl then hl:Destroy() end end
        espHighlights = {}
        for _, label in pairs(espLabels) do if label and label.Parent then label.Parent:Destroy() end end
        espLabels = {}
        if espUpdateConnection then espUpdateConnection:Disconnect() espUpdateConnection = nil end
    end
    atualizarStatus()
end

function lockTarget(newTarget)
    matarLockNativo()
    target = newTarget
    locked = true
    lockBtn.Text = "🔒 LOCK: ON"
    lockBtn.BackgroundColor3 = CORES.on
    infoBox.Visible = true
    updateTargetInfo()
    criarHPBarDoAlvo(newTarget)
    setAutoRotate(false)
    pcall(function()
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.AutoRotate = false
            hum.CameraOffset = Vector3.new(0, 0, 0)
        end
    end)
    cameraTypeAntigo = camera.CameraType
    cameraModeAntigo = player.CameraMode
    camera.CameraType = Enum.CameraType.Scriptable
    forcarOrientacao()
    RunService:UnbindFromRenderStep("EZEK_Cam")
    RunService:BindToRenderStep("EZEK_Cam", Enum.RenderPriority.Camera.Value + 1, updateCamera)
    RunService:UnbindFromRenderStep("EZEK_Body")
    RunService:BindToRenderStep("EZEK_Body", Enum.RenderPriority.Character.Value + 10, updateBody)
    atualizarStatus()
end

function unlockTarget()
    locked = false
    target = nil
    lockBtn.Text = "🔓 LOCK: OFF"
    lockBtn.BackgroundColor3 = CORES.botao
    infoBox.Visible = false
    removerHPBarDoAlvo()
    RunService:UnbindFromRenderStep("EZEK_Cam")
    RunService:UnbindFromRenderStep("EZEK_Body")
    resetarCamera()
    pcall(function()
        if cameraTypeAntigo and cameraTypeAntigo ~= Enum.CameraType.Scriptable then
            if Workspace.CurrentCamera then
                Workspace.CurrentCamera.CameraType = cameraTypeAntigo
            end
        end
        if cameraModeAntigo then player.CameraMode = cameraModeAntigo end
    end)
    pcall(function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
    end)
    pcall(function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and camera then
            local look = camera.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 0.1 then
                root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
            end
        end
    end)
    setAutoRotate(true)
    atualizarStatus()
end

local function toggleLock()
    if locked then unlockTarget()
    else
        local t = findTarget()
        if t then lockTarget(t)
        else print("❌ Nenhum alvo no centro da tela! Mire no inimigo e tente de novo.") end
    end
end

lockBtn.MouseButton1Click:Connect(toggleLock)
espBtn.MouseButton1Click:Connect(toggleESP)

-- ============ INPUTS ============
local r1Pressionado, r2Pressionado, l1Pressionado, l2Pressionado = false, false, false, false
local ultimoToggleLock, ultimoToggleESP = 0, 0
local comboCooldown = 0.8

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if locked then
        if input.KeyCode == Enum.KeyCode.ButtonX or input.KeyCode == Enum.KeyCode.ButtonA
           or input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.Q
           or input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.ButtonR2
           or input.KeyCode == Enum.KeyCode.ButtonL1 or input.KeyCode == Enum.KeyCode.ButtonL2 then
            forcarOrientacao()
        end
    end
    if input.KeyCode == Enum.KeyCode.Q then toggleLock()
    elseif input.KeyCode == Enum.KeyCode.E then toggleESP() end
    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1Pressionado = true end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2Pressionado = true end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1Pressionado = true end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2Pressionado = true end
    if r1Pressionado and r2Pressionado then
        local agora = tick()
        if agora - ultimoToggleLock > comboCooldown then toggleLock(); ultimoToggleLock = agora end
    end
    if l1Pressionado and l2Pressionado then
        local agora = tick()
        if agora - ultimoToggleESP > comboCooldown then toggleESP(); ultimoToggleESP = agora end
    end
end)

UserInputService.InputEnded:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1Pressionado = false end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2Pressionado = false end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1Pressionado = false end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2Pressionado = false end
end)

-- ============ MORTE E RESPAWN ============
player.CharacterRemoving:Connect(function()
    locked = false
    target = nil
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
    end)
    pcall(function() removerHPBarDoAlvo() end)
    print("💀 [EZEK] Morreu — resetado!")
end)

player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    locked = false
    target = nil
    if Workspace.CurrentCamera then camera = Workspace.CurrentCamera end
    resetarCamera()
    pcall(function()
        if lockBtn then
            lockBtn.Text = "🔓 LOCK: OFF"
            lockBtn.BackgroundColor3 = CORES.botao
        end
        if infoBox then infoBox.Visible = false end
    end)
    local hum = newChar:WaitForChild("Humanoid", 5)
    if hum then
        hum.AutoRotate = true
        hum.CameraOffset = Vector3.new(0, 0, 0)
    end
    task.wait(0.5)
    pcall(function() removerHPBarDoAlvo() end)
    pcall(function() atualizarStatus() end)
    print("✅ [EZEK] Respawnou — resetado!")
end)

atualizarStatus()
print("✅ AIMLOCK DO EZEK v16.15 pronto!")
print("🎮 R1+R2 = Lock | L1+L2 = ESP")