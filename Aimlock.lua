-- EZEK v16.1 - ANTI-TREMOR (Lock Fix)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ===================== VARIÁVEIS =====================
local ativo, alvo, espAtivo = false, nil, false
local gyro = nil
local FOV_GRAUS = 120
local filtros = {players=true, dummies=true, monstros=true, objetos=true}
local espEl = {}
local isFlying, isNoclip, isFullbright = false, false, false

-- ===================== FUNÇÕES BASE =====================
local function getVida(m)
    local h = m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildWhichIsA("Humanoid",true)
    if h then return h.Health, h.MaxHealth end
    local hp = m:GetAttribute("Health") or m:GetAttribute("HP") or m:GetAttribute("Vida")
    if type(hp) == "number" then return hp, 100 end
    return nil,nil
end

local function temVida(m)
    local hp = getVida(m)
    return hp and hp > 0
end

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

-- ===================== LOCK (CÂMERA & GIRO) =====================
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

    -- 🔥 GIRA O BONECO NA HORA (Sem Tremor)
    if gyro then
        local targetPos = Vector3.new(p.Position.X, root.Position.Y, p.Position.Z)
        if (targetPos - root.Position).Magnitude > 0.1 then 
            gyro.CFrame = CFrame.lookAt(root.Position, targetPos) 
        end
    end

    -- 🔥 TRAVA A CÂMERA
    h.AutoRotate = false
    if camera.CameraType ~= Enum.CameraType.Custom then camera.CameraType = Enum.CameraType.Custom end
    if camera.CameraSubject ~= h then camera.CameraSubject = h end

    -- MIRA INTELIGENTE
    local cabeca = alvo:FindFirstChild("Head")
    local peito = alvo:FindFirstChild("UpperTorso") or alvo:FindFirstChild("Torso")
    local miraPos = p.Position

    if cabeca and peito then
        if camera.CFrame.Position.Y > cabeca.Position.Y then miraPos = cabeca.Position else miraPos = peito.Position end
    elseif cabeca then miraPos = cabeca.Position
    elseif peito then miraPos = peito.Position end

    -- Aplica a rotação
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
            -- 🔥 BODYGYRO FORTE PRA NÃO TREMER
            gyro = Instance.new("BodyGyro", root)
            gyro.P = 100000
            gyro.D = 1000
            gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        end
        RunService:UnbindFromRenderStep("EZEK_CAM")
        -- Roda logo depois da câmera padrão do Roblox pra não brigar
        RunService:BindToRenderStep("EZEK_CAM", Enum.RenderPriority.Camera.Value + 1, atualizarLock)
    end
end

-- ===================== ESP =====================
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

-- ===================== UI =====================
local sg = Instance.new("ScreenGui", player.PlayerGui)
sg.Name = "EZEK_HUB_v16"; sg.ResetOnSpawn = false
local main = Instance.new("Frame", sg); main.Size = UDim2.new(0, 500, 0, 380); main.Position = UDim2.new(0.5, -250, 0.5, -190); main.BackgroundColor3 = Color3.fromRGB(25, 25, 25); main.Active = true
local topBar = Instance.new("Frame", main); topBar.Size = UDim2.new(1, 0, 0, 30); topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
local title = Instance.new("TextLabel", topBar); title.Size = UDim2.new(1, 0, 1, 0); title.BackgroundTransparency = 1; title.Text = "EZEK HUB v16.1"; title.TextColor3 = Color3.fromRGB(0, 255, 255); title.Font = Enum.Font.Code

local closeBtn = Instance.new("TextButton", topBar); closeBtn.Size = UDim2.new(0, 30, 1, 0); closeBtn.Position = UDim2.new(1, -30, 0, 0); closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeBtn.Text = "X"; closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

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

local tabContainer = Instance.new("Frame", main); tabContainer.Size = UDim2.new(0, 100, 1, -30); tabContainer.Position = UDim2.new(0, 0, 0, 30); tabContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
local contentContainer = Instance.new("Frame", main); contentContainer.Size = UDim2.new(1, -100, 1, -30); contentContainer.Position = UDim2.new(0, 100, 0, 30); contentContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)

