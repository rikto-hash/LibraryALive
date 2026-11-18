--!strict
-- Server entry point: starts every service in order, then fills the shelves.

local Services = script.Parent:WaitForChild("Services")
local BookService = require(Services.BookService)
local ShelfService = require(Services.ShelfService)
local InventoryService = require(Services.InventoryService)
local InteractionService = require(Services.InteractionService)
local DataService = require(Services.DataService)

DataService.init()
BookService.init()
ShelfService.init()
InventoryService.init()
InteractionService.init()

ShelfService.start()

print(string.format(
	"LibraryGame ready: %d shelves, %d slots, %d books",
	ShelfService.getCount(),
	ShelfService.getSlotCount(),
	BookService.count()
))
