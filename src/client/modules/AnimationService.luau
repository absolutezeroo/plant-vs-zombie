--!strict
--[[
	AnimationService.luau - Client-side TweenService-based animations
	
	Handles plant animations WITHOUT Humanoid:
	- Idle: Continuous bob/pulse loop
	- Spawn: Scale up from zero
	- Shoot: Recoil animation
	- Death: Shrink and fade
	
	Reads animation parameters from model attributes:
	- Anim_IdleBobHeight (default 0.2)
	- Anim_IdleBobSpeed (default 1.5)
	- Anim_ShootRecoil (default 0.3)
	
	Supports custom Poses folder for complex animations.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Track active idle animations for cleanup
type IdleAnimation = {
	Model: Model,
	Tween: Tween,
	BasePosition: Vector3,
	Playing: boolean,
}
local _idleAnimations: {[Model]: IdleAnimation} = {}

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
	🌿 IDLE ANIMATION - Continuous bob loop
	Call once when plant spawns, runs until StopIdle is called
]]
function AnimationService.StartIdle(model: Model)
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
			local targetY = if goingUp 
				then basePosition.Y + bobHeight 
				else basePosition.Y
			
			local tweenInfo = TweenInfo.new(
				duration,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut
			)
			
			local tween = TweenService:Create(root, tweenInfo, {
				Position = Vector3.new(basePosition.X, targetY, basePosition.Z)
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
	Stop idle animation
]]
function AnimationService.StopIdle(model: Model)
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
	🌱 SPAWN ANIMATION - Scale up from zero
	Returns when animation completes
]]
function AnimationService.PlaySpawn(model: Model): ()
	local visual = model:FindFirstChild("Visual")
	if not visual or not visual:IsA("Model") then
		return
	end
	
	local duration = DEFAULTS.SpawnDuration
	
	-- Scale all parts from 0 to normal
	local parts: {BasePart} = {}
	local originalSizes: {Vector3} = {}
	
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
			Size = originalSizes[i]
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
		local recoilTween = TweenService:Create(root, 
			TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = recoilPosition }
		)
		
		-- Return to base
		local returnTween = TweenService:Create(root,
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
	💀 DEATH ANIMATION - Shrink and fade
	Returns when animation completes
]]
function AnimationService.PlayDeath(model: Model): ()
	-- Stop idle first
	AnimationService.StopIdle(model)
	
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
				Transparency = 1
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
	🎭 CUSTOM POSE ANIMATION - Lerp to a pose and back
	Used for complex animations like Chomper eating
]]
function AnimationService._playPoseAnimation(model: Model, pose: Model, toPoseDuration: number, returnDuration: number)
	local visual = model:FindFirstChild("Visual")
	if not visual or not visual:IsA("Model") then
		return
	end
	
	-- Build part name -> pose CFrame/Size map
	local poseData: {[string]: {CFrame: CFrame, Size: Vector3}} = {}
	for _, posePart in pose:GetDescendants() do
		if posePart:IsA("BasePart") then
			poseData[posePart.Name] = {
				CFrame = posePart.CFrame,
				Size = posePart.Size,
			}
		end
	end
	
	-- Store original state
	local originalState: {[BasePart]: {CFrame: CFrame, Size: Vector3}} = {}
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
	for model, _ in _idleAnimations do
		AnimationService.StopIdle(model)
	end
	Logger.Info("Animation", "AnimationService cleaned up")
end

return AnimationService
