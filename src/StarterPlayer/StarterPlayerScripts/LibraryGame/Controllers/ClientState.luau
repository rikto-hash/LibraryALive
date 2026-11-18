--!strict
-- Shared client state between the interaction controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookCatalog = require(ReplicatedStorage.LibraryGame.BookCatalog)

export type Entry = { uid: string, bookId: string }

export type Definition = {
	Id: string,
	Name: string,
	Genre: string,
	Description: string,
	Published: string,
	Color: Color3,
	Thickness: number?,
	Height: number?,
	Accent: Color3?,
}

local ClientState = {}

ClientState.catalog = {} :: { [string]: Definition }
ClientState.inventory = {} :: { Entry }
ClientState.selectedUid = nil :: string?
ClientState.pinnedUid = nil :: string?
ClientState.displayedUid = nil :: string?
ClientState.draggingUid = nil :: string?

for _, definition in BookCatalog do
	ClientState.catalog[definition.Id] = definition
end

function ClientState.getDefinition(bookId: string): Definition?
	return ClientState.catalog[bookId]
end

function ClientState.getEntry(uid: string): Entry?
	for _, entry in ClientState.inventory do
		if entry.uid == uid then
			return entry
		end
	end
	return nil
end

function ClientState.getThickness(bookId: string): number
	local definition = ClientState.catalog[bookId]
	return if definition and definition.Thickness then definition.Thickness else 0.7
end

return ClientState
