--!strict
-- Server side of all book interactions. Every remote argument is validated,
-- every action is rate limited and distance checked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.LibraryGame.Config)
local Net = require(ReplicatedStorage.LibraryGame.Net)
local BookService = require(script.Parent.BookService)
local ShelfService = require(script.Parent.ShelfService)
local InventoryService = require(script.Parent.InventoryService)
local Validate = require(script.Parent.Parent.Validate)
local DataService = require(script.Parent.DataService)

local InteractionService = {}

local allowAction = Validate.rateLimiter(30, 1)

local function notify(player: Player, kind: string, message: string)
	Net.Notify:FireClient(player, kind, message)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isNear(player: Player, position: Vector3, maxDistance: number): boolean
	local root = getRoot(player)
	if not root then
		return false
	end
	return (root.Position - position).Magnitude <= maxDistance
end

Net.PickupBook.OnServerEvent:Connect(function(player, uid)
	if not allowAction(player) then
		return
	end
	local validUid = Validate.string(uid, 64)
	if not validUid then
		return
	end

	local book = BookService.get(validUid)
	if not book or book.location == "Inventory" then
		return
	end
	if not isNear(player, book.model:GetPivot().Position, Config.Interaction.MaxPickupDistance) then
		notify(player, "error", "You are too far away to pick that up.")
		return
	end
	if InventoryService.isFull(player) then
		notify(player, "error", "Your hands are full. Drop a book first.")
		return
	end

	local wasOnShelf = book.location == "Shelf"

	if not InventoryService.add(player, validUid) then
		notify(player, "error", "Your hands are full. Drop a book first.")
		return
	end

	if wasOnShelf then
		if not ShelfService.removeBook(book) then
			InventoryService.remove(player, validUid)
			notify(player, "error", "That book is no longer on the shelf.")
			return
		end
	end

	BookService.moveToInventory(book, player)
end)

Net.PlaceBook.OnServerEvent:Connect(function(player, uid, shelfId, slotIndex, hitPosition)
	if not allowAction(player) then
		return
	end
	local validUid = Validate.string(uid, 64)
	local validShelfId = Validate.string(shelfId, 64)
	local validIndex = Validate.integer(slotIndex, 1, 64)
	local validPosition = Validate.vector3(hitPosition, 100000)
	if not validUid or not validShelfId or not validIndex or not validPosition then
		return
	end

	local book = BookService.get(validUid)
	if not book or not InventoryService.has(player, validUid) then
		return
	end

	local requested = ShelfService.getSlot(validShelfId, validIndex)
	if not requested then
		return
	end

	local slot = ShelfService.findSlotAt(validShelfId, validPosition) or requested
	if not isNear(player, slot.marker.Position, Config.Interaction.MaxPlaceDistance) then
		notify(player, "error", "You are too far from that shelf.")
		return
	end
	if not ShelfService.canPlace(book, slot) then
		notify(player, "error", "There is no room left on this shelf.")
		return
	end

	local insertIndex = ShelfService.getInsertIndex(slot, validPosition)
	if not InventoryService.remove(player, validUid) then
		return
	end

	local ok, message = ShelfService.placeBook(book, slot, insertIndex)
	if not ok then
		InventoryService.add(player, validUid)
		notify(player, "error", message or "Could not place that book.")
	else
		DataService.incrementStat(player, "BooksShelved", 1)
	end
end)

Net.DropBook.OnServerEvent:Connect(function(player, uid, position)
	if not allowAction(player) then
		return
	end
	local validUid = Validate.string(uid, 64)
	local validPosition = Validate.vector3(position, 100000)
	if not validUid or not validPosition then
		return
	end

	local book = BookService.get(validUid)
	if not book or not InventoryService.has(player, validUid) then
		return
	end

	local root = getRoot(player)
	if not root then
		return
	end

	if (root.Position - validPosition).Magnitude > Config.Interaction.MaxDropDistance then
		validPosition = root.Position + root.CFrame.LookVector * 3
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local libraryRoot = Workspace:FindFirstChild("LibraryGame")
	if libraryRoot then
		table.insert(exclude, libraryRoot)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true

	local result = Workspace:Raycast(validPosition + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	local floorPosition = if result then result.Position else Vector3.new(validPosition.X, root.Position.Y - 2.5, validPosition.Z)

	local flat = root.Position - floorPosition
	flat = Vector3.new(flat.X, 0, flat.Z)
	local rotation = CFrame.new()
	if flat.Magnitude > 0.01 then
		local forward = flat.Unit
		local right = Vector3.yAxis:Cross(forward).Unit
		rotation = CFrame.fromMatrix(Vector3.zero, right, Vector3.yAxis, forward)
	end

	if not InventoryService.remove(player, validUid) then
		return
	end
	BookService.dropAt(book, floorPosition + Vector3.new(0, 0.02, 0), rotation)
end)

function InteractionService.init() end

function InteractionService.start() end

return InteractionService
