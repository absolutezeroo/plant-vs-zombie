--!nonstrict
--[[
    ServiceLoader.luau - Orchestrates service/controller initialization with loading UI
    
    Provides a structured way to load services with progress tracking.
    Works with LoaderUI to show loading progress to players.
    
    Note: Uses --!nonstrict due to complex Fusion type inference with LoaderUI.
    
    Usage:
        local ServiceLoader = require(Shared.utils.ServiceLoader)
        local loader = ServiceLoader.new()
        
        loader:AddStep("Network", function()
            -- Initialize network
        end)
        
        loader:AddStep("Controllers", function()
            -- Initialize controllers
        end)
        
        loader:Run(function()
            -- All steps complete
        end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Sift = require(Packages.Sift)
local Promise = require(Packages.Promise)
local LoaderUI = require(Shared.ui.LoaderUI)
local Logger = require(Shared.utils.Logger)

local ServiceLoader = {}
ServiceLoader.__index = ServiceLoader

function ServiceLoader.new(config)
    local self = setmetatable({}, ServiceLoader)
    
    config = config or {}
    
    self._steps = {}
    self._stages = config.stages or {}
    self._title = config.title
    self._subtitle = config.subtitle
    self._loaderUI = nil
    self._isRunning = false
    
    return self
end

-- Add a loading step
function ServiceLoader:AddStep(name, action, weight)
    self._steps = Sift.Array.push(self._steps, {
        name = name,
        weight = weight or 1,
        action = action,
    })
end

-- Run all loading steps
function ServiceLoader:Run(onComplete)
    if self._isRunning then
        Logger.Warn("ServiceLoader", "Already running!")
        return
    end
    
    self._isRunning = true
    
    -- Calculate total weight
    local totalWeight = 0
    for _, step in self._steps do
        totalWeight = totalWeight + step.weight
    end
    
    -- Build stages for LoaderUI from predefined stages or from steps
    local loaderStages = {}
    
    if #self._stages > 0 then
        -- Use predefined stages with tips (convert to LoaderUI format)
        for i, stage in self._stages do
            local stepWeight = self._steps[i] and self._steps[i].weight or 1
            loaderStages = Sift.Array.push(loaderStages, {
                Name = stage.name,
                Weight = stepWeight / math.max(totalWeight, 1),
            })
        end
    else
        -- Build from steps
        for _, step in self._steps do
            loaderStages = Sift.Array.push(loaderStages, {
                Name = step.name,
                Weight = step.weight / math.max(totalWeight, 1),
            })
        end
    end
    
    -- Create LoaderUI
    self._loaderUI = LoaderUI.new({
        stages = loaderStages,
        title = self._title,
        subtitle = self._subtitle,
    })
    
    -- Execute steps
    task.spawn(function()
        for i, step in self._steps do
            self._loaderUI:SetStage(i, step.name .. "...")
            
            Logger.Info("ServiceLoader", `[{i}/{#self._steps}] {step.name}`)
            
            -- Execute step action with Promise.try for clean error handling
            Promise.try(step.action):andThen(function()
                self._loaderUI:SetProgress(1)
                Logger.Info("ServiceLoader", `{step.name} complete`)
            end):catch(function(err)
                Logger.Error("ServiceLoader", `{step.name} failed: {err}`)
                -- Continue anyway to not block the game
            end):await() -- Wait for step to complete before next
            
            -- Small delay between steps for visual smoothness
            task.wait(0.05)
        end
        
        -- Complete loading
        self._loaderUI:Complete(function()
            self._isRunning = false
            Logger.Info("ServiceLoader", "All loading complete")
            
            if onComplete then
                onComplete()
            end
        end)
    end)
end

-- Get the LoaderUI instance (for custom progress updates)
function ServiceLoader:GetLoaderUI()
    return self._loaderUI
end

-- Update progress within current step (0-1)
function ServiceLoader:SetProgress(progress)
    if self._loaderUI then
        self._loaderUI:SetProgress(progress)
    end
end

-- Update status text
function ServiceLoader:SetStatus(text)
    if self._loaderUI then
        self._loaderUI:SetStatus(text)
    end
end

return ServiceLoader
