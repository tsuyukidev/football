--[[
    sctx hub | (tuff vape ui aura)
	use K to open menu btw stupid niggas
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local cloneref = cloneref or function(x) return x end

local plr = Players.LocalPlayer
local Football = game:GetService("ReplicatedStorage"):WaitForChild("Football")
local Config = require(Football.Shared.Config)
pcall(function() if setreadonly then setreadonly(Config, false) end end)
local Client = require(Football.Client.BallActionClient)
local TAC = require(Football.Client.ToolAnimationController)

local ballName = Config.BallName
local function getBall()
	return workspace:FindFirstChild(ballName)
end

local function getHRP()
	local c = plr.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- vape setup
local dirs = { "newvape", "newvape/profiles", "newvape/assets", "newvape/assets/new", "newvape/games", "newvape/libraries", "newvape/guis" }
for _, d in dirs do
	if makefolder and isfolder and not isfolder(d) then
		makefolder(d)
	end
end
if writefile then
	local sha = "main"
	pcall(function()
		local dat = HttpService:JSONDecode(cloneref(game):HttpGet("https://api.github.com/repos/7GrandDadPGN/VapeCompiled/commits/main"))
		if type(dat) == "table" and dat.sha then sha = dat.sha end
	end)
	writefile("newvape/profiles/commit.txt", sha)
end

local vape = loadstring(game:HttpGet("https://raw.githubusercontent.com/7GrandDadPGN/VapeCompiled/refs/heads/main/guis/new.lua"))()

local getvapeasset = vape.Libraries.getvapeasset

for _, name in { "Combat", "Blatant", "Render", "Utility", "World", "Inventory" } do
	local comp = vape.Categories[name]
	if comp then
		if comp.Button then
			comp.Button:Destroy()
		end
		comp.Object:Destroy()
		vape.Categories[name] = nil
	end
end

local defaults = {}
for name, act in Config.Actions do
	defaults[name] = act.HitboxSize
end
local defRange = Config.Validation and Config.Validation.MaximumRequestDistance or 15

-- hitbox state
getgenv().HBOn = false
getgenv().HBW = getgenv().HBW or 15
getgenv().HBV = getgenv().HBV or 10
getgenv().HBRange = getgenv().HBRange or 30
getgenv().LTReachOn = false
getgenv().LTW = getgenv().LTW or 24
getgenv().LTV = getgenv().LTV or 12
getgenv().GKW = getgenv().GKW or 14
getgenv().GKV = getgenv().GKV or 9
getgenv().GKD = getgenv().GKD or 6

local function kickBase()
	return getgenv().HBOn and Vector3.new(getgenv().HBW, getgenv().HBV, getgenv().HBW) or defaults.Kick
end

	local function applyKick()
	pcall(function()
		Config.Actions.Kick.HitboxSize = kickBase()
		Config.Validation.MaximumRequestDistance = getgenv().HBOn and getgenv().HBRange or defRange
	end)
end

local function boostKick(size, dur)
	pcall(function()
		Config.Actions.Kick.HitboxSize = size
	end)
	if dur then
		task.delay(dur, function()
			if not getgenv().LTReachOn then
				pcall(function() Config.Actions.Kick.HitboxSize = kickBase() end)
			end
		end)
	end
end

local function applyGK(on)
	pcall(function()
		Config.Actions.GK.HitboxSize = on and Vector3.new(getgenv().GKW, getgenv().GKV, getgenv().GKD) or defaults.GK
		if Config.Actions.GK.DashHitboxSize then
			Config.Actions.GK.DashHitboxSize = on and Vector3.new(getgenv().GKW, getgenv().GKV, getgenv().GKD) or Config.Actions.GK.DashHitboxSize
		end
	end)
end

-- categories
local FootballCat = vape:CreateCategory({
	Name = "Football",
	Icon = getvapeasset("newvape/assets/new/combat.png"),
	Size = UDim2.fromOffset(13, 14),
})
local ClosetCat = vape:CreateCategory({
	Name = "Closet",
	Icon = getvapeasset("newvape/assets/new/blatant.png"),
	Size = UDim2.fromOffset(14, 14),
})
local GKCat = vape:CreateCategory({
	Name = "Goalkeeping",
	Icon = getvapeasset("newvape/assets/new/render.png"),
	Size = UDim2.fromOffset(15, 14),
})

local oursOrder = { Football = 1, Closet = 2, Goalkeeping = 3 }
for name, order in oursOrder do
	local entry = vape.Categories.Main.Buttons[name]
	if entry and entry.Object then
		entry.Object.LayoutOrder = order
	end
end
local backOrder = 10
for name, entry in vape.Categories.Main.Buttons do
	if not oursOrder[name] and entry.Object then
		entry.Object.LayoutOrder = backOrder
		backOrder += 1
	end
end

-- hitbox module
local HBShow
local ad = Instance.new("BoxHandleAdornment")
ad.Color3 = Color3.fromRGB(0, 255, 200)
ad.Transparency = 0.55
ad.AlwaysOnTop = true
ad.ZIndex = 5
ad.Visible = false
ad.Parent = vape.gui

RunService.RenderStepped:Connect(function()
	local hrp = getHRP()
	if hrp and getgenv().HBShow and getgenv().HBOn then
		ad.Adornee = hrp
		ad.Size = Vector3.new(getgenv().HBW, getgenv().HBV, getgenv().HBW)
		ad.Visible = ad.Size.X > hrp.Size.X + 1
	else
		ad.Visible = false
	end
end)

local HBMod
HBMod = FootballCat:CreateModule({
	Name = "Hitbox Expander",
	Function = function(cb)
		getgenv().HBOn = cb
		applyKick()
		if not cb then
			pcall(function() Config.Validation.MaximumRequestDistance = defRange end)
		end
	end,
	Tooltip = "Bigger kick/shoot contact range",
})
HBMod:CreateSlider({
	Name = "Horizontal",
	Min = 2,
	Max = 60,
	Default = getgenv().HBW,
	Decimal = 10,
	Suffix = "st",
	Function = function(v)
		getgenv().HBW = v
		if HBMod.Enabled then applyKick() end
	end,
})
HBMod:CreateSlider({
	Name = "Vertical",
	Min = 1,
	Max = 40,
	Default = getgenv().HBV,
	Decimal = 10,
	Suffix = "st",
	Function = function(v)
		getgenv().HBV = v
		if HBMod.Enabled then applyKick() end
	end,
})
HBMod:CreateSlider({
	Name = "Max request range",
	Min = 10,
	Max = 100,
	Default = getgenv().HBRange,
	Decimal = 10,
	Suffix = "st",
	Function = function(v)
		getgenv().HBRange = v
		if HBMod.Enabled then applyKick() end
	end,
})
HBMod:CreateToggle({
	Name = "Show hitbox",
	Default = true,
	Function = function(v)
		getgenv().HBShow = v
	end,
})

-- lag tackle
local LTMode, LTChance, LTSize, LTVol
local LTRng = Random.new()
local lagSwitch
lagSwitch = function()
	local hrp = getHRP()
	if not hrp then return end
	local old = hrp.CFrame
	local a = LTRng:NextNumber(0, math.pi * 2)
	local mag = LTRng:NextNumber(1, 2.2)
	hrp.CFrame = old + Vector3.new(math.cos(a) * mag, 0, math.sin(a) * mag)
	task.wait(LTRng:NextNumber(0.04, 0.09))
	if getgenv().LTReachOn and getHRP() == hrp then
		hrp.CFrame = old
	end
end

local LTMod
LTMod = ClosetCat:CreateModule({
	Name = "Lag Tackle",
	Function = function(cb)
		getgenv().LTReachOn = cb
		if not cb then return end
		task.spawn(function()
			local mode = LTMode.Value
			if mode == "Reach" then
				if LTRng:NextInteger(1, 100) <= LTChance.Value then
					boostKick(Vector3.new(LTSize.Value, LTVol.Value, LTSize.Value), 0.15)
					task.wait(0.3)
				end
				applyKick()
			else
				for i = 1, LTRng:NextInteger(2, 4) do
					if not getgenv().LTReachOn then break end
					lagSwitch()
					task.wait(LTRng:NextNumber(0.2, 0.5))
				end
				if getgenv().LTReachOn then
					boostKick(Vector3.new(LTSize.Value, LTVol.Value, LTSize.Value), 0.5)
					task.wait(0.8)
				end
				applyKick()
			end
			if LTMod.Enabled then
				LTMod:Toggle()
			end
		end)
	end,
	Tooltip = "One-shot: infinite reach for a second, then back off",
})
LTMode = LTMod:CreateDropdown({
	Name = "Mode",
	List = { "Reach", "Lag switch" },
	Function = function(val) end,
	Tooltip = "Reach - random instant boosts\nLag switch - constant reach + rubberbanding",
})
LTChance = LTMod:CreateSlider({
	Name = "Boost chance",
	Min = 0,
	Max = 100,
	Default = 35,
	Suffix = "%",
	Function = function(v) end,
})
LTSize = LTMod:CreateSlider({
	Name = "Boost width",
	Min = 2,
	Max = 40,
	Default = getgenv().LTW,
	Decimal = 10,
	Suffix = "st",
	Function = function(v)
		getgenv().LTW = v
	end,
})
LTVol = LTMod:CreateSlider({
	Name = "Boost height",
	Min = 2,
	Max = 24,
	Default = getgenv().LTV,
	Decimal = 10,
	Suffix = "st",
	Function = function(v)
		getgenv().LTV = v
	end,
})

-- power feint
local function powerName()
	return (require(Football.Shared.ActionTypes).PowerShoot) or "PowerShoot"
end

local PFMod
local pfOld, pfOldNC, pfConsumed
PFMod = ClosetCat:CreateModule({
	Name = "Power Feint",
	Function = function(cb)
		local remote = Football.Remotes.RequestBallAction
		local consume = function(tbl)
			return type(tbl) == "table" and (tbl.actionType == powerName() or tbl.actionType == "Power Shoot")
		end
		local restore = function()
			if pfOld then
				pcall(function() hookfunction(remote.FireServer, pfOld) end)
				pfOld = nil
			end
			if pfOldNC then
				pcall(function() hookfunction(getrawmetatable(game).__namecall, pfOldNC) end)
				pfOldNC = nil
			end
		end
		if cb then
			pfConsumed = false
			pfOld, pfOldNC = nil, nil
			pcall(function()
				local old
				old = hookfunction(remote.FireServer, function(self, tbl, ...)
					if consume(tbl) then
						pfConsumed = true
						return
					end
					return old(self, tbl, ...)
				end)
				pfOld = old
			end)
			if not pfOld then
				pcall(function()
					local oldnc
					oldnc = hookmetamethod(game, "__namecall", function(self, ...)
						if self == remote and getnamecallmethod() == "FireServer" and consume((...)) then
							pfConsumed = true
							return
						end
						return oldnc(self, ...)
					end)
					pfOldNC = oldnc
				end)
			end
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 1.5 and PFMod.Enabled and not pfConsumed do
					task.wait(0.1)
				end
				if pfConsumed then
					task.wait(0.4)
				end
				if PFMod.Enabled then
					PFMod:Toggle()
				end
			end)
		else
			restore()
		end
	end,
	Tooltip = "One-shot: next power shot is animation-only, auto-disables",
})

-- auto poke
local APRange
local APMod
APMod = ClosetCat:CreateModule({
	Name = "Auto Poke",
	Function = function(cb)
		if not cb then return end
		APMod:Clean(function() end)
		task.spawn(function()
			local attempts = 0
			local lastHolder = nil
			while APMod.Enabled do
				local ball = getBall()
				local hrp = getHRP()
				if ball and hrp then
					local holder, hd = nil, math.huge
					for _, p in Players:GetPlayers() do
						if p ~= plr then
							local h = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
							if h and ball.AssemblyLinearVelocity.Magnitude < 10 then
								local d = (h.Position - ball.Position).Magnitude
								if d < 4.5 and d < hd then
									holder, hd = p, d
								end
							end
						end
					end
					if holder ~= lastHolder then
						attempts = 0
						lastHolder = holder
					end
					local bd = (hrp.Position - ball.Position).Magnitude
					if holder and bd <= APRange.Value and (not holder or true) and attempts < 2 then
						Client.Request({ actionType = "Kick", power = 100, isLow = false, curveAxis = 0 }, function()
							return { power = 100, isLow = false, curveAxis = 0 }
						end)
						attempts += 1
						task.wait(0.8)
					end
					if holder and holder.Character and holder.Character ~= plr.Character and bd > APRange.Value then
						task.wait(0.2)
					end
				end
				task.wait(0.1)
			end
		end)
	end,
	Tooltip = "Auto tackles the ball off the nearest holder, 2 tries max",
})
APRange = APMod:CreateSlider({
	Name = "Poke reach",
	Min = 2,
	Max = 25,
	Default = 10,
	Decimal = 10,
	Suffix = "st",
	Function = function(v) end,
})

-- ball esp
local BEColors = { Friends = Color3.fromRGB(90, 255, 120), Others = Color3.fromRGB(255, 90, 90) }
local BEMod
BEMod = ClosetCat:CreateModule({
	Name = "Ball ESP",
	Function = function(cb)
		local bb, hl, attach
		if cb then
			bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(90, 28)
			bb.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
			bb.AlwaysOnTop = true
			bb.MaxDistance = 400
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold)
			t.TextSize = 14
			t.TextColor3 = Color3.new(1, 1, 1)
			t.TextStrokeTransparency = 0.2
			t.Text = "BALL"
			t.Parent = bb
			bb.Enabled = true
			hl = Instance.new("Highlight")
			hl.FillTransparency = 1
			hl.OutlineColor = Color3.fromRGB(255, 255, 0)
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Enabled = true
			local last
			BEMod:Clean(RunService.RenderStepped:Connect(function()
				local ball = getBall()
				local hrp = getHRP()
				if not ball then
					return
				end
				if ball ~= last then
					bb.Adornee = ball
					hl.Adornee = ball
					last = ball
				end
				if hrp then
					t.Text = ("BALL %d"):format(math.round((hrp.Position - ball.Position).Magnitude))
				end
				hl.Enabled = true
			end))
			bb.Parent = vape.gui
			hl.Parent = vape.gui
		end
	end,
	Tooltip = "Name + distance tag and outline on the ball",
})

