-- StealService (ModuleScript in ServerScriptService)
-- The heart of the game:
--   * Knock someone out -> their equipped power drops as a glowing orb.
--     The killer gets a few seconds to grab it first, then anyone can.
--     If nobody grabs it, it flies back to its owner.
--   * Kill streaks -> at BOUNTY_STREAK kills you become WANTED: glowing red
--     through walls, +damage, and a big reward for whoever takes you down.
--   * Leaving mid-fight counts as getting knocked out (no rage-quit escapes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local StealService = {}

local GOLD = Color3.fromRGB(255, 200, 40)
local RED = Color3.fromRGB(255, 70, 70)

local streaks = {} -- [Player] = kills since last death

local orbs = workspace:FindFirstChild("Orbs")
if not orbs then
	orbs = Instance.new("Folder")
	orbs.Name = "Orbs"
	orbs.Parent = workspace
end

local function notify(player, text, color)
	if player.Parent then
		remotes.Notify:FireClient(player, text, color)
	end
end

local function notifyAll(text, color)
	remotes.Notify:FireAllClients(text, color)
end

local function setStreak(player, streak)
	streaks[player] = streak
	player:SetAttribute("Streak", streak)
end

-- Who gets credit for this knockout? The last attacker, if the hit was recent.
local function getKiller(humanoid)
	local attackerId = humanoid:GetAttribute("LastAttacker")
	local attackTime = humanoid:GetAttribute("LastAttackTime")
	if not attackerId or not attackTime or os.clock() - attackTime > PowerConfig.KILL_CREDIT_WINDOW then
		return nil
	end
	return Players:GetPlayerByUserId(attackerId)
end

-- Wanted ------------------------------------------------------------------------------

local function setWanted(player, isWanted)
	player:SetAttribute("Wanted", isWanted or nil)
	local character = player.Character
	if not character then
		return
	end
	for _, name in { "WantedHighlight", "WantedTag" } do
		local old = character:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if not isWanted then
		return
	end

	-- AlwaysOnTop: everyone can see the wanted player through walls.
	local highlight = Instance.new("Highlight")
	highlight.Name = "WantedHighlight"
	highlight.FillColor = RED
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = GOLD
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	local tag = Instance.new("BillboardGui")
	tag.Name = "WantedTag"
	tag.Size = UDim2.fromOffset(220, 50)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.AlwaysOnTop = true
	tag.Adornee = character:FindFirstChild("Head")
	tag.Parent = character
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = RED
	label.TextStrokeTransparency = 0
	label.Text = `WANTED  {PowerConfig.BOUNTY_REWARD} coins`
	label.Parent = tag
end

-- Power orbs ----------------------------------------------------------------------------

local function spawnOrb(position, powerId, killer, owner)
	local power = PowerConfig.Powers[powerId]
	local rarity = PowerConfig.GetRarityOf(powerId)

	local orb = Instance.new("Part")
	orb.Name = "PowerOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * 3
	orb.Material = Enum.Material.Neon
	orb.Color = rarity.Color
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CastShadow = false
	orb.CFrame = CFrame.new(position)

	local light = Instance.new("PointLight")
	light.Color = rarity.Color
	light.Range = 14
	light.Brightness = 3
	light.Parent = orb

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(200, 50)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.AlwaysOnTop = true
	tag.Parent = orb
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = rarity.Color
	label.TextStrokeTransparency = 0
	label.Text = `{power.Name}\nGRAB IT!`
	label.Parent = tag

	orb.Parent = orbs
	TweenService:Create(orb, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		CFrame = orb.CFrame + Vector3.new(0, 1.5, 0),
	}):Play()

	local spawnedAt = os.clock()
	local claimed = false

	orb.Touched:Connect(function(hit)
		if claimed then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not player or not humanoid or humanoid.Health <= 0 or not DataService.Get(player) then
			return
		end
		if player ~= killer and os.clock() - spawnedAt < PowerConfig.ORB_KILLER_PRIORITY then
			return -- the killer gets the first chance
		end

		claimed = true
		orb:Destroy()
		DataService.AddPower(player, powerId, 1)

		if player == owner then
			notify(player, `You got your {power.Name} back!`, rarity.Color)
			return
		end
		notify(player, `You stole {power.Name}!`, rarity.Color)
		notify(owner, `{player.DisplayName} stole your {power.Name}!`, RED)
		if rarity.Rank >= PowerConfig.RarityByName.Legendary.Rank then
			notifyAll(`{player.DisplayName} stole a {string.upper(rarity.Name)} {power.Name} from {owner.DisplayName}!`, rarity.Color)
		end
	end)

	task.delay(PowerConfig.ORB_LIFETIME, function()
		if claimed then
			return
		end
		claimed = true
		orb:Destroy()
		-- Nobody grabbed it in time: it goes home (unless the owner left the game).
		if owner.Parent and DataService.AddPower(owner, powerId, 1) then
			notify(owner, `Nobody grabbed it. Your {power.Name} came back!`, rarity.Color)
		end
	end)
end

-- Knockouts ------------------------------------------------------------------------------

local function onKnockedOut(player, character, humanoid)
	local root = character:FindFirstChild("HumanoidRootPart")
	local position = if root then root.Position else character:GetPivot().Position
	local wasWanted = player:GetAttribute("Wanted") == true

	setStreak(player, 0)
	setWanted(player, false)

	local killer = getKiller(humanoid)
	if not killer or killer == player then
		return
	end

	-- Reward the killer.
	DataService.AddKill(killer)
	DataService.AddCoins(killer, PowerConfig.KILL_REWARD)
	local streak = (streaks[killer] or 0) + 1
	setStreak(killer, streak)
	DataService.RecordStreak(killer, streak)
	notify(killer, `You knocked out {player.DisplayName}! +{PowerConfig.KILL_REWARD} coins`, GOLD)

	if wasWanted then
		DataService.AddCoins(killer, PowerConfig.BOUNTY_REWARD)
		notifyAll(`{killer.DisplayName} claimed the bounty on {player.DisplayName}! +{PowerConfig.BOUNTY_REWARD}`, GOLD)
	end
	if streak == PowerConfig.BOUNTY_STREAK then
		setWanted(killer, true)
		notifyAll(`{killer.DisplayName} is WANTED! Take them down for {PowerConfig.BOUNTY_REWARD} coins`, RED)
	end

	-- Steal the equipped power.
	local data = DataService.Get(player)
	local powerId = data and data.Equipped
	if powerId and DataService.RemovePower(player, powerId, 1) then
		spawnOrb(position + Vector3.new(0, 1, 0), powerId, killer, player)
		notify(player, `Your {PowerConfig.Powers[powerId].Name} dropped! Run back and grab it!`, RED)
	end
end

function StealService.SetupPlayer(player)
	setStreak(player, 0)
	local function onCharacter(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Once(function()
			onKnockedOut(player, character, humanoid)
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

-- Call before saving: leaving while recently hit counts as a knockout.
function StealService.OnPlayerRemoving(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and getKiller(humanoid) then
		onKnockedOut(player, character, humanoid)
	end
	streaks[player] = nil
end

return StealService
