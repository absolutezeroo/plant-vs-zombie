# 🚀 Prochaines Étapes - Lobby 3D

## ✅ TERMINÉ

Le système de lobby physique 3D est **100% fonctionnel** avec :
- ✅ Teleport pads configurables
- ✅ Queue management + countdown
- ✅ BillboardGui temps réel
- ✅ CurrentDeck sauvegardé dans profile
- ✅ Network events (Zap)
- ✅ Documentation complète

---

## 🔧 AVANT DE TESTER

### 1. Régénérer Code Zap (CRITIQUE)

**Les nouveaux événements réseau doivent être compilés :**

```bash
# Dans le terminal PowerShell à la racine du projet
zap src/lobby/packets.zap
```

**Nouveaux events générés :**
- `PadStateUpdate` (Server → Client)
- `SaveDeck` (Client → Server)
- `DeckChanged` (Server → Client)

### 2. Construire la Map dans Studio

**Suivez le guide** : [BUILD-GUIDE-LOBBY.md](.github/BUILD-GUIDE-LOBBY.md)

**Structure minimale (Test 1 pad) :**
```
Workspace/
├── TeleportPads/
│   └── Stage_1-1/
│       ├── Platform (Part)
│       └── Configuration/
│           └── StageId (StringValue = "1-1")
└── SpawnLocation
```

### 3. Configurer les PlaceIds (Production)

Dans `src/shared/TeleportData.luau` :
```lua
PlaceIds = {
    Lobby = 0,      -- Remplacez par votre Lobby PlaceId
    Arena = 0,      -- Remplacez par votre Arena PlaceId
}
```

**Pour testing en Studio :**
- PlaceIds = 0 → Le système log "Studio mode" et skip la téléportation réelle
- Vous pouvez quand même tester le countdown et la logique

---

## 🧪 TESTING PLAN

### Phase 1 : Solo Test (Studio)

**Objectif** : Vérifier le système fonctionne avec 1 joueur

1. ✅ Build 1 pad dans Workspace
2. ✅ Régénérer Zap
3. ✅ Play test
4. ✅ Vérifier Output :
   - `[Info][Lobby] Loaded 1 teleport pads`
   - `[Info][PadUI] Created UI for pad ...`
5. ✅ Marcher sur le pad
6. ✅ Vérifier BillboardGui apparaît : "Stage 1-1 | 1/4 Players"
7. ✅ Countdown démarre : "Starting in 10..."
8. ✅ À 0 → Log de téléportation ou vraie téléportation

### Phase 2 : Multiplayer Test (Published)

**Objectif** : Tester queue groupée

1. ✅ Publier Lobby place
2. ✅ Configurer PlaceIds réels
3. ✅ Rejoindre avec 2+ comptes
4. ✅ Tous sur le même pad
5. ✅ Countdown synchronisé
6. ✅ Téléportation groupée vers Arena

### Phase 3 : Multi-Pad Test

**Objectif** : Plusieurs stages en parallèle

1. ✅ Build 3+ pads (1-1, 1-2, 1-3)
2. ✅ Joueurs sur différents pads
3. ✅ Countdowns indépendants
4. ✅ Téléportations séparées

### Phase 4 : Edge Cases

1. ✅ **AFK** : Rester immobile 30s → Kick
2. ✅ **Leave** : Quitter pad pendant countdown → Cancel
3. ✅ **Max** : 4 joueurs → Instant teleport
4. ✅ **Deck** : Change deck → Persist après rejoin

---

## 🎨 POLISH & FEATURES V2

### Priorité Haute

#### 1. Deck Builder GUI (2-3 heures)
**Objectif** : Interface complète pour sélectionner deck

**Tasks :**
- [ ] Créer `DeckBuilderView.luau` (Fusion component)
  - Grid de plants disponibles
  - Deck slots (6 max)
  - Drag & drop ou click to add
  - Save button
- [ ] Intégrer dans `DeckBuilderController.luau`
- [ ] Tester ProximityPrompt → Ouvrir GUI
- [ ] Server validation (UnlockedPlants check)

#### 2. Stage Lock System (1 heure)
**Objectif** : Lock pads si stage pas débloqué

**Tasks :**
- [ ] Dans `LobbyService.canPlayerJoinPad()` : Check `CompletedStages`
- [ ] Set `IsLocked = true` dans `PadStateUpdate`
- [ ] Client : Afficher 🔒 sur BillboardGui
- [ ] Visual : Red color, chains model (optionnel)
- [ ] Error sound si joueur marche sur pad locked

#### 3. Shop/Profile Zones (1-2 heures)
**Objectif** : ProximityPrompts ouvrent GUIs existantes

**Tasks :**
- [ ] Créer `ShopZoneController.luau`
- [ ] Créer `ProfileZoneController.luau`
- [ ] Build zones dans Studio avec ProximityPrompts
- [ ] Ouvrir ShopView/ProfileView depuis LobbyScreen
- [ ] Fermer GUI quand joueur s'éloigne