-- gk reach
local GKRRange
local gkvizes = {}
local GKRMod
GKRMod = GKCat:CreateModule({
	Name = "GK Reach",
	Function = function(cb)
		if not cb then
			for _, v in gkvizes do
				v:Destroy()
			end
			table.clear(gkvizes)
			return
		end
		GKRMod:Clean(RunService.RenderStepped:Connect(function()
			local seen = {}
			for _, p in Players:GetPlayers() do
				local tool = p.Character and p.Character:FindFirstChildOfClass("Tool")
				if tool and tool.Name == "GK" then
					local h = p.Character:FindFirstChild("HumanoidRootPart")
					if h then
						seen[p] = true
						local viz = gkvizes[p]
						if not viz then
							viz = Instance.new("Part")
							viz.Shape = Enum.PartType.Cylinder
							viz.Size = Vector3.new(0.4, 2, 2)
							viz.CanCollide = false
							viz.Anchored = true
							viz.CanQuery = false
							viz.Material = Enum.Material.Neon
							viz.Parent = vape.gui
							gkvizes[p] = viz
						end
						viz.Color = p.Team == plr.Team and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 70, 70)
						viz.Size = Vector3.new(0.4, GKRRange.Value * 2, GKRRange.Value * 2)
						viz.CFrame = CFrame.new(h.Position.X, h.Position.Y - 2.2, h.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
					end
				end
			end
			for p, viz in gkvizes do
				if not seen[p] then
					viz:Destroy()
					gkvizes[p] = nil
				end
			end
		end))
	end,
	Tooltip = "Ring under every keeper showing how far they can currently reach",
})
GKRRange = GKRMod:CreateSlider({
	Name = "Reach radius",
	Min = 4,
	Max = 60,
	Default = 18,
	Decimal = 10,
	Suffix = "st",
	Function = function(v) end,
})

