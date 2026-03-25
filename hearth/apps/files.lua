-- HearthOS  |  hearth/apps/files.lua
-- ─────────────────────────────────────
-- File browser. Double-click a file to open in Notepad.

local T = require("theme")
local Files = {}

function Files.new()
    local self = {
        path          = "/",
        entries       = {},
        scroll        = 0,
        selected      = 1,
        winRef        = nil,
        W = 0,  H = 0,
        lastClickIdx  = nil,
        lastClickTime = 0,
        openInNotepad = nil,   -- injected by init.lua
    }

    local function loadDir(path)
        self.path     = path
        self.entries  = {}
        self.scroll   = 0
        self.selected = 1

        if path ~= "/" then
            table.insert(self.entries, { name = "..", isDir = true, isUp = true })
        end

        local names = fs.list(path)
        table.sort(names)

        for _, name in ipairs(names) do
            local full = fs.combine(path, name)
            if fs.isDir(full) then
                table.insert(self.entries, { name = name, isDir = true })
            end
        end
        for _, name in ipairs(names) do
            local full = fs.combine(path, name)
            if not fs.isDir(full) then
                table.insert(self.entries, { name = name, isDir = false, size = fs.getSize(full) })
            end
        end
    end

    local function navigate()
        local e = self.entries[self.selected]
        if not e or not e.isDir then return end
        if e.isUp then
            local parent = fs.getDir(self.path)
            loadDir((parent == "" or parent == nil) and "/" or parent)
        else
            loadDir(fs.combine(self.path, e.name))
        end
    end

    local function clampScroll()
        local listH = self.H - 2
        self.scroll = math.max(0, math.min(self.scroll, math.max(0, #self.entries - listH)))
        if self.selected < self.scroll + 1 then self.scroll = self.selected - 1 end
        if self.selected > self.scroll + listH then self.scroll = self.selected - listH end
    end

    function self.init(win, entry)
        self.winRef = win
        self.W, self.H = win.getSize()
        loadDir("/")
    end

    function self.draw(win)
        self.W, self.H = win.getSize()
        local W, H    = self.W, self.H
        local listH   = H - 2

        T.fill(win, 1, 1, W, 1, T.c.tbarBtn)
        T.put(win, 2, 1, T.clip(self.path, W - 2), T.c.accent, T.c.tbarBtn)

        T.fill(win, 1, 2, W, listH, T.c.winBg)

        for i = 1, listH do
            local idx   = i + self.scroll
            local e     = self.entries[idx]
            if not e then break end

            local row    = i + 1
            local isSel  = (idx == self.selected)
            local bg     = isSel and T.c.listSelBg or T.c.winBg
            local fg     = e.isDir and T.c.dirFg or T.c.fileFg
            if isSel then fg = T.c.listSelFg end

            T.fill(win, 1, row, W, 1, bg)
            win.setBackgroundColor(bg)
            win.setTextColor(fg)
            win.setCursorPos(2, row)

            if e.isDir then
                win.write(T.clip("[" .. e.name .. "]", W - 2))
            else
                local sizeStr = e.size and tostring(e.size) .. "b" or "?"
                local nameW   = W - 3 - #sizeStr
                win.write(T.clip(e.name, nameW))
                win.setTextColor(isSel and T.c.listSelFg or T.c.textDim)
                win.setCursorPos(W - #sizeStr, row)
                win.write(sizeStr)
            end
        end

        if #self.entries > listH then
            local ratio   = self.scroll / math.max(1, #self.entries - listH)
            local thumbY  = math.floor(ratio * (listH - 1)) + 1
            for i = 1, listH do
                local ch = (i == thumbY) and "#" or "|"
                local fg = (i == thumbY) and T.c.accent or T.c.textDim
                T.put(win, W, i + 1, ch, fg, T.c.winBg)
            end
        end

        -- Status bar — hint for double-click
        T.fill(win, 1, H, W, 1, T.c.tbarBtn)
        local count = #self.entries .. " items"
        T.put(win, 2, H, count, T.c.textDim, T.c.tbarBtn)
        local hint = "dbl-click to open"
        T.put(win, W - #hint, H, hint, T.c.accent, T.c.tbarBtn)
    end

    function self.onClick(lx, ly, btn)
        local listH = self.H - 2
        if ly >= 2 and ly <= listH + 1 then
            local idx = (ly - 1) + self.scroll
            if idx >= 1 and idx <= #self.entries then
                local e   = self.entries[idx]
                local now = os.clock()

                if btn == 1 then
                    -- Double-click detection on non-directory files
                    if idx == self.selected
                    and not e.isDir
                    and (now - self.lastClickTime) < 0.5
                    and self.openInNotepad then
                        self.openInNotepad(fs.combine(self.path, e.name))
                    elseif e.isDir then
                        self.selected = idx
                        navigate()
                    else
                        self.selected = idx
                    end
                    self.lastClickIdx  = idx
                    self.lastClickTime = now
                end

                self.draw(self.winRef)
            end
        end
    end

    function self.onScroll(dir)
        self.scroll = math.max(0, math.min(self.scroll + dir,
            math.max(0, #self.entries - (self.H - 2))))
        self.draw(self.winRef)
    end

    function self.onKey(key, held)
        if key == keys.up then
            self.selected = math.max(1, self.selected - 1)
            clampScroll()
            self.draw(self.winRef)
        elseif key == keys.down then
            self.selected = math.min(#self.entries, self.selected + 1)
            clampScroll()
            self.draw(self.winRef)
        elseif key == keys.enter or key == keys.right then
            navigate()
            self.draw(self.winRef)
        elseif key == keys.left or key == keys.backspace then
            if self.path ~= "/" then
                local parent = fs.getDir(self.path)
                loadDir((parent == "" or parent == nil) and "/" or parent)
                self.draw(self.winRef)
            end
        end
    end

    return self
end

return Files