-- Abilities (ModuleScript in ServerScriptService)
-- What each power Kind actually does, plus its visual effects.
-- CombatService calls Abilities.Run with a "ctx" table:
--   ctx.Combat     CombatService (for damage, knockback, slows...)
--   ctx.Player, ctx.Character, ctx.Root, ctx.Humanoid   the attacker
--   ctx.Power      the power's config, ctx.Damage the final damage
--   ctx.Direction  unit vector toward the aim, ctx.Target the aim point (inside Range)

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Abilities = {}
local Kinds = {}

local MAP_FOLDER = "StealAPowerMap"

local effects = workspace:FindFirstChild("Effects")
if not effects then
	effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = workspace
end

-- Visual helpers ------------------------------------------------------------------

local function effectPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in props do
		part[key] = value
	end
	part.Parent = effects
	return part
end

local function fadeOut(part, duration, goalSize)
	local goal = { Transparency = 1 }
	if goalSize then
		goal.Size = goalSize
	end
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(part, duration + 0.1)
end

-- An expanding glowing ball.
function Abilities.Burst(position, radius, color, duration)
	local ball = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one,
		CFrame = CFrame.new(position),
		Color = color,
		Transparency = 0.2,
	})
	fadeOut(ball, duration or 0.4, Vector3.one * radius * 2)
end

-- A flat circle on the ground that warns players where something will hit.
local function telegraph(position, radius, color, duration)
	local circle = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.55,
	})
	Debris:AddItem(circle, duration)
end

local function beam(from, to, color, width)
	local length = (to - from).Magnitude
	local part = effectPart({
		Size = Vector3.new(width, width, length),
		CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
		Color = color,
	})
	fadeOut(part, 0.35)
end

-- A zig-zag bolt from the sky down to `to`.
local function lightningBolt(to, color)
	local from = to + Vector3.new(0, 80, 0)
	local previous = from
	local segments = 7
	for i = 1, segments do
		local point = if i == segments
			then to
			else from:Lerp(to, i / segments) + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
		beam(previous, point, color, 0.7)
		previous = point
	end
end

-- Finds the ground under a point, so strikes land on the floor and not on heads.
local function findGround(position)
	local map = workspace:FindFirstChild(MAP_FOLDER)
	local params = RaycastParams.new()
	if map then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { map }
	else
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { effects }
	end
	local result = workspace:Raycast(position + Vector3.new(0, 40, 0), Vector3.new(0, -250, 0), params)
	return if result then result.Position else position
end

-- Power kinds -------------------------------------------------------------------

-- Hit the closest enemy in front of you.
function Kinds.Melee(ctx)
	local power = ctx.Power
	local forward = Vector3.new(ctx.Direction.X, 0, ctx.Direction.Z)
	forward = if forward.Magnitude > 0.01 then forward.Unit else ctx.Root.CFrame.LookVector

	local best, bestDistance = nil, math.huge
	for _, target in ctx.Combat.GetTargets(ctx.Character) do
		local offset = target.Root.Position - ctx.Root.Position
		local distance = offset.Magnitude
		if distance <= power.Range and distance < bestDistance and distance > 0 and offset.Unit:Dot(forward) > 0.2 then
			best, bestDistance = target, distance
		end
	end

	Abilities.Burst(ctx.Root.Position + forward * 3, 1.5, power.Color, 0.15)
	if best then
		ctx.Combat.DealDamage(ctx.Player, best.Humanoid, ctx.Damage)
		ctx.Combat.Knockback(best.Root, forward * power.Knockback + Vector3.new(0, 12, 0), 0.15)
	end
end

-- Shoot a ball that flies in a straight line. Moved by the server every frame,
-- using a spherecast so fast balls never pass through someone.
function Kinds.Projectile(ctx)
	local power = ctx.Power
	local origin = ctx.Root.Position + ctx.Direction * 3
	local toTarget = ctx.Target - origin
	local direction = if toTarget.Magnitude > 0.1 then toTarget.Unit else ctx.Direction

	local ball = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * power.Size,
		CFrame = CFrame.new(origin),
		Color = power.Color,
	})
	local light = Instance.new("PointLight")
	light.Color = power.Color
	light.Range = 10
	light.Brightness = 2
	light.Parent = ball
	if power.Burn then
		local fire = Instance.new("Fire")
		fire.Size = power.Size * 2
		fire.Heat = 0
		fire.Parent = ball
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.Character, effects }

	local position, traveled = origin, 0
	local connection

	local function finish(hitPosition, hitPart)
		connection:Disconnect()
		ball:Destroy()
		Abilities.Burst(hitPosition, power.Size * 2, power.Color, 0.3)
		if not hitPart then
			return
		end
		local model = hitPart:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			ctx.Combat.DealDamage(ctx.Player, humanoid, ctx.Damage)
			if power.Burn then
				ctx.Combat.Burn(ctx.Player, humanoid, power.Burn.Damage, power.Burn.Ticks)
			end
			if power.Slow then
				ctx.Combat.SetMovement(humanoid, 1 - power.Slow.Amount, power.Slow.Duration)
			end
		end
	end

	connection = RunService.Heartbeat:Connect(function(dt)
		local step = math.min(power.Speed * dt, power.Range - traveled)
		local result = workspace:Spherecast(position, power.Size / 2, direction * step, params)
		if result then
			finish(result.Position, result.Instance)
			return
		end
		position += direction * step
		traveled += step
		ball.CFrame = CFrame.new(position)
		if traveled >= power.Range then
			finish(position, nil)
		end
	end)
