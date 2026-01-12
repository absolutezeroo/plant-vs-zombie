--!strict
--[[
	SunComponent.luau - Sun orb entity marker
	
	Marks entities as collectible sun resources.
	Sun can spawn from:
	- Sky (every 5-10 seconds, falls with gravity)
	- Sunflowers (every 24 seconds)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type SunComponent = {
	Value: number, -- Sun value when collected (default 25)
	SpawnTime: number, -- os.clock() when spawned
	Lifetime: number, -- Seconds until auto-despawn (default 10)
	IsFalling: boolean, -- True if still falling from sky
	TargetY: number?, -- Y position to stop at when falling (nil for non-falling)
	SourceType: string?, -- "Sky" or "Sunflower" (optional for tracking)
	OwnerId: number?, -- UserId of the player who owns this sun (nil = anyone can collect)
}

return Matter.component("Sun")
