---
name: roblox-executor-development
description: "Use when writing Luau for Roblox executors (client-side scripts). Covers the executor environment, client networking, runtime UI, client performance, script protection, and proving it runs on a real client."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [windows]
metadata:
  hermes:
    tags: [roblox, luau, executor, client-side, potassium, 0m3g4, script-development]
    related_skills: [potassium-script-testing, roblox-luau-ui-engineering, roblox-ui-lab, luau-obfuscator-vm-debug, luau-release-parity-audit]
---

# Executor-side Roblox development (client Luau)

This skill is for Luau that is **injected into a running Roblox client by an executor** —
one self-contained chunk, or a bundle concatenated into one, running on the player's own
machine inside the game someone else owns. Everything here assumes that context.

## Scope — what this skill is NOT for

Deliberately excluded, and why (full list in `references/sources-and-exclusions.md`):

| Not covered | Why |
|---|---|
| Server authority, anti-exploit design, remote argument validation *as server code* | We never write the server. The client-side reading of it lives in `references/client-networking.md`. |
| DataStore / ProfileStore / MemoryStore persistence | Server-only APIs. A client script cannot call them, executor or not. Use `references/client-persistence-and-secrets.md`. |
| Rojo, Script Sync, Studio containers, Studio MCP tools, place/model file formats, Studio plugin limits | Studio authoring concerns. We ship scripts, not places. |
| Monetization (game passes, developer products, Transfers, subscriptions) | Server-side economy concerns. |
| Server-side parallel Luau with Actors, `ServerLowMemoryWarning`, `StreamingEnabled` setup | Not actionable from an injected client script. |
| Cross-server messaging (`MessagingService`) | Server-only. |

## Where the knowledge came from

Adapted for executor/client use from two sources:

1. The third-party **roblox-dev-skill** knowledge base (`github.com/MSayib/roblox-dev-skill`,
   metadata version 2.7.0, HEAD commit `21b56c0`, cloned 2026-09-12). The language,
   deprecation, UI, networking and performance material was kept and rewritten; the
   server/Studio material was rewritten from the client side or dropped. Provenance,
   per-file mapping, and every exclusion are recorded in
   `references/sources-and-exclusions.md`. Where the upstream file flagged a claim as
   unverified or future-dated, that flag was kept — do not upgrade it to an assertion.
2. The **official Potassium documentation** (`https://docs.potassium.pro`, UNC-based,
   every page readable as `.md`, index at `/llms.txt`) for the actual executor surface —
   see `references/potassium-api.md`. Executor capability claims come from there, not from
   guesswork about what a generic executor supports.

## Routing table

Read the reference **before** writing code.

| Task | Reference |
|---|---|
| **Is there a function for X? Does Potassium have Y?** Full documented API surface by library | `references/potassium-api.md` |
| Where am I running? Executor globals, environment, portability, state between runs | `references/executor-environment.md` |
| Luau language, types, task library, style, fast pcall, string interpolation | `references/luau-fundamentals.md` |
| Remotes, fires, `OnClientInvoke`, unreliable remotes, bindables, throttling | `references/client-networking.md` |
| Caching state locally, filesystem, HTTP from the client, secrets | `references/client-persistence-and-secrets.md` |
| Keeping a paid script intact; not tripping anti-cheat; not leaking secrets | `references/script-protection.md` |
| Frame cost, connection leaks, `RunService` choice, object pooling, profiling | `references/client-performance.md` |
| Building UI at runtime: ScreenGui, layouts, tween, UIShadow, StyleQuery | `references/runtime-ui.md` |
| Deprecated APIs, breaking changes, legacy patterns in existing scripts | `references/legacy-and-detections.md` |

For design/taste work on the UI itself, use `roblox-luau-ui-engineering` (and `roblox-luau-ui`);
this skill only carries the engine API facts and the runtime-creation constraints.

## Standards for executor code

These apply to everything written in this context.

1. **Assume the environment is hostile.** The game's own client scripts, other injected
   scripts, and the player may all read your globals, hook your functions, and watch the
   instance tree. Anything you cannot afford to leak does not belong in the script.
2. **Never assume a global exists.** Feature-detect before use, and provide a fallback, e.g.
   the idiom already used in this repo (`Games/HackVaultForBrainrots.lua`):
   ```lua
   local env = getgenv and getgenv() or _G
   ```
   Wrap optional capabilities in `if writefile then ... end`, `if request then ... end`.
