-- EZEK v10 - ESTÁVEL (Base v7) + Otimização Essencial + UI Completa
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- 🔥 FAXINEIRO: Limpa qualquer porcaria de versões antigas que ficou na tela
for _, obj in pairs(player:WaitForChild("PlayerGui"):GetChildren()) do
    if obj:IsA("ScreenGui") and (string.find(obj.Name, "EZEK") or string.find(obj.Name, "Aimlock")) then
        obj:Destroy()
    end
end
pcall(function() RunService:UnbindFromRenderStep("EZEK_CAM") end)

local VERSAO = "v10"
local MAX_DIST = 400
local INTERVALO_LISTA = 1.5
local FOV_GRAUS = 30

local ativo, alvo, espAtivo = false, nil, false
local hpBar = nil
local filtros = {players=true, dummies=true, monstros=true, objetos=false}
local espEl = {}
local alvosESP = {}
local cache, cacheT = {}, 0

local previewEl = nil
local previewAlvo = nil
local attBts

local lastEspDraw = 0
local lastPreviewDraw = 0

local r1, r2, l1, l2 = false, false, false, false
local uL, uE = 0, 0

-- ===================== VIDA / UTIL =====================
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

local function getTipo(m)
    if not m then return "monstros" end
    if Players:GetPlayerFromCharacter(m) then return "players" end
    if m:FindFirstChildOfClass("Humanoid") or temVida(m) then
        local n = string.lower(m.Name)
        if n:find("dummy") or n:find("training") then return "dummies" end
        return "monstros"
    end
    return "objetos"
end

local function getTodos()
    local t = tick()
    if t - cacheT < INTERVALO_LISTA and #cache > 0 then
        local v = {}
        for _, m in ipairs(cache) do if m and m.Parent then table.insert(v,m) end end
        return v
    end
    local lista, vistos = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and temVida(p.Character) then
            table.insert(lista,p.Character); vistos[p.Character]=true
        end
    end
    local function proc(pasta, prof)
        if prof > 3 then return end
        for _, o in ipairs(pasta:GetChildren()) do
            if o:IsA("Model") and not vistos[o] and o ~= player.Character and temVida(o) and pegarParte(o) then
                table.insert(lista,o); vistos[o]=true
            elseif o:IsA("Folder") then
                proc(o, prof+1)
            end
        end
    end
    proc(workspace, 0)
    cache = lista; cacheT = t
    return lista
end

local function acharAlvo()
    local melhor, melhorAng = nil, math.rad(FOV_GRAUS)
    local cp = camera.CFrame.Position
    local cl = camera.CFrame.LookVector
    for _, m in ipairs(getTodos()) do
        if m ~= player.Character and filtros[getTipo(m)] and temVida(m) then
            local parte = pegarParte(m)
            if parte then
                -- 🔥 OTIMIZAÇÃO: Só pega se estiver a mais de 3 metros (evita grudar em você)
                if (parte.Position - cp).Magnitude > 3 then
                    local dir = (parte.Position - cp).Unit
                    local ang = math.acos(math.clamp(cl:Dot(dir),-1,1))
                    if ang < melhorAng then
                        melhorAng = ang
                        melhor = m
                    end
                end
            end
        end
    end
    return melhor
end

-- ===================== HP BAR (LOCK) =====================
local function criarHPBar(m)
    if hpBar and hpBar.Parent then hpBar:Destroy() end
    local root = pegarParte(m)
    if not root then return end
    local bb = Instance.new("BillboardGui", m)
    bb.Adornee = root; bb.Size = UDim2.new(0, 150, 0, 45); bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true
    hpBar = bb
    
    local nome = Instance.new("TextLabel", bb)
    nome.Name = "N"; nome.Size = UDim2.new(1,0,0,14); nome.Position = UDim2.new(0,0,0,0)
    nome.BackgroundTransparency = 1; nome.Text = m.Name; nome.TextColor3 = Color3.new(1,1,1)
    nome.TextStrokeTransparency = 0; nome.Font = Enum.Font.GothamBold; nome.TextSize = 12

    local bg = Instance.new("Frame", bb)
    bg.Name = "B"; bg.Size = UDim2.new(1,0,0,10); bg.Position = UDim2.new(0,0,0,16)
    bg.BackgroundColor3 = Color3.fromRGB(20,20,20); bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1,0)
    
    local fill = Instance.new("Frame", bg)
    fill.Name = "F"; fill.Size = UDim2.new(1,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(0,200,0); fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

    local hpText = Instance.new("TextLabel", bb)
    hpText.Name = "H"; hpText.Size = UDim2.new(1,0,0,14); hpText.Position = UDim2.new(0,0,0,28)
    hpText.BackgroundTransparency = 1; hpText.TextColor3 = Color3.new(1,1,1)
    hpText.TextStrokeTransparency = 0; hpText.Font = Enum.Font.GothamBold; hpText.TextSize = 11
end

local function updateHPBar()
    if not hpBar or not alvo then return end
    local hp, mx = getVida(alvo)
    if not hp then return end
    local pct = math.clamp(hp/(mx or 100),0,1)
    local f = hpBar:FindFirstChild("B") and hpBar.B:FindFirstChild("F")
    if f then
        f.Size = UDim2.new(pct,0,1,0)
        f.BackgroundColor3 = pct>0.6 and Color3.fromRGB(0,200,0) or (pct>0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,50,50))
    end
    local hTxt = hpBar:FindFirstChild("H")
    if hTxt then hTxt.Text = string.format("%d/%d", math.floor(hp), math.floor(mx or 100)) end
