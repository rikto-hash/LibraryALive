--!strict
-- Builds and owns every piece of library UI:
--   * BookDescriptionBox (right side)
--   * Inventory bar (bottom, no text)
--   * circular Drop button (bottom right)
--   * warning toast
--   * shelf slot ghost

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.LibraryGame.Config)
local ClientState = require(script.Parent.ClientState)
local ClientUtil = require(script.Parent.ClientUtil)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UI = {}

UI.onPickup = nil :: (() -> ())?
UI.onDrop = nil :: (() -> ())?

local screenGui: ScreenGui = nil :: any
local descriptionBox: Frame = nil :: any
local boxStroke: UIStroke = nil :: any
local genrePill: TextLabel = nil :: any
local titleLabel: TextLabel = nil :: any
local metaLabel: TextLabel = nil :: any
local divider: Frame = nil :: any
local descriptionLabel: TextLabel = nil :: any
local pickupButton: TextButton = nil :: any
local inventoryBar: Frame = nil :: any
local dropButton: TextButton = nil :: any
local toastFrame: Frame = nil :: any
local toastLabel: TextLabel = nil :: any
local ghost: Part = nil :: any

-- Kept clear of the circular drop button in the bottom right corner. -52
-- fits the tallest catalog description (256 px) above the button on a short
-- 422 px viewport; -34 still left a 16 px overlap.
local BOX_POSITION = UDim2.new(1, -26, 0.5, -52)
local BOX_HIDDEN_POSITION = UDim2.new(1, 18, 0.5, -52)

local slotButtons: { TextButton } = {}
local slotStrokes: { UIStroke } = {}
local slotIcons: { Frame } = {}
local slotBands: { Frame } = {}
local slotUids: { string? } = {}
local displayedDefinition: ClientState.Definition? = nil
local toastToken = 0

local function corner(parent: Instance, radius: number)
	local element = Instance.new("UICorner")
	element.CornerRadius = UDim.new(0, radius)
	element.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number): UIStroke
	local element = Instance.new("UIStroke")
	element.Color = color
	element.Thickness = thickness
	element.Transparency = transparency
	element.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	element.Parent = parent
	return element
end

local function padding(parent: Instance, top: number, right: number, bottom: number, left: number)
	local element = Instance.new("UIPadding")
	element.PaddingTop = UDim.new(0, top)
	element.PaddingRight = UDim.new(0, right)
	element.PaddingBottom = UDim.new(0, bottom)
	element.PaddingLeft = UDim.new(0, left)
	element.Parent = parent
end

local function luminance(color: Color3): number
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

