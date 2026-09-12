-- 0M3G4 P1AN0 || loader.lua
-- Entry point. Fetches the catalogue + engine + UI from the GitHub repo and runs.
-- Nothing here touches the old hellohellohell0.com host.

local HOSTS = {
    "https://raw.githubusercontent.com/Maarrvviinn/0M3G4_P1AN0/main/",
    "https://cdn.jsdelivr.net/gh/Maarrvviinn/0M3G4_P1AN0@main/",
}

local function httpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if ok and type(body) == "string" and #body > 0 then return body end
    return nil
end

local function fetchFile(name)
    local lastErr = "no host reachable"
    for _, base in ipairs(HOSTS) do
        local body = httpGet(base .. name)
        if body then
            return body, base
        end
        lastErr = base
    end
    return nil, lastErr
end

local catalogSrc, host = fetchFile("catalog.json")
if not catalogSrc then
    error("[P1AN0] could not download catalog.json (" .. tostring(host) .. ")")
end

local HttpService = game:GetService("HttpService")
local ok, catalog = pcall(function() return HttpService:JSONDecode(catalogSrc) end)
if not ok or type(catalog) ~= "table" or not catalog.songs then
    error("[P1AN0] catalog.json is invalid")
end

local engineSrc = fetchFile("engine.lua")
if not engineSrc then
    error("[P1AN0] could not download engine.lua")
end

local uiSrc = fetchFile("ui.lua")
if not uiSrc then
    error("[P1AN0] could not download ui.lua")
end

local engineFactory, eerr = loadstring(engineSrc, "P1AN0_ENGINE")
if not engineFactory then
    error("[P1AN0] engine failed to compile: " .. tostring(eerr))
end
local Engine = engineFactory()

local uiFactory, uerr = loadstring(uiSrc, "P1AN0_UI")
if not uiFactory then
    error("[P1AN0] ui failed to compile: " .. tostring(uerr))
end
uiFactory(Engine, catalog, host)