end

-- ===================== PARAR LOCK =====================
local function pararLock()
    if not ativo then return end
    ativo = false; alvo = nil
    RunService:UnbindFromRenderStep("EZEK_CAM")
    if hpBar then hpBar:Destroy(); hpBar = nil end
    local c = player.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then
        h.AutoRotate = true
        h.CameraOffset = Vector3.new(0,0,0)
        h.PlatformStand = false
    end
    pcall(function()
        camera.CameraType = Enum.CameraType.Custom
        if h then camera.CameraSubject = h end
    end)
    if attBts then attBts() end
end

-- ===================== LOOP LOCK =====================
local function atualizar()
    if not ativo or not alvo or not alvo.Parent or not temVida(alvo) then pararLock() return end
    local c = player.Character
    if not c then pararLock() return end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChildOfClass("Humanoid")
    local p = pegarParte(alvo)
    if not r or not h or not p then pararLock() return end

    if h.CameraOffset.Magnitude > 0.01 then h.CameraOffset = Vector3.new(0,0,0) end
    if h.AutoRotate then h.AutoRotate = false end
    if h.PlatformStand then h.PlatformStand = false end
    if h.WalkSpeed < 16 then h.WalkSpeed = 16 end
    if camera.CameraType ~= Enum.CameraType.Custom then camera.CameraType = Enum.CameraType.Custom end
    if camera.CameraSubject ~= h then camera.CameraSubject = h end

    local dir = p.Position - r.Position
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude > 0.01 then r.CFrame = CFrame.new(r.Position, r.Position + flat.Unit) end
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, p.Position)
    updateHPBar()
end

local function ligarLock()
    if ativo then return end
    local t = previewAlvo or acharAlvo()
    if not t then print("❌ Sem alvo") return end
    if previewEl then limparPreview() end
    alvo = t; ativo = true
    criarHPBar(t)
    RunService:UnbindFromRenderStep("EZEK_CAM")
    RunService:BindToRenderStep("EZEK_CAM", Enum.RenderPriority.Camera.Value + 1, atualizar)
    if attBts then attBts() end
end

-- ===================== ESP =====================
local espGui = Instance.new("ScreenGui")
espGui.Name = "EZEK_ESP_"..VERSAO
espGui.ResetOnSpawn = false; espGui.IgnoreGuiInset = true; espGui.DisplayOrder = 999998
espGui.Parent = player:WaitForChild("PlayerGui")

local function cor(tipo)
    if tipo=="players" then return Color3.fromRGB(255,70,70) else return Color3.fromRGB(70,150,255) end
end

local function criarESP(m)
    if espEl[m] then return end
    local cont = Instance.new("Frame", espGui)
    cont.BackgroundTransparency = 1; cont.BorderSizePixel = 0
    local box = Instance.new("Frame", cont)
    box.BackgroundTransparency = 1; box.BorderSizePixel = 0
    local st = Instance.new("UIStroke", box); st.Color = cor(getTipo(m)); st.Thickness = 1.5; st.Transparency = 0.2
    local nm = Instance.new("TextLabel", cont)
    nm.BackgroundTransparency = 1; nm.Font = Enum.Font.GothamBold; nm.TextSize = 11
    nm.TextColor3 = st.Color; nm.TextStrokeTransparency = 0; nm.Text = m.Name
    local hp = Instance.new("TextLabel", cont)
    hp.BackgroundTransparency = 1; hp.Font = Enum.Font.GothamBold; hp.TextSize = 10
    hp.TextColor3 = Color3.fromRGB(0,255,0); hp.TextStrokeTransparency = 0
    espEl[m] = {cont=cont, box=box, st=st, nm=nm, hp=hp}
