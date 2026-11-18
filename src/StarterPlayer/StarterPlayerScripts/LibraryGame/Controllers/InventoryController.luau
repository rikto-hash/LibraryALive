--!strict
-- Owns the inventory bar behaviour: remote updates, slot selection, dragging a
-- book out into the world and the circular drop button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.LibraryGame.Config)
local Net = require(ReplicatedStorage.LibraryGame.Net)
local ClientState = require(script.Parent.ClientState)
local ClientUtil = require(script.Parent.ClientUtil)
local UI = require(script.Parent.UIController)

local player = Players.LocalPlayer

local InventoryController = {}

local dragGui: ScreenGui? = nil
local dragIcon: Frame? = nil
local dragMoved = false
local dragStart = Vector2.zero

local function fallbackAim(camera: Camera): Vector3
	return camera.CFrame.Position + camera.CFrame.LookVector * 8
end

-- The drop button drops wherever the camera is pointing, not wherever the
-- button happens to sit under the mouse.
local function cameraAim(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local viewport = camera.ViewportSize
	local result = ClientUtil.raycastFromScreen(viewport.X / 2, viewport.Y / 2, Config.Interaction.MaxDropDistance)
	if result then
		return result.Position
	end
	return fallbackAim(camera)
end

local function select(uid: string?)
	ClientState.selectedUid = uid
	UI.setSelected(uid)
end

-- Fires PlaceBook for the slot that best matches a world point. Falls back to
-- the shelf whose bounds contain the point, so releasing on a board, a trim
-- piece or the floor at the shelf foot still places instead of dropping.
local function placeOnShelf(uid: string, position: Vector3, instance: Instance?): boolean
	local shelf = ClientUtil.findShelf(instance)
		or ClientUtil.getShelfContaining(position, Config.Interaction.ShelfSnapPadding)
	if not shelf then
		return false
	end
	local marker = ClientUtil.getNearestSlot(shelf, position)
	if not marker then
		return false
	end
	local shelfId = marker:GetAttribute("LibraryShelfId")
	local slotIndex = marker:GetAttribute("LibrarySlotIndex")
	if typeof(shelfId) ~= "string" or typeof(slotIndex) ~= "number" then
		return false
	end
	Net.PlaceBook:FireServer(uid, shelfId, slotIndex, position)
	return true
end

local function tryPlaceAt(uid: string, point: Vector2): boolean
	local result = ClientUtil.raycastFromScreen(point.X, point.Y, Config.Interaction.MaxPlaceDistance)
	if not result then
		return false
	end
	return placeOnShelf(uid, result.Position, result.Instance)
end

local function dropBook(uid: string, position: Vector3)
	Net.DropBook:FireServer(uid, position)
end

local function ensureDragVisuals()
	if dragGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LibraryGameDrag"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	dragGui = gui

	local icon = Instance.new("Frame")
	icon.Name = "DragIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Size = UDim2.fromOffset(34, 62)
	icon.BackgroundColor3 = Config.Theme.Gold
	icon.BackgroundTransparency = 0.1
	icon.BorderSizePixel = 0
	icon.Visible = false
	icon.ZIndex = 2
	icon.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = icon

	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0.5, 1)
	band.Position = UDim2.new(0.5, 0, 1, -9)
	band.Size = UDim2.new(1, 2, 0, 6)
	band.BackgroundColor3 = Config.Theme.Gold
	band.BackgroundTransparency = 0.15
	band.BorderSizePixel = 0
	band.ZIndex = 3
	band.Parent = icon

	dragIcon = icon
end

local function finishDrag(x: number, y: number)
	local uid = ClientState.draggingUid
	ClientState.draggingUid = nil
	dragMoved = false
	UI.hideGhost()
	if dragIcon then
		dragIcon.Visible = false
	end
	if not uid then
		return
	end

	if ClientUtil.isPointOver(UI.getInventoryBar(), x, y) then
		return
	end

	-- The release coordinates from InputObject.Position and the pointer the
	-- hover code reads can differ by the GUI inset, so both are release points.
	local points: { Vector2 } = { Vector2.new(x, y) }
	local mouse = ClientUtil.getMousePosition()
	if (mouse - points[1]).Magnitude > 1 then
		table.insert(points, mouse)
	end

	for _, point in points do
		if tryPlaceAt(uid, point) then
			return
		end
	end

	-- Not a shelf: drop where the pointer hit, or use the camera centre the
	-- drop button uses when the release landed on nothing at all.
	for _, point in points do
		local result = ClientUtil.raycastFromScreen(point.X, point.Y, Config.Interaction.MaxDropDistance)
		if result then
			if placeOnShelf(uid, result.Position, result.Instance) then
				return
			end
			dropBook(uid, result.Position)
			return
		end
	end

	local camera = Workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize
		local centre = ClientUtil.raycastFromScreen(viewport.X / 2, viewport.Y / 2, Config.Interaction.MaxDropDistance)
		if centre then
			if placeOnShelf(uid, centre.Position, centre.Instance) then
				return
			end
			dropBook(uid, centre.Position)
			return
		end
	end

	local aim = cameraAim()
	if aim then
		dropBook(uid, aim)
	end
end

function InventoryController.init()
	ensureDragVisuals()

	Net.InventoryUpdated.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end

		local entries: { ClientState.Entry } = {}
		for _, item in payload do
			if typeof(item) == "table"
				and typeof(item.uid) == "string"
				and typeof(item.bookId) == "string"
			then
				table.insert(entries, { uid = item.uid, bookId = item.bookId })
			end
		end

		local known: { [string]: boolean } = {}
		for _, entry in ClientState.inventory do
			known[entry.uid] = true
		end

		local newest: string? = nil
		for _, entry in entries do
			if not known[entry.uid] then
				newest = entry.uid
			end
		end

		ClientState.inventory = entries

		local keep = ClientState.selectedUid
		if keep and not ClientState.getEntry(keep) then
			keep = nil
		end
		if newest then
			keep = newest
		end
		if not keep and #entries > 0 then
			keep = entries[#entries].uid
		end

		UI.setInventory(entries, keep)
		select(keep)
	end)

	UI.onDrop = function()
		local uid = ClientState.selectedUid
		if not uid then
			return
		end
		local aim = cameraAim()
		if aim then
			dropBook(uid, aim)
		end
	end

	local slotButtons = UI.getSlotButtons()
	for index, button in slotButtons do
		button.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local uid = UI.getSlotUid(index)
			if not uid then
				return
			end

			local entry = ClientState.getEntry(uid)
			local definition = if entry then ClientState.getDefinition(entry.bookId) else nil
			if dragIcon then
				dragIcon.BackgroundColor3 = if definition then definition.Color else Config.Theme.Gold
				dragIcon.Position = UDim2.fromOffset(input.Position.X, input.Position.Y)
				dragIcon.Visible = true
			end
			ClientState.draggingUid = uid
			dragMoved = false
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
		end)
	end

	UserInputService.InputChanged:Connect(function(input)
		if not ClientState.draggingUid or not dragIcon then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local position = Vector2.new(input.Position.X, input.Position.Y)
		if (position - dragStart).Magnitude > 6 then
			dragMoved = true
		end
		dragIcon.Position = UDim2.fromOffset(position.X, position.Y)
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not ClientState.draggingUid then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local uid = ClientState.draggingUid
		if not dragMoved then
			ClientState.draggingUid = nil
			if dragIcon then
				dragIcon.Visible = false
			end
			select(if ClientState.selectedUid == uid then nil else uid)
			return
		end

		finishDrag(input.Position.X, input.Position.Y)
	end)
end

return InventoryController
