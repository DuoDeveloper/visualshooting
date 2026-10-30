local players = game:GetService("Players")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local debris = game:GetService("Debris")
local rs = game:GetService("RunService")
local lighting = game:GetService("Lighting")

local lp = players.LocalPlayer
local mouse = lp:GetMouse()
local camera = workspace.CurrentCamera
local pgui = lp:WaitForChild("PlayerGui")
local backpack = lp:WaitForChild("Backpack")

if _G.reaperlinks then
	for _, c in ipairs(_G.reaperlinks) do
		pcall(c.Disconnect, c)
	end
end
pcall(rs.UnbindFromRenderStep, rs, "reaperview")
local links = {}
_G.reaperlinks = links

local function link(c)
	links[#links + 1] = c
	return c
end

for _, v in ipairs({{pgui, "ReaperUI"}, {workspace, "ReaperBlood"}, {workspace, "ReaperBodies"}, {camera, "ReaperView"}, {lighting, "ReaperFx"}}) do
	local old = v[1]:FindFirstChild(v[2])
	if old then
		old:Destroy()
	end
end
for _, name in ipairs({"BloodRevolver", "Revolver", "Knife", "Shotgun"}) do
	for _, holder in ipairs({backpack, lp.Character}) do
		local old = holder and holder:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function tween(o, t, goal, style, dir)
	local tw = ts:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local ink = Color3.fromRGB(14, 14, 16)
local red = Color3.fromRGB(255, 55, 55)
local dim = Color3.fromRGB(48, 48, 54)
local brass = Color3.fromRGB(200, 160, 60)
local gore = "rbxassetid://132080416777849"
local click = "rbxasset://sounds/switch.wav"
local backout = Enum.EasingStyle.Back
local rx90 = CFrame.Angles(math.rad(90), 0, 0)
local rz90 = CFrame.Angles(0, 0, math.rad(90))

local blood = make("Folder", {Name = "ReaperBlood"}, workspace)
local bodies = make("Folder", {Name = "ReaperBodies"}, workspace)
local view = make("Folder", {Name = "ReaperView"}, camera)
mouse.TargetFilter = view

local mparams = RaycastParams.new()
mparams.FilterType = Enum.RaycastFilterType.Exclude
local gparams = RaycastParams.new()
gparams.FilterType = Enum.RaycastFilterType.Exclude
local mbase = {}

local function setchar(char)
	mbase = {view, blood, char}
	mparams.FilterDescendantsInstances = mbase
	gparams.FilterDescendantsInstances = {view, blood, bodies, char}
end
setchar(lp.Character)

local deadtargets, splats, live, bleeders = {}, {}, {}, {}
local sockets = setmetatable({}, {__mode = "k"})
local kick = 22
local current, reloading, token = nil, false, 0
local pose = {0, 0, 0, 2, 0, 0}
local goal = {0, 0, 0, 2, 0, 0}
local rate = 12
local loadout, pipframes, slots = {}, {}, {}
local shakeleft, shakemag = 0, 0
local vm, vmchar, vlist, vrel, vhum, vtorso, vsh
local armlen = 2
local reals = {}
local equip

local cc = make("ColorCorrectionEffect", {Name = "ReaperFx", Enabled = false}, lighting)
local fxid = 0

local gui = make("ScreenGui", {Name = "ReaperUI", ResetOnSpawn = false, IgnoreGuiInset = true}, pgui)

local bloodframe = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(130, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0
}, gui)

local vignette = make("ImageLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = "rbxassetid://4576475446",
	ImageColor3 = Color3.fromRGB(160, 0, 0),
	ImageTransparency = 1
}, bloodframe)

local resetbtn = make("TextButton", {
	Size = UDim2.fromOffset(200, 46),
	Position = UDim2.new(1, 40, 0.5, -23),
	BackgroundColor3 = ink,
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "RESET RAGDOLLS  [X]",
	TextColor3 = red,
	TextTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	ZIndex = 5
}, gui)
local rstroke = make("UIStroke", {Color = red, Thickness = 2, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, resetbtn)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, resetbtn)
local rscale = make("UIScale", {}, resetbtn)

task.delay(0.6, function()
	tween(resetbtn, 0.8, {Position = UDim2.new(1, -220, 0.5, -23), BackgroundTransparency = 0.15, TextTransparency = 0}, backout)
	tween(rstroke, 0.8, {Transparency = 0})
end)

resetbtn.MouseEnter:Connect(function()
	tween(resetbtn, 0.18, {BackgroundColor3 = Color3.fromRGB(70, 8, 8)})
	tween(rstroke, 0.18, {Thickness = 3.5})
	tween(rscale, 0.25, {Scale = 1.07}, backout)
end)
resetbtn.MouseLeave:Connect(function()
	tween(resetbtn, 0.18, {BackgroundColor3 = ink})
	tween(rstroke, 0.18, {Thickness = 2})
	tween(rscale, 0.2, {Scale = 1})
end)

local bar = make("Frame", {
	Size = UDim2.fromOffset(250, 76),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	BackgroundTransparency = 1
}, gui)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 10),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center
}, bar)

for i, name in ipairs({"REVOLVER", "KNIFE", "SHOTGUN"}) do
	local b = make("TextButton", {
		LayoutOrder = i,
		Size = UDim2.fromOffset(76, 60),
		BackgroundColor3 = ink,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5
	}, bar)
	make("UICorner", {CornerRadius = UDim.new(0, 8)}, b)
	local st = make("UIStroke", {Color = Color3.fromRGB(70, 70, 76), Thickness = 1.5, Transparency = 1}, b)
	local sc = make("UIScale", {Scale = 0}, b)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(20, 16),
		Position = UDim2.fromOffset(8, 5),
		Text = tostring(i),
		TextColor3 = red,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		ZIndex = 6
	}, b)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -24),
		Text = name,
		TextColor3 = Color3.fromRGB(225, 225, 230),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		ZIndex = 6
	}, b)
	slots[i] = {btn = b, stroke = st, scale = sc}
	task.delay(0.9 + i * 0.1, function()
		tween(sc, 0.55, {Scale = 1}, backout)
		tween(b, 0.4, {BackgroundTransparency = 0.2})
		tween(st, 0.4, {Transparency = 0})
	end)
	b.MouseButton1Click:Connect(function()
		equip(i)
	end)
end

local function selectslot(i)
	for n, s in ipairs(slots) do
		local on = n == i
		tween(s.stroke, 0.25, {Color = on and red or Color3.fromRGB(70, 70, 76), Thickness = on and 2.5 or 1.5})
		tween(s.scale, 0.3, {Scale = on and 1.14 or 1}, backout)
		tween(s.btn, 0.25, {BackgroundColor3 = on and Color3.fromRGB(48, 10, 10) or ink})
	end
end

local panel = make("Frame", {
	Size = UDim2.fromOffset(250, 92),
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, 130),
	BackgroundColor3 = ink,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 8)}, panel)
make("UIStroke", {Color = Color3.fromRGB(90, 20, 20), Thickness = 1.5}, panel)

