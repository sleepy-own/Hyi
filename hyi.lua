--[[
    SPORENY CLIENT v6.5
    COMBAT (Aim Bot + Silent Aim + ESP + Movement) | VISUAL (3D Preview + FX) | CONFIG | SETTINGS
    RightShift - hide / show
]]

local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")
local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")
local Stats              = game:GetService("Stats")
local Debris             = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local ContentProvider    = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer

local CFG = {
    BRAND = "SPORENY CLIENT", VERSION = "v6.5", TOGGLE_KEY = Enum.KeyCode.RightShift,
    HAT_RADIUS = 2.1, HAT_HEIGHT = 1.15, HAT_LAYERS = 20, HAT_FLOAT = 0.45, HAT_TRANSPARENCY = 0.28,
    CIRCLE_RADIUS = 2.3, CIRCLE_SEGMENTS = 64, CIRCLE_PERIOD = 3.2,
    ANGEL_RADIUS = 0.95, ANGEL_SEGMENTS = 32, ANGEL_THICK = 0.13, ANGEL_HEIGHT = 0.95, ANGEL_MAX_DISTANCE = 160,
    WING_IDLE_SPEED = 4.6, WING_MOVE_SPEED = 7.8, WING_AMPLITUDE = 0.46,
    SHOT_ANIMS = { ["shot"] = true }, SHOT_KEYWORDS = {},
    SHOT_EXCLUDE = { "reload", "equip", "unequip", "idle", "walk", "run", "hold", "aim" },
    IGNORE_ZERO_WEIGHT = true, IGNORED_TOOLS = {},
    MUZZLE_KEYWORDS = { "muzzle", "barrel", "firepoint", "fireposition", "shootpoint", "bulletspawn", "gunpoint", "nozzle" },
    RANGE = 1000, SHOT_COOLDOWN = 0.05, EQUIP_GRACE = 0.4,
    TRACER_LIFE = 0.75, TRACER_TRAVEL = 0.16, LAND_MIN_SPEED = 16,
    SOUL_DURATION = 3.0, SOUL_MAX = 6, KILL_MATCH_WINDOW = 2.5, KILL_ANY_DISTANCE = 250,
    RAIN_COUNT = 140, DARK_LEVEL = 0.55,
    HIT_SOUND_ID = "rbxasset://sounds/electronicpingshort.wav", HIT_WINDOW = 0.9,
    ESP_FILL_TRANSPARENCY = 0.55, -- оставлено для совместимости со старым реколором, бокс больше не рисуется
    PREVIEW_FOV = 38, PREVIEW_SPIN = 0.55,
    CONFIG_FOLDER = "SporenyClient/configs",
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local C = {
    window = BLACK, surface = Color3.fromRGB(8, 8, 8), surface2 = Color3.fromRGB(20, 20, 20),
    border = Color3.fromRGB(36, 36, 36), track = Color3.fromRGB(36, 36, 36),
    text = Color3.fromRGB(245, 245, 245), sub = Color3.fromRGB(150, 150, 150),
    dim = Color3.fromRGB(85, 85, 85), accent = WHITE,
}

local PALETTE = {
    { "Black",  Color3.fromRGB(0, 0, 0) }, { "White",  Color3.fromRGB(255, 255, 255) },
    { "Green",  Color3.fromRGB(70, 255, 130) }, { "Red", Color3.fromRGB(255, 50, 50) },
    { "Orange", Color3.fromRGB(255, 140, 0) }, { "Yellow", Color3.fromRGB(255, 225, 70) },
    { "Cyan",   Color3.fromRGB(0, 220, 255) }, { "Blue",  Color3.fromRGB(50, 120, 255) },
    { "Purple", Color3.fromRGB(170, 80, 255) }, { "Pink", Color3.fromRGB(255, 80, 180) },
}
local PALETTE_MAP = {}
for _, e in ipairs(PALETTE) do PALETTE_MAP[e[1]] = e[2] end

local colors = {
    hat = PALETTE_MAP.Green, circle = PALETTE_MAP.Black, angel = PALETTE_MAP.White, wings = PALETTE_MAP.White,
    trail = PALETTE_MAP.Pink, particles = PALETTE_MAP.Cyan, tracer = PALETTE_MAP.Yellow, jump = PALETTE_MAP.Cyan,
    soul = PALETTE_MAP.Cyan, esp = PALETTE_MAP.White, aura = PALETTE_MAP.Cyan, orb = PALETTE_MAP.Purple,
    dark = PALETTE_MAP.Black,
}

local env = (typeof(getgenv) == "function" and getgenv()) or _G
if env.__BestVisualCleanup then pcall(env.__BestVisualCleanup); env.__BestVisualCleanup = nil end

local connections = {}

local function getGuiParent()
    local ok, ui = pcall(function() return typeof(gethui) == "function" and gethui() or nil end)
    if ok and ui then return ui end
    ok, ui = pcall(function() return game:GetService("CoreGui") end)
    if ok and ui then return ui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function new(class, props, children)
    local inst = Instance.new(class)
    local parent = props.Parent
    for k, v in pairs(props) do if k ~= "Parent" then inst[k] = v end end
    if children then for _, child in ipairs(children) do child.Parent = inst end end
    inst.Parent = parent
    return inst
end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function stroke(color, thickness) return new("UIStroke", { Color = color, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function tween(inst, time, props, style, dir)
    local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play(); return t
end
local function luma(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
local function hasAny(name, list)
    name = string.lower(name)
    for _, k in ipairs(list) do if string.find(name, k, 1, true) then return true end end
    return false
end
local function debounce(fn, delay)
    local token = 0
    return function() token = token + 1; local my = token; task.delay(delay or 0.15, function() if my == token then fn() end end) end
end
local function hash(i) local x = math.sin(i * 12.9898) * 43758.5453; return x - math.floor(x) end
local function makeDraggable(handle, target)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = target.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end
local function normalizeSoundId(text)
    text = tostring(text or ""):gsub("%s", "")
    if text == "" then return nil end
    if text:find("rbxasset") or text:find("http") then return text end
    if text:match("^%d+$") then return "rbxassetid://" .. text end
    return text
end

local gui = new("ScreenGui", {
    Name = "SporenyClient", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local fxFolder = Instance.new("Folder")
fxFolder.Name = "SporenyFX"
fxFolder.Parent = Workspace

local charRefs = { char = nil, hum = nil, root = nil, head = nil, torso = nil }
local UPDATERS = {}
local ON_LOCAL_CHAR = {}
local F = {}
local previewState = { active = false }

local S = {
    hat = { enabled = false, scale = 1 }, circle = { enabled = false, scale = 1, speed = 1 },
    angels = { enabled = false, mode = "Everyone" }, wings = { enabled = false, scale = 1 },
    seleher = { enabled = false }, aura = { enabled = false, style = 1, scale = 1, speed = 1, rainbow = false },
    orb = { enabled = false, rainbow = false }, sky = { enabled = false, density = 1 },
    dark = { enabled = false }, jump = { enabled = false },
}

local function styleFxPart(p)
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
end
local function newBall(size, color, transparency)
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Ball; p.Material = Enum.Material.Neon; p.Color = color
    p.Transparency = transparency; p.Size = Vector3.new(size, size, size); styleFxPart(p); return p
end
local function buildRing(parent, radius, segments, thick, height, color, transparency, name)
    local model = Instance.new("Model"); model.Name = name
    local pivot = Instance.new("Part"); pivot.Name = "Pivot"; pivot.Size = Vector3.new(0.2, 0.2, 0.2); pivot.Transparency = 1
    styleFxPart(pivot); pivot.CFrame = CFrame.new(0, 0, 0); pivot.Parent = model; model.PrimaryPart = pivot
    local chord = 2 * radius * math.sin(math.pi / segments)
    local segs = {}
    for i = 0, segments - 1 do
        local th = (i / segments) * math.pi * 2
        local pos = Vector3.new(math.cos(th) * radius, 0, math.sin(th) * radius)
        local tangent = Vector3.new(-math.sin(th), 0, math.cos(th))
        local seg = Instance.new("Part"); seg.Name = "Seg"; seg.Material = Enum.Material.Neon
        seg.Color = color; seg.Transparency = transparency; seg.Size = Vector3.new(thick, height, chord * 1.2)
        styleFxPart(seg); seg.CFrame = CFrame.lookAt(pos, pos + tangent); seg.Parent = model; segs[#segs + 1] = seg
    end
    model.Parent = parent
    return { model = model, pivot = pivot, segs = segs }
end
local function ringSetColor(ring, color) for _, s in ipairs(ring.segs) do s.Color = color end end
local function watchPlayers(onChar, onRemoving, onLeft, includeSelf)
    local function track(p)
        if p == LocalPlayer and not includeSelf then return end
        if p.Character then task.spawn(onChar, p, p.Character) end
        table.insert(connections, p.CharacterAdded:Connect(function(ch) task.spawn(onChar, p, ch) end))
        if onRemoving then table.insert(connections, p.CharacterRemoving:Connect(function(ch) onRemoving(p, ch) end)) end
    end
    for _, p in ipairs(Players:GetPlayers()) do track(p) end
    table.insert(connections, Players.PlayerAdded:Connect(track))
    if onLeft then table.insert(connections, Players.PlayerRemoving:Connect(onLeft)) end
end
local function findGround(origin, ignoreChar)
    local ignore = { fxFolder }
    if LocalPlayer.Character then ignore[#ignore + 1] = LocalPlayer.Character end
    if ignoreChar then ignore[#ignore + 1] = ignoreChar end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = ignore; params.IgnoreWater = true
    local res = Workspace:Raycast(origin, Vector3.new(0, -14, 0), params)
    if res then return res.Position + res.Normal * 0.05, res.Normal end
    return origin - Vector3.new(0, 3, 0), Vector3.new(0, 1, 0)
end
local function groundCFrame(pos, normal)
    local vx = normal:Cross(Vector3.new(0, 0, 1))
    if vx.Magnitude < 0.01 then vx = Vector3.new(1, 0, 0) end
    return CFrame.fromMatrix(pos, vx.Unit, normal)
end
local function spawnGroundRings(pos, normal, color, power)
    local folder = Instance.new("Folder"); folder.Name = "SC_Rings"
    local d0 = 2.2; local d1 = 9 + 5 * power
    local part = Instance.new("Part"); part.Name = "Rings"; part.Size = Vector3.new(d0, 0.05, d0); part.Transparency = 1
    styleFxPart(part); part.CFrame = groundCFrame(pos, normal); part.Parent = folder
    local sg = new("SurfaceGui", { Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
        CanvasSize = Vector2.new(512, 512), LightInfluence = 0, Brightness = 1.6, AlwaysOnTop = false, Adornee = part, Parent = part })
    local fill = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.96, 0.96), BackgroundColor3 = color, BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = sg },
        { corner(999) })
    tween(fill, 1.0, { BackgroundTransparency = 1, Size = UDim2.fromScale(0.7, 0.7) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local layers = { { 0.98, 16, 0 }, { 0.74, 10, 0.07 }, { 0.5, 7, 0.14 } }
    for _, l in ipairs(layers) do
        local sizeScale, thick, delay = l[1], l[2], l[3]
        local grad = new("UIGradient", { Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.5, color), ColorSequenceKeypoint.new(1, color:Lerp(WHITE, 0.5)),
        }) })
        local st = new("UIStroke", { Color = WHITE, Thickness = thick, Transparency = 0.05, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
        grad.Parent = st
        local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(sizeScale, sizeScale), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = sg }, { corner(999), st })
        task.delay(delay, function()
            tween(ring, 1.0, { Size = UDim2.fromScale(sizeScale * 0.86, sizeScale * 0.86) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            tween(st, 0.95, { Transparency = 1, Thickness = thick * 0.35 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tween(grad, 1.0, { Rotation = 300 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end)
    end
    tween(part, 1.0, { Size = Vector3.new(d1, 0.05, d1) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local att = new("Attachment", { Parent = part })
    local em = new("ParticleEmitter", { Enabled = false, Rate = 0, Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(3, 9),
        SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0, -6, 0),
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) }),
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
        Color = ColorSequence.new(color:Lerp(WHITE, 0.4)), LightEmission = 1,
        Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-100, 100), Parent = att })
    em:Emit(math.floor(14 + 10 * power))
    local light = new("PointLight", { Color = color, Brightness = 3, Range = 14, Shadows = false, Parent = part })
    tween(light, 0.6, { Brightness = 0 })
    folder.Parent = fxFolder; Debris:AddItem(folder, 1.8)
end
local function readPing()
    local sources = {
        function() return Stats.PerformanceStats.Ping:GetValue() end,
        function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end,
    }
    for _, fn in ipairs(sources) do local ok, v = pcall(fn); if ok and type(v) == "number" and v > 0 then return v end end
    local ok, p = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if ok and type(p) == "number" and p > 0 then return p * 2000 end
    return nil
end

local FX = {}
local FX_ORDER = {}

local function registerFx(name, state, make)
    local e = { name = name, state = state, make = make }
    e.world = make({ parent = fxFolder, refs = charRefs, preview = false })
    FX[name] = e; FX_ORDER[#FX_ORDER + 1] = e
    local function sync(inst)
        if state.enabled and not inst.built then inst.built = true; inst.build()
        elseif not state.enabled and inst.built then inst.built = false; inst.destroy() end
    end
    e.sync = sync
    local function each(fn) fn(e.world); if e.preview then fn(e.preview) end end
    local rebuild = debounce(function() each(function(inst) if inst.built then inst.destroy(); inst.build() end end) end)
    F[name] = {
        set = function(v) state.enabled = v and true or false; each(sync) end,
        recolor = function() each(function(inst) if inst.built and inst.recolor then inst.recolor() end end) end,
        rebuild = rebuild,
    }
    return e
end

do
    local warned = {}
    table.insert(UPDATERS, function(t, dt)
        for _, e in ipairs(FX_ORDER) do
            local w = e.world
            if w.built and w.update then
                local ok, err = pcall(w.update, t, dt)
                if not ok and not warned[e.name] then warned[e.name] = true; warn("[Sporeny] " .. e.name .. ": " .. tostring(err)) end
            end
            local p = e.preview
            if previewState.active and p and p.built and p.update then
                local ok, err = pcall(p.update, t, dt)
                if not ok and not warned[e.name .. "_p"] then warned[e.name .. "_p"] = true; warn("[Sporeny] preview " .. e.name .. ": " .. tostring(err)) end
            end
        end
    end)
end

-- ========== HAT ==========
registerFx("hat", S.hat, function(ctx)
    local inst = { layers = {} }
    local function layerColor(k) return colors.hat:Lerp(WHITE, 0.22 * k) end
    local function buildCone(model, pivot)
        local s = S.hat.scale
        local baseTr = ctx.preview and 0.02 or CFG.HAT_TRANSPARENCY
        local layerH = math.max(CFG.HAT_HEIGHT * s / CFG.HAT_LAYERS, 0.05)
        local layers = {}
        for i = 1, CFG.HAT_LAYERS do
            local k = (i - 1) / (CFG.HAT_LAYERS - 1)
            local r = math.max(CFG.HAT_RADIUS * s * (1 - k) ^ 0.9, 0.1)
            local p = Instance.new("Part"); p.Name = "Layer"; p.Shape = Enum.PartType.Cylinder
            p.Material = Enum.Material.Neon; p.Color = layerColor(k)
            p.Transparency = baseTr + (ctx.preview and 0 or 0.1 * k)
            p.Size = Vector3.new(layerH + 0.012, r * 2, r * 2); styleFxPart(p)
            p.CFrame = CFrame.new(0, i * layerH, 0) * CFrame.Angles(0, 0, math.pi / 2)
            p.Parent = model; layers[i] = { part = p, k = k }
        end
        inst.layers = layers
        inst.light = new("PointLight", { Color = colors.hat, Brightness = 1.4, Range = 14, Shadows = false, Parent = pivot })
        inst.emitter = new("ParticleEmitter", {
            Rate = 16, Lifetime = NumberRange.new(0.9, 1.6), Speed = NumberRange.new(0.4, 1.6),
            SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
            Color = ColorSequence.new(colors.hat), LightEmission = 1, Parent = pivot,
        })
    end
    function inst.build()
        local model = Instance.new("Model"); model.Name = "SC_Hat"
        local pivot = Instance.new("Part"); pivot.Name = "Pivot"; pivot.Transparency = 1
        local d = CFG.HAT_RADIUS * 2 * S.hat.scale
        pivot.Size = Vector3.new(d, 0.3, d); styleFxPart(pivot); pivot.CFrame = CFrame.new(0, 0, 0)
        pivot.Parent = model; model.PrimaryPart = pivot
        buildCone(model, pivot)
        model.Parent = ctx.parent; inst.model = model
    end
    function inst.destroy()
        if inst.model then pcall(function() inst.model:Destroy() end) end
        inst.model, inst.light, inst.emitter, inst.layers = nil, nil, nil, {}
    end
    function inst.recolor()
        for _, l in ipairs(inst.layers) do l.part.Color = layerColor(l.k) end
        if inst.light then inst.light.Color = colors.hat end
        if inst.emitter then inst.emitter.Color = ColorSequence.new(colors.hat) end
    end
    function inst.update(t)
        local model = inst.model
        if not model then return end
        local head = ctx.refs.head
        if not (head and head.Parent) then if model.Parent then model.Parent = nil end return end
        if not ctx.preview then
            local cam = Workspace.CurrentCamera
            if cam and (cam.CFrame.Position - head.Position).Magnitude < 1.8 then
                if model.Parent then model.Parent = nil end return
            end
        end
        if model.Parent ~= ctx.parent then model.Parent = ctx.parent end
        local bob = math.sin(t * 2.1) * 0.06
        local pos = head.Position + Vector3.new(0, head.Size.Y / 2 + CFG.HAT_FLOAT * S.hat.scale + bob, 0)
        model:PivotTo(CFrame.new(pos) * CFrame.Angles(math.sin(t * 1.3) * 0.05, t * 0.6, math.cos(t * 1.1) * 0.05))
    end
    return inst
end)

-- ========== CIRCLE ==========
registerFx("circle", S.circle, function(ctx)
    local inst = { ring = nil, phase = 0, topOff = nil, botOff = nil }
    function inst.build()
        inst.ring = buildRing(ctx.parent, CFG.CIRCLE_RADIUS * S.circle.scale, CFG.CIRCLE_SEGMENTS,
            CFG.ANGEL_THICK, CFG.ANGEL_THICK * 0.85, colors.circle, 0, "SC_Circle")
        inst.topOff, inst.botOff = nil, nil
    end
    function inst.destroy()
        if inst.ring then pcall(function() inst.ring.model:Destroy() end); inst.ring = nil end
    end
    function inst.recolor() if inst.ring then ringSetColor(inst.ring, colors.circle) end end
    function inst.update(t, dt)
        local ring = inst.ring
        if not ring then return end
        local refs = ctx.refs
        local root, head, hum = refs.root, refs.head, refs.hum
        if not (root and root.Parent and head and head.Parent and hum) then return end
        local topOff = head.Position.Y + head.Size.Y / 2 - root.Position.Y - 0.1
        local botOff
        if hum.RigType == Enum.HumanoidRigType.R15 then botOff = -(root.Size.Y / 2 + hum.HipHeight) + 0.1 else botOff = -2.9 end
        if inst.topOff then
            local k = 1 - math.exp(-4 * dt)
            inst.topOff = inst.topOff + (topOff - inst.topOff) * k
            inst.botOff = inst.botOff + (botOff - inst.botOff) * k
        else inst.topOff, inst.botOff = topOff, botOff end
        inst.phase = (inst.phase + dt * S.circle.speed / CFG.CIRCLE_PERIOD) % 1
        local u = 0.5 - 0.5 * math.cos(inst.phase * math.pi * 2)
        local y = root.Position.Y + inst.botOff + (inst.topOff - inst.botOff) * u
        ring.model:PivotTo(CFrame.new(root.Position.X, y, root.Position.Z))
    end
    return inst
end)

-- ========== WINGS ==========
registerFx("wings", S.wings, function(ctx)
    local inst = { model = nil, feathers = {}, phase = 0 }
    local specList = {}
    do
        local function row(n, a0, a1, lenFn, width, rowId, off, zoff)
            for i = 1, n do
                local t = (i - 1) / (n - 1)
                specList[#specList + 1] = { a = math.rad(a0 + (a1 - a0) * t), t = t, len = lenFn(t), w = width, row = rowId, off = off, z = zoff }
            end
        end
        row(8, 70, -40, function(t) if t < 0.55 then return 2.4 + 3.0 * math.sin(t / 0.55 * math.pi / 2) end return 5.4 - (t - 0.55) / 0.45 * 1.3 end, 0.8, 1, 0, 0)
        row(7, 80, 0, function(t) return 1.6 + 1.7 * t end, 0.68, 2, 0.1, 0.05)
        row(6, 88, 30, function(t) return 0.9 + 0.9 * t end, 0.52, 3, 0.15, 0.1)
    end
    local function featherColor(rowId)
        if rowId == 1 then return colors.wings end
        if rowId == 2 then return colors.wings:Lerp(WHITE, 0.35) end
        return colors.wings:Lerp(WHITE, 0.6)
    end
    function inst.build()
        local model = Instance.new("Model"); model.Name = "SC_Wings"
        local s = S.wings.scale; inst.feathers = {}
        for _, side in ipairs({ 1, -1 }) do
            for _, sp in ipairs(specList) do
                local p = Instance.new("Part"); p.Name = "Feather"; p.Material = Enum.Material.Neon
                p.Color = featherColor(sp.row); p.Transparency = 0.08 + 0.05 * sp.row
                p.Size = Vector3.new(sp.len * s, sp.w * s, 0.06); styleFxPart(p)
                local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
                p.Parent = model; inst.feathers[#inst.feathers + 1] = { part = p, side = side, spec = sp }
            end
        end
        model.Parent = ctx.parent; inst.model = model
    end
    function inst.destroy()
        if inst.model then pcall(function() inst.model:Destroy() end) end
        inst.model, inst.feathers = nil, {}
    end
    function inst.recolor() for _, f in ipairs(inst.feathers) do f.part.Color = featherColor(f.spec.row) end end
    function inst.update(t, dt)
        local model = inst.model
        if not model then return end
        local refs = ctx.refs
        local torso, hum, root = refs.torso, refs.hum, refs.root
        if not (torso and torso.Parent and hum and hum.Health > 0) then if model.Parent then model.Parent = nil end return end
        if model.Parent ~= ctx.parent then model.Parent = ctx.parent end
        local moving = root and root.AssemblyLinearVelocity.Magnitude > 3
        local speed = moving and CFG.WING_MOVE_SPEED or CFG.WING_IDLE_SPEED
        inst.phase = inst.phase + dt * speed
        local ph = inst.phase
        local flapRaw = math.sin(ph) + 0.18 * math.sin(2 * ph + 0.9)
        local flap = 0.14 + CFG.WING_AMPLITUDE * flapRaw
        local sweep = 0.55 + 0.22 * math.cos(ph)
        local base = torso.CFrame * CFrame.new(0, 0.5, 0.6)
        local scale = S.wings.scale
        for _, f in ipairs(inst.feathers) do
            local s, sp = f.side, f.spec
            local hinge = base * CFrame.new(s * 0.3, 0, 0) * CFrame.Angles(0, -s * sweep, 0) * CFrame.Angles(0, 0, s * flap)
            local a = sp.a + 0.1 * math.sin(ph - sp.t * 1.6) * (0.4 + sp.t)
            local dir = Vector3.new(s * math.cos(a), math.sin(a), 0)
            local ang = (s == 1) and a or (math.pi - a)
            f.part.CFrame = hinge * CFrame.new(dir * (sp.len * scale / 2 + sp.off) + Vector3.new(0, 0, sp.z)) * CFrame.Angles(0, 0, ang)
        end
    end
    return inst
end)

-- ========== AURA ==========
local AURAS = {
    { name = "Helix", n = 72, f = function(i, n, c)
        local arm = i % 2; local k = (math.floor((i - 1) / 2) / (n / 2) + c * 0.22) % 1
        local ang = k * 14 + c * 2.2 + arm * math.pi; local r = 2.0 + 0.12 * math.sin(c * 3 + k * 9)
        local fade = math.sin(k * math.pi)
        return math.cos(ang) * r, -3 + 6.6 * k, math.sin(ang) * r, 0.16 + 0.3 * fade, 0.1 + 0.85 * (1 - fade) ^ 1.2, k end },
    { name = "Vortex", n = 64, f = function(i, n, c)
        local p = (i / n + c * 0.3) % 1; local r = 0.5 + 2.7 * (1 - p) ^ 0.9
        local ang = c * 2.6 + i * 2.39996 + p * 9
        return math.cos(ang) * r, -3 + 7 * p, math.sin(ang) * r, 0.2 + 0.3 * (1 - p), 0.1 + 0.85 * p ^ 2, p end },
    { name = "Gyro", n = 45, f = function(i, n, c)
        local ring = (i - 1) % 3; local idx = math.floor((i - 1) / 3)
        local a = idx / (n / 3) * math.pi * 2 + c * (1.5 + 0.35 * ring) * (ring == 1 and -1 or 1)
        local v = Vector3.new(math.cos(a) * 2.7, 0, math.sin(a) * 2.7)
        v = CFrame.Angles(0.5 + ring * 0.55, c * 0.28 * (ring + 1), ring * 0.9):VectorToWorldSpace(v)
        local tw = 0.5 + 0.5 * math.sin(c * 6 + i)
        return v.X, v.Y + 0.3, v.Z, 0.18 + 0.2 * tw, 0.05 + 0.5 * (1 - tw), ring / 3 end },
    { name = "Embers", n = 80, f = function(i, n, c)
        local h1, h2, h3 = hash(i), hash(i + 7), hash(i + 13)
        local p = (h1 + c * (0.3 + 0.35 * h2)) % 1
        local ang = h2 * 6.283 + c * 0.7 + p * 2; local r = (0.5 + 1.7 * h3) * (1 - 0.35 * p)
        return math.cos(ang) * r + math.sin(c * 2 + i) * 0.15, -3 + 6.8 * p, math.sin(ang) * r,
            0.5 * (1 - p) ^ 0.7 + 0.08, 0.08 + 0.9 * p ^ 1.6, p end },
    { name = "Galaxy", n = 90, f = function(i, n, c)
        local arm = (i - 1) % 3; local k = math.floor((i - 1) / 3) / (n / 3)
        local r = 0.6 + 2.8 * k; local ang = arm * 2.094 + k * 5.5 + c * (1.1 - 0.5 * k)
        local tw = 0.5 + 0.5 * math.sin(c * 5 + i * 1.7)
        return math.cos(ang) * r, 0.2 + math.sin(ang * 2 + c) * 0.18 * k + math.cos(ang) * r * 0.1, math.sin(ang) * r,
            0.1 + 0.22 * (1 - k) + 0.1 * tw, 0.05 + 0.6 * k * (1 - tw * 0.5), k end },
    { name = "Fireflies", n = 36, f = function(i, n, c)
        local h1, h2, h3 = hash(i), hash(i + 3), hash(i + 5)
        local a = h1 * 6.283 + c * (0.3 + h2 * 0.5); local r = 1.4 + 1.6 * h3 + 0.4 * math.sin(c * 0.9 + i)
        local pulse = 0.5 + 0.5 * math.sin(c * 2.6 + i * 3.1)
        return math.cos(a) * r, -2.2 + 5 * h2 + math.sin(c * 1.2 + i * 2) * 0.7, math.sin(a) * r,
            0.22 + 0.2 * pulse, 0.1 + 0.8 * (1 - pulse), pulse end },
    { name = "Pillars", n = 72, f = function(i, n, c)
        local col = (i - 1) % 9; local j = math.floor((i - 1) / 9)
        local a = col / 9 * 6.283 + c * 0.25; local h = 0.5 + 0.5 * math.sin(c * 1.4 + col * 1.3)
        local fade = 1 - j / 8
        return math.cos(a) * 2.5, -3 + j * (0.35 + 0.5 * h), math.sin(a) * 2.5,
            0.2 + 0.18 * fade, 0.1 + 0.8 * (1 - fade) ^ 1.3, j / 8 end },
    { name = "Plasma", n = 27, f = function(i, n, c)
        if i == 1 then return 0, 0.2, 0, 6.6 * (1 + 0.06 * math.sin(c * 3)), 0.86 - 0.05 * math.sin(c * 2), 0 end
        if i == 2 then return 0, 0.2, 0, 5.6 + 0.4 * math.sin(c * 3.4), 0.9, 0.5 end
        local k = i - 2; local a, b = c * 1.8 + k * 2.399, c * 1.1 + k * 1.3
        return math.cos(a) * math.cos(b) * 3, 0.2 + math.sin(b) * 2.6, math.sin(a) * math.cos(b) * 3,
            0.22 + 0.12 * math.sin(c * 4 + k), 0.1, 0.6 end },
    { name = "Rings", n = 72, f = function(i, n, c)
        local ring = (i - 1) % 4; local j = math.floor((i - 1) / 4)
        local p = (ring / 4 + c * 0.22) % 1; local a = j / 18 * 6.283 + c * (ring % 2 == 0 and 0.8 or -0.8)
        local r = 2.3 + 0.15 * math.sin(p * 6.283); local fade = math.sin(p * math.pi)
        return math.cos(a) * r, -3 + 6.6 * p, math.sin(a) * r, 0.14 + 0.1 * fade, 0.1 + 0.88 * (1 - fade) ^ 1.1, p end },
    { name = "Storm", n = 48, f = function(i, n, c)
        local arc = (i - 1) % 4; local j = math.floor((i - 1) / 4)
        local seed = math.floor(c * 9) * 4 + arc
        local dirA = hash(seed * 3 + 1) * 6.283 + (hash(seed * 3 + 3) - 0.5) * 0.9
        local dist = 1.2 + j * 0.36
        local x = math.cos(dirA) * dist + (hash(seed * 7 + j) - 0.5) * 0.7
        local z = math.sin(dirA) * dist + (hash(seed * 11 + j) - 0.5) * 0.7
        local y = 0.2 + (hash(seed * 3 + 2) - 0.5) * 4 + (hash(seed * 13 + j) - 0.5) * 0.7
        local on = (math.floor(c * 18 + arc * 3) % 3 == 0) and 0.1 or 0.55
        return x, y, z, 0.2 * (1 - j / 14) + 0.05, on + j / 20, j / 12 end },
}
local AURA_NAMES = {}
for i, a in ipairs(AURAS) do AURA_NAMES[i] = a.name end

registerFx("aura", S.aura, function(ctx)
    local inst = { clock = 0, parts = {}, def = nil }
    function inst.build()
        inst.def = AURAS[S.aura.style] or AURAS[1]
        local model = Instance.new("Model"); model.Name = "SC_Aura"; inst.parts = {}
        for i = 1, inst.def.n do local p = newBall(0.3, colors.aura, 0.3); p.Parent = model; inst.parts[i] = p end
        if not ctx.preview then
            inst.pivot = newBall(0.2, colors.aura, 1); inst.pivot.Parent = model
            inst.light = new("PointLight", { Color = colors.aura, Brightness = 1.6, Range = 18, Shadows = false, Parent = inst.pivot })
        end
        model.Parent = ctx.parent; inst.model = model
    end
    function inst.destroy()
        if inst.model then pcall(function() inst.model:Destroy() end) end
        inst.model, inst.parts, inst.pivot, inst.light = nil, {}, nil, nil
    end
    function inst.update(t, dt)
        local model = inst.model; if not model then return end
        local refs = ctx.refs; local root, hum = refs.root, refs.hum
        if not (root and root.Parent and hum and hum.Health > 0) then if model.Parent then model.Parent = nil end return end
        if model.Parent ~= ctx.parent then model.Parent = ctx.parent end
        inst.clock = inst.clock + dt * S.aura.speed
        local c, sc = inst.clock, S.aura.scale; local center = root.Position
        local def, base = inst.def, colors.aura; local rainbow = S.aura.rainbow
        for i, p in ipairs(inst.parts) do
            local x, y, z, size, tr, mix = def.f(i, def.n, c)
            size = math.max(size * sc, 0.06)
            p.CFrame = CFrame.new(center.X + x * sc, center.Y + y * sc, center.Z + z * sc)
            p.Size = Vector3.new(size, size, size); p.Transparency = math.clamp(tr, 0, 1)
            if rainbow then p.Color = Color3.fromHSV((c * 0.12 + mix * 0.35) % 1, 0.7, 1)
            else p.Color = base:Lerp(WHITE, mix * 0.5) end
        end
        if inst.pivot then
            inst.pivot.CFrame = CFrame.new(center)
            inst.light.Color = rainbow and Color3.fromHSV((c * 0.12) % 1, 0.7, 1) or base
        end
    end
    return inst
end)
F.aura.setStyle = function(name)
    for i, a in ipairs(AURAS) do if a.name == name then S.aura.style = i end end
    F.aura.rebuild()
end

-- ========== ORB ==========
registerFx("orb", S.orb, function(ctx)
    local inst = { clock = 0, orbs = {} }
    local TRAIL = 12
    local function orbPos(j, c)
        local a = c * 1.5 + j * math.pi; local r = 2.2 + 0.25 * math.sin(c * 0.9 + j)
        return Vector3.new(math.cos(a) * r, 0.2 + 1.7 * math.sin(c * 1.1 + j * 1.3), math.sin(a) * r)
    end
    function inst.build()
        local model = Instance.new("Model"); model.Name = "SC_Orb"; inst.orbs = {}
        for j = 0, 1 do
            local o = { j = j, sats = {}, trail = {} }
            o.core = newBall(0.85, WHITE, 0); o.core.Parent = model
            o.shell = newBall(1.7, colors.orb, 0.55); o.shell.Parent = model
            for s = 1, 3 do local b = newBall(0.28, colors.orb:Lerp(WHITE, 0.4), 0.05); b.Parent = model; o.sats[s] = b end
            for k = 1, TRAIL do local b = newBall(0.5, colors.orb, 0.3); b.Parent = model; o.trail[k] = b end
            if not ctx.preview then new("PointLight", { Color = colors.orb, Brightness = 2, Range = 14, Shadows = false, Parent = o.core }) end
            inst.orbs[#inst.orbs + 1] = o
        end
        model.Parent = ctx.parent; inst.model = model
    end
    function inst.destroy()
        if inst.model then pcall(function() inst.model:Destroy() end) end
        inst.model, inst.orbs = nil, {}
    end
    function inst.update(t, dt)
        local model = inst.model; if not model then return end
        local refs = ctx.refs; local root, hum = refs.root, refs.hum
        if not (root and root.Parent and hum and hum.Health > 0) then if model.Parent then model.Parent = nil end return end
        if model.Parent ~= ctx.parent then model.Parent = ctx.parent end
        inst.clock = inst.clock + dt; local c = inst.clock; local center = root.Position
        local base = S.orb.rainbow and Color3.fromHSV((c * 0.12) % 1, 0.7, 1) or colors.orb
        for _, o in ipairs(inst.orbs) do
            local pos = center + orbPos(o.j, c)
            o.core.CFrame = CFrame.new(pos); o.shell.CFrame = CFrame.new(pos)
            local sz = 1.7 + 0.2 * math.sin(c * 4 + o.j)
            o.shell.Size = Vector3.new(sz, sz, sz); o.shell.Color = base; o.core.Color = WHITE:Lerp(base, 0.15)
            for s, b in ipairs(o.sats) do
                local ang = c * 5 + s * 2.094
                b.CFrame = CFrame.new(pos + Vector3.new(math.cos(ang) * 0.85, math.sin(c * 3 + s) * 0.5, math.sin(ang) * 0.85))
                b.Color = base:Lerp(WHITE, 0.4)
            end
            for k, b in ipairs(o.trail) do
                local f = k / TRAIL; local size = 0.55 * (1 - f) ^ 0.9 + 0.06
                b.CFrame = CFrame.new(center + orbPos(o.j, c - k * 0.05))
                b.Size = Vector3.new(size, size, size); b.Transparency = 0.2 + 0.78 * f; b.Color = base
            end
        end
    end
    return inst
end)

-- ========== SELEHER ==========
registerFx("seleher", S.seleher, function(ctx)
    local inst = { items = {}, trails = {}, wisps = {}, ribbons = {}, emitter = nil }
    local function colorSeq(c)
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.3, c:Lerp(WHITE, 0.4)), ColorSequenceKeypoint.new(1, c),
        })
    end
    local function buildWorld()
        local root = ctx.refs.root
        if not (root and root.Parent) then return end
        local function att(x, y, z)
            local a = Instance.new("Attachment"); a.Position = Vector3.new(x, y, z); a.Parent = root
            inst.items[#inst.items + 1] = a; return a
        end
        local function makeTrail(a0, a1, life)
            local tr = new("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = life, MinLength = 0.02,
                FaceCamera = true, LightEmission = 0.9, LightInfluence = 0, Color = colorSeq(colors.trail),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.5), NumberSequenceKeypoint.new(1, 1) }),
                WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = root })
            inst.items[#inst.items + 1] = tr; inst.trails[#inst.trails + 1] = tr
        end
        makeTrail(att(0, 1.1, 0.7), att(0, -1.3, 0.7), 1.3)
        for i, s in ipairs({ -1, 1 }) do
            local a0, a1 = att(s * 0.5, 0.6, 0.8), att(s * 0.5, 0.05, 0.8)
            makeTrail(a0, a1, 1.0); inst.wisps[#inst.wisps + 1] = { a0 = a0, a1 = a1, s = s, phase = i * 1.7 }
        end
        local back = att(0, 0.2, 0.9)
        inst.emitter = new("ParticleEmitter", { Rate = 26, Lifetime = NumberRange.new(0.9, 1.5), Speed = NumberRange.new(0.2, 1.4),
            SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-80, 80),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.26), NumberSequenceKeypoint.new(1, 0) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
            Color = ColorSequence.new(colors.trail:Lerp(WHITE, 0.3)), LightEmission = 1, Parent = back })
        inst.items[#inst.items + 1] = inst.emitter
    end
    local function buildPreview()
        local folder = Instance.new("Folder"); folder.Name = "SC_PreviewTrail"; folder.Parent = ctx.parent
        inst.items[1] = folder
        for ri, side in ipairs({ 0, -1, 1 }) do
            local list = {}
            for i = 1, 18 do local b = newBall(0.5, colors.trail, 0.2); b.Parent = folder; list[i] = b end
            inst.ribbons[ri] = { balls = list, side = side, phase = ri * 1.7 }
        end
    end
    function inst.build() if ctx.preview then buildPreview() else buildWorld() end end
    function inst.destroy()
        for _, i in ipairs(inst.items) do pcall(function() i:Destroy() end) end
        inst.items, inst.trails, inst.wisps, inst.ribbons, inst.emitter = {}, {}, {}, {}, nil
    end
    function inst.recolor()
        for _, tr in ipairs(inst.trails) do tr.Color = colorSeq(colors.trail) end
        if inst.emitter then inst.emitter.Color = ColorSequence.new(colors.trail:Lerp(WHITE, 0.3)) end
        for _, r in ipairs(inst.ribbons) do for _, b in ipairs(r.balls) do b.Color = colors.trail end end
    end
    function inst.update(t)
        if ctx.preview then
            local torso = ctx.refs.torso
            if not (torso and torso.Parent) then return end
            for _, r in ipairs(inst.ribbons) do
                local n = #r.balls
                for i, b in ipairs(r.balls) do
                    local s = (i - 1) / (n - 1)
                    local x = r.side * (0.5 + s * 1.2) + math.sin(t * 2.2 - s * 5 + r.phase) * 0.5 * s
                    local y = (r.side == 0 and 0.6 or 0.2) + math.sin(t * 1.7 - s * 4 + r.phase) * 0.45 * (0.3 + s)
                    b.CFrame = torso.CFrame * CFrame.new(x, y, 0.9 + s * 5.2)
                    local sz = math.max(0.5 * (1 - s) ^ 0.8, 0.06)
                    b.Size = Vector3.new(sz, sz, sz); b.Transparency = 0.15 + 0.85 * s ^ 1.3
                end
            end
        else
            for _, w in ipairs(inst.wisps) do
                local x = w.s * (0.5 + 0.9 * math.sin(t * 3.2 + w.phase))
                local y = 0.6 + 0.35 * math.sin(t * 2.4 + w.phase)
                w.a0.Position = Vector3.new(x, y, 0.8)
                w.a1.Position = Vector3.new(x, y - 0.55, 0.8)
            end
        end
    end
    return inst
end)

table.insert(ON_LOCAL_CHAR, function()
    local w = FX.seleher.world
    if w.built then w.destroy(); w.build() end
    local h = FX.hat.world
    if h.built then h.destroy(); h.build() end
    local c = FX.circle.world
    c.topOff, c.botOff = nil, nil
end)

-- ========== ANGELS ==========
registerFx("angels", S.angels, function(ctx)
    local inst = { objects = {}, ring = nil }
    if ctx.preview then
        function inst.build()
            inst.ring = buildRing(ctx.parent, CFG.ANGEL_RADIUS, CFG.ANGEL_SEGMENTS, CFG.ANGEL_THICK,
                CFG.ANGEL_THICK * 0.85, colors.angel, 0, "SC_PreviewHalo")
        end
        function inst.destroy()
            if inst.ring then pcall(function() inst.ring.model:Destroy() end); inst.ring = nil end
        end
        function inst.recolor() if inst.ring then ringSetColor(inst.ring, colors.angel) end end
        function inst.update(t)
            local head = ctx.refs.head
            if not (inst.ring and head and head.Parent) then return end
            local pos = head.Position + Vector3.new(0, head.Size.Y / 2 + CFG.ANGEL_HEIGHT + math.sin(t * 2) * 0.04, 0)
            inst.ring.model:PivotTo(CFrame.new(pos) * CFrame.Angles(math.sin(t * 1.2) * 0.05, 0, math.cos(t) * 0.05))
        end
        return inst
    end
    local function wanted(p)
        if S.angels.mode == "Everyone" then return true end
        if S.angels.mode == "Me" then return p == LocalPlayer end
        return p ~= LocalPlayer
    end
    local function remove(p)
        local o = inst.objects[p]
        if o then pcall(function() o.ring.model:Destroy() end); inst.objects[p] = nil end
    end
    local function removeAll()
        local list = {}
        for p in pairs(inst.objects) do list[#list + 1] = p end
        for _, p in ipairs(list) do remove(p) end
    end
    local function headOf(p) local ch = p.Character; return ch and ch:FindFirstChild("Head") end
    function inst.refresh()
        if not (inst.built and S.angels.enabled) then removeAll(); return end
        for _, p in ipairs(Players:GetPlayers()) do
            local head = headOf(p); local obj = inst.objects[p]
            if wanted(p) and head then
                if not obj or obj.head ~= head then
                    remove(p)
                    local ring = buildRing(fxFolder, CFG.ANGEL_RADIUS, CFG.ANGEL_SEGMENTS, CFG.ANGEL_THICK,
                        CFG.ANGEL_THICK * 0.85, colors.angel, 0, "SC_Angel_" .. p.Name)
                    inst.objects[p] = { ring = ring, head = head, phase = math.random() * 6.28 }
                end
            elseif obj then remove(p) end
        end
        local stale = {}
        for p in pairs(inst.objects) do if not p.Parent then stale[#stale + 1] = p end end
        for _, p in ipairs(stale) do remove(p) end
    end
    function inst.build() inst.refresh() end
    function inst.destroy() removeAll() end
    function inst.recolor() for _, o in pairs(inst.objects) do ringSetColor(o.ring, colors.angel) end end
    function inst.update(t)
        local cam = Workspace.CurrentCamera; local camPos = cam and cam.CFrame.Position
        for _, o in pairs(inst.objects) do
            local head, model = o.head, o.ring.model
            if head and head.Parent then
                local pos = head.Position + Vector3.new(0, head.Size.Y / 2 + CFG.ANGEL_HEIGHT + math.sin(t * 2 + o.phase) * 0.04, 0)
                if camPos and (camPos - pos).Magnitude > CFG.ANGEL_MAX_DISTANCE then
                    if model.Parent then model.Parent = nil end
                else
                    if model.Parent ~= fxFolder then model.Parent = fxFolder end
                    model:PivotTo(CFrame.new(pos) * CFrame.Angles(math.sin(t * 1.2 + o.phase) * 0.05, 0, math.cos(t + o.phase) * 0.05))
                end
            elseif model.Parent then model.Parent = nil end
        end
    end
    watchPlayers(function(p, ch) ch:WaitForChild("Head", 10); inst.refresh() end,
        function(p) remove(p) end, remove, true)
    return inst
end)
F.angels.mode = function(m) S.angels.mode = m; FX.angels.world.refresh() end

-- ========== RAIN ==========
do
    local rain = { folder = nil, drops = {} }
    local function destroyRain()
        if rain.folder then pcall(function() rain.folder:Destroy() end) end
        rain.folder, rain.drops = nil, {}
    end
    local function respawn(d, cp)
        d.x = cp.X + (math.random() - 0.5) * 80; d.z = cp.Z + (math.random() - 0.5) * 80
        d.y = cp.Y + 14 + math.random() * 24
    end
    local function buildRain()
        destroyRain()
        local folder = Instance.new("Folder"); folder.Name = "SC_Rain"
        local cam = Workspace.CurrentCamera; local cp = cam and cam.CFrame.Position or Vector3.new()
        for i = 1, CFG.RAIN_COUNT do
            local p = Instance.new("Part"); p.Material = Enum.Material.Neon; p.Color = colors.particles
            p.Size = Vector3.new(0.13, 0.5 + math.random() * 0.9, 0.13)
            p.Transparency = 0.15 + math.random() * 0.3; styleFxPart(p); p.Parent = folder
            local d = { part = p, speed = 20 + math.random() * 16, tr = p.Transparency }
            respawn(d, cp); d.y = cp.Y - 20 + math.random() * 46; rain.drops[i] = d
        end
        folder.Parent = fxFolder; rain.folder = folder
    end
    F.sky = {
        set = function(v) S.sky.enabled = v and true or false; if S.sky.enabled then buildRain() else destroyRain() end end,
        recolor = function() for _, d in ipairs(rain.drops) do d.part.Color = colors.particles end end,
        density = function(percent) S.sky.density = percent / 100 end,
    }
    table.insert(UPDATERS, function(t, dt)
        if not (S.sky.enabled and rain.folder) then return end
        local cam = Workspace.CurrentCamera; if not cam then return end
        local cp = cam.CFrame.Position; local active = math.floor(CFG.RAIN_COUNT * S.sky.density + 0.5)
        for i, d in ipairs(rain.drops) do
            if i <= active then
                d.y = d.y - d.speed * dt
                if d.y < cp.Y - 24 or (d.x - cp.X) ^ 2 + (d.z - cp.Z) ^ 2 > 3000 then respawn(d, cp) end
                d.part.CFrame = CFrame.new(d.x, d.y, d.z); d.part.Transparency = d.tr
            else d.part.Transparency = 1 end
        end
    end)
end

-- ========== DARK ==========
do
    local dark = { orig = nil, cc = nil, sky = nil, atmo = nil, stash = {}, last = 0 }
    local L = CFG.DARK_LEVEL
    local PROPS = { "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation" }
    local function stashSky()
        for _, child in ipairs(Lighting:GetChildren()) do
            if (child:IsA("Sky") or child:IsA("Atmosphere")) and child ~= dark.sky and child ~= dark.atmo then
                dark.stash[#dark.stash + 1] = { inst = child, parent = Lighting }; child.Parent = nil
            end
        end
    end
    local function enforce()
        local o = dark.orig; if not o then return end
        local amb = o.Ambient or Color3.fromRGB(70, 70, 70); local out = o.OutdoorAmbient or Color3.fromRGB(70, 70, 70)
        local want = { Brightness = math.max((o.Brightness or 2) * (1 - 0.6 * L), 0.2),
            Ambient = amb:Lerp(colors.dark, 0.55 * L), OutdoorAmbient = out:Lerp(colors.dark, 0.55 * L),
            ExposureCompensation = (o.ExposureCompensation or 0) - 1.2 * L }
        for prop, val in pairs(want) do pcall(function() if Lighting[prop] ~= val then Lighting[prop] = val end end) end
    end
    local function enable()
        dark.orig = {}
        for _, p in ipairs(PROPS) do pcall(function() dark.orig[p] = Lighting[p] end) end
        dark.cc = new("ColorCorrectionEffect", { Name = "SC_Darkening", Brightness = -0.1 * L, Contrast = 0.15 * L,
            Saturation = -0.2 * L, TintColor = colors.dark:Lerp(WHITE, 0.82), Parent = Lighting })
        stashSky()
        dark.sky = new("Sky", { Name = "SC_DarkSky", SkyboxBk = "", SkyboxDn = "", SkyboxFt = "", SkyboxLf = "",
            SkyboxRt = "", SkyboxUp = "", StarCount = 2500, CelestialBodiesShown = false, Parent = Lighting })
        dark.atmo = new("Atmosphere", { Name = "SC_DarkAtmosphere", Color = colors.dark:Lerp(BLACK, 0.45),
            Decay = colors.dark:Lerp(BLACK, 0.7), Density = 0.3, Offset = 0.6, Glare = 0, Haze = 0.3, Parent = Lighting })
        enforce()
    end
    local function disable()
        for _, k in ipairs({ "cc", "sky", "atmo" }) do if dark[k] then pcall(function() dark[k]:Destroy() end); dark[k] = nil end end
        for _, s in ipairs(dark.stash) do pcall(function() s.inst.Parent = s.parent end) end
        dark.stash = {}
        if dark.orig then for p, v in pairs(dark.orig) do pcall(function() Lighting[p] = v end) end; dark.orig = nil end
    end
    local function recolor()
        if dark.cc then dark.cc.TintColor = colors.dark:Lerp(WHITE, 0.82) end
        if dark.atmo then dark.atmo.Color = colors.dark:Lerp(BLACK, 0.45); dark.atmo.Decay = colors.dark:Lerp(BLACK, 0.7) end
    end
    F.dark = {
        set = function(v) v = v and true or false; if v == S.dark.enabled then return end
            S.dark.enabled = v; if v then enable() else disable() end end,
        recolor = recolor,
    }
    table.insert(UPDATERS, function(t)
        if not S.dark.enabled then return end
        enforce()
        if t - dark.last > 0.5 then dark.last = t; stashSky() end
    end)
end

-- ========== SHOTS ==========
local shotListeners = {}
do
    local lastShot, lastEquip = 0, 0
    local function getOrigin(character, tool, aimPoint)
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("Attachment") and hasAny(d.Name, CFG.MUZZLE_KEYWORDS) then return d.WorldPosition
            elseif d:IsA("BasePart") and hasAny(d.Name, CFG.MUZZLE_KEYWORDS) then return d.Position end
        end
        local handle = tool:FindFirstChild("Handle")
        if not (handle and handle:IsA("BasePart")) then handle = tool:FindFirstChildWhichIsA("BasePart", true) end
        if handle then
            local toAim = aimPoint - handle.Position
            if toAim.Magnitude > 0.1 then return handle.Position + toAim.Unit * math.min(handle.Size.Magnitude * 0.5, 2.5) end
            return handle.Position
        end
        local head = character:FindFirstChild("Head"); if head then return head.Position end
        local root = character:FindFirstChild("HumanoidRootPart"); return root and root.Position or nil
    end
    local function doShot()
        local character = LocalPlayer.Character
        local tool = character and character:FindFirstChildOfClass("Tool")
        if not tool or CFG.IGNORED_TOOLS[tool.Name] then return end
        local camera = Workspace.CurrentCamera; if not camera then return end
        local now = os.clock()
        if now - lastEquip < CFG.EQUIP_GRACE or now - lastShot < CFG.SHOT_COOLDOWN then return end
        lastShot = now
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { character, fxFolder }
        params.IgnoreWater = true
        local sp
        if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then sp = camera.ViewportSize / 2
        else sp = UserInputService:GetMouseLocation() end
        local ray = camera:ViewportPointToRay(sp.X, sp.Y)
        local aimRes = Workspace:Raycast(ray.Origin, ray.Direction * CFG.RANGE, params)
        local aimPoint = aimRes and aimRes.Position or (ray.Origin + ray.Direction * CFG.RANGE)
        local origin = getOrigin(character, tool, aimPoint); if not origin then return end
        local dir = aimPoint - origin
        if dir.Magnitude < 0.1 then dir = ray.Direction end
        dir = dir.Unit
        local res = Workspace:Raycast(origin, dir * CFG.RANGE, params)
        local endPos = res and res.Position or (origin + dir * CFG.RANGE)
        local hitRes = aimRes or res; local hitInst = hitRes and hitRes.Instance
        local hitPos = hitRes and hitRes.Position
        for _, fn in ipairs(shotListeners) do
            local ok, err = pcall(fn, origin, endPos, hitInst, hitPos, ray.Origin, ray.Direction)
            if not ok then warn("[Sporeny] shot: " .. tostring(err)) end
        end
    end
    local function isShotTrack(track)
        local names = { track.Name or "" }
        if track.Animation then names[#names + 1] = track.Animation.Name end
        for _, n in ipairs(names) do
            local lower = string.lower(n)
            if CFG.SHOT_ANIMS[lower] then return true end
            if #CFG.SHOT_KEYWORDS > 0 and hasAny(lower, CFG.SHOT_KEYWORDS) and not hasAny(lower, CFG.SHOT_EXCLUDE) then return true end
        end
        return false
    end
    table.insert(ON_LOCAL_CHAR, function(char)
        local hum = charRefs.hum; if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
        if not animator then return end
        table.insert(connections, animator.AnimationPlayed:Connect(function(track)
            task.defer(function()
                if not isShotTrack(track) then return end
                if hum.Health <= 0 then return end
                if CFG.IGNORE_ZERO_WEIGHT and (track.Speed == 0 or track.WeightTarget == 0) then return end
                local ok, err = pcall(doShot)
                if not ok then warn("[Sporeny] " .. tostring(err)) end
            end)
        end))
        table.insert(connections, char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then lastEquip = os.clock() end
        end))
    end)
end

-- ========== TRACER ==========
do
    local tr = { enabled = false, active = {} }
    local function create(a, b)
        local dist = (b - a).Magnitude; if dist < 1 then return end
        local col = colors.tracer
        local folder = Instance.new("Folder"); folder.Name = "SC_Tracer"
        local function anchor(pos)
            local p = Instance.new("Part"); p.Size = Vector3.new(0.1, 0.1, 0.1); p.Transparency = 1
            styleFxPart(p); p.CFrame = CFrame.new(pos); p.Parent = folder
            local at = Instance.new("Attachment"); at.Parent = p; return p, at
        end
        local pa, at0 = anchor(a); local pb, at1 = anchor(b)
        local outer = new("Beam", { Attachment0 = at0, Attachment1 = at1, Width0 = 0.7, Width1 = 0.7, LightEmission = 1,
            LightInfluence = 0, FaceCamera = true, Segments = 1, Transparency = NumberSequence.new(0.45),
            Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, col:Lerp(WHITE, 0.6)),
                ColorSequenceKeypoint.new(0.5, col), ColorSequenceKeypoint.new(1, col:Lerp(WHITE, 0.3)) }), Parent = pa })
        local inner = new("Beam", { Attachment0 = at0, Attachment1 = at1, Width0 = 0.18, Width1 = 0.18, LightEmission = 1,
            LightInfluence = 0, FaceCamera = true, Segments = 1, Transparency = NumberSequence.new(0),
            Color = ColorSequence.new(WHITE), Parent = pa })
        local line = Instance.new("Part"); line.Size = Vector3.new(0.5, 0.5, dist); line.Transparency = 1
        styleFxPart(line); line.CFrame = CFrame.lookAt((a + b) / 2, b); line.Parent = folder
        local sparks = new("ParticleEmitter", { Enabled = false, Rate = 0, Lifetime = NumberRange.new(0.5, 1.1),
            Speed = NumberRange.new(0.2, 2.2), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360),
            RotSpeed = NumberRange.new(-120, 120),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
            Color = ColorSequence.new(col:Lerp(WHITE, 0.4)), LightEmission = 1, Parent = line })
        sparks:Emit(math.clamp(math.floor(dist * 1.5), 12, 80))
        local orb = newBall(0.7, WHITE, 0); orb.CFrame = CFrame.new(a); orb.Parent = folder
        local o0 = new("Attachment", { Position = Vector3.new(0, 0.3, 0), Parent = orb })
        local o1 = new("Attachment", { Position = Vector3.new(0, -0.3, 0), Parent = orb })
        local orbTrail = new("Trail", { Attachment0 = o0, Attachment1 = o1, Lifetime = 0.25, MinLength = 0.02,
            FaceCamera = true, LightEmission = 1, Color = ColorSequence.new(col),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
            WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = orb })
        new("PointLight", { Color = col, Brightness = 2, Range = 10, Shadows = false, Parent = orb })
        local impact = new("ParticleEmitter", { Enabled = false, Rate = 0, Lifetime = NumberRange.new(0.3, 0.8),
            Speed = NumberRange.new(6, 16), SpreadAngle = Vector2.new(180, 180),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
            Color = ColorSequence.new(col:Lerp(WHITE, 0.5)), LightEmission = 1, Parent = at1 })
        local flash = newBall(0.6, col:Lerp(WHITE, 0.5), 0.2); flash.CFrame = CFrame.new(b); flash.Parent = folder
        folder.Parent = fxFolder
        table.insert(tr.active, { folder = folder, outer = outer, inner = inner, orb = orb, orbTrail = orbTrail,
            impact = impact, flash = flash, a = a, b = b, t0 = os.clock(), hit = false })
    end
    table.insert(shotListeners, function(origin, endPos) if tr.enabled then create(origin, endPos) end end)
    F.tracer = { set = function(v) tr.enabled = v and true or false end, recolor = function() end }
    table.insert(UPDATERS, function(t)
        for i = #tr.active, 1, -1 do
            local a = tr.active[i]; local el = t - a.t0
            if el >= CFG.TRACER_LIFE + 1.4 then pcall(function() a.folder:Destroy() end); table.remove(tr.active, i)
            else
                local u = math.min(el / CFG.TRACER_LIFE, 1)
                if u < 1 then
                    local w = (1 - u) ^ 1.4
                    a.outer.Width0, a.outer.Width1 = 0.7 * w, 0.7 * w
                    a.inner.Width0, a.inner.Width1 = 0.18 * w, 0.18 * w
                    a.outer.Transparency = NumberSequence.new(0.45 + 0.55 * u)
                else a.outer.Enabled = false; a.inner.Enabled = false end
                local s = math.min(el / CFG.TRACER_TRAVEL, 1); local ease = 1 - (1 - s) ^ 3
                if s < 1 then a.orb.CFrame = CFrame.new(a.a:Lerp(a.b, ease))
                elseif not a.hit then
                    a.hit = true; a.orb.Transparency = 1; a.orbTrail.Enabled = false; a.impact:Emit(18)
                end
                if a.hit then
                    local fu = math.clamp((el - CFG.TRACER_TRAVEL) / 0.35, 0, 1)
                    local size = 0.6 + 3.2 * fu; a.flash.Size = Vector3.new(size, size, size)
                    a.flash.Transparency = 0.2 + 0.8 * fu
                else a.flash.Transparency = 1 end
            end
        end
    end)
end

-- ========== JUMP ==========
do
    local jump = { last = 0, fall = 0 }
    local function spawnAt(power)
        local root = charRefs.root; if not root then return end
        local pos, normal = findGround(root.Position); spawnGroundRings(pos, normal, colors.jump, power)
    end
    table.insert(ON_LOCAL_CHAR, function()
        local hum = charRefs.hum; if not hum then return end
        jump.fall = 0
        table.insert(connections, hum.StateChanged:Connect(function(_, new)
            if not S.jump.enabled then return end
            local now = os.clock()
            if new == Enum.HumanoidStateType.Landed then
                local speed = jump.fall; jump.fall = 0
                if speed >= CFG.LAND_MIN_SPEED and now - jump.last > 0.12 then jump.last = now; spawnAt(math.clamp(speed / 55, 0.7, 1.6)) end
            elseif new == Enum.HumanoidStateType.Jumping then
                jump.fall = 0
                if now - jump.last > 0.12 then jump.last = now; spawnAt(0.6) end
            elseif new == Enum.HumanoidStateType.Freefall then jump.fall = 0 end
        end))
    end)
    F.jump = { set = function(v) S.jump.enabled = v and true or false end, recolor = function() end }
    table.insert(UPDATERS, function()
        local hum, root = charRefs.hum, charRefs.root
        if S.jump.enabled and hum and root and hum.Parent and hum:GetState() == Enum.HumanoidStateType.Freefall then
            local vy = -root.AssemblyLinearVelocity.Y; if vy > jump.fall then jump.fall = vy end
        end
    end)
end

-- ========== KILLS ==========
do
    local kills = { enabled = false, mode = "Auto", scale = 1, rainbow = false, souls = {}, deaths = {}, pending = nil, lastAward = 0 }
    local function prepareGhost(char)
        local changed = {}
        local function force(i) if not i.Archivable then i.Archivable = true; changed[#changed + 1] = i end end
        force(char); for _, d in ipairs(char:GetDescendants()) do force(d) end
        local ok, clone = pcall(function() return char:Clone() end)
        for _, i in ipairs(changed) do pcall(function() i.Archivable = false end) end
        if not (ok and clone) then return nil end
        local parts = {}
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("BillboardGui")
                or d:IsA("SurfaceGui") or d:IsA("Highlight") or d:IsA("Humanoid") or d:IsA("Animator")
                or d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") or d:IsA("Shirt") or d:IsA("Pants")
                or d:IsA("ShirtGraphic") or d:IsA("BodyColors") or d:IsA("CharacterMesh") or d:IsA("Tool")
                or d:IsA("Trail") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("PointLight") then
                pcall(function() d:Destroy() end)
            elseif d:IsA("BasePart") then
                d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false
                pcall(function() d.LocalTransparencyModifier = 0 end)
                if d:IsA("MeshPart") then pcall(function() d.TextureID = "" end) end
                if d.Transparency < 0.95 then parts[#parts + 1] = d end
            elseif d:IsA("SpecialMesh") then pcall(function() d.TextureId = "" end) end
        end
        local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
        if not root then clone:Destroy(); return nil end
        clone.PrimaryPart = root
        local torso = clone:FindFirstChild("UpperTorso") or clone:FindFirstChild("Torso") or root
        return { model = clone, parts = parts, root = root, torso = torso }
    end
    local function spawnSoul(prep, origin, corpse)
        while #kills.souls >= CFG.SOUL_MAX do pcall(function() table.remove(kills.souls, 1).folder:Destroy() end) end
        local s = kills.scale; local hue = math.random()
        local color = kills.rainbow and Color3.fromHSV(hue, 0.75, 1) or colors.soul
        local folder = Instance.new("Folder"); folder.Name = "SC_Soul"
        local so = { folder = folder, origin = origin, t0 = os.clock(), seed = math.random() * math.pi * 2,
            color = color, rainbow = kills.rainbow, hue = hue, scale = s, alive = true, parts = {} }
        if prep then
            so.kind = "clone"; so.model = prep.model; so.rot0 = prep.root.CFrame - prep.root.CFrame.Position
            for _, p in ipairs(prep.parts) do p.Material = Enum.Material.Neon; p.Color = color; p.Transparency = 0.42; so.parts[#so.parts + 1] = p end
            local hl = Instance.new("Highlight"); hl.FillColor = color; hl.FillTransparency = 0.5
            hl.OutlineColor = WHITE; hl.OutlineTransparency = 0.15; hl.DepthMode = Enum.HighlightDepthMode.Occluded
            hl.Adornee = prep.model; hl.Parent = prep.model; so.highlight = hl
            local t0 = new("Attachment", { Position = Vector3.new(0, 0.9, 0), Parent = prep.torso })
            local t1 = new("Attachment", { Position = Vector3.new(0, -0.9, 0), Parent = prep.torso })
            so.trail = new("Trail", { Attachment0 = t0, Attachment1 = t1, Lifetime = 0.9, MinLength = 0.03,
                FaceCamera = true, LightEmission = 0.9, Color = ColorSequence.new(color, color:Lerp(WHITE, 0.5)),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
                WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
                Parent = prep.torso })
            so.emitter = new("ParticleEmitter", { Rate = 70, Lifetime = NumberRange.new(0.8, 1.4),
                Speed = NumberRange.new(0.5, 2.2), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360),
                RotSpeed = NumberRange.new(-90, 90),
                Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3 * s), NumberSequenceKeypoint.new(1, 0) }),
                Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
                Color = ColorSequence.new(color), LightEmission = 1, Parent = prep.torso })
            so.light = new("PointLight", { Color = color, Brightness = 2, Range = 16, Shadows = false, Parent = prep.torso })
            prep.model.Parent = folder
        end
        local beamH = 26 * s
        local beam = Instance.new("Part"); beam.Shape = Enum.PartType.Cylinder; beam.Material = Enum.Material.Neon
        beam.Color = color; beam.Transparency = 0.45; beam.Size = Vector3.new(beamH, 0.7 * s, 0.7 * s)
        styleFxPart(beam); beam.CFrame = CFrame.new(origin + Vector3.new(0, beamH / 2 - 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
        beam.Parent = folder
        tween(beam, 1.4, { Transparency = 1, Size = Vector3.new(beamH, 0.05, 0.05) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        local gpos, gnormal = findGround(origin, corpse); spawnGroundRings(gpos, gnormal, color, 1.1 * s)
        folder.Parent = fxFolder; table.insert(kills.souls, so)
    end
    table.insert(UPDATERS, function(t)
        for i = #kills.souls, 1, -1 do
            local so = kills.souls[i]; local el = t - so.t0
            if el >= CFG.SOUL_DURATION + 1.3 then pcall(function() so.folder:Destroy() end); table.remove(kills.souls, i)
            else
                local u = math.min(el / CFG.SOUL_DURATION, 1)
                local rise
                if u < 0.18 then rise = 1.6 * (1 - (1 - u / 0.18) ^ 3) else rise = 1.6 + 22 * ((u - 0.18) / 0.82) ^ 1.6 end
                local spiral = math.sin(math.min(u * 1.1, 1) * math.pi) * 1.5
                local ang = so.seed + u * 9
                local pos = so.origin + Vector3.new(math.cos(ang) * spiral, rise, math.sin(ang) * spiral)
                local fu = math.clamp((u - 0.65) / 0.35, 0, 1); local fade = fu * fu * (3 - 2 * fu)
                local c = so.color; if so.rainbow then c = Color3.fromHSV((so.hue + el * 0.5) % 1, 0.75, 1) end
                if u < 1 then
                    if so.kind == "clone" then
                        so.model:PivotTo(CFrame.new(pos) * CFrame.Angles(math.sin(el * 3) * 0.08, el * 1.4, math.cos(el * 2.4) * 0.08) * so.rot0)
                        for idx, p in ipairs(so.parts) do
                            p.Transparency = math.clamp(0.42 + 0.58 * fade + 0.05 * math.sin(t * 12 + idx), 0, 1)
                            if so.rainbow then p.Color = c end
                        end
                        so.highlight.FillTransparency = 0.5 + 0.5 * fade
                        so.highlight.OutlineTransparency = 0.15 + 0.85 * fade
                        if so.rainbow then
                            so.highlight.FillColor = c; so.trail.Color = ColorSequence.new(c, c:Lerp(WHITE, 0.5))
                            so.emitter.Color = ColorSequence.new(c); so.light.Color = c
                        end
                        so.light.Brightness = 2 * (1 - fade)
                    end
                elseif so.alive then
                    so.alive = false
                    if so.kind == "clone" then
                        for _, p in ipairs(so.parts) do p.Transparency = 1 end
                        so.highlight.FillTransparency = 1; so.highlight.OutlineTransparency = 1
                        so.light.Enabled = false; so.trail.Enabled = false
                    end
                end
            end
        end
    end)
    local TAGS = { "creator", "killer", "lastattacker", "lastdamager", "attacker", "tag" }
    local function refersToMe(v)
        if v == nil then return false end
        if v == LocalPlayer then return true end
        local tv = typeof(v)
        if tv == "Instance" then local ch = LocalPlayer.Character; return ch ~= nil and (v == ch or v:IsDescendantOf(ch))
        elseif tv == "string" then return v == LocalPlayer.Name
        elseif tv == "number" then return v == LocalPlayer.UserId end
        return false
    end
    local function taggedByMe(char, hum)
        for _, holder in ipairs({ hum, char }) do
            for _, child in ipairs(holder:GetChildren()) do
                if (child:IsA("ObjectValue") or child:IsA("StringValue") or child:IsA("IntValue"))
                    and hasAny(child.Name, TAGS) and refersToMe(child.Value) then return true end
            end
            for name, val in pairs(holder:GetAttributes()) do if hasAny(name, TAGS) and refersToMe(val) then return true end end
        end
        return false
    end
    local function award(rec)
        rec.used = true; kills.lastAward = os.clock(); kills.pending = nil
        spawnSoul(rec.prep, rec.pos, rec.char); rec.prep = nil
    end
    local function onDeath(p, char, hum)
        if not kills.enabled then return end
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("Head")
        if not root then return end
        local now = os.clock()
        local rec = { player = p, char = char, pos = root.Position, time = now, used = false, prep = prepareGhost(char) }
        table.insert(kills.deaths, rec)
        while #kills.deaths > 12 do
            local old = table.remove(kills.deaths, 1); if old.prep then pcall(function() old.prep.model:Destroy() end) end
        end
        task.delay(CFG.KILL_MATCH_WINDOW + 0.5, function()
            if not rec.used and rec.prep then pcall(function() rec.prep.model:Destroy() end); rec.prep = nil end
        end)
        if kills.mode == "Any Death" then
            local me = charRefs.root
            if not me or (root.Position - me.Position).Magnitude <= CFG.KILL_ANY_DISTANCE then award(rec) end
            return
        end
        if taggedByMe(char, hum) then award(rec)
        elseif kills.pending and now - kills.pending < CFG.KILL_MATCH_WINDOW then award(rec) end
    end
    local function onKillSignal()
        local now = os.clock(); if now - kills.lastAward < 0.8 then return end
        for i = #kills.deaths, 1, -1 do
            local d = kills.deaths[i]
            if not d.used and now - d.time < CFG.KILL_MATCH_WINDOW then award(d); return end
        end
        kills.pending = now
    end
    local function isKillStat(name)
        local n = string.lower(name); if n == "ko" or n == "kos" then return true end
        return hasAny(n, { "kill", "elim", "frag", "defeat", "wipe" })
    end
    local function hookStats(folder)
        local function watch(v)
            if not (v:IsA("IntValue") or v:IsA("NumberValue")) or not isKillStat(v.Name) then return end
            local last = v.Value
            table.insert(connections, v.Changed:Connect(function(new)
                if new > last and kills.enabled and kills.mode == "Auto" then onKillSignal() end
                last = new
            end))
        end
        for _, v in ipairs(folder:GetChildren()) do watch(v) end
        table.insert(connections, folder.ChildAdded:Connect(watch))
    end
    local ls = LocalPlayer:FindFirstChild("leaderstats"); if ls then hookStats(ls) end
    table.insert(connections, LocalPlayer.ChildAdded:Connect(function(c)
        if string.lower(c.Name) == "leaderstats" then hookStats(c) end
    end))
    watchPlayers(function(p, char)
        local hum = char:WaitForChild("Humanoid", 10); if not hum then return end
        table.insert(connections, hum.Died:Connect(function()
            local ok, err = pcall(onDeath, p, char, hum)
            if not ok then warn("[Sporeny] kill: " .. tostring(err)) end
        end))
    end, nil, nil, false)
    F.kills = {
        set = function(v) kills.enabled = v and true or false; kills.pending = nil end,
        mode = function(m) kills.mode = m end,
        size = function(percent) kills.scale = percent / 100 end,
        color = function(c, name) if name == "Rainbow" then kills.rainbow = true else kills.rainbow = false; colors.soul = c end end,
    }
end

-- ========== HITSOUND ==========
local showHitMarker
do
    local PING = CFG.HIT_SOUND_ID
    local SNAP = "rbxasset://sounds/snap.wav"
    local BASS = "rbxasset://sounds/bass.wav"
    local function style(name, id, pitch, high, mid, low, decay, wet, notes)
        return { name = name, id = id, pitch = pitch, high = high, mid = mid, low = low, decay = decay, wet = wet, notes = notes }
    end
    local HIT_STYLES = {
        style("Soft Bell", PING, 0.62, -40, -3, 3, 1.8, -5, { { 1, 1, 0 }, { 1.5, 0.6, 0.07 } }),
        style("Glass", PING, 1.3, -14, 0, -6, 2.4, -4, { { 1, 1, 0 }, { 1.5, 0.55, 0.06 }, { 2, 0.4, 0.12 } }),
        style("Marimba", PING, 0.9, -28, 2, 0, 0.6, -10, { { 1, 1, 0 }, { 1.26, 0.7, 0.08 } }),
        style("Pop", SNAP, 1.1, -6, 0, 0, 0.5, -12, { { 1, 1, 0 } }),
        style("Thud", BASS, 1.5, -12, 0, 0, 0.4, -14, { { 1, 1, 0 } }),
        style("Crystal", PING, 1.6, -18, 0, -4, 1.6, -5, { { 1, 0.7, 0 }, { 1.26, 0.6, 0.05 }, { 1.5, 0.6, 0.1 }, { 2, 0.7, 0.15 } }),
        style("Chime", PING, 1.0, -22, 0, -2, 2.0, -5, { { 1.5, 0.9, 0 }, { 1.26, 0.8, 0.12 }, { 1, 0.8, 0.24 } }),
        style("Coin", PING, 1.7, -10, 0, -6, 0.8, -9, { { 1, 0.9, 0 }, { 1.33, 1, 0.07 } }),
        style("Harp", PING, 0.7, -30, 0, 0, 2.2, -5, { { 1, 0.8, 0 }, { 1.26, 0.8, 0.06 }, { 1.5, 0.8, 0.12 }, { 2, 0.8, 0.18 }, { 2.52, 0.7, 0.24 } }),
        style("Drum", BASS, 1.2, -8, 2, 3, 0.5, -12, { { 1, 1, 0 }, { 1.5, 0.7, 0.09 } }),
        style("Laser", PING, 2.0, -6, 0, -4, 0.7, -10, { { 1.6, 0.8, 0 }, { 1.3, 0.7, 0.04 }, { 1, 0.7, 0.08 }, { 0.8, 0.6, 0.12 } }),
        style("Sparkle", PING, 1.8, -14, 0, -4, 1.4, -6, { { 1, 0.5, 0 }, { 1.26, 0.5, 0.04 }, { 1.5, 0.5, 0.08 }, { 2, 0.5, 0.12 }, { 2.52, 0.5, 0.16 }, { 3, 0.5, 0.2 } }),
    }
    local HEAD_STYLES = {
        { name = "Rising",  notes = { { 1, 1, 0 }, { 1.26, 0.9, 0.06 }, { 1.5, 0.9, 0.12 }, { 2, 1, 0.19 } } },
        { name = "Fanfare", notes = { { 1, 1, 0 }, { 1, 1, 0.09 }, { 1.5, 1, 0.18 }, { 2, 1.1, 0.3 } } },
        { name = "Sparkle", notes = { { 1, 0.6, 0 }, { 1.26, 0.6, 0.04 }, { 1.5, 0.6, 0.08 }, { 2, 0.6, 0.12 }, { 2.52, 0.6, 0.16 }, { 3, 0.7, 0.2 } } },
        { name = "Impact",  notes = { { 0.5, 1.2, 0 }, { 1, 0.9, 0.05 }, { 2, 0.9, 0.1 } } },
    }
    local HIT_NAMES, HEAD_NAMES = {}, {}
    for i, s in ipairs(HIT_STYLES) do HIT_NAMES[i] = s.name end
    for i, s in ipairs(HEAD_STYLES) do HEAD_NAMES[i] = s.name end
    local hit = { enabled = false, volume = 1, style = 1, headStyle = 1, customId = nil, headId = nil, watchers = {} }
    local function playStyle(st, ratio, vol, delay)
        task.delay(delay or 0, function()
            local s = Instance.new("Sound"); s.SoundId = st.id; s.Volume = vol; s.PlaybackSpeed = st.pitch * ratio
            pcall(function()
                local eq = Instance.new("EqualizerSoundEffect"); eq.HighGain = st.high; eq.MidGain = st.mid; eq.LowGain = st.low; eq.Parent = s
                local rv = Instance.new("ReverbSoundEffect"); rv.DecayTime = st.decay; rv.Density = 0.9; rv.Diffusion = 0.9
                rv.DryLevel = -1; rv.WetLevel = st.wet; rv.Parent = s
            end)
            s.Parent = fxFolder; s:Play(); Debris:AddItem(s, 6)
        end)
    end
    local function playNotes(st, notes, vol) for _, n in ipairs(notes) do playStyle(st, n[1], vol * n[2], n[3]) end end
    local function playRaw(id, vol, delay)
        task.delay(delay or 0, function()
            local s = Instance.new("Sound"); s.SoundId = id; s.Volume = vol; s.Parent = fxFolder; s:Play(); Debris:AddItem(s, 8)
        end)
    end
    local function trigger(isHead)
        local vol = hit.volume; local st = HIT_STYLES[hit.style] or HIT_STYLES[1]
        if hit.customId then playRaw(hit.customId, vol, 0)
        elseif isHead then local hs = HEAD_STYLES[hit.headStyle] or HEAD_STYLES[1]; playNotes(st, hs.notes, vol)
        else playNotes(st, st.notes, vol) end
        if showHitMarker then showHitMarker(isHead) end
    end
    local function watchHum(hum, isHead)
        local w = hit.watchers[hum]
        if not w then
            w = { queue = {}, last = hum.Health }
            w.conn = hum.HealthChanged:Connect(function(new)
                if new < w.last then
                    local now = os.clock()
                    while #w.queue > 0 and now - w.queue[1].time > CFG.HIT_WINDOW do table.remove(w.queue, 1) end
                    local rec = table.remove(w.queue, 1); if rec then trigger(rec.head) end
                end
                w.last = new
            end)
            hit.watchers[hum] = w
        end
        table.insert(w.queue, { head = isHead, time = os.clock() })
        task.delay(CFG.HIT_WINDOW + 0.5, function()
            local last = w.queue[#w.queue]
            if hit.watchers[hum] == w and (not last or os.clock() - last.time > CFG.HIT_WINDOW) then
                w.conn:Disconnect(); hit.watchers[hum] = nil
            end
        end)
    end
    table.insert(shotListeners, function(_, _, inst, hitPos, rayOrigin, rayDir)
        if not (hit.enabled and inst) then return end
        local model = inst:FindFirstAncestorWhichIsA("Model")
        local hum = model and model:FindFirstChildOfClass("Humanoid")
        if not hum or hum == charRefs.hum or hum.Health <= 0 then return end
        local head = model:FindFirstChild("Head"); local isHead = inst.Name == "Head"
        if not isHead and head then
            local radius = math.max(head.Size.X, head.Size.Y, head.Size.Z) * 0.6
            if hitPos and (hitPos - head.Position).Magnitude <= radius * 1.25 then isHead = true end
        end
        watchHum(hum, isHead)
    end)
    F.hitsound = {
        styleNames = HIT_NAMES, headStyleNames = HEAD_NAMES,
        set = function(v) hit.enabled = v and true or false end,
        setStyle = function(name) for i, s in ipairs(HIT_STYLES) do if s.name == name then hit.style = i end end; trigger(false) end,
        setHeadStyle = function(name) for i, s in ipairs(HEAD_STYLES) do if s.name == name then hit.headStyle = i end end end,
        volume = function(percent) hit.volume = percent / 100 end,
        setHitId = function(text) hit.customId = normalizeSoundId(text) end,
        setHeadId = function(text) hit.headId = normalizeSoundId(text) end,
    }
end

-- ========== HUD ==========
do
    local state = { enabled = false, fps = nil, ping = nil, game = tostring(game.Name), acc = 0, frames = 0, samples = {} }
    local hud = new("Frame", { Name = "Hud", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16),
        Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = BLACK,
        BackgroundTransparency = 0.05, BorderSizePixel = 0, Active = true, Visible = false, Parent = gui },
        { corner(8), stroke(C.border, 1), new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
    local label = new("TextLabel", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13, RichText = true,
        TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = hud })
    makeDraggable(hud, hud)
    local function refresh()
        local sep = " <font color='#8a8a8a'>|</font> "
        local fps = state.fps and tostring(state.fps) or "--"
        local ms = state.ping and tostring(state.ping) or "--"
        label.Text = "<b>" .. LocalPlayer.Name .. "</b>" .. sep .. "<font color='#9a9a9a'>FPS:</font> " .. fps
            .. sep .. "<font color='#9a9a9a'>ms:</font> " .. ms .. sep .. "<font color='#9a9a9a'>Game:</font> " .. state.game
            .. sep .. "<b>Sporeny</b>"
    end
    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name then state.game = info.Name; refresh() end
    end)
    F.hud = { set = function(v) state.enabled = v and true or false; hud.Visible = state.enabled; if state.enabled then refresh() end end }
    table.insert(UPDATERS, function(_, dt)
        state.frames = state.frames + 1; state.acc = state.acc + dt
        if state.acc >= 0.5 then
            state.fps = math.floor(state.frames / state.acc + 0.5); state.frames, state.acc = 0, 0
            if state.enabled then
                local p = readPing()
                if p then table.insert(state.samples, p); if #state.samples > 6 then table.remove(state.samples, 1) end
                    local sum = 0; for _, v in ipairs(state.samples) do sum = sum + v end
                    state.ping = math.floor(sum / #state.samples + 0.5) end
                refresh()
            end
        end
    end)
end

-- ========== SILENT AIM ==========
local SA = { enabled = false, delay = 0.15, range = 500, aimPart = "Head", teamCheck = true,
    target = nil, lastFire = 0, silentPt = nil }
local SA_BIND = "SC_SilentAim"
local SA_WINDOW = 0.7
local SIL = env.__SC_Silent
if not SIL then SIL = { namecallOk = false, indexOk = false, info = "", armed = false, bypass = false,
    point = nil, targetPart = nil, mouse = nil }; env.__SC_Silent = SIL end
local hooksAvailable = typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function"
local function saSilentPoint() if SA.silentPt and os.clock() - SA.lastFire < SA_WINDOW then return SA.silentPt end; return nil end
local function installSAHooks()
    if SIL.namecallOk then return true, SIL.info end
    if not hooksAvailable then return false, "no hookmetamethod" end
    local newcc = (typeof(newcclosure) == "function") and newcclosure or function(f) return f end
    local checkc = (typeof(checkcaller) == "function") and checkcaller or function() return false end
    local setnm = (typeof(setnamecallmethod) == "function") and setnamecallmethod or nil
    local getnm = getnamecallmethod
    local RAY_METHODS = { FindPartOnRay = true, FindPartOnRayWithIgnoreList = true, FindPartOnRayWithWhitelist = true }
    local ok = pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcc(function(self, ...)
            if SIL.armed and not SIL.bypass then
                local method = getnm()
                local isRaycast = (method == "Raycast")
                local isRayFind = RAY_METHODS[method]
                local isCamRay = (method == "ViewportPointToRay" or method == "ScreenPointToRay")
                if (isRaycast or isRayFind or isCamRay) and not checkc() then
                    local pt = SIL.point and SIL.point()
                    if pt then
                        if isRaycast then
                            if rawequal(self, Workspace) then
                                local origin, direction = ...
                                if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                                    local to = pt - origin
                                    if to.Magnitude > 0.1 then
                                        if setnm then setnm("Raycast") end
                                        return oldNamecall(self, origin, to.Unit * math.max(direction.Magnitude, to.Magnitude + 300), select(3, ...))
                                    end
                                end
                            end
                        elseif isRayFind then
                            local ray = ...
                            if typeof(ray) == "Ray" then
                                local to = pt - ray.Origin
                                if to.Magnitude > 0.1 then
                                    if setnm then setnm(method) end
                                    return oldNamecall(self, Ray.new(ray.Origin, to.Unit * math.max(ray.Direction.Magnitude, to.Magnitude + 300)), select(2, ...))
                                end
                            end
                        else
                            if rawequal(self, Workspace.CurrentCamera) then
                                local r = oldNamecall(self, ...)
                                if typeof(r) == "Ray" then
                                    local to = pt - r.Origin
                                    if to.Magnitude > 0.1 then return Ray.new(r.Origin, to.Unit * (r.Direction.Magnitude + 300)) end
                                end
                                return r
                            end
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end))
    end)
    if not ok then return false, "namecall hook failed" end
    SIL.namecallOk = true
    local ok2 = pcall(function()
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", newcc(function(self, key)
            if SIL.armed and not SIL.bypass and rawequal(self, SIL.mouse) and not checkc() then
                if key == "Hit" then local pt = SIL.point and SIL.point(); if pt then return CFrame.new(pt) end
                elseif key == "Target" then local part = SIL.targetPart and SIL.targetPart(); if part then return part end
                elseif key == "UnitRay" then local pt = SIL.point and SIL.point(); local cam = Workspace.CurrentCamera
                    if pt and cam then return Ray.new(cam.CFrame.Position, (pt - cam.CFrame.Position).Unit) end end
            end
            return oldIndex(self, key)
        end))
    end)
    SIL.indexOk = ok2 and true or false
    SIL.info = SIL.indexOk and "ray+mouse" or "ray only"
    return true, SIL.info
end
local function saRefresh()
    SIL.armed = false; if not SA.enabled then return end
    if installSAHooks() then
        SIL.point = saSilentPoint
        SIL.targetPart = function() return SA.target and SA.target.part or nil end
        SIL.mouse = LocalPlayer:GetMouse(); SIL.armed = true
    end
end
local function saGetPart(ch, name)
    if name == "Head" then return ch:FindFirstChild("Head") end
    if name == "Body" then return ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso") or ch:FindFirstChild("HumanoidRootPart") end
    return ch:FindFirstChild("Head")
end
local function saCandidate(p)
    if p == LocalPlayer then return nil end
    if SA.teamCheck and p.Team ~= nil and p.Team == LocalPlayer.Team then return nil end
    local ch = p.Character; if not ch then return nil end
    local hum = ch:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return nil end
    if ch:FindFirstChildOfClass("ForceField") then return nil end
    local part = saGetPart(ch, SA.aimPart); if not (part and part:IsA("BasePart")) then return nil end
    return ch, hum, part
end
local function saBlocked(origin, point, ignoreBase)
    local ignore = {}
    for i, v in ipairs(ignoreBase) do ignore[i] = v end
    local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.IgnoreWater = true
    for _ = 1, 6 do
        params.FilterDescendantsInstances = ignore
        local res = Workspace:Raycast(origin, point - origin, params)
        if not res then return false end
        local inst = res.Instance
        if inst:IsA("Terrain") then return true end
        if inst.Transparency >= 0.9 or not inst.CanCollide then ignore[#ignore + 1] = inst
        else return true end
    end
    return true
end
local function saVisiblePoint(eye, part, ignore)
    local s = part.Size; local c = part.Position
    local pts = { c, c + Vector3.new(0, s.Y * 0.3, 0), c + part.CFrame.RightVector * (s.X * 0.3), c - part.CFrame.RightVector * (s.X * 0.3) }
    for _, pt in ipairs(pts) do if not saBlocked(eye, pt, ignore) then return pt end end
    return nil
end
local function saBuildIgnore()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then list[#list + 1] = p.Character end end
    return list
end
local function saScan(cam, eye, ignore)
    local best, bestDist
    for _, p in ipairs(Players:GetPlayers()) do
        local ch, hum, part = saCandidate(p)
        if ch then
            local d = (part.Position - eye).Magnitude
            if d <= SA.range and (not bestDist or d < bestDist) then
                local pt = saVisiblePoint(eye, part, ignore)
                if pt then best = { player = p, hum = hum, part = part, dist = d, aim = pt }; bestDist = d end
            end
        end
    end
    return best
end
local saLastNudge = {}
local function saNudge(tgt)
    if not (tgt and tgt.hum and tgt.hum.Parent) then return end
    local hum = tgt.hum; local before = hum.Health; local now = os.clock()
    if saLastNudge[hum] and now - saLastNudge[hum] < 0.08 then return end
    saLastNudge[hum] = now
    task.delay(0.08, function()
        if not (hum and hum.Parent) then return end
        if hum.Health >= before and hum.Health > 0 then pcall(function() hum:TakeDamage(1) end) end
    end)
end
local function saStep()
    local cam = Workspace.CurrentCamera
    local char, hum = charRefs.char, charRefs.hum
    if not (cam and char and hum and hum.Health > 0) then SA.silentPt, SA.target = nil, nil return end
    local tool = char:FindFirstChildOfClass("Tool"); if not tool then SA.target, SA.silentPt = nil, nil return end
    local eye = charRefs.head and charRefs.head.Position or cam.CFrame.Position
    SA.target = saScan(cam, eye, saBuildIgnore())
    local tgt = SA.target; if not tgt then SA.silentPt = nil return end
    SA.silentPt = tgt.part.Position
    if os.clock() - SA.lastFire >= SA.delay then
        SA.lastFire = os.clock(); SIL.bypass = false
        pcall(function() tool:Activate() end); saNudge(tgt)
    end
end
F.silentaim = {
    set = function(v)
        v = v and true or false; SA.enabled = v
        pcall(function() RunService:UnbindFromRenderStep(SA_BIND) end)
        SA.target, SA.silentPt = nil, nil
        if v then
            RunService:BindToRenderStep(SA_BIND, Enum.RenderPriority.Last.Value, function()
                SIL.bypass = true; local ok, err = pcall(saStep); SIL.bypass = false
                if not ok then warn("[SA] " .. tostring(err)) end
            end)
        end
        saRefresh()
    end,
    delay = function(ms) SA.delay = ms / 1000 end,
    range = function(v) SA.range = v end,
    aimPart = function(name) SA.aimPart = name; SA.target = nil end,
    teamCheck = function(v) SA.teamCheck = v and true or false end,
}

-- ========== AIM BOT (плавно → жёсткий лок) ==========
local AB = { enabled = false, teamCheck = true, range = 500, aimPart = "Head",
    smoothTime = 0.35, lockTime = 0.15, lockFov = 55, target = nil, phase = "idle",
    phaseStart = 0, lockPoint = nil }
local AB_BIND = "SC_AimBot"

local function abGetPart(ch, name)
    if name == "Head" then return ch:FindFirstChild("Head") end
    if name == "Body" then return ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso") or ch:FindFirstChild("HumanoidRootPart") end
    return ch:FindFirstChild("Head")
end
local function abCandidate(p)
    if p == LocalPlayer then return nil end
    if AB.teamCheck and p.Team ~= nil and p.Team == LocalPlayer.Team then return nil end
    local ch = p.Character; if not ch then return nil end
    local hum = ch:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return nil end
    if ch:FindFirstChildOfClass("ForceField") then return nil end
    local part = abGetPart(ch, AB.aimPart); if not (part and part:IsA("BasePart")) then return nil end
    return ch, hum, part
end
local function abVisible(eye, part)
    local ignore = {}
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then ignore[#ignore + 1] = p.Character end end
    return saVisiblePoint(eye, part, ignore) ~= nil
end
local function abScan(cam, eye)
    local look = cam.CFrame.LookVector; local camPos = cam.CFrame.Position; local best, bestDist
    for _, p in ipairs(Players:GetPlayers()) do
        local ch, hum, part = abCandidate(p)
        if ch then
            local d = (part.Position - eye).Magnitude
            if d <= AB.range and (not bestDist or d < bestDist) then
                local to = part.Position - camPos
                if to.Magnitude > 0.01 then
                    local ang = math.deg(math.acos(math.clamp(look:Dot(to.Unit), -1, 1)))
                    if ang <= AB.lockFov and abVisible(eye, part) then
                        best = { player = p, hum = hum, part = part, dist = d }; bestDist = d
                    end
                end
            end
        end
    end
    return best
end
local function abAimAt(cam, point, alpha)
    local camPos = cam.CFrame.Position; local to = point - camPos
    if to.Magnitude < 0.1 then return end
    local focus = cam.Focus.Position; local zoom = (camPos - focus).Magnitude
    local newPos, dir
    if zoom > 0.6 and zoom < 80 and (point - focus).Magnitude > 0.5 then
        dir = (point - focus).Unit; newPos = focus - dir * zoom
    else dir = to.Unit; newPos = camPos end
    local desired = CFrame.lookAt(newPos, newPos + dir)
    if alpha >= 1 then cam.CFrame = desired else cam.CFrame = cam.CFrame:Lerp(desired, alpha) end
end
local function abStep()
    local cam = Workspace.CurrentCamera
    local char, hum = charRefs.char, charRefs.hum
    if not (cam and char and hum and hum.Health > 0) then AB.target, AB.phase = nil, "idle" return end
    local eye = charRefs.head and charRefs.head.Position or cam.CFrame.Position
    local now = os.clock()
    local t = AB.target
    if t then
        local alive = t.hum.Parent and t.hum.Health > 0 and t.part.Parent
        local inRange = alive and (t.part.Position - eye).Magnitude <= AB.range
        local visible = alive and abVisible(eye, t.part)
        if not (alive and inRange and visible) then AB.target, AB.phase, AB.lockPoint = nil, "idle", nil
        else AB.lockPoint = t.part.Position end
    end
    if not AB.target then
        AB.target = abScan(cam, eye)
        if AB.target then AB.phase = "smooth"; AB.phaseStart = now; AB.lockPoint = AB.target.part.Position
        else AB.phase = "idle"; return end
    end
    local tgt = AB.target; if not tgt then return end
    if AB.phase == "smooth" then
        local alpha = math.clamp((now - AB.phaseStart) / math.max(AB.smoothTime, 0.01), 0, 1)
        local eased = 1 - (1 - alpha) * (1 - alpha)
        abAimAt(cam, AB.lockPoint, eased * 0.85)
        if now - AB.phaseStart >= AB.smoothTime + AB.lockTime then AB.phase = "locked" end
    elseif AB.phase == "locked" then
        abAimAt(cam, AB.lockPoint, 1)
    end
end
F.aimbot = {
    set = function(v)
        v = v and true or false; AB.enabled = v
        pcall(function() RunService:UnbindFromRenderStep(AB_BIND) end)
        AB.target, AB.phase, AB.lockPoint = nil, "idle", nil
        if v then
            RunService:BindToRenderStep(AB_BIND, Enum.RenderPriority.Camera.Value + 1, function()
                local ok, err = pcall(abStep); if not ok then warn("[AB] " .. tostring(err)) end
            end)
        end
    end,
    aimPart = function(name) AB.aimPart = name; AB.target, AB.phase = nil, "idle" end,
    teamCheck = function(v) AB.teamCheck = v and true or false; AB.target = nil end,
    range = function(v) AB.range = v end,
    smooth = function(v) AB.smoothTime = math.clamp(v, 0.05, 1.0) end,
    lock = function(v) AB.lockTime = math.clamp(v, 0.0, 1.0) end,
    fov = function(v) AB.lockFov = v end,
}

-- ========== ESP / SPIN / THIRD ==========
-- ESP переработан: без чёрного прямоугольного фона, только текст (имя/HP/дистанция) с тонкой
-- обводкой текста (UIStroke на TextLabel) для читаемости на любом фоне. Highlight-обводка модели
-- осталась, но тоньше. Автодетект: вход нового игрока -> мгновенный ESP (watchPlayers уже эмитит
-- при PlayerAdded+CharacterAdded); смерть -> не убираем ESP, помечаем DEAD пока труп существует;
-- возрождение -> CharacterAdded срабатывает заново и buildEsp пересоздаёт объект на новом char.
do
    local esp = { enabled = false, objects = {}, lastInfo = 0 }
    local function textColor() return (luma(colors.esp) < 0.25) and WHITE or colors.esp end
    local function removeEsp(p)
        local e = esp.objects[p]
        if e then pcall(function() if e.highlight then e.highlight:Destroy() end end)
            pcall(function() e.tag:Destroy() end); esp.objects[p] = nil end
    end
    local function refreshInfo(e, myRoot)
        local dead = e.dead or (e.hum and e.hum.Health <= 0)
        local maxHp = e.hum and e.hum.MaxHealth or 100
        local hp = dead and 0 or math.max(0, math.floor(e.hum.Health + 0.5))
        local dist = myRoot and math.floor((e.lastPos - myRoot.Position).Magnitude + 0.5) or 0
        if dead then
            e.info.Text = "DEAD  |  " .. dist .. "m"; e.info.TextColor3 = C.sub
        else
            e.info.Text = hp .. " HP  |  " .. dist .. "m"; e.info.TextColor3 = textColor()
        end
    end
    local function buildEsp(p, char)
        local head = char:WaitForChild("Head", 5); local hum = char:WaitForChild("Humanoid", 5)
        if not (head and hum) then return end
        if not esp.enabled or p.Character ~= char then return end
        removeEsp(p)
        local tag = Instance.new("Part"); tag.Name = "SC_EspTag"; tag.Size = Vector3.new(0.2, 0.2, 0.2)
        tag.Transparency = 1; styleFxPart(tag); tag.CFrame = CFrame.new(head.Position); tag.Parent = fxFolder
        -- тонкая обводка модели (без заливки — только контур), уменьшенная толщина обводки
        local hl = Instance.new("Highlight"); hl.Name = "SC_Esp"; hl.Adornee = char
        hl.FillTransparency = 1; hl.OutlineColor = colors.esp
        hl.OutlineTransparency = 0; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = fxFolder
        -- BillboardGui без фона: только текст, компактнее прежнего
        local bb = new("BillboardGui", { Adornee = tag, AlwaysOnTop = true, Size = UDim2.fromOffset(140, 34),
            StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0), LightInfluence = 0, ResetOnSpawn = false, Parent = tag })
        local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
        local nameLabel = new("TextLabel", { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 15),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = textColor(),
            TextTruncate = Enum.TextTruncate.AtEnd, Text = p.Name, Parent = holder },
            { new("UIStroke", { Color = BLACK, Thickness = 1, Transparency = 0.25 }) })
        local info = new("TextLabel", { Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 13),
            BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10.5,
            TextColor3 = textColor(), Text = "", Parent = holder },
            { new("UIStroke", { Color = BLACK, Thickness = 1, Transparency = 0.25 }) })
        esp.objects[p] = { tag = tag, highlight = hl, nameLabel = nameLabel, info = info,
            head = head, hum = hum, char = char, lastPos = head.Position, dead = false }
        refreshInfo(esp.objects[p], charRefs.root)
    end
    -- includeSelf=false: сами себе ESP не рисуем. onRemoving помечает DEAD, не убирает -
    -- даёт "увидел кто убит" до фактического удаления модели. PlayerAdded в watchPlayers уже
    -- покрывает "кто только зашёл" автоматически.
    watchPlayers(function(p, char) if esp.enabled then buildEsp(p, char) end end,
        function(p) local e = esp.objects[p]; if e then e.dead = true end end, removeEsp, false)
    F.esp = {
        set = function(v)
            esp.enabled = v and true or false
            if esp.enabled then for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then task.spawn(buildEsp, p, p.Character) end end
            else local list = {}; for p in pairs(esp.objects) do list[#list + 1] = p end
                for _, p in ipairs(list) do removeEsp(p) end end
        end,
        recolor = function()
            for _, e in pairs(esp.objects) do
                if e.highlight then e.highlight.OutlineColor = colors.esp end
                e.nameLabel.TextColor3 = textColor(); if not e.dead then e.info.TextColor3 = textColor() end
            end
        end,
    }
    table.insert(UPDATERS, function(t)
        if not esp.enabled then return end
        local doInfo = t - esp.lastInfo >= 1; if doInfo then esp.lastInfo = t end
        local myRoot = charRefs.root
        for _, e in pairs(esp.objects) do
            if e.head and e.head.Parent then e.lastPos = e.head.Position; e.tag.CFrame = CFrame.new(e.lastPos)
            elseif not e.dead then e.dead = true; doInfo = true end
            if e.highlight and not e.char.Parent then e.highlight:Destroy(); e.highlight = nil end
            if doInfo then refreshInfo(e, myRoot) end
        end
    end)
    local spin = { enabled = false, speed = 1200, orig = nil }
    F.spin = {
        set = function(v)
            spin.enabled = v and true or false; local hum = charRefs.hum
            if spin.enabled then if hum then spin.orig = hum.AutoRotate; hum.AutoRotate = false end
            else if hum and spin.orig ~= nil then hum.AutoRotate = spin.orig end; spin.orig = nil end
        end,
        speed = function(v) spin.speed = v end,
    }
    table.insert(ON_LOCAL_CHAR, function() local hum = charRefs.hum; if spin.enabled and hum then spin.orig = hum.AutoRotate; hum.AutoRotate = false end end)
    table.insert(connections, RunService.Heartbeat:Connect(function(dt)
        if not spin.enabled then return end
        local root, hum = charRefs.root, charRefs.hum
        if root and root.Parent and hum and hum.Health > 0 then
            if hum.AutoRotate then hum.AutoRotate = false end
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(spin.speed) * dt, 0)
        end
    end))
    local tp = { enabled = false, dist = 14, orig = nil, last = 0 }
    local function applyTp()
        pcall(function()
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            LocalPlayer.CameraMinZoomDistance = tp.dist
            LocalPlayer.CameraMaxZoomDistance = math.max(128, tp.dist + 60)
        end)
    end
    F.third = {
        set = function(v)
            v = v and true or false; if v == tp.enabled then return end; tp.enabled = v
            if v then
                pcall(function() tp.orig = { mode = LocalPlayer.CameraMode, min = LocalPlayer.CameraMinZoomDistance,
                    max = LocalPlayer.CameraMaxZoomDistance } end)
                applyTp()
            elseif tp.orig then
                pcall(function() LocalPlayer.CameraMode = tp.orig.mode
                    LocalPlayer.CameraMinZoomDistance = tp.orig.min
                    LocalPlayer.CameraMaxZoomDistance = tp.orig.max end)
                tp.orig = nil
            end
        end,
        distance = function(v) tp.dist = v; if tp.enabled then applyTp() end end,
    }
    table.insert(UPDATERS, function(t) if tp.enabled and t - tp.last > 0.25 then tp.last = t; applyTp() end end)
end

-- ========== CONFIG SYSTEM (save/select/load) ==========
-- Хранит все toggle/slider/selector/color состояния в одной таблице и дампит через writefile в
-- JSON (encode/decode есть почти во всех executor'ах: Synapse/ScriptWare/Fluxus/KRNL дают их
-- глобально; фоллбэк на HttpService:JSONEncode/Decode если нет). Папка на никнейм игрока ->
-- несколько файлов конфигов внутри (запрошено "сохраняет на ник", так что путь =
-- CONFIG_FOLDER/<Nick>/<ConfigName>.json). listCfg сканит папку ника.
local ConfigSys = {}
do
    local hasFS = typeof(writefile) == "function" and typeof(readfile) == "function"
        and typeof(isfile) == "function" and typeof(isfolder) == "function" and typeof(makefolder) == "function"
    local function jsonEncode(t)
        if typeof(HttpService) ~= "nil" then end
        local ok, HttpService = pcall(function() return game:GetService("HttpService") end)
        if ok and HttpService then local ok2, res = pcall(function() return HttpService:JSONEncode(t) end); if ok2 then return res end end
        return nil
    end
    local function jsonDecode(s)
        local ok, HttpService = pcall(function() return game:GetService("HttpService") end)
        if ok and HttpService then local ok2, res = pcall(function() return HttpService:JSONDecode(s) end); if ok2 then return res end end
        return nil
    end
    local function nickFolder()
        local safe = tostring(LocalPlayer.Name):gsub("[^%w_%-]", "_")
        return CFG.CONFIG_FOLDER .. "/" .. safe
    end
    local function ensureFolders()
        if not hasFS then return false end
        local root = CFG.CONFIG_FOLDER
        pcall(function() if not isfolder(root) then makefolder(root) end end)
        local nf = nickFolder()
        pcall(function() if not isfolder(nf) then makefolder(nf) end end)
        return true
    end
    local function sanitizeName(name)
        name = tostring(name or ""):gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return nil end
        return name
    end

    -- снапшот текущего состояния всех фич (то что реально можно "включить обратно" через F.*.set)
    local function snapshot()
        return {
            version = 1,
            colors = {
                hat = { colors.hat.R, colors.hat.G, colors.hat.B }, circle = { colors.circle.R, colors.circle.G, colors.circle.B },
                angel = { colors.angel.R, colors.angel.G, colors.angel.B }, wings = { colors.wings.R, colors.wings.G, colors.wings.B },
                trail = { colors.trail.R, colors.trail.G, colors.trail.B }, particles = { colors.particles.R, colors.particles.G, colors.particles.B },
                tracer = { colors.tracer.R, colors.tracer.G, colors.tracer.B }, jump = { colors.jump.R, colors.jump.G, colors.jump.B },
                soul = { colors.soul.R, colors.soul.G, colors.soul.B }, esp = { colors.esp.R, colors.esp.G, colors.esp.B },
                aura = { colors.aura.R, colors.aura.G, colors.aura.B }, orb = { colors.orb.R, colors.orb.G, colors.orb.B },
                dark = { colors.dark.R, colors.dark.G, colors.dark.B },
            },
            S = {
                hat = { enabled = S.hat.enabled, scale = S.hat.scale },
                circle = { enabled = S.circle.enabled, scale = S.circle.scale, speed = S.circle.speed },
                angels = { enabled = S.angels.enabled, mode = S.angels.mode },
                wings = { enabled = S.wings.enabled, scale = S.wings.scale },
                seleher = { enabled = S.seleher.enabled },
                aura = { enabled = S.aura.enabled, style = S.aura.style, scale = S.aura.scale, speed = S.aura.speed, rainbow = S.aura.rainbow },
                orb = { enabled = S.orb.enabled, rainbow = S.orb.rainbow },
                sky = { enabled = S.sky.enabled, density = S.sky.density },
                dark = { enabled = S.dark.enabled },
                jump = { enabled = S.jump.enabled },
            },
            aimbot = { enabled = AB.enabled, aimPart = AB.aimPart, teamCheck = AB.teamCheck, range = AB.range,
                smoothTime = AB.smoothTime, lockTime = AB.lockTime, lockFov = AB.lockFov },
            silentaim = { enabled = SA.enabled, aimPart = SA.aimPart, teamCheck = SA.teamCheck, range = SA.range, delayMs = SA.delay * 1000 },
            esp = { enabled = (FX and false) or nil }, -- placeholder, реальное значение ставится ниже через closure capture
        }
    end

    -- esp/spin/third/hud/tracer/jump/kills/hitsound хранятся не в S/AB/SA, поэтому отдельные геттеры,
    -- которые проставляются после определения этих модулей (см. ConfigSys.captureExtra ниже)
    local extraGet, extraApply

    function ConfigSys.bindExtra(getFn, applyFn) extraGet = getFn; applyFn_ = applyFn; extraApply = applyFn end

    function ConfigSys.save(name)
        name = sanitizeName(name)
        if not name then return false, "empty name" end
        if not hasFS then return false, "no filesystem api" end
        ensureFolders()
        local data = snapshot()
        if extraGet then data.extra = extraGet() end
        local encoded = jsonEncode(data)
        if not encoded then return false, "json encode failed" end
        local path = nickFolder() .. "/" .. name .. ".json"
        local ok, err = pcall(function() writefile(path, encoded) end)
        if not ok then return false, tostring(err) end
        return true, name
    end

    function ConfigSys.list()
        if not hasFS or typeof(listfiles) ~= "function" then return {} end
        ensureFolders()
        local nf = nickFolder()
        local out = {}
        local ok, files = pcall(function() return listfiles(nf) end)
        if ok and files then
            for _, path in ipairs(files) do
                local name = path:match("([^/\\]+)%.json$")
                if name then out[#out + 1] = name end
            end
        end
        table.sort(out)
        return out
    end

    local function applyColor3(tbl) if tbl and tbl[1] then return Color3.new(tbl[1], tbl[2], tbl[3]) end return nil end

    function ConfigSys.load(name)
        name = sanitizeName(name)
        if not name then return false, "empty name" end
        if not hasFS then return false, "no filesystem api" end
        local path = nickFolder() .. "/" .. name .. ".json"
        local ok, exists = pcall(function() return isfile(path) end)
        if not ok or not exists then return false, "config not found" end
        local ok2, raw = pcall(function() return readfile(path) end)
        if not ok2 then return false, "read failed" end
        local data = jsonDecode(raw)
        if not data then return false, "json decode failed" end

        -- цвета
        if data.colors then
            for key, rgb in pairs(data.colors) do
                local c = applyColor3(rgb)
                if c and colors[key] ~= nil then colors[key] = c end
            end
        end
        -- визуальные фичи
        if data.S then
            if data.S.hat then S.hat.scale = data.S.hat.scale or S.hat.scale; F.hat.set(data.S.hat.enabled); F.hat.rebuild() end
            if data.S.circle then S.circle.scale = data.S.circle.scale or S.circle.scale; S.circle.speed = data.S.circle.speed or S.circle.speed
                F.circle.set(data.S.circle.enabled); F.circle.rebuild() end
            if data.S.angels then F.angels.mode(data.S.angels.mode or S.angels.mode); F.angels.set(data.S.angels.enabled) end
            if data.S.wings then S.wings.scale = data.S.wings.scale or S.wings.scale; F.wings.set(data.S.wings.enabled); F.wings.rebuild() end
            if data.S.seleher then F.seleher.set(data.S.seleher.enabled) end
            if data.S.aura then
                S.aura.style = data.S.aura.style or S.aura.style; S.aura.scale = data.S.aura.scale or S.aura.scale
                S.aura.speed = data.S.aura.speed or S.aura.speed; S.aura.rainbow = data.S.aura.rainbow or false
                F.aura.set(data.S.aura.enabled)
            end
            if data.S.orb then S.orb.rainbow = data.S.orb.rainbow or false; F.orb.set(data.S.orb.enabled) end
            if data.S.sky then S.sky.density = data.S.sky.density or S.sky.density; F.sky.set(data.S.sky.enabled) end
            if data.S.dark then F.dark.set(data.S.dark.enabled) end
            if data.S.jump then F.jump.set(data.S.jump.enabled) end
        end
        -- combat
        if data.aimbot then
            AB.aimPart = data.aimbot.aimPart or AB.aimPart; AB.teamCheck = data.aimbot.teamCheck
            AB.range = data.aimbot.range or AB.range; AB.smoothTime = data.aimbot.smoothTime or AB.smoothTime
            AB.lockTime = data.aimbot.lockTime or AB.lockTime; AB.lockFov = data.aimbot.lockFov or AB.lockFov
            F.aimbot.set(data.aimbot.enabled)
        end
        if data.silentaim then
            SA.aimPart = data.silentaim.aimPart or SA.aimPart; SA.teamCheck = data.silentaim.teamCheck
            SA.range = data.silentaim.range or SA.range; if data.silentaim.delayMs then F.silentaim.delay(data.silentaim.delayMs) end
            F.silentaim.set(data.silentaim.enabled)
        end
        if data.extra and extraApply then extraApply(data.extra) end
        return true, name
    end

    ConfigSys.hasFS = hasFS
end

-- ========== 3D PREVIEW (встроен в систему, первый блок VISUAL) ==========
-- Живая/аватарная R15/R6 модель во ViewportFrame, крутится сама, и на неё применяются активные
-- визуальные FX (hat/wings/aura/circle/orb/seleher/angels) через те же FX[name].preview инстансы -
-- для этого ctx.preview=true веткам в registerFx уже предусмотрены выше (hat/circle/wings/angels/
-- seleher используют ctx.preview; aura/orb рисуют поверх preview-модели напрямую по её root).
local Preview3D = {}
do
    local pv = {
        model = nil, platform = {}, track = nil, token = 0, rig = nil,
        yaw = math.pi + 0.5, dist = 12, focus = Vector3.new(), desc = nil, previewRoot = nil, previewHead = nil, previewTorso = nil,
    }
    local vf, world, camera, loading

    local function liveRig()
        local h = charRefs.hum
        return (h and h.RigType == Enum.HumanoidRigType.R6) and "R6" or "R15"
    end
    local function newDisc(d, thick, y, color)
        local p = Instance.new("Part")
        p.Shape = Enum.PartType.Cylinder; p.Material = Enum.Material.SmoothPlastic; p.Color = color
        p.Size = Vector3.new(thick, d, d); styleFxPart(p)
        p.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2); p.Parent = world
        return p
    end
    local function clearPreview()
        pv.token = pv.token + 1
        if pv.track then pcall(function() pv.track:Stop() end); pv.track = nil end
        -- выключаем FX preview-инстансы, если были включены на старой модели
        for _, e in ipairs(FX_ORDER) do
            if e.preview and e.preview.built then pcall(e.preview.destroy); e.preview.built = false end
        end
        if pv.model then pcall(function() pv.model:Destroy() end); pv.model = nil end
        for _, p in ipairs(pv.platform) do pcall(function() p:Destroy() end) end
        pv.platform = {}
        pv.previewRoot, pv.previewHead, pv.previewTorso = nil, nil, nil
        previewState.active = false
    end
    local function cloneLiveModel()
        local char = charRefs.char
        if not char then return nil end
        local changed = {}
        local function force(i) if not i.Archivable then i.Archivable = true; changed[#changed + 1] = i end end
        force(char); for _, d in ipairs(char:GetDescendants()) do force(d) end
        local ok, clone = pcall(function() return char:Clone() end)
        for _, i in ipairs(changed) do pcall(function() i.Archivable = false end) end
        if not (ok and clone) then return nil end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("BillboardGui")
                or d:IsA("SurfaceGui") or d:IsA("Highlight") or d:IsA("Tool") or d:IsA("Trail") or d:IsA("Beam") then
                pcall(function() d:Destroy() end)
            elseif d:IsA("BasePart") then pcall(function() d.LocalTransparencyModifier = 0 end) end
        end
        return clone
    end
    local function profileModel(rig)
        if not pv.desc then
            local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId) end)
            if ok then pv.desc = desc end
        end
        if not pv.desc then return nil end
        local rigType = (rig == "R6") and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
        local ok2, model = pcall(function() return Players:CreateHumanoidModelFromDescription(pv.desc, rigType) end)
        return ok2 and model or nil
    end
    local function playIdle(model)
        pcall(function()
            local hum = model:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
            local anim = Instance.new("Animation")
            anim.AnimationId = (hum.RigType == Enum.HumanoidRigType.R6) and "rbxassetid://180435571" or "rbxassetid://507766388"
            local track = animator:LoadAnimation(anim)
            track.Looped = true; track.Priority = Enum.AnimationPriority.Idle; track:Play(); pv.track = track
        end)
    end
    local function placeModel(model)
        local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
        local head = model:FindFirstChild("Head")
        if not (root and head) then model:Destroy(); return false end
        local hum = model:FindFirstChildOfClass("Humanoid")
        model.PrimaryPart = root; root.Anchored = true
        if hum then pcall(function() hum.EvaluateStateMachine = false end) end
        model.Parent = world; model:PivotTo(CFrame.new(0, 0, 0)); pv.model = model
        pv.previewRoot, pv.previewHead = root, head
        pv.previewTorso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or root

        local cf, size = model:GetBoundingBox()
        pv.focus = cf.Position + Vector3.new(0, 0.3, 0)
        local floorY = cf.Position.Y - size.Y / 2
        pv.platform = { newDisc(9.2, 0.25, floorY - 0.2, Color3.fromRGB(28, 28, 30)), newDisc(7.2, 0.25, floorY - 0.12, Color3.fromRGB(50, 50, 54)) }
        pv.dist = (math.max(size.Y, 5) * 0.5 * 1.55) / math.tan(math.rad(CFG.PREVIEW_FOV / 2))

        playIdle(model)

        -- переключаем refs для preview-веток FX на модель в вьюпорте и создаём preview-инстансы
        local previewRefs = { char = model, hum = hum, root = root, head = head, torso = pv.previewTorso }
        for _, e in ipairs(FX_ORDER) do
            if not e.preview then e.preview = e.make({ parent = world, refs = previewRefs, preview = true }) end
        end
        previewState.active = true
        for _, e in ipairs(FX_ORDER) do
            if e.state.enabled and e.preview and not e.preview.built then e.preview.built = true; pcall(e.preview.build) end
        end
        return true
    end
    local function loadPreview(rig)
        pv.rig = rig or pv.rig or liveRig()
        clearPreview()
        local token = pv.token
        if loading then loading.Visible = true; loading.Text = "LOADING..." end
        local wantRig = pv.rig
        task.spawn(function()
            local model
            if wantRig == liveRig() then model = cloneLiveModel() end
            if not model then model = profileModel(wantRig) end
            if token ~= pv.token then if model then model:Destroy() end; return end
            if not model or not placeModel(model) then
                if loading then loading.Text = "COULD NOT LOAD" end
                return
            end
            if loading then loading.Visible = false end
        end)
    end

    function Preview3D.mount(parentFrame)
        vf = new("ViewportFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Ambient = Color3.fromRGB(190, 190, 190), LightColor = Color3.fromRGB(255, 255, 255), Parent = parentFrame,
        })
        world = new("WorldModel", { Parent = vf })
        camera = new("Camera", { FieldOfView = CFG.PREVIEW_FOV, Parent = vf })
        vf.CurrentCamera = camera
        loading = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 12, TextColor3 = C.sub, Text = "LOADING...", Parent = parentFrame })

        table.insert(connections, RunService.RenderStepped:Connect(function(_, dt)
            dt = math.min(dt or 0, 0.1)
            if not pv.model then return end
            pv.yaw = pv.yaw + CFG.PREVIEW_SPIN * dt
            local rot = CFrame.Angles(0, pv.yaw, 0) * CFrame.Angles(-0.12, 0, 0)
            local pos = pv.focus + rot:VectorToWorldSpace(Vector3.new(0, 0, pv.dist))
            camera.CFrame = CFrame.lookAt(pos, pv.focus)
            vf.LightDirection = camera.CFrame:VectorToWorldSpace(Vector3.new(0.35, -0.75, -1)).Unit
        end))
        table.insert(connections, LocalPlayer.CharacterAdded:Connect(function()
            task.delay(1.2, function() loadPreview(nil) end)
        end))
        task.delay(0.3, function() loadPreview(nil) end)
    end

    -- вызывается при переключении любого визуального тоггла, чтобы preview мгновенно отразил изменение
    function Preview3D.syncAll()
        if not previewState.active then return end
        for _, e in ipairs(FX_ORDER) do
            if e.preview then
                if e.state.enabled and not e.preview.built then e.preview.built = true; pcall(e.preview.build)
                elseif not e.state.enabled and e.preview.built then e.preview.built = false; pcall(e.preview.destroy) end
            end
        end
    end
    function Preview3D.recolorAll()
        if not previewState.active then return end
        for _, e in ipairs(FX_ORDER) do
            if e.preview and e.preview.built and e.preview.recolor then pcall(e.preview.recolor) end
        end
    end

    Preview3D.setRig = loadPreview
end

-- patch F.* setters так, чтобы preview синхронизировался при каждом toggle (не меняя публичный
-- контракт F[name].set/recolor — оборачиваем после регистрации всех FX)
for _, name in ipairs({ "hat", "circle", "wings", "angels", "aura", "orb", "seleher" }) do
    local orig = F[name].set
    F[name].set = function(v) orig(v); Preview3D.syncAll() end
    if F[name].recolor then
        local origRecolor = F[name].recolor
        F[name].recolor = function() origRecolor(); Preview3D.recolorAll() end
    end
end

-- ========== МОДАЛКА ==========
local warningGui = new("ScreenGui", { Name = "SporenyWarning", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 1100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = getGuiParent() })
local function showWarning(onAccept)
    local existing = warningGui:FindFirstChild("WarnRoot"); if existing then existing:Destroy() end
    local root = new("Frame", { Name = "WarnRoot", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK,
        BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = warningGui })
    local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(440, 300), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = root },
        { corner(14), stroke(C.border, 1) })
    new("TextLabel", { Position = UDim2.new(0, 20, 0, 16), Size = UDim2.new(1, -40, 0, 22), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "WARNING  /  ВНИМАНИЕ", Parent = box })
    new("Frame", { Position = UDim2.new(0, 20, 0, 44), Size = UDim2.new(1, -40, 0, 1),
        BackgroundColor3 = C.border, BorderSizePixel = 0, Parent = box })
    new("TextLabel", { Position = UDim2.new(0, 20, 0, 56), Size = UDim2.new(1, -40, 0, 18), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "This script uses hooks.", Parent = box })
    new("TextLabel", { Position = UDim2.new(0, 20, 0, 76), Size = UDim2.new(1, -40, 0, 36), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Text = "Due to hook usage you may be kicked or banned. Use with caution.", Parent = box })
    new("TextLabel", { Position = UDim2.new(0, 20, 0, 118), Size = UDim2.new(1, -40, 0, 18), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Этот скрипт использует хуки.", Parent = box })
    new("TextLabel", { Position = UDim2.new(0, 20, 0, 138), Size = UDim2.new(1, -40, 0, 36), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, Text = "Из-за хука вы можете получить кик или бан. Используйте с осторожностью.", Parent = box })
    local btnYes = new("TextButton", { Position = UDim2.new(0, 20, 1, -102), Size = UDim2.new(1, -40, 0, 40),
        BackgroundColor3 = WHITE, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = BLACK, Text = "CONTINUE  /  ПРОДОЛЖИТЬ", Parent = box }, { corner(9) })
    local btnNo = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -54),
        Size = UDim2.fromOffset(200, 36), BackgroundColor3 = C.surface2, AutoButtonColor = false,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.sub, Text = "NO  /  ОТКАЗАТЬ", Parent = box },
        { corner(9), stroke(C.border, 1) })
    btnYes.Activated:Connect(function() root:Destroy(); if onAccept then onAccept() end end)
    btnNo.Activated:Connect(function() root:Destroy() end)
