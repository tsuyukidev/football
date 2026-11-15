--[[
    sctx hub | orion ui
    press K to open the menu
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local plr = Players.LocalPlayer
local Football = game:GetService("ReplicatedStorage"):WaitForChild("Football")
local Config = require(Football.Shared.Config)
pcall(function() if setreadonly then setreadonly(Config, false) end end)
local Client = require(Football.Client.BallActionClient)
local TAC = require(Football.Client.ToolAnimationController)

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/jensonhirst/Orion/main/source"))()

local ballName = Config.BallName
local function getBall()
	return workspace:FindFirstChild(ballName)
end

local function getHRP()
	local c = plr.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- world fx container
local uiOwner = gethui and gethui() or game:GetService("CoreGui")
local stale = uiOwner:FindFirstChild("sctx")
if stale then
	stale:Destroy()
end
local world = Instance.new("ScreenGui")
world.Name = "sctx"
world.ResetOnSpawn = false
world.IgnoreGuiInset = true
pcall(function()
	world.Parent = uiOwner
end)
if not world.Parent then
	world.Parent = plr:WaitForChild("PlayerGui")
end

local clean = {}
local function unbind(k)
	local fn = clean[k]
	if fn then
		clean[k] = nil
		pcall(fn)
	end
end
local function bind(k, fn)
	unbind(k)
	clean[k] = fn
end

local defaults = {}
for name, act in Config.Actions do
	defaults[name] = act.HitboxSize
end
local defRange = Config.Validation and Config.Validation.MaximumRequestDistance or 15
local gkDashDefault = Config.Actions.GK.DashHitboxSize

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
		local size = on and Vector3.new(getgenv().GKW, getgenv().GKV, getgenv().GKD) or nil
		Config.Actions.GK.HitboxSize = size or defaults.GK
		if gkDashDefault ~= nil then
			Config.Actions.GK.DashHitboxSize = size or gkDashDefault
		end
	end)
end

local Window = OrionLib:MakeWindow({
	Name = "sctx",
	HidePremium = true,
	SaveConfig = true,
	ConfigFolder = "sctx",
	IntroEnabled = false,
	IntroText = "sctx",
})

local FootballTab = Window:MakeTab({ Name = "Football" })
local ClosetTab = Window:MakeTab({ Name = "Closet" })
local GKTab = Window:MakeTab({ Name = "Goalkeeping" })

-- hitbox module
local ad = Instance.new("BoxHandleAdornment")
ad.Color3 = Color3.fromRGB(0, 255, 200)
ad.Transparency = 0.55
ad.AlwaysOnTop = true
ad.ZIndex = 5
ad.Visible = false
ad.Parent = world

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

local hbOn = false
local hbSec = FootballTab:AddSection({ Name = "Hitbox" })
hbSec:AddToggle({
	Name = "Hitbox Expander",
	Default = false,
	Flag = "hb",
	Save = true,
	Callback = function(cb)
		hbOn = cb
		getgenv().HBOn = cb
		applyKick()
		if not cb then
			pcall(function() Config.Validation.MaximumRequestDistance = defRange end)
		end
	end,
})
hbSec:AddSlider({
	Name = "Horizontal",
	Min = 2,
	Max = 60,
	Default = getgenv().HBW,
	Increment = 0.5,
	ValueName = "st",
	Flag = "hbw",
	Save = true,
	Callback = function(v)
		getgenv().HBW = v
		if hbOn then applyKick() end
	end,
})
hbSec:AddSlider({
	Name = "Vertical",
	Min = 1,
	Max = 40,
	Default = getgenv().HBV,
	Increment = 0.5,
	ValueName = "st",
	Flag = "hbv",
	Save = true,
	Callback = function(v)
		getgenv().HBV = v
		if hbOn then applyKick() end
	end,
})
hbSec:AddSlider({
	Name = "Max request range",
	Min = 10,
	Max = 100,
	Default = getgenv().HBRange,
	Increment = 1,
	ValueName = "st",
	Flag = "hbr",
	Save = true,
	Callback = function(v)
		getgenv().HBRange = v
		if hbOn then applyKick() end
	end,
})
hbSec:AddToggle({
	Name = "Show hitbox",
	Default = true,
	Flag = "hbshow",
	Save = true,
	Callback = function(v)
		getgenv().HBShow = v
	end,
})

-- lag tackle
local LTMode, LTChance, LTSize, LTVol
local ltOn, ltMode, ltChance, ltSize, ltVol = false, "Reach", 35, getgenv().LTW, getgenv().LTV
local LTToggle
local LTRng = Random.new()
local function lagSwitch()
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

local ltSec = ClosetTab:AddSection({ Name = "Lag Tackle" })
LTToggle = ltSec:AddToggle({
	Name = "Lag Tackle",
	Default = false,
	Flag = "lt",
	Save = true,
	Callback = function(cb)
		ltOn = cb
		getgenv().LTReachOn = cb
		if not cb then return end
		task.spawn(function()
			if ltMode == "Reach" then
				if LTRng:NextInteger(1, 100) <= ltChance then
					boostKick(Vector3.new(ltSize, ltVol, ltSize), 0.15)
					task.wait(0.3)
				end
				applyKick()
			else
				for i = 1, LTRng:NextInteger(2, 4) do
					if not ltOn then break end
					lagSwitch()
					task.wait(LTRng:NextNumber(0.2, 0.5))
				end
				if ltOn then
					boostKick(Vector3.new(ltSize, ltVol, ltSize), 0.5)
					task.wait(0.8)
				end
				applyKick()
			end
			if ltOn then
				LTToggle:Set(false)
			end
		end)
	end,
})
LTMode = ltSec:AddDropdown({
	Name = "Mode",
	Default = "Reach",
	Options = { "Reach", "Lag switch" },
	Flag = "ltmode",
	Save = true,
	Callback = function(val)
		ltMode = val
	end,
})
LTChance = ltSec:AddSlider({
	Name = "Boost chance",
	Min = 0,
	Max = 100,
	Default = 35,
	Increment = 1,
	ValueName = "%",
	Flag = "ltchance",
	Save = true,
	Callback = function(v)
		ltChance = v
	end,
})
LTSize = ltSec:AddSlider({
	Name = "Boost width",
	Min = 2,
	Max = 40,
	Default = getgenv().LTW,
	Increment = 0.5,
	ValueName = "st",
	Flag = "ltw",
	Save = true,
	Callback = function(v)
		ltSize = v
		getgenv().LTW = v
	end,
})
LTVol = ltSec:AddSlider({
	Name = "Boost height",
	Min = 2,
	Max = 24,
	Default = getgenv().LTV,
	Increment = 0.5,
	ValueName = "st",
	Flag = "ltv",
	Save = true,
	Callback = function(v)
		ltVol = v
		getgenv().LTV = v
	end,
})

-- power feint
local function powerName()
	return (require(Football.Shared.ActionTypes).PowerShoot) or "PowerShoot"
end

local pfOn = false
local PFToggle
local pfOld, pfOldNC, pfConsumed
local pfSec = ClosetTab:AddSection({ Name = "Power Feint" })
PFToggle = pfSec:AddToggle({
	Name = "Power Feint",
	Default = false,
	Callback = function(cb)
		pfOn = cb
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
				while os.clock() - t0 < 1.5 and pfOn and not pfConsumed do
					task.wait(0.1)
				end
				if pfConsumed then
					task.wait(0.4)
				end
				if pfOn then
					PFToggle:Set(false)
				end
			end)
		else
			restore()
		end
	end,
})

