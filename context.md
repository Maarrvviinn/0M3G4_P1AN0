Objective
- Build a Spotify-style, self-hosted Roblox piano autoplayer ("0M3G4 P1AN0") that uses no hellohellohell0.com dependency, with working settings/persistence, Lucide icons, autoplay-off-by-default, optional song caching, and bug fixes (playback dead, list hover spacer, settings panel grey, top-right button backgrounds).
Important Details
- Repo (write target): C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4\Games\P1AN0 -> https://github.com/Maarrvviinn/0M3G4_P1AN0 (branch main). Has loader.lua, engine.lua, ui.lua, icons.lua, catalog.json, songs/ (650 files), .gitattributes (* -text).
- gh is authed as Maarrvviinn (scopes: gist, repo, workflow). Push via git -C <repo> -c 'credential.helper=!gh auth git-credential' push.
- Git user: Marvin / 79109358+Maarrvviinn@users.noreply.github.com; core.autocrlf=true (hence .gitattributes * -text to preserve exact bytes; catalog sha256 verified against pushed content).
- Root cause of "nothing renders/runs" (fixed): engine.lua/ui.lua end with return function(...) ... end; loader must call factories twice (chunk()() for engine, chunk()(...) for ui). Commit 2382611 fixed this.
- raw.githubusercontent.com CDN caches main (~5 min), ?v= does NOT bust it. So loader.lua pins sub-fetches to local REV = "<sha>", and hosts = jsDelivr @REV -> raw REV -> raw main. Bump REV whenever engine/ui/icons/catalog change.
- Executor file paths are workspace-relative: 0M3G4/P1ANO/settings.json and 0M3G4/P1ANO/cached songs/<file> map to the user's requested C:\Users\marvi\AppData\Local\Potassium\workspace\0M3G4\P1ANO\....
- Works on this executor via PlayerGui (source: user's Neighbors project src\08_UI_Build.lua uses PlayerGui, ResetOnSpawn=false, IgnoreGuiInset=true, DisplayOrder=2147483000, ZIndexBehavior=Global). gethui() returned RobloxGui (didn't render); CoreGui now used only as fallback.
- Song scripts run via globals set by engine: keypress(keys,beats,bpm), rest(beats,bpm), adjustVelocity(v), pedalDown/Up, keysequence16, finishedSong; also globals bpm and x (x is a short-note sentinel string like "hi"; numeric beats = long note). Songs are plaintext MIDI2LUA output. var=true entries are variants.
- 650 songs live (656 unique recovered from 1045-commit history; 5 dead: ROMANTIC_HOMICIDE, HERE_WITH, SKY_FULL_OF_STARS, SYMPHONY__NO5, THE_LEGENDS). Songs stream from live SONGS/<url> and were committed to the repo.
- Original keysystem is client-side inside the obfuscated MAIN.lua (Luraph v14.8); bypass = use public key-free GitHub source. Original logger.lua webhook (webhook-api-six.vercel.app) removed; loader also blocks request/http_request/http.request/syn.request to webhook/discord.com/api.
- Original settings to keep + wire: secondaryloader(->precise timing), disablefeaturedsongs, mutesfx, disablenotifs, alwaysshowmidispoofer (show MIDI pill if set OR game.PlaceId == 10888259502 Piano Rooms), disableaccidents. New settings: autoplay (default false = select loads+pauses), cachesongs (default false), minimizeKeybind (custom keybind capture).
- Lucide integration pattern from Neighbors src\03_Icons.lua: loadstring(game:HttpGet("https://github.com/latte-soft/lucide-roblox/releases/download/0.1.3/lucide-roblox.luau"))(), Lucide.GetAsset(name,48) returns {Url,ImageRectSize,ImageRectOffset}; sprite fallback table for offline.
- UI must stay Spotify-style (user approved current look, wants further polish). Do NOT copy the Neighbors UI style (user finds it ugly).
- Test tooling in temp: C:\Users\marvi\AppData\Local\Temp\opencode\luau\bin\luau-compile.exe (syntax check), luau.exe (run), talentless-src\ (full clone), generation scripts harvest.py, checklive.js, generate.py, build_loader.py, fetch_songs.js, p1ano\ (loader/engine/ui/icons staging), out\ (build outputs).
- Use Write tool / .NET WriteAllText(..., newline="\n") with UTF-8 no BOM for repo files (PowerShell Set-Content -Encoding utf8 adds BOM -> breaks luau-compile; a BOM round-trip also mojibake'd emoji).
- Pinned entry file: C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4 P1AN0.lua (points at 79dbafe/loader.lua).
Work State
Completed
- Cloned + populated repo; 650 songs in songs/<url>.lua; catalog.json (version, generated, count, 24 categories, per-song {name,file,bpm,cat[],alts[],size,sha256,sha}); verified live via commit-pinned raw.
- Delivered no-key build earlier (TALENTLESS_NOKEY.lua self-contained, MAIN_full.lua) in the session workspace folder ...\workspace\0M3G4\S0URCE D3T3CT0R\2026-09-12\18-04-50_f29436d8\.
- Repo files committed:
  - 4912355 songs+catalog; c5a2d9e .gitattributes * -text; e177ef3 loader/engine/ui v1; f85b552 loader v2 diagnostics; ba42971 parent fix + diag; 74d9934 explicit build diagnostics; 0e956e0 UI parent to PlayerGui; 031d457 REV pinning; 37571e0 strip BOM; 2382611 double-call fix; ed8630b Spotify UI + Lucide + settings + autoplay + cache (engine/ui/icons); 88bfa39 loader REV=ed8630b; 1b56d3a initial fixes; 86adac3 loader REV=1b56d3a; e36857c Spotify UI overhaul; 709604e loader REV=e36857c; 974f022 error toast fix; 3e90474 loader REV=974f022; e46c273 dragging, pause, keybind input, styling; d546950 loader REV=e46c273; cff8bb5 full 650 song library audit (author, genre, title fixes); 79dbafe loader REV=cff8bb5.
- Verified live at 79dbafe / cff8bb5: loader.lua, ui.lua, engine.lua, catalog.json all serve HTTP 200 OK.
- Headless verification: compiled cleanly using luau-compile.
Active
- Pinned entry loadstring updated in `! scripts\0M3G4 P1AN0.lua` to `79dbafe/loader.lua`.
- Full song library audit completed:
  - Fixed 109 songs with missing/empty genre categories.
  - Enriched 183 songs that had missing or empty artist / alternative search tags.
  - Replaced misplaced genre tags in the artist slot with real composers/producers (e.g. Tom Odell for Another Love, Grover Washington Jr. / Bill Withers for Just The Two Of Us, Toby Fox for Undertale/Deltarune, Michael Giacchino for Married Life).
  - Fixed raw underscore titles (e.g. `A_TALE_OF_SIX` -> `A TALE OF SIX TRILLION YEARS AND AN OVERNIGHT STORY`, `AI_SCREAM` -> `AI SCREAM`).
  - Fixed prominent typos in classic titles (`A CRUEL ANGLES THESIS` -> `A CRUEL ANGEL'S THESIS`, `CHHA LA HEAD CHA LA` -> `CHA-LA HEAD-CHA-LA`, `LEVAN POLKKA` -> `IEVAN POLKKA`).
  - Removed inappropriate keywords and slurs from metadata.
  - Upgraded Now Playing subtitle to cleanly render `Artist · Genre · BPM`.
Blocked
- None. Ready for user in-game test.
Relevant Files
- C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4\Games\P1AN0\{loader.lua,engine.lua,ui.lua,icons.lua,catalog.json,.gitattributes} - repo; bump REV in loader when engine/ui/icons/catalog change.
- C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4\Games\P1AN0\songs\<url>.lua - 650 song scripts.
- C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4 P1AN0.lua - pinned entry loadstring the user runs.
- C:\Users\marvi\AppData\Local\Temp\opencode\p1ano\{loader.lua,engine.lua,ui.lua,icons.lua} - staging copies.
- C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4\Games\Neighbors\src\{03_Icons.lua,08_UI_Build.lua,01_Config.lua} - reference for Lucide loading + PlayerGui GUI pattern.
- C:\Users\marvi\AppData\Local\Potassium\workspace\0M3G4\P1ANO\{settings.json,cached songs} - runtime settings/cache (executor-relative paths).