local function readableText(color: Color3): Color3
	if luminance(color) > 0.55 then
		return Color3.fromRGB(24, 20, 16)
	end
	return Color3.fromRGB(252, 248, 240)
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function buildDescriptionBox()
	descriptionBox = Instance.new("Frame")
	descriptionBox.Name = "BookDescriptionBox"
	descriptionBox.AnchorPoint = Vector2.new(1, 0.5)
	descriptionBox.Position = BOX_POSITION
	descriptionBox.Size = UDim2.new(0, 340, 0, 0)
	descriptionBox.AutomaticSize = Enum.AutomaticSize.Y
	descriptionBox.BackgroundColor3 = Config.Theme.Panel
	descriptionBox.BackgroundTransparency = 0.04
	descriptionBox.BorderSizePixel = 0
	descriptionBox.Visible = false
	descriptionBox.ZIndex = 5
	descriptionBox.Parent = screenGui
	corner(descriptionBox, 14)
	boxStroke = stroke(descriptionBox, Config.Theme.Gold, 1.5, 0.15)
	padding(descriptionBox, 18, 18, 18, 18)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Padding = UDim.new(0, 9)
	layout.Parent = descriptionBox

	genrePill = Instance.new("TextLabel")
	genrePill.Name = "Genre"
	genrePill.LayoutOrder = 1
	genrePill.AutomaticSize = Enum.AutomaticSize.XY
	genrePill.Size = UDim2.fromOffset(0, 0)
	genrePill.BackgroundColor3 = Config.Theme.Gold
	genrePill.BackgroundTransparency = 0.1
	genrePill.BorderSizePixel = 0
	genrePill.Font = Enum.Font.GothamMedium
	genrePill.Text = ""
	genrePill.TextSize = 12
	genrePill.TextColor3 = Config.Theme.Panel
	genrePill.Parent = descriptionBox
	padding(genrePill, 4, 9, 4, 9)
	corner(genrePill, 99)

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.LayoutOrder = 2
	titleLabel.Size = UDim2.new(1, 0, 0, 0)
	titleLabel.AutomaticSize = Enum.AutomaticSize.Y
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = ""
	titleLabel.TextSize = 24
	titleLabel.TextWrapped = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Top
	titleLabel.TextColor3 = Config.Theme.Text
	titleLabel.Parent = descriptionBox

	metaLabel = Instance.new("TextLabel")
	metaLabel.Name = "Published"
	metaLabel.LayoutOrder = 3
	metaLabel.Size = UDim2.new(1, 0, 0, 0)
	metaLabel.AutomaticSize = Enum.AutomaticSize.Y
	metaLabel.BackgroundTransparency = 1
	metaLabel.Font = Enum.Font.GothamMedium
	metaLabel.Text = ""
	metaLabel.TextSize = 13
	metaLabel.TextXAlignment = Enum.TextXAlignment.Left
	metaLabel.TextColor3 = Config.Theme.TextMuted
	metaLabel.Parent = descriptionBox

	divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.LayoutOrder = 4
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.BackgroundColor3 = Config.Theme.Gold
	divider.BackgroundTransparency = 0.6
	divider.BorderSizePixel = 0
	divider.Parent = descriptionBox

	descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Name = "Description"
	descriptionLabel.LayoutOrder = 5
	descriptionLabel.Size = UDim2.new(1, 0, 0, 0)
	descriptionLabel.AutomaticSize = Enum.AutomaticSize.Y
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Font = Enum.Font.Gotham
	descriptionLabel.Text = ""
	descriptionLabel.TextSize = 15
	descriptionLabel.LineHeight = 1.15
	descriptionLabel.TextWrapped = true
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
	descriptionLabel.TextColor3 = Config.Theme.Text
	descriptionLabel.Parent = descriptionBox

	pickupButton = Instance.new("TextButton")
	pickupButton.Name = "PickUp"
	pickupButton.LayoutOrder = 6
	pickupButton.Size = UDim2.new(1, 0, 0, 44)
	pickupButton.BackgroundColor3 = Config.Theme.Gold
	pickupButton.BorderSizePixel = 0
	pickupButton.AutoButtonColor = false
	pickupButton.Font = Enum.Font.GothamBold
	pickupButton.Text = "Pick Up"
	pickupButton.TextSize = 16
	pickupButton.TextColor3 = Config.Theme.Panel
	pickupButton.Parent = descriptionBox
	corner(pickupButton, 10)
	stroke(pickupButton, Config.Theme.Gold, 1, 0.2)

	pickupButton.MouseEnter:Connect(function()
		TweenService:Create(pickupButton, TweenInfo.new(0.12), { BackgroundColor3 = lighten(pickupButton.BackgroundColor3, 0.2) }):Play()
	end)
	pickupButton.MouseLeave:Connect(function()
		local color = if displayedDefinition then displayedDefinition.Color else Config.Theme.Gold
		TweenService:Create(pickupButton, TweenInfo.new(0.12), { BackgroundColor3 = color }):Play()
	end)
	pickupButton.Activated:Connect(function()
		if UI.onPickup then
			UI.onPickup()
		end
	end)
end

