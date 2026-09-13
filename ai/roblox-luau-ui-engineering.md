---
name: roblox-luau-ui-engineering
description: "Design, build, and optimise Roblox/Luau UI."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [windows, linux, macos]
metadata:
  hermes:
    tags:
      [
        roblox,
        luau,
        ui,
        performance,
        executor,
        lucide,
        headless-testing,
        design-tokens,
      ]
    related_skills:
      [luau-obfuscator-vm-debug, frontend-ui-redesign, systematic-debugging]
---

# Building and optimising Roblox / Luau UI

Use when the task is to build, restyle, or perf-tune Roblox UI: executor hub windows,
key systems, player lists, ESP overlays, game GUIs. Covers the always-on design and
performance rules, the single-file (loadstring) delivery constraints, and how to
actually verify Luau UI when the Roblox engine is not available.

## Where his Roblox work lives

`~/Documents/ANTIAV/Roblox/` — `! scripts/0M3G4` (Key System + Cloudflare Worker, `Games/<Game>/`,
`Tools/`), `LUAU Obfuscator`, `Potassium`. Modular game projects keep `src/NN_*.lua` files that a
build script concatenates into a single `dist/<Name>.lua` loadstring script. `! scripts/0M3G4/UI Lab/`
holds the standalone test builds (`CleanList_v1.lua`, `LiquidGlass_v1.lua`) together with the reusable
`_harness/` (stub + runner + per-UI test files) — read those before writing a new stub from scratch.

