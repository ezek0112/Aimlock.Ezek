-- EZEK v29.0 - Seleção de Mira (Cabeça/Peito) + Câmera Alta + ESP
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

for _, obj in pairs(player:WaitForChild("PlayerGui"):GetChildren()) do
    if obj:IsA("ScreenGui") and (string.find(obj.Name, "EZEK") or string.find(obj.Name, "Aimlock")) then
        obj:Destroy()
    end
end
pcall(function() RunService:UnbindFromRenderStep("EZEK_CAM") end)

local VERSAO = "v29.0"
local FOV_GRAUS = 120
local ativo, alvo, espAtivo = false, nil, false
local gyro = nil
local espEl = {}

local alturaCamera = 2.0
local opcoesAltura = {2.0, 4.0, 6.0, 8.0}
local opcaoIndex = 1

-- 🔥 VARIÁVEL DA MIRA (false = Cabeça, true = Peito)
local miraPeito = false

local filtros = {players=true, dummies=true, monstros=true, objetos=true}
local cache, cacheT = {}, 0

local r1, r2, l1, l2 = false, false, false, false
local uL, uE = 0, 0

local function getVida(m)
    local h = m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildWhichIsA("Humanoid",true)
    if h then return h.Health, h.MaxHealth end
    local attrs = {"Health", "HP", "Vida", "health", "hp", "vida", "CurrentHealth", "MaxHealth"}
    for _, a in ipairs(attrs) do
        local v = m:GetAttribute(a)
        if type(v) == "number" then return v, 100 end
    end
    return nil,nil
end
local function temVida(m) local hp = getVida(m) return hp and hp > 0 end
local function pegarParte(m)
    if not m then return nil end
    if m:IsA("BasePart") then return m end
    return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart") 
        or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") 
        or m:FindFirstChildWhichIsA("BasePart")
end
local function getTipo(m)
    if Players:GetPlayerFromCharacter(m) then return "players" end
    local n = string.lower(m.Name)
    if n:find("dummy") or n:find("training") then return "dummies" end
    if m:FindFirstChildOfClass("Humanoid") or temVida(m) then return "monstros" end
    return "objetos"
end

