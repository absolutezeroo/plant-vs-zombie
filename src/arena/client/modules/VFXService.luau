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
		VFXService.PlayProjectileImpact(data.Position, data.ProjectileType, data.IsFrozen, data.IsEnhanced)
	end)
	
	_trove:Connect(GameSignals.OnSunCollected, function(data)
		VFXService.PlaySunCollect(data.Position)
	end)
	
	Logger.Info("VFX", "VFXService initialized with signal listeners")
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

-- VFX Assets folder (lazy loaded)
local _vfxAssets: Folder? = nil

local function getVFXAssets(): Folder?
	if _vfxAssets then return _vfxAssets end
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
				local clone = child:Clone()
				clone.Parent = part
				local emitCount = clone:GetAttribute("EmitCount")
				clone:Emit(if type(emitCount) == "number" then emitCount else 8)
			elseif child:IsA("PointLight") or child:IsA("SpotLight") then
				local clone = child:Clone() :: Light
				clone.Parent = part
				-- Fade out light
				TweenService:Create(clone, TweenInfo.new(0.5), { Brightness = 0 }):Play()
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
					local emitCount = clone:GetAttribute("EmitCount")
					clone:Emit(if type(emitCount) == "number" then emitCount else 8)
				end
			end
		end
		Debris:AddItem(part, 1)
		Logger.Debug("VFX", `{vfxName} not found, using fallback`)
		return false
	end
end

--[[
	🔥 EXPLOSION EFFECT - CherryBomb/PotatoMine
	ASSET-BASED: Looks for Assets/VFX/Explosion
]]
function VFXService.PlayExplosion(position: Vector3, radius: number?)
	local actualRadius = radius or 9
	
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
	🎯 PROJECTILE IMPACT - When any projectile hits zombie
	ASSET-BASED: Looks for VFX in Assets/VFX/{Variant}_Impact
	Falls back to generic VFX if not found
]]
function VFXService.PlayProjectileImpact(position: Vector3, projectileType: string?, isFrozen: boolean?, isEnhanced: boolean?)
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
		elseif isEnhanced or variant == "FirePea"
		then Color3.fromRGB(255, 150, 50)
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
	ASSET-BASED: Looks for Assets/VFX/Plant_Placed
]]
function VFXService.PlayPlantPlaced(position: Vector3)
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
		local emitCount = clone:GetAttribute("EmitCount")
		clone:Emit(if type(emitCount) == "number" then emitCount else 8)
		Debris:AddItem(part, clone.Lifetime.Max + 0.5)
		return
	end
	
	-- Fallback: Asset-based generic shoot
	local vfxName = if isFrozen then "FrozenPlant_Shoot" else "Plant_Shoot"
	local fallbackColor = if isFrozen 
		then Color3.fromRGB(150, 220, 255)
		else Color3.fromRGB(100, 200, 50)
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
			local clone = shootVFX:Clone()
			clone.Parent = part
			local emitCount = clone:GetAttribute("EmitCount")
			clone:Emit(if type(emitCount) == "number" then emitCount else 8)
			Debris:AddItem(part, clone.Lifetime.Max + 0.5)
			return
		end
	end
	
	-- Fallback: Asset-based generic shoot
	local vfxName = if isFrozen then "FrozenPlant_Shoot" else "Plant_Shoot"
	local fallbackColor = if isFrozen 
		then Color3.fromRGB(150, 220, 255)
		else Color3.fromRGB(100, 200, 50)
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
		local clone = deathVFX:Clone()
		clone.Parent = part
		local emitCount = clone:GetAttribute("EmitCount")
		clone:Emit(if type(emitCount) == "number" then emitCount else 15)
		Debris:AddItem(part, clone.Lifetime.Max + 0.5)
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
	
	-- Try model-specific VFX first
	if model then
		local vfxFolder = model:FindFirstChild("VFX")
		local deathVFX = vfxFolder and vfxFolder:FindFirstChild("Death")
		
		if deathVFX and deathVFX:IsA("ParticleEmitter") then
			local part = createVFXPart(position)
			local clone = deathVFX:Clone()
			clone.Parent = part
			local emitCount = clone:GetAttribute("EmitCount")
			clone:Emit(if type(emitCount) == "number" then emitCount else 15)
			Debris:AddItem(part, clone.Lifetime.Max + 0.5)
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
