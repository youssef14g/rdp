-- UI (ModuleScript in StarterPlayerScripts)
-- Builds every screen element from code, so you don't have to make any GUI by hand.
-- ClientMain calls these functions; this file only draws things.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local PowerConfig = require(ReplicatedStorage:WaitForChild("PowerConfig"))

local UI = {}

local player = Players.LocalPlayer

local THEME = {
	Panel = Color3.fromRGB(20, 22, 30),
	PanelLight = Color3.fromRGB(36, 40, 54),
	Stroke = Color3.fromRGB(70, 75, 95),
	Text = Color3.fromRGB(240, 240, 245),
	Muted = Color3.fromRGB(160, 165, 180),
	Gold = Color3.fromRGB(255, 200, 40),
	Accent = Color3.fromRGB(80, 200, 255),
	Danger = Color3.fromRGB(255, 70, 70),
	Disabled = Color3.fromRGB(70, 72, 82),
	Spin = Color3.fromRGB(60, 190, 90),
}
local FONT = Enum.Font.GothamBold
local MAX_TOASTS = 4

local refs: { [string]: any } = {} -- the screen elements we update later
local callbacks: { [string]: any } = {} -- OnSpin, OnEquip, OnMerge, set by ClientMain
local currentData = nil
local toastCount = 0
local spinToken = 0

-- Small building helpers --------------------------------------------------------------

