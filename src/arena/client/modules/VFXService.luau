--!strict
--[[
	VFXService.luau - Client-side visual effects manager
	
	Handles all particle effects and visual juice:
	- Explosions (CherryBomb, PotatoMine)
	- Projectile impacts
	- Death effects
	- Collection sparkles
	- Damage feedback
	
	Model-aware VFX system:
	- First checks model's VFX folder for custom particles
	- Falls back to generic VFX if not found
	- Supports: Shoot, Death, Idle particles per model
	
	Attachment-based positioning:
	- Uses AttachmentUtils to find semantic points (Muzzle, Center, Overhead)
	- NEVER uses hardcoded Vector3 offsets
	- Attachments are the "spatial contract" between Artists and Code
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local AttachmentUtils = require(Shared.utils.AttachmentUtils)
local GameSignals = require(Shared.signals.GameSignals)

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

-- VFX container
local _vfxFolder: Folder = nil
local _trove: any = nil

local VFXService = {}

-- Initialize VFX folder
function VFXService.Initialize()
	_vfxFolder = Instance.new("Folder")
	_vfxFolder.Name = "VFX"
	_vfxFolder.Parent = Workspace
	
	-- Create Trove for signal connections
	_trove = Trove.new()
	
	-- Connect to combat signals (observer pattern)
	_trove:Connect(GameSignals.OnZombieDeath, function(data)
		VFXService.PlayZombieDeath(data.Position)
	end)
	
	_trove:Connect(GameSignals.OnProjectileImpact, function(data)
		VFXService.PlayPeaImpact(data.Position, data.IsFrozen)
	end)
	
	_trove:Connect(GameSignals.OnSunCollected, function(data)
		VFXService.PlaySunCollect(data.Position)
	end)
	
	Logger.Info("VFX", "VFXService initialized with signal listeners")
end

-- Helper: Create a simple particle emitter
local function createEmitter(config: {
	Color: ColorSequence?,
	Size: NumberSequence?,
	Lifetime: NumberRange?,
	Speed: NumberRange?,
	SpreadAngle: Vector2?,
	Rate: number?,
	Drag: number?,
	Acceleration: Vector3?,
}): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = config.Color or ColorSequence.new(Color3.new(1, 1, 1))
	emitter.Size = config.Size or NumberSequence.new(0.5)
	emitter.Lifetime = config.Lifetime or NumberRange.new(0.5, 1)
	emitter.Speed = config.Speed or NumberRange.new(5, 10)
	emitter.SpreadAngle = config.SpreadAngle or Vector2.new(180, 180)
	emitter.Rate = config.Rate or 0 -- Burst mode by default
	emitter.Drag = config.Drag or 2
	emitter.Acceleration = config.Acceleration or Vector3.new(0, -20, 0)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	return emitter
end

-- Helper: Create a part for VFX attachment
local function createVFXPart(position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "VFXAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Parent = _vfxFolder
	return part
end

--[[
	🔥 EXPLOSION EFFECT - CherryBomb/PotatoMine
]]
function VFXService.PlayExplosion(position: Vector3, radius: number?)
	local actualRadius = radius or 9
	local part = createVFXPart(position)
	
	-- Fire particles
	local fireEmitter = createEmitter({
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 50, 50)),
		}),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(0.3, 4),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(20, 40),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
	})
	fireEmitter.Parent = part
	fireEmitter:Emit(30)
	
	-- Smoke particles
	local smokeEmitter = createEmitter({
		Color = ColorSequence.new(Color3.fromRGB(50, 50, 50)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 5),
		}),
		Lifetime = NumberRange.new(0.8, 1.5),
		Speed = NumberRange.new(5, 15),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 1,
		Acceleration = Vector3.new(0, 10, 0),
	})
	smokeEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	smokeEmitter.Parent = part
	smokeEmitter:Emit(15)
	
	-- Shockwave ring (using a Part with tween)
	local ring = Instance.new("Part")
	ring.Name = "Shockwave"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 150, 50)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.3
	ring.Parent = _vfxFolder
	
	local ringTween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, actualRadius * 2, actualRadius * 2),
		Transparency = 1,
	})
	ringTween:Play()
	
	-- Cleanup
	Debris:AddItem(part, 2)
	Debris:AddItem(ring, 0.5)
	
	Logger.Debug("VFX", `Explosion at {position}`)
