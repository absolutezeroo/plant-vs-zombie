--!strict
--[[
	VFXAudioSystem.luau - Client system for VFX initialization and music management
	
	Priority: 350 (after render systems)
	
	This system:
	- Initializes VFX and Audio services
	- Manages dynamic music based on game state
	- Wave music transitions (calm -> wave -> intense)
	
	V3 Architecture: Matter Hooks pattern
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Packages = ReplicatedStorage:FindFirstChild("Packages")
assert(Packages, "VFXAudioSystem: Packages folder not found")
local Trove = require(Packages.Trove)
local Hooks = require(Packages.MatterHooks)

-- Use FindFirstChild to avoid yielding (modules should exist from init.client.luau)
local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "VFXAudioSystem: Shared folder not found")
local Logger = require(Shared.utils.core.Logger)

-- Client root (script.Parent.Parent.Parent since we're in systems/presentation/)
local Client = script.Parent.Parent.Parent
local Modules = Client:FindFirstChild("modules")
assert(Modules, "VFXAudioSystem: modules folder not found")
local VFXService = require(Modules.VFXService)
local AudioService = require(Modules.AudioService)
local Network = require(Shared.network.generated.client)

-- Controllers
local Controllers = Client:FindFirstChild("controllers")
assert(Controllers, "VFXAudioSystem: controllers folder not found")
local FloatingTextController = require(Controllers.FloatingTextController)

-- Selection state (in modules folder)
local SelectionState = require(Modules.SelectionState)

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------
type VFXAudioState = {
	IsWaveActive: boolean,
	CurrentWave: number,
}

--------------------------------------------------------------------------------
-- SYSTEM FUNCTION
--------------------------------------------------------------------------------
local function VFXAudioSystem(_world: any)
	-- State managed via Hooks.useMap
	local state = Hooks.useMap("VFXAudioState", {
		IsWaveActive = false,
		CurrentWave = 0,
	})

	-- Initialize services and connect network handlers once via useMemo
	local trove = Hooks.useMemo(function()
		local t = Trove.new()

		VFXService.Initialize()
		AudioService.Initialize()

		-- Start with calm music
		AudioService.SetMusic("Calm")

		-- Connect to wave events for music changes
		t:Add(Network.WaveStarted.On(function(data)
			state.value.IsWaveActive = true
			state.value.CurrentWave = data.WaveNumber

			-- Wave 0 = preparation phase, don't play wave start sound
			if state.value.CurrentWave == 0 then
				AudioService.SetMusic("Calm")
				Logger.Debug("VFXAudio", "Preparation phase started - music: calm")
				return
			end

			-- Intense music for later waves
			if state.value.CurrentWave >= 5 then
				AudioService.SetMusic("Intense")
			else
				AudioService.SetMusic("Wave")
			end

			-- Play wave start sound
			AudioService.PlayWaveStart()
			Logger.Debug(
				"VFXAudio",
				`Wave {state.value.CurrentWave} started - music: {if state.value.CurrentWave >= 5 then "intense" else "wave"}`
			)
		end))

		t:Add(Network.WaveCompleted.On(function(_data)
			state.value.IsWaveActive = false
			-- Return to calm music between waves
			AudioService.SetMusic("Calm")
			Logger.Debug("VFXAudio", `Wave completed - music: Calm`)
		end))

		t:Add(Network.GameOver.On(function(data)
			-- Stop music and play end sound
			AudioService.StopMusic()
			if data.Victory then
				AudioService.PlayVictory()
			else
				AudioService.PlayDefeat()
			end
		end))

		-- Explosion VFX event
		t:Add(Network.ExplosionVFX.On(function(data)
			local pos = Vector3.new(data.PositionX, data.PositionY, data.PositionZ)

			-- DoomShroom uses crater explosion (darker, heavier)
			if data.IsCrater then
				VFXService.PlayCraterExplosion(pos, data.Radius)
				AudioService.PlayExplosion(pos) -- Heavy explosion sound
				Logger.Debug("VFXAudio", `Crater explosion at {pos}`)
			else
				VFXService.PlayExplosion(pos, data.Radius)
				AudioService.PlayExplosion(pos)
				VFXService.ScreenShake(0.8, 0.3)
				Logger.Debug("VFXAudio", `Explosion at {pos}`)
			end
		end))

		-- ========================================
		-- MUTATION VFX EVENTS
		-- ========================================

		-- Status effect applied (Burn, Freeze, Poison, Stun)
		t:Add(Network.StatusApplied.On(function(data)
			local pos = Vector3.new(data.PositionX, data.PositionY, data.PositionZ)
			local statusType = tostring(data.StatusType)

			if statusType == "Burn" then
				VFXService.PlayBurnApplied(pos)
				AudioService.PlaySound("FireIgnite", { Position = pos })
			elseif statusType == "Freeze" then
				VFXService.PlayFreezeApplied(pos)
				AudioService.PlaySound("IceFreeze", { Position = pos })
			elseif statusType == "Slow" then
				VFXService.PlaySlowApplied(pos)
			elseif statusType == "Poison" then
				VFXService.PlayBurnApplied(pos) -- Reuse burn for now
				AudioService.PlaySound("PoisonApply", { Position = pos })
			elseif statusType == "Stun" then
				VFXService.PlayStunApplied(pos)
				AudioService.PlaySound("Stun", { Position = pos })
			end

			Logger.Debug("VFXAudio", `Status {statusType} applied at {pos}`)
		end))

		-- Status effect removed
		t:Add(Network.StatusRemoved.On(function(data)
			local statusType = tostring(data.StatusType)

			-- Thaw effect when freeze ends
			if statusType == "Freeze" then
				-- We don't have position here, just log for now
				Logger.Debug("VFXAudio", `Status {statusType} removed from entity {data.EntityId}`)
			end
		end))

		-- Chain Lightning beam VFX
		t:Add(Network.ChainLightningVFX.On(function(data)
			local sourcePos = Vector3.new(data.SourceX, data.SourceY, data.SourceZ)
			local targetPos = Vector3.new(data.TargetX, data.TargetY, data.TargetZ)

			VFXService.PlayChainLightning(sourcePos, targetPos, data.Damage)
			AudioService.PlaySound("ElectricZap", { Position = targetPos })

			Logger.Debug("VFXAudio", `Chain lightning: {sourcePos} -> {targetPos}`)
		end))

		-- Poison Cloud persistent VFX
		t:Add(Network.PoisonCloudVFX.On(function(data)
			local pos = Vector3.new(data.PositionX, data.PositionY, data.PositionZ)

			VFXService.PlayPoisonCloud(pos, data.Radius, data.Duration)
			AudioService.PlaySound("PoisonCloud", { Position = pos })

			Logger.Debug("VFXAudio", `Poison cloud at {pos}, radius {data.Radius}`)
		end))

		-- Lifesteal VFX (drain from zombie to plant)
		t:Add(Network.LifestealVFX.On(function(data)
			local zombiePos = Vector3.new(data.ZombieX, data.ZombieY, data.ZombieZ)
			-- We need plant position - for now estimate based on entity
			-- TODO: Add plant position to event or lookup from render cache
			local plantPos = zombiePos + Vector3.new(-5, 0, 0) -- Estimate: plant is left of zombie

			VFXService.PlayLifesteal(zombiePos, plantPos, data.HealAmount)

			Logger.Debug("VFXAudio", `Lifesteal {data.HealAmount} from zombie`)
		end))

		-- Splash Damage VFX (ring on ground)
		t:Add(Network.SplashDamageVFX.On(function(data)
			local pos = Vector3.new(data.PositionX, data.PositionY, data.PositionZ)

			VFXService.PlaySplashDamage(pos, data.Radius)

			Logger.Debug("VFXAudio", `Splash damage at {pos}, radius {data.Radius}`)
		end))

		-- XP Gained feedback (floating text near player)
		t:Add(Network.XPGained.SetCallback(function(data)
			-- Show XP popup at screen center (no world position needed)
			local camera = workspace.CurrentCamera
			if camera then
				local screenPos = camera.CFrame.Position + camera.CFrame.LookVector * 5
				FloatingTextController.ShowXP(screenPos, data.Amount)
			end

			Logger.Debug("VFXAudio", `XP gained: +{data.Amount}`)
		end))

		-- Level Up celebration
		t:Add(Network.LevelUp.SetCallback(function(data)
			-- Show level up popup at screen center
			local camera = workspace.CurrentCamera
			if camera then
				local screenPos = camera.CFrame.Position + camera.CFrame.LookVector * 5
				FloatingTextController.ShowLevelUp(screenPos, data.NewLevel)
			end

			-- Play level up sound
			AudioService.PlaySound("LevelUp")

			Logger.Info("VFXAudio", `Level up! New level: {data.NewLevel}`)
		end))

		-- PlantFood Collected (from glowing zombie death)
		t:Add(Network.PlantFoodCollected.On(function(data)
			-- No position in packet - just play a UI sound
			AudioService.PlaySound("SunCollect")

			Logger.Debug("VFXAudio", `PlantFood collected from zombie {data.ZombieEntityId}`)
		end))

		-- PlantFood Activated (on a plant)
		t:Add(Network.PlantFoodActivated.On(function(data)
			-- No position in packet - show VFX on the plant entity if we can find it
			AudioService.PlaySound("PlantFood")

			Logger.Debug("VFXAudio", `PlantFood activated on plant {data.PlantEntityId} ({data.PlantType})`)
		end))

		-- ========================================
		-- PROJECTILE & ZOMBIE VFX EVENTS
		-- ========================================

		-- Projectile enhanced by Torchwood (pea -> fire pea)
		t:Add(Network.ProjectileEnhanced.On(function(data)
			-- VFX will be handled by ProjectileRenderSystem which updates the visual
			-- Here we just play the ignition sound
			if data.EnhancementType == "fire" then
				AudioService.PlaySound("FireIgnite")
			end

			Logger.Debug("VFXAudio", `Projectile {data.EntityId} enhanced: {data.EnhancementType}`)
		end))

		-- Cob Cannon fired (corn cob launched)
		t:Add(Network.CobCannonFired.On(function(data)
			local targetPos = Vector3.new(data.TargetX, 0, data.TargetZ)

			-- Play launch sound (cannon fire)
			AudioService.PlaySound("Explosion") -- Reuse explosion for now, TODO: add CobCannonLaunch

			-- Schedule impact VFX after ImpactTime
			task.delay(data.ImpactTime, function()
				VFXService.PlayExplosion(targetPos, 9)
				AudioService.PlayExplosion(targetPos)
				VFXService.ScreenShake(1.0, 0.4)
				Logger.Debug("VFXAudio", `Cob Cannon impact at {targetPos}`)
			end)

			Logger.Debug("VFXAudio", `Cob Cannon fired to {targetPos}, impact in {data.ImpactTime}s`)
		end))

		-- PlantFood Charge Update (UI feedback)
		t:Add(Network.PlantFoodChargeUpdate.SetCallback(function(data)
			SelectionState.SetPlantFoodCharges(data.ChargeCount)
			Logger.Debug("VFXAudio", `PlantFood charge updated: {data.ChargeCount}`)
		end))

		Logger.Info("VFXAudioSystem", "Initialized VFX and Audio services")

		return t
	end, {})

	-- Note: trove is returned but auto-cleanup is handled by Hook lifetime
	_ = trove
end

--------------------------------------------------------------------------------
-- MODULE EXPORT
--------------------------------------------------------------------------------
return {
	priority = 350,
	system = VFXAudioSystem,
}
