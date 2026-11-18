--!strict
-- Client side raycasting and lookup helpers shared by the controllers.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.LibraryGame.Config)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ClientUtil = {}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
raycastParams.RespectCanCollide = false

local function refreshFilter()
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	raycastParams.FilterDescendantsInstances = exclude
end

refreshFilter()
player.CharacterAdded:Connect(refreshFilter)

function ClientUtil.getMousePosition(): Vector2
	return UserInputService:GetMouseLocation()
end

function ClientUtil.raycastFromScreen(x: number, y: number, maxDistance: number): RaycastResult?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(x, y)
	return Workspace:Raycast(ray.Origin, ray.Direction * maxDistance, raycastParams)
end

function ClientUtil.raycastFromMouse(maxDistance: number): RaycastResult?
	local position = ClientUtil.getMousePosition()
	return ClientUtil.raycastFromScreen(position.X, position.Y, maxDistance)
end

function ClientUtil.findBook(instance: Instance?): Model?
	local current = instance
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local uid = current:GetAttribute("BookUid")
			if typeof(uid) == "string" then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

function ClientUtil.findShelf(instance: Instance?): Model?
	local current = instance
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local shelfId = current:GetAttribute("LibraryShelfId")
			if typeof(shelfId) == "string" then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

-- Marker parts are never hit by rays (CanQuery = false); they are only used
-- for slot geometry and attributes.
function ClientUtil.getNearestSlot(shelfModel: Model, position: Vector3): BasePart?
	local slotsFolder = shelfModel:FindFirstChild("Slots")
	if not slotsFolder then
		return nil
	end

	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, marker in slotsFolder:GetChildren() do
		if marker:IsA("BasePart") and marker:GetAttribute("LibrarySlot") == true then
			local localPosition = marker.CFrame:PointToObjectSpace(position)
			local half = marker.Size / 2
			local inside = math.abs(localPosition.X) <= half.X + 0.35
				and math.abs(localPosition.Y) <= half.Y + 0.45
				and math.abs(localPosition.Z) <= half.Z + 0.9
			if inside then
				return marker
			end
			local distance = (marker.Position - position).Magnitude
			if distance < bestDistance then
				best = marker
				bestDistance = distance
			end
		end
	end
	return best
end

-- Every shelf the server has registered; the id attribute is replicated.
local function getShelfModels(): { Model }
	local list: { Model } = {}
	for _, instance in CollectionService:GetTagged(Config.Shelf.Tag) do
		if instance:IsA("Model") and typeof(instance:GetAttribute("LibraryShelfId")) == "string" then
			table.insert(list, instance)
		end
	end
	return list
end

-- The shelf whose bounds contain this world point (plus padding). Handles the
-- case where the pointer rests on a board, trim or the floor at the shelf foot
-- instead of on a slot volume, so a dangling book still finds its shelf.
function ClientUtil.getShelfContaining(position: Vector3, padding: number): Model?
	local best: Model? = nil
	local bestOverflow = padding
	for _, shelf in getShelfModels() do
		local localPosition = shelf:GetPivot():PointToObjectSpace(position)
		local half = shelf:GetExtentsSize() / 2
		local overflow = math.max(
			math.abs(localPosition.X) - half.X,
			math.abs(localPosition.Y) - half.Y,
			math.abs(localPosition.Z) - half.Z
		)
		if overflow <= bestOverflow then
			best = shelf
			bestOverflow = overflow
		end
	end
	return best
end

function ClientUtil.isPointOver(object: GuiObject?, x: number, y: number): boolean
	if not object then
		return false
	end
	for _, gui in playerGui:GetGuiObjectsAtPosition(x, y) do
		if gui == object or gui:IsDescendantOf(object) then
			return true
		end
	end
	return false
end

function ClientUtil.isPointOverUI(uiRoot: Instance?, x: number, y: number): boolean
	if not uiRoot then
		return false
	end
	for _, gui in playerGui:GetGuiObjectsAtPosition(x, y) do
		if gui:IsDescendantOf(uiRoot) then
			return true
		end
	end
	return false
end

return ClientUtil
