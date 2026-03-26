-- HearthOS  |  startup.lua
-- ─────────────────────────────────────
-- Self-modifying installer + boot script.
-- On first run: downloads and installs HearthOS, then marks itself as installed.
-- On subsequent runs: boots HearthOS directly.
--
-- !! DO NOT EDIT THIS LINE MANUALLY !!
local installed = 0
-- !! DO NOT EDIT THE LINE ABOVE     !!

-- ══════════════════════════════════════════════════════════════
-- BOOT (already installed)
-- ══════════════════════════════════════════════════════════════
if installed == 1 then
    local ok, err = pcall(shell.run, "hearth/init")
    if not ok then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.red)
        term.clear()
        term.setCursorPos(1, 1)
        print("HearthOS crashed on startup!")
        print("")
        print(tostring(err))
        print("")
        print("Press any key to exit.")
        os.pullEvent("key")
    end
    return
end

-- ══════════════════════════════════════════════════════════════
-- INSTALLER (first run only)
-- ══════════════════════════════════════════════════════════════

-- ── Files to download ─────────────────────────────────────────
-- { destination path, raw URL }
local FILES = {
    { "hearth/theme.lua",         "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/theme.lua" },
    { "hearth/desktop.lua",       "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/desktop.lua" },
    { "hearth/init.lua",          "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/init.lua" },
    { "hearth/apps/files.lua",    "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/apps/files.lua" },
    { "hearth/apps/messenger.lua","https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/apps/messenger.lua" },
    { "hearth/apps/notepad.lua",  "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/apps/notepad.lua" },
    {
        "hearth/permdata.lua",
        "https://raw.githubusercontent.com/Weaponized-Toaster/HearthOS/refs/heads/main/hearth/permdata.lua"
    },
    }

-- ── Colors ────────────────────────────────────────────────────
local COL = {
    bg      = colors.black,
    fg      = colors.orange,
    accent  = colors.yellow,
    dim     = colors.gray,
    soft    = colors.pink,
    ok      = colors.lime,
    err     = colors.red,
    bar_bg  = colors.gray,
    bar_fg  = colors.orange,
}

local SW, SH = term.getSize()

-- ── Draw helpers ──────────────────────────────────────────────
local function cls()
    term.setBackgroundColor(COL.bg)
    term.clear()
end

local function put(x, y, text, fg, bg)
    if bg  then term.setBackgroundColor(bg)  end
    if fg  then term.setTextColor(fg)        end
    term.setCursorPos(x, y)
    term.write(text)
end

