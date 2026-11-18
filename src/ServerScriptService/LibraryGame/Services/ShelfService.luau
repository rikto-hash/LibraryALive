--!strict
-- Discovers tagged bookshelves, decorates them, builds shelf slots and keeps
-- the books on each shelf packed side by side.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.LibraryGame.Config)
local BookVisuals = require(ReplicatedStorage.LibraryGame.BookVisuals)
local BookService = require(script.Parent.BookService)

export type Slot = {
	index: number,
	shelfId: string,
	marker: BasePart,
	origin: Vector3,
	rightAxis: Vector3,
	rotation: CFrame,
	width: number,
	height: number,
	books: { string },
}

type Shelf = {
	id: string,
	model: Model,
	booksFolder: Folder,
	slots: { Slot },
}

type Entry = { part: BasePart, cf: CFrame }

type SlotGeometry = {
	center: Vector3,
	size: Vector3,
	origin: Vector3,
	rightAxis: Vector3,
	rotation: CFrame,
	width: number,
	height: number,
}

type Analysis = {
	pivot: CFrame,
	min: Vector3,
	max: Vector3,
	boards: { Entry },
	sides: { Entry },
	back: Entry?,
	boardZ: number,
	boardDepth: number,
	frontSign: number,
	width: number,
	height: number,
	depth: number,
	midX: number,
	leftInner: number,
	rightInner: number,
	frontEdgeZ: number,
	slots: { SlotGeometry },
}

local ShelfService = {}

local shelves: { [string]: Shelf } = {}
local shelfOrder: { Shelf } = {}
local animations: { [Model]: thread } = {}
local shelfCounter = 0
local started = false

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function vectorMin(a: Vector3, b: Vector3): Vector3
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end

local function vectorMax(a: Vector3, b: Vector3): Vector3
	return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end

local function analyze(model: Model): Analysis?
	local pivot = model:GetPivot()
	local inverse = pivot:Inverse()
	local entries: { Entry } = {}
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = -min

	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("LibraryTrim") ~= true then
			local cf = inverse * child.CFrame
			table.insert(entries, { part = child, cf = cf })
			min = vectorMin(min, cf.Position - child.Size / 2)
			max = vectorMax(max, cf.Position + child.Size / 2)
		end
	end

	if #entries == 0 then
		return nil
	end

	local width = max.X - min.X
	local height = max.Y - min.Y
	local depth = max.Z - min.Z
	local midX = (min.X + max.X) / 2

	local boards: { Entry } = {}
	local sides: { Entry } = {}
	local back: Entry? = nil

	for _, entry in entries do
		local size = entry.part.Size
		if size.Y <= 0.8 and size.X >= width * 0.45 then
			table.insert(boards, entry)
		elseif size.X <= 0.8 and size.Y >= height * 0.45 then
			table.insert(sides, entry)
		elseif size.Z <= 0.8 and size.X >= width * 0.45 and size.Y >= height * 0.45 then
			back = entry
		end
	end

	if #boards < 2 then
		return nil
	end

	table.sort(boards, function(a, b)
		return a.cf.Position.Y < b.cf.Position.Y
	end)

	local boardZ = boards[1].cf.Position.Z
	local boardDepth = boards[1].part.Size.Z
	local backZ = if back then back.cf.Position.Z else boardZ + boardDepth / 2
	local frontSign = if boardZ >= backZ then 1 else -1

	local leftInner = min.X + 0.15
	local rightInner = max.X - 0.15
	for _, entry in sides do
		local half = entry.part.Size.X / 2
		if entry.cf.Position.X < midX then
			leftInner = math.max(leftInner, entry.cf.Position.X + half)
		else
			rightInner = math.min(rightInner, entry.cf.Position.X - half)
		end
	end

	local frontEdgeZ = boardZ + frontSign * boardDepth / 2
	local bookCenterZ = frontEdgeZ - frontSign * (Config.Book.ShelfInset + Config.Book.Depth / 2)

	local frontAxis = pivot:VectorToWorldSpace(Vector3.new(0, 0, frontSign)).Unit
	local rightAxis = Vector3.yAxis:Cross(frontAxis).Unit
	local rotation = CFrame.fromMatrix(Vector3.zero, rightAxis, Vector3.yAxis, frontAxis)
	local rightLocal = pivot:VectorToObjectSpace(rightAxis)
	local startX = if rightLocal.X >= 0 then leftInner else rightInner

	local slotList: { SlotGeometry } = {}
	for index = 1, #boards - 1 do
		local lower = boards[index]
		local upper = boards[index + 1]
		local floorY = lower.cf.Position.Y + lower.part.Size.Y / 2
		local ceilingY = upper.cf.Position.Y - upper.part.Size.Y / 2
		local slotHeight = ceilingY - floorY
		if slotHeight >= 1.0 then
			local center = Vector3.new((leftInner + rightInner) / 2, (floorY + ceilingY) / 2, boardZ)
			table.insert(slotList, {
				center = center,
				size = Vector3.new(rightInner - leftInner, slotHeight, boardDepth),
				origin = pivot:PointToWorldSpace(Vector3.new(startX, floorY + Config.Book.BottomLift, bookCenterZ)),
				rightAxis = rightAxis,
				rotation = rotation,
				width = rightInner - leftInner,
				height = slotHeight,
			})
		end
	end

	return {
		pivot = pivot,
		min = min,
		max = max,
		boards = boards,
		sides = sides,
		back = back,
		boardZ = boardZ,
		boardDepth = boardDepth,
		frontSign = frontSign,
		width = width,
		height = height,
		depth = depth,
		midX = midX,
		leftInner = leftInner,
		rightInner = rightInner,
		frontEdgeZ = frontEdgeZ,
		slots = slotList,
	}
