-- HearthOS  |  hearth/init.lua
-- ─────────────────────────────────────
-- Kernel: boot, app registry, launcher, power menu, event loop.

local T        = require("theme")
local Desktop  = require("desktop")
local Files    = require("apps.files")
local Msg      = require("apps.messenger")
local Notepad  = require("apps.notepad")
local PermData = require("permdata")

-- ── App registry ───────────────────────────────────────────────
local APPS = {
    { name = "Files",     icon = "[~]", desc = "Browse filesystem", new = Files.new,   w = 38, h = 15 },
    { name = "Messenger", icon = "[>]", desc = "Network chat",      new = Msg.new,     w = 40, h = 15 },
    { name = "Notepad",   icon = "[#]", desc = "Text editor",       new = Notepad.new, w = 38, h = 15 },
}

-- ── Update URLs ────────────────────────────────────────────────
-- Must match startup.lua FILES table. perm.dat is intentionally excluded.
local UPDATE_FILES = {
    { "hearth/theme.lua",         "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/theme.lua" },
    { "hearth/desktop.lua",       "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/desktop.lua" },
    { "hearth/permdata.lua",      "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/permdata.lua" },
    { "hearth/init.lua",          "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/init.lua" },
    { "hearth/apps/files.lua",    "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/apps/files.lua" },
    { "hearth/apps/messenger.lua","https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/apps/messenger.lua" },
    { "hearth/apps/notepad.lua",  "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/apps/notepad.lua" },
}

local openIds = {}

local function launchApp(name)
    if openIds[name] then
        Desktop.focus(openIds[name])
        return
    end
    for _, def in ipairs(APPS) do
        if def.name == name then
            local inst = def.new()
            local origClose = inst.onClose
            inst.onClose = function()
                openIds[name] = nil
                if origClose then origClose() end
            end

            -- Inject Files → Notepad callback
            if name == "Files" then
                inst.openInNotepad = function(path)
                    if openIds["Notepad"] then
                        local entry = Desktop.getById(openIds["Notepad"])
                        if entry and entry.app then
                            entry.app.loadFile(path)
                            entry.app.draw(entry.winContent)
                            Desktop.focus(openIds["Notepad"])
                        end
                    else
                        launchApp("Notepad")
                        local entry = Desktop.getById(openIds["Notepad"])
                        if entry and entry.app then
                            entry.app.loadFile(path)
                            entry.app.draw(entry.winContent)
                        end
                    end
                end
            end

            local id = Desktop.open({ title = def.name, w = def.w, h = def.h, app = inst })
            openIds[name] = id
            return
        end
    end
end

