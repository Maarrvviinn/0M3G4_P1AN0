-- 0M3G4 P1AN0 || engine.lua
-- Autoplay engine: records song scripts into an action list, then plays it back.
-- Song scripts use: keypress(keys, beats, bpm), rest(beats, bpm),
-- adjustVelocity(v), pedalDown(), pedalUp(), keysequence16(...), finishedSong()
-- `bpm` and `x` are provided as globals (x = short-note sentinel, like the original).

return function()
    local RunService = game:GetService("RunService")
    local VirtualInputManager = game:GetService("VirtualInputManager")

    local E = {}
    E.song = {}
    E.bpm = 120
    E.errorMargin = 0
    E.midiSpoof = false
    E.preciseTiming = false
    E.playing = false
    E.paused = false
    E.position = 0
    E.totalBeats = 0
    E.songName = nil
    E.onProgress = nil
    E.onFinish = nil
    E.onState = nil

    local STOP = false
    local thread = nil
    local resumeEvent = Instance.new("BindableEvent")
    local env = (getgenv and getgenv()) or _G
    local function safeSet(t, k, v)
        if type(t) == "table" then pcall(function() t[k] = v end) end
    end

    -- ------------------------------------------------------------------
    -- key tables (ported from the original engine)
    -- ------------------------------------------------------------------
    local midiKeyMappings = {
        ["Ctrl+1"]=21, ["Ctrl+2"]=22, ["Ctrl+3"]=23, ["Ctrl+4"]=24, ["Ctrl+5"]=25, ["Ctrl+6"]=26,
        ["Ctrl+7"]=27, ["Ctrl+8"]=28, ["Ctrl+9"]=29, ["Ctrl+0"]=30, ["Ctrl+q"]=31, ["Ctrl+w"]=32,
        ["Ctrl+e"]=33, ["Ctrl+r"]=34, ["Ctrl+t"]=35,
        ["1"]=36, ["!"]=37, ["2"]=38, ["@"]=39, ["3"]=40, ["4"]=41, ["$"]=42, ["5"]=43, ["%"]=44,
        ["6"]=45, ["^"]=46, ["7"]=47, ["8"]=48, ["*"]=49, ["9"]=50, ["("]=51, ["0"]=52,
        ["q"]=53, ["Q"]=54, ["w"]=55, ["W"]=56, ["e"]=57, ["E"]=58, ["r"]=59,
        ["t"]=60, ["T"]=61, ["y"]=62, ["Y"]=63, ["u"]=64, ["i"]=65, ["I"]=66, ["o"]=67, ["O"]=68,
        ["p"]=69, ["P"]=70, ["a"]=71, ["s"]=72, ["S"]=73, ["d"]=74, ["D"]=75, ["f"]=76, ["g"]=77,
        ["G"]=78, ["h"]=79, ["H"]=80, ["j"]=81, ["J"]=82, ["k"]=83, ["l"]=84, ["L"]=85, ["z"]=86,
        ["Z"]=87, ["x"]=88, ["c"]=89, ["C"]=90, ["v"]=91, ["V"]=92, ["b"]=93, ["B"]=94, ["n"]=95,
        ["m"]=96, ["M"]=97, ["Ctrl+u"]=98, ["Ctrl+i"]=99, ["Ctrl+o"]=100, ["Ctrl+p"]=101,
        ["Ctrl+a"]=102, ["Ctrl+s"]=103, ["Ctrl+d"]=104, ["Ctrl+f"]=105, ["Ctrl+g"]=106,
        ["Ctrl+h"]=107, ["Ctrl+j"]=108,
    }

    local midiNumpadMappings = {
        [0]=Enum.KeyCode.KeypadZero, [1]=Enum.KeyCode.KeypadOne, [2]=Enum.KeyCode.KeypadTwo,
        [3]=Enum.KeyCode.KeypadThree, [4]=Enum.KeyCode.KeypadFour, [5]=Enum.KeyCode.KeypadFive,
        [6]=Enum.KeyCode.KeypadSix, [7]=Enum.KeyCode.KeypadSeven, [8]=Enum.KeyCode.KeypadEight,
        [9]=Enum.KeyCode.KeypadNine, [10]=Enum.KeyCode.KeypadMinus, [11]=Enum.KeyCode.KeypadPlus,
    }

    local shiftKeys = {
        "!","@","#","$","%","^","&","*","(",")",
        "Q","W","E","R","T","Y","U","I","O","P",
        "A","S","D","F","G","H","J","K","L","Z",
        "X","C","V","B","N","M",
    }

    local keyMappings = {
        ["1"]=Enum.KeyCode.One, ["!"]=Enum.KeyCode.One, ["2"]=Enum.KeyCode.Two, ["@"]=Enum.KeyCode.Two,
        ["3"]=Enum.KeyCode.Three, ["#"]=Enum.KeyCode.Three, ["4"]=Enum.KeyCode.Four, ["$"]=Enum.KeyCode.Four,
        ["5"]=Enum.KeyCode.Five, ["%"]=Enum.KeyCode.Five, ["6"]=Enum.KeyCode.Six, ["^"]=Enum.KeyCode.Six,
        ["7"]=Enum.KeyCode.Seven, ["&"]=Enum.KeyCode.Seven, ["8"]=Enum.KeyCode.Eight, ["*"]=Enum.KeyCode.Eight,
        ["9"]=Enum.KeyCode.Nine, ["("]=Enum.KeyCode.Nine, ["0"]=Enum.KeyCode.Zero, [")"]=Enum.KeyCode.Zero,
        ["q"]=Enum.KeyCode.Q, ["Q"]=Enum.KeyCode.Q, ["w"]=Enum.KeyCode.W, ["W"]=Enum.KeyCode.W,
        ["e"]=Enum.KeyCode.E, ["E"]=Enum.KeyCode.E, ["r"]=Enum.KeyCode.R, ["R"]=Enum.KeyCode.R,
        ["t"]=Enum.KeyCode.T, ["T"]=Enum.KeyCode.T, ["y"]=Enum.KeyCode.Y, ["Y"]=Enum.KeyCode.Y,
        ["u"]=Enum.KeyCode.U, ["U"]=Enum.KeyCode.U, ["i"]=Enum.KeyCode.I, ["I"]=Enum.KeyCode.I,
        ["o"]=Enum.KeyCode.O, ["O"]=Enum.KeyCode.O, ["p"]=Enum.KeyCode.P, ["P"]=Enum.KeyCode.P,
        ["a"]=Enum.KeyCode.A, ["A"]=Enum.KeyCode.A, ["s"]=Enum.KeyCode.S, ["S"]=Enum.KeyCode.S,
        ["d"]=Enum.KeyCode.D, ["D"]=Enum.KeyCode.D, ["f"]=Enum.KeyCode.F, ["F"]=Enum.KeyCode.F,
        ["g"]=Enum.KeyCode.G, ["G"]=Enum.KeyCode.G, ["h"]=Enum.KeyCode.H, ["H"]=Enum.KeyCode.H,
        ["j"]=Enum.KeyCode.J, ["J"]=Enum.KeyCode.J, ["k"]=Enum.KeyCode.K, ["K"]=Enum.KeyCode.K,
        ["l"]=Enum.KeyCode.L, ["L"]=Enum.KeyCode.L, ["z"]=Enum.KeyCode.Z, ["Z"]=Enum.KeyCode.Z,
        ["x"]=Enum.KeyCode.X, ["X"]=Enum.KeyCode.X, ["c"]=Enum.KeyCode.C, ["C"]=Enum.KeyCode.C,
        ["v"]=Enum.KeyCode.V, ["V"]=Enum.KeyCode.V, ["b"]=Enum.KeyCode.B, ["B"]=Enum.KeyCode.B,
        ["n"]=Enum.KeyCode.N, ["N"]=Enum.KeyCode.N, ["m"]=Enum.KeyCode.M, ["M"]=Enum.KeyCode.M,
    }

    -- ------------------------------------------------------------------
    -- input primitives
    -- ------------------------------------------------------------------
    local function preciseWait(seconds)
        local start = os.clock()
        while os.clock() - start < seconds do
            if seconds - (os.clock() - start) > 0.015 then
                RunService.Heartbeat:Wait()
            end
        end
    end

    local function noteHoldWait(beats, bpm, shorts)
        local waittime, randomOff
        if not shorts then
            local noteTime = (beats / bpm) * 60
            local maxRan = noteTime * 0.4
            randomOff = math.random() * maxRan
            waittime = noteTime * 0.9 - randomOff
            if E.errorMargin ~= 0 then
                local extraSpread = noteTime * E.errorMargin * 2
                waittime = waittime + (math.random() * 2 - 1) * extraSpread
            end
        else
            local beatDuration = 60 / bpm
            local safeCeiling = beatDuration / 6
            local baseMin = 0.01
            local baseMax = math.max(0.1, safeCeiling)
            waittime = baseMin + math.random() * (baseMax - baseMin)
        end
        preciseWait(waittime)
    end

    local function triggerPress(key, beats, bpm, shift, ctrlRequired)
        if not keyMappings[key] and not midiKeyMappings[key] then return end
        local shiftApplied = false
        local shorts = type(beats) ~= "number"
        local digit1, digit2, digit3, digit4, midiVel

        if E.midiSpoof then
            digit1 = math.floor(midiKeyMappings[key] / 12)
            digit2 = math.floor(midiKeyMappings[key] % 12)
            midiVel = vel and math.floor(vel * 127) or 64
            digit3 = math.floor(midiVel / 12)
            digit4 = math.floor(midiVel % 12)
        end

        if E.errorMargin ~= 0 and math.random() < 0.5 then
            task.wait((math.random() * 0.5 - 0.25) * E.errorMargin)
        end

        if not E.midiSpoof then
            if shift then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
            end
            if not E.disableAccidents then
                local agf = E.errorMargin * 100
                if math.random(1, 1000) <= agf then
                    VirtualInputManager:SendKeyEvent(not shift, Enum.KeyCode.LeftShift, false, game)
                    shiftApplied = true
                end
            end
            if ctrlRequired then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
            end
            VirtualInputManager:SendKeyEvent(true, keyMappings[key], false, game)
            if ctrlRequired then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
            end
            if shiftApplied and not shift then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
                shiftApplied = false
            end
            if shift then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
            end
            noteHoldWait(beats, bpm, shorts)
            VirtualInputManager:SendKeyEvent(false, keyMappings[key], false, game)
        else
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.KeypadMultiply, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.KeypadMultiply, false, game)
            for _, d in ipairs({ digit1, digit2, digit3, digit4 }) do
                VirtualInputManager:SendKeyEvent(true, midiNumpadMappings[d], false, game)
                VirtualInputManager:SendKeyEvent(false, midiNumpadMappings[d], false, game)
            end
            noteHoldWait(beats, bpm, shorts)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.KeypadMultiply, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.KeypadMultiply, false, game)
            VirtualInputManager:SendKeyEvent(true, midiNumpadMappings[digit1], false, game)
            VirtualInputManager:SendKeyEvent(false, midiNumpadMappings[digit1], false, game)
            VirtualInputManager:SendKeyEvent(true, midiNumpadMappings[digit2], false, game)
            VirtualInputManager:SendKeyEvent(false, midiNumpadMappings[digit2], false, game)
            VirtualInputManager:SendKeyEvent(true, midiNumpadMappings[0], false, game)
            VirtualInputManager:SendKeyEvent(false, midiNumpadMappings[0], false, game)
            VirtualInputManager:SendKeyEvent(true, midiNumpadMappings[0], false, game)
            VirtualInputManager:SendKeyEvent(false, midiNumpadMappings[0], false, game)
        end
    end

    function pressKey(keys, beats, bpm, isChord)
        if STOP then return end
        local shiftRequired, nonShift, toPressMidi = {}, {}, {}
        local ctrlRequired = false

        if E.midiSpoof then
            if keys:sub(1, 5) == "Ctrl+" then
                table.insert(toPressMidi, keys)
            else
                for i = 1, #keys do table.insert(toPressMidi, keys:sub(i, i)) end
            end
            for _, key in ipairs(toPressMidi) do
                coroutine.wrap(function() triggerPress(key, beats, bpm, false) end)()
                if isChord and E.errorMargin ~= 0 and math.random() < 0.5 then
                    task.wait((math.random() - 0.5) * E.errorMargin)
                end
            end
        else
            if keys:sub(1, 5) == "Ctrl+" then
                ctrlRequired = true
                keys = keys:sub(6)
            end
            if not ctrlRequired then
                for i = 1, #keys do
                    local key = keys:sub(i, i)
                    table.insert(table.find(shiftKeys, key) and shiftRequired or nonShift, key)
                end
            else
                for i = 1, #keys do
                    table.insert(nonShift, keys:sub(i, i))
                end
            end
            for _, key in ipairs(nonShift) do
                coroutine.wrap(function() triggerPress(key, beats, bpm, false, ctrlRequired) end)()
                if isChord and E.errorMargin ~= 0 and math.random() < 0.5 then
                    task.wait((math.random() - 0.5) * E.errorMargin)
                end
            end
            for _, key in ipairs(shiftRequired) do
                coroutine.wrap(function() triggerPress(key, beats, bpm, true, ctrlRequired) end)()
                if isChord and E.errorMargin ~= 0 and math.random() < 0.5 then
                    task.wait((math.random() - 0.5) * E.errorMargin)
                end
            end
            if ctrlRequired then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
            end
        end
    end
    safeSet(env, "pressKey", pressKey)

    local function adjustVelocitytrigger(velo)
        if STOP then return end
        if E.midiSpoof then
            vel = velo
        else
            local velocityMap = "58qrupdhl"
            velo = math.clamp(velo, 0, 1)
            local topress
            if velo < 0.27 then
                topress = "2"
            elseif velo >= 0.88 then
                topress = "c"
            else
                local index = math.floor((velo - 0.27) / 0.61 * (#velocityMap - 2)) + 2
                topress = velocityMap:sub(index, index)
            end
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftAlt, false, game)
            VirtualInputManager:SendKeyEvent(true, keyMappings[topress], false, game)
            VirtualInputManager:SendKeyEvent(false, keyMappings[topress], false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftAlt, false, game)
        end
    end

    -- ------------------------------------------------------------------
    -- recorders (installed as globals so song scripts can call them)
    -- ------------------------------------------------------------------
    local function rec(t) E.song[#E.song + 1] = t end

    local function doKeypress(keys, beats)
        local last = E.song[#E.song]
        if last and last.type == "keypress" and last.beats == beats
            and keys:sub(1, 5) ~= "Ctrl+" and last.keys:sub(1, 5) ~= "Ctrl+" then
            last.keys = last.keys .. keys
            last.mergeCount = (last.mergeCount or 1) + 1
        else
            rec({ type = "keypress", keys = keys, beats = beats, mergeCount = 1 })
        end
    end
    local function doRest(beats) rec({ type = "rest", beats = beats }) end
    local function doVel(v) rec({ type = "adjustVelocity", vel = v }) end
    local function doPedalDown() rec({ type = "pedalDown" }) end
    local function doPedalUp() rec({ type = "pedalUp" }) end
    local function doFinished() rec({ type = "finishedSong" }) end

    -- dedicated environment for the song chunk (works even when loadstring sandboxes chunks)
    local songEnv = setmetatable({}, { __index = env })
    songEnv.keypress = doKeypress
    songEnv.rest = doRest
    songEnv.adjustVelocity = doVel
    songEnv.pedalDown = doPedalDown
    songEnv.pedalUp = doPedalUp
    songEnv.keysequence16 = doKeypress
    songEnv.finishedSong = doFinished
    songEnv.bpm = E.bpm
    songEnv.x = "short"

    -- also expose globally for non-sandboxed executors
    safeSet(env, "keypress", doKeypress)
    safeSet(env, "rest", doRest)
    safeSet(env, "adjustVelocity", doVel)
    safeSet(env, "pedalDown", doPedalDown)
    safeSet(env, "pedalUp", doPedalUp)
    safeSet(env, "keysequence16", doKeypress)
    safeSet(env, "finishedSong", doFinished)
    safeSet(env, "bpm", E.bpm)
    safeSet(env, "x", "short")

    -- ------------------------------------------------------------------
    -- playback
    -- ------------------------------------------------------------------
    local function totalBeats()
        local t = 0
        for _, a in ipairs(E.song) do
            if a.type == "rest" then t = t + a.beats end
        end
        return t
    end

    local function sleep(seconds)
        local remaining = seconds
        local last = os.clock()
        while remaining > 0 do
            if STOP then return false end
            while E.paused do
                resumeEvent.Event:Wait()
                last = os.clock()
                if STOP then return false end
            end
            RunService.Heartbeat:Wait()
            local now = os.clock()
            remaining = remaining - (now - last)
            last = now
        end
        return true
    end

    local function indexAtBeat(target)
        local acc, idx = 0, 1
        for i, a in ipairs(E.song) do
            if a.type == "rest" then
                if acc + a.beats >= target then idx = i break end
                acc = acc + a.beats
            end
        end
        return idx, acc
    end

    local function run(startIndex)
        E.playing = true
        for i = startIndex, #E.song do
            if STOP then break end
            local a = E.song[i]
            if a.type == "keypress" then
                local isChord = (a.mergeCount or 1) > 1
                coroutine.wrap(function() pressKey(a.keys, a.beats, E.bpm, isChord) end)()
            elseif a.type == "rest" then
                local secs = (a.beats / E.bpm) * 60
                if E.preciseTiming then
                    if STOP then break end
                    preciseWait(secs)
                    if STOP then break end
                else
                    if not sleep(secs) then break end
                end
                E.position = E.position + a.beats
                if E.onProgress then E.onProgress(E.position, E.totalBeats) end
            elseif a.type == "adjustVelocity" then
                adjustVelocitytrigger(a.vel)
            elseif a.type == "pedalDown" then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            elseif a.type == "pedalUp" then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            elseif a.type == "finishedSong" then
                break
            end
        end
        E.playing = false
        STOP = true
        if E.onState then E.onState("finish") end
        if E.onFinish then E.onFinish() end
    end

    function E.load(scriptText, name)
        E.stop()
        E.song = {}
        E.songName = name
        safeSet(env, "bpm", E.bpm)
        songEnv.bpm = E.bpm
        safeSet(env, "x", "short")
        if _G and type(_G) == "table" then
            pcall(function()
                _G.bpm = E.bpm
                _G.x = "short"
                _G.keypress = doKeypress
                _G.rest = doRest
                _G.adjustVelocity = doVel
                _G.pedalDown = doPedalDown
                _G.pedalUp = doPedalUp
                _G.keysequence16 = doKeypress
                _G.finishedSong = doFinished
            end)
        end
        local rawCompile = (getgenv and getgenv().loadstring) or (env and env.loadstring) or loadstring or (getfenv and getfenv().loadstring) or load
        local function safeCompile(code, chunkName)
            if type(rawCompile) ~= "function" then return nil, "no compile function available" end
            local ok, res = pcall(rawCompile, code, chunkName)
            if ok and res then return res end
            local ok2, res2 = pcall(rawCompile, code)
            if ok2 and res2 then return res2 end
            return nil, tostring(res or res2 or "compile failed")
        end

        local fn, err
        if type(scriptText) == "function" then
            fn = scriptText
            if setfenv then pcall(setfenv, fn, songEnv) end
            local ok, runErr = pcall(fn)
            if not ok then return false, tostring(runErr) end
        elseif type(scriptText) == "string" then
            -- Wrap in a closure that receives recorders directly as local arguments.
            -- This completely bypasses any executor sandbox or broken setfenv in Luau.
            local wrapped = "return function(keypress, rest, adjustVelocity, pedalDown, pedalUp, keysequence16, finishedSong, bpm, x)\n"
                .. scriptText
                .. "\nend"
            fn, err = safeCompile(wrapped, "P1AN0_SONG")
            if fn then
                local okF, chunkFn = pcall(fn)
                if okF and type(chunkFn) == "function" then
                    if setfenv then pcall(setfenv, chunkFn, songEnv) end
                    local ok, runErr = pcall(chunkFn, doKeypress, doRest, doVel, doPedalDown, doPedalUp, doKeypress, doFinished, E.bpm, "short")
                    if not ok then return false, tostring(runErr) end
                else
                    if setfenv then pcall(setfenv, fn, songEnv) end
                    local ok, runErr = pcall(fn)
                    if not ok then return false, tostring(runErr) end
                end
            else
                -- Fallback to compiling unwrapped script
                fn, err = safeCompile(scriptText, "P1AN0_SONG")
                if not fn then return false, tostring(err) end
                if setfenv then pcall(setfenv, fn, songEnv) end
                local ok, runErr = pcall(fn)
                if not ok then return false, tostring(runErr) end
            end
        else
            return false, "invalid song script payload: expected string or function"
        end
        E.totalBeats = totalBeats()
        print(string.format("[P1AN0] loaded '%s': %d actions, %.2f beats, %.1fs duration",
            tostring(name or "song"), #E.song, E.totalBeats, E.duration()))
        return true
    end

    function E.play(fromBeat)
        if E.playing then
            if E.paused then E.resume() end
            return
        end
        if #E.song == 0 then
            print("[P1AN0] cannot play: #E.song is 0")
            return
        end
        STOP = false
        E.paused = false
        E.totalBeats = totalBeats()
        local idx, acc = indexAtBeat(fromBeat or 0)
        E.position = acc
        if E.onProgress then E.onProgress(E.position, E.totalBeats) end
        print(string.format("[P1AN0] E.play: starting %d actions at index %d (beat %.1f / %.1f)", #E.song, idx, acc, E.totalBeats))
        thread = task.spawn(function() run(idx) end)
        if E.onState then E.onState("play") end
    end

    function E.pause()
        if not E.playing then return end
        E.paused = true
        if E.onState then E.onState("pause") end
    end

    function E.resume()
        if not E.playing then return end
        E.paused = false
        resumeEvent:Fire()
        if E.onState then E.onState("play") end
    end

    function E.togglePause()
        if E.paused then E.resume() else E.pause() end
        return E.paused
    end

    function E.stop()
        STOP = true
        E.playing = false
        E.paused = false
        resumeEvent:Fire()
        if thread then pcall(task.cancel, thread) end
        thread = nil
        if E.onState then E.onState("stop") end
    end

    function E.seek(percent)
        if #E.song == 0 then return end
        local target = math.clamp(percent, 0, 1) * (E.totalBeats > 0 and E.totalBeats or totalBeats())
        local wasPlaying = E.playing and not E.paused
        E.stop()
        task.wait()
        local idx, acc = indexAtBeat(target)
        E.position = acc
        if E.onProgress then E.onProgress(E.position, E.totalBeats) end
        if wasPlaying then
            STOP = false
            E.paused = false
            E.playing = true
            thread = task.spawn(function() run(idx) end)
        end
    end

    function E.setBpm(n)
        E.bpm = math.clamp(math.floor(n), 10, 1000)
        env.bpm = E.bpm
        songEnv.bpm = E.bpm
        return E.bpm
    end

    function E.setErrorMargin(v)
        E.errorMargin = math.clamp(v, 0, 1)
        return E.errorMargin
    end

    function E.setMidiSpoof(v)
        E.midiSpoof = v and true or false
        return E.midiSpoof
    end

    function E.setDisableAccidents(v)
        E.disableAccidents = v and true or false
    end

    function E.setPreciseTiming(v)
        E.preciseTiming = v and true or false
    end

    function E.duration()
        if E.totalBeats <= 0 then return 0 end
        return (E.totalBeats / E.bpm) * 60
    end

    function E.positionSeconds()
        return (E.position / E.bpm) * 60
    end

    E.clear = function()
        E.stop()
        E.song = {}
        E.totalBeats = 0
        E.position = 0
        E.songName = nil
    end

    return E
end