local function createTab(name)
    local btn = Instance.new("TextButton", tabContainer); btn.Size = UDim2.new(1, 0, 0, 30); btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40); btn.Text = name; btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.Code
    local page = Instance.new("ScrollingFrame", contentContainer); page.Size = UDim2.new(1, 0, 1, 0); page.BackgroundTransparency = 1; page.Visible = false
    local layout = Instance.new("UIListLayout", page); layout.Padding = UDim.new(0, 5)
    btn.MouseButton1Click:Connect(function()
        for _, v in pairs(contentContainer:GetChildren()) do if v:IsA("ScrollingFrame") then v.Visible = false end end
        page.Visible = true
    end)
    return page
end

local pageMain = createTab("Aim/ESP")
local pagePlayer = createTab("Player")
local pageMisc = createTab("Misc")
pageMain.Visible = true

local function createToggle(parent, text, callback)
    local btn = Instance.new("TextButton", parent); btn.Size = UDim2.new(1, -10, 0, 30); btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); btn.Text = text .. " [OFF]"; btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.Code
    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state; btn.Text = text .. (state and " [ON]" or " [OFF]")
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
        callback(state)
    end)
end

local function createButton(parent, text, callback)
    local btn = Instance.new("TextButton", parent); btn.Size = UDim2.new(1, -10, 0, 30); btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); btn.Text = text; btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.Code
    btn.MouseButton1Click:Connect(callback)
end

-- ABA MAIN
createToggle(pageMain, "Lock (Aimlock Avançado)", function(state) if state ~= ativo then toggleLock() end end)
createToggle(pageMain, "ESP Completo", function(state) if state ~= espAtivo then toggleESP() end end)

-- ABA PLAYER
createToggle(pagePlayer, "Fly (Voa)", function(state)
    isFlying = state
    local char = player.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if state and hrp then
        local bv = Instance.new("BodyVelocity", hrp); bv.MaxForce = Vector3.new(9e9, 9e9, 9e9); bv.Velocity = Vector3.new(0,0,0)
        local bg = Instance.new("BodyGyro", hrp); bg.P = 9e4; bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9); bg.CFrame = hrp.CFrame
        RunService.RenderStepped:Connect(function()
            if not isFlying then bv:Destroy(); bg:Destroy(); return end
            local move = camera.CFrame:VectorToWorldSpace(Vector3.new((UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0), (UIS:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 1 or 0), (UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0)))
            bv.Velocity = move * 50; bg.CFrame = camera.CFrame
        end)
    end
end)

createToggle(pagePlayer, "Noclip (Atravessa)", function(state)
    isNoclip = state
    RunService.Stepped:Connect(function()
        if isNoclip and player.Character then
            for _, v in pairs(player.Character:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
            end
        end
    end)
end)

createButton(pagePlayer, "Speed: 50", function()
    if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        player.Character.Humanoid.WalkSpeed = 50
    end
end)
createButton(pagePlayer, "Jump: 100", function()
    if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        player.Character.Humanoid.JumpPower = 100
    end
end)

-- ABA MISC
createButton(pageMisc, "Teleport (Jogador Próximo)", function()
    local closest, dist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local d = (p.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
            if d < dist then closest = p; dist = d end
        end
    end
    if closest and closest.Character then
        player.Character.HumanoidRootPart.CFrame = closest.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
    end
end)

createToggle(pageMisc, "Fullbright (Clarear)", function(state)
    isFullbright = state
    if state then
        Lighting.Brightness = 3; Lighting.ClockTime = 12; Lighting.FogEnd = 100000; Lighting.GlobalShadows = false; Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    else
        Lighting.Brightness = 1; Lighting.GlobalShadows = true; Lighting.FogEnd = 1000; Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    end
end)

-- Teclas
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.P then toggleLock() end
    if input.KeyCode == Enum.KeyCode.O then toggleESP() end
end)

print("⚡ EZEK HUB v16.1 Carregado! Anti-Tremor ativo.")