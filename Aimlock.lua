-- EZEK v5 - ESP 2D tempo real + Lock sem tremor
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local VERSAO = "v5"
local MAX_DIST = 400
local INTERVALO_LISTA = 1

local ativo, alvo, espAtivo = false, nil, false
local hpBar, camConn = nil, nil
local filtros = {players=true, dummies=true, monstros=true, objetos=true}
local espEl = {}
local alvosESP = {}
local cache, cacheT = {}, 0

-- VIDA
local NV = {"Health","HP","health","hp","Vida","vida","Life","life","Hp","HpAtual","HealthPoints","CurrentHealth"}
local NM = {"MaxHealth","MaxHP","maxhealth","MaxHp","HPMAX","VidaMaxima","MaxVida","TotalHealth","MaxLife"}

local function getAtrib(m, lista)
    if not m then return nil end
    for _, n in ipairs(lista) do
        local v = m:GetAttribute(n)
        if type(v)=="number" and v>0 then return v end
    end
    for _, o in ipairs(m:GetChildren()) do
        if (o:IsA("NumberValue") or o:IsA("IntValue")) then
            for _, n in ipairs(lista) do if o.Name==n then return o.Value end end
        end
        if o:IsA("Folder") then
            for _, s in ipairs(o:GetChildren()) do
                if (s:IsA("NumberValue") or s:IsA("IntValue")) then
                    for _, n in ipairs(lista) do if s.Name==n then return s.Value end end
                end
            end
        end
    end
end

local function getVida(m)
    if not m then return nil,nil end
    local h = m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildWhichIsA("Humanoid",true)
    if h and h.Health>0 then return h.Health, h.MaxHealth end
    local hp = getAtrib(m, NV)
    if hp then return hp, getAtrib(m,NM) or hp end
    return nil,nil
end

local function temVida(m) local h=getVida(m) return h and h>0 end

local function pegarParte(m)
    if not m then return nil end
    if m:IsA("BasePart") then return m end
    return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
        or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
        or m:FindFirstChild("Root") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
end

local function temInteracao(m)
    if not m or not m:IsA("Model") then return false end
    if m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildWhichIsA("Humanoid",true) then return true end
    if m:FindFirstChildOfClass("ProximityPrompt") or m:FindFirstChildWhichIsA("ProximityPrompt",true) then return true end
    if m:FindFirstChildOfClass("ClickDetector") or m:FindFirstChildWhichIsA("ClickDetector",true) then return true end
    local n = string.lower(m.Name)
    for _, p in ipairs({"chest","bau","item","drop","loot","coin","door","porta","portal","crate","caixa","npc","shop","gift","key","chave","crystal","ore","minerio","boss","mob","enemy","monstro"}) do
        if n:find(p) then return true end
    end
    return false
end

local function getTipo(m)
    if not m then return "monstros" end
    if Players:GetPlayerFromCharacter(m) then return "players" end
    local hum = m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildWhichIsA("Humanoid",true)
    if hum or temVida(m) then
        local n = string.lower(m.Name)
        if n:find("dummy") or n:find("training") or n:find("test") or n:find("target") then return "dummies" end
        return "monstros"
    end
    return "objetos"
end

local function getTodos()
    local t = tick()
    if t - cacheT < 0.5 and #cache > 0 then
        local v = {}
        for _, m in ipairs(cache) do if m and m.Parent then table.insert(v,m) end end
        cache = v
        return v
    end
    local lista, vistos = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character.Parent then
            if not vistos[p.Character] then table.insert(lista,p.Character); vistos[p.Character]=true end
        end
    end
    local function proc(pasta, prof)
        if prof > 6 then return end
        for _, o in ipairs(pasta:GetChildren()) do
            if o:IsA("Model") and not vistos[o] and o ~= player.Character and temInteracao(o) and pegarParte(o) then
                table.insert(lista,o); vistos[o]=true
            end
            if o:IsA("Folder") or o:IsA("Model") then proc(o, prof+1) end
        end
    end
    proc(workspace, 0)
    cache = lista
    cacheT = t
    return lista
end

