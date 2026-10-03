-- CombatService (ModuleScript in ServerScriptService)
-- Checks every attack the client asks for, then runs the power.
-- The client only says "I pressed Power, aiming here". The server decides
-- if that is allowed (cooldown, safe zone, owns the power...) and how much
-- damage it does, so exploiters can't just send "deal 9999 damage".

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local Abilities = require(script.Parent:WaitForChild("Abilities"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local CombatService = {}

local readyAt = {} -- [Player] = { Punch = time, Power = time }

-- Targets -------------------------------------------------------------------------

-- Everything that can be hit: other players' characters and training dummies,
-- alive and outside the safe zone. Each entry: { Model, Humanoid, Root, Player }.
function CombatService.GetTargets(excludeCharacter)
	local targets = {}
	local function consider(model, player)
		if model == excludeCharacter then
			return
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 and not PowerConfig.IsInSafeZone(root.Position) then
			table.insert(targets, { Model = model, Humanoid = humanoid, Root = root, Player = player })
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			consider(player.Character, player)
		end
	end
	for _, dummy in CollectionService:GetTagged("Dummy") do
		consider(dummy, nil)
	end
	return targets
end

function CombatService.GetTargetsInRadius(center, radius, excludeCharacter)
	local inside = {}
	for _, target in CombatService.GetTargets(excludeCharacter) do
		if (target.Root.Position - center).Magnitude <= radius then
			table.insert(inside, target)
		end
	end
	return inside
end

-- Damage and effects ----------------------------------------------------------------

function CombatService.DealDamage(attacker, humanoid, amount)
	local model = humanoid.Parent
	if not model or humanoid.Health <= 0 or model == attacker.Character then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and PowerConfig.IsInSafeZone(root.Position) then
		return
	end
	if model:FindFirstChildOfClass("ForceField") then
		return -- spawn protection
	end

	-- Remember who hit last, so the knockout (and the stolen power) goes to them.
	humanoid:SetAttribute("LastAttacker", attacker.UserId)
	humanoid:SetAttribute("LastAttackTime", os.clock())
	humanoid:TakeDamage(amount)

	if attacker.Parent then
		local position = if root then root.Position else model:GetPivot().Position
		remotes.DamageDealt:FireClient(attacker, position, amount)
	end
end

-- Pushes a character with a velocity for a short time.
-- The mover is created on the server and the owner's physics applies it.
function CombatService.Knockback(root, velocity, duration)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.MaxForce = math.huge
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VectorVelocity = velocity
	mover.Parent = root
	Debris:AddItem(mover, duration)
	Debris:AddItem(attachment, duration)
end

-- speedMultiplier 0.5 = half speed, 0 = frozen (can't move, jump or attack).
-- A newer slow/freeze replaces an older one.
function CombatService.SetMovement(humanoid, speedMultiplier, duration)
	local token = (humanoid:GetAttribute("MoveToken") or 0) + 1
	humanoid:SetAttribute("MoveToken", token)

	local frozen = speedMultiplier <= 0
	humanoid.WalkSpeed = PowerConfig.WALK_SPEED * speedMultiplier
	humanoid:SetAttribute("Frozen", frozen or nil)

	local highlight
	if frozen then
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
		highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(170, 230, 255)
		highlight.FillTransparency = 0.3
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.Parent = humanoid.Parent
		Debris:AddItem(highlight, duration)
	end

	task.delay(duration, function()
		if humanoid.Parent and humanoid:GetAttribute("MoveToken") == token then
			humanoid.WalkSpeed = PowerConfig.WALK_SPEED
			humanoid.JumpHeight = PowerConfig.JUMP_HEIGHT
			humanoid.JumpPower = PowerConfig.JUMP_POWER
			humanoid.AutoRotate = true
			humanoid:SetAttribute("Frozen", nil)
		end
	end)
end

-- Damage over time, one tick per second.
function CombatService.Burn(attacker, humanoid, damagePerTick, ticks)
	local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
	if root then
		local fire = Instance.new("Fire")
		fire.Heat = 0
		fire.Parent = root
		Debris:AddItem(fire, ticks)
	end
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(1)
			if humanoid.Health <= 0 then
				break
			end
			CombatService.DealDamage(attacker, humanoid, damagePerTick)
		end
	end)
end

-- Using powers ---------------------------------------------------------------------

local function isValidAim(aim)
	-- `x == x` is false only for NaN, which exploiters like to send.
	return typeof(aim) == "Vector3" and aim.X == aim.X and aim.Y == aim.Y and aim.Z == aim.Z and aim.Magnitude < 1e5
end

-- slot is "Punch" or "Power". aim is the world point the player aims at.
function CombatService.UsePower(player, slot, aim)
	if (slot ~= "Punch" and slot ~= "Power") or not isValidAim(aim) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or humanoid:GetAttribute("Frozen") then
		return
	end
	if PowerConfig.IsInSafeZone(root.Position) then
		return -- no fighting in the safe zone
	end

	local data = DataService.Get(player)
	if not data then
		return
	end
	local powerId = if slot == "Punch" then "Punch" else data.Equipped
	if not powerId then
		return
	end
	local power = PowerConfig.Powers[powerId]

	local now = os.clock()
	local times = readyAt[player]
	if not times then
		times = {}
		readyAt[player] = times
	end
	if (times[slot] or 0) > now then
		return -- still on cooldown
	end
	times[slot] = now + power.Cooldown
	remotes.Cooldown:FireClient(player, slot, power.Cooldown)

	-- Aim: never further than the power's range.
	local offset = aim - root.Position
	local direction = if offset.Magnitude > 0.1 then offset.Unit else root.CFrame.LookVector
	local range = power.Range or 0
	local target = if offset.Magnitude > range then root.Position + direction * range else aim

	Abilities.Run(power.Kind, {
		Combat = CombatService,
		Player = player,
		Character = character,
		Root = root,
		Humanoid = humanoid,
		Power = power,
		PowerId = powerId,
		Damage = PowerConfig.GetDamage(powerId, data.Stars[powerId], player:GetAttribute("Wanted") == true),
		Direction = direction,
		Target = target,
	})
end

function CombatService.Cleanup(player)
	readyAt[player] = nil
end

return CombatService
