--!strict
-- Builds the 3D book model for a catalog entry.
-- The model pivot is the centre of the book, and its local +Z axis is the spine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Config)

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

local BookVisuals = {}

local GOLD = Color3.fromRGB(226, 190, 120)
local PAGES = Color3.fromRGB(238, 232, 214)

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material, castShadow: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = castShadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

function BookVisuals.getThickness(definition: Definition): number
	return definition.Thickness or 0.7
end

function BookVisuals.getHeight(definition: Definition): number
	return definition.Height or 1.9
end

function BookVisuals.getDepth(): number
	return Config.Book.Depth
end

function BookVisuals.create(definition: Definition): Model
	local thickness = BookVisuals.getThickness(definition)
	local height = BookVisuals.getHeight(definition)
	local depth = Config.Book.Depth
	local accent = definition.Accent or GOLD

	local model = Instance.new("Model")
	model.Name = definition.Name

	local cover = newPart("Cover", Vector3.new(thickness, height, depth), definition.Color, Enum.Material.Fabric, true)
	cover.CFrame = CFrame.new()
	cover.Parent = model

	local band = newPart("Band", Vector3.new(thickness + 0.018, 0.075, depth + 0.018), accent, Enum.Material.Metal, false)
	band.CFrame = CFrame.new(0, -height * 0.32, 0)
	band.Parent = model

	local label = newPart("SpineLabel", Vector3.new(math.min(thickness * 0.72, 0.5), height * 0.16, 0.035), accent, Enum.Material.SmoothPlastic, false)
	label.CFrame = CFrame.new(0, height * 0.1, depth / 2 + 0.012)
	label.Parent = model

	local pages = newPart("Pages", Vector3.new(thickness * 0.86, 0.05, depth * 0.9), PAGES, Enum.Material.SmoothPlastic, false)
	pages.CFrame = CFrame.new(0, height / 2, 0)
	pages.Parent = model

	model.PrimaryPart = cover
	model:SetAttribute("BookThickness", thickness)
	model:SetAttribute("BookHeight", height)
	model:SetAttribute("BookDepth", depth)
	return model
end

-- Places the book so that its bottom centre sits at bottomCenter and its spine
-- points along rotation's +Z axis.
function BookVisuals.setPose(model: Model, bottomCenter: Vector3, rotation: CFrame)
	local height = model:GetAttribute("BookHeight")
	if typeof(height) ~= "number" then
		height = 1.9
	end
	local target = CFrame.new(bottomCenter + Vector3.new(0, height / 2, 0)) * rotation
	model:PivotTo(target)
end

return BookVisuals
