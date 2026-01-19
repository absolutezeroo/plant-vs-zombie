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
	local VFXUtils = require(Shared.utils.vfx.VFXUtils)
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
	local emitters: { ParticleEmitter } = {}
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
function VFXUtils.PlayFromModel(model: Model, vfxName: string, position: Vector3?, defaultEmitCount: number?): boolean
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
function VFXUtils.CloneAndFadeLight(sourceLight: Light, parent: Instance, fadeTime: number?): Light
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
	if not visual then
		return
	end

	for _, part in visual:GetDescendants() do
		if part:IsA("ParticleEmitter") and part.Name == "IdleVFX_Active" then
			part.Enabled = false
			Debris:AddItem(part, part.Lifetime.Max)
		end
	end
end

-- ============================================
-- Beam Effects (Chain Lightning, etc.)
-- ============================================

--[[
	Create a beam effect between two points (for chain lightning)
	
	Uses asset from Assets/VFX/{beamName} if exists, otherwise creates procedural beam.
	
	@param startPos Vector3 - Start position
	@param endPos Vector3 - End position
	@param beamName string? - Name of beam asset (default "Lightning_Beam")
	@param color Color3? - Beam color (default electric yellow)
	@param duration number? - How long beam stays visible (default 0.2)
	@return (Part, Part, Beam?) - Start anchor, end anchor, and beam (if created)
]]
function VFXUtils.CreateBeam(
	startPos: Vector3,
	endPos: Vector3,
	beamName: string?,
	color: Color3?,
	duration: number?
): (Part, Part, Beam?)
	local actualDuration = duration or 0.2
	local actualColor = color or Color3.fromRGB(255, 255, 100) -- Electric yellow

	-- Create start and end anchors
	local startAnchor = VFXUtils.CreateVFXAnchor(startPos, "BeamStart")
	local endAnchor = VFXUtils.CreateVFXAnchor(endPos, "BeamEnd")

	-- Create attachments
	local startAttachment = Instance.new("Attachment")
	startAttachment.Name = "BeamAttachment"
	startAttachment.Parent = startAnchor

	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "BeamAttachment"
	endAttachment.Parent = endAnchor

	-- Try to find beam template in Assets
	local Assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local VFXAssets = Assets and Assets:FindFirstChild("VFX")
	local beamTemplate = VFXAssets and VFXAssets:FindFirstChild(beamName or "Lightning_Beam")

	local beam: Beam?

	if beamTemplate and beamTemplate:FindFirstChildWhichIsA("Beam") then
		-- Clone from asset
		beam = beamTemplate:FindFirstChildWhichIsA("Beam"):Clone()
		beam.Attachment0 = startAttachment
		beam.Attachment1 = endAttachment
		beam.Parent = startAnchor
	else
		-- Create procedural beam
		beam = Instance.new("Beam")
		beam.Attachment0 = startAttachment
		beam.Attachment1 = endAttachment
		beam.Color = ColorSequence.new(actualColor)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
		beam.Width0 = 0.5
		beam.Width1 = 0.5
		beam.FaceCamera = true
		beam.Segments = 10
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.Parent = startAnchor
	end

	-- Animate fade out and cleanup
	task.delay(actualDuration * 0.5, function()
		if beam then
			local fadeSteps = 5
			for i = 1, fadeSteps do
				if beam.Parent then
					beam.Transparency = NumberSequence.new(i / fadeSteps)
				end
				task.wait(actualDuration * 0.5 / fadeSteps)
			end
		end
	end)

	-- Schedule cleanup
	Debris:AddItem(startAnchor, actualDuration + 0.1)
	Debris:AddItem(endAnchor, actualDuration + 0.1)

	return startAnchor, endAnchor, beam
end

--[[
	Create multiple chained beams (for multi-target chain lightning)
	
	@param positions {Vector3} - Array of positions to chain between
	@param color Color3? - Beam color
	@param duration number? - Duration per beam
]]
function VFXUtils.CreateChainedBeams(positions: { Vector3 }, color: Color3?, duration: number?)
	if #positions < 2 then
		return
	end

	for i = 1, #positions - 1 do
		-- Slight delay between each chain for visual effect
		task.delay((i - 1) * 0.05, function()
			VFXUtils.CreateBeam(positions[i], positions[i + 1], "Lightning_Beam", color, duration)
		end)
	end