end

-- Blast everyone around you away.
function Kinds.Push(ctx)
	local power = ctx.Power
	local center = ctx.Root.Position
	Abilities.Burst(center, power.Radius, power.Color, 0.35)
	for _, target in ctx.Combat.GetTargetsInRadius(center, power.Radius, ctx.Character) do
		local away = target.Root.Position - center
		away = Vector3.new(away.X, 0, away.Z)
		away = if away.Magnitude > 0.01 then away.Unit else ctx.Root.CFrame.LookVector
		ctx.Combat.DealDamage(ctx.Player, target.Humanoid, ctx.Damage)
		ctx.Combat.Knockback(target.Root, away * power.Force + Vector3.new(0, power.Force * 0.4, 0), 0.25)
	end
end

-- Warn with a circle, wait Delay seconds, then hit everyone inside it.
local function strikeAt(ctx, position)
	local power = ctx.Power
	local ground = findGround(position)
	telegraph(ground, power.Radius, power.Color, power.Delay)

	if power.Visual == "Meteor" then
		local rock = effectPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * power.Radius * 0.6,
			CFrame = CFrame.new(ground + Vector3.new(40, 90, 20)),
			Color = power.Color,
		})
		local fire = Instance.new("Fire")
		fire.Size = power.Radius
		fire.Parent = rock
		TweenService:Create(rock, TweenInfo.new(power.Delay, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(ground),
		}):Play()
		Debris:AddItem(rock, power.Delay)
	end

	task.delay(power.Delay, function()
		if power.Visual == "Lightning" then
			lightningBolt(ground, power.Color)
		end
		Abilities.Burst(ground, power.Radius, power.Color, 0.4)
		-- Measure from a little above the ground, about where a character's middle is.
		local center = ground + Vector3.new(0, 3, 0)
		for _, target in ctx.Combat.GetTargetsInRadius(center, power.Radius, ctx.Character) do
			ctx.Combat.DealDamage(ctx.Player, target.Humanoid, ctx.Damage)
		end
	end)
end

function Kinds.Strike(ctx)
	strikeAt(ctx, ctx.Target)
end

-- Many small strikes spread around the aim point.
function Kinds.Storm(ctx)
	local power = ctx.Power
	for i = 1, power.Strikes do
		local angle = math.random() * math.pi * 2
		local distance = math.random() * power.Spread
		local point = ctx.Target + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		task.delay((i - 1) * 0.25, strikeAt, ctx, point)
	end
end

-- Suck enemies toward a point. Damage is split over the pulses.
function Kinds.Pull(ctx)
	local power = ctx.Power
	local center = findGround(ctx.Target) + Vector3.new(0, 4, 0)
	local pulses = power.Pulses
	local damagePerPulse = math.ceil(ctx.Damage / pulses)

	telegraph(center - Vector3.new(0, 4, 0), power.Radius, power.Color, pulses * 0.45)
	local core = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 4,
		CFrame = CFrame.new(center),
		Color = power.Color,
	})
	TweenService:Create(core, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = Vector3.one * 6,
	}):Play()

	task.spawn(function()
		for _ = 1, pulses do
			for _, target in ctx.Combat.GetTargetsInRadius(center, power.Radius, ctx.Character) do
				local inward = center - target.Root.Position
				if inward.Magnitude > 3 then
					ctx.Combat.Knockback(target.Root, inward.Unit * power.Force, 0.3)
				end
				ctx.Combat.DealDamage(ctx.Player, target.Humanoid, damagePerPulse)
			end
			Abilities.Burst(center, power.Radius * 0.3, power.Color, 0.3)
			task.wait(0.45)
		end
		fadeOut(core, 0.3)
	end)
end

-- Freeze everyone around you.
function Kinds.Freeze(ctx)
	local power = ctx.Power
	local center = ctx.Root.Position
	Abilities.Burst(center, power.Radius, power.Color, 0.6)
	for _, target in ctx.Combat.GetTargetsInRadius(center, power.Radius, ctx.Character) do
		ctx.Combat.DealDamage(ctx.Player, target.Humanoid, ctx.Damage)
		ctx.Combat.SetMovement(target.Humanoid, 0, power.Duration)
	end
end

function Abilities.Run(kind, ctx)
	local ability = Kinds[kind]
	if ability then
		ability(ctx)
	else
		warn("[Abilities] Unknown power kind:", kind)
	end
end

return Abilities
