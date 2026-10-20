-- EZEK v8 - OTIMIZADO PARA MOBILE (Menos Lag)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local VERSAO = "v8-Otimizado"
local MAX_DIST = 400
local INTERVALO_LISTA = 1.5 -- Atualiza a lista de inimigos mais devagar
local FOV_GRAUS = 30

local ativo, alvo, espAtivo = false, nil, false
local hpBar = nil
local filtros = {players=true, dummies=true, monstros=true, objetos=false} -- Desliguei objetos pra ajudar no lag
local espEl = {}
local alvosESP = {}
local cache, cacheT = {}, 0

local previewEl = nil
local previewAlvo = nil
local attBts

-- OTIMIZAÇÃO: Controle de tempo para não desenhar toda hora
local lastEspDraw = 0
local lastPreviewDraw = 0

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
    return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
end

local function temInteracao(m)
    if not m or not m:IsA("Model") then return false end
    if m:FindFirstChildOfClass("Humanoid") then return true end
    return false -- OTIMIZAÇÃO: Só foca em bichos/jogadores, ignora baús pra não lagar
end

local function getTipo(m)
    if not m then return "monstros" end
    if Players:GetPlayerFromCharacter(m) then return "players" end
    if m:FindFirstChildOfClass("Humanoid") or temVida(m) then return "monstros" end
    return "objetos"
end

local function getTodos()
    local t = tick()
    if t - cacheT < INTERVALO_LISTA and #cache > 0 then
        return cache
    end
    local lista, vistos = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and temVida(p.Character) then
            table.insert(lista,p.Character); vistos[p.Character]=true
        end
    end
    local function proc(pasta, prof)
        if prof > 4 then return end -- OTIMIZAÇÃO: Não procura tão fundo
        for _, o in ipairs(pasta:GetChildren()) do
            if o:IsA("Model") and not vistos[o] and temInteracao(o) and temVida(o) then
                table.insert(lista,o); vistos[o]=true
            elseif o:IsA("Folder") then
                proc(o, prof+1)
            end
        end
    end
    proc(workspace, 0)
    cache = lista
    cacheT = t
    return lista
end

local function acharAlvo()
    local melhor, melhorAng = nil, math.rad(FOV_GRAUS)
    local cp = camera.CFrame.Position
    local cl = camera.CFrame.LookVector
    for _, m in ipairs(getTodos()) do
        if filtros[getTipo(m)] and temVida(m) then
            local parte = pegarParte(m)
            if parte then
                local dir = (parte.Position - cp).Unit
                local ang = math.acos(math.clamp(cl:Dot(dir),-1,1))
                if ang < melhorAng then
                    melhorAng = ang
                    melhor = m
                end
            end
        end
    end
    return melhor
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
    end
    pcall(function()
        camera.CameraType = Enum.CameraType.Custom
        if h then camera.CameraSubject = h end
    end)
    if attBts then attBts() end
    print("🔓 Lock OFF")
end