end

local function showPrompt(title, placeholder, onSubmit)
    local existing = warningGui:FindFirstChild("PromptRoot"); if existing then existing:Destroy() end
    local root = new("Frame", { Name = "PromptRoot", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK,
        BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = warningGui })
    local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(380, 168), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = root },
        { corner(14), stroke(C.border, 1) })
    new("TextLabel", { Position = UDim2.new(0, 20, 0, 16), Size = UDim2.new(1, -40, 0, 20), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
        Text = title, Parent = box })
    local inputBox = new("TextBox", { Position = UDim2.new(0, 20, 0, 48), Size = UDim2.new(1, -40, 0, 38),
        BackgroundColor3 = C.surface, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text,
        PlaceholderText = placeholder, PlaceholderColor3 = C.dim, Text = "", ClearTextOnFocus = false,
        Parent = box }, { corner(9), stroke(C.border, 1), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
    local status = new("TextLabel", { Position = UDim2.new(0, 20, 0, 90), Size = UDim2.new(1, -40, 0, 16),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub, Text = "",
        TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
    local btnOk = new("TextButton", { Position = UDim2.new(0, 20, 1, -46), Size = UDim2.new(1, -40, 0, 34),
        BackgroundColor3 = WHITE, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = BLACK, Text = "OK", Parent = box }, { corner(9) })
    local function submit()
        local text = inputBox.Text
        local ok, err = onSubmit(text)
        if ok then root:Destroy()
        else status.Text = tostring(err or "error"); status.TextColor3 = Color3.fromRGB(255, 90, 90) end
    end
    btnOk.Activated:Connect(submit)
    inputBox.FocusLost:Connect(function(enter) if enter then submit() end end)
    task.defer(function() pcall(function() inputBox:CaptureFocus() end) end)
end

local function showSelectList(title, items, onPick)
    local existing = warningGui:FindFirstChild("SelectRoot"); if existing then existing:Destroy() end
    local root = new("Frame", { Name = "SelectRoot", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK,
        BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = warningGui })
    local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(380, 320), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = root },
        { corner(14), stroke(C.border, 1) })
    new("TextLabel", { Position = UDim2.new(0, 20, 0, 16), Size = UDim2.new(1, -40, 0, 20), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
        Text = title, Parent = box })
    local list = new("ScrollingFrame", { Position = UDim2.new(0, 20, 0, 50), Size = UDim2.new(1, -40, 1, -98),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.dim,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = box },
        { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
    if #items == 0 then
        new("TextLabel", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
            TextSize = 12, TextColor3 = C.sub, Text = "Нет сохранённых конфигов", Parent = list })
    end
    for i, name in ipairs(items) do
        local row = new("TextButton", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.surface,
            AutoButtonColor = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.text,
            Text = "  " .. name, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = list },
            { corner(8), stroke(C.border, 1) })
        row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundColor3 = C.surface2 }) end)
        row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundColor3 = C.surface }) end)
        row.Activated:Connect(function() root:Destroy(); onPick(name) end)
    end
    local btnClose = new("TextButton", { Position = UDim2.new(0, 20, 1, -40), Size = UDim2.new(1, -40, 0, 30),
        BackgroundColor3 = C.surface2, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = C.sub, Text = "CLOSE", Parent = box }, { corner(9), stroke(C.border, 1) })
    btnClose.Activated:Connect(function() root:Destroy() end)
