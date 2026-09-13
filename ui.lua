-- 0M3G4 P1AN0 || ui.lua
-- Spotify-inspired single-window UI. Transport, seek, BPM, error margin and
-- MIDI-spoof controls all live inside the one window (no separate popup).

return function(Engine, catalog, host, inheritedParent)
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")

    local C = {
        bg      = Color3.fromRGB(18, 18, 18),
        panel   = Color3.fromRGB(24, 24, 24),
        card    = Color3.fromRGB(32, 32, 32),
        hover   = Color3.fromRGB(45, 45, 45),
        accent  = Color3.fromRGB(30, 215, 96),
        text    = Color3.fromRGB(255, 255, 255),
        sub     = Color3.fromRGB(179, 179, 179),
        bar     = Color3.fromRGB(70, 70, 70),
        danger  = Color3.fromRGB(255, 90, 90),
    }

    local function setFont(obj, weight, style)
        pcall(function()
            obj.FontFace = Font.new(
                "rbxasset://fonts/families/GothamSSm.json",
                weight or Enum.FontWeight.Regular,
                style or Enum.FontStyle.Normal
            )
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

    local function stroke(parent, col, th)
        return make("UIStroke", { Color = col or Color3.fromRGB(60, 60, 60), Thickness = th or 1, Parent = parent })
    end

    local function label(parent, props, text, size, bold, color)
        local l = make("TextLabel", props, {})
        l.BackgroundTransparency = 1
        l.Text = text or ""
        l.TextColor3 = color or C.text
        l.TextSize = size or 14
        l.TextXAlignment = props and props.TextXAlignment or Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Center
        l.RichText = false
        setFont(l, bold and Enum.FontWeight.Bold or Enum.FontWeight.Regular)
        l.Parent = parent
        return l
    end

    local function resolveParent()
        local candidates = {}
        if inheritedParent and inheritedParent:IsA("CoreGui") then candidates[#candidates + 1] = function() return inheritedParent end end
        candidates[#candidates + 1] = function() return game:GetService("CoreGui") end
        candidates[#candidates + 1] = function() return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 5) end
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
    if not parentGui then error("[P1AN0] no valid gui parent (CoreGui/gethui/PlayerGui all failed)") end

    local gui = make("ScreenGui", {
        Name = "0M3G4_P1AN0",
        ResetOnSpawn = false,
        Enabled = true,
        DisplayOrder = 1000,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = parentGui,
    })

    -- ------------------------------------------------------------------
    -- floating toggle
    -- ------------------------------------------------------------------
    local toggle = make("TextButton", {
        Name = "toggle",
        Parent = gui,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.4, 0),
        Size = UDim2.new(0, 44, 0, 44),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
        Text = "♫",
        TextColor3 = Color3.fromRGB(0, 0, 0),
        TextSize = 22,
        AutoButtonColor = false,
        Active = true,
    })
    setFont(toggle, Enum.FontWeight.Bold)
    corner(toggle, 22)

    -- ------------------------------------------------------------------
    -- window
    -- ------------------------------------------------------------------
    local W, H = 820, 500
    local frame = make("Frame", {
        Name = "window",
        Parent = gui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, W, 0, H),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
    })
    corner(frame, 14)
    stroke(frame, Color3.fromRGB(45, 45, 45), 1)

    -- top bar
    local top = make("Frame", { Parent = frame, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.panel, BorderSizePixel = 0 })
    label(top, { Position = UDim2.new(0, 18, 0, 0), Size = UDim2.new(0, 300, 1, 0) }, "0M3G4 P1AN0", 17, true, C.accent)
    label(top, { Position = UDim2.new(0, 150, 0, 0), Size = UDim2.new(0, 240, 1, 0) }, string.format("· %d songs", catalog.count or #catalog.songs), 12, false, C.sub)

    local search = make("TextBox", {
        Parent = top,
        Position = UDim2.new(1, -330, 0, 10),
        Size = UDim2.new(0, 250, 0, 26),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = "search songs, artists, tags...",
        PlaceholderColor3 = C.sub,
        Text = "",
        TextColor3 = C.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    corner(search, 13)
    make("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = search })

    local minBtn = make("TextButton", {
        Parent = top,
        Position = UDim2.new(1, -66, 0, 10),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
        Text = "–",
        TextColor3 = C.text,
        TextSize = 18,
        AutoButtonColor = true,
    })
    corner(minBtn, 13)
    local closeBtn = make("TextButton", {
        Parent = top,
        Position = UDim2.new(1, -34, 0, 10),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
        Text = "×",
        TextColor3 = C.text,
        TextSize = 16,
        AutoButtonColor = true,
    })
    corner(closeBtn, 13)

    -- sidebar
    local SB_W = 184
    local side = make("Frame", { Parent = frame, Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(0, SB_W, 1, -46 - 116), BackgroundColor3 = C.panel, BorderSizePixel = 0 })
    local sideList = make("ScrollingFrame", {
        Parent = side,
        Size = UDim2.new(1, -16, 1, -16),
        Position = UDim2.new(0, 8, 0, 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    make("UIListLayout", { Parent = sideList, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
    make("UIPadding", { Parent = sideList, PaddingBottom = UDim.new(0, 8) })

    -- content
    local content = make("Frame", { Parent = frame, Position = UDim2.new(0, SB_W, 0, 46), Size = UDim2.new(1, -SB_W, 1, -46 - 116), BackgroundTransparency = 1 })
    local header = label(content, { Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 20) }, "all songs", 13, true, C.sub)
    local list = make("ScrollingFrame", {
        Parent = content,
        Position = UDim2.new(0, 8, 0, 30),
        Size = UDim2.new(1, -16, 1, -38),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    make("UIListLayout", { Parent = list, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
    make("UIPadding", { Parent = list, PaddingBottom = UDim.new(0, 10) })

    -- now playing bar
    local NOW_H = 116
    local now = make("Frame", { Parent = frame, Position = UDim2.new(0, 0, 1, -NOW_H), Size = UDim2.new(1, 0, 0, NOW_H), BackgroundColor3 = C.panel, BorderSizePixel = 0 })
    make("Frame", { Parent = now, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0 })

    local track = make("Frame", { Parent = now, Position = UDim2.new(0, 20, 0, 12), Size = UDim2.new(1, -40, 0, 6), BackgroundColor3 = C.bar, BorderSizePixel = 0 })
    corner(track, 3)
    local fill = make("Frame", { Parent = track, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0 })
    corner(fill, 3)
    local head = make("Frame", { Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 12, 0, 12), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 2 })
    corner(head, 6)

    local npTitle = label(now, { Position = UDim2.new(0, 20, 0, 30), Size = UDim2.new(0, 260, 0, 20) }, "nothing playing", 15, true, C.text)
    npTitle.TextTruncate = Enum.TextTruncate.AtEnd
    local npSub = label(now, { Position = UDim2.new(0, 20, 0, 50), Size = UDim2.new(0, 260, 0, 16) }, "pick a song", 12, false, C.sub)
    npSub.TextTruncate = Enum.TextTruncate.AtEnd

    local controls = make("Frame", { Parent = now, Position = UDim2.new(0, 292, 0, 30), Size = UDim2.new(1, -312, 0, 50), BackgroundTransparency = 1 })
    make("UIListLayout", { Parent = controls, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })

    local function roundButton(text, size, bg, fg)
        local b = make("TextButton", { Size = UDim2.new(0, size, 0, size), BackgroundColor3 = bg, BorderSizePixel = 0, Text = text, TextColor3 = fg or C.text, TextSize = size * 0.42, AutoButtonColor = true, LayoutOrder = 0 })
        setFont(b, Enum.FontWeight.Bold)
        corner(b, size / 2)
        b.Parent = controls
        return b
    end

    local playBtn = roundButton("▶", 42, C.accent, Color3.fromRGB(0, 0, 0))
    local stopBtn = roundButton("■", 42, C.card, C.text)

    local function stepper(text, width, order)
        local box = make("Frame", { Size = UDim2.new(0, width, 0, 30), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = order })
        corner(box, 15)
        local minus = make("TextButton", { Parent = box, Size = UDim2.new(0, 26, 1, 0), BackgroundTransparency = 1, Text = "−", TextColor3 = C.text, TextSize = 16 })
        local val = label(box, { Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(1, -52, 1, 0), TextXAlignment = Enum.TextXAlignment.Center }, text, 12, true, C.text)
        local plus = make("TextButton", { Parent = box, Position = UDim2.new(1, -26, 0, 0), Size = UDim2.new(0, 26, 1, 0), BackgroundTransparency = 1, Text = "+", TextColor3 = C.text, TextSize = 16 })
        box.Parent = controls
        return box, minus, val, plus
    end

    local _, bpmMinus, bpmVal, bpmPlus = stepper("BPM 120", 100, 10)
    local _, errMinus, errVal, errPlus = stepper("ERR 0%", 96, 11)

    local midiBtn = make("TextButton", { Size = UDim2.new(0, 100, 0, 30), BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "MIDI: off", TextColor3 = C.sub, TextSize = 12, AutoButtonColor = true, LayoutOrder = 12 })
    setFont(midiBtn, Enum.FontWeight.Bold)
    corner(midiBtn, 15)
    midiBtn.Parent = controls

    -- toast
    local toast = label(frame, { Position = UDim2.new(0.5, -190, 1, -160), Size = UDim2.new(0, 380, 0, 30), TextXAlignment = Enum.TextXAlignment.Center }, "", 13, true, C.text)
    toast.BackgroundColor3 = C.card
    toast.BackgroundTransparency = 0.05
    toast.Visible = false
    corner(toast, 8)
    local toastToken = 0
    local function notify(text, color)
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

    -- ------------------------------------------------------------------
    -- song fetching
    -- ------------------------------------------------------------------
    local cache = {}
    local disk = "0M3G4_P1AN0"
    pcall(function() if not isfolder(disk) then makefolder(disk) end end)

    local function safeHttp(url)
        local ok, body = pcall(function() return game:HttpGet(url, true) end)
        if ok and type(body) == "string" and #body > 0 then return body end
        return nil
    end

    local function fetchSong(song)
        if cache[song.file] then return cache[song.file] end
        local path = disk .. "/" .. song.file
        local body = safeHttp(host .. "songs/" .. song.file .. "?v=" .. tostring(song.sha or ""))
        if body then
            cache[song.file] = body
            pcall(function() writefile(path, body) end)
            return body
        end
        local ok, data = pcall(function() return isfile(path) and readfile(path) end)
        if ok and data then
            cache[song.file] = data
            return data
        end
        return nil
    end

    -- ------------------------------------------------------------------
    -- playback wiring
    -- ------------------------------------------------------------------
    local current = nil
    local setPlayingIcon = function()
        playBtn.Text = (Engine.playing and not Engine.paused) and "❚❚" or "▶"
    end

    Engine.onProgress = function(pos, total)
        local p = (total and total > 0) and (pos / total) or 0
        fill.Size = UDim2.new(p, 0, 1, 0)
        head.Position = UDim2.new(p, 0, 0.5, 0)
    end
    Engine.onFinish = function()
        setPlayingIcon()
        notify("finished: " .. tostring(Engine.songName))
    end

    local function updateBpmLabels()
        bpmVal.Text = "BPM " .. tostring(Engine.bpm)
        errVal.Text = string.format("ERR %d%%", math.floor(Engine.errorMargin * 100 + 0.5))
    end

    local function updateNow(song)
        current = song
        npTitle.Text = song.name
        local tags = (#song.cat > 0) and table.concat(song.cat, " · ") or "untagged"
        npSub.Text = string.format("%s BPM  •  %s", tostring(song.bpm), tags)
    end

    local function playSong(song)
        updateNow(song)
        notify("loading " .. song.name .. "...")
        local body = fetchSong(song)
        if not body then
            notify("failed to download " .. song.name, C.danger)
            return
        end
        Engine.setBpm(tonumber(song.bpm) or 120)
        updateBpmLabels()
        local ok, err = Engine.load(body, song.name)
        if not ok then
            notify("song error: " .. tostring(err), C.danger)
            return
        end
        Engine.play()
        setPlayingIcon()
    end

    -- ------------------------------------------------------------------
    -- list rendering
    -- ------------------------------------------------------------------
    local filterCat = nil
    local query = ""

    local function matches(song)
        if filterCat and not table.find(song.cat, filterCat) then return false end
        if query ~= "" then
            local q = query:lower()
            if not (
                song.name:lower():find(q, 1, true)
                or (song.file or ""):lower():find(q, 1, true)
                or (song.bpm and tostring(song.bpm):find(q, 1, true))
                or (function()
                    for _, t in ipairs(song.cat) do if t:lower():find(q, 1, true) then return true end end
                    for _, t in ipairs(song.alts or {}) do if t:lower():find(q, 1, true) then return true end end
                    return false
                end)()
            ) then
                return false
            end
        end
        return true
    end

    local function render()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local shown = 0
        for _, song in ipairs(catalog.songs) do
            if matches(song) then
                shown = shown + 1
                local row = make("TextButton", {
                    Parent = list,
                    Size = UDim2.new(1, 0, 0, 32),
                    BackgroundColor3 = C.card,
                    BackgroundTransparency = 0.35,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                    LayoutOrder = shown,
                })
                corner(row, 6)
                local name = label(row, { Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -220, 1, 0) }, song.name, 13, false, C.text)
                name.TextTruncate = Enum.TextTruncate.AtEnd
                local tagText = (#song.cat > 0) and song.cat[1] or ""
                label(row, { Position = UDim2.new(1, -210, 0, 0), Size = UDim2.new(0, 140, 1, 0) }, tagText, 11, false, C.accent)
                label(row, { Position = UDim2.new(1, -70, 0, 0), Size = UDim2.new(0, 60, 1, 0), TextXAlignment = Enum.TextXAlignment.Right }, tostring(song.bpm), 12, true, C.sub)

                row.MouseEnter:Connect(function() row.BackgroundTransparency = 0 end)
                row.MouseLeave:Connect(function()
                    if current ~= song then row.BackgroundTransparency = 0.35 end
                end)
                row.MouseButton1Click:Connect(function() playSong(song) end)
            end
        end
        header.Text = string.format("%s  ·  %d song%s", filterCat or "all songs", shown, shown == 1 and "" or "s")
    end

    -- sidebar buttons
    local order = 0
    local function catButton(name)
        order = order + 1
        local b = make("TextButton", {
            Parent = sideList,
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            Text = name,
            TextColor3 = C.text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
            LayoutOrder = order,
        })
        setFont(b, Enum.FontWeight.Bold)
        corner(b, 6)
        make("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = b })
        b.MouseEnter:Connect(function() b.BackgroundTransparency = 0 end)
        b.MouseLeave:Connect(function() b.BackgroundTransparency = 0.4 end)
        return b
    end

    local allBtn = catButton("All")
    allBtn.TextColor3 = C.accent
    allBtn.MouseButton1Click:Connect(function()
        filterCat = nil; allBtn.TextColor3 = C.accent; render()
    end)
    for _, cat in ipairs(catalog.categories or {}) do
        local b = catButton(cat)
        b.MouseButton1Click:Connect(function()
            filterCat = cat; allBtn.TextColor3 = C.text; render()
        end)
    end

    search:GetPropertyChangedSignal("Text"):Connect(function()
        query = search.Text or ""
        render()
    end)

    -- ------------------------------------------------------------------
    -- controls
    -- ------------------------------------------------------------------
    playBtn.MouseButton1Click:Connect(function()
        if not Engine.songName then return end
        if Engine.playing then
            Engine.togglePause()
        else
            Engine.play()
        end
        setPlayingIcon()
    end)

    stopBtn.MouseButton1Click:Connect(function()
        Engine.stop()
        Engine.clear()
        setPlayingIcon()
        notify("stopped")
    end)

    bpmMinus.MouseButton1Click:Connect(function() Engine.setBpm(Engine.bpm - 10); updateBpmLabels() end)
    bpmPlus.MouseButton1Click:Connect(function() Engine.setBpm(Engine.bpm + 10); updateBpmLabels() end)
    errMinus.MouseButton1Click:Connect(function() Engine.setErrorMargin(Engine.errorMargin - 0.01); updateBpmLabels() end)
    errPlus.MouseButton1Click:Connect(function() Engine.setErrorMargin(Engine.errorMargin + 0.01); updateBpmLabels() end)

    local midiOn = false
    midiBtn.MouseButton1Click:Connect(function()
        midiOn = not midiOn
        Engine.setMidiSpoof(midiOn)
        midiBtn.Text = midiOn and "MIDI: on" or "MIDI: off"
        midiBtn.TextColor3 = midiOn and C.accent or C.sub
    end)

    -- seek
    local seeking = false
    local function seekFromInput(input)
        local rel = (input.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
        local p = math.clamp(rel, 0, 1)
        fill.Size = UDim2.new(p, 0, 1, 0)
        head.Position = UDim2.new(p, 0, 0.5, 0)
        return p
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            seeking = true
            seekFromInput(input)
        end
    end)
    local UIS = game:GetService("UserInputService")
    UIS.InputChanged:Connect(function(input)
        if seeking and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            seekFromInput(input)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if seeking and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            seeking = false
            Engine.seek(seekFromInput(input))
        end
    end)

    -- window show/hide + drag
    local visible = true
    toggle.MouseButton1Click:Connect(function()
        visible = not visible
        frame.Visible = visible
    end)
    minBtn.MouseButton1Click:Connect(function() frame.Visible = false; visible = false end)
    closeBtn.MouseButton1Click:Connect(function() frame.Visible = false; visible = false end)

    local dragging, dragStart, startPos
    local function dragify(handle, target)
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = target.Position
            end
        end)
        handle.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        handle.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end
    dragify(top, frame)
    dragify(toggle, toggle)

    updateBpmLabels()
    render()
    notify("0M3G4 P1AN0 loaded  •  " .. tostring(catalog.count or #catalog.songs) .. " songs")

    print(string.format("[P1AN0] ui built: gui=%s parent=%s enabled=%s children=%d",
        tostring(gui), tostring(gui.Parent), tostring(gui.Enabled), #gui:GetChildren()))
    print(string.format("[P1AN0] frame parent=%s visible=%s size=%s pos=%s | toggle parent=%s pos=%s",
        tostring(frame.Parent), tostring(frame.Visible), tostring(frame.Size), tostring(frame.Position),
        tostring(toggle.Parent), tostring(toggle.Position)))

    task.spawn(function()
        task.wait(0.5)
        local size = frame.AbsoluteSize
        print(string.format("[P1AN0] diag parent=%s frameAbsSize=%s frameAbsPos=%s", tostring(gui.Parent), tostring(size), tostring(frame.AbsolutePosition)))
        if size.X < 2 or size.Y < 2 then
            local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pg then
                gui.Parent = pg
                print("[P1AN0] frame had no size under " .. tostring(parentGui) .. " ; reparented ui to PlayerGui")
            end
        end
    end)
end