-- ===================== HP BAR =====================
local function criarHPBar(m)
    if hpBar then hpBar:Destroy() end
    local root = pegarParte(m)
    if not root then return end
    local bb = Instance.new("BillboardGui", m)
    bb.Adornee = root; bb.Size = UDim2.new(0, 150, 0, 40); bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true
    hpBar = bb
    local bg = Instance.new("Frame", bb); bg.Name = "B"; bg.Size = UDim2.new(1,0,0,10); bg.Position = UDim2.new(0,0,0,20); bg.BackgroundColor3 = Color3.new(0,0,0); bg.BorderSizePixel = 0
    local fill = Instance.new("Frame", bg); fill.Name = "F"; fill.Size = UDim2.new(1,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(0,200,0); fill.BorderSizePixel = 0
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

    if h.AutoRotate then h.AutoRotate = false end
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
    if previewEl then previewEl.cont.Visible = false end
    alvo = t; ativo = true
    criarHPBar(t)
    RunService:UnbindFromRenderStep("EZEK_CAM")
    RunService:BindToRenderStep("EZEK_CAM", Enum.RenderPriority.Camera.Value + 1, atualizar)
    print("🔒 Lock ON: "..t.Name)
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
    local st = Instance.new("UIStroke", box); st.Color = cor(getTipo(m)); st.Thickness = 1; st.Transparency = 0.3
    local nm = Instance.new("TextLabel", cont); nm.BackgroundTransparency = 1; nm.Font = Enum.Font.Gotham; nm.TextSize = 10; nm.TextColor3 = st.Color; nm.TextStrokeTransparency = 0; nm.Text = m.Name
    local hp = Instance.new("TextLabel", cont); hp.BackgroundTransparency = 1; hp.Font = Enum.Font.Gotham; hp.TextSize = 10; hp.TextColor3 = Color3.fromRGB(0,255,0); hp.TextStrokeTransparency = 0
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
    
    -- OTIMIZAÇÃO CRÍTICA: Só desenha 15 vezes por segundo (0.06s)
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
                    local top = cam:WorldToViewportPoint(parte.Position + Vector3.new(0,2,0))
                    local bot = cam:WorldToViewportPoint(parte.Position - Vector3.new(0,2,0))
                    if top.Z > 0 and bot.Z > 0 then
                        local alt = math.abs(top.Y - bot.Y)
                        if alt > 5 then
                            local lar = alt * 0.5
                            local cx = (top.X + bot.X) / 2
                            local cy = (top.Y + bot.Y) / 2
                            d.cont.Visible = true
                            d.box.Size = UDim2.new(0, lar, 0, alt)
                            d.box.Position = UDim2.new(0, cx - lar/2, 0, cy - alt/2)
                            d.nm.Position = UDim2.new(0, cx - 50, 0, cy - alt/2 - 14)
                            d.nm.Size = UDim2.new(0, 100, 0, 14)
                            d.hp.Position = UDim2.new(0, cx - 50, 0, cy + alt/2 + 2)
                            d.hp.Size = UDim2.new(0, 100, 0, 12)
                            local hp, mx = getVida(m)
                            if hp then d.hp.Text = math.floor(hp).."/"..math.floor(mx or 100) end
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
        print("👁️ ESP ON")
    else
        espListTh = nil
        if espDrawConn then espDrawConn:Disconnect(); espDrawConn = nil end
        limparESP(); alvosESP = {}
        print("👁️ ESP OFF")
    end
end

-- ===================== PREVIEW =====================
local function limparPreview()
    if previewEl and previewEl.cont then previewEl.cont:Destroy() end
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
    
    -- OTIMIZAÇÃO: Só procura alvo 10 vezes por segundo
    if tick() - lastPreviewDraw > 0.1 then
        local t = acharAlvo()
        if t ~= previewAlvo then
            if t then criarPreview(t) else limparPreview() end
        end
        lastPreviewDraw = tick()
    end
    
    if previewEl and previewAlvo and previewAlvo.Parent then
        local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if r then
            local parte = pegarParte(previewAlvo)
            if parte then
                local top = camera:WorldToViewportPoint(parte.Position + Vector3.new(0,2,0))
                local bot = camera:WorldToViewportPoint(parte.Position - Vector3.new(0,2,0))
                if top.Z > 0 and bot.Z > 0 then
                    local alt = math.abs(top.Y - bot.Y)
                    if alt > 5 then
                        local lar = alt * 0.5; local cx = (top.X + bot.X) / 2; local cy = (top.Y + bot.Y) / 2
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
local CORES = {fundo=Color3.fromRGB(20,20,25), topo=Color3.fromRGB(30,30,40), botao=Color3.fromRGB(45,45,60), on=Color3.fromRGB(0,170,90), off=Color3.fromRGB(180,50,50), texto=Color3.fromRGB(240,240,240), fraco=Color3.fromRGB(160,160,170), borda=Color3.fromRGB(90,90,120), cOn=Color3.fromRGB(0,170,90), cOff=Color3.fromRGB(60,60,75)}
local sg = Instance.new("ScreenGui"); sg.Name = "EZEK_GUI_"..VERSAO; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.DisplayOrder = 999999; sg.Parent = player:WaitForChild("PlayerGui")
local main = Instance.new("Frame", sg); main.Size = UDim2.new(0, 200, 0, 320); main.Position = UDim2.new(0, 15, 0, 60); main.BackgroundColor3 = CORES.fundo; main.BorderSizePixel = 0; main.Active = true; main.ClipsDescendants = true; Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local topBar = Instance.new("Frame", main); topBar.Size = UDim2.new(1,0,0,36); topBar.BackgroundColor3 = CORES.topo; topBar.BorderSizePixel = 0; Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)
local title = Instance.new("TextLabel", topBar); title.Size = UDim2.new(1,-70,1,0); title.Position = UDim2.new(0,10,0,0); title.BackgroundTransparency = 1; title.Text = "🎯 EZEK "..VERSAO; title.TextColor3 = CORES.texto; title.Font = Enum.Font.GothamBold; title.TextSize = 12; title.TextXAlignment = Enum.TextXAlignment.Left
local minBtn = Instance.new("TextButton", topBar); minBtn.Size = UDim2.new(0,26,0,26); minBtn.Position = UDim2.new(1,-60,0,5); minBtn.BackgroundColor3 = CORES.botao; minBtn.Text = "—"; minBtn.TextColor3 = CORES.texto; Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0,6)
local closeBtn = Instance.new("TextButton", topBar); closeBtn.Size = UDim2.new(0,26,0,26); closeBtn.Position = UDim2.new(1,-30,0,5); closeBtn.BackgroundColor3 = CORES.off; closeBtn.Text = "✕"; closeBtn.TextColor3 = CORES.texto; Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)
local content = Instance.new("Frame", main); content.Size = UDim2.new(1,-10,1,-44); content.Position = UDim2.new(0,5,0,40); content.BackgroundTransparency = 1
local statusFrame = Instance.new("Frame", content); statusFrame.Size = UDim2.new(1,0,0,40); statusFrame.BackgroundColor3 = CORES.topo; statusFrame.BorderSizePixel = 0; Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0,8)
local statusLbl = Instance.new("TextLabel", statusFrame); statusLbl.Size = UDim2.new(1,-12,1,-8); statusLbl.Position = UDim2.new(0,6,0,4); statusLbl.BackgroundTransparency = 1; statusLbl.Text = "🔓 Lock: OFF\n👁️ ESP: OFF"; statusLbl.TextColor3 = CORES.fraco; statusLbl.Font = Enum.Font.GothamMedium; statusLbl.TextSize = 11; statusLbl.TextXAlignment = Enum.TextXAlignment.Left
local btnLock = Instance.new("TextButton", content); btnLock.Size = UDim2.new(1,0,0,36); btnLock.Position = UDim2.new(0,0,0,46); btnLock.BackgroundColor3 = CORES.botao; btnLock.Text = "🔓 LOCK: OFF"; btnLock.TextColor3 = CORES.texto; btnLock.Font = Enum.Font.GothamBold; btnLock.TextSize = 12; Instance.new("UICorner", btnLock).CornerRadius = UDim.new(0,8)
local btnEsp = Instance.new("TextButton", content); btnEsp.Size = UDim2.new(1,0,0,36); btnEsp.Position = UDim2.new(0,0,0,86); btnEsp.BackgroundColor3 = CORES.botao; btnEsp.Text = "👁️ ESP: OFF"; btnEsp.TextColor3 = CORES.texto; btnEsp.Font = Enum.Font.GothamBold; btnEsp.TextSize = 12; Instance.new("UICorner", btnEsp).CornerRadius = UDim.new(0,8)