-- ── Boot screen ────────────────────────────────────────────────
local function bootScreen()
    local W, H = term.getSize()
    T.fill(term, 1, 1, W, H, T.c.bootBg)
    local logo = {
        " +-+-+-+-+-+-+-+-+-+",
        " |H|e|a|r|t|h|O|S|",
        " +-+-+-+-+-+-+-+-+-+",
    }
    local startY = math.floor((H - 8) / 2)
    for i, line in ipairs(logo) do
        T.center(term, startY + i - 1, line, T.c.bootFg)
    end
    T.center(term, startY + #logo + 1, "v1.0  ~  a cozy computing experience  ~", T.c.bootAccent)
    T.center(term, startY + #logo + 3, "* * *", T.c.bootFg)
    T.center(term, startY + #logo + 5, "Loading...", T.c.textDim)
    os.sleep(1.5)
end

-- ══════════════════════════════════════════════════════════════
-- UPDATER
-- ══════════════════════════════════════════════════════════════
local function runUpdate()
    local W, H = term.getSize()

    local COL = {
        bg     = colors.black,
        fg     = colors.orange,
        accent = colors.yellow,
        dim    = colors.gray,
        ok     = colors.lime,
        err    = colors.red,
        bar_fg = colors.orange,
    }

    local LOGO = {
        " +-+-+-+-+-+-+-+-+-+",
        " |H|e|a|r|t|h|O|S|",
        " +-+-+-+-+-+-+-+-+-+",
    }

    local LOGO_Y   = 2
    local STATUS_Y = LOGO_Y + #LOGO + 2
    local BAR_Y    = STATUS_Y + 2
    local FILE_Y   = BAR_Y + 2
    local HINT_Y   = H - 1

    local function cls()
        term.setBackgroundColor(COL.bg)
        term.clear()
    end

    local function put(x, y, text, fg, bg)
        if bg then term.setBackgroundColor(bg) end
        if fg then term.setTextColor(fg) end
        term.setCursorPos(x, y)
        term.write(text)
    end

    local function center(y, text, fg)
        local x = math.floor((W - #text) / 2) + 1
        put(x, y, text, fg)
    end

    local function hline(y)
        put(1, y, string.rep("-", W), COL.dim, COL.bg)
    end

    local function pad(s, len)
        if #s >= len then return s:sub(1, len) end
        return s .. string.rep(" ", len - #s)
    end

    local function drawProgress(current, total, statusText, fileText, isErr)
        local statusFg = isErr and COL.err or COL.accent
        term.setBackgroundColor(COL.bg)
        term.setTextColor(statusFg)
        term.setCursorPos(1, STATUS_Y)
        term.write(pad(statusText, W))

        local barW   = W - 4
        local filled = math.floor((current / total) * barW)
        put(3, BAR_Y, "[", COL.dim)
        put(4, BAR_Y, string.rep("=", filled), COL.bar_fg, COL.bg)
        put(4 + filled, BAR_Y, string.rep(" ", barW - filled), COL.dim, COL.bg)
        put(4 + barW, BAR_Y, "]", COL.dim)

        local frac = "  " .. current .. " / " .. total .. "  "
        put(math.floor((W - #frac) / 2) + 1, BAR_Y + 1, frac, COL.dim)

        term.setBackgroundColor(COL.bg)
        term.setTextColor(COL.dim)
        term.setCursorPos(1, FILE_Y)
        term.write(pad(fileText, W))
    end

    -- Draw frame
    cls()
    for i, line in ipairs(LOGO) do center(LOGO_Y + i - 1, line, COL.fg) end
    term.setBackgroundColor(COL.bg)
    term.setTextColor(COL.dim)
    put(1, LOGO_Y + #LOGO + 1, pad("   Updater  ~  v1.0", W), COL.dim, COL.bg)
    hline(HINT_Y - 1)
    center(HINT_Y, "perm.dat is safe  ~  data will not be lost", COL.dim)

    -- Check HTTP
    if not http then
        drawProgress(0, #UPDATE_FILES, "ERROR: HTTP is not enabled!", "", true)
        os.pullEvent("key")
        return false
    end

    local total = #UPDATE_FILES
    for i, entry in ipairs(UPDATE_FILES) do
        local dest, url = entry[1], entry[2]
        drawProgress(i - 1, total, "Downloading update...", "-> " .. dest)

        local ok, result = pcall(http.get, url)
        if not ok or not result then
            drawProgress(i, total, "ERROR: Failed to download " .. dest, url, true)
            center(HINT_Y, "Check connection. Press any key.", COL.err)
            os.pullEvent("key")
            return false
        end

        local data = result.readAll()
        result.close()

        local f = fs.open(dest, "w")
        if not f then
            drawProgress(i, total, "ERROR: Could not write " .. dest, "", true)
            os.pullEvent("key")
            return false
        end
        f.write(data)
        f.close()
        os.sleep(0.05)
    end

    drawProgress(total, total, "Update complete!", "", false)

    -- Success screen
    cls()
    for i, line in ipairs(LOGO) do center(LOGO_Y + i - 1, line, COL.fg) end
    hline(LOGO_Y + #LOGO + 1)

    local MSG = {
        "",
        "Update complete!",
        "",
        "Your data is safe  ~  perm.dat untouched",
        "Press any key to reboot into the new version",
        "",
    }
    local startY = LOGO_Y + #LOGO + 2
    for i, line in ipairs(MSG) do
        local fg = (i == 2) and COL.ok
               or  (i == 4) and colors.cyan
               or  COL.accent
        center(startY + i - 1, line, fg)
    end
    hline(H - 1)
    center(H, "HearthOS v1.0", COL.dim)

    os.pullEvent("key")
    return true
end

-- ══════════════════════════════════════════════════════════════
-- LAUNCHER
-- ══════════════════════════════════════════════════════════════
local launcher = {
    open   = false,
    win    = nil,
    search = "",
    W = 32,
}

local function launcherFiltered()
    if #launcher.search == 0 then return APPS end
    local q = launcher.search:lower()
    local out = {}
    for _, app in ipairs(APPS) do
        if app.name:lower():find(q, 1, true) then
            table.insert(out, app)
        end
    end
    return out
end

local function launcherHeight(filtered)
    return 3 + 2 + 1 + #filtered * 2 + 1
end

local function launcherDraw()
    if not launcher.win then return end
    local filtered = launcherFiltered()
    local W = launcher.W
    local H = launcherHeight(filtered)

    launcher.win.reposition(1, select(2, term.getSize()) - 1 - H, W, H)
    T.fill(launcher.win, 1, 1, W, H, T.c.menuBg)

    -- Header
    launcher.win.setBackgroundColor(T.c.tbarAct)
    launcher.win.setTextColor(T.c.tbarActFg)
    launcher.win.setCursorPos(1, 1)
    launcher.win.write(T.pad(" * HearthOS", W))

    T.put(launcher.win, 1, 2, T.pad("   v1.0  ~  cozy computing", W), T.c.textDim, T.c.menuBg)
    T.put(launcher.win, 1, 3, string.rep("-", W), T.c.textDim, T.c.menuBg)

    -- Search bar
    T.put(launcher.win, 2, 4, "Search:", T.c.textDim, T.c.menuBg)
    T.fill(launcher.win, 1, 5, W, 1, T.c.inputBg)
    launcher.win.setBackgroundColor(T.c.inputBg)
    launcher.win.setTextColor(T.c.inputFg)
    launcher.win.setCursorPos(2, 5)
    launcher.win.write(T.clip("> " .. launcher.search .. "_", W - 2))
    T.put(launcher.win, 1, 6, string.rep("-", W), T.c.textDim, T.c.menuBg)

    -- App list
    local rowY = 7
    if #filtered == 0 then
        T.put(launcher.win, 3, rowY, "No apps found~", T.c.textDim, T.c.menuBg)
    else
        for i, app in ipairs(filtered) do
            local isOpen = openIds[app.name] ~= nil
            T.fill(launcher.win, 1, rowY, W, 1, T.c.menuBg)
            T.put(launcher.win, 2, rowY, app.icon .. " ", T.c.soft, T.c.menuBg)
            T.put(launcher.win, 6, rowY, app.name, T.c.accent, T.c.menuBg)
            if isOpen then
                T.put(launcher.win, W - 5, rowY, "[open]", T.c.textDim, T.c.menuBg)
            end
            T.fill(launcher.win, 1, rowY + 1, W, 1, T.c.menuBg)
            T.put(launcher.win, 6, rowY + 1, app.desc, T.c.textDim, T.c.menuBg)
            rowY = rowY + 2
        end
    end

    T.fill(launcher.win, 1, H, W, 1, T.c.menuBg)
end

local function launcherOpen()
    local SH       = select(2, term.getSize())
    local filtered = launcherFiltered()
    local H        = launcherHeight(filtered)
    launcher.open   = true
    launcher.search = ""
    launcher.win    = window.create(term.current(), 1, SH - 1 - H, launcher.W, H, true)

    for row = 1, H do
        launcher.win.setBackgroundColor(T.c.menuBg)
        launcher.win.setCursorPos(1, row)
        launcher.win.write(string.rep(" ", launcher.W))
        os.sleep(0.01)
    end

    launcherDraw()
end

local function launcherClose()
    launcher.open   = false
    launcher.search = ""
    if launcher.win then launcher.win.setVisible(false) end
    launcher.win = nil
    Desktop.redrawAll()
end

local function launcherHandleClick(mx, my)
    if not launcher.open then return false end
    local SH       = select(2, term.getSize())
    local filtered = launcherFiltered()
    local H        = launcherHeight(filtered)
    local ly       = SH - 1 - H
    local W        = launcher.W

    if mx >= 1 and mx <= W and my >= ly and my <= ly + H - 1 then
        local rel = my - ly + 1
        if rel >= 7 then
            local appIdx = math.ceil((rel - 6) / 2)
            if appIdx >= 1 and appIdx <= #filtered then
                launcherClose()
                launchApp(filtered[appIdx].name)
            end
        end
        return true
    else
        launcherClose()
        return true
    end
end

local function launcherHandleChar(ch)
    if not launcher.open then return false end
    launcher.search = launcher.search .. ch
    launcherDraw()
    return true
end

local function launcherHandleKey(key)
    if not launcher.open then return false end
    if key == keys.backspace then
        launcher.search = launcher.search:sub(1, -2)
        launcherDraw()
    elseif key == keys.escape then
        launcherClose()
    elseif key == keys.enter then
        local filtered = launcherFiltered()
        if #filtered == 1 then
            launcherClose()
            launchApp(filtered[1].name)
        end
    end
    return true
end

-- ══════════════════════════════════════════════════════════════
-- POWER MENU
-- ══════════════════════════════════════════════════════════════
local power = { open = false, win = nil }

local POWER_OPTS = {
    { label = "Shutdown", icon = "[!]", fg = colors.red,      action = "shutdown" },
    { label = "Reboot",   icon = "[~]", fg = colors.yellow,   action = "reboot"   },
    { label = "Update",   icon = "[^]", fg = colors.cyan,     action = "update"   },
    { label = "Cancel",   icon = "[.]", fg = colors.lightGray, action = "cancel"  },
}

-- header(1) + id(1) + divider(1) + opts + divider before cancel(1) + pad(1)
local PW = 22
local PH = 1 + 1 + 1 + #POWER_OPTS + 1 + 1

local function powerDraw()
    if not power.win then return end
    T.fill(power.win, 1, 1, PW, PH, T.c.menuBg)

    -- Header
    power.win.setBackgroundColor(T.c.titleAct)
    power.win.setTextColor(T.c.titleActFg)
    power.win.setCursorPos(1, 1)
    power.win.write(T.pad(" [X] Power", PW))

    -- Computer label + ID
    local label = os.getComputerLabel() or ("PC-" .. os.getComputerID())
    local idStr = label .. "  #" .. os.getComputerID()
    T.put(power.win, 2, 2, T.clip(idStr, PW - 2), T.c.textDim, T.c.menuBg)

    -- Divider
    T.put(power.win, 1, 3, string.rep("-", PW), T.c.textDim, T.c.menuBg)

    -- Options
    for i, opt in ipairs(POWER_OPTS) do
        local row = i + 3
        if i == #POWER_OPTS then
            T.put(power.win, 1, row, string.rep("-", PW), T.c.textDim, T.c.menuBg)
            row = row + 1
        end
        T.fill(power.win, 1, row, PW, 1, T.c.menuBg)
        power.win.setBackgroundColor(T.c.menuBg)
        power.win.setTextColor(opt.fg)
        power.win.setCursorPos(2, row)
        power.win.write(opt.icon .. " ")
        power.win.setTextColor(T.c.text)
        power.win.write(opt.label)
    end
end

local function powerOpen()
    local SW, SH = term.getSize()
    local px = SW - PW + 1
    local py = SH - 1 - PH
    power.open = true
    power.win  = window.create(term.current(), px, py, PW, PH, true)

    for row = PH, 1, -1 do
        power.win.setBackgroundColor(T.c.menuBg)
        power.win.setCursorPos(1, row)
        power.win.write(string.rep(" ", PW))
        os.sleep(0.01)
    end

    powerDraw()
end

local function powerClose()
    power.open = false
    if power.win then power.win.setVisible(false) end
    power.win = nil
    Desktop.redrawAll()
end

local function powerHandleClick(mx, my)
    if not power.open then return false end
    local SW, SH = term.getSize()
    local px = SW - PW + 1
    local py = SH - 1 - PH

    if mx >= px and mx <= SW and my >= py and my <= py + PH - 1 then
        local rel = my - py + 1
        for i, opt in ipairs(POWER_OPTS) do
            local row = i + 3
            if i == #POWER_OPTS then row = row + 1 end
            if rel == row then
                powerClose()
                if opt.action == "shutdown" then
                    term.setBackgroundColor(colors.black)
                    term.setTextColor(colors.orange)
                    term.clear()
                    term.setCursorPos(1, 1)
                    print("HearthOS shut down.")
                    print("Run 'hearth/init' to restart.")
                    error("shutdown", 0)
                elseif opt.action == "reboot" then
                    os.reboot()
                elseif opt.action == "update" then
                    local ok = runUpdate()
                    if ok then os.reboot() end
                    -- If update failed, fall back to desktop
                    Desktop.redrawAll()
                end
                return true
            end
        end
        return true
    else
        powerClose()
        return true
    end
end

-- ── Rednet setup ───────────────────────────────────────────────
local function setupRednet()
    for _, side in ipairs({ "top","bottom","left","right","front","back" }) do
        if peripheral.getType(side) == "modem" then
            rednet.open(side)
            return
        end
    end
end

-- ── Main loop ──────────────────────────────────────────────────
local function main()
    bootScreen()
    PermData.init()   -- create perm.dat if it doesn't exist yet
    Desktop.init()
    setupRednet()

    local clockTimer = os.startTimer(1)

    while true do
        local ev = { os.pullEventRaw() }

        if ev[1] == "terminate" then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.orange)
            term.clear()
            term.setCursorPos(1, 1)
            print("HearthOS shut down.")
            print("Run 'hearth/init' to restart.")
            return
        end

        if ev[1] == "char" and launcherHandleChar(ev[2]) then goto continue end
        if ev[1] == "key"  and launcherHandleKey(ev[2])  then goto continue end

        if ev[1] == "mouse_click" then
            if powerHandleClick(ev[3], ev[4])   then goto continue end
            if launcherHandleClick(ev[3], ev[4]) then goto continue end
        end

        if ev[1] == "timer" and ev[2] == clockTimer then
            Desktop.redrawAll()
            if launcher.open then launcherDraw() end
            if power.open    then powerDraw()    end
            clockTimer = os.startTimer(1)
            goto continue
        end

        local result = Desktop.handleEvent(ev)
        if result == "launcher" then
            if launcher.open then launcherClose()
            else launcherOpen() end
        elseif result == "power" then
            if power.open then powerClose()
            else powerOpen() end
        end

        ::continue::
    end
end

main()
