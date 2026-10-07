-- ══════════════════════════════════════════════════════════
--   EZEK LOCK + ESP - v1 REWORK
--   🔒 Lock zero delay | 👁️ ESP completo | 📊 HP Bar
-- ══════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local VERSAO = "v1 REWORK"

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local DIST_CAM = 12

local ativo = false
local alvo = nil
local espAtivo = false
local transparenciasSalvas = {}
local espHighlights = {}
local espLabels = {}
local hpBarAlvo = nil

-- 🔥 FILTROS DO ESP
local filtros = { players = true, dummies = true, monstros = true }

-- ============ ESCONDE SEU BONECO ============
local function esconderBoneco(esconder)
    local char = player.Character
    if not char then return end
    if esconder then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
                if transparenciasSalvas[obj] == nil then
                    transparenciasSalvas[obj] = obj.LocalTransparencyModifier
                end
                obj.LocalTransparencyModifier = 1
            end
        end
    else
        for obj, valor in pairs(transparenciasSalvas) do
            if obj and obj.Parent then
                obj.LocalTransparencyModifier = valor
            end
        end
        transparenciasSalvas = {}
    end
end

-- ============ DETECÇÃO DE VIDA ============
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

-- ============ AUXILIARES ============
local function pegarParte(m)
    if not m then return nil end
    return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
        or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
        or m:FindFirstChild("Root") or m.PrimaryPart
end

local function getTodos()
    local lista, vistos = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and temVida(p.Character) then
            if not vistos[p.Character] then
                table.insert(lista, p.Character)
                vistos[p.Character] = true
            end
        end
    end
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and m ~= player.Character and not vistos[m] and temVida(m) and pegarParte(m) then
            table.insert(lista, m)
            vistos[m] = true
        end
    end
    return lista
end

local function acharAlvo()
    local melhor, melhorAng = nil, math.rad(35)
    local camPos = camera.CFrame.Position
    local camLook = camera.CFrame.LookVector

    for _, m in ipairs(getTodos()) do
        local parte = pegarParte(m)
        if parte then
            local dir = (parte.Position - camPos).Unit
            local ang = math.acos(math.clamp(camLook:Dot(dir), -1, 1))
            if ang < melhorAng then melhorAng = ang; melhor = m end
        end
    end
    return melhor
end

-- ============ HP BAR DO ALVO ============
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
    nomeLbl.Position = UDim2.new(0, 0, 0, 0)
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

-- ============ LOOP: LOCK ZERO DELAY ============
local function atualizar()
    if not ativo or not alvo or not alvo.Parent then return end

    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end

    local parteAlvo = pegarParte(alvo)
    if not parteAlvo then return end

    if not temVida(alvo) then
        desligarLock()
        return
    end

    local posAlvo = parteAlvo.Position
    local minhaPos = root.Position

    local dir = posAlvo - minhaPos
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude > 0.01 then
        root.CFrame = CFrame.lookAt(minhaPos, minhaPos + flat.Unit)
    end

    if camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
    end

    local camAlvo = Vector3.new(posAlvo.X, minhaPos.Y + 2.5, posAlvo.Z)

    local dirCam = camAlvo - minhaPos
    local flatCam = Vector3.new(dirCam.X, 0, dirCam.Z)
    if flatCam.Magnitude < 0.01 then return end
    flatCam = flatCam.Unit

    local camPos = minhaPos - flatCam * DIST_CAM + Vector3.new(0, 4, 0)

    camera.CFrame = CFrame.lookAt(camPos, camAlvo)
    camera.Focus = CFrame.new(camAlvo)

    atualizarHPBar()
end

-- ============ LOCK ============
function ligarLock()
    if ativo then return end
    local t = acharAlvo()
    if not t then print("❌ Nenhum alvo com vida na frente") return end
    alvo = t
    ativo = true

    esconderBoneco(true)
    criarHPBar(t)

    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.AutoRotate = false end

    RunService:UnbindFromRenderStep("EZEK_LOCK")
    RunService:BindToRenderStep("EZEK_LOCK", Enum.RenderPriority.Camera.Value + 1, atualizar)
    print("🔒 Lock ON: " .. alvo.Name)
end

function desligarLock()
    if not ativo then return end
    ativo = false
    alvo = nil

    RunService:UnbindFromRenderStep("EZEK_LOCK")
    esconderBoneco(false)

    if hpBarAlvo then hpBarAlvo:Destroy(); hpBarAlvo = nil end

    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.AutoRotate = true end

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

-- ============ ESP ============
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
    bb.MaxDistance = 300
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

    local atuais = {}
    for _, m in ipairs(getTodos()) do
        if filtros[getTipo(m)] then
            atuais[m] = true
            if not espHighlights[m] then criarESP(m) end
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

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    for m, lbl in pairs(espLabels) do
        if m.Parent and lbl.Parent and root then
            local hp, maxHp = getVida(m)
            local parteAlvo = pegarParte(m)
            if parteAlvo and hp and hp > 0 then
                maxHp = maxHp or 100
                local pct = hp / math.max(maxHp, 1)
                local dist = math.floor((parteAlvo.Position - root.Position).Magnitude)

                local cor = Color3.fromRGB(0, 255, 0)
                if pct < 0.3 then cor = Color3.fromRGB(255, 0, 0)
                elseif pct < 0.6 then cor = Color3.fromRGB(255, 255, 0) end

                lbl.TextColor3 = cor
                lbl.Text = string.format("%s\n%d/%d | %dm", m.Name, math.floor(hp), math.floor(maxHp), dist)
            end
        end
    end
end

local espConn = nil