local function drag(f,h)
    h = h or f; local dr, ds, sp
    h.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dr = true; ds = i.Position; sp = f.Position end end)
    UIS.InputChanged:Connect(function(i) if dr and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local d = i.Position - ds; f.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dr = false end end)
end
drag(main, topBar)

local min = false
minBtn.MouseButton1Click:Connect(function() min = not min; main.Size = min and UDim2.new(0,200,0,36) or UDim2.new(0,200,0,320); content.Visible = not min; minBtn.Text = min and "+" or "—" end)
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

attBts = function()
    btnLock.Text = ativo and "🔒 LOCK: ON" or "🔓 LOCK: OFF"; btnLock.BackgroundColor3 = ativo and CORES.on or CORES.botao
    btnEsp.Text = espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF"; btnEsp.BackgroundColor3 = espAtivo and CORES.on or CORES.botao
    statusLbl.Text = (ativo and "🔒 Lock: ON" or "🔓 Lock: OFF").."\n"..(espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF")
end

btnLock.MouseButton1Click:Connect(function() if ativo then pararLock() else ligarLock() end; attBts() end)
btnEsp.MouseButton1Click:Connect(function() toggleESP(); attBts() end)

UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.P then if ativo then pararLock() else ligarLock() end; attBts() end
    if i.KeyCode == Enum.KeyCode.O then toggleESP(); attBts() end
end)

player.CharacterRemoving:Connect(function() if ativo then pararLock() end; if espAtivo then toggleESP() end; limparPreview() end)
attBts()
print("⚡ EZEK "..VERSAO.." carregado! | P=Lock O=ESP")