end

--[[
	🟢 PEA IMPACT - When pea hits zombie
]]
function VFXService.PlayPeaImpact(position: Vector3, isFrozen: boolean?)
	local part = createVFXPart(position)
	
	local color = if isFrozen 
		then ColorSequence.new(Color3.fromRGB(150, 220, 255))
		else ColorSequence.new(Color3.fromRGB(100, 200, 50))
	
	local emitter = createEmitter({
		Color = color,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(8, 15),
		SpreadAngle = Vector2.new(90, 90),
		Drag = 8,
	})
	emitter.Parent = part
	emitter:Emit(8)
	
	-- Frozen peas leave ice sparkles
	if isFrozen then
		local iceEmitter = createEmitter({
			Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)),
			Size = NumberSequence.new(0.2, 0),
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 1,
			Acceleration = Vector3.new(0, -5, 0),
		})
		iceEmitter.LightEmission = 0.5
		iceEmitter.Parent = part
		iceEmitter:Emit(5)
	end
	
	Debris:AddItem(part, 1)
end

--[[
	💀 ZOMBIE DEATH - When zombie dies
]]
function VFXService.PlayZombieDeath(position: Vector3)
	local part = createVFXPart(position)
	
	-- Green/grey particles
	local emitter = createEmitter({
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 150, 100)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 80)),
		}),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(5, 15),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})
	emitter.Parent = part
	emitter:Emit(12)
	
	Debris:AddItem(part, 1.5)
	
	Logger.Debug("VFX", `Zombie death at {position}`)
end

--[[
	☀️ SUN COLLECTION - When sun is collected
]]
function VFXService.PlaySunCollect(position: Vector3)
	local part = createVFXPart(position)
	
	local emitter = createEmitter({
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 50)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
	})
	emitter.LightEmission = 0.8
	emitter.Parent = part
	emitter:Emit(10)
	
	Debris:AddItem(part, 1)
end

--[[
	💴 COIN COLLECTION - When coin is gained
]]
function VFXService.PlayCoinCollect(position: Vector3)
	local part = createVFXPart(position)
	
	local emitter = createEmitter({
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 150, 50)),
		}),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(8, 15),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
	})
	emitter.LightEmission = 0.5
	emitter.Parent = part
	emitter:Emit(8)
	
	Debris:AddItem(part, 1)
end

