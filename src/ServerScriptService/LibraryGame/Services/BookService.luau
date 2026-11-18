--!strict
-- Owns every book instance and the definition lookup table.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BookCatalog = require(ReplicatedStorage.LibraryGame.BookCatalog)
local BookVisuals = require(ReplicatedStorage.LibraryGame.BookVisuals)

export type Book = {
	uid: string,
	definition: BookVisuals.Definition,
	model: Model,
	location: string,
	ownerUserId: number?,
	shelfId: string?,
	slotIndex: number?,
}

local BookService = {}

local books: { [string]: Book } = {}
local definitions: { [string]: BookVisuals.Definition } = {}
local definitionList: { BookVisuals.Definition } = {}
local nextId = 0

local worldFolder: Folder = nil :: any
local storedFolder: Folder = nil :: any

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

function BookService.init()
	for _, definition in BookCatalog do
		definitions[definition.Id] = definition
		table.insert(definitionList, definition)
	end

	local workspaceRoot = ensureFolder(Workspace, "LibraryGame")
	worldFolder = ensureFolder(workspaceRoot, "WorldBooks")

	local storageRoot = ensureFolder(ServerStorage, "LibraryGame")
	storedFolder = ensureFolder(storageRoot, "StoredBooks")
end

function BookService.get(uid: string): Book?
	return books[uid]
end

function BookService.count(): number
	local total = 0
	for _ in books do
		total += 1
	end
	return total
end

function BookService.getDefinition(id: string): BookVisuals.Definition?
	return definitions[id]
end

function BookService.getDefinitions(): { BookVisuals.Definition }
	return definitionList
end

function BookService.getThickness(book: Book): number
	return BookVisuals.getThickness(book.definition)
end

function BookService.getHeight(book: Book): number
	return BookVisuals.getHeight(book.definition)
end

function BookService.spawn(definitionId: string, parent: Instance?): Book?
	local definition = definitions[definitionId]
	if not definition then
		return nil
	end

	nextId += 1
	local uid = string.format("book_%d", nextId)
	local model = BookVisuals.create(definition)
	model.Name = definition.Name
	model:SetAttribute("BookUid", uid)
	model:SetAttribute("BookId", definition.Id)
	model.Parent = parent or worldFolder

	local book: Book = {
		uid = uid,
		definition = definition,
		model = model,
		location = "World",
	}
	books[uid] = book
	return book
end

function BookService.getFromInstance(instance: Instance?): Book?
	local current = instance
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local uid = current:GetAttribute("BookUid")
			if typeof(uid) == "string" then
				return books[uid]
			end
		end
		current = current.Parent
	end
	return nil
end

function BookService.moveToInventory(book: Book, player: Player)
	book.location = "Inventory"
	book.ownerUserId = player.UserId
	book.shelfId = nil
	book.slotIndex = nil
	book.model:SetAttribute("ShelfId", nil)
	book.model:SetAttribute("OwnerUserId", player.UserId)
	book.model.Parent = storedFolder
end

function BookService.moveToShelf(book: Book, destination: Instance, shelfId: string, slotIndex: number)
	book.location = "Shelf"
	book.ownerUserId = nil
	book.shelfId = shelfId
	book.slotIndex = slotIndex
	book.model:SetAttribute("OwnerUserId", nil)
	book.model:SetAttribute("ShelfId", shelfId)
	book.model.Parent = destination
end

function BookService.dropAt(book: Book, bottomCenter: Vector3, rotation: CFrame)
	book.location = "World"
	book.ownerUserId = nil
	book.shelfId = nil
	book.slotIndex = nil
	book.model:SetAttribute("OwnerUserId", nil)
	book.model:SetAttribute("ShelfId", nil)
	book.model.Parent = worldFolder
	BookVisuals.setPose(book.model, bottomCenter, rotation)
end

function BookService.getRandomDefinition(rng: Random): BookVisuals.Definition?
	if #definitionList == 0 then
		return nil
	end
	return definitionList[rng:NextInteger(1, #definitionList)]
end

return BookService
