---
name: roblox-luau-ui
description: "Use when building or restyling Roblox Luau UI."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [windows, macos, linux]
metadata:
  hermes:
    tags: [roblox, luau, ui, headless-verification, performance, design]
    related_skills: [frontend-ui-redesign, luau-obfuscator-vm-debug, generated-code-differential-testing]
---

# Roblox Luau UI

Building, restyling and verifying interfaces for Roblox executor scripts: single-file Luau run by
`loadstring`, or modules inside a repo that is concatenated into one bundle.

## When to use

- "build me a player list / hub UI", "restyle this UI", "make it look modern / mac / less
  AI-generated".
- The user pastes a screenshot of their in-game UI (good or broken) and asks what to improve.
- Adding UI to an existing Roblox repo (see `references/st4lk3r-repo.md` for that repo's build).
- Any "the UI renders as a grey box" / "column is missing" / "clicking does nothing" report.

## Ground rules

- **Audit the cause, never the symptom.** Screenshot symptoms map to mechanisms: a grey box with a
  stray element = an exception mid-`build()`; text missing inside an opaque panel = ZIndex; one
  column missing = clipping; a click doing nothing = a nil global or an unwired signal.
- **Verify headless before handing over.** You cannot run Roblox, so build the stub harness below
  and *execute* the UI. Shipping unrun Luau is how illegal-property and nil-call crashes reach the
  user's client.
- **No runtime HTTP.** Never `loadstring(game:HttpGet(...))` a library at runtime (remote code in
  every user's client, dead URLs, blocked executors). Vendor tables/assets into the file.
- **Keep the user's real structure when restyling.** Read the existing script's grouping logic
  before redesigning: flattening a grouped list is a regression the user reports as "the whole
  category is missing".
- **Restyle his files; a standalone build is only a design lab.** The behaviour he judges (does the
  button actually do the thing) lives in his script — remotes, queue re-join, voice, profile fetch.
  A UI outside it can at best return `true` and toast, which he reports as "the logic doesn't work".
  Prove the design in a lab if that helps, then port it into his scripts keeping every element name
  and call site; if the UI must stay external, publish a bridge
  (`references/st4lk3r-repo.md`) plus hooks and say plainly which actions need his API.
- **Ask which structure to keep before porting.** Card layout vs dense rows is his call and it changes
  the whole job — one question beats re-skinning the wrong information architecture.
- **Port file by file and verify each.** Re-skin one builder at a time (group headers → cards →
  chrome), compile and rebuild after each, and name the parts still original instead of half-applying
  a palette across a multi-thousand-line file. State the remaining work as the next bounded slice.
- Write in English, tabs, `local` upvalues for services, guarded writes (below) on every hot path.

## Procedure

### 1. Audit before designing

1. Load the skill `frontend-ui-redesign` for the design doctrine and anti-slop vocabulary
   (web-scoped, but the audit register transfers).
2. Zoom the screenshot in regions (`vision_analyze` with `region=`) — header/toolbar, one row, the
   bottom panel. Whole-frame reads miss 1px hairlines, clipped text and wrong glyphs.
3. Produce a **defect → mechanism → fix** table before editing anything. Every visible defect has a
   mechanism; an unnamed one will come back.

### 2. Design tokens first

One table of tokens (surfaces, 3-4 text levels, one accent, radii, 4px spacing scale, motion
vocabulary, elevation presets) and build every element through helpers that read it. Consistency is
what reads as "designed"; features are not. See "Design rules" below for the user's taste.

### 3. Build / restyle

Keep the architecture that survives refresh: static chrome and frequently-updated content in
**separate ScreenGuis**, rows pooled by entity, one shared tooltip, event-driven updates plus a
throttled tick. Details and numbers: "Performance rules".

### 4. Verify headless (the stub harness)

The recipe, the stub's design and every gotcha: `references/luau-stub-harness.md`. Minimum loop:

```bash
# stock Luau CLI (binaries also on PATH or a project bin/ dir; override with LUAU_BIN)
mkdir -p "$LOCALAPPDATA/Temp/luau" && cd "$LOCALAPPDATA/Temp/luau"
curl -sL -o luau.zip https://github.com/luau-lang/luau/releases/latest/download/luau-windows.zip
unzip -o luau.zip            # luau.exe, luau-compile.exe, luau-analyze.exe

# concatenate stub + script + test into ONE chunk and run it
cat _harness/stub.luau Script.lua _harness/test.luau > _harness/.run.luau
cd _harness && "$LUAU" ".run.luau"      # relative path: MSYS paths are not translated for native exes

# syntax/compile check anything you edited (see the BOM note in the harness reference)
"$LUAU_COMPILE" --binary Script.lua > /dev/null && echo compiles
```

`templates/luau-ui-run.sh` is the runner to copy into a project. A working reference
implementation (stub + runner + per-script suites) lives in the user's repo at
`<Roblox>/! scripts/0M3G4/UI Lab/_harness/` — copy it as the starting point instead of rewriting.

### 5. Hand over with hooks, not mocks

Expose a test/integration API (`API.integrate({ onFollow = ..., onInfo = ... })`) whose **hook names
match the user's real functions**, so wiring is one line. Where a feature depends on game-specific
remotes or voice APIs you cannot see, implement the portable half and let the hook override it, and
say plainly in the UI which action needs the game's API — never fake success.

## Pitfalls that cost real round-trips

Lua scoping and engine rules that produce silent, in-game-only failures:

- **Forward-declare before wiring handlers.** A closure created before a `local function` is defined
  binds that name to a nil *global*. Symptom: everything works at boot, and clicking a row throws
  "attempt to call a nil value". Declare `local renderList, renderInspector` above any code that
  wires callbacks, then define with `function renderList(...)`. This is the most repeated bug in
  Roblox UI code — check it in every new file.
- **Never write custom fields to an Instance** (`frame.__meta = {}`, `label.Side = nil`): Roblox
  rejects unknown members, and the error aborts the rest of `build()` (grey box). Keep per-instance
  state in a side table keyed by the instance.
- **Don't set `ZIndexBehavior.Global` casually.** With it, a child at the default `ZIndex = 1` is
  painted *under* an opaque parent frame — invisible titles/headers. Leave the default Sibling
  behaviour and have the label helper set `parent.ZIndex + 1`.
- **`ClipsDescendants` silently eats right-aligned columns.** A label at `UDim2.new(1, -16, ...)`
  with width 56 inside a 437px viewport extends past the clip. Compute offsets from the real row
  width and re-check every column.
- **Never animate children of a `UIListLayout`** (`Position`/`Size` re-layouts every frame), and
  never place an animated indicator inside the layout at all — a layout repositions every child.
  Make it a sibling and position it manually.
- **An icon drawn off-centre in its button** = `AnchorPoint` set without `Position`: the image
  defaults to `(0, 0)`, so with a `0.5, 0.5` anchor it renders at the button's *top-left corner*.
  Set both, and give the icon helper a centred default so no call site can forget.
- **A game timestamp on the wrong clock scale** (treating `os.clock()`-scale `MatchStart` as Unix ms)
  shows up as an absurd timer. Copy the script's own time helpers instead of re-deriving them — full
  recipe in `references/roblox-ui-engine-notes.md`.
- **A collapsed group/place list** means string surgery on the grouping key. Group on the raw
  attribute value (`Place12`), never a digit-stripped version.
- **Avatars:** set the userId field *before* requesting the thumbnail — on a warm cache the callback
  fires synchronously and a later assignment makes the guard reject its own result
  (`references/roblox-ui-engine-notes.md` has the full API).
- **Fonts:** legacy `Enum.Font.*` always resolves; a `FontFace` built from a family path can render
  nothing when that family/weight is unavailable (looks like "my title text vanished"). Use
  `Font.fromEnum`, or `Font.new` only with a family you have seen render. And note that the
  fallback idiom `Enum.Font.RobotoMono or Enum.Font.Code` never works: indexing a member that does
  not exist **throws**, and the throw lands mid-`build()` (symptom: grey box). Resolve enum members
  through `pcall` and keep a known-good default.
- **Icon sprite rects can't be verified from outside Roblox** (asset delivery requires auth) and a
  wrong rect renders as a solid white square. Ship only coordinates confirmed rendering in-game,
  prefer a sheet the user uploaded, and keep a text/monogram fallback so a bad rect degrades.
- **Legacy `wait()`/`spawn()`** do not exist as the user writes them — use `task.wait`/`task.spawn`.

## Performance rules (the mechanism, then the rules)

Roblox caches a Gui's rendered appearance and recomputes it when **any descendant property
changes** — and one change invalidates the **entire ScreenGui**. So:

- Route every hot write through a guard: `set(inst, prop, v)` → `if inst[prop] == v then return end`.
- Split static chrome and frequently-updated content into two ScreenGuis; mirror the window position
  with a single write so the dynamic half follows a drag.
- Pool rows in a table keyed by entity; reuse via `Visible`, destroy only when the entity leaves.
- Cache tweens per `(instance, property, target value)` — a Tween is replayable; never
  `TweenService:Create` on hover.
- One shared tooltip instance; no per-element tooltips.
- No per-frame loops: event-driven plus a throttled tick (0.25s is enough for a list). Springs, if
  used, run from one RenderStepped connection that disconnects itself when everything settles.
- Profile with `debug.profilebegin/profileend` behind a flag; `--!native` and Parallel Luau are
  Studio/published-place features and are **not** available to executor scripts.
- Benchmarks: count *write attempts*, not effective changes (after the first render nothing changes
  value, so both paths read ~0 and look identical).

## Design rules for this user

- Dark, dense tool surfaces. The "AI-made" look to avoid: indigo/violet accent on navy, emoji in
  labels, equal-weight icon cards, decorative gradients everywhere, uniform visible borders.
- Hairline separators (1px, 85-93% transparent) instead of borders; **one** accent used only for
  state (selection, active item); 3-4 text levels (100% / 60% / 45% white); 4px spacing grid; two
  font weights and 3-4 sizes; icons at integer sizes (16/24 from a 48px sheet).
- macOS flavour when asked: traffic-light buttons wired to real actions, centred title bar, Finder/
  Mail source list with coloured tag dots and live counts, inset accent-rounded list selection,
  "Get Info" inspector panel, system palette (`#0A84FF`, `#FF5F57`/`#FEBC2E`/`#28C840`, `#38383A`).
- Preserve the real structure: group/place headers with counts and live match timers, then state
  sections. Avatars in a player list are a hard requirement — monograms are a loading fallback only.
- Persist favourites/ignored into the **same settings file the main script uses**, read-merge-write
  so the other keys survive.
- Answer a screenshot report with an audit table, then state plainly which parts are proven by the
  headless run and which are untested in Roblox.

## Support files

- `references/luau-stub-harness.md` — how to build the Roblox-API stub, the runner, the counters,
  and the stub-specific gotchas (`_G` readonly, metamethods, self-referential tables, whitelist).
- `references/roblox-ui-engine-notes.md` — engine behaviour worth knowing before designing:
  appearance caching, UIShadow/per-corner UICorner, BlurEffect's limit, avatars, sprite sheets.
- `references/st4lk3r-repo.md` — the user's Roblox repo: build pipeline, version/chunk-local rules,
  where UI lives, which `Methods.*`/helpers to wire hooks to.
- `templates/luau-ui-run.sh` — copyable test runner (stub + script + test → one chunk).