local function getTodos()
    local t = tick()
    if t - cacheT < 1 and #cache > 0 then return cache end
    local lista, vistos = {}, {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and temVida(p.Character) then table.insert(lista, p.Character); vistos[p.Character]=true end
    end
    local function proc(pasta, prof)
        if prof > 6 then return end
        for _, v in pairs(pasta:GetChildren()) do
            if v:IsA("Model") and v ~= player.Character and temVida(v) and pegarParte(v) and not vistos[v] then
                table.insert(lista, v); vistos[v]=true
            end
            if v:IsA("Folder") or v:IsA("Model") then proc(v, prof+1) end
        end
    end
    proc(workspace, 0)
    cache = lista; cacheT = t
    return lista
end

-- LOCK CRAVADO
local function acharAlvo()
    local melhor, angMin = nil, math.rad(FOV_GRAUS)
    local cp = camera.CFrame.Position
    local cl = camera.CFrame.LookVector
    for _, m in pairs(getTodos()) do
        if filtros[getTipo(m)] and temVida(m) then
            local p = pegarParte(m)
            if p then
                local dist = (p.Position - cp).Magnitude
                if dist > 0.5 then
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
    if h then h.AutoRotate = true end
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

    -- 🔥 AQUI ESCOLHE O OSSO PRA MIRAR
    local miraPos = p.Position
    if miraPeito then
        local peito = alvo:FindFirstChild("UpperTorso") or alvo:FindFirstChild("Torso")
        if peito then miraPos = peito.Position end
    else
        local cabeca = alvo:FindFirstChild("Head")
        if cabeca then miraPos = cabeca.Position end
    end
    
    -- Câmera sobe fisicamente
    local posicaoAtual = camera.CFrame.Position
    local novaPosicao = Vector3.new(posicaoAtual.X, root.Position.Y + alturaCamera, posicaoAtual.Z)
    local cframeAlvo = CFrame.lookAt(novaPosicao, miraPos)
    
    camera.CFrame = camera.CFrame:Lerp(cframeAlvo, 0.5)
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

-- PREVIEW
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
    local cont = Instance.new("Frame", espGui)
    cont.BackgroundTransparency = 1
    cont.Visible = false
    cont.AnchorPoint = Vector2.new(0.5, 0.5)
    local st = Instance.new("UIStroke", cont)
    st.Color = Color3.fromRGB(0, 255, 0)
    st.Thickness = 2
    previewEl = {cont = cont}; previewAlvo = m
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
                    local lar = alt * 0.55
                    local cx = (top.X + bot.X) / 2
                    local cy = (top.Y + bot.Y) / 2
                    previewEl.cont.Visible = true
                    previewEl.cont.Size = UDim2.new(0, lar, 0, alt)
                    previewEl.cont.Position = UDim2.new(0, cx, 0, cy)
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
    
    for m, d in pairs(espEl) do
        if not m.Parent or not temVida(m) then
            d.cont:Destroy()
            espEl[m] = nil
        end
    end

    for _, m in pairs(getTodos()) do
        if filtros[getTipo(m)] and temVida(m) then
            local p = pegarParte(m)
            if p then
                if not espEl[m] then
                    local cont = Instance.new("Frame", espGui)
                    cont.BackgroundTransparency = 1
                    cont.AnchorPoint = Vector2.new(0.5, 0.5)
                    local st = Instance.new("UIStroke", cont)
                    st.Color = Color3.fromRGB(0, 255, 255)
                    local nm = Instance.new("TextLabel", cont)
                    nm.BackgroundTransparency = 1; nm.Size = UDim2.new(1, 0, 0, 14); nm.Position = UDim2.new(0, 0, 0, -16)
                    nm.TextSize = 11; nm.TextColor3 = st.Color; nm.TextStrokeTransparency = 0; nm.Font = Enum.Font.GothamBold; nm.Text = m.Name
                    local hp = Instance.new("TextLabel", cont)
                    hp.BackgroundTransparency = 1; hp.Size = UDim2.new(1, 0, 0, 14); hp.Position = UDim2.new(0, 0, 1, 2)
                    hp.TextSize = 10; hp.TextColor3 = Color3.fromRGB(0,255,0); hp.TextStrokeTransparency = 0; hp.Font = Enum.Font.GothamBold
                    espEl[m] = {cont=cont, nm=nm, hp=hp}
                end
                local d = espEl[m]
                local top = camera:WorldToViewportPoint(p.Position + Vector3.new(0,2.5,0))
                local bot = camera:WorldToViewportPoint(p.Position - Vector3.new(0,2.5,0))
                if top.Z > 0 and bot.Z > 0 then
                    local alt = math.abs(top.Y - bot.Y)
                    if alt > 5 then
                        local lar = alt * 0.55; local cx = (top.X + bot.X) / 2; local cy = (top.Y + bot.Y) / 2
                        d.cont.Visible = true
                        d.cont.Size = UDim2.new(0, lar, 0, alt); d.cont.Position = UDim2.new(0, cx, 0, cy)
                        local hVal, hMax = getVida(m)
                        if hVal then d.hp.Text = string.format("%d/%d", math.floor(hVal), math.floor(hMax or 100)) end
                    else d.cont.Visible = false end
                else d.cont.Visible = false end
            end
        end
    end
end)

-- ===================== UI =====================
local sg = Instance.new("ScreenGui", player.PlayerGui)
sg.Name = "EZEK_GUI_v29"; sg.ResetOnSpawn = false
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 400); main.Position = UDim2.new(0, 20, 0.5, -200)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30); main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 36); title.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
title.Text = "🎯 EZEK " .. VERSAO; title.TextColor3 = Color3.fromRGB(0, 255, 255); title.Font = Enum.Font.GothamBold; title.TextSize = 14
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton", title)
closeBtn.Size = UDim2.new(0, 30, 1, 0); closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

local minBtn = Instance.new("TextButton", title)
minBtn.Size = UDim2.new(0, 30, 1, 0); minBtn.Position = UDim2.new(1, -60, 0, 0)
minBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50); minBtn.Text = "-"; minBtn.TextColor3 = Color3.new(1,1,1)
minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 16
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 8)

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

