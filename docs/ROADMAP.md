# 🌻 ROADMAP - Garden Swarm - État d'Implémentation

> **Dernière mise à jour automatisée:** 18 Janvier 2026  
> Basé sur l'analyse complète du codebase (`PlantData.luau`, Systems ECS, Services, UI)

---

## 🎯 ÉTAT GLOBAL DU PROJET

### Vue d'Ensemble

| Métrique | Valeur | Status |
|----------|--------|--------|
| **Phase Actuelle** | Phase 3 (Epic 6 - Polish) | 🟢 En cours |
| **Architecture ECS** | Matter V2 Pattern | ✅ Complète |
| **Systèmes Serveur Arena** | 27/27 | ✅ 100% |
| **Systèmes Client Arena** | 7/7 | ✅ 100% |
| **Services Arena** | 10/10 | ✅ 100% |
| **Lobby Serveur** | 11/11 | ✅ 100% |
| **Lobby Client** | 6/6 | ✅ 100% |
| **Composants ECS** | 45 fichiers | ✅ 100% |
| **Modules Partagés** | 92 fichiers | ✅ 99% |

---

## 📊 INVENTAIRE COMPLET DES PLANTES (PlantData.luau)

### 🎯 1. SHOOTERS STANDARD (9 plantes)

| Plante          | Coût ☀️ | Dégâts  | Mécanique                       | État             | Notes                                         |
|-----------------|---------|---------|---------------------------------|------------------|-----------------------------------------------|
| **Peashooter**  | 100     | 20      | `CanShoot`                      | ✅ MVP            | Référence de base                             |
| **Repeater**    | 200     | 20×2    | `IsRepeater`, `ShotsPerBurst=2` | ✅ MVP            | Multi-shot implémenté                         |
| **SnowPea**     | 175     | 20+slow | `IsFrozen`, `SlowPercent=0.5`   | ✅ MVP            | SlowComponent fonctionne                      |
| **Threepeater** | 325     | 20×3    | `IsThreeLane`                   | ✅ Implémenté     | `fireThreeLanes()` dans ProjectileSpawnSystem |
| **SplitPea**    | 125     | 20      | `ShootsBehind`                  | ✅ Implémenté     | Tire avant/arrière                            |
| **GatlingPea**  | 250     | 20×4    | `ShotsPerBurst=4`               | ✅ Implémenté     | Variante Repeater                             |
| **Starfruit**   | 125     | 20×5    | `ShootsMultiDirection`          | ✅ Implémenté     | `fireMultiDirection()` 5 directions           |
| **Cactus**      | 125     | 20      | `CanHitFlying`                  | ⚠️ Partiel       | Flag existe, flying zombies?                  |
| **Cattail**     | 225     | 20      | `IsHoming`, `RequiresLilyPad`   | ❌ Non implémenté | Système homing manquant                       |

### 🎃 2. CATAPULTES / LOBBERS (5 plantes)

| Plante          | Coût ☀️ | Dégâts  | Mécanique                                | État             | Notes                          |
|-----------------|---------|---------|------------------------------------------|------------------|--------------------------------|
| **CabbagePult** | 100     | 40      | `IsCatapult`                             | ✅ Implémenté     | Projectiles en arc             |
| **KernelPult**  | 100     | 20      | `CanStun`, `StunChance=0.2`              | ✅ Implémenté     | StunComponent + Butter variant |
| **MelonPult**   | 300     | 80      | `HasSplash`, `SplashRadius=3`            | ✅ Implémenté     | SplashComponent ajouté         |
| **WinterMelon** | 500     | 80+slow | `IsFrozen` + `HasSplash`                 | ✅ Implémenté     | Combo splash+freeze            |
| **CobCannon**   | 500     | 1800    | `IsManualFire`, `RequiresTwoKernelPults` | ❌ Non implémenté | UI click-to-fire manquant      |

### 💣 3. EXPLOSIVES / INSTANT-KILL (7 plantes)

