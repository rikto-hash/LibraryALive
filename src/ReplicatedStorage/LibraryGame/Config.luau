--!strict
-- Central tuning for the whole library system.
-- Edit INVENTORY_CAPACITY to change how many books a player can carry.

local Config = {}

Config.INVENTORY_CAPACITY = 2

Config.Book = {
	Gap = 0.04,
	Depth = 0.95,
	MinThickness = 0.45,
	MaxThickness = 0.95,
	MinHeight = 1.65,
	MaxHeight = 2.15,
	ShelfInset = 0.2,
	BottomLift = 0.01,
}

Config.Shelf = {
	Tag = "Bookshelf",
	InitialFill = 0.72,
}

Config.Interaction = {
	MaxPickupDistance = 20,
	MaxPlaceDistance = 24,
	MaxDropDistance = 22,
	DoubleClickWindow = 0.32,
	HoverInterval = 0.05,
	HoverReach = 42,
	HoverHideDelay = 0.18,
	-- How far outside a shelf's bounds a pointer may be and still count as
	-- "on that shelf" (boards, trim and the floor at its foot).
	ShelfSnapPadding = 0.6,
}

Config.Theme = {
	Gold = Color3.fromRGB(247, 201, 96),
	GoldDark = Color3.fromRGB(168, 128, 52),
	Panel = Color3.fromRGB(17, 16, 20),
	PanelSoft = Color3.fromRGB(28, 26, 32),
	Slot = Color3.fromRGB(38, 35, 42),
	Text = Color3.fromRGB(243, 240, 234),
	TextMuted = Color3.fromRGB(166, 160, 152),
	Danger = Color3.fromRGB(226, 92, 84),
}

Config.Wood = {
	Body = Color3.fromRGB(92, 58, 40),
	Board = Color3.fromRGB(126, 83, 51),
	Back = Color3.fromRGB(72, 45, 31),
	Trim = Color3.fromRGB(58, 36, 24),
}

Config.RemoteNames = {
	PickupBook = "PickupBook",
	PlaceBook = "PlaceBook",
	DropBook = "DropBook",
	InventoryUpdated = "InventoryUpdated",
	Notify = "Notify",
}

return Config
