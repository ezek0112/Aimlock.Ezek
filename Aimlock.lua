-- ══════════════════════════════════════════════════════════
--   EZEK LOCK + ESP - v3 REWORK (CÂMERA + ZOOM)
--   🔒 Lock (R1+R2) | 👁️ ESP (L1+L2) | 📷 Câmera segue
-- ══════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local VERSAO = "v3 REWORK"
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local MAX_DIST_ESP = 500
local ESP_INTERVALO = 0.3

local ativo = false
local alvo = nil
local espAtivo = false
local espHighlights = {}
local espLabels = {}
local hpBarAlvo = nil
local filtros = { players = true, dummies = true, monstros = true }

-- DETECÇÃO DE VIDA
local NOMES_VIDA = {"Health","HP","health","CurrentHealth","hp","Vida","vida","Life","life","Hp","HpAtual","HealthPoints"}
local NOMES_MAX = {"MaxHealth","MaxHP","maxhealth","MaxHp","HPMAX","VidaMaxima","MaxVida","TotalHealth","MaxLife"}

local function acharAtributoVida(m, lista)
    if not m then return nil end
    for _, nome in ipairs(lista) do
        local v = m:GetAttribute(nome)
        if v and type(v) == "number" then return v end
    end
    for _, obj in ipairs(m:GetChildren()) do
        for _, nome in ipairs(lista) do
            if obj.Name == nome and (obj:IsA("NumberValue") or obj:IsA("IntValue")) then
                return obj.Value
            end
        end
        if obj:IsA("Folder") then
            for _, sub in ipairs(obj:GetChildren()) do
                for _, nome in ipairs(lista) do
                    if sub.Name == nome and (sub:IsA("NumberValue") or sub:IsA("IntValue")) then
                        return sub.Value
                    end
                end
            end
        end
    end
    return nil
end

local function getVida(m)
    if not m then return nil, nil end
    local h = m:FindFirstChildOfClass("Humanoid")
    if h then return h.Health, h.MaxHealth end
    local hp = acharAtributoVida(m, NOMES_VIDA)
    local maxHp = acharAtributoVida(m, NOMES_MAX)
    if hp then return hp, maxHp or 100 end
    local humDesc = m:FindFirstChildWhichIsA("Humanoid", true)
    if humDesc then return humDesc.Health, humDesc.MaxHealth end
    return nil, nil
end

local function temVida(m)
    if not m then return false end
    local hp = getVida(m)
    return hp and hp > 0
end

local function getTipo(m)
    if not m then return "monstros" end
    if Players:GetPlayerFromCharacter(m) then return "players" end
    local n = string.lower(m.Name)
    if n:find("dummy") or n:find("training") or n:find("test") or n:find("target") then
        return "dummies"
    end
    return "monstros"
end

local function pegarParte(m)
    if not m then return nil end
    if m:IsA("BasePart") then return m end
    return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
        or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
        or m:FindFirstChild("Root") or m.PrimaryPart
        or m:FindFirstChildWhichIsA("BasePart")
end

local function pegarPeito(m)
    if not m then return nil end
    if m:IsA("BasePart") then return m end
    return m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
        or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Root")
        or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
end

-- CACHE
local cacheAlvos = {}
local cacheTempo = 0

local function getTodos()
    local agora = tick()
    if agora - cacheTempo < 0.5 and #cacheAlvos > 0 then
        local validos = {}
        for _, m in ipairs(cacheAlvos) do
            if m and m.Parent and temVida(m) then
                table.insert(validos, m)
            end
        end
        cacheAlvos = validos
        return cacheAlvos
    end

    local lista, vistos = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and temVida(p.Character) then
            if not vistos[p.Character] then
                table.insert(lista, p.Character)
                vistos[p.Character] = true
            end
        end
    end
    local function procurar(pasta, prof)
        if prof > 3 then return end
        for _, obj in ipairs(pasta:GetChildren()) do
            if (obj:IsA("Model") or obj:IsA("BasePart")) and not vistos[obj] then
                if obj ~= player.Character and temVida(obj) and pegarParte(obj) then
                    table.insert(lista, obj)
                    vistos[obj] = true
                end
            end
            if obj:IsA("Folder") or obj:IsA("Model") then
                procurar(obj, prof + 1)
            end
        end
    end
    procurar(workspace, 0)
    cacheAlvos = lista
    cacheTempo = agora
    return lista