local pname = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(130, 16),
	Position = UDim2.fromOffset(14, 10),
	Text = "",
	TextColor3 = red,
	TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.GothamBold,
	TextSize = 12
}, panel)
local pcount = make("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(100, 40),
	Position = UDim2.new(1, -14, 0, 2),
	Text = "",
	TextColor3 = Color3.fromRGB(240, 240, 245),
	TextXAlignment = Enum.TextXAlignment.Right,
	Font = Enum.Font.GothamBold,
	TextSize = 34
}, panel)
local preserve = make("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(100, 14),
	Position = UDim2.new(1, -14, 0, 42),
	Text = "",
	TextColor3 = Color3.fromRGB(140, 140, 150),
	TextXAlignment = Enum.TextXAlignment.Right,
	Font = Enum.Font.GothamBold,
	TextSize = 11
}, panel)
local pips = make("Frame", {
	Size = UDim2.fromOffset(122, 26),
	Position = UDim2.fromOffset(14, 38),
	BackgroundTransparency = 1
}, panel)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center
}, pips)
local barbg = make("Frame", {
	Size = UDim2.fromOffset(222, 3),
	Position = UDim2.fromOffset(14, 76),
	BackgroundColor3 = dim,
	BorderSizePixel = 0
}, panel)
local fill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = red, BorderSizePixel = 0}, barbg)

local function updateammo(w)
	if w.melee then
		pcount.Text = "x" .. w.combo
		preserve.Text = "COMBO"
	else
		pcount.Text = tostring(w.mag)
		preserve.Text = "/ " .. w.reserve
	end
	local lit = w.melee and w.combo or w.mag
	for i, p in ipairs(pipframes) do
		p.BackgroundColor3 = i <= lit and brass or dim
	end
end

local function showpanel(w)
	for _, p in ipairs(pipframes) do
		p:Destroy()
	end
	table.clear(pipframes)
	pname.Text = w.name
	for i = 1, w.size do
		local p = make("Frame", {LayoutOrder = i, Size = w.pip, BackgroundColor3 = dim, BorderSizePixel = 0}, pips)
		make("UICorner", {CornerRadius = UDim.new(w.round, 0)}, p)
		pipframes[i] = p
	end
	updateammo(w)
	tween(panel, 0.5, {Position = UDim2.new(1, -24, 1, -24)}, backout)
end

local function hidepanel()
	tween(panel, 0.3, {Position = UDim2.new(1, -24, 1, 130)}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

local function resetall()
	for target, data in pairs(deadtargets) do
		if data.conn then
			data.conn:Disconnect()
		end
		if target and (not data.plr or (data.plr.Parent and data.plr.Character == target)) then
			target.Parent = data.parent or workspace
		end
	end
	table.clear(deadtargets)
	table.clear(live)
	table.clear(bleeders)
	table.clear(splats)
	bodies:ClearAllChildren()
	blood:ClearAllChildren()
end

resetbtn.MouseButton1Click:Connect(function()
	resetall()
	rscale.Scale = 0.9
	tween(rscale, 0.3, {Scale = 1.07}, backout)
end)

local function snd(parent, id, vol, pitch)
	local s = make("Sound", {SoundId = id, Volume = vol, PlaybackSpeed = pitch}, parent)
	s:Play()
	debris:AddItem(s, 6)
end

local bloodcol = {
	Color3.fromRGB(125, 0, 0),
	Color3.fromRGB(150, 4, 4),
	Color3.fromRGB(100, 0, 0),
	Color3.fromRGB(170, 12, 12),
	Color3.fromRGB(80, 4, 4)
}

local function disc(base, off, d, h, grow)
	local p = make("Part", {
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		Color = bloodcol[math.random(#bloodcol)],
		Reflectance = 0.06,
		Size = Vector3.new(h, 0.05, 0.05),
		CFrame = base * CFrame.new(off) * rz90
	}, blood)

	splats[#splats + 1] = p
	if #splats > 260 then
		local old = table.remove(splats, 1)
		if old.Parent then
			old:Destroy()
		end
	end

	tween(p, grow, {Size = Vector3.new(h, d, d)}, Enum.EasingStyle.Quart)
end

local function splat(pos, normal, size, grow)
	local origin = pos + normal * 0.03
	local base = CFrame.lookAt(origin, origin + normal) * CFrame.Angles(math.rad(90), math.rad(math.random(0, 360)), 0)
	local n = size > 1.3 and 4 or (size > 0.6 and 2 or 1)
	for i = 1, n do
		local d = i == 1 and size or size * math.random(25, 55) / 100
		local off = i == 1 and Vector3.zero or Vector3.new(math.random(-100, 100) / 100, -0.002 * i, math.random(-100, 100) / 100) * size * 0.5
		disc(base, off, d, 0.02 + i * 0.004, grow)
	end
end

local function pool(pos)
	local res = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), gparams)
	if not res then return end
	for i = 1, 4 do
		local off = Vector3.new(math.random(-100, 100) / 100, 0, math.random(-100, 100) / 100) * 0.9
		splat(res.Position + off, res.Normal, math.random(18, 38) / 10, 6 + i * 1.5)
	end
end

local function drops(origin, dir, count)
	count = math.min(count, 170 - #live)
	for i = 1, count do
		local sz = math.random(10, 26) / 100
		local drop = make("Part", {
			Size = Vector3.new(sz, sz, sz * 2.2),
			Color = bloodcol[math.random(#bloodcol)],
			Material = Enum.Material.Glass,
			Reflectance = 0.2,
			CFrame = CFrame.new(origin),
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false
		}, blood)
		local a0 = make("Attachment", {Position = Vector3.new(0, sz / 2, 0)}, drop)
		local a1 = make("Attachment", {Position = Vector3.new(0, -sz / 2, 0)}, drop)
		make("Trail", {
			Attachment0 = a0,
			Attachment1 = a1,
			Color = ColorSequence.new(drop.Color),
			Transparency = NumberSequence.new(0.2, 1),
			Lifetime = 0.18,
			FaceCamera = true
		}, drop)
		drop.AssemblyLinearVelocity = dir * math.random(15, 55) + Vector3.new(math.random(-28, 28), math.random(10, 40), math.random(-28, 28))
		live[#live + 1] = {part = drop, born = os.clock()}
	end
end

local mists = {}
local mistn = 0
for i = 1, 6 do
	local m = make("Part", {Size = Vector3.one, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1}, view)
	local fog = make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(160, 0, 0), Color3.fromRGB(60, 0, 0)),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 4.2)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)}),
		Lifetime = NumberRange.new(0.3, 0.6),
		Rate = 0,
		Speed = NumberRange.new(10, 30),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4
	}, m)
	local bits = make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(110, 0, 0)),
		Size = NumberSequence.new(0.35, 0.05),
		Lifetime = NumberRange.new(0.5, 1),
		Rate = 0,
		Speed = NumberRange.new(14, 38),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -70, 0)
	}, m)
	mists[i] = {m, fog, bits}
end

local function makeblood(origin, dir, count)
	mistn = mistn % #mists + 1
	local m = mists[mistn]
	m[1].CFrame = CFrame.lookAt(origin, origin + dir) * CFrame.Angles(math.rad(-90), 0, 0)
	m[2]:Emit(count + 14)
	m[3]:Emit(math.floor(count / 2) + 4)
	drops(origin, dir, count)
