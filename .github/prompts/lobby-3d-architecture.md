# Lobby 3D Physique - Architecture

## Vision
Transformer le lobby GUI en un espace 3D explorable avec des plateformes de téléportation interactives, similaire à Tower Defense Simulator, Toilet Tower Defense, etc.

## Expérience Joueur

```
Joueur rejoint Lobby
   ↓
Spawn dans l'espace 3D (Humanoid, se promène)
   ↓
Explore le monde : Pads de téléportation, Shop zone, Profile zone
   ↓
Marche sur un TeleportPad (ex: "Stage 1-1")
   ↓
BillboardGui affiche : Stage info, X/4 joueurs, Countdown
   ↓
Quand 1+ joueurs ET countdown terminé → Téléportation vers Arena
```

## Structure du Monde Lobby

```
Workspace/
├── Lobby/
│   ├── Terrain (Map physique)
│   ├── SpawnLocation (Spawn point joueur)
│   ├── TeleportPads/
│   │   ├── Stage_1-1/      # Pad pour stage 1-1
│   │   │   ├── Platform (Part avec TouchEnded/TouchStarted)
│   │   │   ├── Billboard (BillboardGui - info)
│   │   │   └── Configuration
│   │   │       ├── StageId (StringValue = "1-1")
│   │   │       ├── MinPlayers (IntValue = 1)
│   │   │       └── MaxPlayers (IntValue = 4)
│   │   ├── Stage_1-2/
│   │   ├── Stage_1-3/
│   │   └── ...
│   ├── ShopZone/
│   │   └── ProximityPrompt ("Open Shop")
│   └── ProfileZone/
│       └── ProximityPrompt ("View Profile")
```

## Systèmes Serveur

### 1. LobbyService.luau
**Responsabilités :**
- Track tous les TeleportPads dans le monde
- Gérer les files d'attente par pad (qui est sur quel pad)
- Gérer les countdowns de téléportation
- Téléporter les groupes quand prêts

**API :**
```lua
-- Initialize all pads in workspace
function LobbyService.Initialize()

-- Player stepped on pad
function LobbyService.PlayerJoinedPad(player: Player, padModel: Model)

-- Player left pad
function LobbyService.PlayerLeftPad(player: Player, padModel: Model)

-- Get pad state for UI updates
function LobbyService.GetPadState(padModel: Model): PadState

-- Force start teleport (manual trigger)
function LobbyService.ForceTeleport(padModel: Model)
```

**État par Pad :**
```lua
type PadState = {
    StageId: string,
    MinPlayers: number,
    MaxPlayers: number,
    PlayersInQueue: {Player},
    CountdownActive: boolean,
    CountdownRemaining: number,
}
```

### 2. TeleportPad Detection (Heartbeat loop)
**Responsabilités :**
- Detect players touching pad platforms
- Update queues en temps réel
- Trigger countdowns quand conditions met

**Logique Countdown :**
```lua
-- Si >= MinPlayers sur le pad:
--   Start countdown (10 secondes)
--   Si joueurs quittent et < MinPlayers : cancel countdown
--   Si countdown atteint 0 : teleport tous les joueurs sur le pad

-- Si MaxPlayers atteint : instant teleport (pas de countdown)
```

## Systèmes Client

### 1. PadUIController.luau
**Responsabilités :**
- Créer/Update BillboardGui au-dessus de chaque pad
- Afficher : Stage name, X/Y joueurs, Countdown, Status

**UI States :**
- **Waiting** : "Stage 1-1 | 0/4 Players | Step on to join"
- **Countdown** : "Stage 1-1 | 2/4 Players | Starting in 7..."
- **Full** : "Stage 1-1 | 4/4 Players | Teleporting..."
- **Locked** : "Stage 1-2 | 🔒 Complete 1-1 first"

### 2. ShopController.luau / ProfileController.luau
**Responsabilités :**
- Écouter ProximityPrompt triggered
- Ouvrir GUI existante (ShopView / ProfileView)
- Fermer GUI quand joueur s'éloigne

## Networking (Zap)

### Nouveaux événements :

```zap
-- Server → Client : Update pad state
event PadStateUpdate = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        PadId: string.utf8(..50),  -- Unique ID du pad
        StageId: string.utf8(..50),
        PlayersCount: u8,
        MaxPlayers: u8,
        CountdownRemaining: u8?,  -- nil si pas de countdown
        IsLocked: boolean,         -- Si joueur n'a pas unlock ce stage
    }
}

-- Client → Server : Manual ready (optionnel)
event ReadyForTeleport = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        PadId: string.utf8(..50),
    }
}
```