local function center(y, text, fg, bg)
    local x = math.floor((SW - #text) / 2) + 1
    put(x, y, text, fg, bg)
end

local function hline(y, fg)
    put(1, y, string.rep("-", SW), fg or COL.dim, COL.bg)
end

local function pad(s, len)
    if #s >= len then return s:sub(1, len) end
    return s .. string.rep(" ", len - #s)
end

-- ── Draw the static installer frame ───────────────────────────
local LOGO = {
    " +-+-+-+-+-+-+-+-+-+",
    " |H|e|a|r|t|h|O|S|",
    " +-+-+-+-+-+-+-+-+-+",
}

local LOGO_Y    = 2
local STATUS_Y  = LOGO_Y + #LOGO + 2
local BAR_Y     = STATUS_Y + 2
local FILE_Y    = BAR_Y + 2
local HINT_Y    = SH - 1

local function drawFrame()
    cls()

    -- Logo
    for i, line in ipairs(LOGO) do
        center(LOGO_Y + i - 1, line, COL.fg)
    end

    -- Subtitle
    center(LOGO_Y + #LOGO + 1, "Installer  ~  v1.0", COL.dim)

    -- Hint at bottom
    hline(HINT_Y - 1, COL.dim)
    center(HINT_Y, "Please wait while HearthOS is installed...", COL.dim)
end

-- ── Progress bar ──────────────────────────────────────────────
local function drawProgress(current, total, statusText, fileText, isErr)
    -- Status text
    local statusFg = isErr and COL.err or COL.accent
    term.setBackgroundColor(COL.bg)
    term.setTextColor(statusFg)
    term.setCursorPos(1, STATUS_Y)
    term.write(pad(statusText, SW))

    -- Bar background
    local barW   = SW - 4
    local filled = math.floor((current / total) * barW)

    put(3, BAR_Y, "[", COL.dim)
    put(4, BAR_Y, string.rep("=", filled), COL.bar_fg, COL.bg)
    put(4 + filled, BAR_Y, string.rep(" ", barW - filled), COL.dim, COL.bg)
    put(4 + barW, BAR_Y, "]", COL.dim)

    -- Fraction
    local frac = "  " .. current .. " / " .. total .. "  "
    put(math.floor((SW - #frac) / 2) + 1, BAR_Y + 1, frac, COL.dim)

    -- Current file
    term.setBackgroundColor(COL.bg)
    term.setTextColor(COL.dim)
    term.setCursorPos(1, FILE_Y)
    term.write(pad(fileText, SW))
end

-- ── Mark self as installed ────────────────────────────────────
local function markInstalled()
    local f = fs.open("startup.lua", "r")
    if not f then return false end
    local contents = f.readAll()
    f.close()

    -- Replace the flag line in place
    local newContents = contents:gsub(
        "local installed = 0",
        "local installed = 1",
        1
    )

    if newContents == contents then return false end  -- nothing changed, bail

    local out = fs.open("startup.lua", "w")
    if not out then return false end
    out.write(newContents)
    out.close()
    return true
end

-- ── Run the install ───────────────────────────────────────────
local function install()
    drawFrame()

    -- Check HTTP
    if not http then
        drawProgress(0, #FILES, "ERROR: HTTP is not enabled!", "", true)
        center(HINT_Y, "Enable HTTP in ComputerCraft config and try again.", COL.err)
        os.pullEvent("key")
        return false
    end

    -- Create folders
    fs.makeDir("hearth")
    fs.makeDir("hearth/apps")

    local total = #FILES

    for i, entry in ipairs(FILES) do
        local dest, url = entry[1], entry[2]

        drawProgress(i - 1, total,
            "Downloading files...",
            "-> " .. dest)

        -- Download
        local ok, result = pcall(http.get, url)
        if not ok or not result then
            drawProgress(i, total,
                "ERROR: Failed to download " .. dest,
                url, true)
            center(HINT_Y, "Check your URLs and HTTP settings. Press any key.", COL.err)
            os.pullEvent("key")
            return false
        end

        local data = result.readAll()
        result.close()

        -- Write file
        local f = fs.open(dest, "w")
        if not f then
            drawProgress(i, total,
                "ERROR: Could not write " .. dest,
                "", true)
            center(HINT_Y, "Check disk space. Press any key.", COL.err)
            os.pullEvent("key")
            return false
        end
        f.write(data)
        f.close()

        -- Small delay so the progress bar is visible
        os.sleep(0.05)
    end

    drawProgress(total, total, "All files installed!", "", false)
    return true
end

-- ── Completion screen ─────────────────────────────────────────
local function completionScreen()
    cls()

    for i, line in ipairs(LOGO) do
        center(LOGO_Y + i - 1, line, COL.fg)
    end

    hline(LOGO_Y + #LOGO + 1, COL.dim)

    local MSG = {
        "",
        "Installation complete!",
        "",
        "Press any key to restart and enter",
        "the cozy world of HearthOS  ~  * *",
        "",
    }

    local startY = LOGO_Y + #LOGO + 2
    for i, line in ipairs(MSG) do
        local fg = (i == 2) and COL.ok
               or  (i == 5) and COL.soft
               or  COL.accent
        center(startY + i - 1, line, fg)
    end

    hline(SH - 1, COL.dim)
    center(SH, "HearthOS v1.0", COL.dim)

    os.pullEvent("key")
end

-- ── Entry point ───────────────────────────────────────────────
local ok = install()

if ok then
    markInstalled()
    completionScreen()
    os.reboot()
else
    -- Install failed — don't mark as installed, let them try again
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    term.clear()
    term.setCursorPos(1,1)
    print("Installation failed. Fix the errors above and reboot to try again.")
end
