local machine = manager.machine
local io = machine.devices[":maincpu"].spaces["io"]
local selected = 0

io:install_write_tap(0x00, 0x02, "docastle_crtc_trace", function(offset, data, mask)
	if offset == 0x00 then
		selected = data & 0x1f
	elseif offset == 0x02 then
		print(string.format("CRTC R%02d=%02X", selected, data))
	end
end)

emu.wait(1.0)
machine:exit()
