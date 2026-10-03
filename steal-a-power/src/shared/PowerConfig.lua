-- PowerConfig (ModuleScript in ReplicatedStorage)
-- Every number in the game lives here, so you can balance it in one place.
-- Both the server and the client read this file.

local PowerConfig = {}

-- Economy -------------------------------------------------------------------
PowerConfig.STARTING_COINS = 300
PowerConfig.SPIN_COST = 100
PowerConfig.PASSIVE_INCOME = 5 -- coins every PASSIVE_INTERVAL seconds
PowerConfig.PASSIVE_INTERVAL = 10
PowerConfig.KILL_REWARD = 50

-- Bounty ("Wanted") -----------------------------------------------------------
PowerConfig.BOUNTY_STREAK = 5 -- kills in a row without dying
PowerConfig.BOUNTY_REWARD = 500 -- paid to whoever knocks out a wanted player
PowerConfig.BOUNTY_DAMAGE_BONUS = 0.2 -- wanted players hit 20% harder

-- Stealing --------------------------------------------------------------------
PowerConfig.ORB_LIFETIME = 15 -- seconds before an unclaimed orb goes back to its owner
PowerConfig.ORB_KILLER_PRIORITY = 3 -- seconds where only the killer can grab the orb
PowerConfig.KILL_CREDIT_WINDOW = 10 -- a hit still counts for the knockout this long after

-- Merging ---------------------------------------------------------------------
PowerConfig.MERGE_COPIES = 3 -- 3 copies -> keep 1 and gain a star
PowerConfig.MAX_STARS = 5
PowerConfig.STAR_DAMAGE_BONUS = 0.15 -- +15% damage per star

-- World -----------------------------------------------------------------------
PowerConfig.SAFE_ZONE_RADIUS = 40 -- the safe zone is a circle around (0, 0, 0)
PowerConfig.WALK_SPEED = 16
PowerConfig.JUMP_HEIGHT = 7.2
PowerConfig.JUMP_POWER = 50

-- Rarities (Weight = chance out of 100) ---------------------------------------
PowerConfig.Rarities = {
	{ Name = "Common", Weight = 50, Color = Color3.fromRGB(200, 200, 200) },
	{ Name = "Rare", Weight = 30, Color = Color3.fromRGB(70, 140, 255) },
	{ Name = "Epic", Weight = 15, Color = Color3.fromRGB(175, 85, 255) },
	{ Name = "Legendary", Weight = 4, Color = Color3.fromRGB(255, 200, 40) },
	{ Name = "Mythic", Weight = 0.9, Color = Color3.fromRGB(255, 55, 70) },
	{ Name = "Secret", Weight = 0.1, Color = Color3.fromRGB(0, 255, 200) },
}

