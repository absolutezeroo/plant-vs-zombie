--!strict
--[[
	SunOnKillSystem.luau - Spawns sun when plants kill zombies
	
	Priority: 375 (After kill detection)
	
	Queries ProjectileHitEvent (WasKill=true) + SunOnKillComponent to spawn sun.
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop - processes kill events for sun spawning
	- Dispose(): No cleanup needed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)

-- Components
local SunOnKillComponent = Components.SunOnKillComponent
local PositionComponent = Components.PositionComponent
local SunComponent = Components.SunComponent
local OwnerComponent = Components.OwnerComponent
local ProjectileHitEvent = Components.ProjectileHitEvent

-- System function
local function SunOnKillSystem(world)
	-- Process ProjectileHitEvents: spawn sun on kills from plants with SunOnKillComponent
	for _, hitEvent in world:query(ProjectileHitEvent) do
		-- Only process kills
		if not hitEvent.WasKill then continue end
		
		local sourcePlant = hitEvent.SourcePlant
		if not world:contains(sourcePlant) then continue end
		
		local sunOnKill = world:get(sourcePlant, SunOnKillComponent)
		if not sunOnKill then continue end
		
		local owner = world:get(sourcePlant, OwnerComponent)
		if not owner then continue end
		
		-- Spawn sun at zombie death location
		local sunAmount = sunOnKill.SunAmount
		
		world:spawn(
			PositionComponent({
				X = hitEvent.PositionX,
				Y = hitEvent.PositionY + 3, -- Above ground
				Z = hitEvent.PositionZ,
			}),
			SunComponent({
				Value = sunAmount,
				OwnerId = owner.PlayerId,
				SpawnTime = os.clock(),
				AutoCollect = true, -- Auto-collect after delay
			})
		)
		
		Logger.Debug("SunOnKillSystem", `Spawned {sunAmount} sun from kill by plant {sourcePlant}`)
	end
end

local function Init(_world)
	-- No initialization needed
end

local function Dispose()
	-- No state to clean up
end

return {
	_name = "SunOnKillSystem",
	priority = 375,
	system = SunOnKillSystem,
	Init = Init,
	Dispose = Dispose,
}
