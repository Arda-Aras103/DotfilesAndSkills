-- Hyprland 0.57+ Lua config dedicated to Persona-Quickshell.
-- Keeps all Quickshell/Cava env vars scoped to Hyprland so KDE Plasma stays untouched.

local home = os.getenv("HOME")
local personaDir = home .. "/.config/quickshell/persona"
local qmlLocal = home .. "/.local/lib/qt6/qml"
local mainMod = "SUPER"

hl.env("QML2_IMPORT_PATH", qmlLocal)
hl.env("LD_LIBRARY_PATH", qmlLocal .. "/CavaMonitor:" .. qmlLocal)

hl.config({
    input = {
        kb_layout = "__KB_LAYOUT__",
        follow_mouse = 1,
    },
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        layout = "dwindle",
    },
    decoration = {
        rounding = 6,
    },
})

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.on("hyprland.start", function()
    hl.exec_cmd('qs -c "' .. personaDir .. '"')
end)

-- Persona-Quickshell app launcher
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd('qs -c "' .. personaDir .. '" ipc call searchapp toggle'))

-- Core apps & window controls matching existing KDE workflow
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("dolphin"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + M", hl.dsp.exit())

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

for i = 1, 4 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
