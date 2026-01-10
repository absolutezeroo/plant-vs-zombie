# 🗺️ Analyse WIP - Carte des Chantiers en Cours
**Date:** 10 Janvier 2026  
**Auteur:** Copilot Multi-Agent Deep Scan  
**Version:** 1.0

---

## 📊 Résumé Exécutif

Cette analyse compare le code source (`src/`) avec la documentation pour identifier :
- Les fonctionnalités cachées (en développement mais non documentées)
- Les TODOs critiques du code
- Le code mort vs le code futur (orphelins)

**Méthode :** 3 agents spécialisés ont scanné le codebase en parallèle.

---

## 🚧 1. Fonctionnalités "Cachées" (En cours de dev)

### 🌙 Système Jour/Nuit - AVANCÉ MAIS NON CONNECTÉ
| Élément | Status | Fichier |
|---------|--------|---------|
| `IsNight: boolean` dans WorldData | ✅ Défini | `src/shared/data/WorldData.luau` |
| `SleepingComponent` | ✅ Utilisé | `src/shared/components/units/` |
| Logique cycle jour/nuit | ❌ TODO | `src/arena/server/systems/units/MushroomSystem.luau:62` |

**Impact :** Les champignons ne dorment/se réveillent pas selon le type de monde.

### 🌊 Système Eau/Pool - PARTIELLEMENT IMPLÉMENTÉ
| Élément | Status | Fichier |
|---------|--------|---------|
| `HasWater`, `WaterLanes` dans WorldData | ✅ Défini | `src/shared/data/WorldData.luau` |
| Plantes aquatiques (LilyPad, TangleKelp, etc.) | ✅ Définies | `src/shared/data/PlantData.luau` |
| Validation zone eau | ❌ TODO | `src/arena/server/systems/units/PlacementSystem.luau:106` |

**Impact :** Les plantes aquatiques peuvent être placées n'importe où.

### 🛡️ Système Bouclier Zombie - STRUCTURE VIDE
| Élément | Status | Fichier |
|---------|--------|---------|
| `DamageReductionComponent` | ✅ Défini | `src/shared/components/mutations/` |
| Réduction dégâts bouclier | ❌ TODO | `src/arena/server/systems/combat/CombatSystem.luau:116` |

**Impact :** Les zombies à bouclier ne réduisent pas les dégâts.

### 🎨 Système Cosmétique (Skins) - DÉFINI MAIS NON UTILISÉ
| Élément | Status | Fichier |
|---------|--------|---------|
| `CosmeticData.luau` (355 lignes) | ✅ Complet | `src/shared/data/CosmeticData.luau` |
| `OwnedSkins` dans Zap | ✅ Défini | `src/shared/network/packets.zap:685` |
| `require("CosmeticData")` | ❌ Aucun | - |
| UI Skins | ❌ Non implémentée | - |

**Impact :** Les skins sont prêts en data mais non accessibles.

### 🎖️ Système Plant Mastery - DATA SEULEMENT
| Élément | Status | Fichier |
|---------|--------|---------|
| `PlantMastery` dans ProfileTemplate | ✅ Défini | `src/shared/data/ProfileTemplate.luau:30` |
| Incrémentation XP mastery | ❌ Aucun système | - |
| UI Mastery | ❌ Non implémentée | - |

**Impact :** Le système de maîtrise des plantes est purement passif.

### 🔧 Plasma Debugger - DÉSACTIVÉ
| Élément | Status | Fichier |
|---------|--------|---------|
| Import Plasma | ❌ Commenté | `src/arena/server/init.server.luau:69` |
| wally.toml | ❌ Non ajouté | `wally.toml` |

---

## 📝 2. La "Todo List" Réelle du Code

### Assets & Icônes (7 TODOs)
| Fichier | Ligne | Description |
|---------|-------|-------------|
| `WorldData.luau` | 62, 89, 116, 147, 178, 205 | `Icon = "rbxassetid://0" -- TODO: Add icon` (6 mondes) |
| `MutationData.luau` | 93 | `Icon = "rbxassetid://0" -- TODO: Add real asset` |

### Combat (2 TODOs)
| Fichier | Ligne | Description |
|---------|-------|-------------|
| `CombatSystem.luau` | 116 | `TODO: Implement shield damage reduction` |
| `PlacementSystem.luau` | 106 | `TODO: Implement water detection based on level type` |

### Gameplay (1 TODO)
| Fichier | Ligne | Description |
|---------|-------|-------------|
| `MushroomSystem.luau` | 62 | `TODO: Implement day/night cycle from WaveManager or GameState` |

### UI (1 TODO)
| Fichier | Ligne | Description |
|---------|-------|-------------|
| `DeckBuilderController.luau` | 41 | `TODO: Create dedicated DeckBuilder GUI` |

### Outils Dev (1 TODO)
| Fichier | Ligne | Description |
|---------|-------|-------------|
| `arena/server/init.server.luau` | 69 | `TODO: Add Plasma to wally.toml and re-enable debugger` |

### Services (1 TODO)
| Fichier | Ligne | Description |
|---------|-------|-------------|
| `ArenaService.luau` | 70 | `TODO: Get player level from PlayerDataService if needed` |

