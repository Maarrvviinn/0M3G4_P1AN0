-- 0M3G4 P1AN0 || ui.lua
-- Spotify-inspired single window. Transport, seek, BPM, error margin, MIDI and
-- settings (incl. autoplay + "cache songs") all live inside the window.

return function(Engine, catalog, host, inheritedParent, Icons)
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")
    local UIS = game:GetService("UserInputService")
    local compile = loadstring or load

    local C = {
        bg      = Color3.fromRGB(18, 18, 18),
        sidebar = Color3.fromRGB(0, 0, 0),
        panel   = Color3.fromRGB(16, 16, 16),
        card    = Color3.fromRGB(36, 36, 36),
        cardHi  = Color3.fromRGB(48, 48, 48),
        hover   = Color3.fromRGB(40, 40, 40),
        elev    = Color3.fromRGB(36, 36, 36),
        accent  = Color3.fromRGB(30, 215, 96),
        text    = Color3.fromRGB(255, 255, 255),
        sub     = Color3.fromRGB(166, 166, 166),
        dim     = Color3.fromRGB(120, 120, 120),
        bar     = Color3.fromRGB(80, 80, 80),
        danger  = Color3.fromRGB(240, 90, 90),
    }

    local function setFont(obj, weight)
        pcall(function()
            obj.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json",
                weight or Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        end)
    end
    local function make(class, props, children)
        local inst = Instance.new(class)
        for k, v in pairs(props or {}) do inst[k] = v end
        for _, c in ipairs(children or {}) do c.Parent = inst end
        return inst
    end
    local function corner(parent, r)
        return make("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = parent })
    end
    local function label(parent, props, text, size, bold, color, align)
        local l = make("TextLabel", props or {})
        l.BackgroundTransparency = 1
        l.Text = text or ""
        l.TextColor3 = color or C.text
        l.TextSize = size or 13
        l.TextXAlignment = align or Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Center
        setFont(l, bold and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
        l.Parent = parent
        return l
    end

    local IIcons = Icons
    local function icon(parent, name, size, color, pos, anchor, glyph)
        if IIcons then return IIcons.new(parent, name, size, color, pos, anchor, glyph) end
        return label(parent, { Position = pos, AnchorPoint = anchor, Size = UDim2.fromOffset(size, size) }, glyph or "*", size, false, color, Enum.TextXAlignment.Center)
    end
    local function setIcon(obj, name, color)
        if IIcons then IIcons.set(obj, name, color) end
    end

    -- ---------------------------------------------------------------- settings
    local DIR = "0M3G4/P1ANO"
    local SETTINGS_PATH = DIR .. "/settings.json"
    local CACHE_DIR = DIR .. "/cached songs"

    local DEFAULTS = {
        autoplay = false, cachesongs = false, disablenotifs = false, mutesfx = false,
        secondaryloader = false, disableaccidents = false, disablefeaturedsongs = false,
        alwaysshowmidispoofer = false, errorMargin = 0, midiSpoof = false,
    }
    local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end
    local function hasRead() return type(readfile) == "function" and type(isfile) == "function" end
    local function hasWrite() return type(writefile) == "function" end
    local function hasMkdir() return type(makefolder) == "function" end
    local function dirExists() return type(isfolder) == "function" and isfolder(DIR) end

    local Settings = { data = copy(DEFAULTS) }
    do
        local s = copy(DEFAULTS)
        if hasRead() then
            local ok, raw = pcall(function() return isfile(SETTINGS_PATH) and readfile(SETTINGS_PATH) or nil end)
            if ok and raw and #raw > 0 then
                local ok2, t = pcall(function() return HttpService:JSONDecode(raw) end)
                if ok2 and type(t) == "table" then
                    for k, v in pairs(t) do if DEFAULTS[k] ~= nil then s[k] = v end end
                end
            end
        end
        Settings.data = s
    end
    local function saveSettings()
        if not hasWrite() then return end
        pcall(function()
            if hasMkdir() and not dirExists() then makefolder(DIR) end
            writefile(SETTINGS_PATH, HttpService:JSONEncode(Settings.data))
        end)
    end

    local function sfx(id, vol)
        if Settings.data.mutesfx then return end
        pcall(function()
            local lp = Players.LocalPlayer
            local s = Instance.new("Sound")
            s.SoundId = "rbxassetid://" .. tostring(id)
            s.Volume = vol or 0.5
            s.Parent = lp.Character or lp
            s:Play()
            task.delay(2, function() pcall(function() s:Destroy() end) end)
        end)
    end

    -- ---------------------------------------------------------------- parent
    local function resolveParent()
        local candidates = {}
        if inheritedParent then candidates[#candidates + 1] = function() return inheritedParent end end
        candidates[#candidates + 1] = function()
            local lp = Players.LocalPlayer
            if not lp then repeat task.wait(0.1) until Players.LocalPlayer; lp = Players.LocalPlayer end
            return lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 10)
        end
        candidates[#candidates + 1] = function() return game:GetService("CoreGui") end
        for _, f in ipairs(candidates) do
            local ok, parent = pcall(f)
            if ok and parent then
                local ok2 = pcall(function() local t = Instance.new("ScreenGui"); t.Parent = parent; t:Destroy() end)
                if ok2 then return parent end
            end
        end
        return nil
    end
    local parentGui = resolveParent()
    if not parentGui then error("[P1AN0] no valid gui parent") end
    local old = parentGui:FindFirstChild("0M3G4_P1AN0")
    if old then old:Destroy() end

    local gui = make("ScreenGui", {
        Name = "0M3G4_P1AN0", ResetOnSpawn = false, Enabled = true, IgnoreGuiInset = true,
        DisplayOrder = 2147483000, ZIndexBehavior = Enum.ZIndexBehavior.Global, Parent = parentGui,
    })

    local W, H = 900, 560
    local win = make("Frame", {
        Name = "window", Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true, Active = true,
    })
    corner(win, 10)

    local toggle = make("TextButton", {
        Name = "toggle", Parent = gui, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.4, 0), Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Active = true,
    })
    corner(toggle, 22)
    icon(toggle, "music", 22, Color3.fromRGB(0, 0, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "o")

    local SIDE_W, NOW_H = 240, 92
    local sidebar = make("Frame", { Parent = win, Size = UDim2.new(0, SIDE_W, 1, -NOW_H), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = C.sidebar, BorderSizePixel = 0 })
    local main = make("Frame", { Parent = win, Position = UDim2.new(0, SIDE_W, 0, 0), Size = UDim2.new(1, -SIDE_W, 1, -NOW_H), BackgroundColor3 = C.bg, BorderSizePixel = 0 })

    local brand = make("Frame", { Parent = sidebar, Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1 })
    icon(brand, "music", 22, C.text, UDim2.new(0, 18, 0.5, 0), Vector2.new(0, 0.5), "o")
    label(brand, { Position = UDim2.new(0, 48, 0, 0), Size = UDim2.new(1, -56, 1, 0) }, "0M3G4 P1AN0", 16, true, C.text)

    local nav = make("Frame", { Parent = sidebar, Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(1, 0, 0, 88), BackgroundTransparency = 1 })
    local browseBtn = make("TextButton", { Parent = nav, Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(1, -20, 0, 40), BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
    icon(browseBtn, "home", 18, C.text, UDim2.new(0, 8, 0.5, 0), Vector2.new(0, 0.5), "^")
    label(browseBtn, { Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(1, -40, 1, 0) }, "Browse", 14, true, C.text)
    local settingsBtn = make("TextButton", { Parent = nav, Position = UDim2.new(0, 10, 0, 44), Size = UDim2.new(1, -20, 0, 40), BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
    icon(settingsBtn, "sliders", 18, C.sub, UDim2.new(0, 8, 0.5, 0), Vector2.new(0, 0.5), "*")
    label(settingsBtn, { Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(1, -40, 1, 0) }, "Settings", 14, false, C.sub)

    label(sidebar, { Position = UDim2.new(0, 20, 0, 152), Size = UDim2.new(1, -30, 0, 18) }, "LIBRARY", 11, true, C.dim)
    local sideList = make("ScrollingFrame", {
        Parent = sidebar, Position = UDim2.new(0, 8, 0, 174), Size = UDim2.new(1, -16, 1, -182),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    make("UIListLayout", { Parent = sideList, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })

    local top = make("Frame", { Parent = main, Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1 })
    local searchBox = make("Frame", { Parent = top, Position = UDim2.new(0, 20, 0, 16), Size = UDim2.new(0, 320, 0, 34), BackgroundColor3 = C.elev, BorderSizePixel = 0 })
    corner(searchBox, 17)
    icon(searchBox, "search", 16, C.sub, UDim2.new(0, 12, 0.5, 0), Vector2.new(0, 0.5), "?")
    local search = make("TextBox", { Parent = searchBox, Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, ClearTextOnFocus = false, PlaceholderText = "What do you want to play?", PlaceholderColor3 = C.sub, Text = "", TextColor3 = C.text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })

    local function topIconButton(x)
        local b = make("TextButton", { Parent = top, Position = UDim2.new(1, x, 0, 16), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false })
        b.MouseEnter:Connect(function() end)
        return b
    end
    local gearBtn = topIconButton(-112)
    icon(gearBtn, "settings", 18, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "*")
    local minBtn = topIconButton(-74)
    icon(minBtn, "minus", 18, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "-")
    local closeBtn = topIconButton(-36)
    icon(closeBtn, "x", 18, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "x")

    local header = label(main, { Position = UDim2.new(0, 20, 0, 70), Size = UDim2.new(1, -40, 0, 26) }, "All songs", 20, true, C.text)
    local subheader = label(main, { Position = UDim2.new(0, 20, 0, 96), Size = UDim2.new(1, -40, 0, 16) }, "", 12, false, C.sub)

    local list = make("ScrollingFrame", {
        Parent = main, Position = UDim2.new(0, 12, 0, 118), Size = UDim2.new(1, -24, 1, -128),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    make("UIListLayout", { Parent = list, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
    make("UIPadding", { Parent = list, PaddingBottom = UDim.new(0, 12) })

    -- hover play button (parented to `main` so it never joins the list layout)
    local hoverPlay = make("ImageLabel", { Parent = main, Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Visible = false, ZIndex = 50 })
    local hoverHit = make("TextButton", { Parent = main, Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, Text = "", Visible = false, ZIndex = 51 })
    local hoverSong = nil
    if IIcons then setIcon(hoverPlay, "play", C.accent) end
    hoverHit.MouseButton1Click:Connect(function() if hoverSong then selectSong(hoverSong) end end)

    -- now bar
    local now = make("Frame", { Parent = win, Position = UDim2.new(0, 0, 1, -NOW_H), Size = UDim2.new(1, 0, 0, NOW_H), BackgroundColor3 = Color3.fromRGB(24, 24, 24), BorderSizePixel = 0 })
    make("Frame", { Parent = now, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.hover })

    local art = make("Frame", { Parent = now, Position = UDim2.new(0, 16, 0, 17), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0 })
    corner(art, 8)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(Color3.fromRGB(30, 215, 96), Color3.fromRGB(24, 110, 80))
    grad.Rotation = 45
    grad.Parent = art
    icon(art, "music", 24, Color3.fromRGB(255, 255, 255), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "o")

    local npTitle = label(now, { Position = UDim2.new(0, 88, 0, 20), Size = UDim2.new(0, 236, 0, 18) }, "Nothing playing", 14, true, C.text)
    npTitle.TextTruncate = Enum.TextTruncate.AtEnd
    local npSub = label(now, { Position = UDim2.new(0, 88, 0, 40), Size = UDim2.new(0, 236, 0, 16) }, "pick a song", 11, false, C.sub)
    npSub.TextTruncate = Enum.TextTruncate.AtEnd

    local transport = make("Frame", { Parent = now, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(360, 68), BackgroundTransparency = 1 })
    local curTime = label(transport, { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.fromOffset(40, 14) }, "0:00", 10, false, C.dim, Enum.TextXAlignment.Right)
    local totTime = label(transport, { Position = UDim2.new(1, -40, 0, 24), Size = UDim2.fromOffset(40, 14) }, "0:00", 10, false, C.dim, Enum.TextXAlignment.Left)
    local track = make("Frame", { Parent = transport, Position = UDim2.new(0, 48, 0, 27), Size = UDim2.new(1, -96, 0, 4), BackgroundColor3 = C.bar, BorderSizePixel = 0 })
    corner(track, 2)
    local fill = make("Frame", { Parent = track, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.text, BorderSizePixel = 0 })
    corner(fill, 2)

    local btns = make("Frame", { Parent = transport, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(220, 34), BackgroundTransparency = 1 })
    make("UIListLayout", { Parent = btns, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder })
    local function transportBtn(name, glyph, size, primary)
        local b = make("TextButton", { Parent = btns, Size = UDim2.fromOffset(size, size), BackgroundColor3 = primary and C.accent or C.bg, BackgroundTransparency = primary and 0 or 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false })
        if primary then corner(b, size / 2) end
        icon(b, name, size * 0.5, primary and Color3.fromRGB(0, 0, 0) or C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), glyph)
        return b
    end
    local shuffleBtn = transportBtn("shuffle", "~", 26, false)
    local playBtn = transportBtn("play", ">", 38, true)
    local stopBtn = transportBtn("square", "[]", 26, false)

    local right = make("Frame", { Parent = now, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(300, 40), BackgroundTransparency = 1 })
    make("UIListLayout", { Parent = right, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
    local function pill(order, width, glyph)
        local p = make("Frame", { Parent = right, Size = UDim2.fromOffset(width, 32), BackgroundColor3 = C.elev, BorderSizePixel = 0, LayoutOrder = order })
        corner(p, 16)
        local minus = make("TextButton", { Parent = p, Size = UDim2.fromOffset(24, 32), BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
        icon(minus, "minus", 12, C.text, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "-")
        local val = label(p, { Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(1, -48, 1, 0) }, "", 11, true, C.text, Enum.TextXAlignment.Center)
        local plus = make("TextButton", { Parent = p, Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(24, 32), BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
        icon(plus, "plus", 12, C.text, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "+")
        return p, minus, val, plus
    end
    local _, bpmMinus, bpmVal, bpmPlus = pill(1, 96, "clock")
    local _, errMinus, errVal, errPlus = pill(2, 92, "zap")
    local midiPill = make("TextButton", { Parent = right, Size = UDim2.fromOffset(110, 32), BackgroundColor3 = C.elev, BorderSizePixel = 0, Text = "MIDI: off", TextColor3 = C.sub, TextSize = 11, AutoButtonColor = true, LayoutOrder = 3 })
    corner(midiPill, 16)
    setFont(midiPill, Enum.FontWeight.Bold)

    -- settings panel
    local panelW = 380
    local panel = make("Frame", { Parent = win, Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(panelW, H - NOW_H), BackgroundColor3 = C.panel, BorderSizePixel = 0, Visible = false, ZIndex = 20 })
    make("Frame", { Parent = panel, Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Color3.fromRGB(44, 44, 44) })
    local panelHead = make("Frame", { Parent = panel, Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1 })
    label(panelHead, { Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(1, -70, 1, 0) }, "Settings", 20, true, C.text)
    local panelClose = make("TextButton", { Parent = panelHead, Position = UDim2.new(1, -48, 0, 13), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false })
    icon(panelClose, "x", 16, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "x")

    local settingsList = make("ScrollingFrame", { Parent = panel, Position = UDim2.new(0, 14, 0, 62), Size = UDim2.new(1, -28, 1, -76), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y })
    make("UIListLayout", { Parent = settingsList, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })

    local toast = label(win, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -NOW_H - 14), Size = UDim2.fromOffset(420, 34) }, "", 13, true, C.text, Enum.TextXAlignment.Center)
    toast.BackgroundColor3 = C.card
    toast.Visible = false
    corner(toast, 8)
    local toastToken = 0
    local function notify(text, color)
        if Settings.data.disablenotifs then return end
        toastToken = toastToken + 1
        local my = toastToken
        toast.Text = text
        toast.TextColor3 = color or C.text
        toast.Visible = true
        task.spawn(function()
            task.wait(3)
            if toastToken == my then toast.Visible = false end
        end)
    end

    -- ---------------------------------------------------------------- songs
    local memCache = {}
    local function cachePath(file) return CACHE_DIR .. "/" .. file end
    local function httpGet(url)
        local ok, body = pcall(function() return game:HttpGet(url, true) end)
        if ok and type(body) == "string" and #body > 0 then return body end
        local req = (syn and syn.request) or (http and http.request) or request or http_request
        if type(req) == "function" then
            local ok2, res = pcall(req, { Url = url, Method = "GET" })
            if ok2 and type(res) == "table" then
                local b = res.Body or res.body
                if type(b) == "string" and #b > 0 then return b end
            end
        end
        return nil
    end
    local function getSongChunk(song)
        if memCache[song.file] then return compile(memCache[song.file], song.file) end
        if Settings.data.cachesongs then
            if type(loadfile) == "function" then
                local ok, fn = pcall(loadfile, cachePath(song.file))
                if ok and type(fn) == "function" then return fn end
            end
            if hasRead() then
                local ok, data = pcall(function() return isfile(cachePath(song.file)) and readfile(cachePath(song.file)) or nil end)
                if ok and data then
                    local fn = compile(data, song.file)
                    if fn then return fn end
                end
            end
        end
        local body = httpGet(host .. "songs/" .. song.file)
        if not body then return nil, "download failed" end
        memCache[song.file] = body
        if Settings.data.cachesongs and hasWrite() then
            pcall(function()
                if hasMkdir() and not (type(isfolder) == "function" and isfolder(CACHE_DIR)) then makefolder(CACHE_DIR) end
                writefile(cachePath(song.file), body)
            end)
        end
        return compile(body, song.file)
    end

    -- ---------------------------------------------------------------- playback
    local current = nil
    local function fmt(sec)
        sec = math.max(0, math.floor(sec or 0))
        return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
    end
    local function setTransportIcon()
        setIcon(playBtn, (Engine.playing and not Engine.paused) and "pause" or "play", Color3.fromRGB(0, 0, 0))
    end
    local function updateProgress()
        local total = Engine.totalBeats
        local p = (total and total > 0) and (Engine.position / total) or 0
        fill.Size = UDim2.new(p, 0, 1, 0)
        curTime.Text = fmt(Engine.positionSeconds())
        totTime.Text = fmt(Engine.duration())
    end
    Engine.onProgress = function() updateProgress() end
    Engine.onState = function() setTransportIcon() end
    Engine.onFinish = function()
        setTransportIcon()
        sfx("18595195017", 0.5)
        notify("Finished: " .. tostring(Engine.songName))
    end
    local function updateBpmLabels()
        bpmVal.Text = "BPM " .. tostring(Engine.bpm)
        errVal.Text = string.format("ERR %d%%", math.floor(Engine.errorMargin * 100 + 0.5))
    end
    local function updateNow(song)
        current = song
        npTitle.Text = song.name
        local tags = (#song.cat > 0) and table.concat(song.cat, " . ") or "untagged"
        npSub.Text = string.format("%s BPM  .  %s", tostring(song.bpm), tags)
    end

    function selectSong(song)
        updateNow(song)
        local fn, err = getSongChunk(song)
        if not fn then
            notify("Failed to load " .. song.name .. " (" .. tostring(err) .. ")", C.danger)
            return
        end
        Engine.setBpm(tonumber(song.bpm) or 120)
        updateBpmLabels()
        local ok, lerr = Engine.load(fn, song.name)
        if not ok then
            notify("Song error: " .. tostring(lerr), C.danger)
            return
        end
        updateProgress()
        if Settings.data.autoplay then
            Engine.play()
            sfx("70452176150315", 0.1)
        else
            setTransportIcon()
            notify("Ready: " .. song.name .. "  (press play)")
        end
    end

    -- ---------------------------------------------------------------- list
    local filterCat = nil
    local query = ""
    local function matches(song)
        if filterCat then
            if filterCat == "__featured" then
                if not (table.find(song.cat, "best") or table.find(song.cat, "peak")) then return false end
            elseif filterCat == "__new" then
                if not table.find(song.cat, "new") then return false end
            elseif not table.find(song.cat, filterCat) then
                return false
            end
        end
        if query ~= "" then
            local q = query:lower()
            local hit = song.name:lower():find(q, 1, true) or (song.file or ""):lower():find(q, 1, true)
            if not hit then
                for _, t in ipairs(song.cat) do if t:lower():find(q, 1, true) then hit = true break end end
            end
            if not hit then
                for _, t in ipairs(song.alts or {}) do if t:lower():find(q, 1, true) then hit = true break end end
            end
            if not hit then return false end
        end
        return true
    end
    local function render()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        hoverSong = nil
        hoverPlay.Visible = false
        hoverHit.Visible = false
        local shown = 0
        for _, song in ipairs(catalog.songs) do
            if matches(song) then
                shown = shown + 1
                local row = make("TextButton", { Parent = list, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.bg, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = shown })
                corner(row, 4)
                label(row, { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.fromOffset(28, 34) }, tostring(shown), 12, false, C.dim)
                local nm = label(row, { Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(0, 300, 1, 0) }, song.name, 13, false, C.text)
                nm.TextTruncate = Enum.TextTruncate.AtEnd
                label(row, { Position = UDim2.new(0, 352, 0, 0), Size = UDim2.new(0, 200, 1, 0) }, (#song.cat > 0) and song.cat[1] or "", 11, false, C.sub)
                label(row, { Position = UDim2.new(1, -70, 0, 0), Size = UDim2.fromOffset(56, 34) }, tostring(song.bpm), 12, false, C.sub, Enum.TextXAlignment.Right)
                row.MouseEnter:Connect(function()
                    row.BackgroundTransparency = 0.4
                    hoverSong = song
                    local mp, rp = main.AbsolutePosition, row.AbsolutePosition
                    local x, y = rp.X - mp.X + 14, rp.Y - mp.Y + 9
                    hoverPlay.Position = UDim2.fromOffset(x, y)
                    hoverHit.Position = UDim2.fromOffset(x - 4, y - 4)
                    hoverPlay.Visible = true
                    hoverHit.Visible = true
                end)
                row.MouseLeave:Connect(function()
                    row.BackgroundTransparency = 1
                    if hoverSong == song then hoverSong = nil; hoverPlay.Visible = false; hoverHit.Visible = false end
                end)
                row.MouseButton1Click:Connect(function() selectSong(song) end)
            end
        end
        header.Text = (filterCat == "__featured" and "Featured") or (filterCat == "__new" and "New") or (filterCat or "All songs")
        subheader.Text = shown .. " song" .. (shown == 1 and "" or "s")
    end

    local order = 0
    local function sideItem(name, iconName, glyph, filter)
        order = order + 1
        local b = make("TextButton", { Parent = sideList, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.sidebar, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = order })
        corner(b, 4)
        local ic = icon(b, iconName, 16, C.sub, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5), glyph)
        local lbl = label(b, { Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -40, 1, 0) }, name, 13, false, C.sub)
        b.MouseEnter:Connect(function() lbl.TextColor3 = C.text end)
        b.MouseLeave:Connect(function() if filterCat ~= filter then lbl.TextColor3 = C.sub end end)
        b.MouseButton1Click:Connect(function()
            filterCat = filter
            for _, other in ipairs(sideList:GetChildren()) do
                if other:IsA("TextButton") and other ~= b then
                    local ol = other:FindFirstChildOfClass("TextLabel")
                    if ol then ol.TextColor3 = C.sub end
                end
            end
            lbl.TextColor3 = C.text
            render()
        end)
        return b
    end
    local libItems = { all = sideItem("All songs", "music", "o", nil), new = sideItem("New", "sparkles", "*", "__new"), featured = sideItem("Featured", "zap", "!", "__featured") }
    for _, cat in ipairs(catalog.categories or {}) do
        sideItem(cat, "tag", "#", cat)
    end
    search:GetPropertyChangedSignal("Text"):Connect(function() query = search.Text or ""; render() end)

    -- ---------------------------------------------------------------- controls
    playBtn.MouseButton1Click:Connect(function()
        if not Engine.songName then return end
        if Engine.playing then Engine.togglePause() else Engine.play(); sfx("70452176150315", 0.1) end
        setTransportIcon()
    end)
    stopBtn.MouseButton1Click:Connect(function()
        Engine.stop(); Engine.clear(); setTransportIcon(); updateProgress(); sfx("1524549907", 0.1); notify("Stopped")
    end)
    shuffleBtn.MouseButton1Click:Connect(function()
        if #catalog.songs > 0 then selectSong(catalog.songs[math.random(1, #catalog.songs)]) end
    end)
    bpmMinus.MouseButton1Click:Connect(function() Engine.setBpm(Engine.bpm - 10); updateBpmLabels() end)
    bpmPlus.MouseButton1Click:Connect(function() Engine.setBpm(Engine.bpm + 10); updateBpmLabels() end)
    errMinus.MouseButton1Click:Connect(function() Engine.setErrorMargin(Engine.errorMargin - 0.01); Settings.data.errorMargin = Engine.errorMargin; saveSettings(); updateBpmLabels() end)
    errPlus.MouseButton1Click:Connect(function() Engine.setErrorMargin(Engine.errorMargin + 0.01); Settings.data.errorMargin = Engine.errorMargin; saveSettings(); updateBpmLabels() end)

    local function updateMidiVisibility()
        midiPill.Visible = Settings.data.alwaysshowmidispoofer or game.PlaceId == 10888259502
    end
    midiPill.MouseButton1Click:Connect(function()
        Settings.data.midiSpoof = not Settings.data.midiSpoof
        Engine.setMidiSpoof(Settings.data.midiSpoof)
        midiPill.Text = Settings.data.midiSpoof and "MIDI: on" or "MIDI: off"
        midiPill.TextColor3 = Settings.data.midiSpoof and C.accent or C.sub
        saveSettings()
    end)

    local seeking = false
    local function seekFromInput(input)
        return math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then seeking = true end
    end)
    UIS.InputChanged:Connect(function(input)
        if seeking and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fill.Size = UDim2.new(seekFromInput(input), 0, 1, 0)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if seeking and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            seeking = false
            Engine.seek(seekFromInput(input))
        end
    end)

    -- settings panel wiring
    local panelOpen = false
    local function setPanel(open)
        panelOpen = open
        panel.Visible = true
        local target = open and UDim2.new(1, -panelW, 0, 0) or UDim2.new(1, 0, 0, 0)
        TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = target }):Play()
        if not open then task.delay(0.22, function() if not panelOpen then panel.Visible = false end end) end
    end
    gearBtn.MouseButton1Click:Connect(function() setPanel(not panelOpen) end)
    settingsBtn.MouseButton1Click:Connect(function() setPanel(not panelOpen) end)
    panelClose.MouseButton1Click:Connect(function() setPanel(false) end)
    browseBtn.MouseButton1Click:Connect(function() filterCat = nil; search.Text = ""; render() end)

    local function toggleSwitch(parent, initial, onChanged)
        local state = initial and true or false
        local sw = make("TextButton", { Parent = parent, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -52, 0.5, 0), Size = UDim2.fromOffset(42, 24), BackgroundColor3 = state and C.accent or Color3.fromRGB(90, 90, 90), BorderSizePixel = 0, Text = "", AutoButtonColor = false })
        corner(sw, 12)
        local knob = make("Frame", { Parent = sw, Size = UDim2.fromOffset(18, 18), Position = state and UDim2.new(1, -22, 0, 3) or UDim2.new(0, 4, 0, 3), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0 })
        corner(knob, 9)
        sw.MouseButton1Click:Connect(function()
            state = not state
            sw.BackgroundColor3 = state and C.accent or Color3.fromRGB(90, 90, 90)
            knob.Position = state and UDim2.new(1, -22, 0, 3) or UDim2.new(0, 4, 0, 3)
            onChanged(state)
        end)
        return sw
    end

    local sorder = 0
    local function sectionHeader(text)
        sorder = sorder + 1
        local f = make("Frame", { Parent = settingsList, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = sorder })
        label(f, { Position = UDim2.new(0, 2, 0, 4), Size = UDim2.new(1, -4, 0, 20) }, text, 11, true, C.dim)
        return f
    end
    local function settingRow(title, subtitle, key, iconName, glyph)
        sorder = sorder + 1
        local row = make("Frame", { Parent = settingsList, Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = sorder })
        corner(row, 8)
        row.MouseEnter:Connect(function() row.BackgroundColor3 = C.cardHi end)
        row.MouseLeave:Connect(function() row.BackgroundColor3 = C.card end)
        icon(row, iconName, 17, C.sub, UDim2.new(0, 14, 0.5, 0), Vector2.new(0, 0.5), glyph)
        label(row, { Position = UDim2.new(0, 42, 0, 7), Size = UDim2.new(1, -120, 0, 18) }, title, 13, true, C.text)
        label(row, { Position = UDim2.new(0, 42, 0, 26), Size = UDim2.new(1, -120, 0, 15) }, subtitle or "", 10, false, C.sub)
        toggleSwitch(row, Settings.data[key], function(v)
            Settings.data[key] = v
            saveSettings()
            if key == "disableaccidents" then Engine.setDisableAccidents(v) end
            if key == "secondaryloader" then Engine.setPreciseTiming(v) end
            if key == "alwaysshowmidispoofer" then updateMidiVisibility() end
            if key == "disablefeaturedsongs" then libItems.featured.Visible = not v end
            notify(title .. ": " .. (v and "on" or "off"))
        end)
        return row
    end

    sectionHeader("Playback")
    settingRow("Autoplay", "Start playing the moment a song is selected", "autoplay", "play", ">")
    settingRow("Precise timing", "Frame-perfect rests (uses more CPU)", "secondaryloader", "clock", "o")
    settingRow("Disable fake accidents", "Never intentionally miss or shift", "disableaccidents", "shield-check", "v")
    sectionHeader("Library")
    settingRow("Cache songs", "Save songs to workspace (off = always fetch)", "cachesongs", "box", "[]")
    settingRow("Hide featured", "Hide the Featured library item", "disablefeaturedsongs", "sparkles", "*")
    settingRow("Always show MIDI spoofer", "Show the MIDI toggle outside Piano Rooms", "alwaysshowmidispoofer", "zap", "!")
    sectionHeader("Interface")
    settingRow("Disable notifications", "Hide the in-window toasts", "disablenotifs", "info", "i")
    settingRow("Mute sound effects", "Silence click and play sounds", "mutesfx", "volume-x", "x")

    local resetBtn = make("TextButton", { Parent = settingsList, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.hover, BorderSizePixel = 0, Text = "Reset to defaults", TextColor3 = C.text, TextSize = 12, AutoButtonColor = true, LayoutOrder = 999 })
    corner(resetBtn, 8)
    setFont(resetBtn, Enum.FontWeight.Bold)
    resetBtn.MouseButton1Click:Connect(function()
        for k, v in pairs(DEFAULTS) do Settings.data[k] = v end
        saveSettings()
        notify("Settings reset (reopen the script to rebuild)")
    end)

    local visible = true
    toggle.MouseButton1Click:Connect(function() visible = not visible; win.Visible = visible end)
    minBtn.MouseButton1Click:Connect(function() win.Visible = false; visible = false end)
    closeBtn.MouseButton1Click:Connect(function() win.Visible = false; visible = false end)

    local dragging, dragStart, startPos
    local function dragify(handle, target)
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = target.Position
            end
        end)
        handle.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        handle.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
    end
    dragify(top, win)
    dragify(toggle, toggle)

    Engine.setDisableAccidents(Settings.data.disableaccidents)
    Engine.setPreciseTiming(Settings.data.secondaryloader)
    Engine.setMidiSpoof(Settings.data.midiSpoof)
    Engine.setErrorMargin(Settings.data.errorMargin)
    Settings.data.errorMargin = Engine.errorMargin
    midiPill.Text = Settings.data.midiSpoof and "MIDI: on" or "MIDI: off"
    midiPill.TextColor3 = Settings.data.midiSpoof and C.accent or C.sub
    libItems.featured.Visible = not Settings.data.disablefeaturedsongs
    updateMidiVisibility()
    updateBpmLabels()
    updateProgress()
    render()

    print(string.format("[P1AN0] ui built: parent=%s songs=%d cache=%s autoplay=%s fileapi=%s/%s",
        tostring(gui.Parent), #catalog.songs, tostring(Settings.data.cachesongs), tostring(Settings.data.autoplay),
        tostring(hasRead()), tostring(hasWrite())))
    notify("0M3G4 P1AN0  .  " .. tostring(#catalog.songs) .. " songs")
end
