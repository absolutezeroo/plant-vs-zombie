--!strict
--[[
	HidingComponent - Applied to ScaredyShroom when hiding
	
	Plant cannot shoot while hiding (zombie too close).
]]

return function()
	return {
		IsHiding = false,     -- Currently hiding?
		HideRadius = 6,       -- Studs - how close zombie triggers hide
	}
end
