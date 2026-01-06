--!strict
--[[
	ChewingComponent - Applied to Chomper while digesting zombie
	
	Chomper is disabled while chewing and cannot attack.
]]

return function()
	return {
		ChewDuration = 42,    -- Seconds to chew (data-driven from PlantData)
		ChewStartTime = 0,    -- os.clock() when started chewing
	}
end
