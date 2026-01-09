# Instructions for GitHub Copilot

I am working on a Roblox Project with a **Monorepo Multi-Place Architecture** (Lobby + Arena).
You must strictly follow the documentation for the libraries I am using. Do not hallucinate APIs.

## 📚 Documentation Sources of Truth
For every implementation, refer to these specific API docs:

1.  **Data Persistence: ProfileStore**
    * **Doc:** https://madstudioroblox.github.io/ProfileStore/api/
    * **Rule:** Use strict typing. Always handle `Profile:Release()` properly before teleporting. Use `Mock` mode for Studio testing if needed.

2.  **UI Framework: Fusion 0.3 (NOT 0.2)**
    * **Doc:** https://elttob.uk/Fusion/0.3/api-reference/
    * **Rule:** We are using Fusion 0.3. Do NOT use `Fusion.State`. Use `Fusion.Value`, `Fusion.Computed`, and `Fusion.Scope`. Use the new syntax for components.

3.  **ECS Engine: Matter**
    * **Doc:** https://matter-ecs.github.io/matter/api/Matter
    * **Rule:** Never mutate components directly. Use `world:insert` with immutable table operations.

4.  **Table Utilities: Sift**
    * **Doc:** https://cxmeel.github.io/sift/api/Sift
    * **Rule:** Use Sift for all table manipulations (Dictionaries/Arrays) to maintain immutability required by Matter. Ex: `Sift.Dictionary.merge`, `Sift.Array.filter`.

5.  **Async Logic: Promise**
    * **Doc:** https://eryn.io/roblox-lua-promise/api/Promise
    * **Rule:** Use Promises for all async operations (Data loading, Teleports). Avoid generic `pcall` loops; use `Promise.retry` if necessary.

6.  **Networking: Zap**
    * **Doc:** https://zap.redblox.dev/usage/generated-api.html
    * **Rule:** Never edit `generated.luau`. Use the generated API strictly for typesafe networking.

7.  **Cleanup: Trove**
    * **Doc:** https://sleitnick.github.io/RbxUtil/api/Trove/
    * **Rule:** Use Trove inside generic Classes or Controllers to clean up connections/instances on destroy.

8.  **Events: Signal**
    * **Doc:** https://sleitnick.github.io/RbxUtil/api/Signal/
    * **Rule:** Use Signal for communication between UI Controllers and non-ECS Managers.

## 🏗️ Architecture Context
- **Src Structure:** `src/shared` (Common), `src/lobby` (Place 1), `src/arena` (Place 2).
- **Rojo:** We map `src/shared` to `ReplicatedStorage/Shared` in both places.