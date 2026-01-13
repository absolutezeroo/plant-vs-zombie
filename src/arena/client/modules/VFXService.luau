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
local VFXUtils = require(Shared.utils.VFXUtils)
local ChanceUtils = require(Shared.utils.ChanceUtils)

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
		VFXService.PlayProjectileImpact(data.Position, data.ProjectileType, data.IsFrozen, data.IsEnhanced)
	end)

	_trove:Connect(GameSignals.OnSunCollected, function(data)
		VFXService.PlaySunCollect(data.Position)
	end)

	Logger.Info("VFX", "VFXService initialized with signal listeners")
end

-- Helper: Create a part for VFX attachment (delegates to VFXUtils)
local function createVFXPart(position: Vector3): Part
	local part = VFXUtils.CreateVFXAnchor(position, "VFXAnchor")
	part.Parent = _vfxFolder
	return part
end

-- VFX Assets folder (lazy loaded)
local _vfxAssets: Folder? = nil

local function getVFXAssets(): Folder?
	if _vfxAssets then
		return _vfxAssets
	end
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	_vfxAssets = Assets and Assets:FindFirstChild("VFX") :: Folder?
	return _vfxAssets
end

--[[
	Generic VFX player from Assets/VFX/{name}
	Returns true if asset was found and played, false otherwise
]]
local function playVFXFromAsset(position: Vector3, vfxName: string, fallbackColor: Color3?): boolean
	local vfxAssets = getVFXAssets()
	local vfxTemplate = vfxAssets and vfxAssets:FindFirstChild(vfxName)

	local part = createVFXPart(position)

	if vfxTemplate then
		-- Clone and play all ParticleEmitters from the asset
		for _, child in vfxTemplate:GetChildren() do
			if child:IsA("ParticleEmitter") then
				VFXUtils.CloneEmitAndCleanup(child, part)
			elseif child:IsA("PointLight") or child:IsA("SpotLight") then
				VFXUtils.CloneAndFadeLight(child, part, 0.5)
			end
		end
		Debris:AddItem(part, 2)
		Logger.Debug("VFX", `{vfxName} played from asset`)
		return true
	else
		-- Fallback: Use Generic_Fallback asset with color tinting
		local fallbackTemplate = vfxAssets and vfxAssets:FindFirstChild("Generic_Fallback")
		if fallbackTemplate then
			for _, child in fallbackTemplate:GetChildren() do
				if child:IsA("ParticleEmitter") then
					local clone = child:Clone()
					if fallbackColor then
						clone.Color = ColorSequence.new(fallbackColor)
					end
					clone.Parent = part
					VFXUtils.Emit(clone)
				end
			end
		end
		Debris:AddItem(part, 1)
		Logger.Debug("VFX", `{vfxName} not found, using fallback`)
		return false
	end
end

--[[
	Advanced VFX player with support for EmitDelay attribute
	For complex multi-phase effects (like DoomShroom nuke)
	Reads EmitDelay attribute from particles to stagger emissions
]]
local function playVFXFromAssetWithDelay(position: Vector3, vfxName: string): boolean
	local vfxAssets = getVFXAssets()
	local vfxTemplate = vfxAssets and vfxAssets:FindFirstChild(vfxName)

	if not vfxTemplate then
		Logger.Debug("VFX", `{vfxName} asset not found`)
		return false
	end

	local part = createVFXPart(position)
	local maxLifetime: number = 0

	-- Clone and play all effects with delay support
	for _, child in vfxTemplate:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local delay: number = (child:GetAttribute("EmitDelay") :: number?) or 0
			local emitCount: number = (child:GetAttribute("EmitCount") :: number?) or 20
			local lifetime: number = child.Lifetime.Max + delay

			if lifetime > maxLifetime then
				maxLifetime = lifetime
			end

			local clone = child:Clone()
			clone.Enabled = false
			clone.Parent = part

			if delay > 0 then
				task.delay(delay, function()
					if clone.Parent then
						clone:Emit(emitCount)
					end
				end)
			else
				clone:Emit(emitCount)
			end

		elseif child:IsA("PointLight") then
			local delay: number = (child:GetAttribute("Delay") :: number?) or 0
			local fadeTime: number = (child:GetAttribute("FadeTime") :: number?) or 0.5
			local peakBrightness: number = (child:GetAttribute("PeakBrightness") :: number?) or child.Brightness

			if delay > 0 then
				task.delay(delay, function()
					if part.Parent then
						VFXUtils.CloneAndFadeLight(child, part, fadeTime)
					end
				end)
			else
				-- Flash effect: quick bright then fade
				local lightClone = child:Clone()
				lightClone.Parent = part
				lightClone.Brightness = peakBrightness

				local fadeTween = TweenService:Create(lightClone, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Brightness = 0,
				})
				fadeTween:Play()
			end

			if fadeTime > maxLifetime then
				maxLifetime = fadeTime
			end
		end
	end

	-- Cleanup after all effects complete
	Debris:AddItem(part, maxLifetime + 1)
	Logger.Debug("VFX", `{vfxName} played with delays (lifetime={maxLifetime}s)`)
	return true