3. **Namespace anything you publish.** Shared state belongs under a unique key
   (`getgenv().MyTool = ...`), never in bare `_G` or `shared` with a generic name — other
   scripts in the same client will collide with it.
4. **Fail loudly while developing, quietly in production.** `warn`/`print` a clear prefix
   during work; a released script should not spam a game's console (the 0M3G4 heartbeat is
   silent by design). Never let a `pcall` failure be invisible during development.
5. **Modern library only:** `task.spawn` / `task.wait` / `task.delay` / `task.cancel`, never
   `spawn` / `wait` / `delay`. See `references/legacy-and-detections.md`.
6. **Disconnect what you connect, destroy what you create.** Every `RBXScriptConnection`,
   thread, and instance your script creates needs a teardown path — an unload function that
   cancels threads, disconnects, and destroys the GUI. Leaks are both a frame cost and a
   detection surface.
7. **Do not break the game you are in.** Do not touch other players' data, do not parent
   instances into the game's containers under names that can collide, and do not hook the
   game's internals unless the feature requires it (`references/script-protection.md`).
8. **Type annotations where they pay.** `--!strict` buys nothing in a chunk that is never
   analyzed; annotations still help in multi-file bundles. See `references/luau-fundamentals.md`.
9. **One concern per script.** If a feature grows past a few hundred lines, split it into
   modules in source and concatenate/bundle for dispatch — do not hand-maintain a monolith.

## Verification — mandatory, not optional

A script is proven when **its own printed value comes back from a real client's console**.
Reading source is not verification; a dispatch response is not verification.

- Load `potassium-script-testing` and use the Potassium MCP loop (`list_clients` →
  `execute_script` → `read_console`) — it runs real Luau on the connected clients.
- Features that cannot be exercised headlessly (a GUI's look, a click flow, icon loading)
  are verified by the UI Lab harness pattern; see `roblox-ui-lab` and
  `roblox-luau-ui-engineering`.
- Performance claims are verified in a client, never estimated. The measurement protocol
  (burn ~0.4 s of `os.clock()` per workload, report ns/iter, never compare in-client numbers
  against CLI numbers) is documented in `potassium-script-testing`.

## Marvin's workflow rules (this repo)

- **Never edit working scripts in place.** Iterate in `! scripts/0M3G4/UI Lab/`; the Key
  System console is the one exception that is edited in place.
- After fixing a client/worker script (Neighbors, KeySystem, Guard, worker.js), run
  `! scripts/0M3G4/build_and_deploy_all.bat` and hand back the obfuscated loadstring.
  Generator/console-only changes need no pipeline — give the file path or the console URL.
- Commit per working change, Conventional Commits, no pushing unless asked.
- Secrets live in the gitignored `.env`; nothing secret goes into a script that runs on a
  player's machine (see `references/script-protection.md`).

## API lookup when the answer is not here

Executor environments differ from the documented client API surface, so check in this order:

1. `references/potassium-api.md` — the documented Potassium surface, grouped by library.
2. The **executor's own docs** when you need an exact signature or example:
   `https://docs.potassium.pro/api-reference/<Library Name>/<function>.md` (index:
   `https://docs.potassium.pro/llms.txt`). Page names use spaces (`Signal Library`).
3. **The environment you are actually in** — probe it rather than recall it:
   ```lua
   print(identifyexecutor and identifyexecutor())
   print(type(hookfunction), type(gethui), type(request), type(writefile))
   ```
4. Roblox's own docs, in markdown, per page:
   `https://create.roblox.com/docs/en-us/{path}.md`, index at
   `https://create.roblox.com/docs/llms.txt`. Useful when you must know the exact
   signature/behaviour of an engine API the client does expose.
5. `https://robloxapi.github.io/ref/class/<ClassName>.html` — per-member deprecation status.
6. If it is still unclear, say so and ask; do not invent an API.

The engine version moves roughly weekly. Do not quote a version from this skill as today's;
re-derive it if a version matters:

```bash
curl -s "https://clientsettings.roblox.com/v2/client-version/WindowsStudio64"
curl -s "https://api.github.com/repos/luau-lang/luau/releases?per_page=1" | grep tag_name
```

## Keeping this current

The upstream knowledge base refreshes on its own schedule and marks engine/Luau versions per
reference. When a reference here looks stale against a real failure, fix the reference in
place (`skill_manage`), record what proved it wrong, and re-sync upstream before trusting it
again. `/roblox-update` is **not** a command anywhere — it was a trigger phrase in the
upstream README, and nothing here listens for it.