-- ball trajectory
local TRMod
TRMod = GKCat:CreateModule({
	Name = "Ball Trajectory",
	Function = function(cb)
		if not cb then return end
		local dots, n = {}, 20
		for i = 1, n do
			local dot = Instance.new("Part")
			dot.Shape = Enum.PartType.Ball
			dot.Size = Vector3.new(0.6, 0.6, 0.6)
			dot.Anchored = true
			dot.CanCollide = false
			dot.CanQuery = false
			dot.Material = Enum.Material.Neon
			dot.Color = Color3.fromRGB(0, 255, 200)
			dot.Transparency = 0.2 + (i / n) * 0.6
			dot.Parent = vape.gui
			dots[i] = dot
		end
		local marker = Instance.new("Part")
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(2.4, 2.4, 2.4)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.Material = Enum.Material.Neon
		marker.Color = Color3.fromRGB(255, 255, 0)
		marker.Transparency = 0.45
		marker.Parent = vape.gui
		TRMod:Clean(function()
			for _, d in dots do d:Destroy() end
			marker:Destroy()
		end)
		TRMod:Clean(RunService.Heartbeat:Connect(function()
			local ball = getBall()
			if not ball or ball.AssemblyLinearVelocity.Magnitude < 6 then
				for _, d in dots do d.Transparency = 1 end
				marker.Transparency = 1
				return
			end
			local p, v = ball.Position, ball.AssemblyLinearVelocity
			local g = workspace.Gravity
			local dt = 0.05
			local pos = {}
			local land = nil
			for i = 1, 48 do
				p += v * dt
				v -= Vector3.new(0, g, 0) * dt
				if p.Y <= 1 then
					land = p
					break
				end
				if i <= n then
					pos[i] = p
				end
			end
			for i, d in dots do
				if pos[i] then
					d.Position = pos[i]
					d.Transparency = 0.2 + (i / n) * 0.6
				else
					d.Transparency = 1
				end
			end
			if land then
				marker.Position = land
				marker.Transparency = 0.45
			else
				marker.Transparency = 1
			end
		end))
	end,
	Tooltip = "Predicted ball path + landing marker for keeper positioning",
})

