-- HearthOS  |  hearth/apps/notepad.lua
-- ─────────────────────────────────────
-- Simple text editor.
-- F2 = Save   F3 = Open   Arrow keys = Navigate

local T = require("theme")
local Notepad = {}

function Notepad.new()
    local self = {
        lines    = { "" },
        cx       = 1,
        cy       = 1,
        scrollY  = 0,
        filename = nil,
        modified = false,
        mode     = "edit",
        prompt   = "",
        winRef   = nil,
        W = 0,  H = 0,
    }

    function self.init(win, entry)
        self.winRef   = win
        self.W, self.H = win.getSize()
    end

    local function clampScroll()
        local textH = self.H - 2
        if self.cy > self.scrollY + textH then self.scrollY = self.cy - textH end
        if self.cy <= self.scrollY         then self.scrollY = self.cy - 1      end
        self.scrollY = math.max(0, self.scrollY)
    end

    -- ── Load a file programmatically (called from Files app) ────
    function self.loadFile(path)
        if fs.exists(path) and not fs.isDir(path) then
            local f = fs.open(path, "r")
            if f then
                self.lines = {}
                local ln = f.readLine()
                while ln ~= nil do
                    table.insert(self.lines, ln)
                    ln = f.readLine()
                end
                f.close()
                if #self.lines == 0 then self.lines = { "" } end
                self.filename = path
                self.modified = false
                self.cx = 1;  self.cy = 1;  self.scrollY = 0
            end
        end
    end

    function self.draw(win)
        self.W, self.H = win.getSize()
        local W, H    = self.W, self.H
        local textH   = H - 2

        T.fill(win, 1, 1, W, 1, T.c.tbarBtn)
        local fname = self.filename or "untitled"
        if self.modified then fname = fname .. " *" end
        T.put(win, 2, 1, T.clip(fname, W - 14), T.c.accent, T.c.tbarBtn)
        T.put(win, W - 11, 1, "F2:Save F3:Open", T.c.textDim, T.c.tbarBtn)

        T.fill(win, 1, 2, W, textH, T.c.winBg)
        local GUTTER = 3

        for i = 1, textH do
            local lineIdx = i + self.scrollY
            local line    = self.lines[lineIdx]
            if not line then break end

            local row = i + 1
            T.put(win, 1, row, string.format("%2d", lineIdx), T.c.textDim, T.c.winBg)
            T.put(win, GUTTER + 1, row, T.clip(line, W - GUTTER), T.c.text, T.c.winBg)
            if lineIdx == self.cy and self.mode == "edit" then
                local visualX = self.cx + GUTTER
                if visualX <= W then
                    local ch = line:sub(self.cx, self.cx)
                    T.put(win, visualX, row, ch == "" and "_" or ch, T.c.accent, T.c.winBg)
                end
            end
        end

        if self.mode == "save" then
            T.fill(win, 1, H, W, 1, T.c.inputBg)
            T.put(win, 1, H, T.pad("Save as: " .. self.prompt .. "_", W), T.c.inputFg, T.c.inputBg)
        elseif self.mode == "load" then
            T.fill(win, 1, H, W, 1, T.c.inputBg)
            T.put(win, 1, H, T.pad("Open file: " .. self.prompt .. "_", W), T.c.inputFg, T.c.inputBg)
        else
            T.fill(win, 1, H, W, 1, T.c.tbarBtn)
            local pos = "L" .. self.cy .. "  C" .. self.cx
            T.put(win, 2, H, pos, T.c.textDim, T.c.tbarBtn)
            T.put(win, W - 12, H, #self.lines .. " lines", T.c.textDim, T.c.tbarBtn)
        end
    end

    function self.onChar(ch)
        if self.mode == "save" or self.mode == "load" then
            self.prompt = self.prompt .. ch
        else
            local line = self.lines[self.cy]
            self.lines[self.cy] = line:sub(1, self.cx - 1) .. ch .. line:sub(self.cx)
            self.cx       = self.cx + 1
            self.modified = true
        end
        self.draw(self.winRef)
    end

    function self.onKey(key, held)
        if self.mode == "save" then
            if key == keys.enter then
                if #self.prompt > 0 then
                    local f = fs.open(self.prompt, "w")
                    if f then
                        for _, ln in ipairs(self.lines) do f.writeLine(ln) end
                        f.close()
                        self.filename = self.prompt
                        self.modified = false
                    end
                end
                self.mode = "edit";  self.prompt = ""
            elseif key == keys.backspace then
                self.prompt = self.prompt:sub(1, -2)
            elseif key == keys.escape then
                self.mode = "edit";  self.prompt = ""
            end

        elseif self.mode == "load" then
            if key == keys.enter then
                if #self.prompt > 0 and fs.exists(self.prompt) and not fs.isDir(self.prompt) then
                    self.loadFile(self.prompt)
                end
                self.mode = "edit";  self.prompt = ""
            elseif key == keys.backspace then
                self.prompt = self.prompt:sub(1, -2)
            elseif key == keys.escape then
                self.mode = "edit";  self.prompt = ""
            end

        else
            if key == keys.f2 then
                self.mode   = "save"
                self.prompt = self.filename or ""
            elseif key == keys.f3 then
                self.mode   = "load"
                self.prompt = ""
            elseif key == keys.backspace then
                if self.cx > 1 then
                    local ln = self.lines[self.cy]
                    self.lines[self.cy] = ln:sub(1, self.cx - 2) .. ln:sub(self.cx)
                    self.cx = self.cx - 1
                    self.modified = true
                elseif self.cy > 1 then
                    local cur  = self.lines[self.cy]
                    local prev = self.lines[self.cy - 1]
                    self.cx = #prev + 1
                    self.lines[self.cy - 1] = prev .. cur
                    table.remove(self.lines, self.cy)
                    self.cy   = self.cy - 1
                    self.modified = true
                end
            elseif key == keys.enter then
                local ln   = self.lines[self.cy]
                local rest = ln:sub(self.cx)
                self.lines[self.cy] = ln:sub(1, self.cx - 1)
                table.insert(self.lines, self.cy + 1, rest)
                self.cy   = self.cy + 1
                self.cx   = 1
                self.modified = true
            elseif key == keys.delete then
                local ln = self.lines[self.cy]
                if self.cx <= #ln then
                    self.lines[self.cy] = ln:sub(1, self.cx - 1) .. ln:sub(self.cx + 1)
                    self.modified = true
                elseif self.cy < #self.lines then
                    self.lines[self.cy] = ln .. self.lines[self.cy + 1]
                    table.remove(self.lines, self.cy + 1)
                    self.modified = true
                end
            elseif key == keys.up then
                if self.cy > 1 then
                    self.cy = self.cy - 1
                    self.cx = math.min(self.cx, #self.lines[self.cy] + 1)
                end
            elseif key == keys.down then
                if self.cy < #self.lines then
                    self.cy = self.cy + 1
                    self.cx = math.min(self.cx, #self.lines[self.cy] + 1)
                end
            elseif key == keys.left then
                if self.cx > 1 then
                    self.cx = self.cx - 1
                elseif self.cy > 1 then
                    self.cy = self.cy - 1
                    self.cx = #self.lines[self.cy] + 1
                end
            elseif key == keys.right then
                if self.cx <= #self.lines[self.cy] then
                    self.cx = self.cx + 1
                elseif self.cy < #self.lines then
                    self.cy = self.cy + 1
                    self.cx = 1
                end
            elseif key == keys.home then
                self.cx = 1
            elseif key == keys["end"] then
                self.cx = #self.lines[self.cy] + 1
            elseif key == keys.pageUp then
                self.cy = math.max(1, self.cy - (self.H - 2))
                self.cx = math.min(self.cx, #self.lines[self.cy] + 1)
            elseif key == keys.pageDown then
                self.cy = math.min(#self.lines, self.cy + (self.H - 2))
                self.cx = math.min(self.cx, #self.lines[self.cy] + 1)
            end
        end

        clampScroll()
        self.draw(self.winRef)
    end

    return self
end

return Notepad