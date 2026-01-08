--!strict
-- Proxy module: re-exports shared network generated code
-- This allows existing code to continue using `require(Client.network.generated)`
-- while the actual generated code lives in shared/network/generated/

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

return require(Shared.network.generated.client)