| Plante         | Coût ☀️ | Dégâts | Mécanique                         | État         | Notes                                  |
|----------------|---------|--------|-----------------------------------|--------------|----------------------------------------|
| **CherryBomb** | 150     | 1800   | `ExplodesOnPlace`, `FuseTime=0.5` | ✅ MVP        | SpecialPlantSystem                     |
| **PotatoMine** | 25      | 1800   | `NeedsArming`, `ArmDuration=20`   | ✅ MVP        | ArmedComponent fonctionne              |
| **Jalapeno**   | 125     | 1800   | `IsLaneWide`                      | ✅ Implémenté | Brûle toute la lane                    |
| **DoomShroom** | 125     | 1800   | `LeavesCrater`                    | ✅ Implémenté | Explosion + cratère bloque placement   |
| **IceShroom**  | 75      | 20     | `FreezesAll`, `FreezeDuration=4`  | ✅ Implémenté | Gèle tous les zombies                  |
| **Squash**     | 50      | 1800   | `JumpsToTarget`                   | ✅ Implémenté | Animation saut dans SpecialPlantSystem |
| **TangleKelp** | 25      | 1800   | `IsInstantKill`, `RequiresWater`  | ⚠️ Partiel   | Logique OK, placement eau à valider    |

### 😋 4. INSTANT-KILL SPÉCIAUX (1 plante)

| Plante      | Coût ☀️ | Dégâts | Mécanique                          | État         | Notes                          |
|-------------|---------|--------|------------------------------------|--------------|--------------------------------|
| **Chomper** | 150     | 1800   | `IsInstantKill`, `ChewDuration=42` | ✅ Implémenté | ChewingComponent bloque le tir |

### 🛡️ 5. DÉFENSIVES (5 plantes)

| Plante          | Coût ☀️ | HP  | Mécanique                    | État             | Notes                                   |
|-----------------|---------|-----|------------------------------|------------------|-----------------------------------------|
| **WallNut**     | 50      | 400 | Défense de base              | ✅ MVP            | Bloqueur simple                         |
| **TallNut**     | 125     | 800 | `BlocksJumpers`              | ✅ Implémenté     | Pole Vaulter ne peut pas sauter         |
| **Pumpkin**     | 125     | 400 | `IsShell`, `CanStackOnPlant` | ✅ Implémenté    | ShellComponent + damage routing         |
| **Garlic**      | 50      | 200 | `DivertsZombies`             | ✅ Implémenté    | TrapSystem complet (lane switch)        |
| **ExplodeONut** | 50      | 400 | `ExplodesOnDeath`            | ⚠️ Partiel       | Logique dans SpecialPlantSystem         |

### 🌻 6. PRODUCTEURS (4 plantes)

| Plante            | Coût ☀️ | Production | Mécanique                   | État             | Notes                         |
|-------------------|---------|------------|-----------------------------|------------------|-------------------------------|
| **Sunflower**     | 50      | 25☀️/30s   | `ProducesSun`, `SunCount=1` | ✅ MVP            | SunflowerProductionSystem     |
| **TwinSunflower** | 150     | 50☀️/24s   | `SunCount=2`                | ✅ Implémenté     | Double production             |
| **SunShroom**     | 25      | 15→25☀️    | `GrowthTime=120`            | ⚠️ Partiel       | Croissance à implémenter      |
| **Marigold**    | 50      | Coins      | `ProducesCoins`             | ✅ Implémenté    | CoinProductionSystem ajouté   |

### 🍄 7. CHAMPIGNONS (7 plantes)

| Plante            | Coût ☀️ | Mécanique Spéciale              | État             | Notes                                   |
|-------------------|---------|---------------------------------|------------------|-----------------------------------------|
| **PuffShroom**    | 0       | `Range=18` (court)              | ✅ Implémenté     | Range limité dans ProjectileSpawnSystem |
| **SeaShroom**     | 0       | `RequiresWater`                 | ⚠️ Partiel       | Validation eau à compléter              |
| **FumeShroom**    | 75      | `PiercesShields`                | ✅ Implémenté     | Flag dans ProjectileComponent           |
| **ScaredyShroom** | 25      | `HidesWhenNear`, `HideRadius=6` | ✅ Implémenté     | HidingComponent + MushroomSystem        |
| **HypnoShroom**   | 75      | `HypnotizesOnDeath`             | ❌ Non implémenté | Retourne zombie = complexe              |
| **GloomShroom**   | 150     | `ShootsAllDirections`           | ⚠️ Partiel       | 8 directions à implémenter              |
| **CoffeeBean**    | 75      | `WakesMushrooms`                | ⚠️ Partiel       | SleepingComponent existe                |

