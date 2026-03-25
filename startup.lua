-- HearthOS v1.0  |  startup.lua
-- ─────────────────────────────────────
-- Place at the root of your computer.
-- This file boots HearthOS on startup.

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