---

## 👻 3. Code Mort ou Futur ? (Orphelins)

### 🔴 Paquets Zap DÉFINIS mais JAMAIS ÉMIS

| Paquet | Fichier | Status |
|--------|---------|--------|
| `XPGained` | `packets.zap:574` | ⚠️ **Jamais `.Fire()`** |
| `LevelUp` | `packets.zap:588` | ⚠️ **Jamais `.Fire()`** |
| `GemsEarned` | `packets.zap:600` | ⚠️ **Jamais `.Fire()`** |
| `GameComplete` | `packets.zap:650` | ⚠️ **Jamais `.Fire()`** (utilise `GameOver` + `GameEndRewards`) |
| `RemoveMutationResponse` | `packets.zap:903` | ⚠️ **DEPRECATED** dans le commentaire Zap |

### 🟡 Modules JAMAIS IMPORTÉS

| Fichier | Lignes | Status |
|---------|--------|--------|
| `CosmeticData.luau` | 355 | ⚠️ **Aucun `require()`** trouvé |
| `LaneCache.luau` | ~100 | ⚠️ **Aucun `require()`** trouvé |

### 🟠 Données Profile JAMAIS LUES EN JEU

| Champ | Fichier | Status |
|-------|---------|--------|
| `PlantMastery` | ProfileTemplate | ⚠️ Jamais incrémenté |
| `Settings.MusicVolume` | ProfileTemplate | ⚠️ Client utilise valeurs hardcodées |
| `Settings.SFXVolume` | ProfileTemplate | ⚠️ Client utilise valeurs hardcodées |

### 🟣 Systèmes DEPRECATED

| Système | Fichier | Note |
|---------|---------|------|
| `ZombieSpawnSystem` | `src/arena/server/systems/units/` | `@deprecated Use WaveManagerSystem` |

---

## ✅ 4. Chantiers FONCTIONNELS (Non documentés)

Ces systèmes fonctionnent mais ne sont pas dans la doc :

### Système Mutations - 100% FONCTIONNEL
- **Backend :** `MutationHandler.luau` (Purchase, Equip, Unequip)
- **Data :** `MutationData.luau` (19 mutations complètes)
- **ECS :** 8 systèmes mutations actifs (Burn, Freeze, Chain Lightning, etc.)
- **Réseau :** Tous les paquets câblés et fonctionnels
- **UI :** `MutationView.luau` existe (~1000 lignes)

### Système Plant Food - FONCTIONNEL
- **Backend :** `PlantFoodSystem.luau` (système complet)
- **Data :** `PlantFoodData.luau` (effets par plante)
- **Réseau :** `PlantFoodRequest`, `PlantFoodActivated`, etc.

### MapLoader - FONCTIONNEL
- Chargement dynamique des maps depuis ReplicatedStorage
- Sync config grille aux clients
- Preload assets

---

## 🎯 5. Recommandations de Priorisation

### 🥇 Quick Wins (< 1 jour)
1. **Cycle Jour/Nuit** - 30 min
   - Lire `WorldData.IsNight` dans `MushroomSystem`
   
2. **Supprimer ZombieSpawnSystem** - 15 min
   - Système deprecated, WaveManagerSystem le remplace

### 🥈 Medium Impact (1-2 jours)
3. **Connecter AudioService aux Settings Profile**
   - Lire `Settings.MusicVolume` / `SFXVolume` depuis PlayerData

4. **Implémenter validation eau dans PlacementSystem**
   - Lire `WorldData.WaterLanes` et valider placement

### 🥉 Future Features (V2)
5. **Système Skins** - ~1 semaine
6. **Plant Mastery** - ~3 jours
7. **Débugger Plasma** - 1 heure

---

## 📋 Checklist Maintenance

- [x] ~~Supprimer `ZombieSpawnSystem.luau` (deprecated)~~ ✅ Supprimé
- [x] ~~Supprimer `LaneCache.luau` (orphelin)~~ ✅ Supprimé
- [x] ~~Supprimer `RemoveMutationResponse` du schema Zap~~ ✅ Supprimé
- [x] ~~Supprimer `GameComplete` du schema Zap (doublon)~~ ✅ Supprimé
- [x] ~~Implémenter validation zone eau~~ ✅ PlacementSystem data-driven
- [x] ~~Implémenter bouclier zombie~~ ✅ CombatSystem + ShieldComponent
- [x] ~~Implémenter cycle jour/nuit~~ ✅ MushroomSystem lit WorldData.IsNight
- [x] ~~Câbler `XPGained.Fire()` et `LevelUp.Fire()`~~ ✅ Arena + Lobby PlayerDataService
- [x] ~~Ajouter icônes manquantes (6 mondes + mutations)~~ ✅ Emojis thématiques
- [x] ~~Documenter système Mutations dans `game-architecture.md`~~ ✅ Section complète ajoutée

---

## 📚 Références

- Scan effectué sur : `src/shared/`, `src/arena/`, `src/lobby/`
- Fichier Zap analysé : `src/shared/network/packets.zap`
- Documentation comparée : `docs/*.md`
- **Dernière mise à jour:** 10 Janvier 2026