end

--[[
	Create a status effect overlay on a model (burning aura, freeze tint, etc.)
	
	@param model Model - The model to apply overlay to
	@param effectType string - "Burn", "Freeze", "Poison", "Stun"
	@param duration number? - How long overlay lasts (nil = permanent until removed)
	@return Instance? - The overlay effect for manual cleanup
]]
function VFXUtils.ApplyStatusOverlay(model: Model, effectType: string, duration: number?): Instance?
	local visual = model:FindFirstChild("Visual")
	if not visual then
		return nil
	end

	-- Find first BasePart for particle attachment
	local targetPart = visual:FindFirstChildWhichIsA("BasePart")
	if not targetPart then
		return nil
	end

	-- Try to find overlay template
	local Assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local VFXAssets = Assets and Assets:FindFirstChild("VFX")
	local overlayName = effectType .. "_Overlay"
	local overlayTemplate = VFXAssets and VFXAssets:FindFirstChild(overlayName)

	-- Color mappings for procedural fallback
	local colorMap = {
		Burn = Color3.fromRGB(255, 100, 0),
		Freeze = Color3.fromRGB(150, 220, 255),
		Poison = Color3.fromRGB(100, 255, 100),
		Stun = Color3.fromRGB(255, 255, 100),
	}

	local overlay: ParticleEmitter

	if overlayTemplate and overlayTemplate:FindFirstChildWhichIsA("ParticleEmitter") then
		overlay = overlayTemplate:FindFirstChildWhichIsA("ParticleEmitter"):Clone()
	else
		-- Create procedural overlay
		overlay = Instance.new("ParticleEmitter")
		overlay.Color = ColorSequence.new(colorMap[effectType] or Color3.new(1, 1, 1))
		overlay.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
		overlay.Transparency = NumberSequence.new(0.5)
		overlay.Lifetime = NumberRange.new(0.5, 1)
		overlay.Rate = 10
		overlay.Speed = NumberRange.new(1, 2)
		overlay.SpreadAngle = Vector2.new(180, 180)
		overlay.LightEmission = 0.5
	end

	overlay.Name = "StatusOverlay_" .. effectType
	overlay.Parent = targetPart
	overlay.Enabled = true

	-- Schedule cleanup if duration specified
	if duration then
		task.delay(duration, function()
			if overlay and overlay.Parent then
				overlay.Enabled = false
				Debris:AddItem(overlay, overlay.Lifetime.Max)
			end
		end)
	end

	return overlay
end

--[[
	Remove a status overlay from a model
	
	@param model Model - The model to remove overlay from
	@param effectType string - "Burn", "Freeze", "Poison", "Stun"
]]
function VFXUtils.RemoveStatusOverlay(model: Model, effectType: string)
	local visual = model:FindFirstChild("Visual")
	if not visual then
		return
	end

	local overlayName = "StatusOverlay_" .. effectType

	for _, part in visual:GetDescendants() do
		if part:IsA("ParticleEmitter") and part.Name == overlayName then
			part.Enabled = false
			Debris:AddItem(part, part.Lifetime.Max)
		end
	end
end

-- ============================================
-- Voxel Burst VFX (Procedural)
-- ============================================

--[[
	Configuration type for VoxelBurst effect
]]
export type VoxelBurstConfig = {
	-- Particle count
	Count: number?,              -- Default: 15
	
	-- Size (voxel cube size)
	SizeMin: number?,            -- Default: 0.3
	SizeMax: number?,            -- Default: 0.6
	
	-- Colors (earth tones, explosion, etc.)
	Colors: { Color3 }?,         -- Default: brown/dirt tones
	
	-- Physics
	SpeedMin: number?,           -- Default: 8
	SpeedMax: number?,           -- Default: 15
	SpreadAngle: number?,        -- Default: 45 (degrees)
	Gravity: number?,            -- Default: -50 (negative Y acceleration)
	Drag: number?,               -- Default: 2
	
	-- Collision
	Bounce: boolean?,            -- Default: true (SurfaceCollision)
	
	-- Timing
	LifetimeMin: number?,        -- Default: 0.5
	LifetimeMax: number?,        -- Default: 1.0
	
	-- Rotation (tumbling voxels)
	RotSpeedMin: number?,        -- Default: -180
	RotSpeedMax: number?,        -- Default: 180
	
	-- Direction
	EmissionDirection: Enum.NormalId?, -- Default: Top
}

