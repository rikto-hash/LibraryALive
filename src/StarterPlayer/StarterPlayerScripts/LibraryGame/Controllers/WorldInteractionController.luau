--!strict
-- Hover highlight, description box, click-to-pin, double-click pickup and the
-- translucent preview of where a carried book will land on a shelf.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.LibraryGame.Config)
local Net = require(ReplicatedStorage.LibraryGame.Net)
local ClientState = require(script.Parent.ClientState)
local ClientUtil = require(script.Parent.ClientUtil)
local UI = require(script.Parent.UIController)

local WorldInteraction = {}

local highlight: Highlight? = nil
local hoveredUid: string? = nil
local hoveredModel: Model? = nil
local lastHoverSeen = 0
local lastClickUid: string? = nil
local lastClickAt = 0
local lastHoverUpdate = 0

local function clearHover()
	hoveredUid = nil
	hoveredModel = nil
	if highlight then
		highlight.Adornee = nil
	end
end

local function hideBox()
	clearHover()
	UI.hideGhost()
	UI.hideBook()
	ClientState.displayedUid = nil
	ClientState.pinnedUid = nil
end

local function showBook(model: Model): boolean
	local uid = model:GetAttribute("BookUid")
	local bookId = model:GetAttribute("BookId")
	if typeof(uid) ~= "string" or typeof(bookId) ~= "string" then
		return false
	end

	local definition = ClientState.getDefinition(bookId)
	if not definition then
		return false
	end

	hoveredUid = uid
	hoveredModel = model
	ClientState.displayedUid = uid
	if highlight then
		highlight.Adornee = model
	end
	UI.showBook(definition)
	return true
end

-- Where the carried book would sit if dropped into this slot marker.
local function previewGhost(marker: BasePart)
	local selectedUid = ClientState.selectedUid
	local entry = if selectedUid then ClientState.getEntry(selectedUid) else nil
	if not entry then
		UI.hideGhost()
		return
	end

	local definition = ClientState.getDefinition(entry.bookId)
	local thickness = if definition and definition.Thickness then definition.Thickness else 0.7
	local height = if definition and definition.Height then definition.Height else 1.9

	local count = marker:GetAttribute("LibraryBookCount")
	local remaining = marker:GetAttribute("LibraryRemaining")
	local gap = if typeof(count) == "number" and count > 0 then Config.Book.Gap else 0
	local fits = typeof(remaining) == "number" and remaining >= thickness + gap

	local forwardOffset = marker.Size.Z / 2 - Config.Book.ShelfInset - Config.Book.Depth / 2
	local cframe = marker.CFrame * CFrame.new(0, -marker.Size.Y / 2 + height / 2 + Config.Book.BottomLift, -forwardOffset)
	UI.showGhost(cframe, Vector3.new(thickness, height, Config.Book.Depth), fits)
end

local function updateHover()
	if ClientState.draggingUid then
		return
	end

	local mouse = UserInputService:GetMouseLocation()

	-- Keep whatever is on screen while the pointer sits over the box itself.
	if UI.isPointOverBox(mouse.X, mouse.Y) then
		lastHoverSeen = os.clock()
		return
	end
	if UI.isPointOverUI(mouse.X, mouse.Y) then
		return
	end

	local result = ClientUtil.raycastFromMouse(Config.Interaction.HoverReach)
	local bookModel = if result then ClientUtil.findBook(result.Instance) else nil

	if bookModel then
		local uid = bookModel:GetAttribute("BookUid")
		if uid ~= hoveredUid then
			showBook(bookModel)
		end
		lastHoverSeen = os.clock()
		UI.hideGhost()
		return
	end

	local shelfModel = if result
		then ClientUtil.findShelf(result.Instance)
			or ClientUtil.getShelfContaining(result.Position, Config.Interaction.ShelfSnapPadding)
		else nil
	if shelfModel and ClientState.selectedUid and result then
		local marker = ClientUtil.getNearestSlot(shelfModel, result.Position)
		if marker then
			previewGhost(marker)
		else
			UI.hideGhost()
		end
	else
		UI.hideGhost()
	end

	if ClientState.pinnedUid == nil
		and ClientState.displayedUid ~= nil
		and os.clock() - lastHoverSeen > Config.Interaction.HoverHideDelay
	then
		hideBox()
	end
end

local function handleClick()
	local mouse = UserInputService:GetMouseLocation()
	if UI.isPointOverUI(mouse.X, mouse.Y) then
		return
	end

	local result = ClientUtil.raycastFromMouse(Config.Interaction.HoverReach)
	local bookModel = if result then ClientUtil.findBook(result.Instance) else nil

	if bookModel then
		local uid = bookModel:GetAttribute("BookUid")
		if typeof(uid) ~= "string" then
			return
		end
		if not showBook(bookModel) then
			return
		end

		lastHoverSeen = os.clock()
		local now = os.clock()
		if lastClickUid == uid and (now - lastClickAt) <= Config.Interaction.DoubleClickWindow then
			lastClickUid = nil
			lastClickAt = 0
			hideBox()
			Net.PickupBook:FireServer(uid)
			return
		end

		lastClickUid = uid
		lastClickAt = now
		ClientState.pinnedUid = uid
		return
	end

	local shelfModel = if result
		then ClientUtil.findShelf(result.Instance)
			or ClientUtil.getShelfContaining(result.Position, Config.Interaction.ShelfSnapPadding)
		else nil
	local selectedUid = ClientState.selectedUid
	if shelfModel and selectedUid and result then
		local marker = ClientUtil.getNearestSlot(shelfModel, result.Position)
		if marker then
			local shelfId = marker:GetAttribute("LibraryShelfId")
			local slotIndex = marker:GetAttribute("LibrarySlotIndex")
			if typeof(shelfId) == "string" and typeof(slotIndex) == "number" then
				Net.PlaceBook:FireServer(selectedUid, shelfId, slotIndex, result.Position)
				UI.hideGhost()
				return
			end
		end
	end

	lastClickUid = nil
	lastClickAt = 0
	hideBox()
end

function WorldInteraction.init()
	local hover = Instance.new("Highlight")
	hover.Name = "LibraryHoverHighlight"
	hover.DepthMode = Enum.HighlightDepthMode.Occluded
	hover.FillTransparency = 1
	hover.OutlineTransparency = 0
	hover.OutlineColor = Config.Theme.Gold
	hover.Adornee = nil
	hover.Parent = Workspace
	highlight = hover

	UI.onPickup = function()
		local uid = ClientState.displayedUid
		if not uid then
			return
		end
		hideBox()
		Net.PickupBook:FireServer(uid)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		handleClick()
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now - lastHoverUpdate < Config.Interaction.HoverInterval then
			return
		end
		lastHoverUpdate = now
		updateHover()
	end)
end

return WorldInteraction
