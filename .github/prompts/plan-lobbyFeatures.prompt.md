# Lobby System - Remaining Features Plan

## Current Status

### ✅ Completed
- Multi-place architecture (Lobby + Arena)
- TeleportService integration with TeleportData
- Lobby server bootstrap with PlayerDataService
- Lobby client bootstrap with Fusion UI
- LobbyScreen UI structure (Main Menu, Stage Select, Deck Builder)
- Zap networking for teleport requests
- Stage validation (StageData format: "1-1", "1-2", etc.)
- Deck validation (1-6 plants, unlocked check)
- ProfileStore with Studio fallback (mock profiles on DataStore errors)

### 🚧 Pending Features

1. **Profile UI**
2. **Shop UI**
3. **Results Screen** (Arena → Lobby return)
4. **Arena TeleportData Receiver**

---

## Feature 1: Profile UI

### Purpose
Display player progression, stats, and plant mastery.

### UI Components

#### ProfileView Structure
```
┌─────────────────────────────────────┐
│  [< Back]         PROFILE           │
├─────────────────────────────────────┤
│  Player: Akuushii                   │
│  Level: 12   XP: 2450/3000          │
│  Coins: 5,430   Gems: 120           │
├─────────────────────────────────────┤
│  STATS                              │
│  • Games Played: 87                 │
│  • Games Won: 65 (74.7%)            │
│  • Zombies Killed: 3,245            │
│  • Plants Placed: 8,921             │
├─────────────────────────────────────┤
│  STAGE PROGRESS                     │
│  World 1: 5/5 ⭐⭐⭐                 │
│  World 2: 3/5 ⭐⭐                   │
│  World 3: 0/5 🔒                    │
├─────────────────────────────────────┤
│  PLANT MASTERY                      │
│  [Peashooter] Rank 5  █████░░░░░    │
│  [Sunflower]  Rank 3  ███░░░░░░░    │
│  [WallNut]    Rank 4  ████░░░░░░    │
└─────────────────────────────────────┘
```

### Data Required
From `profile.Data`:
- `Level`, `XP`
- `Coins`, `Gems`
- `Stats` (GamesPlayed, GamesWon, ZombiesKilled, PlantsPlaced)
- `CompletedStages` (stageId → stars)
- `PlantMastery` (plantType → {Rank, XP})

### Implementation Steps
1. Create `ProfileView.luau` component in `src/lobby/client/ui/`
2. Add Zap event `SyncPlayerData` to push profile updates to client
3. Display stats with progress bars for XP and mastery
4. Calculate world completion (iterate CompletedStages)
5. Sort plants by mastery rank

---

## Feature 2: Shop UI

### Purpose
Allow players to purchase plants, upgrades, and cosmetics using Coins/Gems.

### UI Components

#### ShopView Structure
```
┌─────────────────────────────────────┐
│  [< Back]          SHOP             │
│              💰 5,430  💎 120        │
├─────────────────────────────────────┤
│  [Plants] [Upgrades] [Cosmetics]    │
├─────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐         │
│  │ SnowPea  │  │ Repeater │         │
│  │  ❄️ 150  │  │  💰 200   │         │
│  │  💰 500  │  │  🔒 Lv3   │         │
│  │ [Buy]    │  └──────────┘         │
│  └──────────┘                       │
│  ┌──────────┐  ┌──────────┐         │
│  │ Chomper  │  │ Cherry   │         │
│  │  🍔 100  │  │  💣 250   │         │
│  │  💰 600  │  │  💎 50    │         │
│  │ [Buy]    │  │ [Buy]    │         │
│  └──────────┘  └──────────┘         │
└─────────────────────────────────────┘
```

### Shop Data Structure
```lua
type ShopItem = {
    ItemType: "Plant" | "Upgrade" | "Cosmetic",
    ItemId: string,
    Name: string,
    Description: string,
    Cost: number,
    Currency: "Coins" | "Gems",
    RequiredLevel: number?,
    RequiredStage: string?,
    Icon: string,
}
```

### Implementation Steps
1. Create `ShopConfig.luau` in `src/shared/config/` with shop items
2. Create `ShopView.luau` component with tabs
3. Add Zap event `PurchaseItem` (Client → Server)
4. Add Zap event `PurchaseResponse` (Server → Client)
5. Server validates purchase (cost, level, ownership)
6. Server deducts currency and unlocks item in profile
7. Client displays purchase confirmation/error

