-- 0M3G4 P1AN0 || ui.lua
-- Spotify-inspired single window. Transport, seek, BPM, error margin, MIDI and
-- settings (incl. autoplay + "cache songs") all live inside the window.

return function(Engine, catalog, hostOrHosts, inheritedParent, Icons)
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")
    local UIS = game:GetService("UserInputService")
    local compile = (getgenv and getgenv().loadstring) or loadstring or load

    local HOSTS = (type(hostOrHosts) == "table") and hostOrHosts or {
        hostOrHosts,
        "https://raw.githubusercontent.com/Maarrvviinn/0M3G4_P1AN0/main/",
    }

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
        bar     = Color3.fromRGB(72, 72, 72),
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
        candidates[#candidates + 1] = function() return game:GetService("CoreGui") end
        if gethui then
            candidates[#candidates + 1] = function()
                local h = gethui()
                if h and not h:IsA("ScreenGui") then return h end
                return nil
            end
        end
        candidates[#candidates + 1] = function()
            local lp = Players.LocalPlayer
            if not lp then repeat task.wait(0.1) until Players.LocalPlayer; lp = Players.LocalPlayer end
            return lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 10)
        end
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

    -- Clean up any previous ScreenGui
    local old = parentGui:FindFirstChild("0M3G4_P1AN0")
    if old then pcall(function() old:Destroy() end) end

    -- Using Sibling ZIndexBehavior so child elements naturally layer on top of parent frames
    local gui = make("ScreenGui", {
        Name = "0M3G4_P1AN0", ResetOnSpawn = false, Enabled = true, IgnoreGuiInset = true,
        DisplayOrder = 2147483000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parentGui,
    })

    -- Unload handler for hot-reloading and clean closing
    local function unload()
        pcall(function() Engine.stop() end)
        pcall(function() Engine.clear() end)
        pcall(function() gui:Destroy() end)
        _G.P1AN0_UNLOAD = nil
        if getgenv then getgenv().P1AN0_UNLOAD = nil end
        print("[P1AN0] unloaded cleanly")
    end
    _G.P1AN0_UNLOAD = unload
    if getgenv then getgenv().P1AN0_UNLOAD = unload end

    local W, H = 900, 560
    local win = make("Frame", {
        Name = "window", Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true, Active = true,
        Visible = true,
    })
    corner(win, 10)

    -- Floating toggle button on screen edge (hidden by default while menu is open)
    local toggle = make("TextButton", {
        Name = "toggle", Parent = gui, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.4, 0), Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Active = true,
        Visible = false,
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

    label(sidebar, { Position = UDim2.new(0, 20, 0, 150), Size = UDim2.new(1, -30, 0, 18) }, "LIBRARY", 11, true, C.dim)
    local sideList = make("ScrollingFrame", {
        Parent = sidebar, Position = UDim2.new(0, 8, 0, 172), Size = UDim2.new(1, -16, 1, -180),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    make("UIListLayout", { Parent = sideList, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })

    local top = make("Frame", { Parent = main, Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, Active = true })
    local searchBox = make("Frame", { Parent = top, Position = UDim2.new(0, 20, 0, 14), Size = UDim2.new(0, 320, 0, 34), BackgroundColor3 = C.elev, BorderSizePixel = 0 })
    corner(searchBox, 17)
    icon(searchBox, "search", 16, C.sub, UDim2.new(0, 12, 0.5, 0), Vector2.new(0, 0.5), "?")
    local search = make("TextBox", { Parent = searchBox, Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, ClearTextOnFocus = false, PlaceholderText = "What do you want to play?", PlaceholderColor3 = C.sub, Text = "", TextColor3 = C.text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })

    local function topIconButton(x)
        local b = make("TextButton", { Parent = top, Position = UDim2.new(1, x, 0, 14), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false })
        return b
    end
    local gearBtn = topIconButton(-112)
    icon(gearBtn, "settings", 18, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "*")
    local minBtn = topIconButton(-74)
    icon(minBtn, "minus", 18, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "-")
    local closeBtn = topIconButton(-36)
    icon(closeBtn, "x", 18, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "x")

    local header = label(main, { Position = UDim2.new(0, 20, 0, 64), Size = UDim2.new(1, -40, 0, 24) }, "All songs", 20, true, C.text)
    local subheader = label(main, { Position = UDim2.new(0, 20, 0, 90), Size = UDim2.new(1, -40, 0, 16) }, "", 12, false, C.sub)

    -- Sticky Table Header (Spotify-style with #, Title, Genre, BPM, divider)
    local tableHeader = make("Frame", {
        Parent = main, Position = UDim2.new(0, 12, 0, 112), Size = UDim2.new(1, -24, 0, 28),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    })
    label(tableHeader, { Position = UDim2.new(0, 4, 0, 0), Size = UDim2.fromOffset(36, 26) }, "#", 12, false, C.dim, Enum.TextXAlignment.Center)
    label(tableHeader, { Position = UDim2.new(0, 48, 0, 0), Size = UDim2.new(0, 280, 1, 0) }, "Title", 12, false, C.dim)
    label(tableHeader, { Position = UDim2.new(0, 340, 0, 0), Size = UDim2.new(0, 180, 1, 0) }, "Genre", 12, false, C.dim)
    label(tableHeader, { Position = UDim2.new(1, -64, 0, 0), Size = UDim2.fromOffset(56, 26) }, "BPM", 12, false, C.dim, Enum.TextXAlignment.Right)
    make("Frame", {
        Parent = tableHeader, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Color3.fromRGB(36, 36, 36), BorderSizePixel = 0,
    })

    local list = make("ScrollingFrame", {
        Parent = main, Position = UDim2.new(0, 12, 0, 144), Size = UDim2.new(1, -24, 1, -150),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    make("UIListLayout", { Parent = list, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
    make("UIPadding", { Parent = list, PaddingBottom = UDim.new(0, 12) })

    -- ---------------------------------------------------------------- bottom player
    local now = make("Frame", { Parent = win, Position = UDim2.new(0, 0, 1, -NOW_H), Size = UDim2.new(1, 0, 0, NOW_H), BackgroundColor3 = Color3.fromRGB(24, 24, 24), BorderSizePixel = 0, Active = true })
    make("Frame", { Parent = now, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.hover })

    -- Left: Album Art & Titles (strictly bounded to 230px so it never collides with center timestamps)
    local leftContainer = make("Frame", { Parent = now, Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(0, 230, 1, 0), BackgroundTransparency = 1 })
    local art = make("Frame", { Parent = leftContainer, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0 })
    corner(art, 8)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(Color3.fromRGB(30, 215, 96), Color3.fromRGB(24, 110, 80))
    grad.Rotation = 45
    grad.Parent = art
    icon(art, "music", 24, Color3.fromRGB(255, 255, 255), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "o")

    local textWrap = make("Frame", { Parent = leftContainer, Position = UDim2.new(0, 66, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, -70, 0, 38), BackgroundTransparency = 1 })
    local npTitle = label(textWrap, { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 18) }, "Nothing playing", 14, true, C.text)
    npTitle.TextTruncate = Enum.TextTruncate.AtEnd
    local npSub = label(textWrap, { Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 16) }, "pick a song", 11, false, C.sub)
    npSub.TextTruncate = Enum.TextTruncate.AtEnd

    -- Center: Spotify Transport (Controls on TOP, Scrubber bar on BOTTOM, width 360, centered at 0.5 -> spans x=270 to 630)
    local transport = make("Frame", { Parent = now, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(360, 68), BackgroundTransparency = 1 })

    -- Top: Transport buttons (Shuffle, Play/Pause, Stop)
    local btns = make("Frame", { Parent = transport, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(160, 36), BackgroundTransparency = 1 })
    make("UIListLayout", { Parent = btns, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder })
    local function transportBtn(name, glyph, size, primary)
        local b = make("TextButton", { Parent = btns, Size = UDim2.fromOffset(size, size), BackgroundColor3 = primary and C.accent or C.bg, BackgroundTransparency = primary and 0 or 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false })
        if primary then corner(b, size / 2) end
        icon(b, name, size * 0.5, primary and Color3.fromRGB(0, 0, 0) or C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), glyph)
        return b
    end
    local shuffleBtn = transportBtn("shuffle", "~", 26, false)
    local playBtn = transportBtn("play", ">", 36, true)
    local stopBtn = transportBtn("square", "[]", 26, false)

    -- Bottom: Scrubber bar with timestamps
    local curTime = label(transport, { Position = UDim2.new(0, 0, 0, 42), Size = UDim2.fromOffset(38, 16) }, "0:00", 11, false, C.sub, Enum.TextXAlignment.Right)
    local totTime = label(transport, { Position = UDim2.new(1, -38, 0, 42), Size = UDim2.fromOffset(38, 16) }, "0:00", 11, false, C.sub, Enum.TextXAlignment.Left)
    local track = make("Frame", { Parent = transport, Position = UDim2.new(0, 46, 0, 48), Size = UDim2.new(1, -92, 0, 4), BackgroundColor3 = C.bar, BorderSizePixel = 0 })
    corner(track, 2)
    local fill = make("Frame", { Parent = track, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.text, BorderSizePixel = 0 })
    corner(fill, 2)

    -- Right: Controls (BPM, ERR, MIDI)
    local right = make("Frame", { Parent = now, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(300, 36), BackgroundTransparency = 1 })
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
    local midiPill = make("TextButton", { Parent = right, Size = UDim2.fromOffset(105, 32), BackgroundColor3 = C.elev, BorderSizePixel = 0, Text = "MIDI: off", TextColor3 = C.sub, TextSize = 11, AutoButtonColor = true, LayoutOrder = 3 })
    corner(midiPill, 16)
    setFont(midiPill, Enum.FontWeight.Bold)

    -- ---------------------------------------------------------------- settings panel
    -- Active = true ensures mouse clicks on settings do NOT fall through to background songs
    local panelW = 380
    local panel = make("Frame", { Parent = win, Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(panelW, H - NOW_H), BackgroundColor3 = C.panel, BorderSizePixel = 0, Visible = false, Active = true })
    make("Frame", { Parent = panel, Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Color3.fromRGB(40, 40, 40), BorderSizePixel = 0 })
    local panelHead = make("Frame", { Parent = panel, Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Active = true })
    label(panelHead, { Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(1, -70, 1, 0) }, "Settings", 20, true, C.text)
    local panelClose = make("TextButton", { Parent = panelHead, Position = UDim2.new(1, -48, 0, 13), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false })
    icon(panelClose, "x", 16, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "x")

    local settingsList = make("ScrollingFrame", { Parent = panel, Position = UDim2.new(0, 14, 0, 62), Size = UDim2.new(1, -28, 1, -76), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60), CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Active = true })
    make("UIListLayout", { Parent = settingsList, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })

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

    -- ---------------------------------------------------------------- songs fetching
    local memCache = {}
    local function cachePath(file) return CACHE_DIR .. "/" .. file end

    local function tryHttpGet(url)
        local ok, res = pcall(function() return game:HttpGet(url, true) end)
        if not ok then
            ok, res = pcall(function() return game:HttpGetAsync(url) end)
        end
        if ok and res then
            if type(res) == "string" and #res > 0 then return res end
            if type(res) == "table" then
                local b = res.Body or res.body
                if type(b) == "string" and #b > 0 then return b end
            end
        end
        return nil
    end

    local function tryRequest(url)
        local req = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request or http_request
        if type(req) ~= "function" then return nil end
        local ok, res = pcall(req, { Url = url, Method = "GET" })
        if ok and type(res) == "table" then
            local b = res.Body or res.body
            if type(b) == "string" and #b > 0 then return b end
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

    local function fetchSongBody(fileName)
        for _, base in ipairs(HOSTS) do
            local url = base .. "songs/" .. fileName
            local body = httpGet(url)
            if body and #body > 0 then
                return body
            end
        end
        return nil
    end

    -- Return raw plaintext Lua code for the song
    local function getSongSource(song)
        if memCache[song.file] and #memCache[song.file] > 0 then return memCache[song.file] end
        if Settings.data.cachesongs and hasRead() then
            local ok, data = pcall(function() return isfile(cachePath(song.file)) and readfile(cachePath(song.file)) or nil end)
            if ok and data and #data > 0 then
                memCache[song.file] = data
                return data
            end
        end
        local body = fetchSongBody(song.file)
        if not body or #body == 0 then return nil, "download failed" end
        memCache[song.file] = body
        if Settings.data.cachesongs and hasWrite() then
            pcall(function()
                if hasMkdir() and not (type(isfolder) == "function" and isfolder(CACHE_DIR)) then makefolder(CACHE_DIR) end
                writefile(cachePath(song.file), body)
            end)
        end
        return body
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

    local render = nil -- forward declaration

    function selectSong(song, forcePlay)
        updateNow(song)
        if render then render() end
        local src, err = getSongSource(song)
        if not src then
            print("[P1AN0] failed to load song " .. tostring(song.name) .. ": " .. tostring(err))
            notify("Failed to load " .. song.name .. " (" .. tostring(err) .. ")", C.danger)
            return
        end
        Engine.setBpm(tonumber(song.bpm) or 120)
        updateBpmLabels()
        local ok, lerr = Engine.load(src, song.name)
        if not ok then
            print("[P1AN0] Engine.load error for " .. tostring(song.name) .. ": " .. tostring(lerr))
            notify("Song error: " .. tostring(lerr), C.danger)
            return
        end
        updateProgress()
        print(string.format("[P1AN0] ready '%s': %d actions, duration=%.1fs",
            song.name, #Engine.song, Engine.duration()))
        if forcePlay or Settings.data.autoplay then
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

    render = function()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local shown = 0
        for _, song in ipairs(catalog.songs) do
            if matches(song) then
                shown = shown + 1
                local isCurrent = (current and current.file == song.file)
                local row = make("TextButton", {
                    Parent = list, Size = UDim2.new(1, 0, 0, 36),
                    BackgroundColor3 = C.cardHi, BackgroundTransparency = 1,
                    BorderSizePixel = 0, Text = "", AutoButtonColor = false,
                    LayoutOrder = shown, Active = true,
                })
                corner(row, 4)

                -- Index / Play slot: replaces number with play/pause icon on hover (Spotify style)
                local indexSlot = make("Frame", {
                    Parent = row, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.fromOffset(36, 36),
                    BackgroundTransparency = 1,
                })
                local indexLbl = label(indexSlot, { Size = UDim2.fromScale(1, 1) }, tostring(shown), 12, false, isCurrent and C.accent or C.dim, Enum.TextXAlignment.Center)
                local rowPlayIcon = icon(indexSlot, "play", 14, isCurrent and C.accent or C.text, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), ">")
                rowPlayIcon.Visible = false

                -- Song name (turns vibrant Spotify green when currently selected/playing)
                local nm = label(row, { Position = UDim2.new(0, 48, 0, 0), Size = UDim2.new(0, 280, 1, 0) }, song.name, 13, false, isCurrent and C.accent or C.text)
                nm.TextTruncate = Enum.TextTruncate.AtEnd

                -- Genre / tag
                local genreLbl = label(row, { Position = UDim2.new(0, 340, 0, 0), Size = UDim2.new(0, 180, 1, 0) }, (#song.cat > 0) and song.cat[1] or "", 12, false, C.sub)
                genreLbl.TextTruncate = Enum.TextTruncate.AtEnd

                -- BPM
                local bpmLbl = label(row, { Position = UDim2.new(1, -64, 0, 0), Size = UDim2.fromOffset(56, 36) }, tostring(song.bpm), 12, false, C.sub, Enum.TextXAlignment.Right)

                row.MouseEnter:Connect(function()
                    row.BackgroundTransparency = 0.6
                    indexLbl.Visible = false
                    rowPlayIcon.Visible = true
                    if isCurrent and Engine.playing and not Engine.paused then
                        setIcon(rowPlayIcon, "pause", C.accent)
                    elseif isCurrent then
                        setIcon(rowPlayIcon, "play", C.accent)
                    else
                        setIcon(rowPlayIcon, "play", C.text)
                    end
                end)
                row.MouseLeave:Connect(function()
                    row.BackgroundTransparency = 1
                    indexLbl.Visible = true
                    rowPlayIcon.Visible = false
                end)
                row.MouseButton1Click:Connect(function()
                    if current and current.file == song.file then
                        if Engine.playing then Engine.togglePause() else Engine.play() end
                        setTransportIcon()
                    else
                        selectSong(song, true)
                    end
                end)
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
        if #catalog.songs > 0 then selectSong(catalog.songs[math.random(1, #catalog.songs)], true) end
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
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            seeking = true
            fill.BackgroundColor3 = C.accent
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if seeking and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fill.Size = UDim2.new(seekFromInput(input), 0, 1, 0)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if seeking and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            seeking = false
            fill.BackgroundColor3 = C.text
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
        local sw = make("TextButton", { Parent = parent, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -52, 0.5, 0), Size = UDim2.fromOffset(42, 24), BackgroundColor3 = state and C.accent or Color3.fromRGB(90, 90, 90), BorderSizePixel = 0, Text = "", AutoButtonColor = false, Active = true })
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
        local f = make("Frame", { Parent = settingsList, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = sorder, Active = true })
        label(f, { Position = UDim2.new(0, 4, 0, 6), Size = UDim2.new(1, -8, 0, 18) }, text, 11, true, C.dim)
        return f
    end

    -- Clean Spotify-style settings row: no solid grey card box, clean list layout with subtle divider
    local function settingRow(title, subtitle, key, iconName, glyph)
        sorder = sorder + 1
        local row = make("Frame", { Parent = settingsList, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = sorder, Active = true })
        corner(row, 6)
        row.MouseEnter:Connect(function() row.BackgroundTransparency = 0.94 end)
        row.MouseLeave:Connect(function() row.BackgroundTransparency = 1 end)
        icon(row, iconName, 17, C.sub, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5), glyph)
        label(row, { Position = UDim2.new(0, 38, 0, 6), Size = UDim2.new(1, -100, 0, 18) }, title, 13, true, C.text)
        label(row, { Position = UDim2.new(0, 38, 0, 24), Size = UDim2.new(1, -100, 0, 15) }, subtitle or "", 11, false, C.dim)
        make("Frame", { Parent = row, Position = UDim2.new(0, 38, 1, -1), Size = UDim2.new(1, -38, 0, 1), BackgroundColor3 = Color3.fromRGB(28, 28, 28), BorderSizePixel = 0 })

        toggleSwitch(row, Settings.data[key], function(v)
            Settings.data[key] = v
            saveSettings()
            if key == "disableaccidents" then Engine.setDisableAccidents(v) end
            if key == "secondaryloader" then Engine.setPreciseTiming(v) end
            if key == "alwaysshowmidispoofer" then updateMidiVisibility() end
            if key == "disablefeaturedsongs" then libItems.featured.Visible = not v end
            -- Removed distracting "on / off" notifications per user request
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

    local resetBtn = make("TextButton", { Parent = settingsList, Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.hover, BorderSizePixel = 0, Text = "Reset to defaults", TextColor3 = C.text, TextSize = 12, AutoButtonColor = true, LayoutOrder = 999, Active = true })
    corner(resetBtn, 6)
    setFont(resetBtn, Enum.FontWeight.Bold)
    resetBtn.MouseButton1Click:Connect(function()
        for k, v in pairs(DEFAULTS) do Settings.data[k] = v end
        saveSettings()
        notify("Settings reset (reopen the script to rebuild)")
    end)

    -- Window / Minimize / Close controls:
    -- When menu is open, toggle button is hidden
    -- When minimized, menu hides and toggle button is shown
    -- When closed ('X'), cleanly unloads entire menu
    toggle.MouseButton1Click:Connect(function()
        win.Visible = true
        toggle.Visible = false
    end)
    minBtn.MouseButton1Click:Connect(function()
        win.Visible = false
        toggle.Visible = true
    end)
    closeBtn.MouseButton1Click:Connect(function()
        unload()
    end)

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
