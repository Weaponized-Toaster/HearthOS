-- HearthOS  |  hearth/apps/messenger.lua
-- ─────────────────────────────────────
-- Rednet chat messenger app.

local T = require("theme")
local Messenger = {}

function Messenger.new()
    local self = {
        messages = {},
        input    = "",
        winRef   = nil,
        W = 0,  H = 0,
        myId     = os.getComputerID(),
        myLabel  = os.getComputerLabel() or ("PC-" .. os.getComputerID()),
        hasModem = false,
    }

    -- Detect modem
    for _, side in ipairs({ "top","bottom","left","right","front","back" }) do
        if peripheral.getType(side) == "modem" then
            self.hasModem = true
            break
        end
    end

    local PROTO = "hearth_chat"

    -- ── Init ─────────────────────────────────────────────────────
    function self.init(win, entry)
        self.winRef   = win
        self.W, self.H = win.getSize()

        if self.hasModem then
            self:sysMsg("Connected  ~  " .. self.myLabel .. "  (ID " .. self.myId .. ")")
            self:sysMsg("Type a message and press Enter to broadcast.")
        else
            self:sysMsg("No modem detected!")
            self:sysMsg("Attach a modem and reopen Messenger.")
        end
    end

    -- ── Internal helpers ─────────────────────────────────────────
    function self:sysMsg(text)
        table.insert(self.messages, { text = "* " .. text, color = T.c.msgSys })
    end

    function self:addMsg(text, color)
        table.insert(self.messages, { text = text, color = color })
        if #self.messages > 200 then table.remove(self.messages, 1) end
    end

    -- ── Draw ─────────────────────────────────────────────────────
    function self.draw(win)
        self.W, self.H = win.getSize()
        local W, H    = self.W, self.H
        local msgH    = H - 2   -- rows for messages

        -- Message area
        T.fill(win, 1, 1, W, msgH, T.c.winBg)
        local start = math.max(1, #self.messages - msgH + 1)
        for i = start, #self.messages do
            local row = i - start + 1
            local msg = self.messages[i]
            win.setBackgroundColor(T.c.winBg)
            win.setTextColor(msg.color or T.c.text)
            win.setCursorPos(1, row)
            win.write(T.pad(T.clip(msg.text, W), W))
        end

        -- Input label
        T.fill(win, 1, H - 1, W, 1, T.c.tbarBtn)
        T.put(win, 2, H - 1, "Send:", T.c.textDim, T.c.tbarBtn)

        -- Input field
        T.fill(win, 1, H, W, 1, T.c.inputBg)
        win.setBackgroundColor(T.c.inputBg)
        win.setTextColor(T.c.inputFg)
        win.setCursorPos(1, H)
        win.write(T.pad("> " .. T.clip(self.input, W - 4), W - 1))
        -- Blinking cursor indicator
        win.setTextColor(T.c.accent)
        win.write("_")
    end

    -- ── Char input ───────────────────────────────────────────────
    function self.onChar(ch)
        self.input = self.input .. ch
        self.draw(self.winRef)
    end

    -- ── Key input ────────────────────────────────────────────────
    function self.onKey(key, held)
        if key == keys.backspace then
            self.input = self.input:sub(1, -2)
            self.draw(self.winRef)
        elseif key == keys.enter and #self.input > 0 then
            local text = "[" .. self.myLabel .. "] " .. self.input
            if self.hasModem then
                rednet.broadcast(text, PROTO)
            end
            self:addMsg(text, T.c.msgMe)
            self.input = ""
            self.draw(self.winRef)
        end
    end

    -- ── Rednet message received ───────────────────────────────────
    function self.onRednet(senderId, msg, proto)
        if proto == PROTO and senderId ~= self.myId then
            self:addMsg(tostring(msg), T.c.msgOther)
        end
    end

    return self
end

return Messenger