end

local function wound(att, dur)
	local pe = make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(155, 0, 0), Color3.fromRGB(85, 0, 0)),
		Size = NumberSequence.new(0.4, 0.08),
		Transparency = NumberSequence.new(0, 0.6),
		Lifetime = NumberRange.new(0.4, 0.8),
		Rate = 0,
		Speed = NumberRange.new(6, 16),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -50, 0)
	}, att)
	bleeders[#bleeders + 1] = {att = att, pe = pe, t0 = os.clock(), dur = dur, nextt = 0}
end

link(rs.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local n = #live
	local i = 1
	while i <= n do
		local d = live[i]
		local p = d.part
		local dead = not p.Parent or now - d.born > 3
		if not dead then
			local hit = workspace:Raycast(p.Position, p.AssemblyLinearVelocity * dt * 2, gparams)
			if hit and hit.Instance.CanCollide then
				local m = hit.Instance:FindFirstAncestorOfClass("Model")
				if not (m and m:FindFirstChildOfClass("Humanoid")) then
					splat(hit.Position, hit.Normal, math.random(8, 26) / 10, 0.4)
				end
				dead = true
			end
		end
		if dead then
			p:Destroy()
			live[i] = live[n]
			live[n] = nil
			n = n - 1
		else
			i = i + 1
		end
	end
	for j = #bleeders, 1, -1 do
		local b = bleeders[j]
		if not b.att.Parent or now - b.t0 > b.dur then
			b.pe:Destroy()
			table.remove(bleeders, j)
		elseif now >= b.nextt then
			b.nextt = now + 0.28
			b.pe:Emit(math.ceil(16 * (1 - (now - b.t0) / b.dur)))
			drops(b.att.WorldPosition, Vector3.new(math.random(-10, 10) / 10, 0.5, math.random(-10, 10) / 10), 2)
		end
	end
end))

local function shake(n, mag)
	shakeleft = n
	shakemag = mag
end

local function screenfx()
	fxid = fxid + 1
	local id = fxid
	bloodframe.BackgroundTransparency = 0.35
	vignette.ImageTransparency = 0.05
	cc.Contrast = 0.6
	cc.Saturation = -0.3
	cc.TintColor = Color3.fromRGB(255, 170, 170)
	cc.Enabled = true
	tween(bloodframe, 1.1, {BackgroundTransparency = 1}, Enum.EasingStyle.Sine)
	tween(vignette, 1.5, {ImageTransparency = 1}, Enum.EasingStyle.Sine)
	tween(cc, 0.9, {Contrast = 0, Saturation = 0, TintColor = Color3.fromRGB(255, 255, 255)})
	task.delay(1, function()
		if fxid == id then
			cc.Enabled = false
		end
	end)
	shake(10, 0.75)
end

local function chunks(pos, dir, n)
	for i = 1, n do
		local s = math.random(15, 45) / 100
		local c = make("Part", {
			Size = Vector3.new(s, s * math.random(60, 120) / 100, s),
			Color = bloodcol[math.random(#bloodcol)],
			Material = Enum.Material.SmoothPlastic,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		}, blood)
		c.AssemblyLinearVelocity = dir * math.random(10, 28) + Vector3.new(math.random(-14, 14), math.random(8, 26), math.random(-14, 14))
		debris:AddItem(c, 8)
	end
end

local function killtarget(target, hitpos, dir, power, count)
	if deadtargets[target] then return end
	local hrp = target:FindFirstChild("HumanoidRootPart")
	local hum = target:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	local targetplr = players:GetPlayerFromCharacter(target)
	local origparent = target.Parent
	local wide = hum.RigType == Enum.HumanoidRigType.R15 and 55 or 38

	target.Archivable = true
	local clone = target:Clone()
	target.Archivable = false
	if not clone then return end

	target.Parent = nil
	local parentconn = target:GetPropertyChangedSignal("Parent"):Connect(function()
		if deadtargets[target] and target.Parent ~= nil then
			target.Parent = nil
		end
	end)
	deadtargets[target] = {parent = origparent, plr = targetplr, conn = parentconn}

	clone:SetAttribute("reaper", true)
	clone.Parent = bodies

	local chrp = clone:FindFirstChild("HumanoidRootPart")
	local chum = clone:FindFirstChildOfClass("Humanoid")
	local torso = clone:FindFirstChild("UpperTorso") or clone:FindFirstChild("Torso") or chrp

	if chum then
		chum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		chum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		chum.BreakJointsOnDeath = false
		chum.PlatformStand = true
		chum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		chum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		chum:ChangeState(Enum.HumanoidStateType.Dead)
	end

	local bodyparts, pairsof = {}, {}
	for _, v in ipairs(clone:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Anchored = false
			v.AssemblyLinearVelocity = Vector3.zero
			v.AssemblyAngularVelocity = Vector3.zero
			if v:FindFirstAncestorOfClass("Accessory") or v == chrp then
				v.CanCollide = false
				v.Massless = true
			else
				v.CanCollide = true
				v.CustomPhysicalProperties = PhysicalProperties.new(0.8, 0.5, 0.1, 1, 1)
				bodyparts[#bodyparts + 1] = v
			end
		elseif v:IsA("Motor6D") then
			if v.Part0 and v.Part1 then
				if v.Part0 == chrp or v.Part1 == chrp then
					v:Destroy()
				else
					local a0 = make("Attachment", {CFrame = v.C0}, v.Part0)
					local a1 = make("Attachment", {CFrame = v.C1}, v.Part1)
					sockets[v.Part1] = make("BallSocketConstraint", {
						Attachment0 = a0,
						Attachment1 = a1,
						LimitsEnabled = true,
						TwistLimitsEnabled = true,
						UpperAngle = wide,
						TwistLowerAngle = -30,
						TwistUpperAngle = 30,
						Restitution = 0
					}, v.Part0)
					pairsof[#pairsof + 1] = {v.Part0, v.Part1}
					v:Destroy()
				end
			end
		elseif v:IsA("LuaSourceContainer") or v:IsA("ForceField") or v:IsA("Animator") then
			v:Destroy()
		elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Highlight") or v:IsA("Light") then
			v.Enabled = false
		elseif v:IsA("Sound") then
			v:Stop()
		end
	end

	for _, pr in ipairs(pairsof) do
		make("NoCollisionConstraint", {Part0 = pr[1], Part1 = pr[2]}, pr[1])
	end
	if torso and torso ~= chrp then
		for _, bp in ipairs(bodyparts) do
			if bp ~= torso then
				make("NoCollisionConstraint", {Part0 = bp, Part1 = torso}, bp)
			end
		end
	end

	if chrp then
		chrp:Destroy()
	end

	if torso then
		snd(torso, gore, 2.5, 1)

		local push = dir * power + Vector3.new(0, power * 0.4, 0)
		local spin = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
		for _, bp in ipairs(bodyparts) do
			bp.AssemblyLinearVelocity = push
			bp.AssemblyAngularVelocity = spin
		end

		local bleed = make("ParticleEmitter", {
			Color = ColorSequence.new(Color3.fromRGB(145, 0, 0)),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0)}),
			Lifetime = NumberRange.new(0.25, 0.5),
			Rate = 65,
			Speed = NumberRange.new(4, 14),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -35, 0)
		}, torso)
		task.delay(3, function()
			if bleed.Parent then
				bleed.Enabled = false
			end
		end)

		task.delay(1.2, function()
			if torso.Parent then
				pool(torso.Position)
			end
		end)
	end

	screenfx()
	makeblood(hitpos, dir, count)
	return clone
end

local function stump(att, base, bone)
	local p = make("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.75, 0.75, 0.75),
		Color = Color3.fromRGB(105, 0, 0),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CFrame = CFrame.new(att.WorldPosition)
	}, base.Parent)
	make("WeldConstraint", {Part0 = base, Part1 = p}, p)
	if bone then
		local rel = base.CFrame:PointToObjectSpace(att.WorldPosition)
		local b = make("Part", {
			Size = Vector3.new(0.14, 0.7, 0.14),
			Color = Color3.fromRGB(235, 228, 205),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Massless = true,
			CFrame = CFrame.new(att.WorldPosition) * base.CFrame.Rotation * CFrame.new(0, rel.Y >= 0 and 0.2 or -0.2, 0)
		}, base.Parent)
		make("WeldConstraint", {Part0 = base, Part1 = b}, b)
	end
