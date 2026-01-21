--!strict
--[[
	EnhancementSystem.luau - Server-side projectile enhancement behaviors
	
	Priority: 165 (After projectile movement, before combat detection)
	
	Handles:
	- Torchwood converting peas to fire peas (EnhancesPeas)
	- Fire pea damage multiplier (FireDamageMultiplier)
	
	V3 Architecture: Matter Hooks pattern
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages.MatterHooks)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local PlantData = require(Shared.data.PlantData)

-- Network
local Network = require(Shared.network.generated.server)

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	TORCHWOOD_HIT_RADIUS = 2, -- Studs - how close pea must pass
	DEFAULT_FIRE_MULTIPLIER = 2, -- 2x damage
})

-- 3. TYPES
type EnhancementState = {
	EnhancedProjectiles: { [number]: boolean }, -- Prevent double-enhancement
}

-- 4. SYSTEM FUNCTION
local function EnhancementSystem(world)
	-- State managed via Hooks.useMap
	local state = Hooks.useMap("EnhancementState", {
		EnhancedProjectiles = {} :: { [number]: boolean },
	})

	-- Find all Torchwood plants
	local torchwoods = {}
	for plantId, pos, plant in world:query(Components.PositionComponent, Components.PlantTypeComponent) do
		local stats = PlantData[plant.PlantType]
		if stats and stats.EnhancesPeas then
			table.insert(torchwoods, {
				id = plantId,
				pos = pos,
				lane = plant.Lane,
				multiplier = stats.FireDamageMultiplier or CONFIG.DEFAULT_FIRE_MULTIPLIER,
			})
		end
	end

	-- No torchwoods = nothing to do
	if #torchwoods == 0 then
		return
	end

	-- Check each projectile
	for projId, projPos, proj in world:query(Components.PositionComponent, Components.ProjectileComponent) do
		-- Skip already enhanced
		if state.value.EnhancedProjectiles[projId] then
			continue
		end

		-- Skip non-pea projectiles (catapults don't get enhanced)
		if proj.IsCatapult then
			continue
		end

		-- Skip if already a fire pea
		local existing = world:get(projId, Components.EnhancedProjectileComponent)
		if existing and existing.IsFirePea then
			continue
		end

		-- Check if passing through any Torchwood
		for _, torch in torchwoods do
			-- Must be in same lane
			if torch.lane ~= proj.Lane then
				continue
			end

			-- Check if projectile is passing through Torchwood position
			local distance = math.abs(projPos.X - torch.pos.X)
			if distance <= CONFIG.TORCHWOOD_HIT_RADIUS then
				-- Enhance the projectile!
				world:insert(
					projId,
					Components.EnhancedProjectileComponent({
						IsFirePea = true,
						DamageMultiplier = torch.multiplier,
						ThawsFrozen = true,
					})
				)

				state.value.EnhancedProjectiles[projId] = true

				-- If it was a frozen pea, it's no longer frozen (fire melts ice)
				if proj.IsFrozen then
					world:insert(
						projId,
						Components.ProjectileComponent({
							Damage = proj.Damage,
							Speed = proj.Speed,
							SourceEntity = proj.SourceEntity,
							Lane = proj.Lane,
							SpawnX = proj.SpawnX,
							IsFrozen = false,
							SlowPercent = nil,
							SlowDuration = nil,
							IsCatapult = proj.IsCatapult,
							PiercesShields = proj.PiercesShields,
							CanStun = proj.CanStun,
							StunChance = proj.StunChance,
							StunDuration = proj.StunDuration,
							MaxRange = proj.MaxRange,
							DirectionX = proj.DirectionX,
							DirectionZ = proj.DirectionZ,
						})
					)
				end

				-- Broadcast to clients for VFX change
				Network.ProjectileEnhanced.FireAll({
					EntityId = projId,
					EnhancementType = "fire",
				})

				break -- Only enhance once
			end
		end
	end

	-- Cleanup tracked projectiles
	for projId in state.value.EnhancedProjectiles do
		if not world:contains(projId) then
			state.value.EnhancedProjectiles[projId] = nil
		end
	end
end

-- ============================================================
-- SECTION 5: MODULE EXPORT
-- ============================================================
return {
	priority = 165,
	system = EnhancementSystem,
}