### 🔧 8. SUPPORT / UTILITAIRES (9 plantes)

| Plante           | Coût ☀️ | Mécanique                                | État             | Notes                        |
|------------------|---------|------------------------------------------|------------------|------------------------------|
| **Torchwood**    | 175     | `EnhancesPeas`, `FireDamageMultiplier=2` | ✅ Implémenté     | EnhancementSystem complet    |
| **Plantern**     | 25      | `RemovesFog`                             | ❌ Non implémenté | Fog system manquant          |
| **Blover**       | 100     | `RemovesFlying`                          | ⚠️ Partiel       | Flying zombies à implémenter |
| **UmbrellaLeaf** | 100     | `DeflectsProjectiles`                    | ❌ Non implémenté | Catapult zombies?            |
| **GoldMagnet**   | 50      | `CollectsCoins`                          | ❌ Non implémenté | Coin system manquant         |
| **LilyPad**      | 25      | `IsWaterPlatform`                        | ⚠️ Partiel       | Platform system basique      |
| **FlowerPot**    | 25      | `IsGroundPlatform`                       | ⚠️ Partiel       | Pour niveaux roof            |
| **GraveBuster**  | 75      | `RemovesGraves`                          | ❌ Non implémenté | Grave spawning manquant      |
| **Imitater**     | +0      | `IsImitater`                             | ❌ Non implémenté | Clone plant complexe         |

### 🌵 9. PIÈGES (1 plante)

| Plante        | Coût ☀️ | Mécanique                              | État          | Notes                              |
|---------------|---------|----------------------------------------|---------------|------------------------------------|
| **Spikeweed** | 100     | `IsTrap`, `DamagesOnWalk`, `PopsTires` | ✅ Implémenté | TrapSystem fonctionne + PopsTires  |

---

## 📈 STATISTIQUES D'IMPLÉMENTATION

### Résumé Global

| Catégorie    | Total  | ✅ Complet    | ⚠️ Partiel   | ❌ Non implémenté |
|--------------|--------|--------------|--------------|------------------|
| Shooters     | 9      | 7            | 1            | 1                |
| Catapultes   | 5      | 4            | 0            | 1                |
| Explosives   | 7      | 5            | 2            | 0                |
| Instant-Kill | 1      | 1            | 0            | 0                |
| Défensives   | 5      | 3            | 1            | 1                |
| Producteurs  | 4      | 3            | 1            | 0                |
| Champignons  | 7      | 3            | 2            | 2                |
| Support      | 9      | 1            | 3            | 5                |
| Pièges       | 1      | 1            | 0            | 0                |
| **TOTAL**    | **48** | **28 (58%)** | **11 (23%)** | **9 (19%)**      |

---

## ✅ SYSTÈMES ECS EXISTANTS

### Combat Systems (`src/arena/server/systems/combat/`)
- ✅ `ProjectileSpawnSystem.luau` - Tir, multi-shot, 3-lane, 5-way, catapult
- ✅ `ProjectileMovementSystem.luau` - Déplacement projectiles
- ✅ `CombatSystem.luau` - Détection collision, dégâts
- ✅ `SpecialPlantSystem.luau` - Explosions, Squash, Chomper, PotatoMine
- ✅ `EnhancementSystem.luau` - Torchwood fire enhancement
- ✅ `PlantFoodSystem.luau` - Capacités ultimes
- ✅ `TrapSystem.luau` - Spikeweed + PopsTires + Garlic DivertsZombies
- ⚠️ `BossSystem.luau` - Pour zombies boss

### Unit Systems (`src/arena/server/systems/units/`)
- ✅ `MushroomSystem.luau` - Sleep, Hide, day/night cycle
- ✅ `PlacementSystem.luau` - Validation placement, coût, cooldown
- ✅ `EntityDeathSystem.luau` - Nettoyage entités mortes
- ✅ `ZombieMovementSystem.luau` - Mouvement zombies

