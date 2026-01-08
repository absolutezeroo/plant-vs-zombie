--!strict
--[[
	TrapSystem.luau - Server-side trap and diversion behaviors
	
	Priority: 165 (Simulation phase - after movement, before combat)
	
	Handles:
	- Spikeweed/Spikerock damaging zombies walking over (IsTrap, DamagesOnWalk)
	- Garlic diverting zombies to adjacent lanes (DivertsZombies)
	- Vehicle tire popping (PopsTires) - for Zomboni etc.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local PlantData = require(Shared.data.PlantData)
local ZombieData = require(Shared.data.ZombieData)
local Logger = require(Shared.utils.Logger)

-- Network
local Network = require(Shared.network.generated.server)

-- Components
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local PlantTypeComponent = Components.PlantTypeComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local MovementComponent = Components.MovementComponent

-- Config
local TrapConfig = {
	SPIKEWEED_DAMAGE_INTERVAL = 0.5,  -- Seconds between damage ticks
	SPIKEWEED_HIT_RADIUS = 3,          -- Studs
	GARLIC_BITE_THRESHOLD = 3,         -- Bites before zombie switches lane
}

-- Track last damage time per zombie per trap
local _trapDamageTimes: {[string]: number} = {} -- "trapId_zombieId" -> lastDamageTime

-- Track garlic bite counts
local _garlicBites: {[string]: number} = {} -- "garlicId_zombieId" -> biteCount

local function TrapSystem(world)
	local currentTime = os.clock()
	
	-- Process traps (Spikeweed)
	for trapId, trapPos, trap in world:query(PositionComponent, PlantTypeComponent) do
		local stats = PlantData[trap.PlantType]
		if not stats or not stats.IsTrap or not stats.DamagesOnWalk then continue end
		
		local damage = stats.Damage or 20
		local hitRadius = TrapConfig.SPIKEWEED_HIT_RADIUS
		
		-- Check for zombies walking over
		for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
			if zombie.Lane ~= trap.Lane then continue end
			
			local distance = math.abs(zombiePos.X - trapPos.X)
			if distance > hitRadius then continue end
			
			-- Check damage cooldown
			local key = `{trapId}_{zombieId}`
			local lastDamage = _trapDamageTimes[key] or 0
			if currentTime - lastDamage < TrapConfig.SPIKEWEED_DAMAGE_INTERVAL then continue end
			
			-- Apply damage
			local health = world:get(zombieId, HealthComponent)
			if health then
				local newHealth = math.max(0, health.Current - damage)
				world:insert(zombieId, HealthComponent({
					Current = newHealth,
					Max = health.Max,
				}))
				
				_trapDamageTimes[key] = currentTime
				Logger.Debug("Trap", `Spikeweed {trapId} damaged zombie {zombieId} for {damage}`)
				
				-- Broadcast damage
				Network.EntityDamaged.FireAll({
					EntityId = zombieId,
					NewHealth = newHealth,
					DamageAmount = damage,
				})
				
				-- Check for vehicle (PopsTires)
				if stats.PopsTires then
					local zombieStats = ZombieData[zombie.ZombieType]
					if zombieStats and zombieStats.IsVehicle then
						-- Instant kill vehicle
						world:insert(zombieId, HealthComponent({
							Current = 0,
							Max = health.Max,
						}))
						Logger.Info("Trap", `Spikeweed {trapId} popped tires of vehicle zombie {zombieId}`)
					end
				end
			end
		end
	end
	
	-- Process Garlic (DivertsZombies)
	for garlicId, garlicPos, garlic in world:query(PositionComponent, PlantTypeComponent) do
		local stats = PlantData[garlic.PlantType]
		if not stats or not stats.DivertsZombies then continue end
		
		-- Garlic works by being eaten - zombies switch lane after eating it
		-- This is handled in CombatSystem when zombie finishes eating
		-- Here we just track that the zombie is eating garlic
	end
	
	-- Cleanup old entries
	for key in _trapDamageTimes do
		local parts = string.split(key, "_")
		local trapId = tonumber(parts[1])
		local zombieId = tonumber(parts[2])
		
		if not trapId or not zombieId then
			_trapDamageTimes[key] = nil
		elseif not world:contains(trapId) or not world:contains(zombieId) then
			_trapDamageTimes[key] = nil
		end
	end
	
	for key in _garlicBites do
		local parts = string.split(key, "_")
		local garlicId = tonumber(parts[1])
		local zombieId = tonumber(parts[2])
		
		if not garlicId or not zombieId then
			_garlicBites[key] = nil
		elseif not world:contains(garlicId) or not world:contains(zombieId) then
			_garlicBites[key] = nil
		end
	end
end

-- API for CombatSystem to call when zombie finishes eating Garlic
local TrapAPI = {}

function TrapAPI.OnGarlicEaten(world: any, garlicId: number, zombieId: number)
	local garlic = world:get(garlicId, PlantTypeComponent)
	if not garlic then return end
	
	local stats = PlantData[garlic.PlantType]
	if not stats or not stats.DivertsZombies then return end
	
	local zombie = world:get(zombieId, ZombieTypeComponent)
	if not zombie then return end
	
	local zombieStats = ZombieData[zombie.ZombieType]
	if not zombieStats then return end
	
	-- Increment bite count
	local key = `{garlicId}_{zombieId}`
	local bites = (_garlicBites[key] or 0) + 1
	_garlicBites[key] = bites
	
	-- Check if zombie should switch lanes
	if bites >= TrapConfig.GARLIC_BITE_THRESHOLD then
		-- Pick adjacent lane (prefer away from center)
		local currentLane = zombie.Lane
		local newLane = currentLane
		
		if currentLane <= 2 then
			newLane = currentLane + 1  -- Move down
		elseif currentLane >= 4 then
			newLane = currentLane - 1  -- Move up
		else
			-- Middle lane - random direction
			newLane = currentLane + (if math.random() > 0.5 then 1 else -1)
		end
		
		-- Clamp to valid lanes
		newLane = math.clamp(newLane, 1, GridConfig.GRID_LANES)
		
		if newLane ~= currentLane then
			-- Update zombie lane
			world:insert(zombieId, ZombieTypeComponent({
				ZombieType = zombie.ZombieType,
				Lane = newLane,
			}))
			
			-- Update Z position for new lane (using MapConfig)
			local pos = world:get(zombieId, PositionComponent)
			if pos then
				local laneCenter = MapConfig.GridToWorld(1, newLane)
				world:insert(zombieId, PositionComponent({
					X = pos.X,
					Y = pos.Y,
					Z = laneCenter.Z,
				}))
			end
			
			Logger.Info("Trap", `Garlic diverted zombie {zombieId} from lane {currentLane} to {newLane}`)
		end

		
		-- Reset bite count
		_garlicBites[key] = nil
	end
end

return {
	system = TrapSystem,
	priority = 165,
	API = TrapAPI,
}