end

--[[
	🔥 EXPLOSION EFFECT - CherryBomb/PotatoMine
	ASSET-BASED + VOXEL: Debris burst + shockwave ring
]]
function VFXService.PlayExplosion(position: Vector3, radius: number?)
	local actualRadius = radius or 9

	-- Play voxel explosion burst (debris flying)
	VFXUtils.ExplosionBurst(position)

	-- Try asset-based VFX
	local played = playVFXFromAsset(position, "Explosion", Color3.fromRGB(255, 150, 50))

	-- Always add shockwave ring (procedural - hard to do in particle editor)
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

	Debris:AddItem(ring, 0.5)

	if not played then
		Logger.Debug("VFX", `Explosion fallback at {position}`)
	end
end

--[[
	💀 CRATER EXPLOSION - DoomShroom nuclear-style explosion
	
	ASSET-FIRST: Uses ReplicatedStorage/Assets/VFX/DoomShroom_Explosion
	Contains: MushroomStem, MushroomCap, Shockwave, DebrisBurst, ToxicSparks,
	          NuclearFlash, ToxicGlow, FlashBurst, LingeringCloud
	
	Procedural elements (geometric, hard to do in particles):
	- Neon shockwave ring (expanding cylinder)
	- Ground crater mark
]]
function VFXService.PlayCraterExplosion(position: Vector3, radius: number?)
	local actualRadius = radius or 12

	-- === ASSET-BASED VFX (primary) ===
	local played = playVFXFromAssetWithDelay(position, "DoomShroom_Explosion")
	
	if not played then
		-- Fallback: CraterBurst voxels + generic particles
		VFXUtils.CraterBurst(position)
		playVFXFromAsset(position, "Explosion", Color3.fromRGB(100, 50, 150))
	end

	-- === PROCEDURAL: Expanding shockwave ring (geometric) ===
	local ring = Instance.new("Part")
	ring.Name = "NukeShockwave"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(150, 80, 200) -- Purple neon
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.5, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = _vfxFolder

	local ringTween = TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.5, actualRadius * 3, actualRadius * 3),
		Transparency = 1,
	})
	ringTween:Play()
	Debris:AddItem(ring, 1)

	-- === PROCEDURAL: Ground crater mark ===
	local crater = Instance.new("Part")
	crater.Name = "CraterMark"
	crater.Anchored = true
	crater.CanCollide = false
	crater.CanTouch = false
	crater.CastShadow = false
	crater.Material = Enum.Material.Slate
	crater.Color = Color3.fromRGB(20, 15, 25) -- Dark purple-charred
	crater.Shape = Enum.PartType.Cylinder
	crater.Size = Vector3.new(0.15, actualRadius * 2, actualRadius * 2)
	crater.CFrame = CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	crater.Transparency = 0.4
	crater.Parent = _vfxFolder

	local craterTween = TweenService:Create(crater, TweenInfo.new(4, Enum.EasingStyle.Linear), {
		Transparency = 1,
	})
	craterTween:Play()
	Debris:AddItem(crater, 4.5)

	-- Heavy screen shake for nuke
	VFXService.ScreenShake(2.5, 0.8)
	
	Logger.Info("VFX", `DoomShroom nuke at {position} (asset={played})`)
end

--[[
	❄️ ICE SHATTER - IceShroom or frozen entity breaking
]]
function VFXService.PlayIceShatter(position: Vector3)
	VFXUtils.IceBurst(position)
	playVFXFromAsset(position, "Ice_Shatter", Color3.fromRGB(180, 220, 255))
end

