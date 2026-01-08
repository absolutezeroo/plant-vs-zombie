--!strict
--[[
	EnhancementSystem.luau - Server-side projectile enhancement behaviors
	
	Priority: 158 (Simulation phase - after projectile spawn, before collision)
	
	Handles:
	- Torchwood converting peas to fire peas (EnhancesPeas)
	- Fire pea damage multiplier (FireDamageMultiplier)
	- Future: Other enhancement plants
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

-- Network
local Network = require(Shared.network.generated.server)

-- Components
local PositionComponent = Components.PositionComponent
local PlantTypeComponent = Components.PlantTypeComponent
local ProjectileComponent = Components.ProjectileComponent
local EnhancedProjectileComponent = Components.EnhancedProjectileComponent

-- Config
local EnhancementConfig = {
	TORCHWOOD_HIT_RADIUS = 2,     -- Studs - how close pea must pass
	DEFAULT_FIRE_MULTIPLIER = 2,  -- 2x damage
}

-- Track which projectiles have already been enhanced (prevent double-enhancement)
local _enhancedProjectiles: {[number]: boolean} = {}

local function EnhancementSystem(world)
	-- Find all Torchwood plants
	local torchwoods = {}
	for plantId, pos, plant in world:query(PositionComponent, PlantTypeComponent) do
		local stats = PlantData[plant.PlantType]
		if stats and stats.EnhancesPeas then
			table.insert(torchwoods, {
				id = plantId,
				pos = pos,
				lane = plant.Lane,
				multiplier = stats.FireDamageMultiplier or EnhancementConfig.DEFAULT_FIRE_MULTIPLIER,
			})
		end
	end
	
	-- No torchwoods = nothing to do
	if #torchwoods == 0 then return end
	
	-- Check each projectile
	for projId, projPos, proj in world:query(PositionComponent, ProjectileComponent) do
		-- Skip already enhanced
		if _enhancedProjectiles[projId] then continue end
		
		-- Skip non-pea projectiles (catapults don't get enhanced)
		if proj.IsCatapult then continue end
		
		-- Skip if already a fire pea
		local existing = world:get(projId, EnhancedProjectileComponent)
		if existing and existing.IsFirePea then continue end
		
		-- Check if passing through any Torchwood
		for _, torch in torchwoods do
			-- Must be in same lane
			if torch.lane ~= proj.Lane then continue end
			
			-- Check if projectile is passing through Torchwood position
			local distance = math.abs(projPos.X - torch.pos.X)
			if distance <= EnhancementConfig.TORCHWOOD_HIT_RADIUS then
				-- Enhance the projectile!
				world:insert(projId, EnhancedProjectileComponent({
					IsFirePea = true,
					DamageMultiplier = torch.multiplier,
					ThawsFrozen = true,
				}))
				
				_enhancedProjectiles[projId] = true
				
				-- If it was a frozen pea, it's no longer frozen (fire melts ice)
				if proj.IsFrozen then
					world:insert(projId, ProjectileComponent({
						Damage = proj.Damage,
						Speed = proj.Speed,
						SourceEntity = proj.SourceEntity,
						Lane = proj.Lane,
						SpawnX = proj.SpawnX,
						IsFrozen = false,  -- No longer frozen
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
					}))
				end
				
				Logger.Debug("Enhancement", `Pea {projId} became fire pea (x{torch.multiplier} damage)`)
				
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
	for projId in _enhancedProjectiles do
		if not world:contains(projId) then
			_enhancedProjectiles[projId] = nil
		end
	end
end

return {
	system = EnhancementSystem,
	priority = 158,
}