## Implémentation Progressive

### Phase 1 : Core Teleport Pads (MVP)
1. ✅ Créer structure Workspace avec 3 pads de test (1-1, 1-2, 1-3)
2. ✅ LobbyService : detection + queue management
3. ✅ Countdown logic (10 secondes, cancellable)
4. ✅ Téléportation groupée vers Arena
5. ✅ BillboardGui basique (texte seulement)

### Phase 2 : UI Polish
6. ⭐ Billboard UI stylisée (thème PvZ)
7. ⭐ Animations (glow effect sur pad actif, particles)
8. ⭐ Sounds (pad activation, countdown tick, teleport woosh)

### Phase 3 : Shop/Profile Zones
9. 🛒 Shop zone physique avec ProximityPrompt
10. 📊 Profile zone physique avec ProximityPrompt
11. 🎨 Décor : NPCs, signs, ambiance

### Phase 4 : Advanced Features
12. 🔒 Lock visual (chains sur pads locked)
13. 🏆 Leaderboard zone (top players)
14. 🎮 Difficulty selector per pad (Normal/Hard/Nightmare)

## Considérations Techniques

### Performance
- Heartbeat loop doit être optimisé (spatial partitioning des pads)
- BillboardGui pooling si beaucoup de pads
- Network updates throttled (1 update/sec max par pad)

### Edge Cases
- **Joueur quitte pendant countdown** : remove de queue, recalc countdown
- **Téléportation échoue** : retry ou kick de queue avec message d'erreur
- **Max players atteint pendant countdown** : instant teleport
- **Joueur AFK sur pad** : kick après 30 secondes d'inactivité

### Testing
- **Solo play** : MinPlayers = 1 pour testing
- **Multiplayer** : Test avec 2-4 joueurs simultanés
- **Stage locking** : Vérifier que pads locked affichent 🔒

## Migration depuis GUI Lobby

### Changements :
1. **Supprimer** : LobbyScreen GUI auto-mount
2. **Garder** : ShopView, ProfileView (appelés manuellement)
3. **Ajouter** : Character spawn, humanoid setup
4. **Convertir** : Stage selection → Walk to pad

### Compatibilité :
- ✅ TeleportData reste identique (même structure Arena)
- ✅ PlayerDataService inchangé
- ✅ Retour Arena → Lobby fonctionne (spawn au SpawnLocation)

## Files à Créer

### Serveur
- `src/lobby/server/services/LobbyService.luau`
- `src/lobby/server/modules/PadManager.luau`

### Client
- `src/lobby/client/controllers/PadUIController.luau`
- `src/lobby/client/controllers/ShopZoneController.luau`
- `src/lobby/client/controllers/ProfileZoneController.luau`
- `src/lobby/client/ui/PadBillboard.luau` (Fusion component)

### Shared
- `src/lobby/shared/LobbyConfig.luau` (countdown time, min/max players)

### Workspace (Roblox Studio)
- Construire la map physique avec pads
- Placer spawn points, zones, décor

## Questions Ouvertes

1. **Sélection de deck** : Comment ? 
   - Option A : GUI pre-lobby (avant spawn)
   - Option B : Deck selection zone physique dans lobby
   - Option C : Pad settings (ProximityPrompt ouvre deck GUI)

2. **Difficulty selection** : Par pad ou global ?
   - Option A : Chaque pad a 3 sous-pads (Normal/Hard/Nightmare)
   - Option B : Zone centrale "Difficulty Selector"

3. **Party system** : Rejoindre un ami ?
   - Option A : V2+ feature (friends auto-join même pad)
   - Option B : MVP (aucun party system)

## Recommandation

**Pour MVP (Phase 1) :**
- 3 pads de test (Stage 1-1, 1-2, 1-3)
- MinPlayers = 1 (solo testing)
- MaxPlayers = 4
- Countdown = 10 secondes
- BillboardGui texte simple
- Pas de deck selection (utilise dernier deck sauvegardé)
- Pas de difficulty (Normal only)

**Temps estimé :** 4-6 heures (avec map building)

---

**Prêt à implémenter ?** Je peux commencer par Phase 1 (Core Teleport Pads).