end

local function cut(corpse, limb, dir)
	if not limb or not limb:IsA("BasePart") or not limb:IsDescendantOf(corpse) then return false end
	local n = limb.Name
	if not (n == "Head" or n:find("Arm") or n:find("Leg") or n:find("Hand") or n:find("Foot")) then return false end

	local sock = sockets[limb]
	if not sock or not sock.Parent then return false end

	local a0, a1 = sock.Attachment0, sock.Attachment1
	sock:Destroy()
	sockets[limb] = nil
	stump(a0, a0.Parent, false)
	stump(a1, limb, true)
	wound(a0, n == "Head" and 9 or 7)
	wound(a1, 4)
	limb.AssemblyLinearVelocity = dir * 26 + Vector3.new(math.random(-6, 6), 16, math.random(-6, 6))
	limb.AssemblyAngularVelocity = Vector3.new(math.random(-14, 14), math.random(-14, 14), math.random(-14, 14))
	makeblood(a1.WorldPosition, dir, 30)
	chunks(a1.WorldPosition, dir, 10)
	snd(limb, gore, 2.2, 1.25)
	shake(6, 1.2)
	return true
end

local function bodypart(inst)
	local acc = inst:FindFirstAncestorOfClass("Accessory")
	if acc and inst.Parent == acc then
		local w = inst:FindFirstChildOfClass("Weld")
		if w and w.Part0 and w.Part1 then
			return w.Part0 == inst and w.Part1 or w.Part0
		end
	end
	return inst
end

local function shove(model, dir, power)
	for _, v in ipairs(model:GetDescendants()) do
		if v:IsA("BasePart") and not v.Anchored then
			v.AssemblyLinearVelocity = v.AssemblyLinearVelocity + dir * power * 0.5 + Vector3.new(0, power * 0.2, 0)
		end
	end
end

local function impact(hit, dir, power, count, tear)
	local inst = hit.Instance
	local model = inst:FindFirstAncestorOfClass("Model")
	if not (model and model:FindFirstChildOfClass("Humanoid")) or model == lp.Character then return false end
	local limb = bodypart(inst)
	local corpse = model
	if model:GetAttribute("reaper") then
		makeblood(hit.Position, dir, count)
		shove(model, dir, power)
		snd(inst, gore, 1.4, 1.3)
	else
		corpse = killtarget(model, hit.Position, dir, power, count)
		limb = corpse and limb and corpse:FindFirstChild(limb.Name)
	end
	if corpse and limb and math.random() < tear then
		cut(corpse, limb, dir)
	end
	return true
end

local function tracer(a, b, thick)
	local dist = (a - b).Magnitude
	if dist < 0.1 then return end
	local t = make("Part", {
		Size = Vector3.new(thick, thick, dist),
		CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -dist / 2),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 180, 80),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false
	}, blood)
	tween(t, 0.12, {Size = Vector3.new(0, 0, dist), Transparency = 1})
	debris:AddItem(t, 0.15)
end

local function bullethole(hit)
	local hole = make("Part", {
		Size = Vector3.new(0.3, 0.3, 0.05),
		Color = Color3.fromRGB(15, 15, 15),
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		CFrame = CFrame.lookAt(hit.Position, hit.Position + hit.Normal)
	}, blood)
	debris:AddItem(hole, 6)
end

local function casing(cf, vel, col)
	local c = make("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.28, 0.12, 0.12),
		Color = col or brass,
		Material = Enum.Material.Metal,
		CanQuery = false,
		CanTouch = false,
		CFrame = cf
	}, blood)
	c.AssemblyLinearVelocity = vel
	c.AssemblyAngularVelocity = Vector3.new(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30))
	debris:AddItem(c, 4)
end