local function acharAlvo()
    local melhor, melhorAng = nil, math.rad(35)
    local cp = camera.CFrame.Position
    local cl = camera.CFrame.LookVector
    for _, m in ipairs(getTodos()) do
        if filtros[getTipo(m)] and temVida(m) then
            local parte = pegarParte(m)
            if parte then
                local dir = (parte.Position - cp).Unit
                local ang = math.acos(math.clamp(cl:Dot(dir),-1,1))
                if ang < melhorAng then melhorAng = ang; melhor = m end
            end
        end
    end
    return melhor
end

-- HP BAR
local function criarHPBar(m)
    if hpBar and hpBar.Parent then hpBar:Destroy() end
    local root = pegarParte(m)
    if not root then return end
    local bb = Instance.new("BillboardGui", m)
    bb.Adornee = root
    bb.Size = UDim2.new(0, 180, 0, 50)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    hpBar = bb
    local nome = Instance.new("TextLabel", bb)
    nome.Name = "N"
    nome.Size = UDim2.new(1,0,0,14)
    nome.BackgroundTransparency = 1
    nome.Text = m.Name
    nome.TextColor3 = Color3.new(1,1,1)
    nome.TextStrokeTransparency = 0
    nome.Font = Enum.Font.GothamBold
    nome.TextSize = 12
    local bg = Instance.new("Frame", bb)
    bg.Name = "B"
    bg.Size = UDim2.new(1,0,0,12)
    bg.Position = UDim2.new(0,0,0,16)
    bg.BackgroundColor3 = Color3.fromRGB(20,20,20)
    bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame", bg)
    fill.Name = "F"
    fill.Size = UDim2.new(1,0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(0,200,0)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local hp = Instance.new("TextLabel", bb)
    hp.Name = "H"
    hp.Size = UDim2.new(1,0,0,14)
    hp.Position = UDim2.new(0,0,0,30)
    hp.BackgroundTransparency = 1
    hp.TextColor3 = Color3.new(1,1,1)
    hp.TextStrokeTransparency = 0
    hp.Font = Enum.Font.GothamBold
    hp.TextSize = 11
    hp.Text = "?"
end

local function updateHPBar()
    if not hpBar or not alvo then return end
    local hp, mx = getVida(alvo)
    if not hp then return end
    mx = mx or 100
    local pct = math.clamp(hp/mx,0,1)
    local b = hpBar:FindFirstChild("B")
    if b then
        local f = b:FindFirstChild("F")
        if f then
            f.Size = UDim2.new(pct,0,1,0)
            f.BackgroundColor3 = pct>0.6 and Color3.fromRGB(0,200,0) or (pct>0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,50,50))
        end
    end
    local h = hpBar:FindFirstChild("H")
    if h then
        h.Text = string.format("%d/%d", math.floor(hp), math.floor(mx))
        h.TextColor3 = pct>0.6 and Color3.fromRGB(0,255,120) or (pct>0.3 and Color3.fromRGB(255,220,0) or Color3.fromRGB(255,80,80))
    end
end

-- LOOP LOCK
local function atualizar()
    if not ativo or not alvo or not alvo.Parent then return end
    local c = player.Character
    if not c then return end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChildOfClass("Humanoid")
    if not r or not h or h.Health <= 0 then return end
    local p = pegarParte(alvo)
    if not p then return end
    if not temVida(alvo) then desligarLock() return end

    -- 🛡️ ANTI-BOSS
    if h.CameraOffset.Magnitude > 0.01 then h.CameraOffset = Vector3.new(0,0,0) end
    if h.AutoRotate then h.AutoRotate = false end
    if h.PlatformStand then h.PlatformStand = false end
    if h.WalkSpeed < 16 then h.WalkSpeed = 16 end
    if h.JumpPower < 50 then h.JumpPower = 50 end
    if camera.CameraType ~= Enum.CameraType.Custom then camera.CameraType = Enum.CameraType.Custom end
    if camera.CameraSubject ~= h then camera.CameraSubject = h end
    
    local est = h:GetState()
    if est == Enum.HumanoidStateType.Physics or est == Enum.HumanoidStateType.GettingUp or est == Enum.HumanoidStateType.FallingDown then
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
    end

    -- Gira corpo
    local dir = p.Position - r.Position
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude > 0.01 then r.CFrame = CFrame.new(r.Position, r.Position + flat.Unit) end

    -- Câmera (sem tremor)
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, p.Position)

    updateHPBar()
end

