create_clock -period 10.000 -name wr_clk [get_ports i_Wr_Clk]
create_clock -period 37.000 -name rd_clk [get_ports i_Rd_Clk]
set_clock_groups -asynchronous -group wr_clk -group rd_clk