local function castmouse(dir)
	local unit = mouse.UnitRay
	local look = dir or unit.Direction
	local origin = unit.Origin
	local skipped, res
	for i = 1, 8 do
		res = workspace:Raycast(origin, look * 2500, mparams)
		if not res then break end
		local inst = res.Instance
		local model = inst:FindFirstAncestorOfClass("Model")
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if hum and not deadtargets[model] then break end
		if inst.Transparency >= 0.95 and not inst.CanCollide then
			skipped = skipped or table.clone(mbase)
			skipped[#skipped + 1] = inst
			mparams.FilterDescendantsInstances = skipped
			origin = res.Position + look * 0.05
		else
			break
		end
	end
	if skipped then
		mparams.FilterDescendantsInstances = mbase
	end
	if res then
		return res, res.Position, look
	end
	return nil, unit.Origin + look * 400, look
end

local function play(seq)
	token = token + 1
	local id = token
	task.spawn(function()
		for _, f in ipairs(seq) do
			if token ~= id then return end
			if type(f) == "function" then
				f()
			else
				for i = 1, 6 do
					goal[i] = f[2][i]
				end
				rate = f[3]
				task.wait(f[1])
			end
		end
	end)
end

local function setreal(mod)
	for _, p in ipairs(reals) do
		p.LocalTransparencyModifier = mod
	end
end

local function buildarm(char)
	setreal(0)
	table.clear(reals)
	if vm then
		vm:Destroy()
		vm = nil
	end
	vlist = nil
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local names = r15 and {"RightUpperArm", "RightLowerArm", "RightHand"} or {"Right Arm"}
	local keep = {}
	for _, n in ipairs(names) do
		local p = char:WaitForChild(n, 5)
		if not p then return end
		keep[n] = true
		reals[#reals + 1] = p
	end

	local was = char.Archivable
	char.Archivable = true
	local c = char:Clone()
	char.Archivable = was
	if not c then return end

	for _, v in ipairs(c:GetChildren()) do
		if not (keep[v.Name] or v:IsA("Humanoid") or v:IsA("CharacterAppearance")) then
			v:Destroy()
		end
	end
	for _, v in ipairs(c:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Anchored = true
			v.CanCollide = false
			v.CanQuery = false
			v.CanTouch = false
			v.CastShadow = false
			v.LocalTransparencyModifier = 0
		elseif v:IsA("JointInstance") or v:IsA("LuaSourceContainer") or v:IsA("Sound") or v:IsA("Animator") or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") or v:IsA("Light") or v:IsA("Highlight") or v:IsA("ForceField") then
			v:Destroy()
		end
	end
	local ch = c:FindFirstChildOfClass("Humanoid")
	if ch then
		ch.RequiresNeck = false
		ch.BreakJointsOnDeath = false
		ch.PlatformStand = true
		ch.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		ch.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	if r15 then
		local up, lo, hd = c.RightUpperArm, c.RightLowerArm, c.RightHand
		local relup = up.RightShoulderRigAttachment.CFrame:Inverse()
		local rello = relup * up.RightElbowRigAttachment.CFrame * lo.RightElbowRigAttachment.CFrame:Inverse()
		local relhd = rello * lo.RightWristRigAttachment.CFrame * hd.RightWristRigAttachment.CFrame:Inverse()
		armlen = -(relhd * hd.RightGripAttachment.CFrame).Position.Y
		vlist = {up, lo, hd}
		vrel = {relup, rello, relhd}
		vtorso = char:WaitForChild("UpperTorso", 5)
		vsh = vtorso and vtorso:FindFirstChild("RightShoulderRigAttachment")
	else
		local ra = c["Right Arm"]
		armlen = ra.Size.Y
		vlist = {ra}
		vrel = {CFrame.new(0, -ra.Size.Y / 2, 0)}
		vtorso = char:WaitForChild("Torso", 5)
		vsh = nil
	end
	vhum = hum
	vm = c
	c.Parent = view
end

rs:BindToRenderStep("reaperview", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeleft > 0 then
		shakeleft = shakeleft - 1
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad((math.random() * 2 - 1) * shakemag), math.rad((math.random() * 2 - 1) * shakemag), 0)
	end
	local w = current and loadout[current]
	if not w or not vlist or not vtorso or not vtorso.Parent or vhum.Health <= 0 then return end

	local k = math.min(dt * rate, 1)
	for i = 1, 6 do
		pose[i] = pose[i] + (goal[i] - pose[i]) * k
	end

	local shoulder = vsh and vsh.WorldPosition or (vtorso.CFrame * CFrame.new(1.5, 0.85, 0)).Position
	local ray = mouse.UnitRay
	local ac = CFrame.lookAt(shoulder, ray.Origin + ray.Direction * 80) * CFrame.Angles(pose[1], pose[2], pose[3])
	local base = ac * CFrame.new(0, 0, armlen - pose[4])
	local armcf = base * rx90

	for i, p in ipairs(vlist) do
		p.CFrame = armcf * vrel[i]
	end
	w.root.CFrame = base * CFrame.new(0, 0, -armlen) * CFrame.Angles(pose[5], 0, pose[6]) * w.grip
	setreal(1)
end)

local function part(base, name, cf, size, color, mat, shape)
	local p = make("Part", {
		Name = name,
		Size = size,
		Color = color,
		Material = mat or Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Massless = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth
	}, base)
	if shape then
		p.Shape = shape
	end
	local w = make("Weld", {Part0 = base, Part1 = p, C0 = cf}, p)
	return p, w
end

local function newroot(size, color, mat)
	return make("Part", {
		Name = "Handle",
		Size = size,
		Color = color,
		Material = mat,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false
	})
end

local function reload(w)
	if reloading or w.melee or w.mag == w.size or w.reserve <= 0 then return end
	reloading = true
	local need = math.min(w.size - w.mag, w.reserve)
	play(w.reloadseq)
	if w.dump then
		w.dump()
	end
	fill.Size = UDim2.fromScale(0, 1)
	tween(fill, w.reloadtime, {Size = UDim2.fromScale(1, 1)}, Enum.EasingStyle.Linear)
	task.spawn(function()
		task.wait(w.reloadtime * 0.35)
		for i = 1, need do
			if not reloading then return end
			w.mag = w.mag + 1
			w.reserve = w.reserve - 1
			updateammo(w)
			if w.insert then
				w.insert()
			end
			task.wait(w.reloadtime * 0.4 / need)
		end
		task.wait(w.reloadtime * 0.25)
		reloading = false
		fill.Size = UDim2.fromScale(0, 1)
	end)
end

local function makegun()
	local handle = newroot(Vector3.new(0.32, 0.9, 0.52), Color3.fromRGB(96, 56, 28), Enum.Material.Wood)
	local steel = Color3.fromRGB(46, 48, 54)
	local dark = Color3.fromRGB(22, 22, 24)
	local bright = Color3.fromRGB(110, 112, 120)
	local metal = Enum.Material.Metal
	local cyl = Enum.PartType.Cylinder
	local ry = CFrame.Angles(0, math.rad(90), 0)

	for i = -2, 2 do
		part(handle, "Band", CFrame.new(0, i * 0.17, 0), Vector3.new(0.335, 0.025, 0.535), Color3.fromRGB(38, 22, 10), Enum.Material.Wood)
	end
	part(handle, "Cap", CFrame.new(0, -0.49, 0), Vector3.new(0.35, 0.08, 0.58), steel, metal)
	part(handle, "Strap", CFrame.new(0, 0.02, 0.28), Vector3.new(0.18, 0.92, 0.07), steel, metal)
	for _, sx in ipairs({-1, 1}) do
		part(handle, "Medal", CFrame.new(sx * 0.17, 0.08, 0), Vector3.new(0.02, 0.14, 0.14), brass, metal, cyl)
	end

	part(handle, "Frame", CFrame.new(0, 0.66, -0.1), Vector3.new(0.26, 0.42, 1.0), steel, metal)
	part(handle, "Top", CFrame.new(0, 0.92, -0.05), Vector3.new(0.2, 0.08, 1.0), steel, metal)

	local drum, drumw = part(handle, "Drum", CFrame.new(0, 0.68, -0.3) * ry, Vector3.new(0.6, 0.46, 0.46), bright, metal, cyl)
	for i = 0, 5 do
		local a = math.rad(i * 60)
		local cy, cz = math.sin(a) * 0.15, math.cos(a) * 0.15
		part(drum, "Chamber", CFrame.new(0.3, cy, cz), Vector3.new(0.04, 0.1, 0.1), dark, metal, cyl)
		part(drum, "Shell", CFrame.new(-0.3, cy, cz), Vector3.new(0.04, 0.1, 0.1), brass, metal, cyl)
	end
	part(drum, "Pin", CFrame.new(0.31, 0, 0), Vector3.new(0.05, 0.08, 0.08), steel, metal, cyl)

	part(handle, "Barrel", CFrame.new(0, 0.83, -1.325) * ry, Vector3.new(1.45, 0.2, 0.2), steel, metal, cyl)
	part(handle, "Crown", CFrame.new(0, 0.83, -2.03) * ry, Vector3.new(0.08, 0.27, 0.27), bright, metal, cyl)
	part(handle, "Bore", CFrame.new(0, 0.83, -2.075) * ry, Vector3.new(0.02, 0.1, 0.1), dark, metal, cyl)
	part(handle, "Lug", CFrame.new(0, 0.68, -1.0), Vector3.new(0.17, 0.2, 0.8), steel, metal)
	part(handle, "Rod", CFrame.new(0, 0.6, -1.075) * ry, Vector3.new(0.95, 0.1, 0.1), bright, metal, cyl)
	part(handle, "Knob", CFrame.new(0, 0.6, -1.57) * ry, Vector3.new(0.06, 0.14, 0.14), steel, metal, cyl)
	part(handle, "Front", CFrame.new(0, 0.99, -1.95), Vector3.new(0.04, 0.1, 0.12), dark, metal)
	for _, sx in ipairs({-1, 1}) do
		part(handle, "Rear", CFrame.new(sx * 0.06, 1.0, 0.4), Vector3.new(0.04, 0.08, 0.08), dark, metal)
	end
	part(handle, "GuardF", CFrame.new(0, 0.31, -0.52), Vector3.new(0.06, 0.3, 0.07), steel, metal)
	part(handle, "GuardB", CFrame.new(0, 0.155, -0.26), Vector3.new(0.06, 0.06, 0.58), steel, metal)
	part(handle, "Trigger", CFrame.new(0, 0.34, -0.33) * CFrame.Angles(math.rad(-15), 0, 0), Vector3.new(0.04, 0.17, 0.05), bright, metal)

	local hammer, hammerw = part(handle, "Hammer", CFrame.new(0, 0.9, 0.36) * CFrame.Angles(math.rad(38), 0, 0) * CFrame.new(0, 0.12, 0.02), Vector3.new(0.07, 0.3, 0.1), steel, metal)
	part(hammer, "Spur", CFrame.new(0, 0.14, 0.06), Vector3.new(0.09, 0.05, 0.14), bright, metal)

	local hamcock = hammerw.C0
	local hamrest = CFrame.new(0, 0.9, 0.36) * CFrame.Angles(math.rad(6), 0, 0) * CFrame.new(0, 0.12, 0.02)
	local drumc = drumw.C0

	local muzzle = make("Attachment", {Position = Vector3.new(0, 0.83, -2.1)}, handle)
	local smoke = make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(190, 190, 190)),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1.2)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)}),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(1, 4),
		SpreadAngle = Vector2.new(25, 25),
		Rate = 0
	}, muzzle)
	local flash = make("PointLight", {Color = Color3.fromRGB(255, 60, 40), Range = 20, Brightness = 7, Enabled = false}, muzzle)

	local w = {
		name = "REVOLVER",
		root = handle,
		grip = CFrame.new(0, -0.5, 0.1),
		size = 6,
		mag = 6,
		reserve = 48,
		pip = UDim2.fromOffset(15, 15),
		round = 1,
		reloadtime = 1.7,
		cd = false
	}
	w.idle = {0, 0, 0, 2.1, 0, 0}
	w.equip = {
		{0.01, {-1.2, 0.5, 0, 1.7, -0.4, 0}, 30},
		{0.16, {0.25, -0.1, 0, 2.1, 0.15, 0}, 16},
		{0.2, w.idle, 10}
	}
	w.recoil = {
		{0.05, {0.55, 0.05, 0.1, 1.7, 0.5, 0}, 55},
		{0.25, w.idle, 9}
	}
	w.reloadseq = {
		{0.18, {0.1, 0.7, -0.2, 1.7, 0.2, 0.8}, 14},
		{0.35, {0.3, 0.8, -0.3, 1.6, 0.1, 1.1}, 10},
		{0.7, {0.3, 0.8, -0.3, 1.6, 0.1, 1.1}, 10},
		{0.25, {0.1, 0.5, -0.1, 1.9, 0, 0.3}, 12},
		{0.2, w.idle, 10}
	}

	local spin = 0
	w.dump = function()
		for i = 1, w.size - w.mag do
			casing(handle.CFrame * CFrame.new(0.2, 0.5, 0), handle.CFrame.RightVector * math.random(2, 6) + Vector3.new(math.random(-3, 3), math.random(-2, 3), math.random(-3, 3)))
		end
		snd(handle, click, 0.8, 0.8)
	end
	w.insert = function()
		spin = spin + math.rad(60)
		tween(drumw, 0.12, {C0 = drumc * CFrame.Angles(spin, 0, 0)})
		snd(handle, click, 0.7, 1.5)
	end

	w.use = function()
		if w.cd then return end
		if w.mag <= 0 then
			snd(handle, click, 0.8, 1.7)
			reload(w)
			return
		end
		w.cd = true
		w.mag = w.mag - 1
		updateammo(w)

		local hit, endpos = castmouse()
		local origin = muzzle.WorldPosition

		snd(handle, "rbxassetid://1905367471", 1.6, math.random(95, 105) / 100)
		smoke:Emit(10)
		flash.Enabled = true
		task.delay(0.06, function()
			flash.Enabled = false
		end)
		casing(handle.CFrame * CFrame.new(0.25, 0.4, 0), handle.CFrame.RightVector * 14 + Vector3.new(0, 18, 0))
		tracer(origin, endpos, 0.08)

		if hit then
			local dir = (endpos - origin).Unit
			if not impact(hit, dir, kick, 26, 0.7) then
				bullethole(hit)
			end
		end

		spin = spin + math.rad(60)
		tween(hammerw, 0.04, {C0 = hamrest})
		play(w.recoil)
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(3), math.rad(math.random(-10, 10) / 10), 0)

		task.delay(0.12, function()
			tween(drumw, 0.1, {C0 = drumc * CFrame.Angles(spin, 0, 0)})
			tween(hammerw, 0.12, {C0 = hamcock})
		end)

		task.wait(0.28)
		w.cd = false
	end

	return w
