--!strict
--[[
	JumpingComponent - Applied to Squash while jumping to target
	
	Tracks the target position and jump state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("JumpingComponent", {
	TargetX = 0,           -- Target X position
	TargetZ = 0,           -- Target Z position
	JumpStartTime = 0,     -- os.clock() when jump started
	JumpDuration = 0.5,    -- Seconds for jump animation
	HasLanded = false,     -- Already squashed?
})