--[[
	🎯 PROJECTILE IMPACT - When any projectile hits zombie
	ASSET-BASED: Looks for VFX in Assets/VFX/{Variant}_Impact
	Falls back to generic VFX if not found
]]
function VFXService.PlayProjectileImpact(
	position: Vector3,
	projectileType: string?,
	isFrozen: boolean?,
	isEnhanced: boolean?
)
	local variant = projectileType or "Pea"

	-- Determine which VFX asset to use
	local vfxName: string
	if isEnhanced or variant == "FirePea" then
		vfxName = "FirePea_Impact"
	elseif isFrozen or variant == "FrozenPea" then
		vfxName = "FrozenPea_Impact"
	else
		vfxName = variant .. "_Impact"
	end

	-- Determine fallback color
	local fallbackColor = if isFrozen or variant == "FrozenPea"
		then Color3.fromRGB(150, 220, 255)
		elseif isEnhanced or variant == "FirePea" then Color3.fromRGB(255, 150, 50)
		else Color3.fromRGB(100, 200, 50)

	-- Try asset, fallback to Pea_Impact, then fallback to code
	local played = playVFXFromAsset(position, vfxName, nil)
	if not played then
		played = playVFXFromAsset(position, "Pea_Impact", fallbackColor)
	end
end

-- Legacy alias for backward compatibility
function VFXService.PlayPeaImpact(position: Vector3, isFrozen: boolean?)
	VFXService.PlayProjectileImpact(position, "Pea", isFrozen, false)
end

--[[
	💀 ZOMBIE DEATH - When zombie dies
	ASSET-BASED: Looks for Assets/VFX/Zombie_Death
]]
function VFXService.PlayZombieDeath(position: Vector3)
	playVFXFromAsset(position, "Zombie_Death", Color3.fromRGB(100, 150, 100))
end

--[[
	☀️ SUN COLLECTION - When sun is collected
	ASSET-BASED: Looks for Assets/VFX/Sun_Collect
]]
function VFXService.PlaySunCollect(position: Vector3)
	playVFXFromAsset(position, "Sun_Collect", Color3.fromRGB(255, 220, 50))
end

--[[
	💴 COIN COLLECTION - When coin is gained
	ASSET-BASED: Looks for Assets/VFX/Coin_Collect
]]
function VFXService.PlayCoinCollect(position: Vector3)
	playVFXFromAsset(position, "Coin_Collect", Color3.fromRGB(255, 200, 50))
end

--[[
	🌱 PLANT PLACED - When plant is placed
	VOXEL-BASED: Dirt burst effect + Asset fallback
]]
function VFXService.PlayPlantPlaced(position: Vector3)
	-- Play voxel dirt burst (procedural)
	VFXUtils.DirtBurst(position)
	
	-- Also play asset-based VFX if available (layered effect)
	playVFXFromAsset(position, "Plant_Placed", Color3.fromRGB(120, 100, 60))
end

--[[
	❄️ SLOW EFFECT - Applied to zombie when hit by frozen pea
	ASSET-BASED: Looks for Assets/VFX/Slow_Applied
]]
function VFXService.PlaySlowApplied(position: Vector3)
	playVFXFromAsset(position, "Slow_Applied", Color3.fromRGB(180, 220, 255))
end

