--!strict
-- Single source of truth for a fresh player profile.
-- When you add a field, bump SchemaVersion and add a migration in DataService.

local ProfileTemplate = {
	SchemaVersion = 1,
	Stats = {
		BooksShelved = 0,
		SessionsPlayed = 0,
		SecondsPlayed = 0,
	},
}

return ProfileTemplate