---

## Feature 3: Results Screen

### Purpose
Display battle results when player returns from Arena to Lobby.

### UI Components

#### ResultsPopup Structure
```
┌─────────────────────────────────────┐
│          🎉 VICTORY! 🎉             │
│                                     │
│         Stage 1-3 Cleared           │
│          ⭐⭐⭐ (3 Stars)            │
│                                     │
│  🏆 Rewards:                        │
│    +150 Coins                       │
│    +50 XP                           │
│    +Bonus: First Clear! (+100 💰)   │
│                                     │
│  📊 Performance:                    │
│    Zombies Killed: 45               │
│    Plants Placed: 12                │
│    Time: 3:24                       │
│    Health: 95%                      │
│                                     │
│         [Continue]                  │
└─────────────────────────────────────┘
```

### Data Flow
1. Arena: On battle end, create `LobbyReturnData`
2. Arena: `TeleportService:TeleportAsync(LobbyPlaceId, {player}, teleportOptions)`
3. Lobby Server: Receive `GetLocalPlayerTeleportData()` on player join
4. Lobby Server: Process rewards, update profile
5. Lobby Server: Send results to client via Zap
6. Lobby Client: Display ResultsPopup

### Implementation Steps
1. **Arena Side**: 
   - Detect battle end in WaveSystem
   - Calculate stars (via StageData.CalculateStars)
   - Create LobbyReturnData with results
   - Teleport back to Lobby
2. **Lobby Server**:
   - Check teleportData on PlayerAdded
   - Validate LobbyReturnData
   - Update CompletedStages, add coins/XP
   - Send results to client
3. **Lobby Client**:
   - Listen for results event
   - Show ResultsPopup with animations
   - Update local UI state

---

## Feature 4: Arena TeleportData Receiver

### Purpose
Load the correct stage and deck when player teleports from Lobby.

### Current State
- `src/server/init.server.luau` has basic TeleportData reception (commented out)
- Need to integrate with GameStateService to start battle

### Implementation Steps

1. **Verify TeleportData Reception**
   ```lua
   -- In src/server/init.server.luau
   Players.PlayerAdded:Connect(function(player)
       local teleportData = player:GetJoinData().TeleportData
       if teleportData then
           local arenaData = TeleportData.ValidateArenaJoinData(teleportData)
           if arenaData then
               -- Store for when player loads
               pendingBattles[player.UserId] = {
                   StageId = arenaData.StageId,
                   Deck = arenaData.Deck,
               }
           end
       end
   end)
   ```

2. **Start Battle on Player Ready**
   - Wait for PlayerDataService to load profile
   - Get pendingBattle for player
   - Load StageConfig from StageData
   - Create world entities via Matter
   - Spawn player's deck plants via PlacementSystem

3. **Override Default Stage**
   - Current code starts `CurrentStage` from profile
   - If `pendingBattles[userId]` exists, use that stage instead
   - Clear pendingBattle after starting

---

## Implementation Priority

### Phase 1: Core Flow (High Priority)
1. ✅ Multi-place teleportation (DONE)
2. **Arena TeleportData Receiver** - Start battles from Lobby
3. **Results Screen** - Complete the loop (Arena → Lobby)

### Phase 2: Player Engagement (Medium Priority)
4. **Profile UI** - Show progression
5. **Shop UI** - Monetization & progression

### Phase 3: Polish (Low Priority)
- Animation polish (screen transitions)
- Sound effects
- Loading screens during teleport
- Error popups for failed teleports

---

## Testing Checklist

- [ ] Lobby → Arena: Stage loaded correctly
- [ ] Lobby → Arena: Deck spawned correctly
- [ ] Arena → Lobby: Results displayed
- [ ] Arena → Lobby: Rewards applied to profile
- [ ] Profile UI: Stats update after battle
- [ ] Shop: Purchase succeeds, profile updated
- [ ] Shop: Purchase fails (insufficient funds)
- [ ] Multi-session: Profile persists across rejoins

---

## Notes

- **DataStore in Studio**: Use mock profiles when 502 errors occur (already implemented)
- **PlaceIds**: Currently using real IDs (9511902546, 9511931270) - keep for production
- **Zap Schemas**: Lobby and Arena have separate `packets.zap` files
- **Stage Format**: Must use "1-1" format (not "world1_stage1")
- **Deck Size**: 1-6 plants (Zap type: `PlantType[1..6]`)
