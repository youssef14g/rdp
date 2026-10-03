-- MapBuilder (ModuleScript in ServerScriptService)
-- Builds the whole arena from code when the server starts:
-- floor, safe zone with spawn, rocks for cover, climbable towers and walls.
-- Want to build your own map by hand? Make a Folder named "StealAPowerMap"
-- in Workspace and this script will leave it alone.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))

local MapBuilder = {}
MapBuilder.FOLDER_NAME = "StealAPowerMap"

local ARENA_SIZE = 400
local HALF = ARENA_SIZE / 2
local TOWER_DISTANCE = 130
local ACCENT = Color3.fromRGB(80, 200, 255)

local function part(props, parent)
	local newPart = Instance.new("Part")
	newPart.Anchored = true
	newPart.TopSurface = Enum.SurfaceType.Smooth
	newPart.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		newPart[key] = value
	end
	newPart.Parent = parent
	return newPart
end

local function folder(name, parent)
	local newFolder = Instance.new("Folder")
	newFolder.Name = name
	newFolder.Parent = parent
	return newFolder
end

-- A flat disc: a cylinder lies along X, so we turn it to stand up.
local function disc(name, radius, thickness, y, props, parent)
	local base = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
	}
	for key, value in props do
		base[key] = value
	end
	return part(base, parent)
end

local function buildSafeZone(map)
	local safe = folder("SafeZone", map)
	local radius = PowerConfig.SAFE_ZONE_RADIUS

	disc("Platform", radius, 1, 0.5, { Material = Enum.Material.Marble, Color = Color3.fromRGB(235, 235, 245) }, safe)
	disc("Ring", radius + 1.5, 0.8, 0.4, { Material = Enum.Material.Neon, Color = ACCENT }, safe)
	part({
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2,
		Position = Vector3.zero,
		Material = Enum.Material.ForceField,
		Color = ACCENT,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, safe)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 1.5, 0)
	spawn.Material = Enum.Material.Neon
	spawn.Color = ACCENT
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 3 -- seconds of spawn protection (force field)
	spawn.Neutral = true
	spawn.Parent = safe

	local sign = part({
		Name = "Sign",
		Size = Vector3.one,
		Position = Vector3.new(0, 24, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, safe)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(44, 10)
	billboard.MaxDistance = 400
	billboard.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "SAFE ZONE\nSpin & equip powers here"
	label.Parent = billboard
end

local function buildTowers(map)
	local towers = folder("Towers", map)
	local spots = {}
	for i = 0, 5 do
		local angle = math.rad(i * 60 + 30)
		local height = if i % 2 == 0 then 16 else 24
		local position = Vector3.new(math.cos(angle) * TOWER_DISTANCE, height / 2, math.sin(angle) * TOWER_DISTANCE)
		-- Face the center so the ladder is on the side players come from.
		local cframe = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
		part({
			Name = "Tower",
			Size = Vector3.new(20, height, 20),
			CFrame = cframe,
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(85, 90, 105),
		}, towers)
		part({
			Name = "Trim",
			Size = Vector3.new(20.6, 0.6, 20.6),
			CFrame = cframe * CFrame.new(0, height / 2, 0),
			Material = Enum.Material.Neon,
			Color = ACCENT,
		}, towers)
		local ladder = Instance.new("TrussPart")
		ladder.Name = "Ladder"
		ladder.Anchored = true
		ladder.Size = Vector3.new(2, height, 2)
		ladder.CFrame = cframe * CFrame.new(0, 0, -11)
		ladder.Color = Color3.fromRGB(60, 60, 70)
		ladder.Parent = towers
		table.insert(spots, position)
	end
	return spots
end

local function buildCover(map, towerSpots)
	local cover = folder("Cover", map)
	local rng = Random.new(2026) -- fixed seed: the same map every time
	local colors = {
		Color3.fromRGB(110, 105, 100),
		Color3.fromRGB(95, 100, 110),
		Color3.fromRGB(125, 110, 95),
	}

	local placed, attempts = 0, 0
	while placed < 40 and attempts < 400 do
		attempts += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(PowerConfig.SAFE_ZONE_RADIUS + 35, HALF - 20)
		local position = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)

		local nearTower = false
		for _, spot in towerSpots do
			if (Vector3.new(spot.X, 0, spot.Z) - position).Magnitude < 24 then
				nearTower = true
				break
			end
		end

		if not nearTower then
			local size = Vector3.new(rng:NextInteger(6, 16), rng:NextInteger(6, 20), rng:NextInteger(6, 16))
			part({
				Name = "Rock",
				Size = size,
				CFrame = CFrame.new(position + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Material = Enum.Material.Slate,
				Color = colors[rng:NextInteger(1, #colors)],
			}, cover)
			placed += 1
		end
	end
end

local function buildWalls(map)
	local walls = folder("Walls", map)
	local wallProps = {
		Material = Enum.Material.ForceField,
		Color = ACCENT,
		CastShadow = false,
	}
	local sides = {
		{ Size = Vector3.new(ARENA_SIZE, 80, 2), Position = Vector3.new(0, 40, HALF + 1) },
		{ Size = Vector3.new(ARENA_SIZE, 80, 2), Position = Vector3.new(0, 40, -HALF - 1) },
		{ Size = Vector3.new(2, 80, ARENA_SIZE), Position = Vector3.new(HALF + 1, 40, 0) },
		{ Size = Vector3.new(2, 80, ARENA_SIZE), Position = Vector3.new(-HALF - 1, 40, 0) },
	}
	for _, side in sides do
		local props = table.clone(wallProps)
		props.Name = "Wall"
		props.Size = side.Size
		props.Position = side.Position
		part(props, walls)
	end
end

local function setupLighting()
	Lighting.ClockTime = 17
	Lighting.Brightness = 2
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Color = Color3.fromRGB(200, 170, 140)
		atmosphere.Decay = Color3.fromRGB(110, 90, 120)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.5
		bloom.Size = 24
		bloom.Threshold = 1.2
		bloom.Parent = Lighting
	end
end

function MapBuilder.Build()
	local existing = workspace:FindFirstChild(MapBuilder.FOLDER_NAME)
	if existing then
		return existing
	end

	-- The "Baseplate" template has its own floor and spawn. Ours replace them.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local map = Instance.new("Folder")
	map.Name = MapBuilder.FOLDER_NAME

	part({
		Name = "Floor",
		Size = Vector3.new(ARENA_SIZE, 4, ARENA_SIZE),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(95, 95, 105),
	}, map)
	buildSafeZone(map)
	buildCover(map, buildTowers(map))
	buildWalls(map)
	setupLighting()

	map.Parent = workspace
	return map
end

return MapBuilder