### Economy Systems (`src/arena/server/systems/economy/`)
- ✅ `SunflowerProductionSystem.luau` - Production soleil
- ✅ `SunSpawnSystem.luau` - Spawn soleil du ciel
- ✅ `SunCollectionSystem.luau` - Collecte soleil
- ✅ `CoinProductionSystem.luau` - Marigold produit coins

### Mutation Systems (`src/arena/server/systems/mutations/`)
- ✅ `FreezeSystem.luau` - Effets gel
- ✅ `BurnDamageSystem.luau` - Dégâts feu
- ✅ `SplashDamageSystem.luau` - Dégâts zone
- ✅ `ChainLightningSystem.luau` - Chaîne éclairs
- ✅ `LifestealSystem.luau` - Vol de vie
- ✅ `PoisonCloudSystem.luau` - Nuages poison

---

## 🔧 COMPONENTS DISPONIBLES

### Combat Components
- ✅ `ProjectileComponent` - IsFrozen, IsCatapult, CanStun, PiercesShields, CanHitFlying
- ✅ `ArmedComponent` - PotatoMine arming state
- ✅ `ChewingComponent` - Chomper busy state
- ✅ `HidingComponent` - ScaredyShroom hide state
- ✅ `SlowComponent` - Freeze/slow effects
- ✅ `StunComponent` - Butter stun
- ✅ `SplashComponent` - Area damage
- ✅ `EnhancedProjectileComponent` - Fire peas

### Unit Components
- ✅ `SleepingComponent` - Mushroom day sleep
- ✅ `PlantTypeComponent` - Plant type + lane
- ✅ `ShellComponent` - Pumpkin protection (stacking)
- ✅ `ShieldComponent` - Zombie shields
- ✅ `JumpingComponent` - Pole vaulter state

---

## 🗺️ ROADMAP D'IMPLÉMENTATION PRIORITAIRE

### 🏃 Sprint 1 : Compléter les Partiels (Quick Wins) ✅ TERMINÉ

| Priorité | Plante/Feature            | Travail Requis                       | État  |
|----------|---------------------------|--------------------------------------|-------|
| P1       | **SunShroom Growth**      | Timer dans SunflowerProductionSystem | ✅ Déjà implémenté |
| P1       | **GloomShroom 8-way**     | `fireAllDirections()` ajouté         | ✅ Implémenté |
| P1       | **DoomShroom Crater**     | `GridService.BlockCell()` ajouté     | ✅ Implémenté |
| P1       | **CoffeeBean Wake**       | PlacementSystem + MushroomSystem     | ✅ Déjà implémenté |
| P1       | **TallNut BlocksJumpers** | `VaultedComponent` + CombatSystem    | ✅ Implémenté |

**Sprint 1 complété!**

### 🌱 Sprint 2 : Systèmes Manquants Simples ✅ TERMINÉ

| Priorité | Feature                     | Système à créer                       | État   |
|----------|-----------------------------|---------------------------------------|--------|
| P2       | **Garlic DivertsZombies**   | TrapSystem complet                    | ✅ Implémenté |
| P2       | **Pumpkin Stacking**        | ShellComponent + CombatSystem         | ✅ Implémenté |
| P2       | **Marigold CoinProduction** | CoinProductionSystem créé             | ✅ Implémenté |
| P2       | **Water Lane Validation**   | PlacementSystem (déjà fait)           | ✅ Implémenté |

**Sprint 2 complété!**

### 🚀 Sprint 3 : Features Avancées ❌ EN ATTENTE

| Priorité | Feature                   | Complexité                        | Effort | Status |
|----------|---------------------------|-----------------------------------|--------|--------|
| P3       | **Cattail Homing**        | HomingProjectileSystem            | 6h     | ❌ Non commencé |
| P3       | **CobCannon Manual Fire** | UI click + targeting              | 8h     | ❌ Non commencé |
| P3       | **HypnoShroom**           | Retourner zombie = faction change | 6h     | ❌ Non commencé |
| P3       | **Fog System**            | Visibilité + Plantern + Blover    | 8h     | ✅ **Implémenté** (FogSystem.luau + FogController.luau) |
| P3       | **Flying Zombies**        | CanHitFlying validation           | 6h     | ⚠️ Flag existe, zombies manquants |

