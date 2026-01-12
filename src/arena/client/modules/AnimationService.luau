--!strict
--[[
	AnimationService.luau - Client-side animations
	
	Supports TWO animation modes (auto-detected):
	
	1. TWEEN MODE (Plants - no Humanoid):
	   - Idle: Continuous bob/pulse loop
	   - Spawn: Scale up from zero
	   - Shoot: Recoil animation
	   - Death: Shrink and fade
	
	2. HUMANOID MODE (Zombies - with Humanoid):
	   - Walk: Looping walk cycle
	   - Attack: One-shot attack animation
	   - Death: Death animation
	   
	Model attributes (Tween mode):
	- Anim_IdleBobHeight (default 0.2)
	- Anim_IdleBobSpeed (default 1.5)
	- Anim_ShootRecoil (default 0.3)
	
	Expected zombie structure:
	- Model with HumanoidRootPart as PrimaryPart
	- Humanoid with Animator inside
	- Animations folder with Animation instances (Walk, Attack, Death)
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Track active idle animations for cleanup (Tween mode)
type IdleAnimation = {
	Model: Model,
	Tween: Tween,
	BasePosition: Vector3,
	Playing: boolean,
}
local _idleAnimations: { [Model]: IdleAnimation } = {}

-- Track active Humanoid animations for cleanup
type HumanoidAnimData = {
	Animator: Animator,
	WalkTrack: AnimationTrack?,
	AttackTrack: AnimationTrack?,
	DeathTrack: AnimationTrack?,
}
local _humanoidAnimations: { [Model]: HumanoidAnimData } = {}

-- Default animation values
local DEFAULTS = {
	IdleBobHeight = 0.2,
	IdleBobSpeed = 1.5,
	ShootRecoil = 0.3,
	SpawnDuration = 0.3,
	DeathDuration = 0.3,
}

local AnimationService = {}

--[[
	Check if model uses Humanoid (zombie) or Tween (plant) mode
]]
local function hasHumanoid(model: Model): boolean
	return model:FindFirstChildOfClass("Humanoid") ~= nil
end

--[[
	Get or create Animator from Humanoid
]]
local function getAnimator(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local newAnimator = Instance.new("Animator")
		newAnimator.Parent = humanoid
		return newAnimator
	end
	return animator
end

--[[
	Load animation tracks for a zombie model
]]
local function loadZombieAnimations(model: Model): HumanoidAnimData?
	local animator = getAnimator(model)
	if not animator then
		return nil
	end

	local animFolder = model:FindFirstChild("Animations")
	if not animFolder then
		Logger.Warn("Animation", `No Animations folder in {model.Name}`)
		return nil
	end

	local data: HumanoidAnimData = {
		Animator = animator,
		WalkTrack = nil,
		AttackTrack = nil,
		DeathTrack = nil,
	}

	-- Helper to check if Animation has valid ID
	local function isValidAnimation(anim: Animation?): boolean
		if not anim or not anim:IsA("Animation") then
			return false
		end
		local id = anim.AnimationId
		return id ~= nil and id ~= ""
	end

	-- Load each animation if it exists and has a valid ID
	local walkAnim = animFolder:FindFirstChild("Walk")
	if isValidAnimation(walkAnim) then
		local track = animator:LoadAnimation(walkAnim)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Movement
		data.WalkTrack = track
	end

	local attackAnim = animFolder:FindFirstChild("Attack")
	if isValidAnimation(attackAnim) then
		local track = animator:LoadAnimation(attackAnim)
		track.Looped = false
		track.Priority = Enum.AnimationPriority.Action
		data.AttackTrack = track
	end

	local deathAnim = animFolder:FindFirstChild("Death")
	if isValidAnimation(deathAnim) then
		local track = animator:LoadAnimation(deathAnim)
		track.Looped = false
		track.Priority = Enum.AnimationPriority.Action4
		data.DeathTrack = track
	end

	_humanoidAnimations[model] = data
	return data
end

--[[
	Get cached animation data or load new
]]
local function getZombieAnimData(model: Model): HumanoidAnimData?
	if _humanoidAnimations[model] then
		return _humanoidAnimations[model]
	end
	return loadZombieAnimations(model)
end

--[[
	Get animation parameter from model attribute or default
]]
local function getAnimParam(model: Model, param: string): number
	local attrName = "Anim_" .. param
	local value = model:GetAttribute(attrName)
	if value ~= nil and type(value) == "number" then
		return value
	end
	return DEFAULTS[param] or 0
end

--[[
	🌿 START IDLE - Works for both Plants (bob) and Zombies (walk)
	Call once when entity spawns, runs until StopIdle is called
]]
function AnimationService.StartIdle(model: Model)
	-- HUMANOID MODE: Play walk animation
	if hasHumanoid(model) then
		local animData = getZombieAnimData(model)
		if animData and animData.WalkTrack then
			animData.WalkTrack:Play()
			Logger.Debug("Animation", `Started walk animation on {model.Name}`)
		end
		return
	end

	-- TWEEN MODE: Bob animation for plants
	if _idleAnimations[model] then
		return -- Already playing
	end

	local root = model.PrimaryPart
	if not root then
		Logger.Warn("Animation", `Cannot start idle - no PrimaryPart on {model.Name}`)
		return
	end

	local bobHeight = getAnimParam(model, "IdleBobHeight")
	local bobSpeed = getAnimParam(model, "IdleBobSpeed")

	if bobHeight <= 0 then
		return -- No idle animation
	end

	local basePosition = root.Position
	local duration = 1 / bobSpeed

	local idleData: IdleAnimation = {
		Model = model,
		Tween = nil :: any,
		BasePosition = basePosition,
		Playing = true,
	}
	_idleAnimations[model] = idleData

	-- Coroutine for continuous bob
	task.spawn(function()
		local goingUp = true

		while idleData.Playing and model.Parent do
			local targetY = if goingUp then basePosition.Y + bobHeight else basePosition.Y

			local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

			local tween = TweenService:Create(root, tweenInfo, {
				Position = Vector3.new(basePosition.X, targetY, basePosition.Z),
			})

			idleData.Tween = tween
			tween:Play()
			tween.Completed:Wait()

			goingUp = not goingUp
		end

		-- Cleanup when stopped
		_idleAnimations[model] = nil
	end)

	Logger.Debug("Animation", `Started idle animation on {model.Name}`)
end

--[[
	Stop idle/walk animation
]]
function AnimationService.StopIdle(model: Model)
	-- HUMANOID MODE: Stop walk animation
	local animData = _humanoidAnimations[model]
	if animData and animData.WalkTrack then
		animData.WalkTrack:Stop()
	end

	-- TWEEN MODE: Stop bob animation
	local idleData = _idleAnimations[model]
	if idleData then
		idleData.Playing = false
		if idleData.Tween then
			idleData.Tween:Cancel()
		end
		_idleAnimations[model] = nil
	end
end

--[[
	🌱 SPAWN ANIMATION - Scale up from zero (Plants only)
	Zombies don't use spawn animation (they walk in)
]]
function AnimationService.PlaySpawn(model: Model): ()
	-- Skip for Humanoid models (zombies just walk in)
	if hasHumanoid(model) then
		return
	end

	local visual = model:FindFirstChild("Visual")
	if not visual or not visual:IsA("Model") then
		return
	end

	local duration = DEFAULTS.SpawnDuration

	-- Scale all parts from 0 to normal
	local parts: { BasePart } = {}
	local originalSizes: { Vector3 } = {}

	for _, part in visual:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
			table.insert(originalSizes, part.Size)
			part.Size = Vector3.new(0.1, 0.1, 0.1)
		end
	end

	-- Animate all parts
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local lastTween: Tween? = nil

	for i, part in parts do
		local tween = TweenService:Create(part, tweenInfo, {
			Size = originalSizes[i],
		})
		tween:Play()
		lastTween = tween
	end

	-- Wait for completion
	if lastTween then
		lastTween.Completed:Wait()
	end
end

--[[
	🔫 SHOOT ANIMATION - Recoil backwards then return
	Non-blocking (fire and forget)
]]
function AnimationService.PlayShoot(model: Model)
	local visual = model:FindFirstChild("Visual")
	local root = model.PrimaryPart
	if not visual or not root then
		return
	end

	local recoilDistance = getAnimParam(model, "ShootRecoil")
	if recoilDistance <= 0 then
		return
	end

	-- Check for custom Shoot pose
	local poses = model:FindFirstChild("Poses")
	local shootPose = poses and poses:FindFirstChild("Shoot")

	if shootPose and shootPose:IsA("Model") then
		-- Use custom pose (interpolate to it and back)
		AnimationService._playPoseAnimation(model, shootPose, 0.1, 0.1)
	else
		-- Generic recoil animation
		local basePosition = root.Position
		local recoilPosition = basePosition - Vector3.new(recoilDistance, 0, 0)

		-- Quick recoil back
		local recoilTween = TweenService:Create(
			root,
			TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = recoilPosition }
		)

		-- Return to base
		local returnTween = TweenService:Create(
			root,
			TweenInfo.new(0.15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{ Position = basePosition }
		)

		task.spawn(function()
			recoilTween:Play()
			recoilTween.Completed:Wait()
			returnTween:Play()
		end)
	end
end

--[[
	💀 DEATH ANIMATION - Works for both Plants and Zombies
]]
function AnimationService.PlayDeath(model: Model): ()
	-- Stop idle/walk first
	AnimationService.StopIdle(model)

	-- HUMANOID MODE: Play death animation
	if hasHumanoid(model) then
		local animData = _humanoidAnimations[model]
		if animData and animData.DeathTrack then
			animData.DeathTrack:Play()
			Logger.Debug("Animation", `Started death animation on {model.Name}`)
		end
		-- Cleanup animation data
		_humanoidAnimations[model] = nil
		return
	end

	-- TWEEN MODE: Shrink and fade for plants
	local visual = model:FindFirstChild("Visual")
	if not visual then
		return
	end

	local duration = DEFAULTS.DeathDuration
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.In)

	local lastTween: Tween? = nil

	for _, part in visual:GetDescendants() do
		if part:IsA("BasePart") then
			local tween = TweenService:Create(part, tweenInfo, {
				Size = Vector3.new(0.1, 0.1, 0.1),
				Transparency = 1,
			})
			tween:Play()
			lastTween = tween
		end
	end

	if lastTween then
		lastTween.Completed:Wait()
	end
end

--[[
	🧟 ATTACK ANIMATION - Zombies only
]]
function AnimationService.PlayAttack(model: Model)
	if not hasHumanoid(model) then
		return -- Plants don't attack
	end

	local animData = getZombieAnimData(model)
	if animData and animData.AttackTrack then
		animData.AttackTrack:Play()
	end
end

--[[
	🎭 CUSTOM POSE ANIMATION - Lerp to a pose and back
	Used for complex animations like Chomper eating
]]
function AnimationService._playPoseAnimation(model: Model, pose: Model, toPoseDuration: number, returnDuration: number)
	local visual = model:FindFirstChild("Visual")
	if not visual or not visual:IsA("Model") then
		return
	end

	-- Build part name -> pose CFrame/Size map
	local poseData: { [string]: { CFrame: CFrame, Size: Vector3 } } = {}
	for _, posePart in pose:GetDescendants() do
		if posePart:IsA("BasePart") then
			poseData[posePart.Name] = {
				CFrame = posePart.CFrame,
				Size = posePart.Size,
			}
		end
	end

	-- Store original state
	local originalState: { [BasePart]: { CFrame: CFrame, Size: Vector3 } } = {}
	for _, part in visual:GetDescendants() do
		if part:IsA("BasePart") then
			originalState[part] = {
				CFrame = part.CFrame,
				Size = part.Size,
			}
		end
	end

	task.spawn(function()
		-- Tween to pose
		local toPoseInfo = TweenInfo.new(toPoseDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for part, original in originalState do
			local poseTarget = poseData[part.Name]
			if poseTarget then
				local tween = TweenService:Create(part, toPoseInfo, {
					CFrame = poseTarget.CFrame,
					Size = poseTarget.Size,
				})
				tween:Play()
			end
		end
		task.wait(toPoseDuration)

		-- Return to original
		local returnInfo = TweenInfo.new(returnDuration, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
		for part, original in originalState do
			local tween = TweenService:Create(part, returnInfo, {
				CFrame = original.CFrame,
				Size = original.Size,
			})
			tween:Play()
		end
	end)
end

--[[
	Cleanup all animations (call on game end)
]]
function AnimationService.Cleanup()
	-- Cleanup tween animations (plants)
	for model, _ in _idleAnimations do
		AnimationService.StopIdle(model)
	end

	-- Cleanup humanoid animations (zombies)
	for model, animData in _humanoidAnimations do
		if animData.WalkTrack then
			animData.WalkTrack:Stop()
		end
		if animData.AttackTrack then
			animData.AttackTrack:Stop()
		end
		if animData.DeathTrack then
			animData.DeathTrack:Stop()
		end
	end
	table.clear(_humanoidAnimations)

	Logger.Info("Animation", "AnimationService cleaned up")
end

return AnimationService
