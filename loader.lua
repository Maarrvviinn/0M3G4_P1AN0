-- 0M3G4 P1AN0 || loader.lua (v2, self-diagnosing)
-- Nothing from the old hellohellohell0.com host is used.

local TAG = "[P1AN0]"
local function log(...)
    local parts = { TAG }
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print(table.concat(parts, " "))
end

-- ----------------------------------------------------------------------
-- HTTP: try every method an executor might expose
-- ----------------------------------------------------------------------
local function tryHttpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if not ok then
        ok, res = pcall(function() return game:HttpGetAsync(url) end)
    end
    if ok then
        if type(res) == "string" then return res end
        if type(res) == "table" and type(res.Body) == "string" then return res.Body end
    end
    return nil
end

local function tryRequest(url)
    local req = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request or http_request
    if type(req) ~= "function" then return nil end
    local ok, res = pcall(req, { Url = url, Method = "GET" })
    if ok and type(res) == "table" then
        if type(res.Body) == "string" then return res.Body end
        if type(res.body) == "string" then return res.body end
    end
    return nil
end

local function httpGet(url)
    local body = tryHttpGet(url)
    if body and #body > 0 then return body end
    body = tryRequest(url)
    if body and #body > 0 then return body end
    return nil
end

-- Pin to the commit that holds the current engine/ui/catalog so the raw CDN
-- can never serve a stale copy. Bump REV whenever those files change.
local REV = "1b56d3a"

local HOSTS = {
    "https://cdn.jsdelivr.net/gh/Maarrvviinn/0M3G4_P1AN0@" .. REV .. "/",
    "https://raw.githubusercontent.com/Maarrvviinn/0M3G4_P1AN0/" .. REV .. "/",
    "https://raw.githubusercontent.com/Maarrvviinn/0M3G4_P1AN0/main/",
}

local function fetchFile(name)
    for _, base in ipairs(HOSTS) do
        log("fetching", base .. name)
        local body = httpGet(base .. name)
        if body then
            log("ok", name, #body, "bytes")
            return body, base
        end
        log("failed", name, "from", base)
    end
    return nil, nil
end

-- ----------------------------------------------------------------------
-- parent resolution (gethui -> CoreGui -> PlayerGui)
-- ----------------------------------------------------------------------
local function resolveParent()
    local candidates = {}
    candidates[#candidates + 1] = function()
        local lp = game:GetService("Players").LocalPlayer
        if not lp then
            repeat task.wait(0.1) until game:GetService("Players").LocalPlayer
            lp = game:GetService("Players").LocalPlayer
        end
        return lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 10)
    end
    candidates[#candidates + 1] = function() return game:GetService("CoreGui") end
    if gethui then
        candidates[#candidates + 1] = function()
            local h = gethui()
            if h and h:IsA("ScreenGui") and h.Name ~= "RobloxGui" then return h end
            return nil
        end
    end
    for _, f in ipairs(candidates) do
        local ok, parent = pcall(f)
        if ok and parent then
            local ok2 = pcall(function()
                local t = Instance.new("ScreenGui")
                t.Parent = parent
                t:Destroy()
            end)
            if ok2 then return parent end
        end
    end
    return nil
end

local parentGui = resolveParent()
log("parent:", parentGui and tostring(parentGui) or "NONE")

-- status toast so "nothing happens" becomes something visible
local statusGui, statusLabel
if parentGui then
    pcall(function()
        statusGui = Instance.new("ScreenGui")
        statusGui.Name = "0M3G4_Status"
        statusGui.ResetOnSpawn = false
        statusGui.IgnoreGuiInset = true
        statusGui.DisplayOrder = 2147483000
        statusGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        statusGui.Parent = parentGui
        statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(0, 420, 0, 34)
        statusLabel.Position = UDim2.new(0.5, -210, 0, 24)
        statusLabel.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
        statusLabel.BorderSizePixel = 0
        statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        statusLabel.TextSize = 14
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.Text = "0M3G4 P1AN0 loading..."
        statusLabel.Parent = statusGui
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = statusLabel
    end)
end

local function setStatus(text, red)
    log("status:", text)
    if statusLabel then
        statusLabel.Text = text
        statusLabel.TextColor3 = red and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255)
    end
end

-- ----------------------------------------------------------------------
-- main
-- ----------------------------------------------------------------------
local function main()
    setStatus("fetching catalogue...")
    local catalogSrc, host = fetchFile("catalog.json")
    if not catalogSrc then
        return false, "could not download catalog.json - does your executor allow game:HttpGet to github?"
    end

    setStatus("parsing catalogue...")
    local HttpService = game:GetService("HttpService")
    local ok, catalog = pcall(function() return HttpService:JSONDecode(catalogSrc) end)
    if not ok or type(catalog) ~= "table" or not catalog.songs then
        return false, "catalog.json invalid: " .. tostring(catalog)
    end
    log("catalogue:", catalog.count or #catalog.songs, "songs")

    local engineSrc = fetchFile("engine.lua")
    if not engineSrc then return false, "could not download engine.lua" end
    local uiSrc = fetchFile("ui.lua")
    if not uiSrc then return false, "could not download ui.lua" end
    local iconsSrc = fetchFile("icons.lua")
    if not iconsSrc then return false, "could not download icons.lua" end

    local compile = loadstring or load
    if type(compile) ~= "function" then return false, "loadstring is not available in this executor" end

    setStatus("building engine...")
    local engineChunk, cerr = compile(engineSrc, "P1AN0_ENGINE")
    if not engineChunk then return false, "engine compile error: " .. tostring(cerr) end
    local engineFactory = engineChunk()
    if type(engineFactory) ~= "function" then return false, "engine.lua did not return a factory" end
    local Engine = engineFactory()
    log("engine ready")

    setStatus("building ui...")
    local uiChunk, uerr = compile(uiSrc, "P1AN0_UI")
    if not uiChunk then return false, "ui compile error: " .. tostring(uerr) end
    local uiFn = uiChunk()
    if type(uiFn) ~= "function" then return false, "ui.lua did not return a factory" end

    local iconsChunk, ierr = compile(iconsSrc, "P1AN0_ICONS")
    if not iconsChunk then return false, "icons compile error: " .. tostring(ierr) end
    local iconsFn = iconsChunk()
    local Icons = type(iconsFn) == "function" and iconsFn() or nil
    log("icons ready:", Icons and tostring(Icons.Lucide ~= nil) or "none")

    uiFn(Engine, catalog, host, parentGui, Icons)
    log("ui ready")

    return true
end

local function handler(e)
    return tostring(e) .. "\n" .. debug.traceback("", 2)
end

local ok, err = xpcall(main, handler)
if ok then
    if statusGui then pcall(function() statusGui:Destroy() end) end
    log("done")
else
    setStatus("ERROR: " .. tostring(err), true)
    log("ERROR", err)
    -- keep the error toast on screen
    if statusGui and statusLabel then pcall(function() statusGui.Name = "0M3G4_Error" end) end
end