--[[
	💥 DAMAGE FLASH - Flash a part red briefly
]]
function VFXService.FlashDamage(part: BasePart)
	if not part then
		return
	end

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
	if not camera then
		return
	end

	local originalCFrame = camera.CFrame
	local startTime = tick()

	task.spawn(function()
		while tick() - startTime < actualDuration do
			local progress = (tick() - startTime) / actualDuration
			local shake = actualIntensity * (1 - progress) -- Decay

			local offsetX = ChanceUtils.RandomOffset(shake)
			local offsetY = ChanceUtils.RandomOffset(shake)

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
		VFXUtils.CloneEmitAndCleanup(shootVFX, part)
		Debris:AddItem(part, shootVFX.Lifetime.Max + 0.5)
		return
	end

	-- Fallback: Asset-based generic shoot
	local vfxName = if isFrozen then "FrozenPlant_Shoot" else "Plant_Shoot"
	local fallbackColor = if isFrozen then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(100, 200, 50)
	playVFXFromAsset(position, vfxName, fallbackColor)
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
			VFXUtils.CloneEmitAndCleanup(shootVFX, part)
			Debris:AddItem(part, shootVFX.Lifetime.Max + 0.5)
			return
		end
	end

	-- Fallback: Asset-based generic shoot
	local vfxName = if isFrozen then "FrozenPlant_Shoot" else "Plant_Shoot"
	local fallbackColor = if isFrozen then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(100, 200, 50)
	playVFXFromAsset(position, vfxName, fallbackColor)
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
		VFXUtils.CloneEmitAndCleanup(deathVFX, part, 15)
		Debris:AddItem(part, deathVFX.Lifetime.Max + 0.5)
		return
	end

	-- Fallback: Asset-based generic plant death
	playVFXFromAsset(position, "Plant_Death", Color3.fromRGB(100, 180, 100))
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

	-- Play voxel plant burst (procedural debris)
	VFXUtils.PlantBurst(position)

	-- Try model-specific VFX first
	if model then
		local vfxFolder = model:FindFirstChild("VFX")
		local deathVFX = vfxFolder and vfxFolder:FindFirstChild("Death")

		if deathVFX and deathVFX:IsA("ParticleEmitter") then
			local part = createVFXPart(position)
			VFXUtils.CloneEmitAndCleanup(deathVFX, part, 15)
			Debris:AddItem(part, deathVFX.Lifetime.Max + 0.5)
			return
		end
	end

	-- Fallback: Asset-based generic plant death
	playVFXFromAsset(position, "Plant_Death", Color3.fromRGB(100, 180, 100))
end

--[[
	🌿 ATTACH IDLE VFX - Model-aware
	Clones model.VFX.Idle and parents to the model's Visual
	Returns the emitter for cleanup later
]]
function VFXService.AttachIdleVFX(model: Model): ParticleEmitter?
	return VFXUtils.AttachIdleVFX(model, "Idle")
end

--[[
	Stop idle VFX attached to a model
]]
function VFXService.DetachIdleVFX(model: Model)
	VFXUtils.DetachIdleVFX(model)
end

-- ============================================
-- MUTATION VFX EFFECTS
-- ============================================

--[[
	🔥 BURN APPLIED - When zombie starts burning
	ASSET-BASED: Looks for Assets/VFX/Burn_Applied
]]
function VFXService.PlayBurnApplied(position: Vector3)
	playVFXFromAsset(position, "Burn_Applied", Color3.fromRGB(255, 100, 0))
end

--[[
	🔥 BURN TICK - Each burn damage tick
	ASSET-BASED: Looks for Assets/VFX/Burn_Tick
]]
function VFXService.PlayBurnTick(position: Vector3)
	playVFXFromAsset(position, "Burn_Tick", Color3.fromRGB(255, 80, 0))
end

--[[
	❄️ FREEZE APPLIED - When zombie is frozen solid
	ASSET-BASED: Looks for Assets/VFX/Freeze_Applied
]]
function VFXService.PlayFreezeApplied(position: Vector3)
	playVFXFromAsset(position, "Freeze_Applied", Color3.fromRGB(150, 220, 255))
end

--[[
	❄️ FREEZE THAW - When zombie unfreezes
	ASSET-BASED: Looks for Assets/VFX/Freeze_Thaw
]]
function VFXService.PlayFreezeThaw(position: Vector3)
	playVFXFromAsset(position, "Freeze_Thaw", Color3.fromRGB(200, 240, 255))
end

--[[
	⚡ CHAIN LIGHTNING - Electric arc between targets
	Creates a beam effect between source and target
]]
function VFXService.PlayChainLightning(sourcePos: Vector3, targetPos: Vector3, damage: number?)
	-- Create beam
	VFXUtils.CreateBeam(sourcePos, targetPos, "Lightning_Beam", Color3.fromRGB(255, 255, 100), 0.25)

	-- Play spark at target
	playVFXFromAsset(targetPos, "Electric_Spark", Color3.fromRGB(255, 255, 100))

	-- Screen shake for powerful hits
	if damage and damage >= 50 then
		VFXService.ScreenShake(0.3, 0.1)
	end

	Logger.Debug("VFX", `Chain lightning from {sourcePos} to {targetPos}`)
end

--[[
	☠️ POISON CLOUD - Persistent poison area effect
	Creates a lingering cloud at position
]]
function VFXService.PlayPoisonCloud(position: Vector3, radius: number, duration: number)
	local played = playVFXFromAsset(position, "Poison_Cloud", Color3.fromRGB(100, 255, 100))

	if not played then
		-- Create procedural poison cloud (multiple emitters for coverage)
		local part = createVFXPart(position)

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromRGB(100, 200, 100))
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.5),
			NumberSequenceKeypoint.new(0.5, radius),
			NumberSequenceKeypoint.new(1, radius * 0.3),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.Rate = 20
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.RotSpeed = NumberRange.new(-30, 30)
		emitter.LightEmission = 0.3
		emitter.Parent = part

		-- Schedule cleanup after duration
		task.delay(duration, function()
			if emitter and emitter.Parent then
				emitter.Enabled = false
			end
		end)

		Debris:AddItem(part, duration + 3)
	end

	Logger.Debug("VFX", `Poison cloud at {position}, radius {radius}, duration {duration}`)