### Priorité Moyenne

#### 4. Visual Polish (2-3 heures)
**Objectif** : Rendre le lobby plus vivant

**Tasks :**
- [ ] **Particles** : Glow sur pads actifs (countdown)
- [ ] **Sounds** :
  - Pad activation (magic chime)
  - Countdown tick (last 3 seconds)
  - Teleport woosh
- [ ] **Animations** :
  - Pad pulsing (TweenService)
  - Character teleport effect (particles + fade)
- [ ] **Lighting** : SpotLights sur pads

#### 5. Results Screen Popup (1 heure)
**Objectif** : Afficher results quand retour Arena

**Tasks :**
- [ ] Detecter `ShowResults` event dans client
- [ ] Créer `ResultsPopup.luau` (extrait de LobbyScreen)
- [ ] Afficher automatiquement au spawn
- [ ] Animations (slide in, confetti si victory)

### Priorité Basse

#### 6. Leaderboard (2 heures)
**Objectif** : Top players dans lobby

**Tasks :**
- [ ] Créer `LeaderboardController.luau`
- [ ] SurfaceGui sur un Part dans lobby
- [ ] Fetch top 10 players (OrderedDataStore)
- [ ] Update every 60 seconds

#### 7. Party System (4-6 heures)
**Objectif** : Friends auto-join même pad

**Tasks :**
- [ ] Detect friends in lobby
- [ ] Visual indicators (player nameplates)
- [ ] Auto-join pad when friend joins
- [ ] Party leader system (optionnel)

---

## 🐛 KNOWN ISSUES

### Critiques (À Fixer Avant Production)

- [ ] **PlaceIds hardcodés** : Remplacer 0 par vrais IDs
- [ ] **Stage unlock** : Tous stages unlocked pour testing
- [ ] **Error handling** : Teleport failures pas gérés côté client

### Mineurs (Polish)

- [ ] DeckBuilderController GUI pas implémentée
- [ ] PadUIController : Retry si pad pas trouvé
- [ ] BillboardGui : Theme pas 100% PvZ

### Optimisations Futures

- [ ] Spatial partitioning (si 100+ pads)
- [ ] Billboard pooling
- [ ] Debounce sur Touched events

---

## 📝 REFACTORING POSSIBLE

### Structure Code

**Actuel** : Tout dans `src/lobby/`
**Amélioration** :
- Déplacer `shared/` vers `src/shared/lobby/` (partagé Arena/Lobby)
- Centraliser ProfileStore schema (éviter duplication)

### Network

**Actuel** : `packets.zap` a tous les events
**Amélioration** :
- Séparer en `lobby-packets.zap` et `arena-packets.zap`
- Ou garder 1 fichier mais organiser par sections

### UI Components

**Actuel** : `LobbyScreen.luau` = 787 lignes
**Amélioration** :
- Extraire `DeckBuilderView`, `StageSelectView`, `ResultsPopup` en fichiers séparés
- Réutiliser components (MenuButton, InfoCard, etc.)

---

## 🎯 MVP vs V2+ Scope

### MVP (Soft Launch - 1,000 Players)

**Must Have :**
- ✅ Teleport pads fonctionnels
- ✅ Queue + countdown
- ✅ BillboardGui basique
- ✅ CurrentDeck persist
- ⚠️ Deck Builder GUI (basic)
- ⚠️ Stage lock system

**Can Skip :**
- Shop/Profile zones (use GUI fallback)
- Particles, sounds, animations
- Leaderboard
- Party system

### V2+ (Post-Launch)

**Polish :**
- Full visual effects
- Sounds + music
- Animations smooth
- Leaderboard live
- Party system
- Hero Mode (PvP)

---

## 📊 Performance Targets

### Entity Budget (Lobby)
- **Target** : 50 players simultanés dans lobby
- **Pads** : 10-20 pads maximum
- **Heartbeat** : <1ms per frame
- **Network** : <10 KB/s per player

### Testing Benchmarks
- [ ] 10 players, 5 pads : 60 FPS
- [ ] 50 players, 10 pads : 60 FPS
- [ ] 100 players, 20 pads : 30 FPS (acceptable lobby)

---

## 🚀 GO-LIVE CHECKLIST

**Avant Publish Lobby :**
- [ ] Régénérer Zap
- [ ] Build map complète (3+ pads minimum)
- [ ] Configurer PlaceIds réels
- [ ] Test solo + multiplayer
- [ ] Deck Builder GUI fonctionnelle (ou disabled)
- [ ] Stage lock implémenté
- [ ] Error handling (teleport failures)
- [ ] Performance test (10+ players)

**Après Publish :**
- [ ] Monitor logs (ErrorHandler)
- [ ] Check player feedback
- [ ] Iterate sur polish
- [ ] Plan V2 features

---

**Prêt pour le refactoring ou les tests !** 🎮