-- 🔥 BOTÃO DE MIRA CABEÇA/PEITO
local btnMira = Instance.new("TextButton", main)
btnMira.Size = UDim2.new(1, -20, 0, 35); btnMira.Position = UDim2.new(0, 10, 0, 136)
btnMira.BackgroundColor3 = Color3.fromRGB(40, 40, 50); btnMira.Text = "🎯 MIRA: CABEÇA"
btnMira.TextColor3 = Color3.new(1,1,1); btnMira.Font = Enum.Font.GothamBold; btnMira.TextSize = 12
Instance.new("UICorner", btnMira).CornerRadius = UDim.new(0, 6)

local btnCam = Instance.new("TextButton", main)
btnCam.Size = UDim2.new(1, -20, 0, 35); btnCam.Position = UDim2.new(0, 10, 0, 181)
btnCam.BackgroundColor3 = Color3.fromRGB(40, 40, 50); btnCam.Text = "📷 CÂMERA ACIMA: 2.0"
btnCam.TextColor3 = Color3.new(1,1,1); btnCam.Font = Enum.Font.GothamBold; btnCam.TextSize = 12
Instance.new("UICorner", btnCam).CornerRadius = UDim.new(0, 6)

local fTitle = Instance.new("TextLabel", main)
fTitle.Size = UDim2.new(1, -20, 0, 20); fTitle.Position = UDim2.new(0, 10, 0, 225)
fTitle.BackgroundTransparency = 1; fTitle.Text = "Filtros:"; fTitle.TextColor3 = Color3.fromRGB(150, 150, 150)
fTitle.Font = Enum.Font.GothamMedium; fTitle.TextSize = 11; fTitle.TextXAlignment = Enum.TextXAlignment.Left

local function mkCheckInContainer(txt, chave, y)
    local cf = Instance.new("Frame", main)
    cf.Size = UDim2.new(1, -20, 0, 24); cf.Position = UDim2.new(0, 10, 0, 245 + y); cf.BackgroundTransparency = 1
    
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

local function atualizarBotoes()
    btnLock.Text = ativo and "🔒 LOCK: ON" or "🔓 LOCK: OFF"
    btnLock.BackgroundColor3 = ativo and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(40, 40, 50)
    btnEsp.Text = espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF"
    btnEsp.BackgroundColor3 = espAtivo and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(40, 40, 50)
end

btnLock.MouseButton1Click:Connect(function()
    toggleLock()
    atualizarBotoes()
end)

btnEsp.MouseButton1Click:Connect(function()
    toggleESP()
    atualizarBotoes()
end)

-- 🔥 LÓGICA DO BOTÃO DE MIRA
btnMira.MouseButton1Click:Connect(function()
    miraPeito = not miraPeito
    if miraPeito then
        btnMira.Text = "🎯 MIRA: PEITO"
        btnMira.BackgroundColor3 = Color3.fromRGB(180, 50, 50) -- Vermelho pra diferenciar
    else
        btnMira.Text = "🎯 MIRA: CABEÇA"
        btnMira.BackgroundColor3 = Color3.fromRGB(40, 40, 50) -- Cinza normal
    end
end)

btnCam.MouseButton1Click:Connect(function()
    opcaoIndex = opcaoIndex + 1
    if opcaoIndex > #opcoesAltura then opcaoIndex = 1 end
    alturaCamera = opcoesAltura[opcaoIndex]
    btnCam.Text = "📷 CÂMERA ACIMA: " .. tostring(alturaCamera)
end)

UIS.InputBegan:Connect(function(input, gp)
    local nosso = input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.O
        or input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.ButtonR2
        or input.KeyCode == Enum.KeyCode.ButtonL1 or input.KeyCode == Enum.KeyCode.ButtonL2
    if gp and not nosso then return end
    
    if input.KeyCode == Enum.KeyCode.P then toggleLock(); atualizarBotoes(); return end
    if input.KeyCode == Enum.KeyCode.O then toggleESP(); atualizarBotoes(); return end

    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1 = true end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2 = true end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1 = true end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2 = true end

    if r1 and r2 then
        local a = tick()
        if a-uL > 0.8 then toggleLock(); atualizarBotoes(); uL = a; r1=false; r2=false end
    end
    if l1 and l2 then
        local a = tick()
        if a-uE > 0.8 then toggleESP(); atualizarBotoes(); uE = a; l1=false; l2=false end
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1 = false end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2 = false end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1 = false end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2 = false end
end)

print("⚡ EZEK " .. VERSAO .. " Carregado! Seleção de Mira Ativada.")