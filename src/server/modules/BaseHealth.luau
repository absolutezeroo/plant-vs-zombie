--!strict
--[[
	BaseHealth.luau - Server module for tracking base/lawn health
	
	The player's house has HP that decreases when zombies reach it.
	When HP reaches 0, the game is over (defeat).
	
	This is a module (not a system) so multiple systems can access it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Network
local Server = script.Parent.Parent
local Network = require(Server.network.generated)

-- Configuration
local Config = {
	MAX_HEALTH = 1000,
	ZOMBIE_DAMAGE = 100,  -- Damage per zombie that reaches house
}

-- State
local _currentHealth = Config.MAX_HEALTH
local _isDefeated = false

local BaseHealth = {}

function BaseHealth.GetHealth(): number
	return _currentHealth
end

function BaseHealth.GetMaxHealth(): number
	return Config.MAX_HEALTH
end

function BaseHealth.IsDefeated(): boolean
	return _isDefeated
end

function BaseHealth.TakeDamage(amount: number)
	if _isDefeated then
		return
	end
	
	local oldHealth = _currentHealth
	_currentHealth = math.max(0, _currentHealth - amount)
	
	Logger.Warn("BaseHealth", `Base took {amount} damage! ({oldHealth} -> {_currentHealth}/{Config.MAX_HEALTH})`)
	
	-- Broadcast to clients
	Network.BaseHealthUpdated.FireAll({
		CurrentHealth = _currentHealth,
		MaxHealth = Config.MAX_HEALTH,
		DamageAmount = amount,
	})
	
	-- Check for defeat
	if _currentHealth <= 0 and not _isDefeated then
		_isDefeated = true
		Logger.Error("BaseHealth", "💀 BASE DESTROYED - DEFEAT!")
		
		-- Broadcast game over
		Network.GameOver.FireAll({
			Victory = false,
			WaveReached = 0, -- Will be set by WaveManager
		})
	end
end

function BaseHealth.OnZombieReachedHouse()
	BaseHealth.TakeDamage(Config.ZOMBIE_DAMAGE)
end

function BaseHealth.Reset()
	_currentHealth = Config.MAX_HEALTH
	_isDefeated = false
	
	Logger.Info("BaseHealth", `Base health reset to {Config.MAX_HEALTH}`)
	
	-- Broadcast initial state
	Network.BaseHealthUpdated.FireAll({
		CurrentHealth = _currentHealth,
		MaxHealth = Config.MAX_HEALTH,
		DamageAmount = 0,
	})
end

return BaseHealth