--[[
	🌱 PLANT PLACED - When plant is placed
]]
function VFXService.PlayPlantPlaced(position: Vector3)
	local part = createVFXPart(position)
	
	-- Dirt/earth particles
	local emitter = createEmitter({
		Color = ColorSequence.new(Color3.fromRGB(120, 80, 40)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(5, 12),
		SpreadAngle = Vector2.new(60, 60),
		Drag = 6,
		Acceleration = Vector3.new(0, -30, 0),
	})
	emitter.Parent = part
	emitter:Emit(10)
	
	-- Green sparkle
	local greenEmitter = createEmitter({
		Color = ColorSequence.new(Color3.fromRGB(100, 255, 100)),
		Size = NumberSequence.new(0.3, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 2,
	})
	greenEmitter.LightEmission = 0.6
	greenEmitter.Parent = part
	greenEmitter:Emit(6)
	
	Debris:AddItem(part, 1)
end

--[[
	❄️ SLOW EFFECT - Applied to zombie when hit by frozen pea
]]
function VFXService.PlaySlowApplied(position: Vector3)
	local part = createVFXPart(position)
	
	local emitter = createEmitter({
		Color = ColorSequence.new(Color3.fromRGB(180, 220, 255)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 0.5,
		Acceleration = Vector3.new(0, 2, 0),
	})
	emitter.LightEmission = 0.3
	emitter.Parent = part
	emitter:Emit(8)
	
	Debris:AddItem(part, 2.5)
end

--[[
	💥 DAMAGE FLASH - Flash a part red briefly
]]
function VFXService.FlashDamage(part: BasePart)
	if not part then return end
	
	local originalColor = part.Color
	part.Color = Color3.fromRGB(255, 100, 100)
	
	task.delay(0.1, function()
		if part and part.Parent then
			part.Color = originalColor
		end
	end)
end

--[[
	📍 SCREEN SHAKE - Camera shake effect
]]
function VFXService.ScreenShake(intensity: number?, duration: number?)
	local actualIntensity = intensity or 0.5
	local actualDuration = duration or 0.2
	
	local camera = Workspace.CurrentCamera
	if not camera then return end
	
	local originalCFrame = camera.CFrame
	local startTime = tick()
	
	task.spawn(function()
		while tick() - startTime < actualDuration do
			local progress = (tick() - startTime) / actualDuration
			local shake = actualIntensity * (1 - progress) -- Decay
			
			local offsetX = (math.random() - 0.5) * 2 * shake
			local offsetY = (math.random() - 0.5) * 2 * shake
			
			camera.CFrame = camera.CFrame * CFrame.new(offsetX, offsetY, 0)
			task.wait()
		end
	end)
end

--[[
	===========================================
	MODEL-AWARE VFX SYSTEM (Attachment-Based)
	===========================================
	These functions use Attachments as "spatial contracts":
	- Muzzle: Projectile spawn point
	- Center: Mass center for effects
	- Overhead: Health bar position
	
	RULE: Never use hardcoded Vector3 offsets.
	The Attachment IS the position.
]]

--[[
	🔫 PLANT SHOOT VFX - Model-aware + Attachment-based
	Position is read from "Muzzle" Attachment
	Checks model.VFX.Shoot first, falls back to generic pea splat
]]
function VFXService.PlayPlantShootFromModel(model: Model, isFrozen: boolean?)
	-- Get position from Muzzle Attachment (never hardcode!)
	local position = AttachmentUtils.GetWorldPosition(model, AttachmentUtils.Names.Muzzle)
	
	-- Try model-specific VFX first
	local vfxFolder = model:FindFirstChild("VFX")
	local shootVFX = vfxFolder and vfxFolder:FindFirstChild("Shoot")
	
	if shootVFX and shootVFX:IsA("ParticleEmitter") then
		local part = createVFXPart(position)
		local clone = shootVFX:Clone()
		clone.Parent = part
		clone:Emit(clone:GetAttribute("EmitCount") or 8)
		Debris:AddItem(part, clone.Lifetime.Max + 0.5)
		return
	end
	
	-- Fallback: Generic pea shoot
	local part = createVFXPart(position)
	local color = if isFrozen 
		then ColorSequence.new(Color3.fromRGB(150, 220, 255))
		else ColorSequence.new(Color3.fromRGB(100, 200, 50))
	
	local emitter = createEmitter({
		Color = color,
		Size = NumberSequence.new(0.3, 0),
		Lifetime = NumberRange.new(0.1, 0.2),
		Speed = NumberRange.new(5, 10),
		SpreadAngle = Vector2.new(30, 30),
		Drag = 5,
	})
	emitter.Parent = part
	emitter:Emit(5)
	Debris:AddItem(part, 0.5)
end

--[[
	🔫 PLANT SHOOT VFX - Legacy (position provided)
	Kept for backward compatibility
]]
function VFXService.PlayPlantShoot(model: Model?, position: Vector3, isFrozen: boolean?)
	-- If model provided, prefer Attachment-based position
	if model then
		local muzzlePos = AttachmentUtils.GetWorldPosition(model, AttachmentUtils.Names.Muzzle, false)
		position = muzzlePos
	end
	
	-- Try model-specific VFX first
	if model then
		local vfxFolder = model:FindFirstChild("VFX")
		local shootVFX = vfxFolder and vfxFolder:FindFirstChild("Shoot")
		
		if shootVFX and shootVFX:IsA("ParticleEmitter") then
			local part = createVFXPart(position)
			local clone = shootVFX:Clone()
			clone.Parent = part
			clone:Emit(clone:GetAttribute("EmitCount") or 8)
			Debris:AddItem(part, clone.Lifetime.Max + 0.5)
			return
		end
	end
	
	-- Fallback: Generic pea shoot
	local part = createVFXPart(position)
	local color = if isFrozen 
		then ColorSequence.new(Color3.fromRGB(150, 220, 255))
		else ColorSequence.new(Color3.fromRGB(100, 200, 50))
	
	local emitter = createEmitter({
		Color = color,
		Size = NumberSequence.new(0.3, 0),
		Lifetime = NumberRange.new(0.1, 0.2),
		Speed = NumberRange.new(5, 10),
		SpreadAngle = Vector2.new(30, 30),
		Drag = 5,
	})
	emitter.Parent = part
	emitter:Emit(5)
	Debris:AddItem(part, 0.5)
end

--[[
	💀 PLANT DEATH VFX - Model-aware + Attachment-based
	Position is read from "Center" Attachment
]]
function VFXService.PlayPlantDeathFromModel(model: Model)
	-- Get position from Center Attachment (never hardcode!)
	local position = AttachmentUtils.GetWorldPosition(model, AttachmentUtils.Names.Center)
	
	-- Try model-specific VFX first
	local vfxFolder = model:FindFirstChild("VFX")
	local deathVFX = vfxFolder and vfxFolder:FindFirstChild("Death")
	
	if deathVFX and deathVFX:IsA("ParticleEmitter") then
		local part = createVFXPart(position)
		local clone = deathVFX:Clone()
		clone.Parent = part
		clone:Emit(clone:GetAttribute("EmitCount") or 15)
		Debris:AddItem(part, clone.Lifetime.Max + 0.5)
		return
	end
	
	-- Fallback: Generic plant death
	local part = createVFXPart(position)
	local emitter = createEmitter({
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 180, 100)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 120, 80)),
		}),
		Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(5, 12),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
	})
	emitter.Parent = part
	emitter:Emit(12)
	Debris:AddItem(part, 1)
