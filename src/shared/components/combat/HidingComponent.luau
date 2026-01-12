--!strict
--[[
	HidingComponent - Applied to ScaredyShroom when hiding
	
	Plant cannot shoot while hiding (zombie too close).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("HidingComponent", {
	IsHiding = false, -- Currently hiding?
	HideRadius = 6, -- Studs - how close zombie triggers hide
})