end

local function makeknife()
	local handle = newroot(Vector3.new(0.22, 0.26, 0.85), Color3.fromRGB(70, 44, 26), Enum.Material.Leather)
	local steel = Color3.fromRGB(70, 72, 80)
	local raw = Color3.fromRGB(140, 146, 155)
	local metal = Enum.Material.Metal
	local cyl = Enum.PartType.Cylinder
	local silver = Color3.fromRGB(205, 210, 218)

	for i = 0, 5 do
		part(handle, "Wrap", CFrame.new(0, 0, -0.33 + i * 0.13), Vector3.new(0.235, 0.275, 0.05), Color3.fromRGB(18, 18, 20), Enum.Material.Fabric)
	end
	for _, z in ipairs({-0.2, 0.2}) do
		part(handle, "Pin", CFrame.new(0, 0, z), Vector3.new(0.27, 0.07, 0.07), brass, metal, cyl)
	end
	part(handle, "Butt", CFrame.new(0, 0, 0.45), Vector3.new(0.24, 0.3, 0.06), steel, metal)
	part(handle, "Pommel", CFrame.new(0, 0, 0.55), Vector3.new(0.3, 0.3, 0.3), brass, metal, Enum.PartType.Ball)
	part(handle, "Guard", CFrame.new(0, 0, -0.48), Vector3.new(0.16, 0.46, 0.1), steel, metal)
	part(handle, "Lip", CFrame.new(0, 0, -0.54), Vector3.new(0.12, 0.4, 0.04), brass, metal)
	part(handle, "QuillonB", CFrame.new(0, -0.3, -0.5) * CFrame.Angles(math.rad(28), 0, 0), Vector3.new(0.1, 0.18, 0.08), steel, metal)
	part(handle, "QuillonT", CFrame.new(0, 0.3, -0.5) * CFrame.Angles(math.rad(-28), 0, 0), Vector3.new(0.1, 0.18, 0.08), steel, metal)
	part(handle, "Ricasso", CFrame.new(0, 0, -0.62), Vector3.new(0.07, 0.27, 0.14), raw, metal)

	local blade = part(handle, "Blade", CFrame.new(0, 0, -1.2), Vector3.new(0.05, 0.25, 1.05), silver, metal)
	blade.Reflectance = 0.25
	part(handle, "Tip", CFrame.new(0, 0, -1.725) * CFrame.Angles(math.rad(45), 0, 0), Vector3.new(0.05, 0.17, 0.17), silver, metal)
	part(handle, "Edge", CFrame.new(0, -0.1, -1.2), Vector3.new(0.056, 0.05, 1.05), Color3.fromRGB(240, 244, 250), metal)
	part(handle, "Spine", CFrame.new(0, 0.105, -1.2), Vector3.new(0.066, 0.04, 1.05), raw, metal)
	part(handle, "Fuller", CFrame.new(0, 0.03, -1.12), Vector3.new(0.058, 0.035, 0.75), Color3.fromRGB(120, 126, 136), metal)
	for i = 0, 6 do
		part(handle, "Tooth", CFrame.new(0, 0.13, -0.8 - i * 0.1), Vector3.new(0.07, 0.035, 0.05), raw, metal)
	end

	local ta = make("Attachment", {Position = Vector3.new(0, -0.1, -1.85)}, handle)
	local tb = make("Attachment", {Position = Vector3.new(0, -0.1, -0.75)}, handle)
	local trail = make("Trail", {
		Attachment0 = ta,
		Attachment1 = tb,
		Lifetime = 0.18,
		Transparency = NumberSequence.new(0.35, 1),
		Color = ColorSequence.new(Color3.fromRGB(235, 240, 255)),
		LightEmission = 0.4,
		Enabled = false
	}, handle)

	local kidle = {-0.55, -0.2, 0, 1.75, 0.95, 0}
	local w = {
		name = "KNIFE",
		root = handle,
		grip = CFrame.new(0, 0, 0.15),
		size = 4,
		melee = true,
		combo = 0,
		last = 0,
		pip = UDim2.fromOffset(40, 6),
		round = 1,
		cd = false
	}
	w.equip = {
		{0.01, {-1.3, 0.3, 0, 1.5, 0.2, 0}, 30},
		{0.14, {0.2, -0.1, 0, 2.0, 0.2, 0}, 22},
		{0.34, {0.2, -0.1, 0, 2.0, 6.483, 0}, 16},
		function()
			pose[5] = 0.2
			goal[5] = 0.2
		end,
		{0.25, kidle, 10}
	}

	local swings = {
		{{0.13, {0.15, -1.0, 0.3, 1.8, 0.5, 0.5}, 30}, {0.1, {-0.15, 1.0, -0.3, 2.5, 0.5, -0.5}, 50}, {0.3, kidle, 11}},
		{{0.13, {0.1, 1.0, -0.4, 1.8, 0.5, -0.5}, 30}, {0.1, {-0.1, -1.0, 0.3, 2.5, 0.5, 0.5}, 50}, {0.3, kidle, 11}},
		{{0.16, {1.5, 0, 0, 1.6, 0.6, 0}, 28}, {0.09, {-0.8, 0.1, 0, 2.7, 0.9, 0}, 55}, {0.34, kidle, 10}},
		{{0.2, {-0.3, 0, 0, 1.0, 0, 0}, 24}, {0.08, {0.05, 0, 0, 3.1, -0.05, 0}, 60}, {0.38, kidle, 9}}
	}

	w.use = function()
		if w.cd then return end
		w.cd = true

		if os.clock() - w.last > 1.4 then
			w.combo = 0
		end
		w.combo = w.combo % 4 + 1
		w.last = os.clock()
		local stamp = w.last
		local seq = swings[w.combo]
		updateammo(w)

		task.delay(1.5, function()
			if w.last == stamp then
				w.combo = 0
				if current and loadout[current] == w then
					updateammo(w)
				end
			end
		end)

		play(seq)
		trail.Enabled = true
		task.delay(0.3, function()
			trail.Enabled = false
		end)
		snd(handle, "rbxasset://sounds/swordslash.wav", 0.9, math.random(95, 112) / 100)

		task.wait(seq[1][1])

		local char = lp.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local hit = castmouse()
			if hit and (hit.Position - root.Position).Magnitude <= 9 then
				impact(hit, (hit.Position - root.Position).Unit, 3, w.combo == 4 and 22 or 14, 1)
			end
		end

		task.wait(seq[2][1] + 0.2)
		w.cd = false
	end

	return w
