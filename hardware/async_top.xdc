## Clocks: two separate oscillators on the board
## 100 MHz: pin R2 is on bank 34 (the DDR3 bank, 1.35 V), so it uses SSTL135
set_property -dict { PACKAGE_PIN R2  IOSTANDARD SSTL135 }  [get_ports i_Clk_100]
set_property INTERNAL_VREF 0.675 [get_iobanks 34]
create_clock -period 10.000 -name clk100 [get_ports i_Clk_100]

## 12 MHz
set_property -dict { PACKAGE_PIN F14 IOSTANDARD LVCMOS33 } [get_ports i_Clk_12]
create_clock -period 83.333 -name clk12 [get_ports i_Clk_12]

## The two clocks are unrelated: don't time paths between them
set_clock_groups -asynchronous -group clk100 -group clk12

## Button
set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports i_Btn0]

##LEDs 
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports {o_Led[0]}]
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports {o_Led[1]}]
set_property -dict { PACKAGE_PIN E13 IOSTANDARD LVCMOS33 } [get_ports {o_Led[2]}]
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports {o_Led[3]}]

##Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
