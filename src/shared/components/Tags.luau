--!strict
--[[
	Tag Components - Lightweight entity type markers
	
	Tags are components with no data, used for entity classification.
	Systems query by tag to process specific entity types.
	
	Uses Matter.component() to create valid ECS components.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

-- Plant tag - marks entity as a plant
local PlantTag = Matter.component("PlantTag")

-- Zombie tag - marks entity as a zombie
local ZombieTag = Matter.component("ZombieTag")

-- Projectile tag - marks entity as a projectile
local ProjectileTag = Matter.component("ProjectileTag")

-- Resource tag - marks entity as a resource (sun drop)
local ResourceTag = Matter.component("ResourceTag")

-- Inactive tag - marks entity as pooled/inactive
local InactiveTag = Matter.component("InactiveTag")

-- Replicated tag - marks entity for network replication
local ReplicatedTag = Matter.component("ReplicatedTag")

return {
	PlantTag = PlantTag,
	ZombieTag = ZombieTag,
	ProjectileTag = ProjectileTag,
	ResourceTag = ResourceTag,
	InactiveTag = InactiveTag,
	ReplicatedTag = ReplicatedTag,
}