end

local function acharAlvo()
    local melhor, melhorAng = nil, math.rad(35)
    local camPos = camera.CFrame.Position
    local camLook = camera.CFrame.LookVector

    for _, m in ipairs(getTodos()) do
        local parte = pegarParte(m)
        if parte then
            local dir = parte.Position - camPos
            local dist = dir.Magnitude
            if dist > 0.1 then
                local dirUnit = dir.Unit
                local ang = math.acos(math.clamp(camLook:Dot(dirUnit), -1, 1))
                if ang < melhorAng then
                    melhorAng = ang
                    melhor = m
                end
            end
        end
    end
    return melhor
end

-- HP BAR
local function criarHPBar(m)
    if hpBarAlvo and hpBarAlvo.Parent then hpBarAlvo:Destroy() end
    if not m or not m.Parent then return end
    local root = pegarParte(m)
    if not root then return end
    local bb = Instance.new("BillboardGui")
    bb.Adornee = root
    bb.Size = UDim2.new(0, 200, 0, 55)
    bb.StudsOffset = Vector3.new(0, 5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 1000
    bb.Parent = m
    hpBarAlvo = bb

    local nomeLbl = Instance.new("TextLabel")
    nomeLbl.Name = "Nome"
    nomeLbl.Size = UDim2.new(1, 0, 0, 16)
    nomeLbl.BackgroundTransparency = 1
    nomeLbl.Text = m.Name
    nomeLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nomeLbl.TextStrokeTransparency = 0
    nomeLbl.Font = Enum.Font.GothamBold
    nomeLbl.TextSize = 13
    nomeLbl.Parent = bb

    local bg = Instance.new("Frame")
    bg.Name = "BarBg"
    bg.Size = UDim2.new(1, 0, 0, 14)
    bg.Position = UDim2.new(0, 0, 0, 18)
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

    local hpLbl = Instance.new("TextLabel")
    hpLbl.Name = "HpLbl"
    hpLbl.Size = UDim2.new(1, 0, 0, 16)
    hpLbl.Position = UDim2.new(0, 0, 0, 36)
    hpLbl.BackgroundTransparency = 1
    hpLbl.Text = "?"
    hpLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpLbl.TextStrokeTransparency = 0
    hpLbl.Font = Enum.Font.GothamBold
    hpLbl.TextSize = 12
    hpLbl.Parent = bb
end

local function atualizarHPBar()
    if not hpBarAlvo or not hpBarAlvo.Parent or not alvo or not alvo.Parent then return end
    local hp, maxHp = getVida(alvo)
    if not hp then return end
    maxHp = maxHp or 100
    local pct = math.clamp(hp / math.max(maxHp, 1), 0, 1)

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
    local hpLbl = hpBarAlvo:FindFirstChild("HpLbl")
    if hpLbl then
        hpLbl.Text = string.format("%d/%d", math.floor(hp), math.floor(maxHp))
        if pct > 0.6 then hpLbl.TextColor3 = Color3.fromRGB(0, 255, 120)
        elseif pct > 0.3 then hpLbl.TextColor3 = Color3.fromRGB(255, 220, 0)
        else hpLbl.TextColor3 = Color3.fromRGB(255, 80, 80) end
    end
end

-- ══════════════════════════════════════════════════
-- 🔥 LOOP: CÂMERA SEGUE + ZOOM NATIVO
-- ══════════════════════════════════════════════════
local function atualizar()
    if not ativo or not alvo or not alvo.Parent then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end

    local parteAlvo = pegarPeito(alvo)
    if not parteAlvo then return end
    if not temVida(alvo) then desligarLock() return end

    -- 🛡️ Zera CameraOffset (anti-shake)
    if hum.CameraOffset ~= Vector3.new(0, 0, 0) then
        hum.CameraOffset = Vector3.new(0, 0, 0)
    end

    -- 🔥 Gira o CORPO pro alvo
    local minhaPos = root.Position
    local posAlvo = parteAlvo.Position
    local dir = posAlvo - minhaPos
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude > 0.01 then
        root.CFrame = CFrame.new(minhaPos, minhaPos + flat.Unit)
    end

    -- 🔥 CUSTOM (permite zoom nativo)
    if camera.CameraType ~= Enum.CameraType.Custom then
        camera.CameraType = Enum.CameraType.Custom
    end
    if camera.CameraSubject ~= hum then
        camera.CameraSubject = hum
    end

    -- 🔥 POSICIONA a câmera atrás olhando pro alvo
    local dirCam = posAlvo - minhaPos
    if dirCam.Magnitude < 0.1 then return end
    dirCam = dirCam.Unit

    local eyePos = minhaPos + Vector3.new(0, 3.5, 0)
    local camPos = eyePos - dirCam * 13

    camera.CFrame = CFrame.lookAt(camPos, posAlvo)
    camera.Focus = CFrame.new(posAlvo)

    -- 🛡️ Anti-knockback
    local vel = root.AssemblyLinearVelocity
    if vel.Magnitude > 200 then
        root.AssemblyLinearVelocity = vel.Unit * 50
    end

    atualizarHPBar()
end

function ligarLock()
    if ativo then return end
    local t = acharAlvo()
    if not t then print("❌ Nenhum alvo") return end
    alvo = t
    ativo = true
    criarHPBar(t)

    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.AutoRotate = false
        hum.CameraOffset = Vector3.new(0, 0, 0)
    end

    RunService:UnbindFromRenderStep("EZEK_LOCK")
    RunService:BindToRenderStep("EZEK_LOCK", Enum.RenderPriority.Camera.Value + 1, atualizar)
    print("🔒 Lock ON: " .. alvo.Name)
end

function desligarLock()
    if not ativo then return end
    ativo = false
    alvo = nil

    RunService:UnbindFromRenderStep("EZEK_LOCK")

    if hpBarAlvo then hpBarAlvo:Destroy(); hpBarAlvo = nil end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.AutoRotate = true
        hum.CameraOffset = Vector3.new(0, 0, 0)
    end
    pcall(function()
        camera.CameraType = Enum.CameraType.Custom
        if hum then camera.CameraSubject = hum end
    end)
    print("🔓 Lock OFF")
end

function toggleLock()
    if ativo then desligarLock() else ligarLock() end
    atualizarBotoes()
end

-- ESP
local function criarESP(m)
    if espHighlights[m] then return end
    local root = pegarParte(m)
    if not root then return end

    local tipo = getTipo(m)
    local cor
    if tipo == "players" then cor = Color3.fromRGB(255, 70, 70)
    elseif tipo == "dummies" then cor = Color3.fromRGB(255, 200, 0)
    else cor = Color3.fromRGB(70, 150, 255) end

    local hl = Instance.new("Highlight")
    hl.FillColor = cor
    hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0.2
    hl.Parent = m
    espHighlights[m] = hl

    local bb = Instance.new("BillboardGui")
    bb.Adornee = root
    bb.Size = UDim2.new(0, 180, 0, 45)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = MAX_DIST_ESP
    bb.Parent = m

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.7
    lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextWrapped = true
    lbl.Text = m.Name
    lbl.Parent = bb
    espLabels[m] = lbl
end

local function limparESP()
    for m, hl in pairs(espHighlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    for m, lbl in pairs(espLabels) do
        if lbl and lbl.Parent then lbl.Parent:Destroy() end
    end
    espHighlights = {}
    espLabels = {}
end

local function atualizarESP()
    if not espAtivo then return end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local minhaPos = root.Position

    local atuais = {}
    local todos = getTodos()

    for _, m in ipairs(todos) do
        if filtros[getTipo(m)] then
            atuais[m] = true
            if not espHighlights[m] then criarESP(m) end

            local parteAlvo = pegarParte(m)
            if parteAlvo then
                local dist = (parteAlvo.Position - minhaPos).Magnitude
                if dist > MAX_DIST_ESP then
                    if espHighlights[m] and espHighlights[m].Parent then espHighlights[m]:Destroy() end
                    espHighlights[m] = nil
                    if espLabels[m] and espLabels[m].Parent then espLabels[m].Parent:Destroy() end
                    espLabels[m] = nil
                    atuais[m] = nil
                end
            end
        end
    end

    for m, hl in pairs(espHighlights) do
        if not atuais[m] or not m.Parent then
            if hl and hl.Parent then hl:Destroy() end
            espHighlights[m] = nil
            if espLabels[m] and espLabels[m].Parent then espLabels[m].Parent:Destroy() end
            espLabels[m] = nil
        end
    end

    for m, lbl in pairs(espLabels) do
        if m.Parent and lbl.Parent then
            local hp, maxHp = getVida(m)
            local parteAlvo = pegarParte(m)
            if parteAlvo and hp and hp > 0 then
                maxHp = maxHp or 100
                local pct = hp / math.max(maxHp, 1)
                local dist = math.floor((parteAlvo.Position - minhaPos).Magnitude)

                local cor = Color3.fromRGB(0, 255, 0)
                if pct < 0.3 then cor = Color3.fromRGB(255, 0, 0)
                elseif pct < 0.6 then cor = Color3.fromRGB(255, 255, 0) end

                lbl.TextColor3 = cor
                lbl.Text = string.format("%s\n%d/%d | %dm", m.Name, math.floor(hp), math.floor(maxHp), dist)
            end
        end
    end
end

local espThread = nil

function toggleESP()
    espAtivo = not espAtivo
    if espAtivo then
        for _, m in ipairs(getTodos()) do
            if filtros[getTipo(m)] then criarESP(m) end
        end
        espThread = task.spawn(function()
            while espAtivo do
                pcall(atualizarESP)
                task.wait(ESP_INTERVALO)
            end
        end)
        print("👁️ ESP ON")
    else
        espThread = nil
        limparESP()
        print("👁️ ESP OFF")
    end
    atualizarBotoes()
end

-- GUI
local CORES = {
    fundo = Color3.fromRGB(20,20,25), topo = Color3.fromRGB(30,30,40),
    botao = Color3.fromRGB(45,45,60), on = Color3.fromRGB(0,170,90),
    off = Color3.fromRGB(180,50,50), texto = Color3.fromRGB(240,240,240),
    textoFraco = Color3.fromRGB(160,160,170), borda = Color3.fromRGB(90,90,120),
    checkOn = Color3.fromRGB(0,170,90), checkOff = Color3.fromRGB(60,60,75),
}

local sg = Instance.new("ScreenGui")
sg.Name = "EZEK_" .. VERSAO:gsub(" ", "_")
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999999
sg.Parent = player:WaitForChild("PlayerGui")

local tamW, tamH = 240, 440
local tamanhoNormal = UDim2.new(0, tamW, 0, tamH)
local tamanhoMin = UDim2.new(0, tamW, 0, 40)

local main = Instance.new("Frame")
main.Size = tamanhoNormal
main.Position = UDim2.new(0, 20, 0, 60)
main.BackgroundColor3 = CORES.fundo
main.BorderSizePixel = 0
main.Active = false
main.ClipsDescendants = true
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local ms = Instance.new("UIStroke")
ms.Color = CORES.borda; ms.Thickness = 1.5; ms.Parent = main

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = CORES.topo
topBar.BorderSizePixel = 0
topBar.Active = true
topBar.Parent = main
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🛡️ EZEK " .. VERSAO
title.TextColor3 = CORES.texto
title.Font = Enum.Font.GothamBold
title.TextSize = 11
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
scroll.CanvasSize = UDim2.new(0, 0, 0, 420)
scroll.Parent = main

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -10, 0, 420)
content.BackgroundTransparency = 1
content.Parent = scroll

local statusFrame = Instance.new("Frame")
statusFrame.Size = UDim2.new(1, 0, 0, 56)
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
    b.Font = Enum.Font.GothamBold; b.TextSize = 14
    b.Parent = content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local btnLock = criarBotao("🔓 LOCK: OFF", 66)
local btnEsp = criarBotao("👁️ ESP: OFF", 116)

local filtroFrame = Instance.new("Frame")
filtroFrame.Size = UDim2.new(1, 0, 0, 110)
filtroFrame.Position = UDim2.new(0, 0, 0, 166)
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
        if espAtivo then
            for m, hl in pairs(espHighlights) do
                if hl and hl.Parent then hl:Destroy() end
                espHighlights[m] = nil
                if espLabels[m] and espLabels[m].Parent then espLabels[m].Parent:Destroy() end
                espLabels[m] = nil
            end
        end
    end
    box.MouseButton1Click:Connect(toggle)
    lb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            toggle()
        end
    end)