function ligarLock()
    if ativo then return end
    local t = acharAlvo()
    if not t then print("❌ Sem alvo") return end
    alvo = t; ativo = true
    criarHPBar(t)
    local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if h then h.AutoRotate = false end
    -- 🔥 BindToRenderStep com prioridade DEPOIS da câmera (sem tremor)
    RunService:UnbindFromRenderStep("EZEK_CAM")
    RunService:BindToRenderStep("EZEK_CAM", Enum.RenderPriority.Camera.Value + 1, atualizar)
    print("🔒 Lock ON: "..t.Name)
end

function desligarLock()
    if not ativo then return end
    ativo = false; alvo = nil
    RunService:UnbindFromRenderStep("EZEK_CAM")
    if camConn then camConn:Disconnect(); camConn = nil end
    if hpBar then hpBar:Destroy(); hpBar = nil end
    local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if h then h.AutoRotate = true end
    pcall(function() camera.CameraType = Enum.CameraType.Custom; if h then camera.CameraSubject = h end end)
end

function toggleLock() if ativo then desligarLock() else ligarLock() end; attBts() end

-- ESP 2D TEMPO REAL
local espGui = Instance.new("ScreenGui")
espGui.Name = "EZEK_ESP2D_"..VERSAO
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.DisplayOrder = 999998
espGui.Parent = player:WaitForChild("PlayerGui")

local function cor(tipo)
    if tipo=="players" then return Color3.fromRGB(255,70,70)
    elseif tipo=="dummies" then return Color3.fromRGB(255,200,0)
    elseif tipo=="objetos" then return Color3.fromRGB(255,150,0)
    else return Color3.fromRGB(70,150,255) end
end

local function criarESP(m)
    if espEl[m] then return end
    local c = cor(getTipo(m))
    local cont = Instance.new("Frame", espGui)
    cont.BackgroundTransparency = 1
    cont.BorderSizePixel = 0
    local box = Instance.new("Frame", cont)
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    local st = Instance.new("UIStroke", box)
    st.Color = c; st.Thickness = 1.5; st.Transparency = 0.2
    local nm = Instance.new("TextLabel", cont)
    nm.BackgroundTransparency = 1
    nm.Font = Enum.Font.GothamBold
    nm.TextSize = 12
    nm.TextColor3 = c
    nm.TextStrokeTransparency = 0
    nm.TextStrokeColor3 = Color3.new(0,0,0)
    nm.Text = m.Name
    local hp = Instance.new("TextLabel", cont)
    hp.BackgroundTransparency = 1
    hp.Font = Enum.Font.GothamBold
    hp.TextSize = 11
    hp.TextColor3 = Color3.fromRGB(0,255,0)
    hp.TextStrokeTransparency = 0
    hp.TextStrokeColor3 = Color3.new(0,0,0)
    hp.Text = ""
    espEl[m] = {cont=cont, box=box, st=st, nm=nm, hp=hp}
end

local function limparESP()
    for _, d in pairs(espEl) do if d.cont and d.cont.Parent then d.cont:Destroy() end end
    espEl = {}
end

local function atualizarListaESP()
    local lista = {}
    for _, m in ipairs(getTodos()) do
        if filtros[getTipo(m)] then
            local parte = pegarParte(m)
            if parte then table.insert(lista, {model = m, parte = parte}) end
        end
    end
    alvosESP = lista
    for _, t in ipairs(alvosESP) do
        if not espEl[t.model] then criarESP(t.model) end
    end
    for m, d in pairs(espEl) do
        local achou = false
        for _, t in ipairs(alvosESP) do
            if t.model == m then achou = true break end
        end
        if not achou or not m.Parent then
            if d.cont and d.cont.Parent then d.cont:Destroy() end
            espEl[m] = nil
        end
    end
end

