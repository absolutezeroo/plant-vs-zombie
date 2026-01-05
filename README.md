# 🌻 Plant vs Zombie: Ultimate Warfare (ECS)

A mobile-first tower defense game built on Roblox using Matter ECS architecture.

## 🎮 Game Pillars

| Pillar | Description |
|--------|-------------|
| **Mobile-First** | 60 FPS on iPhone 11, touch-optimized UI |
| **The Swarm** | 100+ zombies on screen, ECS-driven |
| **Skill Sovereignty** | Player skill > pay-to-win |
| **Sustainability** | Built to last, maintainable codebase |

## 🛠️ Tech Stack

| Tool | Version | Purpose |
|------|---------|---------|
| **Matter** | 0.8.4 | ECS framework |
| **Fusion** | 0.3.0 | Reactive UI |
| **Zap** | 0.6.28 | Type-safe networking |
| **ProfileStore** | 1.0.9 | Data persistence |
| **Rojo** | 7.6.1 | File sync |
| **Wally** | 0.3.2 | Package manager |

## 🚀 Getting Started

### Prerequisites

Install [Rokit](https://github.com/rojo-rbx/rokit) (manages Rojo, Wally, Zap):

```bash
rokit install
```

### Installation

```bash
# Install dependencies
wally install

# Generate network code
zap src/shared/network/packets.zap

# Start Rojo server
rojo serve
```

### Development Workflow

1. **Start Rojo**: `rojo serve`
2. **Open Studio**: Connect Rojo plugin
3. **Play Test**: F5 in Studio
4. **Edit Code**: Changes sync automatically

### Regenerating Files

```bash
# After editing wally.toml
wally install

# After editing packets.zap
zap src/shared/network/packets.zap
```

## 📁 Project Structure

```
src/
├── client/                 # Client-side code
│   ├── init.client.luau    # Client bootstrap
│   ├── systems/            # Client ECS systems
│   ├── ui/                 # Fusion UI components
│   └── network/            # Zap generated (gitignored)
├── server/                 # Server-side code
│   ├── init.server.luau    # Server bootstrap
│   ├── systems/            # Server ECS systems
│   └── network/            # Zap generated (gitignored)
└── shared/                 # Shared code
    ├── components/         # Matter components
    ├── config/             # Game configuration
    ├── network/            # Zap schema (packets.zap)
    └── utils/              # Utilities
```

## ⚡ Performance Targets

| Metric | Target | Enforced By |
|--------|--------|-------------|
| Entity Cap | 200 | SafetySystem |
| Frame Budget | 15ms | PerformanceMonitorSystem |
| Memory Limit | 600MB | Server bootstrap |
| Tick Rate | 60 Hz | Matter Loop |

## 🎯 Architecture

### ECS System Priorities

| Phase | Priority | Examples |
|-------|----------|----------|
| Input | 0-99 | InputSystem |
| Simulation | 100-299 | MovementSystem, CombatSystem |
| Presentation | 300-399 | VFXSystem, AudioSystem |
| Cleanup | 400+ | EventCleanupSystem |

### Sacred Constants (DO NOT CHANGE)

```lua
CELL_SIZE = 6        -- Grid cell size in studs
GRID_COLUMNS = 9     -- Playable columns
GRID_LANES = 5       -- Playable lanes
ENTITY_CAP = 200     -- Maximum entities
```

## 📜 Scripts

| Command | Description |
|---------|-------------|
| `rojo serve` | Start file sync server |
| `rojo build -o game.rbxl` | Build place file |
| `wally install` | Install/update packages |
| `zap src/shared/network/packets.zap` | Generate network code |

## 🧪 Testing

Play test in Studio and check Output for:
- `[Info][Server] Matter World created`
- `[Info][Server] Entity Pool initialized`
- `[Info][Client] Client bootstrap complete`

## 📖 Documentation

- [Game Architecture](docs/game-architecture.md) *(if exists)*
- [Matter ECS](https://matter-ecs.github.io/matter/)
- [Fusion](https://elttob.uk/Fusion/)
- [Zap](https://github.com/red-blox/zap)

## 📄 License

Private - All rights reserved.