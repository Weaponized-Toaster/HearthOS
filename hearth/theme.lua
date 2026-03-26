-- HearthOS  |  hearth/theme.lua
-- ─────────────────────────────────────
-- Cozy-retro color palette and shared draw helpers.

local T = {}

-- ── Color palette ──────────────────────────────────────────────
T.c = {
    -- Desktop
    desk        = colors.brown,
    deskDot     = colors.orange,

    -- Taskbar
    tbar        = colors.orange,
    tbarFg      = colors.black,
    tbarBtn     = colors.brown,
    tbarBtnFg   = colors.yellow,
    tbarAct     = colors.magenta,
    tbarActFg   = colors.white,
    tbarClock   = colors.yellow,
    tbarMenuBg  = colors.white,

    -- Window chrome
    winBg       = colors.black,
    titleIn     = colors.brown,       -- inactive title bar bg
    titleInFg   = colors.lightGray,   -- inactive title bar text
    titleAct    = colors.magenta,     -- active title bar bg
    titleActFg  = colors.white,       -- active title bar text
    closeBtn    = colors.red,
    closeBtnFg  = colors.white,

    -- General text
    text        = colors.white,
    textDim     = colors.lightGray,
    accent      = colors.yellow,
    soft        = colors.pink,

    -- Buttons
    btn         = colors.orange,
    btnFg       = colors.black,

    -- Input fields
    inputBg     = colors.gray,
    inputFg     = colors.white,

    -- Lists
    listSelBg   = colors.orange,
    listSelFg   = colors.black,

    -- File types
    dirFg       = colors.yellow,
    fileFg      = colors.white,

    -- Messenger messages
    msgMe       = colors.cyan,
    msgOther    = colors.pink,
    msgSys      = colors.yellow,

    -- Boot screen
    bootBg      = colors.black,
    bootFg      = colors.orange,
    bootAccent  = colors.yellow,
}

-- ── Draw helpers ───────────────────────────────────────────────

-- Fill a rectangle with a background color (and optional char)
function T.fill(win, x, y, w, h, bg, ch)
    win.setBackgroundColor(bg)
    local row = string.rep(ch or " ", w)
    for dy = 0, h - 1 do
        win.setCursorPos(x, y + dy)
        win.write(row)
    end
end

-- Write text at a specific position with optional fg/bg
function T.put(win, x, y, text, fg, bg)
    if bg then win.setBackgroundColor(bg) end
    if fg then win.setTextColor(fg) end
    win.setCursorPos(x, y)
    win.write(text)
end

-- Write text centered on a given row
function T.center(win, y, text, fg, bg)
    local W = select(1, win.getSize())
    local x = math.floor((W - #text) / 2) + 1
    T.put(win, x, y, text, fg, bg)
end

-- Truncate string with trailing ~ if too long
function T.clip(s, maxLen)
    if #s > maxLen then return s:sub(1, maxLen - 1) .. "~" end
    return s
end

-- Pad or truncate string to exactly len chars
function T.pad(s, len)
    if #s >= len then return s:sub(1, len) end
    return s .. string.rep(" ", len - #s)
end

return T