-- Powers ------------------------------------------------------------------------
-- Kind decides what the power does (see Abilities on the server):
--   Melee      hit the closest enemy in front of you
--   Projectile shoot a ball that flies to where you aim
--   Push       blast everyone around you away
--   Strike     after Delay seconds, hit everyone in Radius where you aim
--   Pull       suck enemies toward where you aim, Pulses times
--   Freeze     freeze everyone around you for Duration seconds
--   Storm      Strikes small strikes spread around where you aim
PowerConfig.PowerList = {
	{
		Id = "Punch",
		Name = "Punch",
		Rarity = "Default",
		Kind = "Melee",
		Damage = 12,
		Cooldown = 0.6,
		Range = 7,
		Knockback = 30,
		Color = Color3.fromRGB(255, 255, 255),
		Description = "Always yours. Nobody can steal it.",
	},
	{
		Id = "RockThrow",
		Name = "Rock Throw",
		Rarity = "Common",
		Kind = "Projectile",
		Damage = 15,
		Cooldown = 1.2,
		Range = 120,
		Speed = 90,
		Size = 1.6,
		Color = Color3.fromRGB(140, 115, 90),
		Description = "Throw a heavy rock.",
	},
	{
		Id = "WindPush",
		Name = "Wind Push",
		Rarity = "Common",
		Kind = "Push",
		Damage = 10,
		Cooldown = 3,
		Radius = 14,
		Force = 90,
		Color = Color3.fromRGB(210, 245, 255),
		Description = "Blast everyone near you away.",
	},
	{
		Id = "Fireball",
		Name = "Fireball",
		Rarity = "Rare",
		Kind = "Projectile",
		Damage = 22,
		Cooldown = 1.5,
		Range = 150,
		Speed = 110,
		Size = 2,
		Color = Color3.fromRGB(255, 110, 30),
		Burn = { Damage = 3, Ticks = 3 },
		Description = "Sets the target on fire.",
	},
	{
		Id = "IceShard",
		Name = "Ice Shard",
		Rarity = "Rare",
		Kind = "Projectile",
		Damage = 18,
		Cooldown = 1.4,
		Range = 150,
		Speed = 140,
		Size = 1.3,
		Color = Color3.fromRGB(120, 220, 255),
		Slow = { Amount = 0.5, Duration = 2.5 },
		Description = "Slows the target down.",
	},
	{
		Id = "Lightning",
		Name = "Lightning",
		Rarity = "Epic",
		Kind = "Strike",
		Visual = "Lightning",
		Damage = 35,
		Cooldown = 4,
		Range = 90,
		Radius = 8,
		Delay = 0.35,
		Color = Color3.fromRGB(255, 240, 90),
		Description = "Call lightning where you aim.",
	},
	{
		Id = "ShadowBolt",
		Name = "Shadow Bolt",
		Rarity = "Epic",
		Kind = "Projectile",
		Damage = 30,
		Cooldown = 2,
		Range = 200,
		Speed = 220,
		Size = 1.4,
		Color = Color3.fromRGB(120, 40, 200),
		Description = "A very fast bolt of darkness.",
	},
	{
		Id = "GravityWell",
		Name = "Gravity Well",
		Rarity = "Legendary",
		Kind = "Pull",
		Damage = 30,
		Cooldown = 7,
		Range = 80,
		Radius = 24,
		Force = 70,
		Pulses = 1,
		Color = Color3.fromRGB(90, 70, 255),
		Description = "Pull enemies into one spot.",
	},
	{
		Id = "Meteor",
		Name = "Meteor",
		Rarity = "Legendary",
		Kind = "Strike",
		Visual = "Meteor",
		Damage = 55,
		Cooldown = 8,
		Range = 100,
		Radius = 16,
		Delay = 1.2,
		Color = Color3.fromRGB(255, 70, 20),
		Description = "A meteor falls from the sky.",
	},
	{
		Id = "TimeStop",
		Name = "Time Stop",
		Rarity = "Mythic",
		Kind = "Freeze",
		Damage = 20,
		Cooldown = 14,
		Radius = 30,
		Duration = 2.5,
		Color = Color3.fromRGB(180, 220, 255),
		Description = "Freeze everyone around you.",
	},
	{
		Id = "BlackHole",
		Name = "Black Hole",
		Rarity = "Mythic",
		Kind = "Pull",
		Damage = 60,
		Cooldown = 12,
		Range = 90,
		Radius = 35,
		Force = 110,
		Pulses = 4,
		Color = Color3.fromRGB(60, 0, 90),
		Description = "Swallow everything nearby.",
	},
	{
		Id = "VoidStorm",
		Name = "Void Storm",
		Rarity = "Secret",
		Kind = "Storm",
		Visual = "Lightning",
		Damage = 30,
		Cooldown = 15,
		Range = 100,
		Radius = 10,
		Delay = 0.5,
		Strikes = 6,
		Spread = 25,
		Color = Color3.fromRGB(200, 0, 255),
		Description = "Rain void lightning on a whole area.",
	},
}

