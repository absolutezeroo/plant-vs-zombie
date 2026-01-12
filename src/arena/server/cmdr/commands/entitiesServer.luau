--!strict
--[[
	entities Command (Server)
	
	Shows current entity count and breakdown from the live Matter world.
	Usage: entities
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local EntityPool = require(Shared.utils.EntityPool)

return function(_context)
	local world = EntityPool.GetWorld()

	if not world then
		return "ERROR: World not initialized yet"
	end

	-- Count entities by type using Matter queries
	local zombieCount = 0
	local plantCount = 0
	local projectileCount = 0
	local sunCount = 0
	local totalCount = 0

	-- Query each entity type
	for _ in world:query(Components.ZombieTypeComponent) do
		zombieCount += 1
	end

	for _ in world:query(Components.PlantTypeComponent) do
		plantCount += 1
	end

	for _ in world:query(Components.ProjectileComponent) do
		projectileCount += 1
	end

	for _ in world:query(Components.SunComponent) do
		sunCount += 1
	end

	-- Count all entities with PositionComponent (basically everything with a position)
	for _ in world:query(Components.PositionComponent) do
		totalCount += 1
	end

	-- EntityPool stats (if initialized)
	local poolStats = EntityPool.GetStats()

	local lines = {
		"=== Live Entity Stats ===",
		`Zombies: {zombieCount}`,
		`Plants: {plantCount}`,
		`Projectiles: {projectileCount}`,
		`Suns: {sunCount}`,
		`Total (with position): {totalCount}`,
		"",
		"=== Entity Pool ===",
		`Pool Total: {poolStats.Total}`,
		`Available: {poolStats.Available}`,
		`In Use: {poolStats.InUse}`,
	}

	return table.concat(lines, "\n")
end