end

local function makeTrim(parent: Folder, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("LibraryTrim", true)
	part.Parent = parent
end

local function decorate(model: Model, info: Analysis)
	if model:GetAttribute("LibraryDecorated") == true then
		return
	end
	model:SetAttribute("LibraryDecorated", true)

	for _, entry in info.boards do
		entry.part.Color = Config.Wood.Board
		entry.part.Material = Enum.Material.Wood
	end
	for _, entry in info.sides do
		entry.part.Color = Config.Wood.Body
		entry.part.Material = Enum.Material.Wood
	end
	if info.back then
		info.back.part.Color = Config.Wood.Back
		info.back.part.Material = Enum.Material.Wood
	end

	local trimFolder = ensureFolder(model, "Trim")
	local pivot = info.pivot
	local midY = (info.min.Y + info.max.Y) / 2
	local leftEdge = info.min.X + 0.15
	local rightEdge = info.max.X - 0.15

	makeTrim(
		trimFolder,
		"Crown",
		Vector3.new(info.width + 0.5, 0.34, info.depth + 0.45),
		pivot * CFrame.new(info.midX, info.max.Y + 0.15, info.boardZ),
		Config.Wood.Trim,
		Enum.Material.Wood
	)
	makeTrim(
		trimFolder,
		"CrownInlay",
		Vector3.new(info.width - 0.6, 0.05, 0.05),
		pivot * CFrame.new(info.midX, info.max.Y - 0.06, info.frontEdgeZ + info.frontSign * 0.02),
		Config.Theme.Gold,
		Enum.Material.Metal
	)
	makeTrim(
		trimFolder,
		"BasePlinth",
		Vector3.new(info.width + 0.28, 0.18, info.depth + 0.16),
		pivot * CFrame.new(info.midX, info.min.Y + 0.09, info.boardZ),
		Config.Wood.Trim,
		Enum.Material.Wood
	)

	for index, entry in info.boards do
		local top = entry.cf.Position.Y + entry.part.Size.Y / 2
		makeTrim(
			trimFolder,
			string.format("ShelfLip%d", index),
			Vector3.new(info.width - 0.3, 0.13, 0.1),
			pivot * CFrame.new(info.midX, top + 0.065, info.frontEdgeZ - info.frontSign * 0.03),
			Config.Wood.Trim,
			Enum.Material.Wood
		)
	end

	makeTrim(
		trimFolder,
		"PilasterLeft",
		Vector3.new(0.17, info.height - 0.2, 0.14),
		pivot * CFrame.new(leftEdge + 0.085, midY, info.frontEdgeZ - info.frontSign * 0.07),
		Config.Wood.Trim,
		Enum.Material.Wood
	)
	makeTrim(
		trimFolder,
		"PilasterRight",
		Vector3.new(0.17, info.height - 0.2, 0.14),
		pivot * CFrame.new(rightEdge - 0.085, midY, info.frontEdgeZ - info.frontSign * 0.07),
		Config.Wood.Trim,
		Enum.Material.Wood
	)
end

local function usedWidth(slot: Slot): number
	local total = 0
	for index, uid in slot.books do
		local book = BookService.get(uid)
		if book then
			if index > 1 then
				total += Config.Book.Gap
			end
			total += BookService.getThickness(book)
		end
	end
	return total
end

local function updateMarker(slot: Slot)
	slot.marker:SetAttribute("LibraryBookCount", #slot.books)
	slot.marker:SetAttribute("LibraryRemaining", math.max(0, slot.width - usedWidth(slot)))
end

local function moveBook(model: Model, bottom: Vector3, rotation: CFrame, animate: boolean)
	local existing = animations[model]
	if existing then
		task.cancel(existing)
		animations[model] = nil
	end

	local height = model:GetAttribute("BookHeight")
	if typeof(height) ~= "number" then
		height = 1.9
	end
	local target = CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * rotation

	if not animate then
		model:PivotTo(target)
		return
	end

	local start = model:GetPivot()
	if (start.Position - target.Position).Magnitude < 0.002 then
		model:PivotTo(target)
		return
	end

	local startedAt = os.clock()
	local duration = 0.26
	local thread = task.spawn(function()
		while true do
			local alpha = math.min((os.clock() - startedAt) / duration, 1)
			model:PivotTo(start:Lerp(target, alpha))
			if alpha >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		animations[model] = nil
	end)
	animations[model] = thread
end

local function reflow(slot: Slot, animate: boolean)
	local cursor = 0
	for _, uid in slot.books do
		local book = BookService.get(uid)
		if book then
			local thickness = BookService.getThickness(book)
			local bottom = slot.origin + slot.rightAxis * (cursor + thickness / 2)
			moveBook(book.model, bottom, slot.rotation, animate)
			cursor += thickness + Config.Book.Gap
		end
	end
	updateMarker(slot)
end

local function buildShelf(model: Model): Shelf?
	local info = analyze(model)
	if not info then
		warn("LibraryGame: shelf geometry not recognised on " .. model:GetFullName())
		return nil
	end

	local existingId = model:GetAttribute("LibraryShelfId")
	local shelfId: string
	if typeof(existingId) == "string" then
		shelfId = existingId
	else
		shelfCounter += 1
		shelfId = string.format("shelf_%02d", shelfCounter)
		model:SetAttribute("LibraryShelfId", shelfId)
	end

	local booksFolder = ensureFolder(model, "Books")
	local slotsFolder = ensureFolder(model, "Slots")
	for _, child in slotsFolder:GetChildren() do
		child:Destroy()
	end

	local slots: { Slot } = {}
	for index, geometry in info.slots do
		local marker = Instance.new("Part")
		marker.Name = string.format("Slot%d", index)
		marker.Size = geometry.size
		marker.CFrame = info.pivot * CFrame.new(geometry.center)
		marker.Transparency = 1
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = false
		marker.CastShadow = false
		marker:SetAttribute("LibrarySlot", true)
		marker:SetAttribute("LibraryShelfId", shelfId)
		marker:SetAttribute("LibrarySlotIndex", index)
		marker:SetAttribute("LibrarySlotWidth", geometry.width)
		marker:SetAttribute("LibrarySlotHeight", geometry.height)
		marker:SetAttribute("LibraryBookCount", 0)
		marker:SetAttribute("LibraryRemaining", geometry.width)
		marker.Parent = slotsFolder

		table.insert(slots, {
			index = index,
			shelfId = shelfId,
			marker = marker,
			origin = geometry.origin,
			rightAxis = geometry.rightAxis,
			rotation = geometry.rotation,
			width = geometry.width,
			height = geometry.height,
			books = {},
		})
	end

	decorate(model, info)

	local shelf: Shelf = {
		id = shelfId,
		model = model,
		booksFolder = booksFolder,
		slots = slots,
	}
	shelves[shelfId] = shelf
	table.insert(shelfOrder, shelf)
	return shelf
end

function ShelfService.init()
	local workspaceRoot = ensureFolder(Workspace, "LibraryGame")
	ensureFolder(workspaceRoot, "ShelfSlots")

	for _, model in CollectionService:GetTagged(Config.Shelf.Tag) do
		if model:IsA("Model") then
			buildShelf(model)
		end
	end

	CollectionService:GetInstanceAddedSignal(Config.Shelf.Tag):Connect(function(model)
		if not model:IsA("Model") then
			return
		end
		local existingId = model:GetAttribute("LibraryShelfId")
		if typeof(existingId) == "string" and shelves[existingId] then
			return
		end
		local shelf = buildShelf(model)
		if shelf and started then
			ShelfService.fillShelf(shelf)
		end
	end)
end

function ShelfService.getCount(): number
	return #shelfOrder
end

function ShelfService.getSlotCount(): number
	local total = 0
	for _, shelf in shelfOrder do
		total += #shelf.slots
	end
	return total
end

function ShelfService.getSlot(shelfId: string, index: number): Slot?
	local shelf = shelves[shelfId]
	if not shelf then
		return nil
	end
	for _, slot in shelf.slots do
		if slot.index == index then
			return slot
		end
	end
	return nil
end

function ShelfService.findSlotAt(shelfId: string, position: Vector3): Slot?
	local shelf = shelves[shelfId]
	if not shelf then
		return nil
	end

	local best: Slot? = nil
	local bestDistance = math.huge
	for _, slot in shelf.slots do
		local localPosition = slot.marker.CFrame:PointToObjectSpace(position)
		local half = slot.marker.Size / 2
		local inside = math.abs(localPosition.X) <= half.X + 0.35
			and math.abs(localPosition.Y) <= half.Y + 0.45
			and math.abs(localPosition.Z) <= half.Z + 0.9
		if inside then
			return slot
		end
		local distance = (slot.marker.Position - position).Magnitude
		if distance < bestDistance then
			best = slot
			bestDistance = distance
		end
	end
	return best
end

function ShelfService.getInsertIndex(slot: Slot, position: Vector3): number
	local along = (position - slot.origin):Dot(slot.rightAxis)
	local cursor = 0
	for index, uid in slot.books do
		local book = BookService.get(uid)
		if book then
			local thickness = BookService.getThickness(book)
			if along < cursor + thickness / 2 then
				return index
			end
			cursor += thickness + Config.Book.Gap
		end
	end
	return #slot.books + 1
end

function ShelfService.canPlace(book: BookService.Book, slot: Slot): boolean
	local required = usedWidth(slot) + BookService.getThickness(book)
	if #slot.books > 0 then
		required += Config.Book.Gap
	end
	return required <= slot.width + 0.001
end

function ShelfService.placeBook(book: BookService.Book, slot: Slot, insertIndex: number): (boolean, string?)
	local shelf = shelves[slot.shelfId]
	if not shelf then
		return false, "That shelf is no longer available."
	end
	if not ShelfService.canPlace(book, slot) then
		return false, "There is no room left on this shelf."
	end
	if book.location == "Shelf" and book.shelfId and book.slotIndex then
		ShelfService.removeBook(book)
	end

	local index = math.clamp(insertIndex, 1, #slot.books + 1)
	table.insert(slot.books, index, book.uid)
	BookService.moveToShelf(book, shelf.booksFolder, shelf.id, slot.index)
	reflow(slot, true)
	return true, nil
end

function ShelfService.removeBook(book: BookService.Book): boolean
	if not book.shelfId or not book.slotIndex then
		return false
	end
	local slot = ShelfService.getSlot(book.shelfId, book.slotIndex)
	if not slot then
		return false
	end
	local index = table.find(slot.books, book.uid)
	if not index then
		return false
	end
	table.remove(slot.books, index)
	book.shelfId = nil
	book.slotIndex = nil
	reflow(slot, true)
	return true
end

function ShelfService.fillShelf(shelf: Shelf)
	local rng = Random.new(20261117 + shelf.id:len() * 31 + #shelfOrder)
	for _, slot in shelf.slots do
		local targetWidth = slot.width * Config.Shelf.InitialFill
		while true do
			local chosen: BookVisuals.Definition? = nil
			for _ = 1, 8 do
				local definition = BookService.getRandomDefinition(rng)
				if definition then
					local required = usedWidth(slot) + BookVisuals.getThickness(definition)
					if #slot.books > 0 then
						required += Config.Book.Gap
					end
					if required <= targetWidth then
						chosen = definition
					end
				end
				if chosen then
					break
				end
			end
			if not chosen then
				break
			end
			local book = BookService.spawn(chosen.Id, shelf.booksFolder)
			if not book then
				break
			end
			book.location = "Shelf"
			book.shelfId = shelf.id
			book.slotIndex = slot.index
			table.insert(slot.books, book.uid)
		end
		reflow(slot, false)
	end
end

function ShelfService.start()
	started = true
	for _, shelf in shelfOrder do
		ShelfService.fillShelf(shelf)
	end
end

return ShelfService
