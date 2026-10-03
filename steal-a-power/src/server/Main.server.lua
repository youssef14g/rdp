-- Main (Script in ServerScriptService)
-- Starts every system and connects the client's requests to them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))

-- 1. Remotes: the "phone lines" between client and server.
--    They must exist before the other modules load, because they use them.
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "Spin", "Equip", "Merge" } do
	local remoteFunction = Instance.new("RemoteFunction") -- client asks, server answers
	remoteFunction.Name = name
	remoteFunction.Parent = remotes
end
for _, name in { "UsePower", "DataUpdated", "Notify", "Cooldown", "DamageDealt" } do
	local remoteEvent = Instance.new("RemoteEvent") -- one-way message
	remoteEvent.Name = name
	remoteEvent.Parent = remotes
end
remotes.Parent = ReplicatedStorage

-- 2. Load the systems.
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DummyService = require(script.Parent:WaitForChild("DummyService"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local PowerService = require(script.Parent:WaitForChild("PowerService"))
local StealService = require(script.Parent:WaitForChild("StealService"))

local AUTOSAVE_INTERVAL = 120

Players.RespawnTime = 4
MapBuilder.Build()
DummyService.Start()

-- 3. Keep the client and the leaderboard in sync with the data.
--    Many changes can happen in one frame, so we send once at the end of it.
local pushQueued = {}
local function pushData(player)
	if pushQueued[player] then
		return
	end
	pushQueued[player] = true
	task.defer(function()
		pushQueued[player] = nil
		local snapshot = DataService.Snapshot(player)
		if not snapshot or not player.Parent then
			return
		end
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			stats.Kills.Value = snapshot.Kills
			stats.Coins.Value = snapshot.Coins
		end
		remotes.DataUpdated:FireClient(player, snapshot)
	end)
end
DataService.Changed:Connect(pushData)

local function createLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats" -- this exact name shows the values on the player list
	for _, name in { "Kills", "Coins" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
end

-- 4. Players joining and leaving.
local function onPlayerAdded(player)
	createLeaderstats(player)
	local data = DataService.Load(player)
	if not data then
		return -- left while loading
	end
	StealService.SetupPlayer(player)
	pushData(player)
	if not DataService.CanSave(player) then
		remotes.Notify:FireClient(
			player,
			"Saving is OFF for this session (in Studio: Game Settings > Security > API Services)",
			Color3.fromRGB(255, 160, 60)
		)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	StealService.OnPlayerRemoving(player) -- must run before the last save
	DataService.Release(player)
	CombatService.Cleanup(player)
	PowerService.Cleanup(player)
end)

-- 5. Requests from the client.
remotes.Spin.OnServerInvoke = function(player)
	return PowerService.Spin(player)
end
remotes.Equip.OnServerInvoke = function(player, powerId)
	return PowerService.Equip(player, powerId)
end
remotes.Merge.OnServerInvoke = function(player, powerId)
	return PowerService.Merge(player, powerId)
end
remotes.UsePower.OnServerEvent:Connect(function(player, slot, aim)
	CombatService.UsePower(player, slot, aim)
end)

-- 6. Coins over time, so everyone can keep spinning.
task.spawn(function()
	while true do
		task.wait(PowerConfig.PASSIVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			DataService.AddCoins(player, PowerConfig.PASSIVE_INCOME)
		end
	end
end)

-- 7. Saving: every few minutes, and when the server shuts down.
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.Save, player)
		end
	end
end)

game:BindToClose(function()
	local running = 0
	for _, player in Players:GetPlayers() do
		running += 1
		task.spawn(function()
			DataService.Save(player)
			running -= 1
		end)
	end
	local started = os.clock()
	while running > 0 and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)
