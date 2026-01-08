# 🏗️ System Lifecycle Pipeline - Roadmap

## 📊 État Actuel (Janvier 2026)

### ✅ Nettoyage Terminé

| Tâche | Statut |
|-------|--------|
| Schéma Zap unifié (`shared/network/packets.zap`) | ✅ |
| Arena migré vers Shared.network.generated | ✅ |
| Lobby migré vers Shared.network.generated | ✅ |
| Suppression `arena/packets.zap` | ✅ |
| Suppression `lobby/server/network/`, `lobby/client/network/` | ✅ |
| Docs obsolètes nettoyées | ✅ |

### 📁 Architecture Réseau Unifiée

```
src/
├── shared/
│   └── network/
│       ├── packets.zap              # SOURCE UNIQUE Zap schema
│       └── generated/
│           ├── server.luau          # Généré par Zap
│           └── client.luau          # Généré par Zap
├── arena/
│   ├── client/                      # Utilise Shared.network.generated.client
│   └── server/                      # Utilise Shared.network.generated.server
└── lobby/
    ├── client/                      # Utilise Shared.network.generated.client
    └── server/                      # Utilise Shared.network.generated.server
```

**Commande pour régénérer :**
```bash
zap src/shared/network/packets.zap
```

---

## 🔴 Problème : Lifecycle des Systèmes Matter ECS

### Symptômes Identifiés

1. **Yield dans OnStep** → Erreur `System yielded! Its thread has been closed`
   - Cause : `WaitForChild()`, `GetConfig()` appelés dans la loop
   - Exemple : `GhostPreviewSystem` appelait `MapConfig.GetConfig()` chaque frame

2. **Pas de phase Init explicite** → Init lazy dans la loop
   - Risk : Race conditions, ordre d'init imprévisible

3. **Pas de Dispose** → Fuites mémoire, connections orphelines
   - Tracking tables (`_zombieAttackTimes`, `_enhancedProjectiles`) jamais nettoyées

4. **Dépendances implicites** → Couplage fort, difficile à tester

### Systèmes Affectés

#### Client (7 systèmes)
| Système | Init Pattern | Problème |
|---------|--------------|----------|
| GhostPreviewSystem | ⚠️ Lazy init + cache GridY | Fixed, mais pattern fragile |
| GridVisualizationSystem | `task.spawn(createGrid)` | OK mais init ordre aléatoire |
| PlantRenderSystem | Event-driven | OK |
| ProjectileRenderSystem | Event-driven | OK |
| SunRenderSystem | Event-driven | OK |
| ZombieRenderSystem | `MapConfig.IsInitialized()` check | OK defensive |
| VFXAudioSystem | `_initialized` flag | OK |

#### Server (25 systèmes)
| Catégorie | Systèmes | Problèmes |
|-----------|----------|-----------|
| Core | 4 | SafetySystem, FullStateSyncSystem OK |
| Combat | 7 | ⚠️ Tracking tables sans cleanup |
| Economy | 3 | ⚠️ `_productionTimers` sans cleanup |
| Units | 5 | ⚠️ `playerSun`, `playerCooldowns` cleanup partiel |
| Mutations | 8 | ⚠️ `_activeClouds` cleanup OK, autres tables non |
| Wave | 1 | ⚠️ State reset nécessaire par match |

---

## 🟢 Solution : SystemManager Pipeline

### Architecture Proposée

```
┌─────────────────────────────────────────────────────────────┐
│                      INIT PHASE                              │
│  (AVANT Matter.loop - Peut yield)                           │
├─────────────────────────────────────────────────────────────┤
│  1. SystemManager.RegisterAll(systems)                       │
│  2. SystemManager.InitializeAll()  ← Appelle system.Init()  │
│     - Peut WaitForChild, require, setup connections          │
│     - Ordre contrôlé par priorités                           │
│     - Timeout + error handling                               │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      RUNTIME PHASE                           │
│  (Matter.loop @ 60Hz - NE PEUT PAS yield)                   │
├─────────────────────────────────────────────────────────────┤
│  3. Matter.loop:scheduleSystems(systems)                     │
│  4. loop:begin()                                             │
│     - system.OnStep(world, dt)                               │
│     - Pure computation only                                   │
│     - Access pre-initialized state only                       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      DISPOSE PHASE                           │
│  (PlayerRemoving / GameOver)                                 │
├─────────────────────────────────────────────────────────────┤
│  5. SystemManager.DisposePlayer(player)                      │
│     - Nettoie tracking tables par player                     │
│  6. SystemManager.DisposeAll()                               │
│     - Déconnecte events, clear caches                        │
└─────────────────────────────────────────────────────────────┘
```

### Nouveau Pattern Système

