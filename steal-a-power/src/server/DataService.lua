-- DataService (ModuleScript in ServerScriptService)
-- Loads, saves and changes player data. Every change goes through here,
-- so the client always gets an up-to-date copy.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))

local STORE_NAME = "StealAPower_v1"
local MAX_RETRIES = 3

local DataService = {}

-- Fires (player) whenever that player's data changes.
local changedEvent = Instance.new("BindableEvent")
DataService.Changed = changedEvent.Event

local sessions = {} -- [Player] = { Data = table, CanSave = boolean }

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress will not save:", result)
	end
end

local function defaultData()
	return {
		Coins = PowerConfig.STARTING_COINS,
		Kills = 0,
		BestStreak = 0,
		Owned = {}, -- [powerId] = number of copies
		Stars = {}, -- [powerId] = star level
		Equipped = nil, -- powerId, or nil when only Punch is used
	}
end

-- Fills in anything missing (for example a field added in an update)
-- and drops powers that no longer exist in PowerConfig.
local function reconcile(data)
	for key, value in defaultData() do
		if data[key] == nil then
			data[key] = value
		end
	end
	for powerId in data.Owned do
		if not PowerConfig.Powers[powerId] then
			data.Owned[powerId] = nil
		end
	end
	if data.Equipped and (data.Owned[data.Equipped] or 0) < 1 then
		data.Equipped = nil
	end
	return data
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function changed(player)
	changedEvent:Fire(player)
end

-- Loading and saving -----------------------------------------------------------

-- Yields while loading. Returns the data, or nil if the player left meanwhile.
function DataService.Load(player)
	local data, loaded = nil, false
	if store then
		for attempt = 1, MAX_RETRIES do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				data, loaded = result, true
				break
			end
			warn(`[DataService] Load failed for {player.Name} (try {attempt}):`, result)
			-- In Studio a failure almost always means API access is off, so don't wait.
			if RunService:IsStudio() then
				break
			end
			task.wait(attempt * 2)
		end
	end

	if not player.Parent then
		return nil
	end
	-- If loading failed we must not save, or we would overwrite their real data.
	sessions[player] = { Data = reconcile(data or defaultData()), CanSave = loaded }
	changed(player)
	return sessions[player].Data
end

function DataService.Save(player)
	local session = sessions[player]
	if not session or not session.CanSave then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return session.Data
		end)
	end)
	if not ok then
		warn(`[DataService] Save failed for {player.Name}:`, err)
	end
end

-- Saves one last time and forgets the player.
function DataService.Release(player)
	DataService.Save(player)
	sessions[player] = nil
end

function DataService.Get(player)
	local session = sessions[player]
	return session and session.Data
end

function DataService.CanSave(player)
	local session = sessions[player]
	return session ~= nil and session.CanSave
end

-- A copy that is safe to send to the client.
function DataService.Snapshot(player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	return {
		Coins = data.Coins,
		Kills = data.Kills,
		BestStreak = data.BestStreak,
		Owned = table.clone(data.Owned),
		Stars = table.clone(data.Stars),
		Equipped = data.Equipped,
	}
end

-- Changing data ----------------------------------------------------------------
-- Each function returns true when it worked.

function DataService.AddCoins(player, amount)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	data.Coins += amount
	changed(player)
	return true
end

function DataService.SpendCoins(player, amount)
	local data = DataService.Get(player)
	if not data or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	changed(player)
	return true
end

function DataService.AddPower(player, powerId, count)
	local data = DataService.Get(player)
	if not data or not PowerConfig.Powers[powerId] then
		return false
	end
	data.Owned[powerId] = (data.Owned[powerId] or 0) + (count or 1)
	changed(player)
	return true
end

-- Removing the last copy of the equipped power also unequips it.
function DataService.RemovePower(player, powerId, count)
	local data = DataService.Get(player)
	count = count or 1
	if not data or (data.Owned[powerId] or 0) < count then
		return false
	end
	local left = data.Owned[powerId] - count
	data.Owned[powerId] = if left > 0 then left else nil
	if left == 0 and data.Equipped == powerId then
		data.Equipped = nil
	end
	changed(player)
	return true
end

-- powerId = nil unequips (you fight with Punch only, and nothing can be stolen).
function DataService.SetEquipped(player, powerId)
	local data = DataService.Get(player)
	if not data or (powerId ~= nil and (data.Owned[powerId] or 0) < 1) then
		return false
	end
	data.Equipped = powerId
	changed(player)
	return true
end

function DataService.AddStar(player, powerId)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	data.Stars[powerId] = math.min((data.Stars[powerId] or 0) + 1, PowerConfig.MAX_STARS)
	changed(player)
	return true
end

function DataService.AddKill(player)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	data.Kills += 1
	changed(player)
	return true
end

function DataService.RecordStreak(player, streak)
	local data = DataService.Get(player)
	if not data or streak <= data.BestStreak then
		return false
	end
	data.BestStreak = streak
	changed(player)
	return true
end

return DataService
