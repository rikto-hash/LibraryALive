--!strict
-- The single place to edit book data.
--
-- To add a book, copy one block and change the values:
--   Id          unique id (no spaces, never reuse an old id)
--   Name        title shown in the BookDescriptionBox
--   Genre       short genre label
--   Description a sentence or two about the book
--   Published   publication year / date text
--   Color       the book colour, also used as the description box theme colour
--   Thickness   optional, spine thickness in studs (0.45 - 0.95 recommended)
--   Height      optional, book height in studs (1.65 - 2.15 recommended)
--
-- Any new book is automatically added to the libraries and can be picked up.

export type BookDefinition = {
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

local BookCatalog: { BookDefinition } = {
	{
		Id = "silent_orchard",
		Name = "The Silent Orchard",
		Genre = "Literary Fiction",
		Description = "A quiet gardener discovers that every tree she plants remembers a promise someone once broke beneath its branches.",
		Published = "1973",
		Color = Color3.fromRGB(122, 66, 52),
		Thickness = 0.72,
		Height = 2.02,
	},
	{
		Id = "cartographers_daughter",
		Name = "The Cartographer's Daughter",
		Genre = "Adventure",
		Description = "Armed with her father's unfinished maps, a young woman sails past the last marked coastline of the known world.",
		Published = "1988",
		Color = Color3.fromRGB(38, 72, 112),
		Thickness = 0.66,
		Height = 1.95,
	},
	{
		Id = "salt_and_starlight",
		Name = "Salt and Starlight",
		Genre = "Fantasy",
		Description = "Tide-witches bargain with fallen constellations to keep their drowned city breathing for one more winter.",
		Published = "2004",
		Color = Color3.fromRGB(76, 44, 104),
		Thickness = 0.88,
		Height = 2.1,
	},
	{
		Id = "engine_of_small_things",
		Name = "The Engine of Small Things",
		Genre = "Science",
		Description = "A patient tour through the tiny mechanisms, from enzymes to transistors, that quietly run the modern world.",
		Published = "2011",
		Color = Color3.fromRGB(46, 96, 90),
		Thickness = 0.58,
		Height = 1.86,
	},
	{
		Id = "letters_from_the_tide",
		Name = "Letters from the Tide",
		Genre = "Poetry",
		Description = "Sixty short poems written on ferry crossings, collected across thirty years of salt-stained notebooks.",
		Published = "1961",
		Color = Color3.fromRGB(176, 120, 54),
		Thickness = 0.52,
		Height = 1.74,
	},
	{
		Id = "the_quiet_archive",
		Name = "The Quiet Archive",
		Genre = "Mystery",
		Description = "A night archivist finds a file that has been checked out every year since 1952 by someone long dead.",
		Published = "1996",
		Color = Color3.fromRGB(52, 52, 60),
		Thickness = 0.78,
		Height = 2.04,
	},
	{
		Id = "hounds_of_harrow_moor",
		Name = "Hounds of Harrow Moor",
		Genre = "Horror",
		Description = "The village dogs stop barking at dusk, and the mist begins to walk uphill against the wind.",
		Published = "1982",
		Color = Color3.fromRGB(86, 32, 32),
		Thickness = 0.84,
		Height = 2.08,
	},
	{
		Id = "a_map_of_ordinary_days",
		Name = "A Map of Ordinary Days",
		Genre = "Memoir",
		Description = "A baker's account of the small rituals that held a neighborhood together through a decade of change.",
		Published = "2017",
		Color = Color3.fromRGB(150, 92, 96),
		Thickness = 0.62,
		Height = 1.92,
	},
	{
		Id = "the_glass_catalogue",
		Name = "The Glass Catalogue",
		Genre = "Art History",
		Description = "The rise and ruin of a family of Venetian glassmakers, told through the objects that survived their furnaces.",
		Published = "2008",
		Color = Color3.fromRGB(58, 104, 132),
		Thickness = 0.7,
		Height = 2.0,
	},
	{
		Id = "roots_and_remedies",
		Name = "Roots and Remedies",
		Genre = "Nature",
		Description = "A practical field companion to the medicinal plants of the northern woods, with careful warnings for lookalikes.",
		Published = "1994",
		Color = Color3.fromRGB(70, 98, 52),
		Thickness = 0.56,
		Height = 1.8,
	},
	{
		Id = "midnight_at_the_observatory",
		Name = "Midnight at the Observatory",
		Genre = "Astronomy",
		Description = "One sleepless night at a mountain observatory, and the century-old argument that finally gets settled there.",
		Published = "1979",
		Color = Color3.fromRGB(36, 44, 86),
		Thickness = 0.9,
		Height = 2.12,
	},
	{
		Id = "the_paper_lantern",
		Name = "The Paper Lantern",
		Genre = "Children's",
		Description = "A shy boy builds a lantern from a ruined book and follows its light through the city's sleeping streets.",
		Published = "1999",
		Color = Color3.fromRGB(196, 120, 54),
		Thickness = 0.48,
		Height = 1.7,
	},
	{
		Id = "theory_of_restless_wings",
		Name = "A Theory of Restless Wings",
		Genre = "Philosophy",
		Description = "An essay collection on restlessness, migration, and why the human mind refuses to stay where it is put.",
		Published = "2014",
		Color = Color3.fromRGB(96, 64, 124),
		Thickness = 0.68,
		Height = 1.98,
	},
	{
		Id = "the_clockmakers_apology",
		Name = "The Clockmaker's Apology",
		Genre = "Historical Fiction",
		Description = "In 1760 a clockmaker writes a letter to every customer whose clock he secretly made worse on purpose.",
		Published = "1968",
		Color = Color3.fromRGB(104, 74, 44),
		Thickness = 0.74,
		Height = 2.06,
	},
	{
		Id = "beneath_the_lantern_sea",
		Name = "Beneath the Lantern Sea",
		Genre = "Fantasy",
		Description = "Deep under a sea of drifting lights, two rival salvage crews race to wake a sleeping leviathan.",
		Published = "2021",
		Color = Color3.fromRGB(34, 84, 96),
		Thickness = 0.82,
		Height = 2.14,
	},
	{
		Id = "six_winters_in_a_suitcase",
		Name = "Six Winters in a Suitcase",
		Genre = "Travel",
		Description = "A train conductor's diary of crossing the continent every season, carrying only what fits under one seat.",
		Published = "2002",
		Color = Color3.fromRGB(128, 48, 72),
		Thickness = 0.6,
		Height = 1.88,
	},
}

return BookCatalog
