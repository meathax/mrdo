-- Deterministic reference capture for every Universal Do! Castle family set.
-- Run with MAME -autoboot_script. emu.wait advances emulated, not wall time.

local machine = manager.machine
local screen = machine.screens[":screen"]
local system_port = machine.ioport.ports[":SYSTEM"]
local buttons_port = machine.ioport.ports[":BUTTONS"]
local set_name = machine.system.name
local output_dir = os.getenv("DOCASTLE_CAPTURE_DIR") or "."
local separator = package.config:sub(1, 1)

local function output_path(label)
	return output_dir .. separator .. set_name .. "_" .. label .. ".png"
end

emu.wait(2.05)
screen:snapshot(output_path("title"))

emu.wait(3.00)
screen:snapshot(output_path("attract"))

local coin1 = system_port:field(0x20)
coin1:set_value(1)
emu.wait(0.08)
coin1:clear_value()
emu.wait(0.35)

local start1 = buttons_port:field(0x08)
start1:set_value(1)
emu.wait(0.08)
start1:clear_value()

emu.wait(2.50)
screen:snapshot(output_path("gameplay"))
machine:exit()