-- gk expander
local GKMod
GKMod = GKCat:CreateModule({
	Name = "GK Expander",
	Function = function(cb)
		applyGK(cb)
	end,
	Tooltip = "Wider keeper hitbox, tuned for saves not dives",
})
GKMod:CreateSlider({
	Name = "Width",
	Min = 2,
	Max = 30,
	Default = getgenv().GKW,
	Decimal = 10,
	Suffix = "st",
	Function = function(v)
		getgenv().GKW = v
		if GKMod.Enabled then applyGK(true) end
	end,
})
GKMod:CreateSlider({
	Name = "Height",
	Min = 2,
	Max = 24,
	Default = getgenv().GKV,
	Decimal = 10,
	Suffix = "st",
	Function = function(v)
		getgenv().GKV = v
		if GKMod.Enabled then applyGK(true) end
	end,
})
GKMod:CreateSlider({
	Name = "Depth",
	Min = 2,
	Max = 12,
	Default = getgenv().GKD,
	Decimal = 10,
	Suffix = "st",
	Function = function(v)
		getgenv().GKD = v
		if GKMod.Enabled then applyGK(true) end
	end,
})


UIS.InputBegan:Connect(function(input, over)
	if over then return end
	if input.KeyCode == Enum.KeyCode.K and vape.GUIBind then
		vape.GUIBind.Triggered:Fire(true)
	end
end)

vape:Load()

task.spawn(function()
	repeat
		pcall(function() vape:Save() end)
		task.wait(15)
	until not vape.Loaded
end)

vape:CreateNotification("sctx", "Press K to open the menu", 5)