**Read the project's own rule file before editing** — `Games/Neighbors/.ai/context.md` (and the
matching `docs/*_PROJECT_CONTEXT.md`) carries MANDATORY conventions: bump `CFG.VERSION` with every
change, edit only `src/` (never `dist/` or the root bundle by hand), rebuild with
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1`, introduce **no new top-level
chunk locals** (attach to `State` / `Storage` / `UI` / `Methods` — the concatenated chunk has a hard
local limit), and use Conventional Commits.

Two build-pipeline quirks that look like failures and are not:

- The build **prepends `Key System/Guard/0M3G4_Guard.luau`** to every bundle. A "no Guard" test build
  is therefore impossible via the normal build — make it a standalone file instead, and do not be
  surprised by Guard code in `dist/`.
- `luau-compile` on a built `dist/*.lua` reports `Unicode character U+FEFF` on line 1 because the Guard
  file starts with a BOM. Strip byte 1 (`tail -c +4 dist/x.lua > x-check.lua`) before believing a
  syntax error from the bundle.

## Verify before you ship (there is no Roblox engine here)

Never hand over unrun Luau UI. Concatenate a Roblox API stub + the script under test + an assertion
file and run it under the stock `luau` CLI:

```bash
bash _harness/run.sh MyUI_v1.lua test_myui.luau      # cat stub + target + test > .run.luau; luau.exe .run.luau
```

Start from `templates/roblox-stub.luau` and `scripts/run-ui-test.sh`; `references/headless-harness.md`
has the design notes and the traps that cost real time (read it before writing a new stub).

The gate before reporting done — all four, every time:

1. The stub **rejects writes to members that do not exist on that class**, in the engine's own wording
   (`"Side is not a valid member of ImageLabel"`). A permissive stub is worse than no stub: an illegal
   write aborts `build()` half way and the user sees a bare grey box with nothing to go on. Derive the
   whitelist from the stub's own defaults table so the two cannot drift, and extend it when the UI
   legitimately grows.
2. The UI mounts, pools rows, filters/searches/sorts, dispatches actions, and tears down with
   **0 harness errors**.
3. The **interaction sweep** passes: fire every signal on every instance (`MouseEnter`, `MouseLeave`,
   `InputBegan` with a `MouseButton1` table, `Focused`, `FocusLost`, `Activated`) plus the global input
   paths (drag `InputChanged`/`InputEnded`, the toggle key) and the player events. Boot-time assertions
   never reach those handlers, and that is exactly where the nil-call and illegal-write bugs hide.
4. The write-count A/B shows the guarded path doing strictly less work.

Compile-verified is not done — run it. When the user reports a runtime error or a visually broken
build, **make the harness reproduce that exact error first** (tighten the stub until it prints the same
message), then fix it; that is how the rest of the same bug class surfaces in one pass instead of three
round trips.

Traps that cost real time when the code under test is a _component_ rather than a whole UI:

- **`luau.exe` has no `io` library and freezes `_G`.** A harness cannot `io.open()` the target, and
  `rawset(_G, ...)` throws `attempt to modify a readonly table`. Inline the target at build time
  (a small Python assembler that swaps a `@@@SOURCE@@@` placeholder for a long-bracket literal,
  escalating the bracket level until the delimiter is absent from the source), then give each case
  its own environment: `local fn = loadstring(SRC); setfenv(fn, setmetatable({ KEY = value }, { __index = getfenv(0) }))`.
  That mirrors what a real envelope does with `rawset(_G, ...)`.
- **`luau.exe a.luau b.luau` runs _both_ files**, so `arg[1]`-style path passing is unreliable — a
  second "script" argument executes standalone and dies on the first nil global.
- **Stub the escape hatches, not just the API.** Give the stub `game.HttpGet` returning a plausible
  JSON body, otherwise every watchdog path aborts and the run looks like a pass/fail artefact of the
  harness. And when a termination path ends in `while true do task.wait(999999) end`, make the stub's
  `task.wait` throw after N calls so the hang is observable as "halted" instead of a timeout.
- **To audit a Cloudflare Worker/HTTP backend without deploying it:** copy `worker.js` to a `.mjs`
  in a temp dir (a repo file with no `package.json` cannot be imported as ESM), `await import()` it,
  and pass an instrumented in-memory `Map` as `env.KEYS_KV` plus `ctx = { waitUntil() {} }`. Count
  `get`/`put`/`list` calls in the stub to expose per-request KV cost, and honour KV's real 1,000-key
  `list()` page so silent truncation shows up as a count mismatch.
- **When the browser backend is cloud-side, `file://` proofs are impossible** (the tool times out).
  For DOM injection claims use `npm i jsdom` locally and run the target's own template string
  verbatim in a real DOM; state plainly that jsdom does not execute inline event handlers, so the
  proof covers markup injection and attribute break-out, not live script execution.

For code that cannot be stubbed (the full engine surface of a 6k-line game script), say so explicitly
and fall back to per-file `luau-compile --binary` syntax checks. For what a stub structurally cannot see
— real rendering, engine-only APIs, how it actually looks in his client — hand it to the real-client
route described in `potassium-script-testing`, and say which tier proved what.

## Performance rules (always on)

1. **Guard every write on a hot path** — `if inst[prop] ~= v then inst[prop] = v end` (or a
   `Methods.set` helper). WHY: any property change on a Gui descendant invalidates that ScreenGui's
   cached appearance, so one changed label re-renders the whole Gui next frame; with the guard a
   no-op refresh costs zero writes instead of hundreds.
2. **Split static chrome from frequently-updated content into separate ScreenGuis.** If the panel is
   draggable, mirror its `Position` onto the dynamic Gui's root inside the same drag handler (one
   write per drag frame). Prove it: count writes per instance and assert a refresh writes **0**
   properties into the chrome Gui.
3. **Pool repeated subtrees.** Rows/cards/toasts are created once and reused via `Visible`; never
   create+destroy per refresh. When you must create, build one template and `:Clone()` it, and set
   `Parent` last. Same for `Highlight`/adornment pools in ESP — churning instances shows up as GC
   pressure and renderer rebuilds.
4. **Cache lookups.** Hoist services to file-scope locals, store built elements in a table at build
   time, and never call `FindFirstChild` / `WaitForChild` / `game:GetService` inside a per-frame or
   per-player-per-refresh loop. `:GetDescendants()` is the worst lookup in the API — keep it out of
   hot paths entirely.
5. **Cache tweens.** A Tween is replayable, so create one per `(instance, property, target value)`
   and `:Play()` it again. Key the cache by the **target value**, not just the property — otherwise the
   first target you played sticks forever and leave-hovers animate to the wrong colour.
6. **Never animate `Position`/`Size` of elements inside a `UIListLayout`** — it forces a relayout every
   frame. Animate `UIScale`/`GroupTransparency`, or animate a `Position` element that sits outside the
   layout. The same holds at build time: a layout repositions _every child frame_, so a traveling pill or
   selection indicator must be parented as a **sibling** (a child of the layout's parent) and positioned
   from the layout's offset, or the layout silently wins and the animation never appears.
7. **Springs and animations must self-disconnect.** Drive them from one `RenderStepped` connection
   that removes settled items and disconnects when the list empties — a still UI must cost zero
   per-frame work. Do not restart a spring whose target is unchanged (a refresh would spin it up for
   nothing).
8. **Instrument before optimising**: `debug.profilebegin`/`profileend` scopes behind a `CFG.PROFILE`
   flag around refresh/render, `os.clock()` deltas for before/after. `--!native` and Parallel Luau are
   Studio/published-place features — never plan around them in executor scripts.
9. **Never `:Connect` from inside a refresh.** Tooltip/hover helpers that attach a handler per call
   leak a connection (and multiply handlers) on every refresh — attach once, memoised on the payload
   that selects the handler text.
10. **Taper the expensive visuals**: no `CanvasGroup` unless you actually need `GroupTransparency` or
    rotated clipping (it costs memory and render time); keep `Highlight` transparency static; skip
    drawing for anything off-screen via `WorldToViewportPoint` before anything else; throttle ESP to
    ~20Hz — only camera interpolation needs `RenderStepped`.

## Visual rules (his taste — "not that AI-made looking")

The tells to avoid: navy/indigo-violet accent, uniform 8px radius on everything, full-width pill
buttons as navigation, border transparency around 0.35 (reads as a hard 2010 web border), emoji as
UI icons, decorative gradients, a centred bold title, and large empty padding.

Do instead:

- **Neutral surface ramp** — a near-black warm graphite base with 2-3 steps of elevation, not navy.
  One restrained accent used only for state (selection, active tab, focus).
- **1px hairlines at 0.88-0.94 transparency** as separators instead of visible borders.
- **A real type scale** — e.g. 9 caps / 10-11 secondary / 12 body / 13 title / 20 display, two weights,
  set through `FontFace` (`Enum.Font.Gotham*` is the legacy path; use
  `Font.new("rbxasset://fonts/families/<Family>.json", Enum.FontWeight.Medium)` with a `Font.fromEnum`
  fallback wrapped in `pcall`).
- **Density and alignment** — 28-32px rows, monogram avatars instead of network thumbnails, right-aligned
  tabular numbers, a 5-6px state dot instead of coloured pills.
- **One motion vocabulary** — hover 120-160ms, panel 220-260ms, a single easing curve reused everywhere.
- **Native primitives** — `UIShadow` for elevation and glow, per-corner `UICorner` radii. Details,
  property lists and the glass recipe: `references/visual-playbook.md`.
- **Vendor your icons.** Render the sprite table at whole-pixel even divisors of the source sheet
  (16/24 out of 48px), tint with `ImageColor3`, use `ImageTransparency` for disabled states. Never
  invent asset ids or sprite coordinates — copy them from the user's existing table.
- Roblox **cannot** blur UI behind UI: `BlurEffect` is a Lighting post-process for the 3D world. Say so
  instead of implying real glass; simulate frosted/liquid glass with layered translucent fills, gradient
  edge lighting, a pointer-tracking specular highlight and springs.

## Security and hygiene (state plainly, up front)

- **No runtime `loadstring(game:HttpGet(...))()`**, including for icons. It is remote code execution in
  every user's client, a blocking fetch on the first-paint path, and a dependency on a URL you do not
  control. Check whether the upstream repo is archived and report it as unmaintained; vendor the table
  into the file. Lead the reply with this class of finding rather than burying it.
- Keep secrets out of source files; never commit them.

## Shape of the deliverable he expects

- **Build alternatives as new standalone scripts, never rewrite the working UI in place.** He keeps a
  working-but-disliked UI live; the replacement arrives beside it so he can compare.
- **Keep the current interaction model.** Search, filter, select a row, act on the selection, a
  persistent info surface on screen. He asked for a cleaner list that still _is_ a list and works the
  way the current one does — restyle the presentation, do not invent a new workflow.
- Each new UI is single-file, self-contained (no Guard, no HTTP, no external assets), and ends with an
  exported API table (`_G.UILAB_*` plus an env-local mirror, see the harness reference) exposing:
  `refresh`, `select`, `setFilter`, `setSearch`, `setSort`, integration hooks
  (`integrate{ onInfo, onFollow, ... }`), `rawWrites(bool)` for benchmarking, `stats`, `destroy`.
- **Demo-data fallback when the server is empty** so the design can be judged immediately, with the
  inspector labelling `demo` vs `live`.
- Report **measured numbers** (write attempts guarded vs unguarded, instances created, frames to
  settle) and be explicit about **what you did not apply and why** — he asks for the changes that are
  genuinely recommended, and wants the ones you would not recommend named rather than silently applied.

## Pitfalls

- Writing the same value to a property still costs a bridge call and dirties dependent systems; only the
  guard makes it free. Do not "optimise" by removing the format/compare and keeping the write.
- `AutomaticSize`/`AutomaticCanvasSize` are useful, but re-setting them per refresh is a layout write —
  guard them like any other property.
- A header/toolbar label positioned with `UDim2.new(1, -offset, ...)` inside a row is offset from the
  **row** width, not the window width; recompute offsets against the parent you actually parent into or
  the right-hand columns overflow the panel.
- Sprite-sheet icons scaled to odd sizes look blurry; use whole-pixel, even-divisor sizes and never
  nudge an icon between states with `Position` math — swap it into a fixed-size holder instead.
- Off-the-shelf declarative UI layers (React-Luau / roact-alignment and friends) are a Rojo +
  Wally/rotriever multi-module build and a rendering layer, not a design system: wrong tool for a
  single-file executor script, and no visual gain. Decide by inspecting the dependency tree, e.g.
  `curl -s https://api.wally.run/v1/package-metadata/<scope>/<pkg>` — if it pulls a reconciler, a
  scheduler and a polyfill, the bundle is ~a dozen modules.
- **Never store custom fields on an Instance** (`frame.__meta = {}`, `img.__gradient`). Roblox rejects
  them — `"__glassStrokes is not a valid member of Frame"` — and one such line aborts the whole build;
  keep metadata in a side table keyed by the instance, or return it from the factory
  (`local frame, gradient = GlassKit.sheen(...)`). The same mistake going unnoticed in the stub is why it
  shipped.
- **Declare a function before the code that wires it.** A handler attached during construction that
  calls a `local function renderX()` defined further down binds to a nil _global_ and throws
  `attempt to call a nil value` — but only on interaction, so every boot-time test passes. Forward
  declare above the wiring (`local renderX, fullRender`) and define them as `function renderX()`, which
  then assigns to those locals instead of creating globals.
- **Apply edits as individual `patch` calls, not one multi-edit `execute_code` batch.** Each patch lands
  on its own, so a batch that is refused or blocked loses nothing and the diff stays reviewable. If a
  call is blocked pending consent, report the state and ask — never re-run it, restate it, or route the
  same edit through another tool.
