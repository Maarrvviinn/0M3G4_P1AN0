-- 0M3G4 P1AN0 || icons.lua
-- Lucide icons (latte-soft/lucide-roblox) with a sprite-sheet fallback.

return function()
    local I = {}
    local URL = "https://github.com/latte-soft/lucide-roblox/releases/download/0.1.3/lucide-roblox.luau"
    local genv = (getgenv and getgenv()) or _G

    I.Lucide = genv.Lucide
    if not I.Lucide then
        local body
        pcall(function() body = game:HttpGet(URL, true) end)
        if not body then
            local req = (syn and syn.request) or (http and http.request) or request or http_request
            if type(req) == "function" then
                local ok, res = pcall(req, { Url = URL, Method = "GET" })
                if ok and type(res) == "table" then body = res.Body or res.body end
            end
        end
        if body then pcall(function() I.Lucide = loadstring(body)() end) end
        if I.Lucide then genv.Lucide = I.Lucide end
    end

    -- 48px spritesheet rects (fallback when the module can't be fetched)
    I.SPRITES = {
        ["play"]         = {16898613699, 48, 48, 918, 257},
        ["square"]       = {16898613777, 48, 48, 869, 710},
        ["pause"]        = {16898613613, 48, 48, 967, 306},
        ["skip-back"]    = {16898613777, 48, 48, 306, 869},
        ["skip-forward"] = {16898613777, 48, 48, 355, 869},
        ["shuffle"]      = {16898613777, 48, 48, 257, 869},
        ["repeat"]       = {16898613699, 48, 48, 355, 869},
        ["settings"]     = {16898613777, 48, 48, 771, 257},
        ["search"]       = {16898613699, 48, 48, 918, 857},
        ["x"]            = {16898613869, 48, 48, 869, 906},
        ["minus"]        = {16898613613, 48, 48, 771, 196},
        ["plus"]         = {16898613699, 48, 48, 257, 918},
        ["chevron-down"] = {16898612819, 48, 48, 196, 918},
        ["chevron-up"]   = {16898612819, 48, 48, 710, 918},
        ["volume-2"]     = {16898613869, 48, 48, 771, 808},
        ["volume-x"]     = {16898613869, 48, 48, 710, 869},
        ["home"]         = {16898613509, 48, 48, 820, 147},
        ["tag"]          = {16898613777, 48, 48, 967, 906},
        ["clock"]        = {16898613044, 48, 48, 771, 661},
        ["check"]        = {16898612819, 48, 48, 710, 869},
        ["headphones"]   = {16898613509, 48, 48, 306, 869},
        ["music"]        = {16898613613, 48, 48, 355, 820},
        ["list-music"]   = {16898613613, 48, 48, 355, 820},
        ["sparkles"]     = {16898613777, 48, 48, 918, 49},
        ["zap"]          = {16898613869, 48, 48, 918, 906},
        ["refresh-cw"]   = {16898613699, 48, 48, 404, 869},
        ["trash-2"]      = {16898613869, 48, 48, 257, 918},
        ["heart"]        = {16898613509, 48, 48, 306, 869},
        ["info"]         = {16898613509, 48, 48, 612, 869},
        ["sliders"]      = {16898613777, 48, 48, 404, 771},
    }

    function I.get(name)
        if I.Lucide and type(I.Lucide.GetAsset) == "function" then
            local ok, asset = pcall(I.Lucide.GetAsset, name, 48)
            if ok and asset then return asset end
        end
        local raw = I.SPRITES[name]
        if raw then
            return {
                IconName = name,
                Id = raw[1],
                Url = "rbxassetid://" .. raw[1],
                ImageRectSize = Vector2.new(raw[2], raw[3]),
                ImageRectOffset = Vector2.new(raw[4], raw[5]),
            }
        end
        return nil
    end

    function I.new(parent, name, size, color, position, anchor, glyph)
        local asset = I.get(name)
        if asset then
            local img = Instance.new("ImageLabel")
            img.Name = "Icon"
            img.BackgroundTransparency = 1
            img.BorderSizePixel = 0
            img.ScaleType = Enum.ScaleType.Fit
            img.Size = UDim2.fromOffset(size, size)
            if position then img.Position = position end
            if anchor then img.AnchorPoint = anchor end
            img.ImageColor3 = color or Color3.fromRGB(255, 255, 255)
            img.Image = asset.Url
            if asset.ImageRectSize then img.ImageRectSize = asset.ImageRectSize end
            if asset.ImageRectOffset then img.ImageRectOffset = asset.ImageRectOffset end
            img.Parent = parent
            return img
        end
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Icon"
        lbl.BackgroundTransparency = 1
        lbl.BorderSizePixel = 0
        lbl.Size = UDim2.fromOffset(size, size)
        if position then lbl.Position = position end
        if anchor then lbl.AnchorPoint = anchor end
        lbl.Text = glyph or "*"
        lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        lbl.TextSize = size
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.TextYAlignment = Enum.TextYAlignment.Center
        lbl.Parent = parent
        return lbl
    end

    function I.set(img, name, color)
        if not img then return end
        local asset = I.get(name)
        if asset and img:IsA("ImageLabel") then
            img.Image = asset.Url
            if asset.ImageRectSize then img.ImageRectSize = asset.ImageRectSize end
            if asset.ImageRectOffset then img.ImageRectOffset = asset.ImageRectOffset end
        end
        if color then img.ImageColor3 = color end
    end

    return I
end
