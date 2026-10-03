-- Checks PowerConfig outside Roblox.
-- Run from the steal-a-power folder:  sh tests/run.sh
-- run.sh puts the Color3 stand-in and PowerConfig in front of this file,
-- so `PowerConfig` is already defined here.

local failures = 0
local function check(condition, message)
	if not condition then
		failures += 1
		print("FAIL: " .. message)
	end
end

-- A Random-like object built on math.random.
local function makeRng(seed)
	math.randomseed(seed)
	return {
		NextNumber = function(_)
			return math.random()
		end,
		NextInteger = function(_, low, high)
			return math.random(low, high)
		end,
	}
end

-- Weights add up to 100 ----------------------------------------------------------
local totalWeight = 0
for _, rarity in PowerConfig.Rarities do
	totalWeight += rarity.Weight
end
check(math.abs(totalWeight - 100) < 1e-9, `weights add up to {totalWeight}, expected 100`)

-- Rolled rarities match the weights ----------------------------------------------
local ROLLS = 1_000_000
local rng = makeRng(42)
local counts = {}
for _ = 1, ROLLS do
	local name = PowerConfig.RollRarity(rng)
	counts[name] = (counts[name] or 0) + 1
end
for _, rarity in PowerConfig.Rarities do
	local p = rarity.Weight / 100
	local expected = ROLLS * p
	local tolerance = 5 * math.sqrt(ROLLS * p * (1 - p))
	local got = counts[rarity.Name] or 0
	check(math.abs(got - expected) <= tolerance, `{rarity.Name}: got {got}, expected about {expected}`)
	print(string.format("%-10s %6.3f%%  (expected %6.3f%%)", rarity.Name, got / ROLLS * 100, p * 100))
end

-- Luck makes rare pulls more likely ----------------------------------------------
local function commonShare(luck)
	local luckyRng = makeRng(7)
	local common = 0
	for _ = 1, 200_000 do
		if PowerConfig.RollRarity(luckyRng, luck) == "Common" then
			common += 1
		end
	end
	return common / 200_000
end
check(commonShare(2) < commonShare(1), "luck 2 should roll fewer Commons than luck 1")

-- Every rolled power exists and is never the default Punch -----------------------
local powerRng = makeRng(3)
for _ = 1, 10_000 do
	local id = PowerConfig.RollPower(powerRng)
	check(PowerConfig.Powers[id] ~= nil, `rolled unknown power {id}`)
	check(id ~= "Punch", "Punch must never come from a spin")
end

-- Damage math ----------------------------------------------------------------------
check(PowerConfig.GetDamage("Fireball", 0, false) == 22, "Fireball base damage should be 22")
check(PowerConfig.GetDamage("Fireball", 2, false) == 29, "Fireball with 2 stars should do 29")
check(PowerConfig.GetDamage("Fireball", 0, true) == 26, "wanted Fireball should do 26")

-- Safe zone ---------------------------------------------------------------------
check(PowerConfig.IsInSafeZone({ X = 0, Y = 3, Z = 0 }), "center is safe")
check(PowerConfig.IsInSafeZone({ X = 39, Y = 3, Z = 0 }), "inside the edge is safe")
check(not PowerConfig.IsInSafeZone({ X = 41, Y = 3, Z = 0 }), "outside the edge is not safe")
check(not PowerConfig.IsInSafeZone({ X = 30, Y = 3, Z = 30 }), "diagonal outside the circle is not safe")

if failures > 0 then
	error(`{failures} check(s) failed`)
end
print("All PowerConfig checks passed")
