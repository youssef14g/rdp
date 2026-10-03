-- DummyService (ModuleScript in ServerScriptService)
-- Training dummies next to the safe zone, so you can test powers alone.
-- They give no coins (otherwise people would farm them) and respawn after dying.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local DummyService = {}

local SPOTS = {
	Vector3.new(58, 4, 0),
	Vector3.new(-58, 4, 0),
	Vector3.new(0, 4, 58),
	Vector3.new(0, 4, -58),
}
local HEALTH = 150
local RESPAWN_TIME = 4
local SKIN = Color3.fromRGB(205, 175, 125)

local folder = workspace:FindFirstChild("Dummies")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Dummies"
	folder.Parent = workspace
end

-- A simple block dummy, used if Roblox can't build a normal character.
local function blockDummy()
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 5, 1.5)
	root.Anchored = true
	root.Color = SKIN
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Anchored = true
	head.Color = SKIN
	head.CFrame = root.CFrame * CFrame.new(0, 3.25, 0)
	head.Parent = model
	Instance.new("Humanoid").Parent = model
	model.PrimaryPart = root
	return model
end

local function buildDummy()
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		for _, part in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
			description[part .. "Color"] = SKIN
		end
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model
	end
	warn("[DummyService] Using block dummies:", model)
	return blockDummy()
end

local function spawnDummy(spot)
	local model = buildDummy()
	model.Name = "Training Dummy"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "Training Dummy"
	humanoid.MaxHealth = HEALTH
	humanoid.Health = HEALTH
	CollectionService:AddTag(model, "Dummy")

	-- Stand on the spot, facing the safe zone.
	model:PivotTo(CFrame.lookAt(spot, Vector3.new(0, spot.Y, 0)))
	model.Parent = folder

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and not root.Anchored then
		root:SetNetworkOwner(nil) -- the server moves it, not a nearby player
	end

	local respawned = false
	local function respawn()
		if respawned then
			return
		end
		respawned = true
		task.delay(RESPAWN_TIME, function()
			model:Destroy()
			spawnDummy(spot)
		end)
	end
	humanoid.Died:Once(respawn)

	-- Knocked off the map or broken: replace it.
	task.spawn(function()
		while not respawned do
			task.wait(5)
			local currentRoot = model:FindFirstChild("HumanoidRootPart")
			if not model.Parent or not currentRoot or currentRoot.Position.Y < -50 then
				respawn()
			end
		end
	end)
end

function DummyService.Start()
	for _, spot in SPOTS do
		task.spawn(spawnDummy, spot)
	end
end

return DummyService
