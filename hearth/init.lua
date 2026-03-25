-- HearthOS  |  hearth/init.lua
-- ─────────────────────────────────────
-- Kernel: boot, app registry, launcher, power menu, event loop.

local T       = require("theme")
local Desktop = require("desktop")
local Files   = require("apps.files")
local Msg     = require("apps.messenger")
local Notepad = require("apps.notepad")

-- ── App registry ───────────────────────────────────────────────
local APPS = {
    { name = "Files",     icon = "[~]", new = Files.new,   w = 38, h = 15 },
    { name = "Messenger", icon = "[>]", new = Msg.new,     w = 40, h = 15 },
    { name = "Notepad",   icon = "[#]", new = Notepad.new, w = 38, h = 15 },
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
                        -- Reuse existing Notepad window
                        local entry = Desktop.getById(openIds["Notepad"])
                        if entry and entry.app then
                            entry.app.loadFile(path)
                            entry.app.draw(entry.winContent)
                            Desktop.focus(openIds["Notepad"])
                        end
                    else
                        -- Open a new Notepad, then load the file
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

-- ── Launcher ───────────────────────────────────────────────────
local launcher = { open = false, win = nil }

local function launcherDraw()
    if not launcher.win then return end
    local W, H = launcher.win.getSize()
    T.fill(launcher.win, 1, 1, W, H, T.c.tbarBtn)
    launcher.win.setBackgroundColor(T.c.tbarAct)
    launcher.win.setTextColor(T.c.tbarActFg)
    launcher.win.setCursorPos(1, 1)
    launcher.win.write(T.pad(" * Applications", W))
    for i, app in ipairs(APPS) do
        local y  = (i - 1) * 3 + 3
        T.fill(launcher.win, 1, y, W, 2, T.c.tbarBtn)
        T.put(launcher.win, 3, y, app.icon .. " " .. app.name, T.c.accent, T.c.tbarBtn)
        local suffix = openIds[app.name] and " (open)" or ""
        T.put(launcher.win, 5, y + 1, "Click to open" .. suffix, T.c.textDim, T.c.tbarBtn)
    end
end

local function launcherOpen()
    local SH = select(2, term.getSize())
    local lw = 28
    local lh = #APPS * 3 + 3
    local ly = SH - 1 - lh
    launcher.open = true
    launcher.win  = window.create(term.current(), 1, ly, lw, lh, true)
    launcherDraw()
end

local function launcherClose()
    launcher.open = false
    if launcher.win then launcher.win.setVisible(false) end
    launcher.win = nil
    Desktop.redrawAll()
end

local function launcherHandleClick(mx, my)
    if not launcher.open then return false end
    local SH = select(2, term.getSize())
    local lw = 28
    local lh = #APPS * 3 + 3
    local ly = SH - 1 - lh
    if mx >= 1 and mx <= lw and my >= ly and my <= ly + lh - 1 then
        local rel = my - ly + 1
        for i, app in ipairs(APPS) do
            local appY = (i - 1) * 3 + 3
            if rel >= appY and rel <= appY + 1 then
                launcherClose()
                launchApp(app.name)
                return true
            end
        end
        return true
    else
        launcherClose()
        return true
    end
end

-- ── Power menu ─────────────────────────────────────────────────
local power = { open = false, win = nil }
local POWER_OPTS = { "Shutdown", "Reboot", "Cancel" }

local function powerDraw()
    if not power.win then return end
    local W = power.win.getSize()
    T.fill(power.win, 1, 1, W, #POWER_OPTS + 3, T.c.tbarBtn)
    power.win.setBackgroundColor(T.c.tbarAct)
    power.win.setTextColor(T.c.tbarActFg)
    power.win.setCursorPos(1, 1)
    power.win.write(T.pad(" [X] Power", W))
    for i, opt in ipairs(POWER_OPTS) do
        T.put(power.win, 3, i + 2, opt, T.c.accent, T.c.tbarBtn)
    end
end

local function powerOpen()
    local SW, SH = term.getSize()
    local pw = 16
    local ph = #POWER_OPTS + 3
    power.open = true
    power.win  = window.create(term.current(), SW - pw, SH - 1 - ph, pw, ph, true)
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
    local pw = 16
    local ph = #POWER_OPTS + 3
    local px = SW - pw
    local py = SH - 1 - ph
    if mx >= px and mx <= SW and my >= py and my <= py + ph - 1 then
        local rel = my - py + 1
        for i, opt in ipairs(POWER_OPTS) do
            if rel == i + 2 then
                powerClose()
                if opt == "Shutdown" then
                    term.setBackgroundColor(colors.black)
                    term.setTextColor(colors.orange)
                    term.clear()
                    term.setCursorPos(1, 1)
                    print("HearthOS shut down.")
                    print("Run 'hearth/init' to restart.")
                    error("shutdown", 0)
                elseif opt == "Reboot" then
                    os.reboot()
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

        if ev[1] == "mouse_click" then
            if powerHandleClick(ev[3], ev[4])   then goto continue end
            if launcherHandleClick(ev[3], ev[4]) then goto continue end
        end

        if ev[1] == "timer" and ev[2] == clockTimer then
            Desktop.redrawAll()
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