end

--[[
	🌑 LIFESTEAL DRAIN - Dark energy from zombie to plant
]]
function VFXService.PlayLifesteal(zombiePos: Vector3, plantPos: Vector3, healAmount: number)
	-- Create drain beam
	VFXUtils.CreateBeam(zombiePos, plantPos, "Lifesteal_Beam", Color3.fromRGB(80, 40, 120), 0.3)

	-- Play heal VFX at plant
	playVFXFromAsset(plantPos, "Shadow_Heal", Color3.fromRGB(80, 40, 120))

	Logger.Debug("VFX", `Lifesteal {healAmount} from {zombiePos} to {plantPos}`)
end

--[[
	💥 SPLASH DAMAGE - Ring effect on ground
]]
function VFXService.PlaySplashDamage(position: Vector3, radius: number)
	local played = playVFXFromAsset(position, "Splash_Ring", Color3.fromRGB(255, 200, 100))

	if not played then
		-- Create procedural splash ring
		local ring = Instance.new("Part")
		ring.Name = "SplashRing"
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanTouch = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 200, 100)
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.1, 1, 1)
		ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.3
		ring.Parent = _vfxFolder

		local ringTween =
			TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.1, radius * 2, radius * 2),
				Transparency = 1,
			})
		ringTween:Play()

		Debris:AddItem(ring, 0.4)
	end
end

--[[
	⭐ STUN APPLIED - Stars above zombie
]]
function VFXService.PlayStunApplied(position: Vector3)
	playVFXFromAsset(position + Vector3.new(0, 2, 0), "Stunned_Indicator", Color3.fromRGB(255, 255, 100))
end

--[[
	☀️ SUN BURST - Golden burst for kill bonus sun
]]
function VFXService.PlaySunBurst(position: Vector3)
	playVFXFromAsset(position, "Sun_Burst", Color3.fromRGB(255, 220, 50))
end

-- ============================================
-- STATUS OVERLAY MANAGEMENT
-- ============================================

-- Cache of active status overlays per entity
local _statusOverlays: { [number]: { [string]: Instance } } = {}

--[[
	Apply a status overlay to a zombie model
	@param entityId number - Entity ID for tracking
	@param model Model - The zombie model
	@param statusType string - "Burn", "Freeze", "Poison", "Stun"
	@param duration number? - Duration (nil = permanent)
]]
function VFXService.ApplyStatusOverlay(entityId: number, model: Model, statusType: string, duration: number?)
	-- Initialize cache for entity
	if not _statusOverlays[entityId] then
		_statusOverlays[entityId] = {}
	end

	-- Remove existing overlay of same type
	if _statusOverlays[entityId][statusType] then
		VFXUtils.RemoveStatusOverlay(model, statusType)
	end

	-- Apply new overlay
	local overlay = VFXUtils.ApplyStatusOverlay(model, statusType, duration)
	if overlay then
		_statusOverlays[entityId][statusType] = overlay
	end
end

--[[
	Remove a status overlay from a zombie
]]
function VFXService.RemoveStatusOverlay(entityId: number, model: Model, statusType: string)
	VFXUtils.RemoveStatusOverlay(model, statusType)

	if _statusOverlays[entityId] then
		_statusOverlays[entityId][statusType] = nil
	end
end

--[[
	Cleanup all overlays for an entity (on death)
]]
function VFXService.CleanupEntityOverlays(entityId: number)
	_statusOverlays[entityId] = nil
end

return VFXService
