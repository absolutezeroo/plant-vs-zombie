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
    * **Rule:** Use Promises for ALL async operations (Data loading, Teleports, HTTP). 
    * **Pattern:** `Promise.new() :andThen() :catch()` for chaining.
    * **Retry:** Use `Promise.retry(fn, maxAttempts, delay)` instead of pcall loops.
    * **Parallel:** Use `Promise.all({promise1, promise2})` for concurrent operations.
    * **NEVER** use `wait()` or `task.wait()` in ECS systems.

6.  **Networking: Zap**
    * **Doc:** https://zap.redblox.dev/usage/generated-api.html
    * **Rule:** Never edit `generated.luau`. Use the generated API strictly for typesafe networking.

7.  **Cleanup: Trove**
    * **Doc:** https://sleitnick.github.io/RbxUtil/api/Trove/
    * **Rule:** Use Trove for ALL `:Connect()` calls in Services/Controllers.
    * **Pattern:** `local _trove = Trove.new()` then `_trove:Connect(event, callback)`.
    * **Cleanup:** Call `_trove:Destroy()` in `Dispose()` or `BindToClose`.
    * **Exceptions:** One-shot connections (`tween.Completed`, `sound.Ended`), generated Zap code, ProfileStore API.

8.  **Events: Signal**
    * **Doc:** https://sleitnick.github.io/RbxUtil/api/Signal/
    * **Rule:** Use Signal instead of BindableEvent for internal communication.
    * **Cleanup:** Always wrap Signal connections with `_trove:Connect()`.

## 🏗️ Architecture Context
- **Src Structure:** `src/shared` (Common), `src/lobby` (Place 1), `src/arena` (Place 2).
- **Rojo:** We map `src/shared` to `ReplicatedStorage/Shared` in both places.