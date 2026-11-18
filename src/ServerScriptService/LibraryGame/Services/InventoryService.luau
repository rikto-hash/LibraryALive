--!strict
-- Per-player book inventory. Capacity lives in Config.INVENTORY_CAPACITY.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.LibraryGame.Config)
local Net = require(ReplicatedStorage.LibraryGame.Net)
local BookService = require(script.Parent.BookService)

local InventoryService = {}

local inventories: { [Player]: { string } } = {}

local function push(player: Player)
	local entries = inventories[player]
	if not entries then
		return
	end

	local payload = {}
	for _, uid in entries do
		local book = BookService.get(uid)
		if book then
			table.insert(payload, { uid = uid, bookId = book.definition.Id })
		end
	end
	if player.Parent == Players then
		Net.InventoryUpdated:FireClient(player, payload)
	end
end

local function onPlayerAdded(player: Player)
	if inventories[player] then
		return
	end
	inventories[player] = {}
	push(player)
end

local function onPlayerRemoving(player: Player)
	local entries = inventories[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local basePosition = Vector3.new(0, 3, 0)
	if root and root:IsA("BasePart") then
		basePosition = root.Position + Vector3.new(0, 0.5, 0)
	else
		local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
		if spawn then
			basePosition = spawn.Position + Vector3.new(0, 3, 0)
		end
	end

	if entries then
		for index, uid in entries do
			local book = BookService.get(uid)
			if book then
				local offset = Vector3.new((index - 1) * 1.2 - 0.6, 0, 0)
				BookService.dropAt(book, basePosition + offset, CFrame.new())
			end
		end
	end
	inventories[player] = nil
end

function InventoryService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function InventoryService.get(player: Player): { string }
	return inventories[player] or {}
end

function InventoryService.count(player: Player): number
	return #InventoryService.get(player)
end

function InventoryService.isFull(player: Player): boolean
	return InventoryService.count(player) >= Config.INVENTORY_CAPACITY
end

function InventoryService.has(player: Player, uid: string): boolean
	return table.find(InventoryService.get(player), uid) ~= nil
end

function InventoryService.add(player: Player, uid: string): boolean
	local entries = inventories[player]
	if not entries then
		return false
	end
	if #entries >= Config.INVENTORY_CAPACITY then
		return false
	end
	if table.find(entries, uid) then
		return false
	end
	table.insert(entries, uid)
	push(player)
	return true
end

function InventoryService.remove(player: Player, uid: string): boolean
	local entries = inventories[player]
	if not entries then
		return false
	end
	local index = table.find(entries, uid)
	if not index then
		return false
	end
	table.remove(entries, index)
	push(player)
	return true
end

function InventoryService.push(player: Player)
	push(player)
end

return InventoryService