end

local function showToast(text, isError)
    local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40),
        Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = BLACK,
        BackgroundTransparency = 0.05, BorderSizePixel = 0, Parent = gui },
        { corner(9), stroke(isError and Color3.fromRGB(255, 90, 90) or C.border, 1),
          new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }) })
    new("TextLabel", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = isError and Color3.fromRGB(255, 140, 140) or WHITE,
        Text = text, Parent = holder })
    task.delay(2.2, function()
        tween(holder, 0.3, { BackgroundTransparency = 1 })
        Debris:AddItem(holder, 0.35)
    end)
end

-- ========== МЕНЮ ==========
do
    local cam0 = Workspace.CurrentCamera
    local vp = cam0 and cam0.ViewportSize or Vector2.new(1280, 720)
    local HEADER_H, FOOTER_H, SIDE_W = 62, 28, 118
    local W = math.clamp(vp.X - 40, 420, 620)
    local H = math.clamp(vp.Y - 40, 340, 600)
    local finalPos = UDim2.new(0, 20, 0.5, -H / 2)
    local collapsed, busy, closing = false, false, false

    local window = new("Frame", { Name = "Window", Position = finalPos + UDim2.fromOffset(-30, 0),
        Size = UDim2.fromOffset(W, H), BackgroundColor3 = BLACK, BorderSizePixel = 0, Active = true,
        ClipsDescendants = true, Parent = gui }, { corner(16), stroke(C.border, 1) })

    local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, HEADER_H),
        BackgroundTransparency = 1, Active = true, Parent = window })
    new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = C.border, BorderSizePixel = 0, Parent = header })

    -- LOGO (картинка)
    local logo = new("Frame", { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 16, 0.5, -19),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = header }, { corner(11) })
    new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Image = "rbxassetid://122961584783190", ScaleType = Enum.ScaleType.Fit, Parent = logo }, { corner(11) })

    new("TextLabel", { Position = UDim2.new(0, 66, 0, 11), Size = UDim2.new(1, -160, 0, 22),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = WHITE,
        TextXAlignment = Enum.TextXAlignment.Left, Text = CFG.BRAND, Parent = header })
    new("TextLabel", { Position = UDim2.new(0, 66, 0, 35), Size = UDim2.new(1, -160, 0, 16),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "combat suite  |  " .. CFG.VERSION, Parent = header })

    local function headerButton(text, xOffset)
        local b = new("TextButton", { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, xOffset, 0.5, -16),
            BackgroundColor3 = C.surface, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 16,
            TextColor3 = C.sub, Text = text, Parent = header }, { corner(9), stroke(C.border, 1) })
        b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundColor3 = C.surface2, TextColor3 = WHITE }) end)
        b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundColor3 = C.surface, TextColor3 = C.sub }) end)
        return b
    end
    local minBtn = headerButton("-", -84)
    local closeBtn = headerButton("x", -46)
    makeDraggable(header, window)

    local side = new("Frame", { Name = "Side", Position = UDim2.new(0, 0, 0, HEADER_H),
        Size = UDim2.new(0, SIDE_W, 1, -(HEADER_H + FOOTER_H)), BackgroundTransparency = 1, Parent = window })
    new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = C.border, BorderSizePixel = 0, Parent = side })
    local contentArea = new("Frame", { Name = "Content", Position = UDim2.new(0, SIDE_W, 0, HEADER_H),
        Size = UDim2.new(1, -SIDE_W, 1, -(HEADER_H + FOOTER_H)), BackgroundTransparency = 1,
        ClipsDescendants = true, Parent = window })
    local footer = new("Frame", { Name = "Footer", Position = UDim2.new(0, 0, 1, -FOOTER_H),
        Size = UDim2.new(1, 0, 0, FOOTER_H), BackgroundTransparency = 1, Parent = window })
    new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.border, BorderSizePixel = 0, Parent = footer })
    new("TextLabel", { Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(0.6, 0, 1, 0),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Left, Text = CFG.BRAND .. "  |  " .. CFG.VERSION, Parent = footer })
    new("TextLabel", { Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, -16, 1, 0),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Right, Text = CFG.TOGGLE_KEY.Name .. " - hide", Parent = footer })

    local pages = {}
    local function createPage(name)
        local scroll = new("ScrollingFrame", { Name = name, Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.dim,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, Parent = contentArea }, {
            new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
                PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
            new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
        })
        local page = { scroll = scroll, order = 0 }; pages[#pages + 1] = page; return page
    end
    local function nextOrder(page) page.order = page.order + 1; return page.order end
    local function baseRow(page, height, clickable)
        local props = { Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = C.surface,
            BorderSizePixel = 0, LayoutOrder = nextOrder(page), Parent = page.scroll }
        if clickable then props.AutoButtonColor = false; props.Text = "" end
        return new(clickable and "TextButton" or "Frame", props, { corner(10), stroke(C.border, 1) })
    end
    local function hoverable(row)
        local st = row:FindFirstChildOfClass("UIStroke")
        row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundColor3 = C.surface2 })
            if st then tween(st, 0.12, { Color = C.dim }) end end)
        row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundColor3 = C.surface })
            if st then tween(st, 0.12, { Color = C.border }) end end)
    end
    local function addTitle(row, title, desc, height, rightPad)
        new("TextLabel", { Position = UDim2.new(0, 14, 0, desc and 7 or 0),
            Size = UDim2.new(1, -rightPad, 0, desc and 18 or height), BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = title, Parent = row })
        if desc then new("TextLabel", { Position = UDim2.new(0, 14, 0, 26), Size = UDim2.new(1, -rightPad, 0, 14),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = desc, Parent = row }) end
    end
    local function addSection(page, text)
        local row = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
            LayoutOrder = nextOrder(page), Parent = page.scroll })
        new("TextLabel", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(text), Parent = row })
        new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -2),
            BackgroundColor3 = C.border, BorderSizePixel = 0, Parent = row })
    end
    local function addToggle(page, title, desc, default, callback)
        local height = desc and 50 or 40
        local row = baseRow(page, height, true); hoverable(row); addTitle(row, title, desc, height, 80)
        local track = new("Frame", { Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -54, 0.5, -11),
            BackgroundColor3 = C.track, BorderSizePixel = 0, Parent = row }, { corner(11) })
        local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE,
            BackgroundTransparency = 1, BorderSizePixel = 0, Parent = track }, { corner(11) })
        local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = C.sub, BorderSizePixel = 0, Parent = track }, { corner(8) })
        local value = default and true or false
        local function render(instant)
            local t = instant and 0 or 0.16
            tween(fill, t, { BackgroundTransparency = value and 0 or 1 })
            tween(knob, t, { Position = value and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                BackgroundColor3 = value and BLACK or C.sub })
        end
        row.Activated:Connect(function() value = not value; render(false); if callback then task.spawn(callback, value) end end)
        render(true)
        row.setValue = function(v, instant) value = v and true or false; render(instant) end
        return row
    end
    local function addWarnToggle(page, title, desc, default, onAccept)
        local height = desc and 50 or 40
        local row = baseRow(page, height, true); hoverable(row); addTitle(row, title, desc, height, 80)
        local track = new("Frame", { Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -54, 0.5, -11),
            BackgroundColor3 = C.track, BorderSizePixel = 0, Parent = row }, { corner(11) })
        local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE,
            BackgroundTransparency = 1, BorderSizePixel = 0, Parent = track }, { corner(11) })
        local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = C.sub, BorderSizePixel = 0, Parent = track }, { corner(8) })
        local value = default and true or false; local locked = false
        local function render(instant)
            local t = instant and 0 or 0.16
            tween(fill, t, { BackgroundTransparency = value and 0 or 1 })
            tween(knob, t, { Position = value and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                BackgroundColor3 = value and BLACK or C.sub })
        end
        row.Activated:Connect(function()
            if locked then return end
            if value then value = false; render(false); if onAccept then task.spawn(onAccept, false) end; return end
            locked = true
            showWarning(function() value = true; render(false); locked = false; if onAccept then task.spawn(onAccept, true) end end)
            task.delay(60, function() locked = false end)
        end)
        render(true)
        row.setValue = function(v, instant) value = v and true or false; render(instant) end
        return row
    end
    local function addSlider(page, title, minV, maxV, default, suffix, callback)
        local row = baseRow(page, 56, false); hoverable(row); addTitle(row, title, nil, 32, 100)
        local valueLabel = new("TextLabel", { Position = UDim2.new(1, -80, 0, 0), Size = UDim2.fromOffset(66, 32),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = WHITE,
            TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = row })
        local track = new("Frame", { Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -28, 0, 4),
            BackgroundColor3 = C.track, BorderSizePixel = 0, Parent = row }, { corner(2) })
        local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE,
            BorderSizePixel = 0, Parent = track }, { corner(2) })
        local knob = new("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, -6, 0.5, -6),
            BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = track }, { corner(6) })
        local hit = new("TextButton", { Position = UDim2.new(0, 8, 0, 28), Size = UDim2.new(1, -16, 0, 24),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = row })
        local value = math.clamp(default, minV, maxV); local lastReported, dragging = nil, false
        local function setAlpha(a) a = math.clamp(a, 0, 1)
            value = math.floor(minV + (maxV - minV) * a + 0.5)
            fill.Size = UDim2.new(a, 0, 1, 0); knob.Position = UDim2.new(a, -6, 0.5, -6)
            valueLabel.Text = value .. (suffix or "") end
        local function fromInput(input) local w = track.AbsoluteSize.X; if w <= 0 then return end
            setAlpha((input.Position.X - track.AbsolutePosition.X) / w)
            if callback and value ~= lastReported then lastReported = value; task.spawn(callback, value) end end
        hit.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; page.scroll.ScrollingEnabled = false
                tween(knob, 0.1, { Size = UDim2.fromOffset(16, 16) }); fromInput(input)
            end
        end)
        table.insert(connections, UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                fromInput(input) end
        end))
        table.insert(connections, UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false; page.scroll.ScrollingEnabled = true
                tween(knob, 0.1, { Size = UDim2.fromOffset(12, 12) })
            end
        end))
        setAlpha((value - minV) / math.max(maxV - minV, 1))
        row.setValue = function(v) setAlpha((v - minV) / math.max(maxV - minV, 1)) end
        return row
    end
    local function addSelector(page, title, options, default, callback)
        local row = baseRow(page, 42, true); hoverable(row); addTitle(row, title, nil, 42, 160)
        local chip = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(130, 26), BackgroundColor3 = C.window, BorderSizePixel = 0, Parent = row },
            { corner(7), stroke(C.border, 1) })
        new("TextLabel", { Position = UDim2.new(0, 4, 0, 0), Size = UDim2.fromOffset(18, 26), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center, Text = "<", Parent = chip })
        new("TextLabel", { Position = UDim2.new(1, -22, 0, 0), Size = UDim2.fromOffset(18, 26), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center, Text = ">", Parent = chip })
        local valueLabel = new("TextLabel", { Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(1, -44, 1, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Center, Text = "", Parent = chip })
        local index = 1; for i, o in ipairs(options) do if o == default then index = i end end
        valueLabel.Text = options[index]
        row.Activated:Connect(function() index = index % #options + 1; valueLabel.Text = options[index]
            valueLabel.TextColor3 = WHITE; tween(valueLabel, 0.3, { TextColor3 = C.text })
            if callback then task.spawn(callback, options[index]) end end)
        row.setValue = function(v) for i, o in ipairs(options) do if o == v then index = i; valueLabel.Text = o end end end
        return row
    end
    local function addColor(page, title, defaultName, callback, extra)
        local list = {}; for _, e in ipairs(PALETTE) do list[#list + 1] = e end
        if extra then for _, e in ipairs(extra) do list[#list + 1] = e end end
        local index = 1; for i, e in ipairs(list) do if e[1] == defaultName then index = i end end
        local row = baseRow(page, 42, true); hoverable(row); addTitle(row, title, nil, 42, 170)
        local chip = new("Frame", { Size = UDim2.fromOffset(132, 26), Position = UDim2.new(1, -146, 0.5, -13),
            BackgroundColor3 = C.window, BorderSizePixel = 0, Parent = row }, { corner(7), stroke(C.border, 1) })
        local swatch = new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 8, 0.5, -7),
            BackgroundColor3 = list[index][2], BorderSizePixel = 0, Parent = chip }, { corner(999), stroke(C.dim, 1) })
        local nameLabel = new("TextLabel", { Position = UDim2.new(0, 30, 0, 0), Size = UDim2.new(1, -54, 1, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = list[index][1], Parent = chip })
        new("TextLabel", { Position = UDim2.new(1, -22, 0, 0), Size = UDim2.fromOffset(18, 26),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.dim, Text = ">", Parent = chip })
        row.Activated:Connect(function() index = index % #list + 1; local entry = list[index]
            swatch.BackgroundColor3 = entry[2]; nameLabel.Text = entry[1]
            if callback then task.spawn(callback, entry[2], entry[1]) end end)
        row.setValue = function(colorName)
            for i, e in ipairs(list) do if e[1] == colorName then index = i; swatch.BackgroundColor3 = e[2]; nameLabel.Text = e[1] end end
        end
        return row
    end
    local function addInput(page, title, placeholder, callback)
        local row = baseRow(page, 46, false); hoverable(row); addTitle(row, title, nil, 46, 190)
        local box = new("TextBox", { Position = UDim2.new(1, -176, 0.5, -15), Size = UDim2.fromOffset(162, 30),
            BackgroundColor3 = C.window, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
            PlaceholderText = placeholder, PlaceholderColor3 = C.dim, Text = "", ClearTextOnFocus = false,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = row }, { corner(7), stroke(C.border, 1) })
        box.FocusLost:Connect(function() if callback then task.spawn(callback, box.Text) end end)
        return row
    end
    local function addInfo(page, label, value)
        local row = baseRow(page, 36, false); addTitle(row, label, nil, 36, 190)
        local vl = new("TextLabel", { Position = UDim2.new(1, -184, 0, 0), Size = UDim2.fromOffset(170, 36),
            BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Text = value, Parent = row })
        return row, vl
    end
    -- простая кнопка-строка для CONFIG вкладки (SaveConfig / SelectConfig / LoadConfig)
    local function addButtonRow(page, title, desc, buttonText, callback)
        local height = desc and 50 or 40
        local row = baseRow(page, height, false); hoverable(row); addTitle(row, title, desc, height, 110)
        local btn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(92, 28), BackgroundColor3 = C.window, AutoButtonColor = false,
            Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text, Text = buttonText, Parent = row },
            { corner(7), stroke(C.border, 1) })
        btn.MouseEnter:Connect(function() tween(btn, 0.12, { BackgroundColor3 = C.surface2 }) end)
        btn.MouseLeave:Connect(function() tween(btn, 0.12, { BackgroundColor3 = C.window }) end)
        btn.Activated:Connect(function() if callback then callback() end end)
        return row
    end

    local pageConfig = createPage("CONFIG")
    local pageCombat = createPage("COMBAT")
    local pageVisual = createPage("VISUAL")
    local pageSettings = createPage("SETTINGS")

    -- CONFIG: SaveConfig / SelectConfig(list) / LoadConfig + строка для имени
    addSection(pageConfig, "Конфиги — " .. LocalPlayer.Name)
    local configNameRow = addInput(pageConfig, "Имя конфига", "например: legit", nil)
    local selectedConfigLabel
    addSection(pageConfig, "Действия")
    addButtonRow(pageConfig, "SaveConfig", "Сохранить текущие настройки под именем выше", "SAVE", function()
        local box = configNameRow:FindFirstChildOfClass("TextBox")
        local name = box and box.Text or ""
        if name == "" then
            showPrompt("SaveConfig — введите название", "название конфига", function(text)
                local ok, res = ConfigSys.save(text)
                if ok then showToast("Сохранено: " .. res); return true end
                return false, res
            end)
        else
            local ok, res = ConfigSys.save(name)
            if ok then showToast("Сохранено: " .. res) else showToast("Ошибка: " .. tostring(res), true) end
        end
    end)
    addButtonRow(pageConfig, "SelectConfig", "Выбрать один из сохранённых конфигов", "SELECT", function()
        local items = ConfigSys.list()
        showSelectList("Твои конфиги", items, function(picked)
            local box = configNameRow:FindFirstChildOfClass("TextBox")
            if box then box.Text = picked end
            if selectedConfigLabel then selectedConfigLabel.Text = "Выбран: " .. picked end
            showToast("Выбран: " .. picked)
        end)
    end)
    addButtonRow(pageConfig, "LoadConfig", "Загрузить конфиг из строки имени выше", "LOAD", function()
        local box = configNameRow:FindFirstChildOfClass("TextBox")
        local name = box and box.Text or ""
        if name == "" then showToast("Сначала укажи имя или выбери конфиг", true); return end
        local ok, res = ConfigSys.load(name)
        if ok then showToast("Загружено: " .. res) else showToast("Ошибка: " .. tostring(res), true) end
    end)
    do
        local row = baseRow(pageConfig, 30, false)
        selectedConfigLabel = new("TextLabel", { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -28, 1, 0),
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.dim,
            Text = ConfigSys.hasFS and "Готово к работе" or "Executor не даёт filesystem API — сохранение недоступно",
            TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
    end

    -- COMBAT
    addSection(pageCombat, "Aim Bot")
    local rowAimbot = addWarnToggle(pageCombat, "Aim Bot", "Smooth to hard lock. Nearest visible", false, F.aimbot.set)
    addSelector(pageCombat, "Aim Bot Part", { "Head", "Body" }, "Head", F.aimbot.aimPart)
    addToggle(pageCombat, "Aim Bot Team", "Skip your teammates", true, F.aimbot.teamCheck)
    addSlider(pageCombat, "Aim Bot Range", 50, 2000, 500, "", F.aimbot.range)
    addSlider(pageCombat, "Smooth Time", 5, 100, 35, " x.01s", function(v) F.aimbot.smooth(v / 100) end)
    addSlider(pageCombat, "Lock Time", 0, 100, 15, " x.01s", function(v) F.aimbot.lock(v / 100) end)
    addSlider(pageCombat, "Lock FOV", 10, 180, 55, "", F.aimbot.fov)

    addSection(pageCombat, "Silent Aim")
    local rowSilent = addWarnToggle(pageCombat, "Silent Aim", "Hooks. Auto-targets nearest visible", false, F.silentaim.set)
    addSelector(pageCombat, "Silent Aim Part", { "Head", "Body" }, "Head", F.silentaim.aimPart)
    addToggle(pageCombat, "Silent Aim Team", "Skip your teammates", true, F.silentaim.teamCheck)
    addSlider(pageCombat, "Silent Aim Delay", 40, 800, 150, " ms", F.silentaim.delay)
    addSlider(pageCombat, "Silent Aim Range", 50, 2000, 500, "", F.silentaim.range)

    addSection(pageCombat, "ESP")
    local rowEsp = addToggle(pageCombat, "ESP", "Nick, HP, distance — без фона", false, F.esp.set)
    addColor(pageCombat, "Esp Color", "White", function(c) colors.esp = c; F.esp.recolor() end)

    addSection(pageCombat, "Movement")
    local rowSpin = addToggle(pageCombat, "Spin Bot", "Just a spinner", false, F.spin.set)
    addSlider(pageCombat, "Spin Speed", 200, 3000, 1200, "", F.spin.speed)
    local rowThird = addToggle(pageCombat, "Third Person", "Stays until you turn it off", false, F.third.set)
    addSlider(pageCombat, "Camera Distance", 6, 60, 14, "", F.third.distance)

    -- VISUAL — 3D Preview первым блоком
    addSection(pageVisual, "3D Preview")
    do
        local previewCard = new("Frame", { Size = UDim2.new(1, 0, 0, 260), BackgroundColor3 = C.window,
            BorderSizePixel = 0, LayoutOrder = nextOrder(pageVisual), ClipsDescendants = true, Parent = pageVisual.scroll },
            { corner(12), stroke(C.border, 1) })
        new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = previewCard }, {
            new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(38, 38, 40), Color3.fromRGB(66, 66, 68)), Rotation = 90 }),
        })
        local body = new("Frame", { Size = UDim2.new(1, -16, 1, -48), Position = UDim2.new(0, 8, 0, 8),
            BackgroundColor3 = C.window, BorderSizePixel = 0, ClipsDescendants = true, Parent = previewCard },
            { corner(10), stroke(C.border, 1) })
        new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = body }, {
            new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(38, 38, 40), Color3.fromRGB(66, 66, 68)), Rotation = 90 }),
        })
        Preview3D.mount(body)
        local rigRow = new("Frame", { Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0, 8, 1, -36),
            BackgroundTransparency = 1, Parent = previewCard })
        local function rigBtn(text, xOffset)
            local b = new("TextButton", { Size = UDim2.fromOffset(60, 28), Position = UDim2.new(1, xOffset, 0, 2),
                BackgroundColor3 = C.surface, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 12,
                TextColor3 = C.sub, Text = text, Parent = rigRow }, { corner(7), stroke(C.border, 1) })
            return b
        end
        local b15 = rigBtn("R15", -128)
        local b6 = rigBtn("R6", -64)
        b15.Activated:Connect(function() Preview3D.setRig("R15") end)
        b6.Activated:Connect(function() Preview3D.setRig("R6") end)
    end

    addSection(pageVisual, "HUD")
    addToggle(pageVisual, "HUD", "Nick, FPS, ms, game", false, F.hud.set)
    addSection(pageVisual, "Hat")
    local rowHat = addToggle(pageVisual, "Hat", "Glowing cone", false, F.hat.set)
    addColor(pageVisual, "Hat Color", "Green", function(c) colors.hat = c; F.hat.recolor() end)
    addSlider(pageVisual, "Hat Size", 60, 160, 100, "%", function(v) S.hat.scale = v / 100; F.hat.rebuild() end)
    addSection(pageVisual, "Circle")
    local rowCircle = addToggle(pageVisual, "Visual Circle", "Feet-head-feet ring", false, F.circle.set)
    addColor(pageVisual, "Circle Color", "Black", function(c) colors.circle = c; F.circle.recolor() end)
    addSlider(pageVisual, "Circle Speed", 50, 250, 100, "%", function(v) S.circle.speed = v / 100 end)
    addSlider(pageVisual, "Circle Size", 70, 160, 100, "%", function(v) S.circle.scale = v / 100; F.circle.rebuild() end)
    addSection(pageVisual, "Angels")
    local rowAngels = addToggle(pageVisual, "Visual Angels", "Halo above heads", false, F.angels.set)
    addSelector(pageVisual, "Angels On", { "Everyone", "Others", "Me" }, "Everyone", F.angels.mode)
    addColor(pageVisual, "Angel Color", "White", function(c) colors.angel = c; F.angels.recolor() end)
    addSection(pageVisual, "Wings")
    local rowWings = addToggle(pageVisual, "Angel Wings", "Flapping behind you", false, F.wings.set)
    addColor(pageVisual, "Wings Color", "White", function(c) colors.wings = c; F.wings.recolor() end)
    addSlider(pageVisual, "Wings Size", 60, 150, 100, "%", function(v) S.wings.scale = v / 100; F.wings.rebuild() end)
    addSection(pageVisual, "Aura")
    local rowAura = addToggle(pageVisual, "Aura", "10 animated styles", false, F.aura.set)
    addSelector(pageVisual, "Aura Style", AURA_NAMES, AURA_NAMES[1], F.aura.setStyle)
    addColor(pageVisual, "Aura Color", "Cyan", function(c, name) if name == "Rainbow" then S.aura.rainbow = true
        else S.aura.rainbow = false; colors.aura = c end end, { { "Rainbow", Color3.fromRGB(255, 120, 255) } })
    addSlider(pageVisual, "Aura Size", 60, 160, 100, "%", function(v) S.aura.scale = v / 100 end)
    addSlider(pageVisual, "Aura Speed", 40, 220, 100, "%", function(v) S.aura.speed = v / 100 end)
    addSection(pageVisual, "Lefer Orb")
    local rowOrb = addToggle(pageVisual, "Lefer Orb", "Glowing orbs around you", false, F.orb.set)
    addColor(pageVisual, "Orb Color", "Purple", function(c, name) if name == "Rainbow" then S.orb.rainbow = true
        else S.orb.rainbow = false; colors.orb = c end end, { { "Rainbow", Color3.fromRGB(255, 120, 255) } })
    addSection(pageVisual, "Seleher")
    local rowSeleher = addToggle(pageVisual, "Seleher", "Animated trail behind", false, F.seleher.set)
    addColor(pageVisual, "Seleher Color", "Pink", function(c) colors.trail = c; F.seleher.recolor() end)
    addSection(pageVisual, "Particles")
    addToggle(pageVisual, "Visual Particles", "Pixel rain", false, F.sky.set)
    addColor(pageVisual, "Particles Color", "Cyan", function(c) colors.particles = c; F.sky.recolor() end)
    addSlider(pageVisual, "Density", 20, 100, 100, "%", F.sky.density)
    addSection(pageVisual, "Darkening")
    addToggle(pageVisual, "Darkening", "Map and sky darken", false, F.dark.set)
    addColor(pageVisual, "Darkening Color", "Black", function(c) colors.dark = c; F.dark.recolor() end)
    addSection(pageVisual, "Shots")
    addToggle(pageVisual, "Treceons Amon", "Divine line per shot", false, F.tracer.set)
    addColor(pageVisual, "Treceons Color", "Yellow", function(c) colors.tracer = c; F.tracer.recolor() end)
    addSection(pageVisual, "Jump")
    addToggle(pageVisual, "Jump Circle", "On jump and landing", false, F.jump.set)
    addColor(pageVisual, "Jump Color", "Cyan", function(c) colors.jump = c; F.jump.recolor() end)
    addSection(pageVisual, "Kills")
    addToggle(pageVisual, "Visual Kills", "Soul from each kill", false, F.kills.set)
    addColor(pageVisual, "Soul Color", "Cyan", F.kills.color, { { "Rainbow", Color3.fromRGB(255, 120, 255) } })
    addSelector(pageVisual, "Kill Detect", { "Auto", "Any Death" }, "Auto", F.kills.mode)
    addSlider(pageVisual, "Soul Size", 60, 200, 100, "%", F.kills.size)
    addSection(pageVisual, "HitSound")
    addToggle(pageVisual, "HitSound", "Hit sound", false, F.hitsound.set)
    addSelector(pageVisual, "Hit Style", F.hitsound.styleNames, F.hitsound.styleNames[1], F.hitsound.setStyle)
    addSelector(pageVisual, "Headshot Style", F.hitsound.headStyleNames, F.hitsound.headStyleNames[1], F.hitsound.setHeadStyle)
    addSlider(pageVisual, "Volume", 10, 300, 100, "%", F.hitsound.volume)
    addInput(pageVisual, "Hit Sound ID", "rbxassetid://...", F.hitsound.setHitId)
    addInput(pageVisual, "Headshot Sound ID", "rbxassetid://...", F.hitsound.setHeadId)

    -- SETTINGS
    addSection(pageSettings, "About")
    addInfo(pageSettings, "Version", CFG.VERSION)
    addInfo(pageSettings, "Toggle key", CFG.TOGGLE_KEY.Name)
    addInfo(pageSettings, "Brand", CFG.BRAND)

    -- extra getter/applier для ConfigSys (esp/spin/third/hud/tracer/jump/kills/hitsound +
    -- переотрисовка всех UI toggles, чтобы ползунки/переключатели визуально совпали после load)
    do
        local espEnabledRef, spinEnabledRef, thirdEnabledRef = false, false, false
        local origEspSet, origSpinSet, origThirdSet = F.esp.set, F.spin.set, F.third.set
        F.esp.set = function(v) espEnabledRef = v and true or false; origEspSet(v) end
        F.spin.set = function(v) spinEnabledRef = v and true or false; origSpinSet(v) end
        F.third.set = function(v) thirdEnabledRef = v and true or false; origThirdSet(v) end

        ConfigSys.bindExtra(
            function()
                return {
                    esp = espEnabledRef, spin = spinEnabledRef, third = thirdEnabledRef,
                }
            end,
            function(extra)
                if extra.esp ~= nil then F.esp.set(extra.esp); if rowEsp.setValue then rowEsp.setValue(extra.esp, true) end end
                if extra.spin ~= nil then F.spin.set(extra.spin); if rowSpin.setValue then rowSpin.setValue(extra.spin, true) end end
                if extra.third ~= nil then F.third.set(extra.third); if rowThird.setValue then rowThird.setValue(extra.third, true) end end
            end
        )
    end

    local TAB_NAMES = { "CONFIG", "COMBAT", "VISUAL", "SETTINGS" }
    local TAB_Y0, TAB_STEP = 14, 44
    local tabButtons = {}; local activeIndex = 0
    local selectorBar = new("Frame", { Position = UDim2.new(0, 8, 0, TAB_Y0), Size = UDim2.new(1, -16, 0, 40),
        BackgroundColor3 = C.surface2, BorderSizePixel = 0, Parent = side }, { corner(10), stroke(C.border, 1) })
    new("Frame", { Position = UDim2.new(0, 0, 0.5, -9), Size = UDim2.fromOffset(3, 18),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = selectorBar }, { corner(2) })
    local function selectTab(index, instant)
        if index == activeIndex then return end; activeIndex = index
        for i, t in ipairs(tabButtons) do tween(t.label, 0.15, { TextColor3 = (i == index) and WHITE or C.sub }) end
        tween(selectorBar, instant and 0 or 0.25,
            { Position = UDim2.new(0, 8, 0, TAB_Y0 + (index - 1) * TAB_STEP) }, Enum.EasingStyle.Quint)
        for i, pg in ipairs(pages) do pg.scroll.Visible = (i == index) end
    end
    for i, name in ipairs(TAB_NAMES) do
        local btn = new("TextButton", { Name = name, Size = UDim2.new(1, -16, 0, 40),
            Position = UDim2.new(0, 8, 0, TAB_Y0 + (i - 1) * TAB_STEP), BackgroundTransparency = 1,
            AutoButtonColor = false, Text = "", Parent = side })
        local label = new("TextLabel", { Position = UDim2.new(0, 18, 0, 0), Size = UDim2.new(1, -18, 1, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left, Text = name, Parent = btn })
        tabButtons[i] = { label = label }
        btn.Activated:Connect(function() selectTab(i, false) end)
        btn.MouseEnter:Connect(function() if activeIndex ~= i then tween(label, 0.12, { TextColor3 = C.text }) end end)
        btn.MouseLeave:Connect(function() if activeIndex ~= i then tween(label, 0.12, { TextColor3 = C.sub }) end end)
    end
    selectTab(1, true)

    minBtn.Activated:Connect(function()
        if busy then return end; busy = true; collapsed = not collapsed
        minBtn.Text = collapsed and "+" or "-"
        if collapsed then
            tween(window, 0.3, { Size = UDim2.fromOffset(W, HEADER_H) }, Enum.EasingStyle.Quint)
            task.delay(0.15, function() side.Visible = false; contentArea.Visible = false; footer.Visible = false end)
        else
            side.Visible, contentArea.Visible, footer.Visible = true, true, true
            tween(window, 0.3, { Size = UDim2.fromOffset(W, H) }, Enum.EasingStyle.Quint)
        end
        task.delay(0.3, function() busy = false end)
    end)

    local function fullCleanup()
        pcall(F.aimbot.set, false); pcall(F.silentaim.set, false)
        for _, key in ipairs({ "hat", "circle", "angels", "wings", "aura", "orb", "seleher", "sky", "dark",
            "tracer", "jump", "kills", "hitsound", "hud", "esp", "spin", "third" }) do
            pcall(F[key].set, false)
        end
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        pcall(function() gui:Destroy() end); pcall(function() warningGui:Destroy() end)
        pcall(function() fxFolder:Destroy() end); env.__BestVisualCleanup = nil
    end
    closeBtn.Activated:Connect(function()
        if closing then return end; closing = true
        tween(window, 0.25, { Position = finalPos + UDim2.fromOffset(-40, 0) }, Enum.EasingStyle.Quint)
        task.delay(0.25, fullCleanup)
    end)
    table.insert(connections, UserInputService.InputBegan:Connect(function(input, gp)
        if gp or closing then return end
        if input.KeyCode == CFG.TOGGLE_KEY then window.Visible = not window.Visible end
    end))
    tween(window, 0.4, { Position = finalPos }, Enum.EasingStyle.Quint)
    env.__BestVisualCleanup = fullCleanup
end

-- ========== HITMARKER / CHAR / LOOP ==========
showHitMarker = function(isHead)
    local c = isHead and WHITE or Color3.fromRGB(200, 200, 200)
    local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, Parent = gui })
    for i = 1, 4 do
        local ang = math.rad(45 + (i - 1) * 90)
        local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(11, 3),
            Position = UDim2.new(0.5, math.cos(ang) * 13, 0.5, math.sin(ang) * 13),
            Rotation = math.deg(ang), BackgroundColor3 = c, BorderSizePixel = 0, Parent = holder }, { corner(1) })
        tween(f, 0.28, { BackgroundTransparency = 1,
            Position = UDim2.new(0.5, math.cos(ang) * 21, 0.5, math.sin(ang) * 21) })
    end
    Debris:AddItem(holder, 0.4)
    if isHead then
        local text = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36),
            Size = UDim2.fromOffset(300, 40), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack,
            TextSize = 30, TextColor3 = WHITE, Text = "HEADSHOT!", Parent = gui },
            { new("UIStroke", { Color = BLACK, Thickness = 2 }) })
        tween(text, 0.18, { TextSize = 38 }, Enum.EasingStyle.Back)
        task.delay(0.3, function()
            tween(text, 0.7, { Position = UDim2.fromScale(0.5, 0.31), TextTransparency = 1 })
            local st = text:FindFirstChildOfClass("UIStroke")
            if st then tween(st, 0.7, { Transparency = 1 }) end
        end)
        Debris:AddItem(text, 1.2)
    end