-- Preset configurations
local VOXEL_PRESETS = {
	-- Dirt burst when planting
	Dirt = {
		Count = 25,
		SizeMin = 0.25,
		SizeMax = 0.5,
		Colors = {
			Color3.fromRGB(101, 67, 33),   -- Dark brown
			Color3.fromRGB(139, 90, 43),   -- Saddle brown
			Color3.fromRGB(160, 120, 60),  -- Light brown
		},
		SpeedMin = 8,
		SpeedMax = 14,
		SpreadAngle = 50,
		Gravity = -45,
		Drag = 3,
		Bounce = true,
		LifetimeMin = 0.4,
		LifetimeMax = 0.8,
	},
	
	-- Crater explosion (DoomShroom)
	Crater = {
		Count = 35,
		SizeMin = 0.4,
		SizeMax = 0.9,
		Colors = {
			Color3.fromRGB(50, 40, 30),    -- Charred dark
			Color3.fromRGB(80, 60, 40),    -- Burnt brown
			Color3.fromRGB(60, 50, 35),    -- Ash brown
			Color3.fromRGB(30, 25, 20),    -- Almost black
		},
		SpeedMin = 18,
		SpeedMax = 30,
		SpreadAngle = 60,
		Gravity = -35,
		Drag = 1.5,
		Bounce = true,
		LifetimeMin = 0.8,
		LifetimeMax = 1.5,
	},
	
	-- Ice shatter
	Ice = {
		Count = 20,
		SizeMin = 0.2,
		SizeMax = 0.5,
		Colors = {
			Color3.fromRGB(200, 230, 255), -- Light ice blue
			Color3.fromRGB(150, 200, 255), -- Ice blue
			Color3.fromRGB(255, 255, 255), -- White
		},
		SpeedMin = 10,
		SpeedMax = 18,
		SpreadAngle = 70,
		Gravity = -40,
		Drag = 2,
		Bounce = true,
		LifetimeMin = 0.5,
		LifetimeMax = 1.0,
	},
	
	-- Fire/Explosion debris
	Explosion = {
		Count = 25,
		SizeMin = 0.3,
		SizeMax = 0.7,
		Colors = {
			Color3.fromRGB(255, 100, 0),   -- Orange
			Color3.fromRGB(255, 50, 0),    -- Red-orange
			Color3.fromRGB(80, 40, 20),    -- Burnt
		},
		SpeedMin = 15,
		SpeedMax = 25,
		SpreadAngle = 80,
		Gravity = -30,
		Drag = 2,
		Bounce = false,
		LifetimeMin = 0.4,
		LifetimeMax = 0.8,
	},
	
	-- Leaf/Plant debris
	Plant = {
		Count = 25,
		SizeMin = 0.2,
		SizeMax = 0.4,
		Colors = {
			Color3.fromRGB(34, 139, 34),   -- Forest green
			Color3.fromRGB(50, 180, 50),   -- Lime green
			Color3.fromRGB(85, 170, 85),   -- Light green
		},
		SpeedMin = 6,
		SpeedMax = 12,
		SpreadAngle = 60,
		Gravity = -25,
		Drag = 4,
		Bounce = false,
		LifetimeMin = 0.6,
		LifetimeMax = 1.2,
	},
}

