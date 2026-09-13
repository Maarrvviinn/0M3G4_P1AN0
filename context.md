Objective
- Build a Spotify-style, self-hosted Roblox piano autoplayer ("0M3G4 P1AN0") that uses no hellohellohell0.com dependency, with working settings/persistence, Lucide icons, autoplay-off-by-default, optional song caching, and bug fixes (playback dead, list hover spacer, settings panel grey, top-right button backgrounds).
Important Details
- Repo (write target): C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4\Games\P1AN0 -> https://github.com/Maarrvviinn/0M3G4_P1AN0 (branch main). Has loader.lua, engine.lua, ui.lua, icons.lua, catalog.json, songs/ (650 files), .gitattributes (* -text), deploy.bat.
- gh is authed as Maarrvviinn (scopes: gist, repo, workflow). Push via git -C <repo> -c 'credential.helper=!gh auth git-credential' push, or double click deploy.bat.
- Direct entry loadstring: loadstring(game:HttpGet("https://raw.githubusercontent.com/Maarrvviinn/0M3G4_P1AN0/main/loader.lua", true))()
- Git user: Marvin / 79109358+Maarrvviinn@users.noreply.github.com; core.autocrlf=true (hence .gitattributes * -text to preserve exact bytes; catalog sha256 verified against pushed content).
- Executor file paths are workspace-relative: 0M3G4/P1ANO/settings.json and 0M3G4/P1ANO/cached songs/<file> map to the user's requested C:\Users\marvi\AppData\Local\Potassium\workspace\0M3G4\P1ANO\....
- Works on this executor via PlayerGui (source: user's Neighbors project src\08_UI_Build.lua uses PlayerGui, ResetOnSpawn=false, IgnoreGuiInset=true, DisplayOrder=2147483000, ZIndexBehavior=Global). gethui() returned RobloxGui (didn't render); CoreGui now used only as fallback.
- Song scripts run via globals set by engine: keypress(keys,beats,bpm), rest(beats,bpm), adjustVelocity(v), pedalDown/Up, keysequence16, finishedSong; also globals bpm and x (x is a short-note sentinel string like "hi"; numeric beats = long note). Songs are plaintext MIDI2LUA output. var=true entries are variants.
- 650 songs live (656 unique recovered from 1045-commit history; 5 dead: ROMANTIC_HOMICIDE, HERE_WITH, SKY_FULL_OF_STARS, SYMPHONY__NO5, THE_LEGENDS). Songs stream from live SONGS/<url> and were committed to the repo.
- Original keysystem is client-side inside the obfuscated MAIN.lua (Luraph v14.8); bypass = use public key-free GitHub source. Original logger.lua webhook (webhook-api-six.vercel.app) removed; loader also blocks request/http_request/http.request/syn.request to webhook/discord.com/api.
- Original settings to keep + wire: secondaryloader(->precise timing), disablefeaturedsongs, mutesfx, disablenotifs, alwaysshowmidispoofer (show MIDI pill if set OR game.PlaceId == 10888259502 Piano Rooms), disableaccidents. New settings: autoplay (default false = select loads+pauses), cachesongs (default false), minimizeKeybind (custom keybind capture).
- Lucide integration pattern from Neighbors src\03_Icons.lua: loadstring(game:HttpGet("https://github.com/latte-soft/lucide-roblox/releases/download/0.1.3/lucide-roblox.luau"))(), Lucide.GetAsset(name,48) returns {Url,ImageRectSize,ImageRectOffset}; sprite fallback table for offline.
- UI must stay Spotify-style (user approved current look, wants further polish). Do NOT copy the Neighbors UI style (user finds it ugly).
- Pinned entry file: C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4 P1AN0.lua (points to main/loader.lua).
- Automated deployment tool: C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4\Games\P1AN0\deploy.bat.
Work State
Completed
- Cloned + populated repo; 650 songs in songs/<url>.lua; catalog.json (version, generated, count, 24 categories, per-song {name,file,bpm,cat[],alts[],size,sha256,sha}); verified live via main branch.
- Delivered no-key build earlier (TALENTLESS_NOKEY.lua self-contained, MAIN_full.lua).
- Direct loader setup: removed commit-hash pinning (REV) from loader.lua and entry scripts, switched directly to raw.githubusercontent.com/Maarrvviinn/0M3G4_P1AN0/main/loader.lua.
- Created one-click deployment batch script `deploy.bat` to stage, commit, and push updates seamlessly to GitHub.
- Full song library audit completed:
  - Fixed 109 songs with missing/empty genre categories.
  - Enriched 183 songs that had missing or empty artist / alternative search tags.
  - Replaced misplaced genre tags in the artist slot with real composers/producers.
  - Fixed raw underscore titles and prominent typos in classic titles.
  - Removed inappropriate keywords and slurs from metadata.
  - Upgraded Now Playing subtitle to cleanly render `Artist · Genre · BPM`.
Active
- Direct entry loadstring configured in `! scripts\0M3G4 P1AN0.lua`.
- Ready for one-click updates via `deploy.bat`.
Blocked
- None.
Relevant Files
- C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4\Games\P1AN0\{loader.lua,engine.lua,ui.lua,icons.lua,catalog.json,.gitattributes,deploy.bat} - repo.
- C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4\Games\P1AN0\songs\<url>.lua - 650 song scripts.
- C:\Users\marvi\Documents\ANTIAV\Roblox\! scripts\0M3G4 P1AN0.lua - pinned direct entry loadstring.
- C:\Users\marvi\AppData\Local\Potassium\workspace\0M3G4\P1ANO\{settings.json,cached songs} - runtime settings/cache (executor-relative paths).