end

local function hookLocalChar(char)
    task.spawn(function()
        local hum = char:WaitForChild("Humanoid", 10)
        local root = char:WaitForChild("HumanoidRootPart", 10)
        local head = char:WaitForChild("Head", 10)
        if not (hum and root and head) then return end
        charRefs.char, charRefs.hum, charRefs.root, charRefs.head = char, hum, root, head
        charRefs.torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or root
        for _, fn in ipairs(ON_LOCAL_CHAR) do
            local ok, err = pcall(fn, char)
            if not ok then warn("[Sporeny] char: " .. tostring(err)) end
        end
    end)
end
if LocalPlayer.Character then hookLocalChar(LocalPlayer.Character) end
table.insert(connections, LocalPlayer.CharacterAdded:Connect(hookLocalChar))

do
    local warned = {}
    table.insert(connections, RunService.RenderStepped:Connect(function(dt)
        dt = math.min(dt, 0.1); local t = os.clock()
        for i, fn in ipairs(UPDATERS) do
            local ok, err = pcall(fn, t, dt)
            if not ok and not warned[i] then warned[i] = true; warn("[Sporeny] update #" .. i .. ": " .. tostring(err)) end
        end
    end))
end

gui.Parent = getGuiParent()
env.__BestVisualCleanup = F.fullCleanup
