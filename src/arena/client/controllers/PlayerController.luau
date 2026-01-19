--!strict
--[[
	PlayerController.luau - Player character setup for Arena
	
	Handles player-specific settings in the arena:
	- Disables jumping (tower defense gameplay)
	- Disables collisions between players
	- Future: Camera constraints, movement limits, etc.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local PlayerController = {}

local _initialized = false
local _trove: any = nil
local PLAYER_COLLISION_GROUP = "Players"

--[[
	Set all parts in a model to a collision group
]]
local function setCollisionGroup(model: Model, groupName: string)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end
	-- Also handle parts added later (accessories, etc.) - cleaned up via Trove
	_trove:Connect(model.DescendantAdded, function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end)
end

--[[
	Disable jumping for a character and set collision group
]]
local function setupCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Disable jumping completely
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0

		Logger.Debug("PlayerController", "Jump disabled for character")
	end

	-- Set collision group so players don't collide with each other
	setCollisionGroup(character, PLAYER_COLLISION_GROUP)
	Logger.Debug("PlayerController", "Collision group set for character")
end

--[[
	Initialize the controller
]]
function PlayerController.Init()
	if _initialized then
		return
	end
	_initialized = true
	_trove = Trove.new()

	local player = Players.LocalPlayer

	-- Setup current character if exists
	if player.Character then
		setupCharacter(player.Character)
	end

	-- Setup future characters (respawn) - cleaned up via Trove
	_trove:Connect(player.CharacterAdded, setupCharacter)

	Logger.Info("PlayerController", "Initialized - Jump disabled in Arena")
end

--[[
	Cleanup controller resources
]]
function PlayerController.Dispose()
	if _trove then
		_trove:Destroy()
		_trove = nil
	end
	_initialized = false
	Logger.Debug("PlayerController", "Disposed")
end

return PlayerController