-- auto poke
local apOn = false
local apRange = 10
local apSec = ClosetTab:AddSection({ Name = "Auto Poke" })
apSec:AddToggle({
	Name = "Auto Poke",
	Default = false,
	Flag = "ap",
	Save = true,
	Callback = function(cb)
		apOn = cb
		if not cb then return end
		task.spawn(function()
			local attempts = 0
			local lastHolder = nil
			while apOn do
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
					if holder and bd <= apRange and attempts < 2 then
						Client.Request({ actionType = "Kick", power = 100, isLow = false, curveAxis = 0 }, function()
							return { power = 100, isLow = false, curveAxis = 0 }
						end)
						attempts += 1
						task.wait(0.8)
					end
					if holder and holder.Character and holder.Character ~= plr.Character and bd > apRange then
						task.wait(0.2)
					end
				end
				task.wait(0.1)
			end
		end)
	end,
})
apSec:AddSlider({
	Name = "Poke reach",
	Min = 2,
	Max = 25,
	Default = 10,
	Increment = 0.5,
	ValueName = "st",
	Flag = "apr",
	Save = true,
	Callback = function(v)
		apRange = v
	end,
})

-- ball esp
local beSec = ClosetTab:AddSection({ Name = "Ball ESP" })
beSec:AddToggle({
	Name = "Ball ESP",
	Default = false,
	Flag = "be",
	Save = true,
	Callback = function(cb)
		unbind("esp")
		if not cb then return end
		local bb = Instance.new("BillboardGui")
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
		bb.Parent = world
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.OutlineColor = Color3.fromRGB(255, 255, 0)
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Enabled = true
		hl.Parent = world
		local last
		local conn = RunService.RenderStepped:Connect(function()
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
		end)
		bind("esp", function()
			conn:Disconnect()
			bb:Destroy()
			hl:Destroy()
		end)
	end,
})