function toggleESP()
    espAtivo = not espAtivo
    if espAtivo then
        for _, m in ipairs(getTodos()) do
            if filtros[getTipo(m)] then criarESP(m) end
        end
        if espConn then espConn:Disconnect() end
        espConn = RunService.Heartbeat:Connect(atualizarESP)
        print("👁️ ESP ON")
    else
        if espConn then espConn:Disconnect() espConn = nil end
        limparESP()
        print("👁️ ESP OFF")
    end
    atualizarBotoes()
end

-- ============ GUI ============
local CORES = {
    fundo = Color3.fromRGB(20,20,25),
    topo = Color3.fromRGB(30,30,40),
    botao = Color3.fromRGB(45,45,60),
    on = Color3.fromRGB(0,170,90),
    texto = Color3.fromRGB(240,240,240),
    textoFraco = Color3.fromRGB(160,160,170),
    borda = Color3.fromRGB(90,90,120),
    checkOn = Color3.fromRGB(0,170,90),
    checkOff = Color3.fromRGB(60,60,75),
}

local sg = Instance.new("ScreenGui")
sg.Name = "EZEK_" .. VERSAO:gsub(" ", "_")
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 180, 0, 290)
main.Position = UDim2.new(1, -200, 0, 100)
main.BackgroundColor3 = CORES.fundo
main.BorderSizePixel = 0
main.Active = true
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local ms = Instance.new("UIStroke")
ms.Color = CORES.borda; ms.Thickness = 1.5; ms.Parent = main

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 32)
topBar.BackgroundColor3 = CORES.topo
topBar.BorderSizePixel = 0
topBar.Parent = main
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -12, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🎯 EZEK " .. VERSAO
title.TextColor3 = CORES.texto
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local btnLock = Instance.new("TextButton")
btnLock.Size = UDim2.new(1, -16, 0, 36)
btnLock.Position = UDim2.new(0, 8, 0, 40)
btnLock.BackgroundColor3 = CORES.botao
btnLock.TextColor3 = CORES.texto
btnLock.Font = Enum.Font.GothamBold
btnLock.TextSize = 13
btnLock.Text = "🔓 LOCK: OFF"
btnLock.Parent = main
Instance.new("UICorner", btnLock).CornerRadius = UDim.new(0, 8)

local btnEsp = Instance.new("TextButton")
btnEsp.Size = UDim2.new(1, -16, 0, 36)
btnEsp.Position = UDim2.new(0, 8, 0, 82)
btnEsp.BackgroundColor3 = CORES.botao
btnEsp.TextColor3 = CORES.texto
btnEsp.Font = Enum.Font.GothamBold
btnEsp.TextSize = 13
btnEsp.Text = "👁️ ESP: OFF"
btnEsp.Parent = main
Instance.new("UICorner", btnEsp).CornerRadius = UDim.new(0, 8)

local filtroTit = Instance.new("TextLabel")
filtroTit.Size = UDim2.new(1, -16, 0, 18)
filtroTit.Position = UDim2.new(0, 8, 0, 126)
filtroTit.BackgroundTransparency = 1
filtroTit.Text = "🎛️ Filtros do ESP"
filtroTit.TextColor3 = CORES.textoFraco
filtroTit.Font = Enum.Font.GothamBold
filtroTit.TextSize = 11
filtroTit.TextXAlignment = Enum.TextXAlignment.Left
filtroTit.Parent = main

local function criarCheck(texto, chave, y)
    local cf = Instance.new("Frame")
    cf.Size = UDim2.new(1, -16, 0, 26)
    cf.Position = UDim2.new(0, 8, 0, y)
    cf.BackgroundTransparency = 1
    cf.Parent = main

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
    lb.TextSize = 12
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

criarCheck("👤 Players", "players", 148)
criarCheck("🎯 Dummies", "dummies", 178)
criarCheck("👹 Monstros", "monstros", 208)

-- Versão no rodapé
local versaoLbl = Instance.new("TextLabel")
versaoLbl.Size = UDim2.new(1, -16, 0, 14)
versaoLbl.Position = UDim2.new(0, 8, 1, -18)
versaoLbl.BackgroundTransparency = 1
versaoLbl.Text = "⚡ " .. VERSAO
versaoLbl.TextColor3 = CORES.textoFraco
versaoLbl.Font = Enum.Font.GothamBold
versaoLbl.TextSize = 10
versaoLbl.TextXAlignment = Enum.TextXAlignment.Center
versaoLbl.Parent = main

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
end

btnLock.MouseButton1Click:Connect(toggleLock)
btnEsp.MouseButton1Click:Connect(toggleESP)

-- Arrastar
local dragging, dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ============ TECLADO + CONTROLE ============
local r1, r2, l1, l2 = false, false, false, false
local ultLock, ultEsp = 0, 0

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    if input.KeyCode == Enum.KeyCode.Q then toggleLock() return end
    if input.KeyCode == Enum.KeyCode.E then toggleESP() return end

    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1 = true end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2 = true end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1 = true end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2 = true end

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
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1 = false end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2 = false end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1 = false end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2 = false end
end)

-- ============ RESPAWN ============
player.CharacterRemoving:Connect(function()
    if ativo then desligarLock() end
    if espAtivo then toggleESP() end
end)

atualizarBotoes()
print("═══════════════════════════════════════════")
print("⚡ EZEK LOCK + ESP - " .. VERSAO)
print("═══════════════════════════════════════════")
print("🎮 Q = Lock | E = ESP")
print("🎮 R1+R2 = Lock | L1+L2 = ESP")
print("═══════════════════════════════════════════")