end

local function limparESP()
    for _, d in pairs(espEl) do if d.cont then d.cont:Destroy() end end
    espEl = {}
end

local function atualizarListaESP()
    local lista = {}
    for _, m in ipairs(getTodos()) do
        if filtros[getTipo(m)] and pegarParte(m) then table.insert(lista, {model = m, parte = pegarParte(m)}) end
    end
    alvosESP = lista
    for _, t in ipairs(alvosESP) do if not espEl[t.model] then criarESP(t.model) end end
    for m, d in pairs(espEl) do
        local achou = false
        for _, t in ipairs(alvosESP) do if t.model == m then achou = true break end end
        if not achou or not m.Parent then d.cont:Destroy(); espEl[m] = nil end
    end
end

local function desenharESP()
    if not espAtivo then return end
    -- 🔥 OTIMIZAÇÃO: Desenha 15 vezes por segundo em vez de 60 (menos lag)
    if tick() - lastEspDraw < 0.06 then return end
    lastEspDraw = tick()

    local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not r then return end
    local mp = r.Position
    local cam = camera

    for _, t in ipairs(alvosESP) do
        local m = t.model
        local parte = t.parte
        local d = espEl[m]
        if d then
            if not m.Parent or not parte or not parte.Parent or not temVida(m) then
                d.cont.Visible = false
            else
                local dist = (parte.Position - mp).Magnitude
                if dist <= MAX_DIST then
                    local top = cam:WorldToViewportPoint(parte.Position + Vector3.new(0,2.5,0))
                    local bot = cam:WorldToViewportPoint(parte.Position - Vector3.new(0,2.5,0))
                    if top.Z > 0 and bot.Z > 0 then
                        local alt = math.abs(top.Y - bot.Y)
                        if alt > 5 then
                            local lar = alt * 0.55
                            local cx = (top.X + bot.X) / 2
                            local cy = (top.Y + bot.Y) / 2
                            d.cont.Visible = true
                            d.box.Size = UDim2.new(0, lar, 0, alt)
                            d.box.Position = UDim2.new(0, cx - lar/2, 0, cy - alt/2)
                            d.nm.Position = UDim2.new(0, cx - 75, 0, cy - alt/2 - 16)
                            d.nm.Size = UDim2.new(0, 150, 0, 14)
                            d.hp.Position = UDim2.new(0, cx - 75, 0, cy + alt/2 + 2)
                            d.hp.Size = UDim2.new(0, 150, 0, 14)
                            local hp, mx = getVida(m)
                            if hp then
                                local pct = hp/(mx or 100)
                                d.hp.Text = string.format("%d/%d | %dm", math.floor(hp), math.floor(mx or 100), math.floor(dist))
                                d.hp.TextColor3 = pct>0.6 and Color3.fromRGB(0,255,0) or (pct>0.3 and Color3.fromRGB(255,220,0) or Color3.fromRGB(255,80,80))
                            end
                        else d.cont.Visible = false end
                    else d.cont.Visible = false end
                else d.cont.Visible = false end
            end
        end
    end
end

local espListTh = nil
local espDrawConn = nil

local function toggleESP()
    espAtivo = not espAtivo
    if espAtivo then
        atualizarListaESP()
        espListTh = task.spawn(function()
            while espAtivo do pcall(atualizarListaESP); task.wait(INTERVALO_LISTA) end
        end)
        espDrawConn = RunService.RenderStepped:Connect(desenharESP)
    else
        espListTh = nil
        if espDrawConn then espDrawConn:Disconnect(); espDrawConn = nil end
        limparESP(); alvosESP = {}
    end
    if attBts then attBts() end
end

-- ===================== PREVIEW =====================
local function limparPreview()
    if previewEl and previewEl.cont and previewEl.cont.Parent then previewEl.cont:Destroy() end
    previewEl = nil; previewAlvo = nil
end

local function criarPreview(m)
    limparPreview()
    if not m or not m.Parent then return end
    local cont = Instance.new("Frame", espGui); cont.BackgroundTransparency = 1; cont.BorderSizePixel = 0; cont.Visible = false
    local box = Instance.new("Frame", cont); box.BackgroundTransparency = 1; box.BorderSizePixel = 0
    local st = Instance.new("UIStroke", box); st.Color = Color3.fromRGB(0, 255, 0); st.Thickness = 2; st.Transparency = 0
    previewEl = {cont = cont, box = box, st = st}; previewAlvo = m