local function desenharESP()
    if not espAtivo then return end
    local c = player.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if not r then return end
    local mp = r.Position
    local cam = workspace.CurrentCamera
    if not cam then return end

    for _, t in ipairs(alvosESP) do
        local m = t.model
        local parte = t.parte
        if m.Parent and parte and parte.Parent then
            local dist = (parte.Position - mp).Magnitude
            local d = espEl[m]
            if d and dist <= MAX_DIST then
                local pos = parte.Position
                local top = cam:WorldToViewportPoint(pos + Vector3.new(0,2.5,0))
                local bot = cam:WorldToViewportPoint(pos - Vector3.new(0,2.5,0))
                if top.Z > 0 and bot.Z > 0 then
                    local alt = math.abs(top.Y - bot.Y)
                    if alt > 5 then
                        local lar = alt * 0.55
                        local cx = (top.X + bot.X) / 2
                        local cy = (top.Y + bot.Y) / 2
                        d.cont.Visible = true
                        d.box.Size = UDim2.new(0, lar, 0, alt)
                        d.box.Position = UDim2.new(0, cx - lar/2, 0, cy - alt/2)
                        d.nm.Size = UDim2.new(0, 150, 0, 16)
                        d.nm.Position = UDim2.new(0, cx - 75, 0, cy - alt/2 - 18)
                        d.hp.Size = UDim2.new(0, 150, 0, 14)
                        d.hp.Position = UDim2.new(0, cx - 75, 0, cy + alt/2 + 2)
                        local hp, mx = getVida(m)
                        if hp and hp > 0 then
                            mx = mx or 100
                            local pct = hp/mx
                            d.hp.Text = string.format("%d/%d | %dm", math.floor(hp), math.floor(mx), math.floor(dist))
                            d.hp.TextColor3 = pct>0.6 and Color3.fromRGB(0,255,0) or (pct>0.3 and Color3.fromRGB(255,220,0) or Color3.fromRGB(255,80,80))
                        else
                            d.hp.Text = math.floor(dist).."m"
                        end
                    else
                        d.cont.Visible = false
                    end
                else
                    d.cont.Visible = false
                end
            elseif d then
                d.cont.Visible = false
            end
        end
    end
end

local espListTh = nil
local espDrawConn = nil

function toggleESP()
    espAtivo = not espAtivo
    if espAtivo then
        atualizarListaESP()
        espListTh = task.spawn(function()
            while espAtivo do
                pcall(atualizarListaESP)
                task.wait(INTERVALO_LISTA)
            end
        end)
        espDrawConn = RunService.RenderStepped:Connect(desenharESP)
        print("👁️ ESP 2D ON")
    else
        espListTh = nil
        if espDrawConn then espDrawConn:Disconnect() espDrawConn = nil end
        limparESP()
        alvosESP = {}
        print("👁️ ESP 2D OFF")
    end
    attBts()
end

-- GUI
local CORES = {
    fundo=Color3.fromRGB(20,20,25), topo=Color3.fromRGB(30,30,40),
    botao=Color3.fromRGB(45,45,60), on=Color3.fromRGB(0,170,90),
    off=Color3.fromRGB(180,50,50), texto=Color3.fromRGB(240,240,240),
    fraco=Color3.fromRGB(160,160,170), borda=Color3.fromRGB(90,90,120),
    cOn=Color3.fromRGB(0,170,90), cOff=Color3.fromRGB(60,60,75),
}

local sg = Instance.new("ScreenGui")
sg.Name = "EZEK_"..VERSAO
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999999
sg.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 220, 0, 380)
main.Position = UDim2.new(0, 15, 0, 60)
main.BackgroundColor3 = CORES.fundo
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local mst = Instance.new("UIStroke", main)
mst.Color = CORES.borda; mst.Thickness = 1.5

local topBar = Instance.new("Frame", main)
topBar.Size = UDim2.new(1,0,0,36)
topBar.BackgroundColor3 = CORES.topo
topBar.BorderSizePixel = 0
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.new(1,-70,1,0)
title.Position = UDim2.new(0,10,0,0)
title.BackgroundTransparency = 1
title.Text = "🎯 EZEK "..VERSAO
title.TextColor3 = CORES.texto
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

local minBtn = Instance.new("TextButton", topBar)
minBtn.Size = UDim2.new(0,26,0,26)
minBtn.Position = UDim2.new(1,-60,0,5)
minBtn.BackgroundColor3 = CORES.botao
minBtn.Text = "—"; minBtn.TextColor3 = CORES.texto
minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 16
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0,6)

local closeBtn = Instance.new("TextButton", topBar)
closeBtn.Size = UDim2.new(0,26,0,26)
closeBtn.Position = UDim2.new(1,-30,0,5)
closeBtn.BackgroundColor3 = CORES.off
closeBtn.Text = "✕"; closeBtn.TextColor3 = CORES.texto
closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 14
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)

local content = Instance.new("Frame", main)
content.Size = UDim2.new(1,-10,1,-44)
content.Position = UDim2.new(0,5,0,40)
content.BackgroundTransparency = 1

