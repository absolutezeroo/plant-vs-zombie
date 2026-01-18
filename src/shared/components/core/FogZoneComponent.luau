--!strict
--[[
	FogZoneComponent.luau - Fog zone marker
	
	Applied to maps/waves that have fog.
	Tracks which columns are foggy and which are illuminated.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type FogZoneComponent = {
	FoggyColumns: { number }, -- List of column indices covered by fog (typically 5-9 in original PvZ)
	IlluminatedCells: { [string]: boolean }, -- "column,lane" keys for cells lit by Plantern
}

return Matter.component("FogZoneComponent", {
	FoggyColumns = {},
	IlluminatedCells = {},
})