end

local function atualizarPreview()
    if ativo then if previewEl then limparPreview() end return end
    
    if tick() - lastPreviewDraw > 0.1 then
        local t = acharAlvo()
        if t ~= previewAlvo then
            if t then criarPreview(t) else limparPreview() end
        end
        lastPreviewDraw = tick()
    end
    
    if previewEl and previewAlvo and previewAlvo.Parent and previewAlvo ~= player.Character then
        local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if r then
            local parte = pegarParte(previewAlvo)
            if parte then
                local top = camera:WorldToViewportPoint(parte.Position + Vector3.new(0,2.5,0))
                local bot = camera:WorldToViewportPoint(parte.Position - Vector3.new(0,2.5,0))
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
    end
end

RunService.RenderStepped:Connect(function() pcall(atualizarPreview) end)

-- ===================== GUI =====================
local CORES = {fundo=Color3.fromRGB(20,20,25), topo=Color3.fromRGB(30,30,40), botao=Color3.fromRGB(45,45,60), on=Color3.fromRGB(0,170,90), off=Color3.fromRGB(180,50,50), texto=Color3.fromRGB(240,240,240), fraco=Color3.fromRGB(160,160,170), borda=Color3.fromRGB(90,90,120)}

local sg = Instance.new("ScreenGui")
sg.Name = "EZEK_GUI_"..VERSAO
sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.DisplayOrder = 999999
sg.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 200, 0, 320); main.Position = UDim2.new(0, 15, 0, 60)
main.BackgroundColor3 = CORES.fundo; main.BorderSizePixel = 0; main.Active = true; main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local topBar = Instance.new("Frame", main)
topBar.Size = UDim2.new(1,0,0,36); topBar.BackgroundColor3 = CORES.topo; topBar.BorderSizePixel = 0
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.new(1,-70,1,0); title.Position = UDim2.new(0,10,0,0); title.BackgroundTransparency = 1
title.Text = "🎯 EZEK "..VERSAO; title.TextColor3 = CORES.texto; title.Font = Enum.Font.GothamBold; title.TextSize = 12; title.TextXAlignment = Enum.TextXAlignment.Left

local minBtn = Instance.new("TextButton", topBar)
minBtn.Size = UDim2.new(0,26,0,26); minBtn.Position = UDim2.new(1,-60,0,5); minBtn.BackgroundColor3 = CORES.botao
minBtn.Text = "—"; minBtn.TextColor3 = CORES.texto; minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 16
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0,6)

local closeBtn = Instance.new("TextButton", topBar)
closeBtn.Size = UDim2.new(0,26,0,26); closeBtn.Position = UDim2.new(1,-30,0,5); closeBtn.BackgroundColor3 = CORES.off
closeBtn.Text = "✕"; closeBtn.TextColor3 = CORES.texto; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 14
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)

local content = Instance.new("Frame", main)
content.Size = UDim2.new(1,-10,1,-44); content.Position = UDim2.new(0,5,0,40); content.BackgroundTransparency = 1

local statusFrame = Instance.new("Frame", content)
statusFrame.Size = UDim2.new(1,0,0,40); statusFrame.BackgroundColor3 = CORES.topo; statusFrame.BorderSizePixel = 0
Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0,8)

local statusLbl = Instance.new("TextLabel", statusFrame)
statusLbl.Size = UDim2.new(1,-12,1,-8); statusLbl.Position = UDim2.new(0,6,0,4); statusLbl.BackgroundTransparency = 1
statusLbl.Text = "🔓 Lock: OFF\n👁️ ESP: OFF"; statusLbl.TextColor3 = CORES.fraco; statusLbl.Font = Enum.Font.GothamMedium; statusLbl.TextSize = 11; statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local btnLock = Instance.new("TextButton", content)
btnLock.Size = UDim2.new(1,0,0,36); btnLock.Position = UDim2.new(0,0,0,46); btnLock.BackgroundColor3 = CORES.botao
btnLock.Text = "🔓 LOCK: OFF"; btnLock.TextColor3 = CORES.texto; btnLock.Font = Enum.Font.GothamBold; btnLock.TextSize = 12
Instance.new("UICorner", btnLock).CornerRadius = UDim.new(0,8)

