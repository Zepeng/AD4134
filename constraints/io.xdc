# ==============================================================================
# UltraZed-3EG IO Constraints
# ==============================================================================

# Clock input - REMOVED: Now using Zynq PS pl_clk0 instead of external clock
# set_property PACKAGE_PIN C3 [get_ports clk]
# set_property IOSTANDARD LVCMOS18 [get_ports clk]

# LEDs (directly on UltraZed SOM - active high)
set_property PACKAGE_PIN AC12 [get_ports {LEDS[0]}]
set_property PACKAGE_PIN AD11 [get_ports {LEDS[1]}]
set_property PACKAGE_PIN AD12 [get_ports {LEDS[2]}]
set_property PACKAGE_PIN AD10 [get_ports {LEDS[3]}]
set_property PACKAGE_PIN AE10 [get_ports {LEDS[4]}]
set_property PACKAGE_PIN AA11 [get_ports {LEDS[5]}]
set_property PACKAGE_PIN AF10 [get_ports {LEDS[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {LEDS[*]}]

# Heartbeat LED
set_property PACKAGE_PIN F8 [get_ports {hb_led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {hb_led[0]}]

# SPI interface
set_property PACKAGE_PIN H12 [get_ports spi_clk]
set_property PACKAGE_PIN E10 [get_ports miso]
set_property PACKAGE_PIN B10 [get_ports mosi]
set_property PACKAGE_PIN E12 [get_ports spi_cs_n]
set_property IOSTANDARD LVCMOS18 [get_ports spi_clk]
set_property IOSTANDARD LVCMOS18 [get_ports miso]
set_property IOSTANDARD LVCMOS18 [get_ports mosi]
set_property IOSTANDARD LVCMOS18 [get_ports spi_cs_n]

# AD4134 data interface
set_property PACKAGE_PIN D11 [get_ports dclk_out]
set_property PACKAGE_PIN D10 [get_ports odr_out]
set_property PACKAGE_PIN J11 [get_ports data_in0]
set_property PACKAGE_PIN J10 [get_ports data_in1]
set_property PACKAGE_PIN K13 [get_ports data_in2]
set_property PACKAGE_PIN K12 [get_ports data_in3]
set_property IOSTANDARD LVCMOS18 [get_ports dclk_out]
set_property IOSTANDARD LVCMOS18 [get_ports odr_out]
set_property IOSTANDARD LVCMOS18 [get_ports data_in0]
set_property IOSTANDARD LVCMOS18 [get_ports data_in1]
set_property IOSTANDARD LVCMOS18 [get_ports data_in2]
set_property IOSTANDARD LVCMOS18 [get_ports data_in3]

# Debug signals
set_property PACKAGE_PIN H11 [get_ports {debug[0]}]
set_property PACKAGE_PIN G10 [get_ports {debug[1]}]
set_property PACKAGE_PIN F12 [get_ports {debug[2]}]
set_property PACKAGE_PIN F11 [get_ports {debug[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {debug[*]}]
