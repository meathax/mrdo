project_open Universal_DoCastle
create_timing_netlist
read_sdc
update_timing_netlist

report_timing \
    -setup \
    -to_clock {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk} \
    -npaths 5 \
    -detail full_path

delete_timing_netlist
project_close