```lua
--!strict
local MySystem = {}

-- Lifecycle exports
MySystem.priority = 150
MySystem.dependencies = {"MapConfig", "GridService"} -- Optional

-- Init: Called ONCE before Matter loop (can yield)
function MySystem.Init(world)
    -- Safe to WaitForChild, require, etc.
    local mapConfig = MapConfig.GetConfig() -- Blocking OK here
    _cachedGridY = mapConfig.GridY
    
    -- Setup network listeners
    Network.SomeEvent.On(function(data) ... end)
end

-- OnStep: Called every frame by Matter (CANNOT yield)
function MySystem.OnStep(world, dt)
    -- Use pre-initialized state only
    for entityId, component in world:query(Component) do
        -- Pure computation
    end
end

-- Dispose: Called on cleanup (player leave, game end)
function MySystem.Dispose(player: Player?)
    if player then
        -- Clean player-specific state
        _playerData[player] = nil
    else
        -- Full cleanup
        table.clear(_cache)
        _connection:Disconnect()
    end
end

-- API: External interface
MySystem.API = {
    DoSomething = function() ... end
}

return MySystem
```

---

## 📋 Plan de Migration

### Phase 1 : Infrastructure (1 jour)

#### 1.1 Créer SystemManager.luau
```
src/shared/utils/SystemManager.luau
```

**API :**
```lua
SystemManager.Register(system, name)
SystemManager.InitializeAll(world) -> Promise
SystemManager.DisposePlayer(player)
SystemManager.DisposeAll()
SystemManager.GetSystem(name)
```

#### 1.2 Modifier init scripts
- `arena/server/init.server.luau`
- `arena/client/init.client.luau`

**Pattern :**
```lua
-- Before Matter loop
SystemManager.InitializeAll(world):await()

-- Start Matter loop
loop:scheduleSystems(systems)
loop:begin()

-- On cleanup
Players.PlayerRemoving:Connect(function(player)
    SystemManager.DisposePlayer(player)
end)
```

### Phase 2 : Client Migration (1 jour)

| Système | Priorité Migration | Effort |
|---------|-------------------|--------|
| GhostPreviewSystem | 🔴 High | Medium |
| GridVisualizationSystem | 🟡 Medium | Low |
| PlantRenderSystem | 🟢 Low | Low |
| ProjectileRenderSystem | 🟢 Low | Low |
| SunRenderSystem | 🟢 Low | Low |
| ZombieRenderSystem | 🟡 Medium | Low |
| VFXAudioSystem | 🟢 Low | Low |

**Pattern de migration :**
1. Ajouter `Init()` - déplacer code d'init lazy
2. Ajouter `Dispose()` - déconnexion events
3. Vérifier OnStep - supprimer tout yield potentiel

### Phase 3 : Server Migration (2-3 jours)

#### 3.1 Combat Systems (Priority)
- `EnhancementSystem` - cleanup `_enhancedProjectiles`
- `ProjectileSystem` - cleanup `_plantFireTimes`
- `TrapSystem` - cleanup `_trapDamageTimes`
- `CombatSystem` - cleanup `_zombieAttackTimes`
- `SpecialPlantSystem` - cleanup `_fusePlants`, `_squashJumps`

#### 3.2 Economy Systems
- `SunflowerProductionSystem` - cleanup `_productionTimers`

#### 3.3 Units Systems
- `PlacementSystem` - cleanup `playerSun`, `playerCooldowns`
- `EntityDeathSystem` - cleanup session stats

#### 3.4 Wave System
- `WaveManagerSystem` - state reset per match

### Phase 4 : Testing & Validation (1 jour)

1. **Unit tests** pour SystemManager
2. **Integration test** : Game flow complet
3. **Memory profiling** : Vérifier pas de leaks
4. **Performance check** : Pas de regression FPS

---

## 🎯 Bénéfices Attendus

| Avant | Après |
|-------|-------|
| Race conditions d'init | Ordre d'init garanti |
| Fuites mémoire | Cleanup automatique |
| Yield crashes | Init phase séparée |
| Dépendances implicites | Graph explicite |
| Debug difficile | Logs structurés |

---

## 📊 Inventaire Code Mort

### À Supprimer

| Fichier | Variable | Raison |
|---------|----------|--------|
| `init.server.luau` (Arena) | `_GridPositionComponent`, `_HealthComponent` | Réservés, jamais utilisés |
| `GhostPreviewSystem.luau` | `_Players` | Réservé, jamais utilisé |
| `GhostPreviewSystem.luau` | `_getVFXService()` | Défini mais jamais appelé |
| `ZombieSpawnSystem.luau` | Tout le système | ENABLED = false, WaveManagerSystem le remplace |

### À Marquer Deprecated

| Module | Note |
|--------|------|
| `ZombieSpawnSystem.luau` | Garder pour API.SpawnZombie(), ajouter @deprecated |

---

## 🔮 Future Roadmap

### V2.0 - Dependency Injection
- Container IoC pour injecter dépendances
- Mock facile pour tests unitaires

### V2.1 - Hot Reload Systems
- Recharger systèmes sans restart
- Dev experience améliorée

### V2.2 - Metrics Dashboard
- Temps d'init par système
- Memory usage tracking
- Query performance

---

## 📚 Références

- [Matter ECS Documentation](https://matter-ecs.github.io/matter/)
- [Zap Networking](https://github.com/red-blox/zap)
- [Fusion Reactive State](https://elttob.uk/Fusion/)
