-- HearthOS  |  hearth/desktop.lua
-- ─────────────────────────────────────
-- Window manager, taskbar, and desktop renderer.

local T = require("theme")

local D = {}

-- ── Internal state ─────────────────────────────────────────────
D._wins   = {}      -- list of window entries, back-to-front
D._nextId = 1
D._focused = nil
D._SW     = 0       -- screen width
D._SH     = 0       -- screen height
D._DH     = 0       -- desktop height (SH - taskbar)

-- ── Init ───────────────────────────────────────────────────────
function D.init()
    D._SW, D._SH = term.getSize()
    D._DH = D._SH - 1
    D._drawDesktop()
    D._drawTaskbar()
end

-- ── Desktop background ─────────────────────────────────────────
function D._drawDesktop()
    T.fill(term, 1, 1, D._SW, D._DH, T.c.desk)
    -- Subtle dot grid for cozy texture
    term.setBackgroundColor(T.c.desk)
    term.setTextColor(T.c.deskDot)
    for dy = 3, D._DH - 1, 3 do
        for dx = 4, D._SW - 3, 6 do
            term.setCursorPos(dx, dy)
            term.write(".")
        end
    end
end

-- ── Taskbar ────────────────────────────────────────────────────
function D._drawTaskbar()
    local y = D._SH
    T.fill(term, 1, y, D._SW, 1, T.c.tbar)

    -- Launcher button (left)
    T.put(term, 1, y, " * HearthOS ", T.c.tbarBtnFg, T.c.tbarBtn)

    -- Open window buttons (middle)
    local x = 14
    for _, w in ipairs(D._wins) do
        local isAct = (w.id == D._focused)
        local bg    = isAct and T.c.tbarAct or T.c.tbarBtn
        local fg    = isAct and T.c.tbarActFg or T.c.tbarBtnFg
        local label = " " .. T.clip(w.title, 10) .. " "
        if x + #label <= D._SW - 9 then
            T.put(term, x, y, label, fg, bg)
            w._tbX = x
            w._tbW = #label
            x = x + #label + 1
        end
    end

    -- Power button (far right)
    T.put(term, D._SW - 2, y, "[X]", T.c.closeBtn, T.c.tbar)
    -- Clock (left of power button)
    local clock = textutils.formatTime(os.time(), false)
    T.put(term, D._SW - #clock - 4, y, clock, T.c.tbarClock, T.c.tbar)
end

-- ── Window chrome ──────────────────────────────────────────────
function D._drawChrome(entry)
    local isAct = (entry.id == D._focused)
    local tbg   = isAct and T.c.titleAct  or T.c.titleIn
    local tfg   = isAct and T.c.titleActFg or T.c.titleInFg
    local w     = entry.w

    -- Title bar (row 1 of winFull)
    entry.winFull.setBackgroundColor(tbg)
    entry.winFull.setTextColor(tfg)
    entry.winFull.setCursorPos(1, 1)
    entry.winFull.write(T.pad(" " .. T.clip(entry.title, w - 5), w - 3))
    -- Close button
    entry.winFull.setBackgroundColor(T.c.closeBtn)
    entry.winFull.setTextColor(T.c.closeBtnFg)
    entry.winFull.write("[X]")

    -- Clear content area (rows 2..h)
    T.fill(entry.winFull, 1, 2, w, entry.h - 1, T.c.winBg)
end

-- ── Redraw everything ──────────────────────────────────────────
function D.redrawAll()
    D._drawDesktop()
    for _, entry in ipairs(D._wins) do
        D._drawChrome(entry)
        if entry.app and entry.app.draw then
            entry.app.draw(entry.winContent)
        end
    end
    D._drawTaskbar()
end

-- ── Open a window ──────────────────────────────────────────────
-- config: { title, w, h, [x], [y], app }
function D.open(config)
    local id = D._nextId
    D._nextId = D._nextId + 1

    local cw = config.w or 34
    local ch = config.h or 14
    local cx = config.x or math.floor((D._SW - cw) / 2) + 1
    local cy = config.y or math.floor((D._DH - ch) / 2) + 1
    cx = math.max(1, math.min(cx, D._SW - cw + 1))
    cy = math.max(1, math.min(cy, D._DH - ch + 1))

    -- Full window (title bar + content)
    local winFull    = window.create(term.current(), cx, cy, cw, ch, true)
    -- Content sub-window (rows 2..ch inside winFull)
    local winContent = window.create(winFull, 1, 2, cw, ch - 1, true)

    local entry = {
        id = id,  title = config.title or "Window",
        x  = cx,  y = cy,  w = cw,  h = ch,
        winFull = winFull,  winContent = winContent,
        app = config.app,
        dragging = false,  dragOX = 0,  dragOY = 0,
        _tbX = 0,  _tbW = 0,
    }

    table.insert(D._wins, entry)
    D.focus(id, true)   -- silent=true, we'll draw manually

    D._drawChrome(entry)
    if entry.app and entry.app.init then
        entry.app.init(winContent, entry)
    end
    if entry.app and entry.app.draw then
        entry.app.draw(winContent)
    end

    D._drawTaskbar()
    return id
end

-- ── Close a window ─────────────────────────────────────────────
function D.close(id)
    for i, w in ipairs(D._wins) do
        if w.id == id then
            if w.app and w.app.onClose then w.app.onClose() end
            table.remove(D._wins, i)
            if D._focused == id then
                local last = D._wins[#D._wins]
                D._focused = last and last.id or nil
            end
            D.redrawAll()
            return
        end
    end
end

-- ── Bring window to focus ──────────────────────────────────────
-- silent: if true, skip redrawAll (caller will redraw)
function D.focus(id, silent)
    D._focused = id
    for i, w in ipairs(D._wins) do
        if w.id == id then
            table.remove(D._wins, i)
            table.insert(D._wins, w)
            break
        end
    end
    if not silent then D.redrawAll() end
end

-- ── Find window by id ──────────────────────────────────────────
function D.getById(id)
    for _, w in ipairs(D._wins) do
        if w.id == id then return w end
    end
end

-- ── Hit test ───────────────────────────────────────────────────
-- Returns: id, zone ("title"/"close"/"content"), lx, ly (window-local 1-indexed)
function D.hitTest(mx, my)
    for i = #D._wins, 1, -1 do
        local w = D._wins[i]
        if mx >= w.x and mx <= w.x + w.w - 1
        and my >= w.y and my <= w.y + w.h - 1 then
            local lx = mx - w.x + 1
            local ly = my - w.y + 1
            if ly == 1 then
                local zone = (lx >= w.w - 2) and "close" or "title"
                return w.id, zone, lx, ly
            else
                return w.id, "content", lx, ly
            end
        end
    end
end

-- ── Taskbar hit test ───────────────────────────────────────────
function D.hitTaskbar(mx, my)
    if my ~= D._SH then return nil end
    if mx >= 1 and mx <= 13 then return "menu" end
    if mx >= D._SW - 2 and mx <= D._SW then return "power" end
    for _, w in ipairs(D._wins) do
        if w._tbX and mx >= w._tbX and mx < w._tbX + w._tbW then
            return "win", w.id
        end
    end
end

-- ── Master event handler ───────────────────────────────────────
-- Returns "launcher" if the launcher should open, else nil.
function D.handleEvent(ev)
    local name = ev[1]

    if name == "mouse_click" then
        local btn, mx, my = ev[2], ev[3], ev[4]

        -- Taskbar
        local tbZone, tbId = D.hitTaskbar(mx, my)
       local tbZone, tbId = D.hitTaskbar(mx, my)
        if tbZone == "menu"  then return "launcher" end
        if tbZone == "power" then return "power" end
        if tbZone == "win"   then D.focus(tbId); return end

        -- Windows
        local id, zone, lx, ly = D.hitTest(mx, my)
        if not id then return end

        if id ~= D._focused then D.focus(id); return end

        local entry = D.getById(id)
        if zone == "close" then
            D.close(id)
        elseif zone == "title" then
            entry.dragging = true
            entry.dragOX   = mx - entry.x
            entry.dragOY   = my - entry.y
        elseif zone == "content" and entry.app and entry.app.onClick then
            -- ly-1 converts full-window row to content row (title is row 1)
            entry.app.onClick(lx, ly - 1, btn)
            D._drawTaskbar()
        end

    elseif name == "mouse_drag" then
        local btn, mx, my = ev[2], ev[3], ev[4]
        for _, w in ipairs(D._wins) do
            if w.dragging then
                local nx = math.max(1, math.min(mx - w.dragOX, D._SW - w.w + 1))
                local ny = math.max(1, math.min(my - w.dragOY, D._DH - w.h + 1))
                w.x = nx;  w.y = ny
                w.winFull.reposition(nx, ny, w.w, w.h)
                D.redrawAll()
                break
            end
        end

    elseif name == "mouse_up" then
        for _, w in ipairs(D._wins) do w.dragging = false end

    elseif name == "mouse_scroll" then
        local dir, mx, my = ev[2], ev[3], ev[4]
        local id = D.hitTest(mx, my)
        if id then
            local entry = D.getById(id)
            if entry.app and entry.app.onScroll then
                entry.app.onScroll(dir)
                D._drawTaskbar()
            end
        end

    elseif name == "key" then
        local key, held = ev[2], ev[3]
        if D._focused then
            local entry = D.getById(D._focused)
            if entry and entry.app and entry.app.onKey then
                entry.app.onKey(key, held)
                D._drawTaskbar()
            end
        end

    elseif name == "char" then
        if D._focused then
            local entry = D.getById(D._focused)
            if entry and entry.app and entry.app.onChar then
                entry.app.onChar(ev[2])
                D._drawTaskbar()
            end
        end

    elseif name == "rednet_message" then
        local senderId, msg, proto = ev[2], ev[3], ev[4]
        for _, w in ipairs(D._wins) do
            if w.app and w.app.onRednet then
                w.app.onRednet(senderId, msg, proto)
                if w.app.draw then w.app.draw(w.winContent) end
            end
        end
        D._drawTaskbar()

    elseif name == "timer" then
        D._drawTaskbar()
    end
end

return D