local function buildInventoryBar()
	inventoryBar = Instance.new("Frame")
	inventoryBar.Name = "InventoryBar"
	inventoryBar.AnchorPoint = Vector2.new(0.5, 1)
	inventoryBar.Position = UDim2.new(0.5, 0, 1, -26)
	inventoryBar.Size = UDim2.new(0, 0, 0, 94)
	inventoryBar.AutomaticSize = Enum.AutomaticSize.X
	inventoryBar.BackgroundColor3 = Config.Theme.Panel
	inventoryBar.BackgroundTransparency = 0.05
	inventoryBar.BorderSizePixel = 0
	inventoryBar.Visible = false
	inventoryBar.ZIndex = 4
	inventoryBar.Parent = screenGui
	corner(inventoryBar, 18)
	stroke(inventoryBar, Config.Theme.GoldDark, 1.5, 0.35)
	padding(inventoryBar, 12, 12, 12, 12)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = inventoryBar

	table.clear(slotButtons)
	table.clear(slotStrokes)
	table.clear(slotIcons)
	table.clear(slotBands)
	table.clear(slotUids)

	for index = 1, Config.INVENTORY_CAPACITY do
		local button = Instance.new("TextButton")
		button.Name = string.format("Slot%d", index)
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(66, 66)
		button.BackgroundColor3 = Config.Theme.Slot
		button.BackgroundTransparency = 0.05
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.ZIndex = 4
		button.Parent = inventoryBar
		corner(button, 10)
		local slotStroke = stroke(button, Config.Theme.PanelSoft, 1, 0.35)

		local icon = Instance.new("Frame")
		icon.Name = "Spine"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.Size = UDim2.fromOffset(22, 50)
		icon.BackgroundColor3 = Config.Theme.Gold
		icon.BorderSizePixel = 0
		icon.Visible = false
		icon.ZIndex = 5
		icon.Parent = button
		corner(icon, 3)

		local band = Instance.new("Frame")
		band.Name = "Band"
		band.AnchorPoint = Vector2.new(0.5, 1)
		band.Position = UDim2.new(0.5, 0, 1, -8)
		band.Size = UDim2.new(1, 2, 0, 5)
		band.BackgroundColor3 = Config.Theme.Gold
		band.BackgroundTransparency = 0.15
		band.BorderSizePixel = 0
		band.Visible = false
		band.ZIndex = 6
		band.Parent = button

		table.insert(slotButtons, button)
		table.insert(slotStrokes, slotStroke)
		table.insert(slotIcons, icon)
		table.insert(slotBands, band)
		table.insert(slotUids, nil)
	end
end

local function buildDropButton()
	dropButton = Instance.new("TextButton")
	dropButton.Name = "DropBookButton"
	dropButton.AnchorPoint = Vector2.new(1, 1)
	dropButton.Position = UDim2.new(1, -26, 1, -26)
	dropButton.Size = UDim2.fromOffset(78, 78)
	dropButton.BackgroundColor3 = Color3.fromRGB(86, 44, 38)
	dropButton.BorderSizePixel = 0
	dropButton.AutoButtonColor = false
	dropButton.Font = Enum.Font.GothamBold
	dropButton.Text = "↓"
	dropButton.TextSize = 34
	dropButton.TextColor3 = Config.Theme.Text
	dropButton.Visible = false
	dropButton.ZIndex = 6
	dropButton.Parent = screenGui
	corner(dropButton, 999)
	stroke(dropButton, Config.Theme.GoldDark, 2, 0.15)

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(124, 66, 56), Color3.fromRGB(54, 26, 24))
	gradient.Parent = dropButton

	dropButton.Activated:Connect(function()
		if UI.onDrop then
			UI.onDrop()
		end
	end)
end

local function buildToast()
	toastFrame = Instance.new("Frame")
	toastFrame.Name = "Toast"
	toastFrame.AnchorPoint = Vector2.new(0.5, 1)
	toastFrame.Position = UDim2.new(0.5, 0, 1, -136)
	toastFrame.AutomaticSize = Enum.AutomaticSize.XY
	toastFrame.Size = UDim2.fromOffset(0, 0)
	toastFrame.BackgroundColor3 = Config.Theme.PanelSoft
	toastFrame.BackgroundTransparency = 0.06
	toastFrame.BorderSizePixel = 0
	toastFrame.Visible = false
	toastFrame.ZIndex = 20
	toastFrame.Parent = screenGui
	corner(toastFrame, 999)
	stroke(toastFrame, Config.Theme.Danger, 1.5, 0.25)
	padding(toastFrame, 9, 18, 9, 18)

	toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "Message"
	toastLabel.AutomaticSize = Enum.AutomaticSize.XY
	toastLabel.Size = UDim2.fromOffset(0, 0)
	toastLabel.BackgroundTransparency = 1
	toastLabel.Font = Enum.Font.GothamMedium
	toastLabel.Text = ""
	toastLabel.TextSize = 15
	toastLabel.TextColor3 = Config.Theme.Text
	toastLabel.ZIndex = 21
	toastLabel.Parent = toastFrame
end

function UI.init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LibraryGameGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	buildDescriptionBox()
	buildInventoryBar()
	buildDropButton()
	buildToast()

	ghost = Instance.new("Part")
	ghost.Name = "LibrarySlotGhost"
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanTouch = false
	ghost.CanQuery = false
	ghost.CastShadow = false
	ghost.Material = Enum.Material.SmoothPlastic
	ghost.Transparency = 1
	ghost.Color = Config.Theme.Gold
	ghost.Size = Vector3.new(1, 1, 1)
	ghost.Parent = Workspace
