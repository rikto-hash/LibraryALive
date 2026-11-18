--!strict
-- Typed access to the shared LibraryGame remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = ReplicatedStorage:WaitForChild("LibraryGame")
local remotes = root:WaitForChild("Remotes")

local Net = {
	PickupBook = remotes:WaitForChild("PickupBook") :: RemoteEvent,
	PlaceBook = remotes:WaitForChild("PlaceBook") :: RemoteEvent,
	DropBook = remotes:WaitForChild("DropBook") :: RemoteEvent,
	InventoryUpdated = remotes:WaitForChild("InventoryUpdated") :: RemoteEvent,
	Notify = remotes:WaitForChild("Notify") :: RemoteEvent,
}

return Net
