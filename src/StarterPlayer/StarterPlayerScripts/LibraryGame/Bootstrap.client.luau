--!strict
-- Client entry point. Builds the HUD, then starts the controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.LibraryGame.Net)
local Controllers = script.Parent:WaitForChild("Controllers")
local UI = require(Controllers.UIController)
local InventoryController = require(Controllers.InventoryController)
local WorldInteractionController = require(Controllers.WorldInteractionController)

UI.init()

Net.Notify.OnClientEvent:Connect(function(kind, message)
	if typeof(kind) == "string" and typeof(message) == "string" then
		UI.showToast(kind, message)
	end
end)

InventoryController.init()
WorldInteractionController.init()