end

function UI.getRoot(): ScreenGui
	return screenGui
end

function UI.getInventoryBar(): Frame
	return inventoryBar
end

function UI.getDropButton(): TextButton
	return dropButton
end

function UI.getSlotButtons(): { TextButton }
	return slotButtons
end

function UI.showBook(definition: ClientState.Definition)
	displayedDefinition = definition
	boxStroke.Color = definition.Color
	boxStroke.Transparency = 0.08
	divider.BackgroundColor3 = definition.Color
	divider.BackgroundTransparency = 0.55

	titleLabel.Text = definition.Name
	titleLabel.TextColor3 = lighten(definition.Color, 0.58)

	genrePill.Text = definition.Genre
	genrePill.BackgroundColor3 = definition.Color
	genrePill.TextColor3 = readableText(definition.Color)

	metaLabel.Text = "Published " .. definition.Published
	descriptionLabel.Text = definition.Description

	pickupButton.BackgroundColor3 = definition.Color
	pickupButton.TextColor3 = readableText(definition.Color)

	if not descriptionBox.Visible then
		descriptionBox.Visible = true
		descriptionBox.Position = BOX_HIDDEN_POSITION
		TweenService:Create(
			descriptionBox,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = BOX_POSITION }
		):Play()
	end
end

function UI.hideBook()
	descriptionBox.Visible = false
end

function UI.isShowingBook(): boolean
	return descriptionBox.Visible
end

function UI.isPointOverBox(x: number, y: number): boolean
	return ClientUtil.isPointOver(descriptionBox, x, y)
end

function UI.isPointOverUI(x: number, y: number): boolean
	return ClientUtil.isPointOverUI(screenGui, x, y)
end

function UI.setInventory(entries: { ClientState.Entry }, selectedUid: string?)
	for index, button in slotButtons do
		local entry = entries[index]
		slotUids[index] = entry and entry.uid or nil

		local icon = slotIcons[index]
		local band = slotBands[index]
		if entry then
			local definition = ClientState.getDefinition(entry.bookId)
			icon.BackgroundColor3 = if definition then definition.Color else Config.Theme.Gold
			icon.Visible = true
			band.Visible = true
			button.BackgroundTransparency = 0.05
		else
			icon.Visible = false
			band.Visible = false
		end

		local slotStroke = slotStrokes[index]
		if entry and entry.uid == selectedUid then
			slotStroke.Color = Config.Theme.Gold
			slotStroke.Thickness = 2
			slotStroke.Transparency = 0
		else
			slotStroke.Color = Config.Theme.PanelSoft
			slotStroke.Thickness = 1
			slotStroke.Transparency = 0.35
		end
	end

	local hasBooks = #entries > 0
	inventoryBar.Visible = hasBooks
	dropButton.Visible = hasBooks
end

function UI.setSelected(selectedUid: string?)
	for index, slotStroke in slotStrokes do
		if slotUids[index] and slotUids[index] == selectedUid then
			slotStroke.Color = Config.Theme.Gold
			slotStroke.Thickness = 2
			slotStroke.Transparency = 0
		else
			slotStroke.Color = Config.Theme.PanelSoft
			slotStroke.Thickness = 1
			slotStroke.Transparency = 0.35
		end
	end
end

function UI.getSlotUid(index: number): string?
	return slotUids[index]
end

function UI.showToast(kind: string, message: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = message
	if kind == "error" then
		toastFrame.BackgroundColor3 = Color3.fromRGB(46, 22, 22)
	else
		toastFrame.BackgroundColor3 = Config.Theme.PanelSoft
	end
	toastFrame.Visible = true
	toastFrame.BackgroundTransparency = 0.06
	toastLabel.TextTransparency = 0

	task.delay(2.6, function()
		if token ~= toastToken then
			return
		end
		TweenService:Create(toastFrame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(toastLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.delay(0.34, function()
			if token == toastToken then
				toastFrame.Visible = false
			end
		end)
	end)
end

function UI.showGhost(cframe: CFrame, size: Vector3, fits: boolean)
	ghost.CFrame = cframe
	ghost.Size = Vector3.new(math.max(size.X, 0.1), math.max(size.Y, 0.1), math.max(size.Z, 0.1))
	ghost.Color = if fits then Config.Theme.Gold else Config.Theme.Danger
	ghost.Transparency = 0.88
end

function UI.hideGhost()
	ghost.Transparency = 1
end

return UI