local statusFrame = Instance.new("Frame", content)
statusFrame.Size = UDim2.new(1,0,0,46)
statusFrame.BackgroundColor3 = CORES.topo
statusFrame.BorderSizePixel = 0
Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0,8)
local statusLbl = Instance.new("TextLabel", statusFrame)
statusLbl.Size = UDim2.new(1,-12,1,-8)
statusLbl.Position = UDim2.new(0,6,0,4)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "🔓 Lock: OFF\n👁️ ESP: OFF"
statusLbl.TextColor3 = CORES.fraco
statusLbl.Font = Enum.Font.GothamMedium
statusLbl.TextSize = 12
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextYAlignment = Enum.TextYAlignment.Top

local function mkBtn(txt,y)
    local b = Instance.new("TextButton", content)
    b.Size = UDim2.new(1,0,0,38)
    b.Position = UDim2.new(0,0,0,y)
    b.BackgroundColor3 = CORES.botao
    b.Text = txt; b.TextColor3 = CORES.texto
    b.Font = Enum.Font.GothamBold; b.TextSize = 13
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    return b
end

local btnLock = mkBtn("🔓 LOCK: OFF", 54)
local btnEsp = mkBtn("👁️ ESP: OFF", 96)

local filtFrame = Instance.new("Frame", content)
filtFrame.Size = UDim2.new(1,0,0,126)
filtFrame.Position = UDim2.new(0,0,0,140)
filtFrame.BackgroundColor3 = CORES.topo
filtFrame.BorderSizePixel = 0
Instance.new("UICorner", filtFrame).CornerRadius = UDim.new(0,8)

local fTit = Instance.new("TextLabel", filtFrame)
fTit.Size = UDim2.new(1,-10,0,16)
fTit.Position = UDim2.new(0,6,0,2)
fTit.BackgroundTransparency = 1
fTit.Text = "🎛️ Filtros"
fTit.TextColor3 = CORES.fraco
fTit.Font = Enum.Font.GothamBold
fTit.TextSize = 10
fTit.TextXAlignment = Enum.TextXAlignment.Left

local function mkCheck(txt, chave, y)
    local cf = Instance.new("Frame", filtFrame)
    cf.Size = UDim2.new(1,-12,0,24)
    cf.Position = UDim2.new(0,6,0,y)
    cf.BackgroundTransparency = 1
    local box = Instance.new("TextButton", cf)
    box.Size = UDim2.new(0,20,0,20)
    box.Position = UDim2.new(0,0,0,2)
    box.BackgroundColor3 = filtros[chave] and CORES.cOn or CORES.cOff
    box.Text = filtros[chave] and "✓" or ""
    box.TextColor3 = CORES.texto
    box.Font = Enum.Font.GothamBold
    box.TextSize = 12
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,4)
    local lb = Instance.new("TextLabel", cf)
    lb.Size = UDim2.new(1,-26,1,0)
    lb.Position = UDim2.new(0,26,0,0)
    lb.BackgroundTransparency = 1
    lb.Text = txt
    lb.TextColor3 = CORES.texto
    lb.Font = Enum.Font.GothamMedium
    lb.TextSize = 12
    lb.TextXAlignment = Enum.TextXAlignment.Left
    local function tg()
        filtros[chave] = not filtros[chave]
        box.BackgroundColor3 = filtros[chave] and CORES.cOn or CORES.cOff
        box.Text = filtros[chave] and "✓" or ""
        if espAtivo then limparESP(); alvosESP={}; atualizarListaESP() end
    end
    box.MouseButton1Click:Connect(tg)
    lb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then tg() end
    end)
end

mkCheck("👤 Players","players",20)
mkCheck("🎯 Dummies","dummies",44)
mkCheck("👹 Monstros","monstros",68)
mkCheck("📦 Objetos","objetos",92)

local infoBox = Instance.new("Frame", content)
infoBox.Size = UDim2.new(1,0,0,44)
infoBox.Position = UDim2.new(0,0,0,272)
infoBox.BackgroundColor3 = CORES.topo
infoBox.BorderSizePixel = 0
infoBox.Visible = false
Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0,8)
local infoLbl = Instance.new("TextLabel", infoBox)
infoLbl.Size = UDim2.new(1,-12,1,-8)
infoLbl.Position = UDim2.new(0,6,0,4)
infoLbl.BackgroundTransparency = 1
infoLbl.Text = ""
infoLbl.TextColor3 = CORES.texto
infoLbl.Font = Enum.Font.GothamMedium
infoLbl.TextSize = 11
infoLbl.TextXAlignment = Enum.TextXAlignment.Left
infoLbl.TextYAlignment = Enum.TextYAlignment.Top

