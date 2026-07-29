project_open DoCastle
create_timing_netlist
read_sdc
update_timing_netlist

report_timing \
    -setup \
    -npaths 1 \
    -detail full_path

delete_timing_netlist
project_close
