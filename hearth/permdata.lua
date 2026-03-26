-- HearthOS  |  hearth/permdata.lua
-- ─────────────────────────────────────
-- Persistent key=value data store.
-- Survives updates. Never overwritten by the installer or updater.
-- Stored at: hearth/perm.dat

local PermData = {}

local PATH = "hearth/perm.dat"

-- ── Default values ────────────────────────────────────────────
local DEFAULTS = {
    -- Theme / wallpaper
    wallpaper       = "dots",   -- "dots" or "plain"
    theme           = "default",

    -- App window positions (x,y,w,h as comma-separated)
    pos_files       = "",
    pos_messenger   = "",
    pos_notepad     = "",

    -- Bookmarks (comma-separated paths)
    bookmarks       = "/,/hearth,/hearth/apps",

    -- User notes (single line)
    note            = "",
}

-- ── Parse key=value file ──────────────────────────────────────
local function parse(text)
    local t = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = line:match("^%s*(.-)%s*$")  -- trim whitespace
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local k, v = line:match("^([^=]+)=(.*)$")
            if k then t[k:match("^%s*(.-)%s*$")] = v end
        end
    end
    return t
end

-- ── Serialize table to key=value text ────────────────────────
local function serialize(t)
    local lines = {
        "# HearthOS  |  perm.dat",
        "# Persistent data — do not delete!",
        "# This file survives updates.",
        "",
    }
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        table.insert(lines, k .. "=" .. tostring(t[k]))
    end
    return table.concat(lines, "\n") .. "\n"
end

-- ── Load from disk ────────────────────────────────────────────
function PermData.load()
    local data = {}
    -- Start with defaults
    for k, v in pairs(DEFAULTS) do data[k] = v end

    if fs.exists(PATH) and not fs.isDir(PATH) then
        local f = fs.open(PATH, "r")
        if f then
            local parsed = parse(f.readAll())
            f.close()
            -- Overlay parsed values on top of defaults
            for k, v in pairs(parsed) do data[k] = v end
        end
    end

    return data
end

-- ── Save to disk ──────────────────────────────────────────────
function PermData.save(data)
    local f = fs.open(PATH, "w")
    if not f then return false end
    f.write(serialize(data))
    f.close()
    return true
end

-- ── Get a single value (loads fresh each time) ───────────────
function PermData.get(key)
    local data = PermData.load()
    return data[key]
end

-- ── Set a single value and save ───────────────────────────────
function PermData.set(key, value)
    local data = PermData.load()
    data[key] = tostring(value)
    return PermData.save(data)
end

-- ── Init: create perm.dat if it doesn't exist ────────────────
function PermData.init()
    if not fs.exists(PATH) then
        local data = {}
        for k, v in pairs(DEFAULTS) do data[k] = v end
        PermData.save(data)
    end
end

return PermData