end

local function makeshotgun()
	local handle = newroot(Vector3.new(0.3, 0.85, 0.42), Color3.fromRGB(88, 52, 26), Enum.Material.Wood)
	local steel = Color3.fromRGB(40, 42, 48)
	local bright = Color3.fromRGB(105, 108, 116)
	local wood = Color3.fromRGB(110, 66, 32)
	local dark = Color3.fromRGB(18, 18, 20)
	local metal = Enum.Material.Metal
	local cyl = Enum.PartType.Cylinder
	local ry = CFrame.Angles(0, math.rad(90), 0)

	part(handle, "Receiver", CFrame.new(0, 0.62, -0.25), Vector3.new(0.36, 0.42, 1.5), steel, metal)
	part(handle, "Top", CFrame.new(0, 0.86, -0.25), Vector3.new(0.22, 0.06, 1.5), bright, metal)
	part(handle, "Barrel", CFrame.new(0, 0.74, -2.0) * ry, Vector3.new(2.3, 0.28, 0.28), steel, metal, cyl)
	part(handle, "Muzzle", CFrame.new(0, 0.74, -3.17) * ry, Vector3.new(0.08, 0.34, 0.34), bright, metal, cyl)
	part(handle, "Bore", CFrame.new(0, 0.74, -3.2) * ry, Vector3.new(0.02, 0.18, 0.18), dark, metal, cyl)
	part(handle, "Tube", CFrame.new(0, 0.48, -1.9) * ry, Vector3.new(1.9, 0.22, 0.22), steel, metal, cyl)
	part(handle, "Cap", CFrame.new(0, 0.48, -2.88) * ry, Vector3.new(0.08, 0.28, 0.28), bright, metal, cyl)
	part(handle, "Bead", CFrame.new(0, 0.94, -3.05), Vector3.new(0.05, 0.1, 0.05), brass, metal)
	for i = 0, 3 do
		part(handle, "Band", CFrame.new(0, 0.74, -1.2 - i * 0.55) * ry, Vector3.new(0.05, 0.31, 0.31), bright, metal, cyl)
	end

	local pump, pumpw = part(handle, "Pump", CFrame.new(0, 0.46, -1.45), Vector3.new(0.38, 0.32, 0.9), wood, Enum.Material.Wood)
	for i = -2, 2 do
		part(pump, "Groove", CFrame.new(0, -0.17, i * 0.17), Vector3.new(0.4, 0.04, 0.05), Color3.fromRGB(40, 24, 12), Enum.Material.Wood)
	end
	part(handle, "Stock", CFrame.new(0, 0.5, 0.95), Vector3.new(0.32, 0.55, 1.5), wood, Enum.Material.Wood)
	part(handle, "Neck", CFrame.new(0, 0.62, 0.32), Vector3.new(0.3, 0.3, 0.6), wood, Enum.Material.Wood)
	part(handle, "Plate", CFrame.new(0, 0.5, 1.72), Vector3.new(0.34, 0.6, 0.06), dark, Enum.Material.Fabric)
	part(handle, "GuardF", CFrame.new(0, 0.31, -0.52), Vector3.new(0.06, 0.3, 0.07), steel, metal)
	part(handle, "GuardB", CFrame.new(0, 0.155, -0.26), Vector3.new(0.06, 0.06, 0.58), steel, metal)
	part(handle, "Trigger", CFrame.new(0, 0.34, -0.33) * CFrame.Angles(math.rad(-15), 0, 0), Vector3.new(0.04, 0.17, 0.05), bright, metal)

	local pumpc = pumpw.C0
	local muzzle = make("Attachment", {Position = Vector3.new(0, 0.74, -3.25)}, handle)
	local smoke = make("ParticleEmitter", {
		Color = ColorSequence.new(Color3.fromRGB(200, 200, 200)),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 2.2)}),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)}),
		Lifetime = NumberRange.new(0.7, 1.3),
		Speed = NumberRange.new(2, 7),
		SpreadAngle = Vector2.new(30, 30),
		Rate = 0
	}, muzzle)
	local flash = make("PointLight", {Color = Color3.fromRGB(255, 120, 40), Range = 26, Brightness = 10, Enabled = false}, muzzle)

	local w = {
		name = "SHOTGUN",
		root = handle,
		grip = CFrame.new(0, -0.55, 0),
		size = 4,
		mag = 4,
		reserve = 28,
		pip = UDim2.fromOffset(14, 28),
		round = 0.3,
		reloadtime = 2.4,
		cd = false
	}
	w.idle = {0, 0, 0, 2.0, 0, 0}
	w.equip = {
		{0.01, {-1.3, -0.3, 0, 1.6, -0.5, 0}, 30},
		{0.18, {0.3, 0.05, 0, 2.0, 0.2, 0}, 16},
		{0.2, w.idle, 10}
	}
	w.recoil = {
		{0.05, {1.0, 0.05, 0.12, 1.4, 0.8, 0}, 60},
		{0.2, {0.3, 0, 0, 1.9, 0.2, 0}, 9},
		{0.3, w.idle, 8}
	}
	w.reloadseq = {
		{0.3, {0.9, -0.2, 0.2, 1.7, 0.9, 0.2}, 12},
		{1.8, {0.9, -0.2, 0.2, 1.7, 0.9, 0.2}, 8},
		{0.3, w.idle, 10}
	}
	w.insert = function()
		snd(handle, click, 0.8, 1.2)
	end

	w.use = function()
		if w.cd then return end
		if w.mag <= 0 then
			snd(handle, click, 0.8, 1.7)
			reload(w)
			return
		end
		w.cd = true
		w.mag = w.mag - 1
		updateammo(w)

		local origin = muzzle.WorldPosition
		snd(handle, "rbxassetid://1905367471", 3, math.random(66, 74) / 100)
		smoke:Emit(18)
		flash.Enabled = true
		task.delay(0.07, function()
			flash.Enabled = false
		end)
		play(w.recoil)
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(6), math.rad(math.random(-20, 20) / 10), 0)

		local base = mouse.UnitRay.Direction
		for i = 1, 8 do
			local d = (base + Vector3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)) / 100 * 0.055).Unit
			local hit, endpos = castmouse(d)
			tracer(origin, endpos, 0.04)
			if hit then
				if not impact(hit, (endpos - origin).Unit, 48, 20, i == 1 and 1 or 0.45) then
					bullethole(hit)
				end
			end
		end

		task.wait(0.4)
		snd(handle, click, 1, 0.6)
		tween(pumpw, 0.13, {C0 = pumpc * CFrame.new(0, 0, 0.55)})
		casing(handle.CFrame * CFrame.new(0.2, 0.7, -0.3), handle.CFrame.RightVector * 9 + Vector3.new(0, 12, 0), Color3.fromRGB(190, 40, 30))
		task.wait(0.15)
		tween(pumpw, 0.13, {C0 = pumpc})
		task.wait(0.3)
		w.cd = false
	end

	return w
