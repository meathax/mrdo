-- Raw-frame MAME participant for the RTL-vs-MAME lockstep session.
-- MAME 0.288 exposes screen:pixels(), which returns the native visible-area
-- bitmap without PNG conversion or emulator-side scaling.

local machine = manager.machine
local screen = machine.screens[":screen"]
local session = os.getenv("DOCASTLE_LOCKSTEP_SESSION") or "."
local max_frames = tonumber(os.getenv("DOCASTLE_LOCKSTEP_FRAMES") or "0") or 0
local separator = package.config:sub(1, 1)
local ref_dir = session .. separator .. "reference"
local input_dir = session .. separator .. "inputs"
local trace_path = ref_dir .. separator .. "trace.jsonl"

local function path(name)
    return ref_dir .. separator .. name
end

local function atomic_write(name, data)
    local tmp = name .. ".tmp"
    local file = assert(io.open(tmp, "wb"))
    file:write(data)
    file:close()
    os.remove(name)
    assert(os.rename(tmp, name))
end

local function release_seen(frame)
    local file = io.open(session .. separator .. "release.txt", "rb")
    if not file then return false end
    local value = tonumber(file:read("*l") or "-1") or -1
    file:close()
    return value >= frame
end

local function apply_input(frame)
    local file = io.open(input_dir .. separator .. string.format("frame_%06d.txt", frame), "rb")
    if not file then return end
    for line in file:lines() do
        local name, value = line:match("^(%w+)=([%da-fA-Fx]+)$")
        if name and value then
            local port = machine.ioport.ports[":" .. name:upper()]
            if port then port:write(tonumber(value) or 0xff) end
        end
    end
    file:close()
end

local trace = io.open(trace_path, "wb")
if trace then
    trace:write("{\"event\":\"start\",\"game\":\"" .. machine.system.name .. "\"}\n")
    trace:flush()
end

for frame = 0, (max_frames == 0 and math.huge or max_frames - 1) do
    apply_input(frame)
    emu.wait_next_frame()
    local data, width, height = screen:pixels()
    local stem = string.format("frame_%06d", frame)
    atomic_write(path(stem .. ".raw"), data)
    atomic_write(path(stem .. ".meta"), string.format("width=%d\nheight=%d\nformat=ARGB32-native\n", width, height))
    atomic_write(path(stem .. ".ready"), "ready\n")
    if trace then
        trace:write(string.format("{\"frame\":%d,\"width\":%d,\"height\":%d}\n", frame, width, height))
        trace:flush()
    end
    -- A tiny timer yield lets the SDL/MAME host service its window while
    -- keeping the task inside the same raster frame. emu.wait(0) advances to
    -- the next scheduler update on this MAME build and would duplicate every
    -- other captured frame.
    while not release_seen(frame) do
        emu.wait(0.000001)
    end
end

if trace then trace:close() end
atomic_write(session .. separator .. "mame_done.txt", "done\n")
machine:exit()