--[[
	Create a voxel/cube burst effect at a position using real 3D Parts
	
	@param position Vector3 - World position for the burst
	@param config VoxelBurstConfig | string - Config table or preset name ("Dirt", "Crater", "Ice", "Explosion", "Plant")
]]
function VFXUtils.VoxelBurst(position: Vector3, config: VoxelBurstConfig | string?)
	-- Resolve preset or use custom config
	local cfg: VoxelBurstConfig
	if type(config) == "string" then
		cfg = VOXEL_PRESETS[config] or VOXEL_PRESETS.Dirt
	elseif config then
		cfg = config
	else
		cfg = VOXEL_PRESETS.Dirt
	end
	
	-- Apply defaults
	local count = cfg.Count or 15
	local sizeMin = cfg.SizeMin or 0.3
	local sizeMax = cfg.SizeMax or 0.6
	local colors = cfg.Colors or { Color3.fromRGB(139, 90, 43) }
	local speedMin = cfg.SpeedMin or 8
	local speedMax = cfg.SpeedMax or 15
	local spreadAngle = math.rad(cfg.SpreadAngle or 45)
	local lifetimeMin = cfg.LifetimeMin or 0.5
	local lifetimeMax = cfg.LifetimeMax or 1.0
	
	-- Spawn real 3D cubes
	for _ = 1, count do
		local cube = Instance.new("Part")
		cube.Name = "VoxelDebris"
		
		-- Random size
		local size = sizeMin + math.random() * (sizeMax - sizeMin)
		cube.Size = Vector3.new(size, size, size)
		
		-- Random color from palette
		cube.Color = colors[math.random(1, #colors)]
		
		-- Appearance
		cube.Material = Enum.Material.Plastic
		cube.TopSurface = Enum.SurfaceType.Smooth
		cube.BottomSurface = Enum.SurfaceType.Smooth
		
		-- Physics
		cube.Anchored = false
		cube.CanCollide = true
		cube.CanQuery = false
		cube.CanTouch = false
		
		-- Position with slight random offset
		local offsetX = (math.random() - 0.5) * 1
		local offsetZ = (math.random() - 0.5) * 1
		cube.Position = position + Vector3.new(offsetX, 0.5, offsetZ)
		
		-- Random rotation
		cube.CFrame = cube.CFrame * CFrame.Angles(
			math.random() * math.pi * 2,
			math.random() * math.pi * 2,
			math.random() * math.pi * 2
		)
		
		cube.Parent = workspace
		
		-- Apply upward/outward velocity
		local speed = speedMin + math.random() * (speedMax - speedMin)
		local angle = math.random() * math.pi * 2 -- Random horizontal direction
		local verticalAngle = math.pi / 2 - math.random() * spreadAngle -- Mostly up
		
		local velocityX = math.cos(angle) * math.sin(verticalAngle) * speed
		local velocityY = math.cos(verticalAngle) * speed + speed * 0.5 -- Bias upward
		local velocityZ = math.sin(angle) * math.sin(verticalAngle) * speed
		
		cube.AssemblyLinearVelocity = Vector3.new(velocityX, velocityY, velocityZ)
		
		-- Random spin
		cube.AssemblyAngularVelocity = Vector3.new(
			(math.random() - 0.5) * 20,
			(math.random() - 0.5) * 20,
			(math.random() - 0.5) * 20
		)
		
		-- Fade out and cleanup
		local lifetime = lifetimeMin + math.random() * (lifetimeMax - lifetimeMin)
		
		task.spawn(function()
			-- Wait for most of lifetime
			task.wait(lifetime * 0.7)
			
			-- Fade out
			local fadeSteps = 5
			for i = 1, fadeSteps do
				if cube and cube.Parent then
					cube.Transparency = i / fadeSteps
				end
				task.wait(lifetime * 0.3 / fadeSteps)
			end
			
			-- Destroy
			if cube and cube.Parent then
				cube:Destroy()
			end
		end)
	end
end

--[[
	Dirt burst effect for plant placement
	
	@param position Vector3 - World position for the burst
]]
function VFXUtils.DirtBurst(position: Vector3)
	VFXUtils.VoxelBurst(position, "Dirt")
end

--[[
	Crater explosion effect (DoomShroom, etc.)
	
	@param position Vector3 - World position for the burst
]]
function VFXUtils.CraterBurst(position: Vector3)
	VFXUtils.VoxelBurst(position, "Crater")
end

--[[
	Ice shatter effect (frozen plants/zombies breaking)
	
	@param position Vector3 - World position for the burst
]]
function VFXUtils.IceBurst(position: Vector3)
	VFXUtils.VoxelBurst(position, "Ice")
end

--[[
	Explosion debris effect (CherryBomb, Jalapeno, etc.)
	
	@param position Vector3 - World position for the burst
]]
function VFXUtils.ExplosionBurst(position: Vector3)
	VFXUtils.VoxelBurst(position, "Explosion")
end

--[[
	Plant debris effect (plant destroyed)
	
	@param position Vector3 - World position for the burst
]]
function VFXUtils.PlantBurst(position: Vector3)
	VFXUtils.VoxelBurst(position, "Plant")
end

return VFXUtils