local function make(className, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = props.Parent
	return instance
end

local function rounded(radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function border(color, thickness)
	return make("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function text(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = THEME.Text,
		TextSize = 18,
		TextStrokeTransparency = 0.6,
		Size = UDim2.fromScale(1, 1),
	}
	for key, value in props do
		defaults[key] = value
	end
	return make("TextLabel", defaults)
end

local function button(props)
	local defaults = {
		Font = FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 18,
		TextStrokeTransparency = 0.6,
		AutoButtonColor = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return make("TextButton", defaults, { rounded(10) })
end

local function formatNumber(number)
	local digits = tostring(math.floor(number))
	local withCommas = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (withCommas:gsub("^,", ""))
end

local function starsText(stars)
	return string.rep("★", stars) .. string.rep("☆", PowerConfig.MAX_STARS - stars)
end

-- Building the screen -----------------------------------------------------------------

local function buildStats(gui)
	local panel = make("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(230, 76),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { rounded(12), border(THEME.Stroke, 1.5) })
	refs.Coins = text({
		Text = "Loading...",
		TextColor3 = THEME.Gold,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 32),
		Parent = panel,
	})
	refs.Kills = text({
		Text = "",
		TextColor3 = THEME.Muted,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, 22),
		Parent = panel,
	})
end

local function buildMenu(gui)
	local menu = make("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.45, 0),
		Size = UDim2.fromOffset(170, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.SpinButton = button({
		Name = "Spin",
		Text = `SPIN  ({PowerConfig.SPIN_COST} coins)`,
		BackgroundColor3 = THEME.Spin,
		Size = UDim2.fromOffset(170, 54),
		LayoutOrder = 1,
		Parent = menu,
	})
	refs.SpinButton.Activated:Connect(function()
		callbacks.OnSpin()
	end)
	local powersButton = button({
		Name = "Powers",
		Text = "POWERS",
		BackgroundColor3 = Color3.fromRGB(110, 70, 220),
		Size = UDim2.fromOffset(170, 54),
		LayoutOrder = 2,
		Parent = menu,
	})
	powersButton.Activated:Connect(function()
		UI.ToggleInventory()
	end)
end

local function buildAbilityBar(gui)
	local bar = make("Frame", {
		Name = "Abilities",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(340, 70),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local function slot(name, title, keyHint, order)
		local frame = make("Frame", {
			Name = name,
			Size = UDim2.fromOffset(160, 70),
			BackgroundColor3 = THEME.Panel,
			BackgroundTransparency = 0.1,
			LayoutOrder = order,
			Parent = bar,
		}, { rounded(12) })
		local outline = border(THEME.Stroke, 2)
		outline.Parent = frame
		local titleLabel = text({
			Text = title,
			TextSize = 18,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 26),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
		text({
			Text = if touchOnly then "Tap the button" else keyHint,
			TextColor3 = THEME.Muted,
			TextSize = 14,
			Position = UDim2.fromOffset(8, 40),
			Size = UDim2.new(1, -16, 0, 20),
			Parent = frame,
		})
		local cover = make("Frame", {
			Name = "Cooldown",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			ZIndex = 2,
			Parent = frame,
		}, { rounded(12) })
		local timer = text({ Text = "", TextSize = 26, ZIndex = 3, Parent = frame })
		return { Title = titleLabel, Outline = outline, Cover = cover, Timer = timer, Token = 0 }
	end

	refs.Slots = {
		Punch = slot("Punch", "PUNCH", "Click / F", 1),
		Power = slot("Power", "No power", "E", 2),
	}
end

local function buildBannerAndToasts(gui)
	refs.SafeBanner = text({
		Text = "SAFE ZONE  -  no damage, change powers here",
		TextColor3 = THEME.Accent,
		TextSize = 16,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(420, 30),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		Parent = gui,
	})
	rounded(8).Parent = refs.SafeBanner

	refs.Toasts = make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(480, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		make("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function buildSpinPopup(gui)
	local popup = make("Frame", {
		Name = "SpinPopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(360, 220),
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { rounded(16) })
	refs.SpinScale = make("UIScale", { Parent = popup })
	refs.SpinOutline = border(THEME.Stroke, 3)
	refs.SpinOutline.Parent = popup
	refs.SpinPopup = popup
	refs.SpinRarity = text({ TextSize = 22, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 28), ZIndex = 11, Parent = popup })
	refs.SpinName = text({ TextSize = 38, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 50), ZIndex = 11, Parent = popup })
	refs.SpinDescription = text({
		TextSize = 16,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		Position = UDim2.fromOffset(16, 108),
		Size = UDim2.new(1, -32, 0, 40),
		ZIndex = 11,
		Parent = popup,
	})
	refs.SpinClose = button({
		Text = "NICE!",
		BackgroundColor3 = THEME.Spin,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(140, 42),
		ZIndex = 11,
		Parent = popup,
	})
	refs.SpinClose.Activated:Connect(function()
		popup.Visible = false
	end)
end

local function buildInventory(gui)
	local panel = make("Frame", {
		Name = "Inventory",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.8),
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	}, {
		rounded(16),
		border(THEME.Stroke, 2),
		make("UISizeConstraint", { MaxSize = Vector2.new(480, 420) }),
	})
	refs.Inventory = panel
	text({
		Text = "YOUR POWERS",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -80, 0, 30),
		ZIndex = 6,
		Parent = panel,
	})
	text({
		Text = "Your EQUIPPED power drops if you get knocked out. Change powers in the Safe Zone.",
		TextSize = 13,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.new(1, -32, 0, 34),
		ZIndex = 6,
		Parent = panel,
	})
	local close = button({
		Text = "X",
		BackgroundColor3 = THEME.Danger,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(36, 36),
		ZIndex = 6,
		Parent = panel,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	refs.InventoryList = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 86),
		Size = UDim2.new(1, -24, 1, -98),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 6,
		Parent = panel,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

-- Inventory rows -------------------------------------------------------------------------

local function inventoryRow(order, powerId, count, stars, equipped)
	local power = PowerConfig.Powers[powerId]
	local rarity = PowerConfig.GetRarityOf(powerId)

	local row = make("Frame", {
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = THEME.PanelLight,
		LayoutOrder = order,
		ZIndex = 6,
		Parent = refs.InventoryList,
	}, { rounded(10) })
	if equipped then
		border(rarity.Color, 2).Parent = row
	end
	make("Frame", {
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = rarity.Color,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = row,
	}, { rounded(3) })
	text({
		Text = if equipped then `{power.Name}  (equipped)` else power.Name,
		TextColor3 = rarity.Color,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -200, 0, 24),
		ZIndex = 7,
		Parent = row,
	})
	text({
		Text = `{rarity.Name}  x{count}  {starsText(stars)}`,
		TextColor3 = THEME.Muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 36),
		Size = UDim2.new(1, -200, 0, 20),
		ZIndex = 7,
		Parent = row,
	})

	local equipButton = button({
		Text = if equipped then "UNEQUIP" else "EQUIP",
		BackgroundColor3 = if equipped then THEME.Danger else THEME.Accent,
		TextSize = 14,
		Position = UDim2.new(1, -176, 0.5, -18),
		Size = UDim2.fromOffset(80, 36),
		ZIndex = 7,
		Parent = row,
	})
	equipButton.Activated:Connect(function()
		callbacks.OnEquip(if equipped then nil else powerId)
	end)

	local maxed = stars >= PowerConfig.MAX_STARS
	local canMerge = count >= PowerConfig.MERGE_COPIES and not maxed
	local mergeButton = button({
		Text = if maxed then "MAX" else `MERGE {count}/{PowerConfig.MERGE_COPIES}`,
		BackgroundColor3 = if canMerge then THEME.Gold else THEME.Disabled,
		AutoButtonColor = canMerge,
		TextSize = 13,
		Position = UDim2.new(1, -88, 0.5, -18),
		Size = UDim2.fromOffset(80, 36),
		ZIndex = 7,
		Parent = row,
	})
	if canMerge then
		mergeButton.Activated:Connect(function()
			callbacks.OnMerge(powerId)
		end)
	end
end

local function renderInventory()
	for _, child in refs.InventoryList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not currentData then
		return
	end

	local ids = {}
	for powerId, count in currentData.Owned do
		if count > 0 and PowerConfig.Powers[powerId] then
			table.insert(ids, powerId)
		end
	end
	-- Rarest first, then by name.
	table.sort(ids, function(a, b)
		local rankA, rankB = PowerConfig.GetRarityOf(a).Rank, PowerConfig.GetRarityOf(b).Rank
		if rankA ~= rankB then
			return rankA > rankB
		end
		return PowerConfig.Powers[a].Name < PowerConfig.Powers[b].Name
	end)

	if #ids == 0 then
		text({
			Text = "No powers yet. Press SPIN!",
			TextColor3 = THEME.Muted,
			Size = UDim2.new(1, 0, 0, 40),
			ZIndex = 7,
			Parent = refs.InventoryList,
		})
		return
	end
	for order, powerId in ids do
		inventoryRow(order, powerId, currentData.Owned[powerId], currentData.Stars[powerId] or 0, currentData.Equipped == powerId)
	end
end

-- Public functions ---------------------------------------------------------------------

function UI.Init(newCallbacks)
	callbacks = newCallbacks
	local gui = make("ScreenGui", {
		Name = "GameUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildStats(gui)
	buildMenu(gui)
	buildAbilityBar(gui)
	buildBannerAndToasts(gui)
	buildSpinPopup(gui)
	buildInventory(gui)
end

function UI.SetData(data)
	currentData = data
	refs.Coins.Text = `{formatNumber(data.Coins)} coins`

	local slot = refs.Slots.Power
	if data.Equipped then
		local power = PowerConfig.Powers[data.Equipped]
		local rarity = PowerConfig.GetRarityOf(data.Equipped)
		local stars = data.Stars[data.Equipped] or 0
		slot.Title.Text = if stars > 0 then `{power.Name} {string.rep("★", stars)}` else power.Name
		slot.Title.TextColor3 = rarity.Color
		slot.Outline.Color = rarity.Color
	else
		slot.Title.Text = "No power"
		slot.Title.TextColor3 = THEME.Muted
		slot.Outline.Color = THEME.Stroke
	end

	if refs.Inventory.Visible then
		renderInventory()
	end
end

function UI.SetKills(kills, streak, wanted)
	local line = `{kills} kills   streak {streak}`
	refs.Kills.Text = if wanted then line .. "   WANTED!" else line
	refs.Kills.TextColor3 = if wanted then THEME.Danger else THEME.Muted
end

function UI.ToggleInventory()
	refs.Inventory.Visible = not refs.Inventory.Visible
	if refs.Inventory.Visible then
		renderInventory()
	end
end

function UI.SetSpinBusy(busy)
	refs.SpinButton.AutoButtonColor = not busy
	refs.SpinButton.BackgroundColor3 = if busy then THEME.Disabled else THEME.Spin
end

function UI.SetSafeZone(inside)
	refs.SafeBanner.Visible = inside
end

function UI.StartCooldown(slotName, duration)
	local slot = refs.Slots[slotName]
	if not slot then
		return
	end
	slot.Token += 1
	local token = slot.Token
	slot.Cover.Size = UDim2.fromScale(1, 1)
	TweenService:Create(slot.Cover, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1, 0),
	}):Play()
	task.spawn(function()
		local endsAt = os.clock() + duration
		while slot.Token == token and os.clock() < endsAt do
			slot.Timer.Text = string.format("%.1f", endsAt - os.clock())
			task.wait(0.1)
		end
		if slot.Token == token then
			slot.Timer.Text = ""
		end
	end)
end

function UI.Toast(message, color)
	toastCount += 1
	local toast = text({
		Text = message,
		TextColor3 = color or THEME.Text,
		TextSize = 17,
		TextWrapped = true,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.2,
		Size = UDim2.fromOffset(460, 34),
		AutomaticSize = Enum.AutomaticSize.Y, -- grows for long messages
		LayoutOrder = toastCount,
		Parent = refs.Toasts,
	})
	rounded(8).Parent = toast

	-- Keep only the newest few.
	local shown = {}
	for _, child in refs.Toasts:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(shown, child)
		end
	end
	table.sort(shown, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #shown - MAX_TOASTS do
		shown[i]:Destroy()
	end

	task.delay(3.5, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.4), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				BackgroundTransparency = 1,
			}):Play()
			Debris:AddItem(toast, 0.45)
		end
	end)
end

-- Rolls through random names, slowing down, then reveals the real result. Yields.
function UI.PlaySpin(powerId)
	spinToken += 1
	local token = spinToken
	local popup = refs.SpinPopup
	popup.Visible = true
	refs.SpinClose.Visible = false
	refs.SpinDescription.Text = ""
	refs.SpinRarity.Text = "SPINNING..."
	refs.SpinRarity.TextColor3 = THEME.Muted
	refs.SpinOutline.Color = THEME.Stroke

	local pool = {}
	for _, power in PowerConfig.PowerList do
		if power.Rarity ~= "Default" then
			table.insert(pool, power)
		end
	end
	local delay = 0.05
	while delay < 0.3 do
		local power = pool[math.random(1, #pool)]
		refs.SpinName.Text = power.Name
		refs.SpinName.TextColor3 = PowerConfig.RarityByName[power.Rarity].Color
		task.wait(delay)
		delay *= 1.18
	end

	local power = PowerConfig.Powers[powerId]
	local rarity = PowerConfig.GetRarityOf(powerId)
	refs.SpinRarity.Text = string.upper(rarity.Name)
	refs.SpinRarity.TextColor3 = rarity.Color
	refs.SpinName.Text = power.Name
	refs.SpinName.TextColor3 = rarity.Color
	refs.SpinDescription.Text = power.Description
	refs.SpinOutline.Color = rarity.Color
	refs.SpinClose.Visible = true

	-- A little "pop" so the reveal feels good.
	refs.SpinScale.Scale = 1.25
	TweenService:Create(refs.SpinScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	task.delay(4, function()
		if spinToken == token then
			popup.Visible = false
		end
	end)
end

-- Floating "-22" over whoever you hit.
function UI.DamageNumber(position, amount)
	local attachment = Instance.new("Attachment")
	attachment.Position = position + Vector3.new(math.random(-10, 10) / 10, 2.5, 0)
	attachment.Parent = workspace.Terrain
	local billboard = make("BillboardGui", {
		Size = UDim2.fromOffset(100, 40),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = attachment,
	})
	local label = text({
		Text = `-{amount}`,
		TextColor3 = THEME.Danger,
		TextSize = 28,
		TextStrokeTransparency = 0,
		Parent = billboard,
	})
	TweenService:Create(billboard, TweenInfo.new(0.8), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(attachment, 0.9)
end

return UI