local function drag(f,h)
    h = h or f
    local dr, ds, sp
    h.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dr = true; ds = i.Position; sp = f.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dr and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            f.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dr = false end
    end)
end
drag(main, topBar)

local min = false
minBtn.MouseButton1Click:Connect(function()
    min = not min
    main.Size = min and UDim2.new(0,220,0,36) or UDim2.new(0,220,0,380)
    content.Visible = not min
    minBtn.Text = min and "+" or "—"
end)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    local rb = Instance.new("TextButton", sg)
    rb.Size = UDim2.new(0,44,0,44)
    rb.Position = UDim2.new(1,-60,0,20)
    rb.BackgroundColor3 = CORES.topo
    rb.Text = "🎯"; rb.TextSize = 20
    Instance.new("UICorner", rb).CornerRadius = UDim.new(1,0)
    drag(rb)
    rb.MouseButton1Click:Connect(function() main.Visible = true; rb:Destroy() end)
end)

function attBts()
    btnLock.Text = ativo and "🔒 LOCK: ON" or "🔓 LOCK: OFF"
    btnLock.BackgroundColor3 = ativo and CORES.on or CORES.botao
    btnEsp.Text = espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF"
    btnEsp.BackgroundColor3 = espAtivo and CORES.on or CORES.botao
    statusLbl.Text = (ativo and "🔒 Lock: ON" or "🔓 Lock: OFF").."\n"..(espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF")
    statusLbl.TextColor3 = (ativo or espAtivo) and CORES.on or CORES.fraco
    infoBox.Visible = ativo
    if ativo and alvo then
        local hp, mx = getVida(alvo)
        if hp then infoLbl.Text = string.format("🎯 %s\n❤️ %d/%d", alvo.Name, math.floor(hp), math.floor(mx or 100)) end
    end
end

btnLock.MouseButton1Click:Connect(toggleLock)
btnEsp.MouseButton1Click:Connect(toggleESP)

-- TECLADO + CONTROLE
local r1,r2,l1,l2 = false,false,false,false
local uL, uE = 0, 0

UIS.InputBegan:Connect(function(i, gp)
    local nosso = i.KeyCode == Enum.KeyCode.Q or i.KeyCode == Enum.KeyCode.E
        or i.KeyCode == Enum.KeyCode.ButtonR1 or i.KeyCode == Enum.KeyCode.ButtonR2
        or i.KeyCode == Enum.KeyCode.ButtonL1 or i.KeyCode == Enum.KeyCode.ButtonL2
    if gp and not nosso then return end
    if i.KeyCode == Enum.KeyCode.Q then toggleLock(); return end
    if i.KeyCode == Enum.KeyCode.E then toggleESP(); return end
    if i.KeyCode == Enum.KeyCode.ButtonR1 then r1 = true end
    if i.KeyCode == Enum.KeyCode.ButtonR2 then r2 = true end
    if i.KeyCode == Enum.KeyCode.ButtonL1 then l1 = true end
    if i.KeyCode == Enum.KeyCode.ButtonL2 then l2 = true end
    if r1 and r2 then
        local a = tick()
        if a-uL > 0.8 then toggleLock(); uL = a; r1=false; r2=false end
    end
    if l1 and l2 then
        local a = tick()
        if a-uE > 0.8 then toggleESP(); uE = a; l1=false; l2=false end
    end
end)

UIS.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.ButtonR1 then r1 = false end
    if i.KeyCode == Enum.KeyCode.ButtonR2 then r2 = false end
    if i.KeyCode == Enum.KeyCode.ButtonL1 then l1 = false end
    if i.KeyCode == Enum.KeyCode.ButtonL2 then l2 = false end
end)

player.CharacterRemoving:Connect(function()
    if ativo then desligarLock() end
    if espAtivo then toggleESP() end
end)

attBts()
print("⚡ EZEK "..VERSAO.." carregado! | Q=Lock E=ESP | R1+R2=Lock L1+L2=ESP")