**Effort restant Sprint 3:** ~20h (Fog fait, reste homing + cobcannon + hypno)

### 🏆 Sprint 4 : Cosmétiques & Polish ❌ EN ATTENTE

| Priorité | Feature                     | Type                       | Effort | Status |
|----------|-----------------------------|----------------------------|--------|--------|
| P4       | **Imitater Clone**          | UI + spawn duplicate       | 6h     | ❌ Non commencé |
| P4       | **GraveBuster + Graves**    | Night level mechanics      | 8h     | ❌ Non commencé |
| P4       | **UmbrellaLeaf Deflect**    | Catapult zombie protection | 4h     | ❌ Non commencé |
| P4       | **GoldMagnet Auto-collect** | Coin attraction range      | 3h     | ❌ Non commencé |

**Effort total Sprint 4:** ~21h

---

## 🏗️ ARCHITECTURE SYSTÈME (COMPLÈTE)

### Systèmes Serveur Arena (27 fichiers - V2 Pattern)

| Catégorie | Systèmes | Status |
|-----------|----------|--------|
| **Combat** (8) | BossSystem, CombatSystem, EnhancementSystem, PlantFoodSystem, ProjectileMovementSystem, ProjectileSpawnSystem, SpecialPlantSystem, TrapSystem | ✅ 100% |
| **Core** (5) | EventCleanupSystem, FullSyncSystem, PerformanceSystem, SafeEntityCapSystem, LaneCacheSystem | ✅ 100% |
| **Economy** (4) | CoinProductionSystem, SunCollectionSystem, SunflowerProductionSystem, SunSpawnSystem | ✅ 100% |
| **Environment** (1) | FogSystem | ✅ 100% |
| **Mutations** (8) | BurnDamageSystem, ChainLightningSystem, FreezeSystem, LifestealSystem, MutationApplySystem, PoisonCloudSystem, SplashDamageSystem, SolarKillSystem | ✅ 100% |
| **Units** (4) | EntityDeathSystem, MushroomSystem, PlacementSystem, ZombieMovementSystem | ✅ 100% |
| **Wave** (1) | WaveLoopSystem | ✅ 100% |

### Services Arena (10 fichiers)

| Service | Rôle | Status |
|---------|------|--------|
| ArenaService | Lifecycle battle, config monde/difficulté | ✅ |
| GridService | Occupancy tracking, plant limits | ✅ |
| LightingService | Presets éclairage par monde | ✅ |
| MapService | Chargement dynamique maps | ✅ |
| MutationService | Cache mutations joueur | ✅ |
| PlantFoodService | Charges Plant Food (0-3) | ✅ |
| PlayerDataService | Persistence ProfileStore | ✅ |
| StatsService | Statistiques session | ✅ |
| SunService | Économie soleil joueur | ✅ |
| WaveService | État vagues, orchestration | ✅ |

### Systèmes Client Arena (7 fichiers)

| Système | Priorité | Status |
|---------|----------|--------|
| PlacementPreviewSystem | 50 | ✅ Ghost preview, validation visuelle |
| EffectsSystem | 350 | ✅ VFX/Audio, music dynamique |
| GridRenderingSystem | 350 | ✅ Debug grid |
| SunRenderingSystem | 400 | ✅ Collection optimiste |
| PlantRenderingSystem | 405 | ✅ Modèles, animations |
| ZombieRenderingSystem | 410 | ✅ Interpolation, fog visibility |
| ProjectileRenderingSystem | 420 | ✅ Trails, impacts |

### Lobby Implémentation

| Catégorie | Fichiers | Status |
|-----------|----------|--------|
| **Services Serveur** | LobbyService, PlayerDataService | ✅ 100% |
| **Managers Serveur** | 6 managers (Countdown, Broadcaster, Queue, Touch, Lock, Teleport) | ✅ 100% |
| **Handlers Serveur** | MutationHandler, PadConfigReader, ShopHandler | ✅ 100% |
| **Controllers Client** | 6 controllers (HUD, Pad, Zone, Tooltip, Visibility, DeckBuilder) | ✅ 100% |
| **UI Organisms** | 7 écrans (Lobby, Profile, Shop, Deck, Mutation, Unlocks, SeedBank) | ✅ 100% |