-- Fields each Kind needs. A missing one stops the game with a clear message,
-- so a typo in a new power is easy to find.
local REQUIRED_FIELDS = {
	Melee = { "Range", "Knockback" },
	Projectile = { "Range", "Speed", "Size" },
	Push = { "Radius", "Force" },
	Strike = { "Range", "Radius", "Delay", "Visual" },
	Pull = { "Range", "Radius", "Force", "Pulses" },
	Freeze = { "Radius", "Duration" },
	Storm = { "Range", "Radius", "Delay", "Strikes", "Spread", "Visual" },
}

-- Lookup tables built from the lists above ------------------------------------
PowerConfig.RarityByName = {
	Default = { Name = "Default", Weight = 0, Color = Color3.fromRGB(255, 255, 255), Rank = 0 },
}
for rank, rarity in PowerConfig.Rarities do
	rarity.Rank = rank
	PowerConfig.RarityByName[rarity.Name] = rarity
end

PowerConfig.Powers = {} -- [powerId] = power
PowerConfig.PowersByRarity = {} -- [rarityName] = { powerId, ... }
for _, power in PowerConfig.PowerList do
	local required = REQUIRED_FIELDS[power.Kind]
	assert(required, `Power {power.Id} has an unknown Kind "{power.Kind}"`)
	for _, field in { "Id", "Name", "Damage", "Cooldown", "Color", "Description", table.unpack(required) } do
		assert(power[field] ~= nil, `Power {power.Id} is missing {field}`)
	end
	assert(PowerConfig.RarityByName[power.Rarity], `Power {power.Id} has an unknown Rarity "{power.Rarity}"`)
	assert(PowerConfig.Powers[power.Id] == nil, `Two powers use the Id {power.Id}`)

	PowerConfig.Powers[power.Id] = power
	if power.Rarity ~= "Default" then
		local list = PowerConfig.PowersByRarity[power.Rarity] or {}
		table.insert(list, power.Id)
		PowerConfig.PowersByRarity[power.Rarity] = list
	end
end
for _, rarity in PowerConfig.Rarities do
	assert(PowerConfig.PowersByRarity[rarity.Name], `No power has the rarity {rarity.Name}`)
end

-- Helpers -----------------------------------------------------------------------

-- Picks a rarity name using the weights. `rng` is a Random object.
-- `luck` (default 1) multiplies the chance of everything rarer than Common.
function PowerConfig.RollRarity(rng, luck)
	luck = luck or 1
	local function weightOf(rarity)
		return rarity.Weight * (rarity.Rank > 1 and luck or 1)
	end

	local total = 0
	for _, rarity in PowerConfig.Rarities do
		total += weightOf(rarity)
	end

	local roll = rng:NextNumber() * total
	for _, rarity in PowerConfig.Rarities do
		local weight = weightOf(rarity)
		if roll < weight then
			return rarity.Name
		end
		roll -= weight
	end
	return PowerConfig.Rarities[1].Name
end

-- Picks a random power id: first the rarity, then a power of that rarity.
function PowerConfig.RollPower(rng, luck)
	local list = PowerConfig.PowersByRarity[PowerConfig.RollRarity(rng, luck)]
	return list[rng:NextInteger(1, #list)]
end

-- Final damage after stars and the wanted bonus.
function PowerConfig.GetDamage(powerId, stars, isWanted)
	local power = PowerConfig.Powers[powerId]
	local multiplier = 1 + (stars or 0) * PowerConfig.STAR_DAMAGE_BONUS
	if isWanted then
		multiplier += PowerConfig.BOUNTY_DAMAGE_BONUS
	end
	return math.floor(power.Damage * multiplier + 0.5)
end

function PowerConfig.IsInSafeZone(position)
	local radius = PowerConfig.SAFE_ZONE_RADIUS
	return position.X * position.X + position.Z * position.Z <= radius * radius and position.Y < 60
end

function PowerConfig.GetRarityOf(powerId)
	return PowerConfig.RarityByName[PowerConfig.Powers[powerId].Rarity]
end

return PowerConfig
