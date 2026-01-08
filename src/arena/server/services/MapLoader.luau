--!strict
--[[
    MapLoader.luau - Dynamic map loading service
    
    Loads map models from ReplicatedStorage.Maps based on world configuration.
    Handles map cleanup, grid reconfiguration, and spawn point setup.
    
    Expected structure in ReplicatedStorage:
    
    📁 Maps/
    ├── 📁 World1_Day/
    │   ├── 🧱 ArenaMap (Folder/Model) - Grid config (GridBounds, ZombieSpawns, BasePosition)
    │   └── 📁 World (Folder/Model) - Visual elements (terrain, decorations, house)
    ├── 📁 World2_Night/
    │   ├── 🧱 ArenaMap
    │   └── 📁 World
    └── 📁 World3_Pool/
        ├── 🧱 ArenaMap
        └── 📁 World
    
    ArenaMap contains:
    - GridBounds (Part with CornerA/CornerB Attachments)
    - ZombieSpawns (Folder with Lane1-Lane5)
    - BasePosition (Part or Attachment)
    
    World contains:
    - Visual elements (lawn, house, decorations, etc.)
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Network (from shared module)
local _network: any = nil
local function getNetwork()
    if not _network then
        _network = require(Shared.network.generated.server)
    end
    return _network
end

-- State
local _currentMapId: string? = nil
local _currentMapModel: Model? = nil
local _currentWorldModel: (Model | Folder)? = nil  -- Visual world elements
local _mapsFolder: Folder? = nil

local MapLoader = {}

--[[
    Initialize the MapLoader
]]
function MapLoader.Initialize()
    -- Find or create Maps folder
    _mapsFolder = ReplicatedStorage:FindFirstChild("Maps") :: Folder?
    
    if not _mapsFolder then
        Logger.Warn("MapLoader", "Maps folder not found in ReplicatedStorage, creating empty folder")
        local newFolder = Instance.new("Folder")
        newFolder.Name = "Maps"
        newFolder.Parent = ReplicatedStorage
        _mapsFolder = newFolder
    end
    
    Logger.Info("MapLoader", "Initialized")
end

--[[
    Get the currently loaded map ID
    @return MapId or nil
]]
function MapLoader.GetCurrentMapId(): string?
    return _currentMapId
end

--[[
    Get the currently loaded map model
    @return Model or nil
]]
function MapLoader.GetCurrentMap(): Model?
    return _currentMapModel
end

--[[
    Load a map by ID
    @param mapId - Map identifier (e.g., "World1_Day")
    @return boolean success
]]
function MapLoader.LoadMap(mapId: string): boolean
    if not _mapsFolder then
        MapLoader.Initialize()
    end
    
    -- Safety check after init
    if not _mapsFolder then
        Logger.Error("MapLoader", "Failed to initialize maps folder")
        return false
    end
    
    -- Already loaded?
    if _currentMapId == mapId and _currentMapModel then
        Logger.Info("MapLoader", `Map {mapId} already loaded`)
        return true
    end
    
    -- Unload current map first
    if _currentMapModel then
        MapLoader.UnloadMap()
    end
    
    -- Find the map folder
    local mapFolder = _mapsFolder:FindFirstChild(mapId)
    if not mapFolder then
        Logger.Error("MapLoader", `Map folder not found: {mapId}`)
        return false
    end
    
    -- Find ArenaMap model
    local arenaMapTemplate = mapFolder:FindFirstChild("ArenaMap")
    if not arenaMapTemplate then
        Logger.Error("MapLoader", `ArenaMap model not found in {mapId}`)
        return false
    end
    
    -- Clone and parent to Workspace
    Logger.Info("MapLoader", `Loading map: {mapId}`)
    
    local mapClone = arenaMapTemplate:Clone()
    mapClone.Name = "ArenaMap"
    mapClone.Parent = Workspace
    
    _currentMapId = mapId
    _currentMapModel = mapClone :: Model  -- Can be Model or Folder, both work
    
    -- Also load the World folder (visual elements) if it exists
    local worldTemplate = mapFolder:FindFirstChild("World")
    if worldTemplate then
        Logger.Info("MapLoader", `Loading world visuals for {mapId}`)
        
        -- Remove existing World if any
        local existingWorld = Workspace:FindFirstChild("World")
        if existingWorld then
            existingWorld:Destroy()
        end
        
        local worldClone = worldTemplate:Clone()
        worldClone.Name = "World"
        worldClone.Parent = Workspace
        _currentWorldModel = worldClone
        
        Logger.Info("MapLoader", `World visuals loaded: {#worldClone:GetChildren()} objects`)
    else
        Logger.Warn("MapLoader", `No World folder found in {mapId} - using ArenaMap only`)
    end
    
    -- Load SpawnLocation if it exists (for player spawn point)
    local spawnTemplate = mapFolder:FindFirstChild("SpawnLocation")
    if spawnTemplate and spawnTemplate:IsA("SpawnLocation") then
        Logger.Info("MapLoader", `Loading SpawnLocation for {mapId}`)
        
        -- Remove existing SpawnLocation if any
        local existingSpawn = Workspace:FindFirstChildOfClass("SpawnLocation")
        if existingSpawn then
            existingSpawn:Destroy()
        end
        
        local spawnClone = spawnTemplate:Clone()
        spawnClone.Parent = Workspace
        
        Logger.Info("MapLoader", `SpawnLocation loaded at {spawnClone.Position}`)
    else
        Logger.Warn("MapLoader", `No SpawnLocation found in {mapId}`)
    end
    
    -- Notify MapConfig to reload from the new map
    local MapConfig = require(Shared.config.MapConfig)
    MapConfig.LoadFromMap(mapClone)
    
    -- Send map config to all clients (authoritative sync)
    MapLoader._SyncConfigToClients(mapId)
    
    Logger.Info("MapLoader", `Map loaded: {mapId}`)
    return true
end

--[[
    Sync map configuration to all connected clients
    This ensures clients have correct data without race conditions
]]
function MapLoader._SyncConfigToClients(mapId: string)
    local network = getNetwork()
    if not network then
        Logger.Warn("MapLoader", "Network not available, cannot sync config to clients")
        return
    end
    
    local MapConfig = require(Shared.config.MapConfig)
    local syncData = MapConfig.GetServerSyncData(mapId)
    
    -- Send to all players (Zap uses Fire(Player, Data))
    for _, player in Players:GetPlayers() do
        network.MapConfigSync.Fire(player, syncData)
    end
    
    Logger.Info("MapLoader", `Synced map config to {#Players:GetPlayers()} clients`)
    
    -- Also resync after a short delay to catch clients still initializing
    task.delay(1, function()
        for _, player in Players:GetPlayers() do
            network.MapConfigSync.Fire(player, syncData)
        end
        Logger.Debug("MapLoader", "Resent map config after delay")
    end)
end

--[[
    Sync map configuration to a specific player (for late joiners)
]]
function MapLoader.SyncConfigToPlayer(player: Player)
    if not _currentMapId then
        return
    end
    
    local network = getNetwork()
    if not network then
        return
    end
    
    local MapConfig = require(Shared.config.MapConfig)
    local syncData = MapConfig.GetServerSyncData(_currentMapId)
    network.MapConfigSync.Fire(player, syncData)
    
    Logger.Info("MapLoader", `Synced map config to late joiner: {player.Name}`)
end

--[[
    Unload the current map (ArenaMap + World)
]]
function MapLoader.UnloadMap()
    if _currentMapModel then
        Logger.Info("MapLoader", `Unloading map: {_currentMapId}`)
        _currentMapModel:Destroy()
        _currentMapModel = nil
    end
    
    if _currentWorldModel then
        Logger.Info("MapLoader", "Unloading world visuals")
        _currentWorldModel:Destroy()
        _currentWorldModel = nil
    end
    
    _currentMapId = nil
end

--[[
    Check if a map exists
    @param mapId - Map identifier
    @return boolean
]]
function MapLoader.MapExists(mapId: string): boolean
    if not _mapsFolder then
        MapLoader.Initialize()
    end
    
    if not _mapsFolder then
        return false
    end
    
    local mapFolder = _mapsFolder:FindFirstChild(mapId)
    if not mapFolder then
        return false
    end
    
    return mapFolder:FindFirstChild("ArenaMap") ~= nil
end

--[[
    Get list of available maps
    @return Array of map IDs
]]
function MapLoader.GetAvailableMaps(): {string}
    if not _mapsFolder then
        MapLoader.Initialize()
    end
    
    local maps: {string} = {}
    
    if not _mapsFolder then
        return maps
    end
    
    for _, child in _mapsFolder:GetChildren() do
        if child:IsA("Folder") and child:FindFirstChild("ArenaMap") then
            table.insert(maps, child.Name)
        end
    end
    
    return maps
end

--[[
    Collect all assets that need preloading from a folder
    @param folder - Folder/Model to scan
    @return Array of instances to preload
]]
local function collectPreloadAssets(folder: Instance): {Instance}
    local assets: {Instance} = {}
    
    for _, descendant in folder:GetDescendants() do
        -- Collect meshes, textures, sounds, etc.
        if descendant:IsA("MeshPart") or
           descendant:IsA("SpecialMesh") or
           descendant:IsA("Decal") or
           descendant:IsA("Texture") or
           descendant:IsA("Sound") or
           descendant:IsA("ImageLabel") or
           descendant:IsA("ImageButton") then
            table.insert(assets, descendant)
        end
    end
    
    return assets
end

--[[
    Preload map assets before loading into Workspace
    This prevents visual pop-in when the map loads
    
    @param mapId - Map identifier
    @param player - Optional player to send progress events to (nil = all players)
    @return boolean success, number assetsLoaded
]]
function MapLoader.PreloadMapAssets(mapId: string, player: Player?): (boolean, number)
    if not _mapsFolder then
        MapLoader.Initialize()
    end
    
    if not _mapsFolder then
        Logger.Error("MapLoader", "Failed to initialize maps folder")
        return false, 0
    end
    
    local mapFolder = _mapsFolder:FindFirstChild(mapId)
    if not mapFolder then
        Logger.Error("MapLoader", `Map folder not found for preload: {mapId}`)
        return false, 0
    end
    
    -- Collect all assets to preload
    local assets = collectPreloadAssets(mapFolder)
    local totalAssets = #assets
    
    if totalAssets == 0 then
        Logger.Info("MapLoader", `No assets to preload for {mapId}`)
        return true, 0
    end
    
    Logger.Info("MapLoader", `Preloading {totalAssets} assets for {mapId}`)
    
    -- Send loading started event
    local network = getNetwork()
    if network and network.MapLoadingStarted then
        local targets = player and {player} or Players:GetPlayers()
        for _, p in targets do
            network.MapLoadingStarted.Fire(p, {
                MapId = mapId,
                TotalAssets = totalAssets,
            })
        end
    end
    
    -- Preload with progress tracking
    local loadedCount = 0
    local lastProgressUpdate = 0
    
    ContentProvider:PreloadAsync(assets, function(assetId: string, status: Enum.AssetFetchStatus)
        loadedCount += 1
        
        -- Throttle progress updates (every 5% or every 10 assets)
        local progressPercent = loadedCount / totalAssets
        if progressPercent - lastProgressUpdate >= 0.05 or loadedCount % 10 == 0 then
            lastProgressUpdate = progressPercent
            
            if network and network.MapLoadingProgress then
                local assetName = string.match(assetId, "([^/]+)$") or assetId
                local targets = player and {player} or Players:GetPlayers()
                for _, p in targets do
                    network.MapLoadingProgress.Fire(p, {
                        LoadedAssets = loadedCount,
                        TotalAssets = totalAssets,
                        AssetName = string.sub(assetName, 1, 50), -- Limit length
                    })
                end
            end
        end
        
        if status ~= Enum.AssetFetchStatus.Success then
            Logger.Warn("MapLoader", `Failed to preload asset: {assetId} ({status.Name})`)
        end
    end)
    
    Logger.Info("MapLoader", `Preloaded {loadedCount}/{totalAssets} assets for {mapId}`)
    
    -- Send loading complete event
    if network and network.MapLoadingComplete then
        local targets = player and {player} or Players:GetPlayers()
        for _, p in targets do
            network.MapLoadingComplete.Fire(p, {
                MapId = mapId,
                Success = true,
            })
        end
    end
    
    return true, loadedCount
end

--[[
    Load a map with preloading (recommended for player-facing loads)
    Combines PreloadMapAssets + LoadMap for seamless experience
    
    @param mapId - Map identifier
    @param player - Optional player to send progress events to
    @return boolean success
]]
function MapLoader.LoadMapWithPreload(mapId: string, player: Player?): boolean
    -- Preload assets first
    local preloadSuccess, assetsLoaded = MapLoader.PreloadMapAssets(mapId, player)
    if not preloadSuccess then
        Logger.Warn("MapLoader", `Preload failed for {mapId}, attempting load anyway`)
    else
        Logger.Info("MapLoader", `Preloaded {assetsLoaded} assets, now loading map`)
    end
    
    -- Load the map
    return MapLoader.LoadMap(mapId)
end

return MapLoader
