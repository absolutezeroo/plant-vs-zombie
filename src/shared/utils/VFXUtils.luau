--!strict
--[[
	VFXUtils.luau - Visual Effects utility functions
	
	Consolidates common VFX patterns to reduce code duplication:
	- Particle emitter cloning and emission
	- VFX anchor part creation
	- Debris cleanup scheduling
	
	PHILOSOPHY:
	- Asset-based VFX (clone from templates, never Instance.new for art)
	- Automatic cleanup via Debris service
	- Support for EmitCount attribute on particle emitters
	
	USAGE:
	local VFXUtils = require(Shared.utils.VFXUtils)
	VFXUtils.CloneAndEmit(shootVFX, muzzlePosition, 8)
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local VFXUtils = {}

-- Default values
local DEFAULT_EMIT_COUNT = 8
local DEFAULT_ANCHOR_SIZE = Vector3.one * 0.1

-- ============================================
-- Anchor Creation
-- ============================================

--[[
	Create an invisible anchored part for VFX attachment
	
	@param position Vector3 - World position for the anchor
	@param name string? - Optional name for the anchor
	@return Part - The created anchor part
]]
function VFXUtils.CreateVFXAnchor(position: Vector3, name: string?): Part
	local anchor = Instance.new("Part")
	anchor.Name = name or "VFXAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = DEFAULT_ANCHOR_SIZE
	anchor.Position = position
	anchor.Parent = workspace
	return anchor
end

-- ============================================
-- Particle Emission
-- ============================================

--[[
	Get the emit count from a ParticleEmitter's attribute or use default
	
	@param emitter ParticleEmitter - The emitter to check
	@param defaultCount number? - Default count if attribute not found
	@return number - The emit count to use
]]
function VFXUtils.GetEmitCount(emitter: ParticleEmitter, defaultCount: number?): number
	local emitCount = emitter:GetAttribute("EmitCount")
	if type(emitCount) == "number" then
		return emitCount
	end
	return defaultCount or DEFAULT_EMIT_COUNT
end

--[[
	Emit particles from an existing emitter
	
	@param emitter ParticleEmitter - The emitter to trigger
	@param count number? - Number of particles (uses EmitCount attribute if nil)
]]
function VFXUtils.Emit(emitter: ParticleEmitter, count: number?)
	local emitCount = count or VFXUtils.GetEmitCount(emitter)
	emitter:Emit(emitCount)
end

--[[
	Clone a ParticleEmitter, parent it, emit, and schedule cleanup
	
	@param sourceEmitter ParticleEmitter - Template emitter to clone
	@param parent Instance - Parent for the cloned emitter
	@param emitCount number? - Override emit count (uses EmitCount attribute if nil)
	@param cleanupDelay number? - Override cleanup delay (uses Lifetime.Max + 0.5 if nil)
	@return ParticleEmitter - The cloned emitter
]]
function VFXUtils.CloneEmitAndCleanup(
	sourceEmitter: ParticleEmitter,
	parent: Instance,
	emitCount: number?,
	cleanupDelay: number?
): ParticleEmitter
	local clone = sourceEmitter:Clone()
	clone.Parent = parent
	
	local count = emitCount or VFXUtils.GetEmitCount(clone)
	clone:Emit(count)
	
	local delay = cleanupDelay or (clone.Lifetime.Max + 0.5)
	Debris:AddItem(clone, delay)
	
	return clone
end

--[[
	Clone a ParticleEmitter to a new anchor at position, emit, and cleanup both
	
	This is the most common VFX pattern - creates anchor, clones emitter, emits, cleans up.
	
	@param sourceEmitter ParticleEmitter - Template emitter to clone
	@param position Vector3 - World position for the effect
	@param emitCount number? - Override emit count
	@param cleanupDelay number? - Override cleanup delay
	@return (Part, ParticleEmitter) - The anchor part and cloned emitter
]]
function VFXUtils.CloneAndEmit(
	sourceEmitter: ParticleEmitter,
	position: Vector3,
	emitCount: number?,
	cleanupDelay: number?
): (Part, ParticleEmitter)
	local anchor = VFXUtils.CreateVFXAnchor(position, "VFX_" .. sourceEmitter.Name)
	
	local clone = sourceEmitter:Clone()
	clone.Parent = anchor
	
	local count = emitCount or VFXUtils.GetEmitCount(clone)
	clone:Emit(count)
	
	local delay = cleanupDelay or (clone.Lifetime.Max + 0.5)
	Debris:AddItem(anchor, delay)
	
	return anchor, clone
end

-- ============================================
-- Multi-Emitter VFX
-- ============================================

--[[
	Play all ParticleEmitters from a VFX folder at a position
	
	@param vfxFolder Instance - Folder containing ParticleEmitters
	@param position Vector3 - World position for the effect
	@param colorOverride Color3? - Optional color to apply to all emitters
	@param cleanupDelay number? - Override cleanup delay
	@return Part? - The anchor part, or nil if no emitters found
]]
function VFXUtils.PlayFromFolder(
	vfxFolder: Instance,
	position: Vector3,
	colorOverride: Color3?,
	cleanupDelay: number?
): Part?
	local emitters: {ParticleEmitter} = {}
	local maxLifetime = 0
	
	-- Collect all ParticleEmitters
	for _, child in vfxFolder:GetChildren() do
		if child:IsA("ParticleEmitter") then
			table.insert(emitters, child)
			maxLifetime = math.max(maxLifetime, child.Lifetime.Max)
		end
	end
	
	if #emitters == 0 then
		return nil
	end
	
	local anchor = VFXUtils.CreateVFXAnchor(position, "VFX_" .. vfxFolder.Name)
	
	for _, emitter in emitters do
		local clone = emitter:Clone()
		
		if colorOverride then
			clone.Color = ColorSequence.new(colorOverride)
		end
		
		clone.Parent = anchor
		
		local count = VFXUtils.GetEmitCount(clone)
		clone:Emit(count)
	end
	
	local delay = cleanupDelay or (maxLifetime + 0.5)
	Debris:AddItem(anchor, delay)
	
	return anchor
end

--[[
	Play VFX from a model's VFX folder
	
	Looks for model.VFX.{vfxName} and plays it at the model's position
	
	@param model Model - The model containing VFX folder
	@param vfxName string - Name of the VFX to play (e.g., "Shoot", "Death")
	@param position Vector3? - Override position (uses model position if nil)
	@param defaultEmitCount number? - Default emit count if no attribute
	@return boolean - True if VFX was found and played
]]
function VFXUtils.PlayFromModel(
	model: Model,
	vfxName: string,
	position: Vector3?,
	defaultEmitCount: number?
): boolean
	local vfxFolder = model:FindFirstChild("VFX")
	if not vfxFolder then
		return false
	end
	
	local vfx = vfxFolder:FindFirstChild(vfxName)
	if not vfx then
		return false
	end
	
	local pos = position or model:GetPivot().Position
	
	if vfx:IsA("ParticleEmitter") then
		VFXUtils.CloneAndEmit(vfx, pos, defaultEmitCount)
		return true
	elseif vfx:IsA("Folder") then
		VFXUtils.PlayFromFolder(vfx, pos)
		return true
	end
	
	return false
end

-- ============================================
-- Light Effects
-- ============================================

--[[
	Clone a light and fade it out
	
	@param sourceLight Light - Template light to clone
	@param parent Instance - Parent for the cloned light
	@param fadeTime number? - Time to fade out (default 0.5)
	@return Light - The cloned light
]]
function VFXUtils.CloneAndFadeLight(
	sourceLight: Light,
	parent: Instance,
	fadeTime: number?
): Light
	local clone = sourceLight:Clone() :: Light
	clone.Parent = parent
	
	local fade = fadeTime or 0.5
	local tween = TweenService:Create(clone, TweenInfo.new(fade), { Brightness = 0 })
	tween:Play()
	
	Debris:AddItem(clone, fade + 0.1)
	
	return clone
end

-- ============================================
-- Idle VFX (Continuous)
-- ============================================

--[[
	Attach an idle (continuous) VFX to a model
	
	Unlike burst VFX, idle VFX uses Rate instead of Emit
	
	@param model Model - The model to attach VFX to
	@param vfxName string? - Name of VFX (default "Idle")
	@return ParticleEmitter? - The attached emitter, or nil if not found
]]
function VFXUtils.AttachIdleVFX(model: Model, vfxName: string?): ParticleEmitter?
	local name = vfxName or "Idle"
	
	local vfxFolder = model:FindFirstChild("VFX")
	local idleVFX = vfxFolder and vfxFolder:FindFirstChild(name)
	
	if not idleVFX or not idleVFX:IsA("ParticleEmitter") then
		return nil
	end
	
	-- Find target part (Visual folder's first BasePart)
	local visual = model:FindFirstChild("Visual")
	local targetPart = visual and visual:FindFirstChildWhichIsA("BasePart")
	
	if not targetPart then
		return nil
	end
	
	local clone = idleVFX:Clone()
	clone.Name = "IdleVFX_Active"
	clone.Parent = targetPart
	clone.Enabled = true
	
	return clone
end

--[[
	Detach and cleanup idle VFX from a model
	
	@param model Model - The model to detach VFX from
]]
function VFXUtils.DetachIdleVFX(model: Model)
	local visual = model:FindFirstChild("Visual")
	if not visual then return end
	
	for _, part in visual:GetDescendants() do
		if part:IsA("ParticleEmitter") and part.Name == "IdleVFX_Active" then
			part.Enabled = false
			Debris:AddItem(part, part.Lifetime.Max)
		end
	end
end

return VFXUtils