local btnEsp = Instance.new("TextButton", content)
btnEsp.Size = UDim2.new(1,0,0,36); btnEsp.Position = UDim2.new(0,0,0,86); btnEsp.BackgroundColor3 = CORES.botao
btnEsp.Text = "👁️ ESP: OFF"; btnEsp.TextColor3 = CORES.texto; btnEsp.Font = Enum.Font.GothamBold; btnEsp.TextSize = 12
Instance.new("UICorner", btnEsp).CornerRadius = UDim.new(0,8)

local floatingBtn = Instance.new("TextButton", sg)
floatingBtn.Size = UDim2.new(0, 44, 0, 44); floatingBtn.Position = UDim2.new(1, -60, 0, 20)
floatingBtn.BackgroundColor3 = CORES.topo; floatingBtn.Text = "🎯"; floatingBtn.TextSize = 20
floatingBtn.Visible = false
Instance.new("UICorner", floatingBtn).CornerRadius = UDim.new(1,0)

local function drag(f,h)
    h = h or f; local dr, ds, sp
    h.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dr = true; ds = i.Position; sp = f.Position end end)
    UIS.InputChanged:Connect(function(i) if dr and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local d = i.Position - ds; f.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dr = false end end)
end
drag(main, topBar)
drag(floatingBtn)

local min = false
minBtn.MouseButton1Click:Connect(function()
    min = not min
    main.Size = min and UDim2.new(0,200,0,36) or UDim2.new(0,200,0,320)
    content.Visible = not min
    minBtn.Text = min and "+" or "—"
end)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    floatingBtn.Visible = true
end)

floatingBtn.MouseButton1Click:Connect(function()
    main.Visible = true
    floatingBtn.Visible = false
end)

attBts = function()
    btnLock.Text = ativo and "🔒 LOCK: ON" or "🔓 LOCK: OFF"
    btnLock.BackgroundColor3 = ativo and CORES.on or CORES.botao
    btnEsp.Text = espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF"
    btnEsp.BackgroundColor3 = espAtivo and CORES.on or CORES.botao
    statusLbl.Text = (ativo and "🔒 Lock: ON" or "🔓 Lock: OFF").."\n"..(espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF")
end

btnLock.MouseButton1Click:Connect(function() if ativo then pararLock() else ligarLock() end; attBts() end)
btnEsp.MouseButton1Click:Connect(function() toggleESP(); attBts() end)

UIS.InputBegan:Connect(function(i, gp)
    local nosso = i.KeyCode == Enum.KeyCode.P or i.KeyCode == Enum.KeyCode.O
        or i.KeyCode == Enum.KeyCode.ButtonR1 or i.KeyCode == Enum.KeyCode.ButtonR2
        or i.KeyCode == Enum.KeyCode.ButtonL1 or i.KeyCode == Enum.KeyCode.ButtonL2
    if gp and not nosso then return end
    
    if i.KeyCode == Enum.KeyCode.P then if ativo then pararLock() else ligarLock() end; attBts() return end
    if i.KeyCode == Enum.KeyCode.O then toggleESP(); attBts() return end

    if i.KeyCode == Enum.KeyCode.ButtonR1 then r1 = true end
    if i.KeyCode == Enum.KeyCode.ButtonR2 then r2 = true end
    if i.KeyCode == Enum.KeyCode.ButtonL1 then l1 = true end
    if i.KeyCode == Enum.KeyCode.ButtonL2 then l2 = true end

    if r1 and r2 then
        local a = tick()
        if a-uL > 0.8 then
            if ativo then pararLock() else ligarLock() end
            attBts(); uL = a; r1=false; r2=false
        end
    end
    if l1 and l2 then
        local a = tick()
        if a-uE > 0.8 then
            toggleESP(); attBts(); uE = a; l1=false; l2=false
        end
    end
end)

UIS.InputEnded:Connect(function(i)
    if i.KeyCode == Enum.KeyCode.ButtonR1 then r1 = false end
    if i.KeyCode == Enum.KeyCode.ButtonR2 then r2 = false end
    if i.KeyCode == Enum.KeyCode.ButtonL1 then l1 = false end
    if i.KeyCode == Enum.KeyCode.ButtonL2 then l2 = false end
end)

player.CharacterRemoving:Connect(function() if ativo then pararLock() end; if espAtivo then toggleESP() end; limparPreview() end)
attBts()
print("⚡ EZEK "..VERSAO.." carregado! | P=Lock O=ESP | R1+R2=Lock L1+L2=ESP")