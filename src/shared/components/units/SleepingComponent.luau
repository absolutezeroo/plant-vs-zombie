--!strict
--[[
	SleepingComponent - Applied to mushrooms sleeping during day
	
	Sleeping plants cannot shoot or produce anything.
	Coffee Bean removes this component.
]]

return function()
	return {
		IsSleeping = true,      -- Currently sleeping?
		WokeAt = nil,           -- os.clock() when woken (nil if still sleeping)
	}
end