---

## 📏 CONVENTIONS DE DÉGÂTS (VALIDÉES)

| Référence    | Valeur PlantData | Équivalent    |
|--------------|------------------|---------------|
| 1 pea        | 20 dmg           | Dégât de base |
| 1 cabbage    | 40 dmg           | 2 peas        |
| 1 melon      | 80 dmg           | 4 peas        |
| Instant-kill | 1800 dmg         | 90 peas       |
| Splash melon | 40 dmg (50%)     | 2 peas        |

---

## 🎯 PROCHAINES ÉTAPES RECOMMANDÉES

### 🔴 Haute Priorité (Sprint 3)

1. **Cattail Homing Projectiles** (~6h)
   - Créer `HomingProjectileComponent` (existe déjà!)
   - Implémenter logique homing dans `ProjectileMovementSystem`
   - Target: zombie le plus proche cross-lane

2. **CobCannon Manual Fire** (~8h)
   - UI: Click-to-fire targeting overlay
   - Network: `CobCannonFireRequest` event (déjà dans packets.zap!)
   - Server: Spawn projectile at target position

3. **HypnoShroom** (~6h)
   - `HypnotizedComponent` (existe!)
   - Toggle faction dans `ZombieMovementSystem`
   - VFX: Swirl eyes indicator

### 🟡 Moyenne Priorité (Sprint 4)

4. **Flying Zombies** (~6h)
   - `CanHitFlying` flag déjà dans ProjectileComponent
   - Créer `FlyingZombie` dans ZombieData
   - Modifier CombatSystem pour hit detection aérienne

5. **Imitater Clone** (~6h)
   - UI selection du plant à imiter
   - Spawn duplicate avec visuals différents
   - Cooldown séparé

### 🟢 Basse Priorité (Polish)

6. **GraveBuster + Graves** - Night levels
7. **UmbrellaLeaf Deflect** - Catapult protection
8. **GoldMagnet Auto-collect** - Coin attraction

---

## 📈 EPICS & MILESTONES (Timeline 20 Semaines)

| Phase | Epic | Semaines | Status |
|-------|------|----------|--------|
| **Phase 1** | Epic 1: ECS Skeleton | 1-2 | ✅ Complète |
| **Phase 1** | Epic 2: Grid & Deployment | 3-4 | ✅ Complète |
| **Phase 2** | Epic 3: Swarm Engine | 5-7 | ✅ Complète |
| **Phase 2** | Epic 4: The Arsenal | 8-10 | ✅ Complète |
| **Phase 3** | Epic 5: Progression Loop | 11-13 | ✅ Complète |
| **Phase 3** | Epic 6: "Juice" Injection | 14-16 | 🟡 En cours (VFX/Audio polish) |
| **Phase 4** | Epic 7: Monetization & Analytics | 17-18 | ❌ Non commencé |
| **Phase 4** | Epic 8: QA & Optimization | 19-20 | ❌ Non commencé |

### Post-Launch Roadmap

| Version | Contenu | Status |
|---------|---------|--------|
| V1.5 | Hard/Nightmare, Daily Challenges, Plant Mastery | ❌ Planifié |
| V2.0 | Worlds 2-4, Endless Mode, +20 zombies, +12 plants | ❌ Planifié |
| V2.5 | PvP Arena, Coop Mode (2-4 players) | ❌ Planifié |
| V3.0 | Roguelite Mode, Trading, Housing | ❌ Planifié |

---

## 📊 MÉTRIQUES TECHNIQUES

| Métrique | Cible | Actuel |
|----------|-------|--------|
| Entity Cap | 200 | ✅ SafeEntityCapSystem |
| FPS Target | 60 | ✅ 60 ticks/sec ECS |
| Bandwidth | <50 KB/s | ✅ Zap optimisé |
| LaneCache | O(1) | ✅ Implémenté |
| Strict Typing | 100% | ✅ `--!strict` partout |

---

> **Dernière mise à jour:** 18 Janvier 2026  
> **Source:** Analyse automatisée du codebase complet  
> **Prochaine review:** Fin Sprint 3
