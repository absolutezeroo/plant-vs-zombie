--!strict
--[[
	StunComponent - Applied to stunned entities (butter from KernelPult)
	
	Stun prevents all movement and attacking for Duration seconds.
]]

return function()
	return {
		Duration = 4,        -- Total stun duration
		AppliedAt = 0,       -- os.clock() when applied
	}
end
