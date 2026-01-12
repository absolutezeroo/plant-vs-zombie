--!strict
--[[
	ArmedComponent.luau - Arming state for mines/traps
	
	Used by PotatoMine to track arming progress.
	When fully armed, the mine can explode on contact.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type ArmedComponent = {
	IsArmed: boolean, -- True when ready to explode
	ArmTime: number, -- os.clock() when arming started
	ArmDuration: number, -- Seconds to fully arm
}

return Matter.component("Armed")