-- gk reach
local gkrRange = 18
local gkvizes = {}
local gkSec = GKTab:AddSection({ Name = "Keeper Info" })
gkSec:AddToggle({
	Name = "GK Reach",
	Default = false,
	Flag = "gkr",
	Save = true,
	Callback = function(cb)
		unbind("gkr")
		if not cb then
			for _, v in gkvizes do
				v:Destroy()
			end
			table.clear(gkvizes)
			return
		end
		local conn = RunService.RenderStepped:Connect(function()
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
							viz.Parent = world
							gkvizes[p] = viz
						end
						viz.Color = p.Team == plr.Team and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 70, 70)
						viz.Size = Vector3.new(0.4, gkrRange * 2, gkrRange * 2)
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
		end)
		bind("gkr", function()
			conn:Disconnect()
			for _, v in gkvizes do
				v:Destroy()
			end
			table.clear(gkvizes)
		end)
	end,
})
gkSec:AddSlider({
	Name = "Reach radius",
	Min = 4,
	Max = 60,
	Default = 18,
	Increment = 0.5,
	ValueName = "st",
	Flag = "gkrr",
	Save = true,
	Callback = function(v)
		gkrRange = v
	end,
})

-- ball trajectory
gkSec:AddToggle({
	Name = "Ball Trajectory",
	Default = false,
	Flag = "tr",
	Save = true,
	Callback = function(cb)
		unbind("tr")
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
			dot.Parent = world
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
		marker.Parent = world
		local conn = RunService.Heartbeat:Connect(function()
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
		end)
		bind("tr", function()
			conn:Disconnect()
			for _, d in dots do d:Destroy() end
			marker:Destroy()
		end)
	end,
})

-- gk expander
local gkOn = false
local gkModSec = GKTab:AddSection({ Name = "GK Expander" })
gkModSec:AddToggle({
	Name = "GK Expander",
	Default = false,
	Flag = "gkx",
	Save = true,
	Callback = function(cb)
		gkOn = cb
		applyGK(cb)
	end,
})
gkModSec:AddSlider({
	Name = "Width",
	Min = 2,
	Max = 30,
	Default = getgenv().GKW,
	Increment = 0.5,
	ValueName = "st",
	Flag = "gkw",
	Save = true,
	Callback = function(v)
		getgenv().GKW = v
		if gkOn then applyGK(true) end
	end,
})
gkModSec:AddSlider({
	Name = "Height",
	Min = 2,
	Max = 24,
	Default = getgenv().GKV,
	Increment = 0.5,
	ValueName = "st",
	Flag = "gkh",
	Save = true,
	Callback = function(v)
		getgenv().GKV = v
		if gkOn then applyGK(true) end
	end,
})
gkModSec:AddSlider({
	Name = "Depth",
	Min = 2,
	Max = 12,
	Default = getgenv().GKD,
	Increment = 0.5,
	ValueName = "st",
	Flag = "gkd",
	Save = true,
	Callback = function(v)
		getgenv().GKD = v
		if gkOn then applyGK(true) end
	end,
})

OrionLib:Init()

local function mainFrame()
	local gui = uiOwner:FindFirstChild("Orion")
	if not gui then return end
	for _, f in gui:GetChildren() do
		if f:IsA("Frame") and f:FindFirstChild("TopBar") then
			return f
		end
	end
end

local ui = mainFrame()
UIS.InputBegan:Connect(function(input, over)
	if over then return end
	if input.KeyCode == Enum.KeyCode.K and ui then
		ui.Visible = not ui.Visible
	end
end)

OrionLib:MakeNotification({ Name = "sctx", Content = "Press K to open the menu", Time = 5 })
