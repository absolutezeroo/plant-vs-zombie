--!strict
--[[
	AttachmentUtils.luau - Attachment-based spatial contracts
	
	Attachments serve as "spatial contracts" between Artists and Developers:
	- Artists place Attachments at semantic points (Muzzle, Center, Overhead, Torso)
	- Code reads WorldPosition from Attachments
	- Code NEVER uses hardcoded Vector3 offsets
	
	Standard Model Structure:
		{EntityType} (Model)
		├── Root (Part) ────────── PrimaryPart (invisible, anchored)
		├── Visual (Model) ─────── All visible parts
		├── VFX (Folder) ───────── Optional particle templates
		│   ├── Shoot (ParticleEmitter)
		│   ├── Death (ParticleEmitter)
		│   └── Idle (ParticleEmitter)
		└── [Attributes]
		    ├── EntityType = "{Type}"
		    └── Anim_* = animation parameters
	
	Standard Attachment Names (on Root):
	- "Muzzle"   : Projectile spawn point (front of shooter plants)
	- "Center"   : Mass center (targeting, effects)
	- "Overhead" : Above model (health bars, indicators)
	- "Torso"    : Enemy targeting point (for zombie models)
	- "Head"     : Headshot targeting point
	
	FORBIDDEN: Position + Vector3.new(0, 2, 0) -- NEVER hardcode offsets!
	REQUIRED:  AttachmentUtils.GetWorldPosition(model, "Muzzle")
	
	Usage:
	  local pos = AttachmentUtils.GetWorldPosition(model, "Muzzle")
	  -- Returns Muzzle.WorldPosition, or model center as fallback
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)

local AttachmentUtils = {}

--[[
	Find an Attachment by name in a model.
	Searches: PrimaryPart first, then all descendants.
	
	@param model The model to search
	@param attachmentName The name of the Attachment (e.g., "Muzzle")
	@return The Attachment instance, or nil if not found
]]
function AttachmentUtils.FindAttachment(model: Model, attachmentName: string): Attachment?
	if not model then
		return nil
	end

	-- Priority 1: Check PrimaryPart (most common location)
	local primaryPart = model.PrimaryPart
	if primaryPart then
		local attachment = primaryPart:FindFirstChild(attachmentName)
		if attachment and attachment:IsA("Attachment") then
			return attachment
		end
	end

	-- Priority 2: Search all descendants
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Attachment") and descendant.Name == attachmentName then
			return descendant
		end
	end

	return nil
end

--[[
	Get the WorldPosition of a named Attachment.
	If not found, returns a fallback position (model center).
	
	RULE: Never use hardcoded Vector3 offsets. The Attachment IS the position.
	
	@param model The model to search
	@param attachmentName The name of the Attachment
	@param logWarning If true, logs a warning when using fallback (default true)
	@return The WorldPosition of the Attachment, or fallback position
]]
function AttachmentUtils.GetWorldPosition(model: Model, attachmentName: string, logWarning: boolean?): Vector3
	local shouldLog = if logWarning == nil then true else logWarning

	-- Find the attachment
	local attachment = AttachmentUtils.FindAttachment(model, attachmentName)

	if attachment then
		return attachment.WorldPosition
	end

	-- Fallback: Use model center
	local fallbackPos = Vector3.zero

	if model.PrimaryPart then
		fallbackPos = model.PrimaryPart.Position
	else
		-- Last resort: Get bounding box center
		local cf, size = model:GetBoundingBox()
		fallbackPos = cf.Position
	end

	if shouldLog then
		Logger.Warn("Attachment", `Attachment "{attachmentName}" not found in {model.Name}, using fallback position`)
	end

	return fallbackPos
end

--[[
	Get the WorldCFrame of a named Attachment.
	Useful when you need both position AND orientation (e.g., projectile direction).
	
	@param model The model to search
	@param attachmentName The name of the Attachment
	@return The WorldCFrame of the Attachment, or fallback CFrame
]]
function AttachmentUtils.GetWorldCFrame(model: Model, attachmentName: string): CFrame
	local attachment = AttachmentUtils.FindAttachment(model, attachmentName)

	if attachment then
		return attachment.WorldCFrame
	end

	-- Fallback
	if model.PrimaryPart then
		return model.PrimaryPart.CFrame
	end

	local cf, _ = model:GetBoundingBox()
	Logger.Warn("Attachment", `Attachment "{attachmentName}" not found in {model.Name}, using fallback CFrame`)
	return cf
end

--[[
	Check if a model has a specific Attachment.
	Useful for validation or feature detection.
	
	@param model The model to check
	@param attachmentName The name to look for
	@return true if the Attachment exists
]]
function AttachmentUtils.HasAttachment(model: Model, attachmentName: string): boolean
	return AttachmentUtils.FindAttachment(model, attachmentName) ~= nil
end

--[[
	Get multiple Attachments as a dictionary.
	Useful when you need several points at once.
	
	@param model The model to search
	@param attachmentNames Array of Attachment names
	@return Dictionary of {name -> WorldPosition}, missing ones are nil
]]
function AttachmentUtils.GetMultiplePositions(model: Model, attachmentNames: { string }): { [string]: Vector3? }
	local result: { [string]: Vector3? } = {}

	for _, name in attachmentNames do
		local attachment = AttachmentUtils.FindAttachment(model, name)
		result[name] = attachment and attachment.WorldPosition or nil
	end

	return result
end

--[[
	Standard Attachment names for easy reference
]]
AttachmentUtils.Names = {
	Muzzle = "Muzzle", -- Projectile spawn point
	Center = "Center", -- Mass center (targeting)
	Overhead = "Overhead", -- Health bar position
	Torso = "Torso", -- Zombie targeting point
	Head = "Head", -- Headshot targeting
}

return AttachmentUtils