end

loadout = {makegun(), makeknife(), makeshotgun()}

equip = function(i)
	if reloading then return end
	local char = lp.Character
	local old = current and loadout[current]
	if old then
		old.root.Parent = nil
	end
	if current == i then
		current = nil
		token = token + 1
		if vm then
			vm.Parent = nil
		end
		setreal(0)
		selectslot(0)
		hidepanel()
		return
	end
	local w = loadout[i]
	if not w or not char then return end
	if vmchar ~= char then
		vmchar = char
		buildarm(char)
	end
	if not current then
		local low = {-1.4, 0.3, 0, 1.5, 0, 0}
		for n = 1, 6 do
			pose[n] = low[n]
			goal[n] = low[n]
		end
	end
	current = i
	w.root.Parent = view
	if vm then
		vm.Parent = view
	end
	selectslot(i)
	showpanel(w)
	snd(w.root, click, 0.8, 1)
	play(w.equip)
end

link(uis.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	local kc = input.KeyCode
	local ut = input.UserInputType
	if ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.Touch then
		if current and not reloading then
			loadout[current].use()
		end
	elseif kc == Enum.KeyCode.One then
		equip(1)
	elseif kc == Enum.KeyCode.Two then
		equip(2)
	elseif kc == Enum.KeyCode.Three then
		equip(3)
	elseif kc == Enum.KeyCode.R then
		if current then
			reload(loadout[current])
		end
	elseif kc == Enum.KeyCode.X then
		resetall()
	end
end))

link(lp.CharacterAdded:Connect(function(char)
	setchar(char)
	current = nil
	reloading = false
	token = token + 1
	vmchar = nil
	vlist = nil
	table.clear(reals)
	if vm then
		vm:Destroy()
		vm = nil
	end
	for _, w in ipairs(loadout) do
		w.root.Parent = nil
		w.cd = false
	end
	selectslot(0)
	hidepanel()
	char:WaitForChild("Humanoid")
	local t0 = os.clock()
	while not lp:HasAppearanceLoaded() and os.clock() - t0 < 6 do
		task.wait(0.1)
	end
	task.wait(0.3)
	equip(1)
end))

task.delay(2, function()
	if not current then
		equip(1)
	end
end)
