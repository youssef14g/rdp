-- PowerService (ModuleScript in ServerScriptService)
-- Spinning for powers, equipping them, and merging copies into stars.
-- Each function returns a table the client can read: { ok = true, ... }
-- or { ok = false, err = "message to show" }.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local PowerService = {}

local rng = Random.new()
local lastSpin = {} -- [Player] = os.clock() of their last spin
local ANNOUNCE_DELAY = 2 -- wait for the spin animation before telling everyone

local function isPowerId(value)
	return type(value) == "string" and PowerConfig.Powers[value] ~= nil
end

function PowerService.Spin(player)
	local now = os.clock()
	if lastSpin[player] and now - lastSpin[player] < 0.5 then
		return { ok = false, err = "Slow down!" }
	end
	lastSpin[player] = now

	if not DataService.SpendCoins(player, PowerConfig.SPIN_COST) then
		return { ok = false, err = `You need {PowerConfig.SPIN_COST} coins to spin` }
	end

	local powerId = PowerConfig.RollPower(rng)
	DataService.AddPower(player, powerId, 1)

	-- Nothing equipped yet? Equip the new power so new players can use it right away.
	local data = DataService.Get(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if data and not data.Equipped and root and PowerConfig.IsInSafeZone(root.Position) then
		DataService.SetEquipped(player, powerId)
	end

	local power = PowerConfig.Powers[powerId]
	local rarity = PowerConfig.GetRarityOf(powerId)
	if rarity.Rank >= PowerConfig.RarityByName.Mythic.Rank then
		task.delay(ANNOUNCE_DELAY, function()
			remotes.Notify:FireAllClients(
				`{player.DisplayName} pulled a {string.upper(rarity.Name)} power: {power.Name}!`,
				rarity.Color
			)
		end)
	end
	return { ok = true, powerId = powerId }
end

-- powerId = nil unequips. Only allowed in the safe zone, otherwise players
-- would unequip their best power mid-fight to stop it being stolen.
function PowerService.Equip(player, powerId)
	if powerId ~= nil and not isPowerId(powerId) then
		return { ok = false, err = "Unknown power" }
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not PowerConfig.IsInSafeZone(root.Position) then
		return { ok = false, err = "Go to the Safe Zone to change powers" }
	end
	if not DataService.SetEquipped(player, powerId) then
		return { ok = false, err = "You don't own that power" }
	end
	return { ok = true }
end

-- MERGE_COPIES copies -> keep one and gain a star (+damage).
function PowerService.Merge(player, powerId)
	if not isPowerId(powerId) then
		return { ok = false, err = "Unknown power" }
	end
	local data = DataService.Get(player)
	if not data then
		return { ok = false, err = "Still loading..." }
	end
	local stars = data.Stars[powerId] or 0
	if stars >= PowerConfig.MAX_STARS then
		return { ok = false, err = "Already at max stars" }
	end
	if (data.Owned[powerId] or 0) < PowerConfig.MERGE_COPIES then
		return { ok = false, err = `You need {PowerConfig.MERGE_COPIES} copies to merge` }
	end
	DataService.RemovePower(player, powerId, PowerConfig.MERGE_COPIES - 1)
	DataService.AddStar(player, powerId)
	return { ok = true, stars = stars + 1 }
end

function PowerService.Cleanup(player)
	lastSpin[player] = nil
end

return PowerService
