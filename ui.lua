-- 0M3G4 P1AN0 || ui.lua
-- Spotify-inspired desktop client for Roblox piano autoplayer.
-- Features: Fixed native HttpGet download flow matching TALENTLESS source,
-- sleek player bar with NO bulky grey backgrounds, compact 52px MIDI badge with zero timestamp collisions,
-- clean 68px collapsible sidebar with centered icons, dynamic proportional table columns
-- that resize without clipping behind Settings, tactile button click/hover micro-interactions,
-- and ironclad isolation from ghost hovers.

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
        bg          = Color3.fromRGB(18, 18, 18),
        sidebar     = Color3.fromRGB(0, 0, 0),
        panel       = Color3.fromRGB(18, 18, 18),
        card        = Color3.fromRGB(28, 28, 28),
        cardHi      = Color3.fromRGB(38, 38, 38),
        hover       = Color3.fromRGB(36, 36, 36),
        elev        = Color3.fromRGB(28, 28, 28),
        accent      = Color3.fromRGB(30, 215, 96),       -- Spotify neon green
        accentHover = Color3.fromRGB(35, 235, 105),
        text        = Color3.fromRGB(255, 255, 255),
        sub         = Color3.fromRGB(170, 170, 170),
        dim         = Color3.fromRGB(110, 110, 110),
        bar         = Color3.fromRGB(70, 70, 70),
        border      = Color3.fromRGB(48, 48, 48),
        danger      = Color3.fromRGB(240, 90, 90),
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

    -- Tactile button interaction helper (hover brightening + scale depress)
    local function addTactile(btn, opts)
        opts = opts or {}
        local uis = make("UIScale", { Parent = btn, Scale = 1 })
        local defaultScale = opts.defaultScale or 1
        local downScale = opts.downScale or 0.94

        btn.MouseEnter:Connect(function()
            if opts.onHover then opts.onHover(true) end
            if opts.hoverBg then
                TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quart), { BackgroundColor3 = opts.hoverBg }):Play()
            end
        end)

        btn.MouseLeave:Connect(function()
            if opts.onHover then opts.onHover(false) end
            if opts.hoverBg and opts.idleBg then
                TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quart), { BackgroundColor3 = opts.idleBg }):Play()
            end
            TweenService:Create(uis, TweenInfo.new(0.12, Enum.EasingStyle.Quart), { Scale = defaultScale }):Play()
        end)

        btn.MouseButton1Down:Connect(function()
            TweenService:Create(uis, TweenInfo.new(0.08, Enum.EasingStyle.Quart), { Scale = downScale }):Play()
        end)

        btn.MouseButton1Up:Connect(function()
            TweenService:Create(uis, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = defaultScale }):Play()
        end)

        return uis
    end

    local function getSongArtist(song)
        if song.alts and #song.alts > 0 then
            local a = song.alts[1]
            return (a:gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest:lower() end))
        end
        return "—"
    end

    -- ---------------------------------------------------------------- settings
    local DIR = "0M3G4/P1ANO"
    local SETTINGS_PATH = DIR .. "/settings.json"
    local CACHE_DIR = DIR .. "/cached songs"

    local DEFAULTS = {
        autoplay = false, cachesongs = false, disablenotifs = false, mutesfx = false,
        secondaryloader = false, disableaccidents = false, disablefeaturedsongs = false,
        alwaysshowmidispoofer = false, errorMargin = 0, midiSpoof = false,
        sidebarCollapsed = false, showColArtist = true, showColGenre = true, showColBpm = true,
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

    local old = parentGui:FindFirstChild("0M3G4_P1AN0")
    if old then pcall(function() old:Destroy() end) end

    local gui = make("ScreenGui", {
        Name = "0M3G4_P1AN0", ResetOnSpawn = false, Enabled = true, IgnoreGuiInset = true,
        DisplayOrder = 2147483000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parentGui,
    })

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
    -- Subtle elegant border around the window
    make("UIStroke", {
        Parent = win, Color = C.border, Thickness = 1, Transparency = 0.45,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    -- Floating edge toggle button on screen edge (visible only when minimized)
    local toggle = make("TextButton", {
        Name = "toggle", Parent = gui, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.4, 0), Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Active = true,
        Visible = false,
    })
    corner(toggle, 22)
    icon(toggle, "music", 22, Color3.fromRGB(0, 0, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "o")
    addTactile(toggle, { hoverBg = C.accentHover, idleBg = C.accent, downScale = 0.9 })

    local SIDE_EXP, SIDE_COL = 230, 68
    local NOW_H = 92
    local PANEL_W = 360
    local isSidebarCollapsed = Settings.data.sidebarCollapsed and true or false
    local currentSideW = isSidebarCollapsed and SIDE_COL or SIDE_EXP
    local panelOpen = false

    local sidebar = make("Frame", {
        Parent = win, Size = UDim2.new(0, currentSideW, 1, -NOW_H),
        Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = C.sidebar, BorderSizePixel = 0,
        ClipsDescendants = true, ZIndex = 2,
    })
    local main = make("Frame", {
        Parent = win, Position = UDim2.new(0, currentSideW, 0, 0),
        Size = UDim2.new(1, -currentSideW, 1, -NOW_H), BackgroundColor3 = C.bg, BorderSizePixel = 0,
        ClipsDescendants = true, ZIndex = 1,
    })

    -- Sidebar brand header with collapse toggle button
    local brand = make("Frame", { Parent = sidebar, Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, ZIndex = 2 })
    local brandIcon = icon(brand, "music", 20, C.accent, UDim2.new(0, isSidebarCollapsed and 34 or 20, 0.5, 0), Vector2.new(0.5, 0.5), "o")
    local brandTitle = label(brand, { Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -84, 1, 0), ZIndex = 2 }, "0M3G4 P1AN0", 15, true, C.text)
    brandTitle.Visible = not isSidebarCollapsed

    local collapseBtn = make("TextButton", {
        Parent = brand, AnchorPoint = isSidebarCollapsed and Vector2.new(0.5, 0.5) or Vector2.new(1, 0.5),
        Position = isSidebarCollapsed and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 4,
    })
    corner(collapseBtn, 6)
    local collapseIcon = icon(collapseBtn, isSidebarCollapsed and "panel-left-open" or "panel-left-close", 16, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), isSidebarCollapsed and "[>]" or "[|]")
    addTactile(collapseBtn, {
        onHover = function(h)
            collapseBtn.BackgroundTransparency = h and 0.85 or 1
            collapseBtn.BackgroundColor3 = C.hover
            collapseIcon.TextColor3 = h and C.text or C.sub
        end
    })

    local nav = make("Frame", { Parent = sidebar, Position = UDim2.new(0, 0, 0, 56), Size = UDim2.new(1, 0, 0, 88), BackgroundTransparency = 1, ZIndex = 2 })
    local browseBtn = make("TextButton", {
        Parent = nav, Position = UDim2.new(0, isSidebarCollapsed and 14 or 10, 0, 2),
        Size = isSidebarCollapsed and UDim2.fromOffset(40, 40) or UDim2.new(1, -20, 0, 40),
        BackgroundColor3 = C.hover, BackgroundTransparency = 0.8, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 2,
    })
    corner(browseBtn, 6)
    local browseIcon = icon(browseBtn, "home", 18, C.text, isSidebarCollapsed and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 12, 0.5, 0), isSidebarCollapsed and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5), "^")
    local browseLbl = label(browseBtn, { Position = UDim2.new(0, 38, 0, 0), Size = UDim2.new(1, -42, 1, 0), ZIndex = 2 }, "Browse", 14, true, C.text)
    browseLbl.Visible = not isSidebarCollapsed
    addTactile(browseBtn)

    local settingsBtn = make("TextButton", {
        Parent = nav, Position = UDim2.new(0, isSidebarCollapsed and 14 or 10, 0, 44),
        Size = isSidebarCollapsed and UDim2.fromOffset(40, 40) or UDim2.new(1, -20, 0, 40),
        BackgroundColor3 = C.hover, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 2,
    })
    corner(settingsBtn, 6)
    local settingsIcon = icon(settingsBtn, "sliders", 18, C.sub, isSidebarCollapsed and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 12, 0.5, 0), isSidebarCollapsed and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5), "*")
    local settingsLbl = label(settingsBtn, { Position = UDim2.new(0, 38, 0, 0), Size = UDim2.new(1, -42, 1, 0), ZIndex = 2 }, "Settings", 14, false, C.sub)
    settingsLbl.Visible = not isSidebarCollapsed
    addTactile(settingsBtn)

    local libHeader = label(sidebar, { Position = UDim2.new(0, 18, 0, 150), Size = UDim2.new(1, -26, 0, 18), ZIndex = 2 }, "LIBRARY", 11, true, C.dim)
    libHeader.Visible = not isSidebarCollapsed

    local sideList = make("ScrollingFrame", {
        Parent = sidebar, Position = UDim2.new(0, 6, 0, 172), Size = UDim2.new(1, -12, 1, -180),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = isSidebarCollapsed and 0 or 2,
        ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 2,
    })
    make("UIListLayout", { Parent = sideList, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })

    -- Top bar in main viewport
    local top = make("Frame", { Parent = main, Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, Active = true, ZIndex = 1 })
    local searchBox = make("Frame", { Parent = top, Position = UDim2.new(0, 20, 0, 14), Size = UDim2.new(0, 300, 0, 34), BackgroundColor3 = C.card, BorderSizePixel = 0 })
    corner(searchBox, 17)
    icon(searchBox, "search", 16, C.sub, UDim2.new(0, 12, 0.5, 0), Vector2.new(0, 0.5), "?")
    local search = make("TextBox", { Parent = searchBox, Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, ClearTextOnFocus = false, PlaceholderText = "What do you want to play?", PlaceholderColor3 = C.sub, Text = "", TextColor3 = C.text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })

    local function topIconButton(x, iconName, glyph)
        local b = make("TextButton", { Parent = top, Position = UDim2.new(1, x, 0, 14), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 2 })
        corner(b, 16)
        local ic = icon(b, iconName, 17, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), glyph)
        addTactile(b, {
            onHover = function(h)
                b.BackgroundTransparency = h and 0.82 or 1
                b.BackgroundColor3 = C.hover
                ic.TextColor3 = h and C.text or C.sub
            end
        })
        return b, ic
    end
    local gearBtn = topIconButton(-112, "settings", "*")
    local minBtn = topIconButton(-74, "minus", "-")
    local closeBtn = topIconButton(-36, "x", "x")

    local header = label(main, { Position = UDim2.new(0, 20, 0, 64), Size = UDim2.new(1, -40, 0, 24) }, "All songs", 20, true, C.text)
    local subheader = label(main, { Position = UDim2.new(0, 20, 0, 90), Size = UDim2.new(1, -40, 0, 16) }, "", 12, false, C.sub)

    -- Dynamic table header
    local tableHeader = make("Frame", {
        Parent = main, Position = UDim2.new(0, 12, 0, 112), Size = UDim2.new(1, -24, 0, 28),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
    })
    local thIndex = label(tableHeader, { Position = UDim2.new(0, 4, 0, 0), Size = UDim2.fromOffset(36, 26) }, "#", 12, false, C.dim, Enum.TextXAlignment.Center)
    local thTitle = label(tableHeader, { Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(0, 240, 1, 0) }, "Title", 12, false, C.dim)
    local thArtist = label(tableHeader, { Position = UDim2.new(0, 290, 0, 0), Size = UDim2.new(0, 160, 1, 0) }, "Artist", 12, false, C.dim)
    local thGenre = label(tableHeader, { Position = UDim2.new(0, 460, 0, 0), Size = UDim2.new(0, 130, 1, 0) }, "Genre", 12, false, C.dim)
    local thBpm = label(tableHeader, { Position = UDim2.new(1, -64, 0, 0), Size = UDim2.fromOffset(56, 26) }, "BPM", 12, false, C.dim, Enum.TextXAlignment.Right)
    make("Frame", {
        Parent = tableHeader, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Color3.fromRGB(36, 36, 36), BorderSizePixel = 0,
    })

    local list = make("ScrollingFrame", {
        Parent = main, Position = UDim2.new(0, 12, 0, 144), Size = UDim2.new(1, -24, 1, -150),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 1,
    })
    make("UIListLayout", { Parent = list, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
    make("UIPadding", { Parent = list, PaddingBottom = UDim.new(0, 12) })

    -- ---------------------------------------------------------------- bottom player bar
    local now = make("Frame", { Parent = win, Position = UDim2.new(0, 0, 1, -NOW_H), Size = UDim2.new(1, 0, 0, NOW_H), BackgroundColor3 = Color3.fromRGB(24, 24, 24), BorderSizePixel = 0, Active = true, ZIndex = 10 })
    make("Frame", { Parent = now, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(38, 38, 38) })

    -- Left: Currently playing info
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

    -- Center: Transport & Scrubber (Width 320px, clear buffer from right controls)
    local transport = make("Frame", { Parent = now, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(320, 68), BackgroundTransparency = 1 })
    local btns = make("Frame", { Parent = transport, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(150, 36), BackgroundTransparency = 1 })
    make("UIListLayout", { Parent = btns, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder })

    local function transportBtn(name, glyph, size, primary)
        local b = make("TextButton", { Parent = btns, Size = UDim2.fromOffset(size, size), BackgroundColor3 = primary and C.accent or C.bg, BackgroundTransparency = primary and 0 or 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false })
        if primary then corner(b, size / 2) end
        local ic = icon(b, name, size * 0.5, primary and Color3.fromRGB(0, 0, 0) or C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), glyph)
        addTactile(b, {
            downScale = 0.9,
            onHover = function(h)
                if primary then
                    TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quart), { BackgroundColor3 = h and C.accentHover or C.accent }):Play()
                else
                    ic.TextColor3 = h and C.text or C.sub
                end
            end
        })
        return b, ic
    end
    local shuffleBtn = transportBtn("shuffle", "~", 26, false)
    local playBtn = transportBtn("play", ">", 36, true)
    local stopBtn = transportBtn("square", "[]", 26, false)

    local curTime = label(transport, { Position = UDim2.new(0, 0, 0, 42), Size = UDim2.fromOffset(38, 16) }, "0:00", 11, false, C.sub, Enum.TextXAlignment.Right)
    local totTime = label(transport, { Position = UDim2.new(1, -38, 0, 42), Size = UDim2.fromOffset(38, 16) }, "0:00", 11, false, C.sub, Enum.TextXAlignment.Left)
    local track = make("Frame", { Parent = transport, Position = UDim2.new(0, 46, 0, 48), Size = UDim2.new(1, -92, 0, 4), BackgroundColor3 = C.bar, BorderSizePixel = 0 })
    corner(track, 2)
    local fill = make("Frame", { Parent = track, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.text, BorderSizePixel = 0 })
    corner(fill, 2)

    -- Right: Minimal controls (NO ugly grey rectangles; width 200px, 70px+ buffer from transport)
    local right = make("Frame", { Parent = now, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(200, 32), BackgroundTransparency = 1 })
    make("UIListLayout", { Parent = right, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })

    local function miniControl(order, width)
        local c = make("Frame", { Parent = right, Size = UDim2.fromOffset(width, 28), BackgroundTransparency = 1, LayoutOrder = order })
        local minus = make("TextButton", { Parent = c, Size = UDim2.fromOffset(18, 28), BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
        corner(minus, 4)
        local mic = icon(minus, "minus", 11, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "-")
        addTactile(minus, { onHover = function(h) mic.TextColor3 = h and C.text or C.sub end })

        local val = label(c, { Position = UDim2.new(0, 18, 0, 0), Size = UDim2.new(1, -36, 1, 0) }, "", 11, true, C.text, Enum.TextXAlignment.Center)

        local plus = make("TextButton", { Parent = c, Position = UDim2.new(1, -18, 0, 0), Size = UDim2.fromOffset(18, 28), BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
        corner(plus, 4)
        local pic = icon(plus, "plus", 11, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "+")
        addTactile(plus, { onHover = function(h) pic.TextColor3 = h and C.text or C.sub end })

        return c, minus, val, plus
    end
    local _, bpmMinus, bpmVal, bpmPlus = miniControl(1, 68)
    local _, errMinus, errVal, errPlus = miniControl(2, 64)

    -- Compact 52px inline MIDI badge with green status dot
    local midiBadge = make("TextButton", {
        Parent = right, Size = UDim2.fromOffset(52, 24),
        BackgroundColor3 = Color3.fromRGB(28, 28, 28), BackgroundTransparency = 0.5,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = 3,
    })
    corner(midiBadge, 12)
    local midiDot = make("Frame", {
        Parent = midiBadge, Size = UDim2.fromOffset(6, 6),
        Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = C.dim, BorderSizePixel = 0,
    })
    corner(midiDot, 3)
    local midiLbl = label(midiBadge, { Position = UDim2.new(0, 18, 0, 0), Size = UDim2.new(1, -22, 1, 0) }, "MIDI", 11, true, C.dim, Enum.TextXAlignment.Left)
    addTactile(midiBadge, {
        onHover = function(h)
            midiBadge.BackgroundTransparency = h and 0.2 or 0.5
        end
    })

    -- ---------------------------------------------------------------- settings panel
    local panel = make("Frame", {
        Parent = win, Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(PANEL_W, H - NOW_H),
        BackgroundColor3 = C.panel, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 20,
    })
    make("Frame", { Parent = panel, Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Color3.fromRGB(38, 38, 38), BorderSizePixel = 0, ZIndex = 21 })
    local panelBlocker = make("TextButton", {
        Parent = panel, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Active = true, ZIndex = 20,
    })

    local panelHead = make("Frame", { Parent = panel, Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Active = true, ZIndex = 21 })
    label(panelHead, { Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(1, -70, 1, 0), ZIndex = 21 }, "Settings", 20, true, C.text)
    local panelClose = make("TextButton", { Parent = panelHead, Position = UDim2.new(1, -46, 0, 14), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 22 })
    corner(panelClose, 15)
    local pCloseIc = icon(panelClose, "x", 16, C.sub, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "x")
    addTactile(panelClose, {
        onHover = function(h)
            panelClose.BackgroundTransparency = h and 0.85 or 1
            panelClose.BackgroundColor3 = C.hover
            pCloseIc.TextColor3 = h and C.text or C.sub
        end
    })

    local settingsList = make("ScrollingFrame", {
        Parent = panel, Position = UDim2.new(0, 14, 0, 62), Size = UDim2.new(1, -28, 1, -76),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60),
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Active = true, ZIndex = 21,
    })
    make("UIListLayout", { Parent = settingsList, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })

    local toast = label(win, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -NOW_H - 14), Size = UDim2.fromOffset(420, 34), ZIndex = 30 }, "", 13, true, C.text, Enum.TextXAlignment.Center)
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

    -- ---------------------------------------------------------------- robust song fetching
    -- Matches TALENTLESS source directly: relies on native game:HttpGet without hanging request stubs
    local memCache = {}
    local function cachePath(file) return CACHE_DIR .. "/" .. file end

    local function httpGet(url)
        -- 1. Direct game:HttpGet with cache (standard native executor API)
        local ok, res = pcall(function() return game:HttpGet(url, true) end)
        if ok and type(res) == "string" and #res > 0 then return res end

        -- 2. Direct game:HttpGet without cache flag
        local ok2, res2 = pcall(function() return game:HttpGet(url) end)
        if ok2 and type(res2) == "string" and #res2 > 0 then return res2 end

        -- 3. game:HttpGetAsync
        local ok3, res3 = pcall(function() return game:HttpGetAsync(url) end)
        if ok3 and type(res3) == "string" and #res3 > 0 then return res3 end

        return nil
    end

    local function fetchSongBody(fileName)
        for _, rawBase in ipairs(HOSTS) do
            local base = rawBase:sub(-1) == "/" and rawBase or (rawBase .. "/")
            local url = base .. "songs/" .. fileName
            print("[P1AN0] fetching: " .. url)
            local body = httpGet(url)
            if body and #body > 0 then
                print(string.format("[P1AN0] fetched '%s' (%d bytes)", fileName, #body))
                return body
            end
        end
        return nil
    end

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

    -- ---------------------------------------------------------------- playback & row tracking
    local current = nil
    local rowRefs = {}
    local isDownloading = false
    local playPendingOnLoad = false

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
        bpmVal.Text = tostring(Engine.bpm) .. " BPM"
        errVal.Text = string.format("%d%% ERR", math.floor(Engine.errorMargin * 100 + 0.5))
    end

    local function updateMidiBadge()
        local active = Settings.data.midiSpoof
        midiDot.BackgroundColor3 = active and C.accent or C.dim
        midiLbl.TextColor3 = active and C.text or C.dim
        midiBadge.Visible = Settings.data.alwaysshowmidispoofer or game.PlaceId == 10888259502
    end

    local function updateRowHighlight(newSong)
        if current and current.file ~= (newSong and newSong.file) then
            local prev = rowRefs[current.file]
            if prev then
                prev.nm.TextColor3 = C.text
                prev.indexLbl.TextColor3 = C.dim
                if prev.playIcon then setIcon(prev.playIcon, "play", C.text) end
            end
        end
        if newSong then
            local cur = rowRefs[newSong.file]
            if cur then
                cur.nm.TextColor3 = C.accent
                cur.indexLbl.TextColor3 = C.accent
                if cur.playIcon then
                    setIcon(cur.playIcon, (Engine.playing and not Engine.paused) and "pause" or "play", C.accent)
                end
            end
        end
    end

    local function updateNow(song)
        updateRowHighlight(song)
        current = song
        npTitle.Text = song.name
        local tags = (#song.cat > 0) and table.concat(song.cat, " · ") or "untagged"
        npSub.Text = string.format("%s BPM  ·  %s", tostring(song.bpm), tags)
    end

    -- Asynchronous song loader that immediately prepares song for playing
    local function selectSong(song, forcePlay)
        updateNow(song)
        if forcePlay then playPendingOnLoad = true end

        -- If song script is already in memory and engine has it loaded
        if Engine.songName == song.name and #Engine.song > 0 then
            Engine.setBpm(tonumber(song.bpm) or 120)
            updateBpmLabels()
            if forcePlay or Settings.data.autoplay then
                Engine.play()
                setTransportIcon()
                sfx("70452176150315", 0.1)
            end
            return
        end

        npSub.Text = "Loading song from CDN..."
        curTime.Text = "0:00"
        totTime.Text = "--:--"
        fill.Size = UDim2.new(0, 0, 1, 0)
        isDownloading = true

        print(string.format("[P1AN0] selectSong: '%s' (%s)", song.name, song.file))
        local src, err = getSongSource(song)
        isDownloading = false

        if not src then
            print(string.format("[P1AN0] failed to load '%s': %s", song.name, tostring(err)))
            notify("Failed to load " .. song.name .. " (" .. tostring(err) .. ")", C.danger)
            npSub.Text = "Download failed"
            playPendingOnLoad = false
            return
        end

        Engine.setBpm(tonumber(song.bpm) or 120)
        updateBpmLabels()

        local ok, lerr = Engine.load(src, song.name)
        if not ok then
            print(string.format("[P1AN0] Engine.load error for '%s': %s", song.name, tostring(lerr)))
            notify("Song error: " .. tostring(lerr), C.danger)
            npSub.Text = "Load error"
            playPendingOnLoad = false
            return
        end

        updateProgress()
        local tags = (#song.cat > 0) and table.concat(song.cat, " · ") or "untagged"
        npSub.Text = string.format("%s BPM  ·  %s", tostring(song.bpm), tags)
        print(string.format("[P1AN0] ready '%s': %d actions, duration=%.1fs", song.name, #Engine.song, Engine.duration()))

        if playPendingOnLoad or Settings.data.autoplay then
            playPendingOnLoad = false
            print("[P1AN0] playing: " .. song.name)
            Engine.play()
            setTransportIcon()
            sfx("70452176150315", 0.1)
        else
            setTransportIcon()
            notify("Ready: " .. song.name .. "  (click play)")
        end
    end

    -- ---------------------------------------------------------------- dynamic proportional columns
    local function updateColumnLayout()
        local showArt = Settings.data.showColArtist
        local showGen = Settings.data.showColGenre
        local showBpm = Settings.data.showColBpm

        thArtist.Visible = showArt
        thGenre.Visible = showGen
        thBpm.Visible = showBpm

        -- Measure list width or use dynamic proportions
        local availW = math.max(300, list.AbsoluteSize.X - 44 - (showBpm and 64 or 12))

        local titleW, artW, genW
        if showArt and showGen then
            titleW = math.floor(availW * 0.46)
            artW = math.floor(availW * 0.30)
            genW = math.floor(availW * 0.24)
        elseif showArt and not showGen then
            titleW = math.floor(availW * 0.62)
            artW = math.floor(availW * 0.38)
            genW = 0
        elseif not showArt and showGen then
            titleW = math.floor(availW * 0.66)
            artW = 0
            genW = math.floor(availW * 0.34)
        else
            titleW = availW
            artW = 0
            genW = 0
        end

        local offset = 44
        thTitle.Position = UDim2.new(0, offset, 0, 0)
        thTitle.Size = UDim2.new(0, titleW, 1, 0)

        thArtist.Position = UDim2.new(0, offset + titleW + 8, 0, 0)
        thArtist.Size = UDim2.new(0, artW, 1, 0)

        thGenre.Position = UDim2.new(0, offset + titleW + (showArt and (artW + 16) or 8), 0, 0)
        thGenre.Size = UDim2.new(0, genW, 1, 0)

        for _, ref in pairs(rowRefs) do
            if ref.nm then
                ref.nm.Position = UDim2.new(0, offset, 0, 0)
                ref.nm.Size = UDim2.new(0, titleW, 1, 0)
            end
            if ref.artistLbl then
                ref.artistLbl.Visible = showArt
                ref.artistLbl.Position = UDim2.new(0, offset + titleW + 8, 0, 0)
                ref.artistLbl.Size = UDim2.new(0, artW, 1, 0)
            end
            if ref.genreLbl then
                ref.genreLbl.Visible = showGen
                ref.genreLbl.Position = UDim2.new(0, offset + titleW + (showArt and (artW + 16) or 8), 0, 0)
                ref.genreLbl.Size = UDim2.new(0, genW, 1, 0)
            end
            if ref.bpmLbl then
                ref.bpmLbl.Visible = showBpm
            end
        end
    end

    -- ---------------------------------------------------------------- song list rendering
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

    local function render(animateTransition)
        rowRefs = {}
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
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1,
                    BorderSizePixel = 0, Text = "", AutoButtonColor = false,
                    LayoutOrder = shown, Active = true, ZIndex = 1,
                })
                corner(row, 4)

                local indexSlot = make("Frame", {
                    Parent = row, Position = UDim2.new(0, 4, 0, 0), Size = UDim2.fromOffset(36, 36),
                    BackgroundTransparency = 1,
                })
                local indexLbl = label(indexSlot, { Size = UDim2.fromScale(1, 1) }, tostring(shown), 12, false, isCurrent and C.accent or C.dim, Enum.TextXAlignment.Center)
                local rowPlayIcon = icon(indexSlot, "play", 14, isCurrent and C.accent or C.text, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), ">")
                rowPlayIcon.Visible = false

                local nm = label(row, { Position = UDim2.new(0, 44, 0, 0), Size = UDim2.new(0, 240, 1, 0) }, song.name, 13, false, isCurrent and C.accent or C.text)
                nm.TextTruncate = Enum.TextTruncate.AtEnd

                local artistLbl = label(row, { Position = UDim2.new(0, 290, 0, 0), Size = UDim2.new(0, 160, 1, 0) }, getSongArtist(song), 12, false, C.sub)
                artistLbl.TextTruncate = Enum.TextTruncate.AtEnd

                local genreLbl = label(row, { Position = UDim2.new(0, 460, 0, 0), Size = UDim2.new(0, 130, 1, 0) }, (#song.cat > 0) and song.cat[1] or "", 12, false, C.sub)
                genreLbl.TextTruncate = Enum.TextTruncate.AtEnd

                local bpmLbl = label(row, { Position = UDim2.new(1, -64, 0, 0), Size = UDim2.fromOffset(56, 36) }, tostring(song.bpm), 12, false, C.sub, Enum.TextXAlignment.Right)

                rowRefs[song.file] = {
                    row = row,
                    nm = nm,
                    artistLbl = artistLbl,
                    genreLbl = genreLbl,
                    bpmLbl = bpmLbl,
                    indexLbl = indexLbl,
                    playIcon = rowPlayIcon,
                }

                row.MouseEnter:Connect(function()
                    if panelOpen and panel.Visible then return end
                    row.BackgroundTransparency = 0.94
                    indexLbl.Visible = false
                    rowPlayIcon.Visible = true
                    if current and current.file == song.file and Engine.playing and not Engine.paused then
                        setIcon(rowPlayIcon, "pause", C.accent)
                    elseif current and current.file == song.file then
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
                    if panelOpen and panel.Visible then return end
                    if current and current.file == song.file then
                        if Engine.playing then
                            Engine.togglePause()
                        else
                            Engine.play()
                        end
                        setTransportIcon()
                    else
                        task.spawn(function()
                            selectSong(song, true)
                        end)
                    end
                end)
            end
        end

        header.Text = (filterCat == "__featured" and "Featured") or (filterCat == "__new" and "New") or (filterCat or "All songs")
        subheader.Text = shown .. " song" .. (shown == 1 and "" or "s")
        updateColumnLayout()

        if animateTransition then
            list.CanvasPosition = Vector2.new(0, 0)
            list.Position = UDim2.new(0, 12, 0, 156)
            TweenService:Create(list, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 12, 0, 144)
            }):Play()
        end
    end

    -- ---------------------------------------------------------------- sidebar items & collapse
    local order = 0
    local sideItemButtons = {}
    local function sideItem(name, iconName, glyph, filter)
        order = order + 1
        local b = make("TextButton", {
            Parent = sideList,
            Size = isSidebarCollapsed and UDim2.fromOffset(40, 36) or UDim2.new(1, 0, 0, 32),
            Position = isSidebarCollapsed and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0, 0),
            AnchorPoint = isSidebarCollapsed and Vector2.new(0.5, 0) or Vector2.new(0, 0),
            BackgroundColor3 = C.sidebar, BackgroundTransparency = 1, BorderSizePixel = 0,
            Text = "", AutoButtonColor = false, LayoutOrder = order, ZIndex = 2,
        })
        corner(b, 4)
        local ic = icon(b, iconName, 16, C.sub, isSidebarCollapsed and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 8, 0.5, 0), isSidebarCollapsed and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5), glyph)
        local lbl = label(b, { Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -40, 1, 0), ZIndex = 2 }, name, 13, false, C.sub)
        lbl.Visible = not isSidebarCollapsed

        sideItemButtons[#sideItemButtons + 1] = { btn = b, lbl = lbl, icon = ic, filter = filter }
        addTactile(b, {
            onHover = function(h)
                lbl.TextColor3 = (h or filterCat == filter) and C.text or C.sub
                ic.TextColor3 = (h or filterCat == filter) and C.text or C.sub
            end
        })

        b.MouseButton1Click:Connect(function()
            filterCat = filter
            for _, item in ipairs(sideItemButtons) do
                local active = (item.filter == filter)
                item.lbl.TextColor3 = active and C.text or C.sub
                item.icon.TextColor3 = active and C.text or C.sub
            end
            render(true)
        end)
        return b
    end

    local libItems = {
        all = sideItem("All songs", "music", "o", nil),
        new = sideItem("New", "sparkles", "*", "__new"),
        featured = sideItem("Featured", "zap", "!", "__featured"),
    }
    for _, cat in ipairs(catalog.categories or {}) do
        sideItem(cat, "tag", "#", cat)
    end
    search:GetPropertyChangedSignal("Text"):Connect(function() query = search.Text or ""; render(false) end)

    -- ---------------------------------------------------------------- sidebar collapse wiring
    local function setSidebarCollapsed(collapsed)
        isSidebarCollapsed = collapsed
        Settings.data.sidebarCollapsed = collapsed
        saveSettings()

        currentSideW = collapsed and SIDE_COL or SIDE_EXP
        local tInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

        TweenService:Create(sidebar, tInfo, { Size = UDim2.new(0, currentSideW, 1, -NOW_H) }):Play()
        local mainW = panelOpen and (currentSideW + PANEL_W) or currentSideW
        TweenService:Create(main, tInfo, {
            Position = UDim2.new(0, currentSideW, 0, 0),
            Size = UDim2.new(1, -mainW, 1, -NOW_H),
        }):Play()

        brandTitle.Visible = not collapsed
        browseLbl.Visible = not collapsed
        settingsLbl.Visible = not collapsed
        libHeader.Visible = not collapsed
        sideList.ScrollBarThickness = collapsed and 0 or 2

        collapseIcon.Text = collapsed and "[>]" or "[|]"
        setIcon(collapseIcon, collapsed and "panel-left-open" or "panel-left-close", C.sub)
        collapseBtn.Position = collapsed and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(1, -10, 0.5, 0)
        collapseBtn.AnchorPoint = collapsed and Vector2.new(0.5, 0.5) or Vector2.new(1, 0.5)

        brandIcon.Position = UDim2.new(0, collapsed and 34 or 20, 0.5, 0)

        browseBtn.Size = collapsed and UDim2.fromOffset(40, 40) or UDim2.new(1, -20, 0, 40)
        browseBtn.Position = UDim2.new(0, collapsed and 14 or 10, 0, 2)
        browseIcon.Position = collapsed and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 12, 0.5, 0)
        browseIcon.AnchorPoint = collapsed and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5)

        settingsBtn.Size = collapsed and UDim2.fromOffset(40, 40) or UDim2.new(1, -20, 0, 40)
        settingsBtn.Position = UDim2.new(0, collapsed and 14 or 10, 0, 44)
        settingsIcon.Position = collapsed and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 12, 0.5, 0)
        settingsIcon.AnchorPoint = collapsed and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5)

        for _, item in ipairs(sideItemButtons) do
            item.lbl.Visible = not collapsed
            item.btn.Size = collapsed and UDim2.fromOffset(40, 36) or UDim2.new(1, 0, 0, 32)
            item.btn.Position = collapsed and UDim2.new(0.5, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
            item.btn.AnchorPoint = collapsed and Vector2.new(0.5, 0) or Vector2.new(0, 0)
            item.icon.Position = collapsed and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, 8, 0.5, 0)
            item.icon.AnchorPoint = collapsed and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5)
        end

        task.delay(0.24, function() updateColumnLayout() end)
    end
    collapseBtn.MouseButton1Click:Connect(function() setSidebarCollapsed(not isSidebarCollapsed) end)

    -- ---------------------------------------------------------------- settings panel wiring
    local function updateNav()
        if panelOpen then
            settingsBtn.BackgroundTransparency = 0.8
            settingsLbl.TextColor3 = C.text
            browseBtn.BackgroundTransparency = 1
            browseLbl.TextColor3 = C.sub
        else
            settingsBtn.BackgroundTransparency = 1
            settingsLbl.TextColor3 = C.sub
            browseBtn.BackgroundTransparency = 0.8
            browseLbl.TextColor3 = C.text
        end
    end

    local function clearSongHovers()
        for _, ref in pairs(rowRefs) do
            if ref.row then ref.row.BackgroundTransparency = 1 end
            if ref.indexLbl then ref.indexLbl.Visible = true end
            if ref.playIcon then ref.playIcon.Visible = false end
        end
    end

    local function setPanel(open)
        panelOpen = open
        panel.Visible = true
        updateNav()
        if open then clearSongHovers() end

        -- Smoothly resize main area so table columns NEVER clip behind settings panel
        local tInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        local mainW = open and (currentSideW + PANEL_W) or currentSideW
        TweenService:Create(main, tInfo, { Size = UDim2.new(1, -mainW, 1, -NOW_H) }):Play()

        local target = open and UDim2.new(1, -PANEL_W, 0, 0) or UDim2.new(1, 0, 0, 0)
        TweenService:Create(panel, tInfo, { Position = target }):Play()

        if not open then
            task.delay(0.22, function()
                if not panelOpen then panel.Visible = false end
            end)
        end
        task.delay(0.24, function() updateColumnLayout() end)
    end
    gearBtn.MouseButton1Click:Connect(function() setPanel(not panelOpen) end)
    settingsBtn.MouseButton1Click:Connect(function() setPanel(not panelOpen) end)
    panelClose.MouseButton1Click:Connect(function() setPanel(false) end)
    browseBtn.MouseButton1Click:Connect(function()
        setPanel(false)
        filterCat = nil
        search.Text = ""
        render(true)
    end)

    -- ---------------------------------------------------------------- transport controls wiring
    playBtn.MouseButton1Click:Connect(function()
        if not current then
            if #catalog.songs > 0 then
                task.spawn(function() selectSong(catalog.songs[1], true) end)
            end
            return
        end

        if Engine.playing then
            Engine.togglePause()
            setTransportIcon()
            return
        end

        if isDownloading then
            playPendingOnLoad = true
            notify("Starting playback once loaded...")
            return
        end

        if Engine.songName == current.name and #Engine.song > 0 then
            Engine.play()
            setTransportIcon()
            sfx("70452176150315", 0.1)
            return
        end

        task.spawn(function()
            selectSong(current, true)
        end)
    end)

    stopBtn.MouseButton1Click:Connect(function()
        Engine.stop()
        Engine.clear()
        setTransportIcon()
        updateProgress()
        sfx("1524549907", 0.1)
        notify("Stopped")
    end)

    shuffleBtn.MouseButton1Click:Connect(function()
        if #catalog.songs > 0 then
            local nextSong = catalog.songs[math.random(1, #catalog.songs)]
            task.spawn(function() selectSong(nextSong, true) end)
        end
    end)

    bpmMinus.MouseButton1Click:Connect(function() Engine.setBpm(Engine.bpm - 10); updateBpmLabels() end)
    bpmPlus.MouseButton1Click:Connect(function() Engine.setBpm(Engine.bpm + 10); updateBpmLabels() end)
    errMinus.MouseButton1Click:Connect(function() Engine.setErrorMargin(Engine.errorMargin - 0.01); Settings.data.errorMargin = Engine.errorMargin; saveSettings(); updateBpmLabels() end)
    errPlus.MouseButton1Click:Connect(function() Engine.setErrorMargin(Engine.errorMargin + 0.01); Settings.data.errorMargin = Engine.errorMargin; saveSettings(); updateBpmLabels() end)

    midiBadge.MouseButton1Click:Connect(function()
        Settings.data.midiSpoof = not Settings.data.midiSpoof
        Engine.setMidiSpoof(Settings.data.midiSpoof)
        updateMidiBadge()
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

    -- ---------------------------------------------------------------- settings panel controls
    local function toggleSwitch(parent, initial, onChanged)
        local state = initial and true or false
        local sw = make("TextButton", {
            Parent = parent, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -52, 0.5, 0),
            Size = UDim2.fromOffset(42, 24), BackgroundColor3 = state and C.accent or Color3.fromRGB(80, 80, 80),
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, Active = true, ZIndex = 24,
        })
        corner(sw, 12)
        local knob = make("Frame", {
            Parent = sw, Size = UDim2.fromOffset(18, 18),
            Position = state and UDim2.new(1, -22, 0, 3) or UDim2.new(0, 4, 0, 3),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 25,
        })
        corner(knob, 9)

        local function toggle()
            state = not state
            sw.BackgroundColor3 = state and C.accent or Color3.fromRGB(80, 80, 80)
            knob.Position = state and UDim2.new(1, -22, 0, 3) or UDim2.new(0, 4, 0, 3)
            onChanged(state)
        end
        sw.MouseButton1Click:Connect(toggle)
        addTactile(sw, { downScale = 0.92 })
        return sw, toggle
    end

    local sorder = 0
    local function sectionHeader(text)
        sorder = sorder + 1
        local f = make("Frame", { Parent = settingsList, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = sorder, Active = true, ZIndex = 21 })
        label(f, { Position = UDim2.new(0, 4, 0, 8), Size = UDim2.new(1, -8, 0, 18), ZIndex = 21 }, text:upper(), 11, true, C.dim)
        return f
    end

    local function settingRow(title, subtitle, key, iconName, glyph, onToggle)
        sorder = sorder + 1
        local row = make("TextButton", {
            Parent = settingsList, Size = UDim2.new(1, 0, 0, 48),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1,
            BorderSizePixel = 0, LayoutOrder = sorder, Text = "", AutoButtonColor = false,
            Active = true, ZIndex = 22,
        })
        corner(row, 6)
        row.MouseEnter:Connect(function() row.BackgroundTransparency = 0.96 end)
        row.MouseLeave:Connect(function() row.BackgroundTransparency = 1 end)

        local ic = icon(row, iconName, 17, C.sub, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5), glyph)
        ic.ZIndex = 23
        label(row, { Position = UDim2.new(0, 38, 0, 6), Size = UDim2.new(1, -100, 0, 18), ZIndex = 23 }, title, 13, true, C.text)
        label(row, { Position = UDim2.new(0, 38, 0, 24), Size = UDim2.new(1, -100, 0, 15), ZIndex = 23 }, subtitle or "", 11, false, C.dim)
        make("Frame", { Parent = row, Position = UDim2.new(0, 38, 1, -1), Size = UDim2.new(1, -38, 0, 1), BackgroundColor3 = Color3.fromRGB(28, 28, 28), BorderSizePixel = 0, ZIndex = 23 })

        local sw, toggleFn = toggleSwitch(row, Settings.data[key], function(v)
            Settings.data[key] = v
            saveSettings()
            if onToggle then onToggle(v) end
        end)

        row.MouseButton1Click:Connect(toggleFn)
        return row
    end

    sectionHeader("Playback")
    settingRow("Autoplay", "Start playing immediately when a song is selected", "autoplay", "play", ">")
    settingRow("Precise timing", "Frame-perfect rests (uses more CPU)", "secondaryloader", "clock", "o", function(v) Engine.setPreciseTiming(v) end)
    settingRow("Disable fake accidents", "Never intentionally miss or shift notes", "disableaccidents", "shield-check", "v", function(v) Engine.setDisableAccidents(v) end)

    sectionHeader("Table Columns")
    settingRow("Show Artist", "Display artist column in track table", "showColArtist", "user", "@", function() updateColumnLayout() end)
    settingRow("Show Genre", "Display genre category column", "showColGenre", "tag", "#", function() updateColumnLayout() end)
    settingRow("Show BPM", "Display BPM column on the right", "showColBpm", "clock", "~", function() updateColumnLayout() end)

    sectionHeader("Library")
    settingRow("Cache songs", "Save songs to workspace (off = always fetch)", "cachesongs", "box", "[]")
    settingRow("Hide featured", "Hide the Featured library item", "disablefeaturedsongs", "sparkles", "*", function(v) libItems.featured.Visible = not v end)
    settingRow("Always show MIDI spoofer", "Show MIDI toggle outside Piano Rooms", "alwaysshowmidispoofer", "zap", "!", function() updateMidiBadge() end)

    sectionHeader("Interface")
    settingRow("Disable notifications", "Hide the in-window toasts", "disablenotifs", "info", "i")
    settingRow("Mute sound effects", "Silence click and play sounds", "mutesfx", "volume-x", "x")

    local resetBtn = make("TextButton", {
        Parent = settingsList, Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.hover, BorderSizePixel = 0, Text = "Reset to defaults",
        TextColor3 = C.text, TextSize = 12, AutoButtonColor = true, LayoutOrder = 999,
        Active = true, ZIndex = 22,
    })
    corner(resetBtn, 6)
    setFont(resetBtn, Enum.FontWeight.Bold)
    addTactile(resetBtn, { downScale = 0.96 })
    resetBtn.MouseButton1Click:Connect(function()
        for k, v in pairs(DEFAULTS) do Settings.data[k] = v end
        saveSettings()
        notify("Settings reset (reopen script to rebuild)")
    end)

    -- Window Minimize / Close / Dragging
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

    -- Initialize engine and UI states
    Engine.setDisableAccidents(Settings.data.disableaccidents)
    Engine.setPreciseTiming(Settings.data.secondaryloader)
    Engine.setMidiSpoof(Settings.data.midiSpoof)
    Engine.setErrorMargin(Settings.data.errorMargin)
    Settings.data.errorMargin = Engine.errorMargin
    updateMidiBadge()
    libItems.featured.Visible = not Settings.data.disablefeaturedsongs
    updateBpmLabels()
    updateProgress()
    render(false)

    print(string.format("[P1AN0] ui built: parent=%s songs=%d cache=%s autoplay=%s fileapi=%s/%s",
        tostring(gui.Parent), #catalog.songs, tostring(Settings.data.cachesongs), tostring(Settings.data.autoplay),
        tostring(hasRead()), tostring(hasWrite())))
    notify("0M3G4 P1AN0  ·  " .. tostring(#catalog.songs) .. " songs")
end
