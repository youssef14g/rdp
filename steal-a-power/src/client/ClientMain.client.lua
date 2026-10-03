-- ClientMain (LocalScript in StarterPlayerScripts)
-- Controls and talking to the server. Works on PC, mobile and controller.
--   PC:         Click or F = Punch, E = Power (aims at your mouse)
--   Mobile:     PUNCH and POWER buttons (aims where the camera looks)
--   Controller: X = Punch, R2 = Power

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))
local UI = require(script.Parent:WaitForChild("UI"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local RED = Color3.fromRGB(255, 90, 90)
local GOLD = Color3.fromRGB(255, 200, 40)
local AIM_DISTANCE = 500

local currentData = nil
local cooldownEnds = { Punch = 0, Power = 0 }
local inSafeZone = false
local lastWarning = 0
local spinning = false

local function warnOnce(message)
	if os.clock() - lastWarning > 2 then
		lastWarning = os.clock()
		UI.Toast(message, RED)
	end
end

-- Aiming ------------------------------------------------------------------------------

-- Where the player is aiming in the world: the mouse on PC,
-- the middle of the screen on mobile and controller.
local function getAimPoint()
	local screenPoint
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		screenPoint = UserInputService:GetMouseLocation()
	else
		screenPoint = camera.ViewportSize / 2
	end
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)

	-- Don't aim at yourself or at effects.
	local ignore = {}
	for _, name in { "Effects", "Orbs" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
	return if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE
end

-- Attacking -----------------------------------------------------------------------------

local function use(slot)
	if not currentData then
		return
	end
	if inSafeZone then
		warnOnce("You can't fight inside the Safe Zone")
		return
	end
	if slot == "Power" and not currentData.Equipped then
		warnOnce("No power equipped. Open POWERS in the Safe Zone")
		return
	end
	if os.clock() < cooldownEnds[slot] then
		return
	end
	-- A tiny local wait so holding the key doesn't spam the server.
	-- The real cooldown comes back from the server in the Cooldown event.
	cooldownEnds[slot] = os.clock() + 0.15
	remotes.UsePower:FireServer(slot, getAimPoint())
end

local function onAction(actionName, inputState)
	if inputState == Enum.UserInputState.Begin then
		use(if actionName == "PunchAction" then "Punch" else "Power")
	end
	return Enum.ContextActionResult.Sink
end

-- `true` also creates an on-screen button on mobile.
ContextActionService:BindAction("PunchAction", onAction, true, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("PunchAction", "PUNCH")
ContextActionService:BindAction("PowerAction", onAction, true, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)
ContextActionService:SetTitle("PowerAction", "POWER")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		use("Punch")
	end
end)

-- Menu buttons ----------------------------------------------------------------------------

local function ask(remote, ...)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false, err = "Something went wrong, try again" }
	end
	return result
end

UI.Init({
	OnSpin = function()
		if spinning then
			return
		end
		spinning = true
		UI.SetSpinBusy(true)
		local result = ask(remotes.Spin)
		if result.ok then
			UI.PlaySpin(result.powerId)
		else
			UI.Toast(result.err, RED)
		end
		UI.SetSpinBusy(false)
		spinning = false
	end,

	OnEquip = function(powerId)
		local result = ask(remotes.Equip, powerId)
		if not result.ok then
			UI.Toast(result.err, RED)
		end
	end,

	OnMerge = function(powerId)
		local result = ask(remotes.Merge, powerId)
		if result.ok then
			UI.Toast(`{PowerConfig.Powers[powerId].Name} is now {string.rep("★", result.stars)}`, GOLD)
		else
			UI.Toast(result.err, RED)
		end
	end,
})

-- Messages from the server -----------------------------------------------------------------

local welcomed = false
remotes.DataUpdated.OnClientEvent:Connect(function(data)
	currentData = data
	UI.SetData(data)
	if not welcomed then
		welcomed = true
		if next(data.Owned) == nil then
			UI.Toast("Welcome! Press SPIN to get your first power", GOLD)
		end
	end
	UI.SetKills(data.Kills, player:GetAttribute("Streak") or 0, player:GetAttribute("Wanted") == true)
end)

local function refreshKills()
	if currentData then
		UI.SetKills(currentData.Kills, player:GetAttribute("Streak") or 0, player:GetAttribute("Wanted") == true)
	end
end
player:GetAttributeChangedSignal("Streak"):Connect(refreshKills)
player:GetAttributeChangedSignal("Wanted"):Connect(refreshKills)

remotes.Cooldown.OnClientEvent:Connect(function(slot, duration)
	cooldownEnds[slot] = os.clock() + duration
	UI.StartCooldown(slot, duration)
end)

remotes.Notify.OnClientEvent:Connect(function(message, color)
	UI.Toast(message, color)
end)

remotes.DamageDealt.OnClientEvent:Connect(function(position, amount)
	UI.DamageNumber(position, amount)
end)

-- Safe zone banner (checked a few times per second) -----------------------------------------

local sinceCheck = 0
RunService.Heartbeat:Connect(function(dt)
	sinceCheck += dt
	if sinceCheck < 0.25 then
		return
	end
	sinceCheck = 0
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local inside = root ~= nil and PowerConfig.IsInSafeZone(root.Position)
	if inside ~= inSafeZone then
		inSafeZone = inside
		UI.SetSafeZone(inside)
	end
end)