end

--[[
	💀 PLANT DEATH VFX - Legacy (position provided)
	Kept for backward compatibility
]]
function VFXService.PlayPlantDeath(model: Model?, position: Vector3)
	-- If model provided, prefer Attachment-based position
	if model then
		local centerPos = AttachmentUtils.GetWorldPosition(model, AttachmentUtils.Names.Center, false)
		position = centerPos
	end
	
	-- Try model-specific VFX first
	if model then
		local vfxFolder = model:FindFirstChild("VFX")
		local deathVFX = vfxFolder and vfxFolder:FindFirstChild("Death")
		
		if deathVFX and deathVFX:IsA("ParticleEmitter") then
			local part = createVFXPart(position)
			local clone = deathVFX:Clone()
			clone.Parent = part
			clone:Emit(clone:GetAttribute("EmitCount") or 15)
			Debris:AddItem(part, clone.Lifetime.Max + 0.5)
			return
		end
	end
	
	-- Fallback: Generic plant death
	local part = createVFXPart(position)
	local emitter = createEmitter({
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 180, 100)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 120, 80)),
		}),
		Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(5, 12),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
	})
	emitter.Parent = part
	emitter:Emit(12)
	Debris:AddItem(part, 1)
end

--[[
	🌿 ATTACH IDLE VFX - Model-aware
	Clones model.VFX.Idle and parents to the model's Visual
	Returns the emitter for cleanup later
]]
function VFXService.AttachIdleVFX(model: Model): ParticleEmitter?
	local vfxFolder = model:FindFirstChild("VFX")
	local idleVFX = vfxFolder and vfxFolder:FindFirstChild("Idle")
	
	if idleVFX and idleVFX:IsA("ParticleEmitter") then
		local visual = model:FindFirstChild("Visual")
		local targetPart = visual and visual:FindFirstChildWhichIsA("BasePart")
		
		if targetPart then
			local clone = idleVFX:Clone()
			clone.Name = "IdleVFX_Active"
			clone.Parent = targetPart
			-- Idle VFX uses Rate, not Emit
			clone.Enabled = true
			return clone
		end
	end
	
	return nil
end

--[[
	Stop idle VFX attached to a model
]]
function VFXService.DetachIdleVFX(model: Model)
	local visual = model:FindFirstChild("Visual")
	if visual then
		for _, part in visual:GetDescendants() do
			if part:IsA("ParticleEmitter") and part.Name == "IdleVFX_Active" then
				part.Enabled = false
				Debris:AddItem(part, part.Lifetime.Max)
			end
		end
	end
end

return VFXService