end

criarCheck("👤 Players", "players", 26)
criarCheck("🎯 Dummies", "dummies", 56)
criarCheck("👹 Monstros", "monstros", 86)

local infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1, 0, 0, 55)
infoBox.Position = UDim2.new(0, 0, 0, 286)
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

local minimized = false
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

function atualizarBotoes()
    if ativo then
        btnLock.Text = "🔒 LOCK: ON"
        btnLock.BackgroundColor3 = CORES.on
    else
        btnLock.Text = "🔓 LOCK: OFF"
        btnLock.BackgroundColor3 = CORES.botao
    end
    if espAtivo then
        btnEsp.Text = "👁️ ESP: ON"
        btnEsp.BackgroundColor3 = CORES.on
    else
        btnEsp.Text = "👁️ ESP: OFF"
        btnEsp.BackgroundColor3 = CORES.botao
    end

    statusLabel.Text = (ativo and "🔒 Lock: ON" or "🔓 Lock: OFF") .. "\n"
        .. (espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF")
    statusLabel.TextColor3 = (ativo or espAtivo) and CORES.on or CORES.textoFraco

    infoBox.Visible = ativo
    if ativo and alvo then
        local hp, maxHp = getVida(alvo)
        if hp then
            infoLabel.Text = string.format("🎯 Alvo: %s\n❤️ %d/%d", alvo.Name, math.floor(hp), math.floor(maxHp or 100))
        else
            infoLabel.Text = "🎯 Alvo: " .. alvo.Name
        end
    end
end

btnLock.MouseButton1Click:Connect(toggleLock)
btnEsp.MouseButton1Click:Connect(toggleESP)

-- ══════════════════════════════════════════════════
-- 🎮 CONTROLES (R1+R2 | L1+L2)
-- ══════════════════════════════════════════════════
local r1, r2, l1, l2 = false, false, false, false
local ultLock, ultEsp = 0, 0

local function processarBotao(nome, state)
    if state == Enum.UserInputState.Begin then
        if nome == "EZEK_R1" then r1 = true end
        if nome == "EZEK_R2" then r2 = true end
        if nome == "EZEK_L1" then l1 = true end
        if nome == "EZEK_L2" then l2 = true end

        if r1 and r2 then
            local a = tick()
            if a - ultLock > 0.8 then
                toggleLock()
                ultLock = a
                r1 = false
                r2 = false
            end
        end
        if l1 and l2 then
            local a = tick()
            if a - ultEsp > 0.8 then
                toggleESP()
                ultEsp = a
                l1 = false
                l2 = false
            end
        end
    elseif state == Enum.UserInputState.End then
        if nome == "EZEK_R1" then r1 = false end
        if nome == "EZEK_R2" then r2 = false end
        if nome == "EZEK_L1" then l1 = false end
        if nome == "EZEK_L2" then l2 = false end
    end
    return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority("EZEK_R1", processarBotao, false, 3000, Enum.KeyCode.ButtonR1)
ContextActionService:BindActionAtPriority("EZEK_R2", processarBotao, false, 3000, Enum.KeyCode.ButtonR2)
ContextActionService:BindActionAtPriority("EZEK_L1", processarBotao, false, 3000, Enum.KeyCode.ButtonL1)
ContextActionService:BindActionAtPriority("EZEK_L2", processarBotao, false, 3000, Enum.KeyCode.ButtonL2)

-- 🎹 Teclado Q/E
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Q then toggleLock() return end
    if input.KeyCode == Enum.KeyCode.E then toggleESP() return end
end)

player.CharacterRemoving:Connect(function()
    if ativo then desligarLock() end
    if espAtivo then toggleESP() end
end)

atualizarBotoes()
print("═══════════════════════════════════════════")
print("🛡️ EZEK LOCK + ESP - " .. VERSAO)
print("═══════════════════════════════════════════")
print("🎮 R1+R2 = Lock | L1+L2 = ESP")
print("📷 Câmera segue o alvo + Zoom nativo")
print("═══════════════════════════════════════════")