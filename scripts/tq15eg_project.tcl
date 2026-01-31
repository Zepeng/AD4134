#!/usr/bin/env vivado
# ==============================================================================
# AD4134 Project Recreation Script for Vivado 2023.1
# ==============================================================================
# This script recreates the AD4134 project from the 2024.2 export
# Modified to work with Vivado 2023.1
#
# Usage:
#   vivado -mode batch -source recreate_2023_1.tcl
#   OR
#   Open Vivado 2023.1 and run: source /path/to/recreate_2023_1.tcl
#
# ==============================================================================

# Get script directory and repo root
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ..]]

# ==============================================================================
# Project Configuration - MODIFY THESE AS NEEDED
# ==============================================================================
set proj_name "ad4134fw_tq15eg"
set proj_dir [file join $repo_root "vivado_2023_1"]

# Target: UltraZed-3EG PCIECC
set part_name "xczu15eg-ffvb1156-2-i"
set board_part "not-applicable"
set preset_file_name "tq15eg_preset.tcl"
set constraints_dir "tq15eg"

# Alternative: Kria K260 SOM (uncomment if targeting Kria)
# set part_name "xck26-sfvc784-2LV-c"
# set board_part "xilinx.com:kr260_som:part0:1.1"

puts "=============================================================================="
puts "AD4134 Project Recreation for Vivado 2023.1"
puts "=============================================================================="
puts "Project name: $proj_name"
puts "Project dir:  $proj_dir"
puts "Part:         $part_name"
puts "Board:        $board_part"
puts "=============================================================================="

# ==============================================================================
# Step 1: Create Project
# ==============================================================================
puts "\n>>> Step 1: Creating project..."

# Remove existing project if present
if {[file exists $proj_dir]} {
    puts "WARNING: Removing existing project directory..."
    file delete -force $proj_dir
}

create_project $proj_name $proj_dir -part $part_name -force
#set xpr_path [file join $proj_dir "${proj_name}.xpr"]
#if {[file exists $xpr_path]} {
#    puts "Opening existing project: $xpr_path"
#    open_project $xpr_path
#} else {
#    puts "Creating new project in: $proj_dir"
##    file mkdir $proj_dir
#    create_project $proj_name $proj_dir -part $part_name
#}

# Creates IP cache directory to decrease the amount of time required for
# synthesis
set ip_cache_dir [file join $repo_root "ip_cache"]
file mkdir $ip_cache_dir

config_ip_cache -use_cache_location $ip_cache_dir
set_property IP_CACHE_PERMISSIONS {read write} [current_project]

puts "Using IP cache at: $ip_cache_dir"
puts "IP_OUTPUT_REPO is: [get_property IP_OUTPUT_REPO [current_project]]"
puts "IP_CACHE_PERMISSIONS is: [get_property IP_CACHE_PERMISSIONS [current_project]]"

# Set IP cache directory outside of the root repo. Avoids synthesis of individual
# IPs after running project creations
#set ip_cache_dir [file join $repo_root "ip"]
#file mkdir $ip_cache_dir
#set_property ip_cache_permissions {read write} [current_project]
#set_property ip_cache_dir $ip_cache_dir [current_project]


# Set board part (may fail if board files not installed)
if {[catch {set_property board_part $board_part [current_project]} err]} {
    puts "WARNING: Could not set board_part. Board files may not be installed."
    puts "         Continuing without board preset..."
}

set_property target_language VHDL [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property simulator_language Mixed [current_project]
set_property enable_vhdl_2008 1 [current_project]
set_property source_mgmt_mode All [current_project]

puts "Project created successfully."

# ==============================================================================
# Step 2: Add RTL Source Files (MUST be added BEFORE block design)
# ==============================================================================
puts "\n>>> Step 2: Adding RTL source files..."

set src_dir [file join $repo_root src]
set vhdl_files [glob -nocomplain [file join $src_dir *.vhd]]

# Separate synthesis and simulation files
set synth_files {}
set sim_files {}
foreach f $vhdl_files {
    if {[string match "*_tb.vhd" $f]} {
        lappend sim_files $f
    } else {
        lappend synth_files $f
    }
}

if {[llength $synth_files] > 0} {
    add_files -norecurse $synth_files
    puts "Added [llength $synth_files] synthesis source files:"
    foreach f $synth_files {
        puts "  - [file tail $f]"
    }
    update_compile_order -fileset sources_1
} else {
    puts "ERROR: No VHDL source files found in $src_dir"
    return 1
}

# ==============================================================================
# Step 3: Add Constraint Files
# ==============================================================================
puts "\n>>> Step 3: Adding constraint files..."

set constr_dir [file join $repo_root constraints $constraints_dir]
set xdc_files [glob -nocomplain [file join $constr_dir *.xdc]]

if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 -norecurse $xdc_files
    puts "Added [llength $xdc_files] constraint files:"
    foreach f $xdc_files {
        puts "  - [file tail $f]"
    }
} else {
    puts "WARNING: No constraint files found in $constr_dir"
}

# ==============================================================================
# Step 4: Create Block Design
# ==============================================================================
puts "\n>>> Step 4: Creating block design..."

# Source the block design TCL (modified inline to remove version check)
set design_name "ad4134fw"

# Check if design already exists
set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
    puts "ERROR: No project open"
    return 1
}

# Create the block design
create_bd_design $design_name
current_bd_design $design_name

puts "Block design '$design_name' created."

# ==============================================================================
# Block Design Procedures (from ad4134fw_bd.tcl)
# ==============================================================================

# Hierarchical cell: ADC_BRAM
proc create_hier_cell_ADC_BRAM { parentCell nameHier } {
  if { $parentCell eq "" || $nameHier eq "" } {
     puts "ERROR: create_hier_cell_ADC_BRAM() - Empty argument(s)!"
     return
  }

  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     puts "ERROR: Unable to find parent cell <$parentCell>!"
     return
  }

  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
     return
  }

  set oldCurInst [current_bd_instance .]
  current_bd_instance $parentObj

  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 ADC_BRAM_Reader
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 adc_bram_enable

  # Create pins
  create_bd_pin -dir I clk
  create_bd_pin -dir I rst_n
  create_bd_pin -dir I -from 23 -to 0 data_in0_0
  create_bd_pin -dir I -from 23 -to 0 data_in1_0
  create_bd_pin -dir I -from 23 -to 0 data_in2_0
  create_bd_pin -dir I -from 23 -to 0 data_in3_0
  create_bd_pin -dir I data_rdy_0
  create_bd_pin -dir O done_0
  create_bd_pin -dir O -from 3 -to 0 debug_0

  # Create instance: blk_mem_gen_0
  # Configure as True Dual Port RAM with BRAM_CTRL interface on Port B for AXI BRAM Controller
  set blk_mem_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen blk_mem_gen_0 ]
  set_property -dict [list \
    CONFIG.Enable_32bit_Address {false} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Enable_B {Always_Enabled} \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Operating_Mode_A {NO_CHANGE} \
    CONFIG.Port_B_Clock {100} \
    CONFIG.Port_B_Enable_Rate {100} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {true} \
    CONFIG.Use_Byte_Write_Enable {false} \
    CONFIG.Write_Depth_A {32768} \
    CONFIG.use_bram_block {Stand_Alone} \
  ] $blk_mem_gen_0

  # Create instance: ADC_BRAM_READ
  set ADC_BRAM_READ [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl ADC_BRAM_READ ]
  set_property CONFIG.SINGLE_PORT_BRAM {1} $ADC_BRAM_READ

  # Create instance: ad4134_to_bram_0 (module reference)
  set ad4134_to_bram_0 [create_bd_cell -type module -reference ad4134_to_bram ad4134_to_bram_0]

  # Create instance: adc_bram_enable
  set adc_bram_enable [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio adc_bram_enable ]
  set_property CONFIG.C_ALL_OUTPUTS {1} $adc_bram_enable

  # Create instance: xlslice_0
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice xlslice_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins ADC_BRAM_READ/S_AXI] [get_bd_intf_pins ADC_BRAM_Reader]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins adc_bram_enable/S_AXI] [get_bd_intf_pins adc_bram_enable]
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins ADC_BRAM_READ/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTB]

  # Create port connections
  connect_bd_net [get_bd_pins ad4134_to_bram_0/addra] [get_bd_pins blk_mem_gen_0/addra]
  connect_bd_net [get_bd_pins ad4134_to_bram_0/debug] [get_bd_pins debug_0]
  connect_bd_net [get_bd_pins ad4134_to_bram_0/dia] [get_bd_pins blk_mem_gen_0/dina]
  connect_bd_net [get_bd_pins ad4134_to_bram_0/done] [get_bd_pins done_0]
  connect_bd_net [get_bd_pins ad4134_to_bram_0/wea] [get_bd_pins blk_mem_gen_0/wea]
  connect_bd_net [get_bd_pins adc_bram_enable/gpio_io_o] [get_bd_pins xlslice_0/Din]
  connect_bd_net [get_bd_pins clk] [get_bd_pins ADC_BRAM_READ/s_axi_aclk] [get_bd_pins adc_bram_enable/s_axi_aclk] [get_bd_pins blk_mem_gen_0/clka] [get_bd_pins ad4134_to_bram_0/clk]
  connect_bd_net [get_bd_pins data_in0_0] [get_bd_pins ad4134_to_bram_0/data_in0]
  connect_bd_net [get_bd_pins data_in1_0] [get_bd_pins ad4134_to_bram_0/data_in1]
  connect_bd_net [get_bd_pins data_in2_0] [get_bd_pins ad4134_to_bram_0/data_in2]
  connect_bd_net [get_bd_pins data_in3_0] [get_bd_pins ad4134_to_bram_0/data_in3]
  connect_bd_net [get_bd_pins data_rdy_0] [get_bd_pins ad4134_to_bram_0/data_rdy]
  connect_bd_net [get_bd_pins rst_n] [get_bd_pins ADC_BRAM_READ/s_axi_aresetn] [get_bd_pins adc_bram_enable/s_axi_aresetn] [get_bd_pins ad4134_to_bram_0/rst_n]
  connect_bd_net [get_bd_pins xlslice_0/Dout] [get_bd_pins ad4134_to_bram_0/bram_enable]

  current_bd_instance $oldCurInst
}

# Hierarchical cell: bram_tester
proc create_hier_cell_bram_tester { parentCell nameHier } {
  if { $parentCell eq "" || $nameHier eq "" } {
     puts "ERROR: create_hier_cell_bram_tester() - Empty argument(s)!"
     return
  }

  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     puts "ERROR: Unable to find parent cell <$parentCell>!"
     return
  }

  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
     return
  }

  set oldCurInst [current_bd_instance .]
  current_bd_instance $parentObj

  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 BRAM_INIT
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 BRAM_READ

  # Create pins
  create_bd_pin -dir I clk
  create_bd_pin -dir I rst_n

  # Create instance: bram_writer_0 (module reference)
  set bram_writer_0 [create_bd_cell -type module -reference bram_writer bram_writer_0]

  # Create instance: blk_mem_gen_0
  # Configure as True Dual Port RAM with BRAM_CTRL interface on Port B for AXI BRAM Controller
  set blk_mem_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen blk_mem_gen_0 ]
  set_property -dict [list \
    CONFIG.Enable_32bit_Address {false} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Enable_B {Always_Enabled} \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Operating_Mode_A {NO_CHANGE} \
    CONFIG.Port_B_Clock {100} \
    CONFIG.Port_B_Enable_Rate {100} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {true} \
    CONFIG.Use_Byte_Write_Enable {false} \
    CONFIG.use_bram_block {Stand_Alone} \
  ] $blk_mem_gen_0

  # Create instance: bram_read
  set bram_read [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl bram_read ]
  set_property CONFIG.SINGLE_PORT_BRAM {1} $bram_read

  # Create instance: bram_test_control
  set bram_test_control [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio bram_test_control ]
  set_property CONFIG.C_ALL_OUTPUTS {1} $bram_test_control

  # Create instance: xlslice_0
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice xlslice_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins bram_test_control/S_AXI] [get_bd_intf_pins BRAM_INIT]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins bram_read/S_AXI] [get_bd_intf_pins BRAM_READ]
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins bram_read/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTB]

  # Create port connections
  connect_bd_net [get_bd_pins bram_test_control/gpio_io_o] [get_bd_pins xlslice_0/Din]
  connect_bd_net [get_bd_pins bram_writer_0/addra] [get_bd_pins blk_mem_gen_0/addra]
  connect_bd_net [get_bd_pins bram_writer_0/dia] [get_bd_pins blk_mem_gen_0/dina]
  connect_bd_net [get_bd_pins bram_writer_0/wea] [get_bd_pins blk_mem_gen_0/wea]
  connect_bd_net [get_bd_pins clk] [get_bd_pins bram_read/s_axi_aclk] [get_bd_pins bram_test_control/s_axi_aclk] [get_bd_pins blk_mem_gen_0/clka] [get_bd_pins bram_writer_0/clk]
  connect_bd_net [get_bd_pins rst_n] [get_bd_pins bram_read/s_axi_aresetn] [get_bd_pins bram_test_control/s_axi_aresetn] [get_bd_pins bram_writer_0/reset_n]
  connect_bd_net [get_bd_pins xlslice_0/Dout] [get_bd_pins bram_writer_0/start]

  current_bd_instance $oldCurInst
}

# Hierarchical cell: LEDS
proc create_hier_cell_LEDS { parentCell nameHier } {
  if { $parentCell eq "" || $nameHier eq "" } {
     puts "ERROR: create_hier_cell_LEDS() - Empty argument(s)!"
     return
  }

  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     puts "ERROR: Unable to find parent cell <$parentCell>!"
     return
  }

  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
     return
  }

  set oldCurInst [current_bd_instance .]
  current_bd_instance $parentObj

  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI

  # Create pins
  create_bd_pin -dir O -from 6 -to 0 LEDS
  create_bd_pin -dir O -from 0 -to 0 hb_led
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn

  # Create instance: xlslice_0
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {6} \
    CONFIG.DOUT_WIDTH {7} \
  ] $xlslice_0

  # Create instance: xlslice_1
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice xlslice_1 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {25} \
    CONFIG.DIN_TO {25} \
  ] $xlslice_1

  # Create instance: c_counter_binary_0
  set c_counter_binary_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_counter_binary c_counter_binary_0 ]
  set_property -dict [list \
    CONFIG.Increment_Value {1} \
    CONFIG.Output_Width {32} \
  ] $c_counter_binary_0

  # Create instance: axi_gpio_0
  set axi_gpio_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0 ]
  set_property CONFIG.C_ALL_OUTPUTS {1} $axi_gpio_0

  # Create interface connections
  connect_bd_intf_net [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_gpio_0/S_AXI]

  # Create port connections
  connect_bd_net [get_bd_pins s_axi_aclk] [get_bd_pins axi_gpio_0/s_axi_aclk] [get_bd_pins c_counter_binary_0/CLK]
  connect_bd_net [get_bd_pins s_axi_aresetn] [get_bd_pins axi_gpio_0/s_axi_aresetn]
  connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_pins xlslice_0/Din]
  connect_bd_net [get_bd_pins c_counter_binary_0/Q] [get_bd_pins xlslice_1/Din]
  connect_bd_net [get_bd_pins xlslice_0/Dout] [get_bd_pins LEDS]
  connect_bd_net [get_bd_pins xlslice_1/Dout] [get_bd_pins hb_led]

  current_bd_instance $oldCurInst
}

# Hierarchical cell: SPI_Control
proc create_hier_cell_SPI_Control { parentCell nameHier } {
  if { $parentCell eq "" || $nameHier eq "" } {
     puts "ERROR: create_hier_cell_SPI_Control() - Empty argument(s)!"
     return
  }

  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     puts "ERROR: Unable to find parent cell <$parentCell>!"
     return
  }

  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
     return
  }

  set oldCurInst [current_bd_instance .]
  current_bd_instance $parentObj

  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create pins
  create_bd_pin -dir I -type clk clk
  create_bd_pin -dir I -type rst rstn
  create_bd_pin -dir O -type clk spi_clk
  create_bd_pin -dir O -from 3 -to 0 debug
  create_bd_pin -dir O mosi
  create_bd_pin -dir I miso
  create_bd_pin -dir O spi_cs_n

  # Create instance: ad4134_clock_generator (module reference)
  set ad4134_clock_generator [create_bd_cell -type module -reference ad4134_clock_generator ad4134_clock_generator]

  # Create instance: ad4134_control_0 (module reference)
  set ad4134_control_0 [create_bd_cell -type module -reference ad4134_control ad4134_control_0]

  # Create instance: spi_controller_0 (module reference)
  set spi_controller_0 [create_bd_cell -type module -reference spi_controller spi_controller_0]

  # Create port connections
  connect_bd_net [get_bd_pins clk] [get_bd_pins ad4134_clock_generator/clk] [get_bd_pins ad4134_control_0/clk] [get_bd_pins spi_controller_0/clk]
  connect_bd_net [get_bd_pins rstn] [get_bd_pins ad4134_clock_generator/rstn] [get_bd_pins ad4134_control_0/rstn] [get_bd_pins spi_controller_0/rstn]
  connect_bd_net [get_bd_pins ad4134_clock_generator/spi_clk] [get_bd_pins spi_clk]
  connect_bd_net [get_bd_pins ad4134_control_0/datain] [get_bd_pins spi_controller_0/datain]
  connect_bd_net [get_bd_pins ad4134_control_0/debug] [get_bd_pins debug]
  connect_bd_net [get_bd_pins ad4134_control_0/read] [get_bd_pins spi_controller_0/read]
  connect_bd_net [get_bd_pins ad4134_control_0/spi_clk_en] [get_bd_pins ad4134_clock_generator/spi_clk_en]
  connect_bd_net [get_bd_pins ad4134_control_0/spiaddr] [get_bd_pins spi_controller_0/spiaddr]
  connect_bd_net [get_bd_pins ad4134_control_0/write] [get_bd_pins spi_controller_0/write]
  connect_bd_net [get_bd_pins miso] [get_bd_pins spi_controller_0/miso]
  connect_bd_net [get_bd_pins spi_controller_0/cs_n] [get_bd_pins spi_cs_n]
  connect_bd_net [get_bd_pins spi_controller_0/dataout] [get_bd_pins ad4134_control_0/dataout]
  connect_bd_net [get_bd_pins spi_controller_0/mosi] [get_bd_pins mosi]
  connect_bd_net [get_bd_pins spi_controller_0/spidone] [get_bd_pins ad4134_control_0/spidone]

  current_bd_instance $oldCurInst
}

# Hierarchical cell: Processing_Subsystem
# NOTE: For UltraZed-3EG, the PS provides pl_clk0 to the PL (no external PL clock)
#       For Kria KR260, an external PL clock is available on the SOM
proc create_hier_cell_Processing_Subsystem { parentCell nameHier } {
  if { $parentCell eq "" || $nameHier eq "" } {
     puts "ERROR: create_hier_cell_Processing_Subsystem() - Empty argument(s)!"
     return
  }

  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     puts "ERROR: Unable to find parent cell <$parentCell>!"
     return
  }

  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
     return
  }

  set oldCurInst [current_bd_instance .]
  current_bd_instance $parentObj

  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 AXI_GPIO
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M01_AXI_0
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M02_AXI_0
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M03_AXI_0
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M04_AXI_0

  # Create pins
  # NOTE: No external clk pin for UltraZed - using pl_clk0 from PS instead
  create_bd_pin -dir O -from 0 -to 0 global_rst_n
  create_bd_pin -dir O global_clk

  # Create instance: proc_sys_reset_0
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset proc_sys_reset_0 ]

  # Create instance: clk_wiz_0
  # Configured for 100 MHz input from PS pl_clk0, 50 MHz output
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.PRIM_SOURCE {Global_buffer} \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000} \
    CONFIG.CLKOUT2_DRIVES {Buffer} \
    CONFIG.CLKOUT2_USED {false} \
    CONFIG.CLKOUT3_DRIVES {Buffer} \
    CONFIG.CLKOUT4_DRIVES {Buffer} \
    CONFIG.CLKOUT5_DRIVES {Buffer} \
    CONFIG.CLKOUT6_DRIVES {Buffer} \
    CONFIG.CLKOUT7_DRIVES {Buffer} \
    CONFIG.MMCM_COMPENSATION {AUTO} \
    CONFIG.NUM_OUT_CLKS {1} \
    CONFIG.USE_LOCKED {false} \
    CONFIG.USE_PHASE_ALIGNMENT {true} \
    CONFIG.USE_RESET {false} \
  ] $clk_wiz_0

  # Create instance: zynq_ultra_ps_e_0
  # Configure PS using UltraZed preset
  set zynq_ultra_ps_e_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0 ]


  # Source and apply the UltraZed preset
  global script_dir preset_file_name
  set preset_file [file join $script_dir $preset_file_name]
  if {[file exists $preset_file]} {
    puts "Applying preset from $preset_file..."
    source $preset_file

    set preset_config [apply_preset $zynq_ultra_ps_e_0]
    set_property -dict $preset_config $zynq_ultra_ps_e_0
  } else {
    puts "WARNING: Preset file not found at $preset_file"
    puts "         Using default PS configuration..."
    set_property -dict [list \
      CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x00000002} \
      CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} \
      CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE {0} \
      CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} \
      CONFIG.PSU__USE__M_AXI_GP0 {1} \
      CONFIG.PSU__USE__M_AXI_GP2 {0} \
      CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
      CONFIG.PSU__FPGA_PL0_ENABLE {1} \
      CONFIG.PSU__UART0__PERIPHERAL__ENABLE {1} \
      CONFIG.PSU__UART0__PERIPHERAL__IO {MIO 34 .. 35} \
      CONFIG.PSU__UART0__BAUD_RATE {115200} \
      CONFIG.PSU__UART1__PERIPHERAL__ENABLE {1} \
      CONFIG.PSU__UART1__PERIPHERAL__IO {MIO 32 .. 33} \
      CONFIG.PSU__UART1__BAUD_RATE {115200} \
      CONFIG.PSU__USB0__PERIPHERAL__ENABLE {1} \
      CONFIG.PSU__USB0__PERIPHERAL__IO {MIO 52 .. 63} \
      CONFIG.PSU__USB0__RESET__ENABLE {0} \
      CONFIG.PSU__USB__RESET__MODE {Boot Pin} \
      CONFIG.PSU__USB__RESET__POLARITY {Active Low} \
      CONFIG.PSU__USB1__RESET__ENABLE {0} \
      CONFIG.PSU__TTC0__PERIPHERAL__ENABLE {1} \
      CONFIG.PSU__TTC1__PERIPHERAL__ENABLE {1} \
      CONFIG.PSU__TTC2__PERIPHERAL__ENABLE {1} \
      CONFIG.PSU__TTC3__PERIPHERAL__ENABLE {1} \
    ] $zynq_ultra_ps_e_0
  }

  # Override specific settings needed for this design
  set_property -dict [list \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
  ] $zynq_ultra_ps_e_0

  # Sync clk_wiz_0 input frequency to the actual PS pl_clk0 rate to avoid FREQ_HZ mismatch.
  set pl_clk0_pin [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]
  set pl_clk0_freq_hz [get_property FREQ_HZ $pl_clk0_pin]
  if {$pl_clk0_freq_hz eq ""} {
    set pl_clk0_freq_hz [get_property CONFIG.FREQ_HZ $pl_clk0_pin]
  }
  if {$pl_clk0_freq_hz ne ""} {
    set pl_clk0_freq_mhz [format "%.6f" [expr {$pl_clk0_freq_hz / 1000000.0}]]
    set_property -dict [list CONFIG.PRIM_IN_FREQ $pl_clk0_freq_mhz] $clk_wiz_0
    catch {set_property -dict [list CONFIG.FREQ_HZ $pl_clk0_freq_hz] [get_bd_pins clk_wiz_0/clk_in1]}
  } else {
    puts "WARNING: Unable to read pl_clk0 FREQ_HZ; clk_wiz_0 PRIM_IN_FREQ not updated."
  }

  # Create instance: smartconnect_0
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_0 ]
  set_property -dict [list \
    CONFIG.NUM_MI {5} \
    CONFIG.NUM_SI {2} \
  ] $smartconnect_0

  # Create instance: jtag_axi_0
  set jtag_axi_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi jtag_axi_0 ]

  # Create interface connections
  connect_bd_intf_net [get_bd_intf_pins jtag_axi_0/M_AXI] [get_bd_intf_pins smartconnect_0/S01_AXI]
  connect_bd_intf_net [get_bd_intf_pins M01_AXI_0] [get_bd_intf_pins smartconnect_0/M00_AXI]
  connect_bd_intf_net [get_bd_intf_pins AXI_GPIO] [get_bd_intf_pins smartconnect_0/M01_AXI]
  connect_bd_intf_net [get_bd_intf_pins M02_AXI_0] [get_bd_intf_pins smartconnect_0/M02_AXI]
  connect_bd_intf_net [get_bd_intf_pins M03_AXI_0] [get_bd_intf_pins smartconnect_0/M03_AXI]
  connect_bd_intf_net [get_bd_intf_pins M04_AXI_0] [get_bd_intf_pins smartconnect_0/M04_AXI]
  connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins smartconnect_0/S00_AXI]

  # Create port connections
  # Clock: PS pl_clk0 (100 MHz) -> clk_wiz_0 -> 50 MHz output
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins clk_wiz_0/clk_in1]
  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins global_clk] [get_bd_pins smartconnect_0/aclk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk] [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_pins jtag_axi_0/aclk]
  


  # If S_AXI_GP3/HP1 is enabled, drive its ACLK from the PL clock.
  set hp1_aclk_pin [get_bd_pins -quiet zynq_ultra_ps_e_0/saxihp1_fpd_aclk]
  if {$hp1_aclk_pin ne ""} {
    connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] $hp1_aclk_pin
  }
  connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins global_rst_n] [get_bd_pins smartconnect_0/aresetn] [get_bd_pins jtag_axi_0/aresetn]
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins proc_sys_reset_0/ext_reset_in]

  current_bd_instance $oldCurInst
}

# ==============================================================================
# Create the root design
# ==============================================================================
puts "\n>>> Creating block design hierarchy..."

set parentCell [get_bd_cells /]
set oldCurInst [current_bd_instance .]
current_bd_instance $parentCell

# Create ports
# NOTE: No external clk port for UltraZed-3EG - clock comes from PS pl_clk0
set spi_clk [ create_bd_port -dir O spi_clk ]
set miso [ create_bd_port -dir I miso ]
set mosi [ create_bd_port -dir O mosi ]
set spi_cs_n [ create_bd_port -dir O spi_cs_n ]
set debug [ create_bd_port -dir O -from 3 -to 0 debug ]
set LEDS [ create_bd_port -dir O -from 6 -to 0 LEDS ]
set hb_led [ create_bd_port -dir O -from 0 -to 0 hb_led ]
set dclk_out [ create_bd_port -dir O dclk_out ]
set odr_out [ create_bd_port -dir O odr_out ]
set data_in0 [ create_bd_port -dir I data_in0 ]
set data_in1 [ create_bd_port -dir I data_in1 ]
set data_in2 [ create_bd_port -dir I data_in2 ]
set data_in3 [ create_bd_port -dir I data_in3 ]

# Create hierarchical cells
create_hier_cell_Processing_Subsystem [current_bd_instance .] Processing_Subsystem
create_hier_cell_SPI_Control [current_bd_instance .] SPI_Control
create_hier_cell_LEDS [current_bd_instance .] LEDS
create_hier_cell_bram_tester [current_bd_instance .] bram_tester
create_hier_cell_ADC_BRAM [current_bd_instance .] ADC_BRAM

# Create instance: ad4134_data_0 (module reference)
set ad4134_data_0 [create_bd_cell -type module -reference ad4134_data ad4134_data_0]

# Create instance: ila_0
set ila_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ila ila_0 ]
set_property -dict [list \
  CONFIG.C_ADV_TRIGGER {true} \
  CONFIG.C_DATA_DEPTH {131072} \
  CONFIG.C_EN_STRG_QUAL {1} \
  CONFIG.C_MONITOR_TYPE {Native} \
  CONFIG.C_NUM_OF_PROBES {6} \
] $ila_0

# Create interface connections
connect_bd_intf_net [get_bd_intf_pins LEDS/S_AXI] [get_bd_intf_pins Processing_Subsystem/AXI_GPIO]
connect_bd_intf_net [get_bd_intf_pins Processing_Subsystem/M01_AXI_0] [get_bd_intf_pins bram_tester/BRAM_INIT]
connect_bd_intf_net [get_bd_intf_pins Processing_Subsystem/M02_AXI_0] [get_bd_intf_pins bram_tester/BRAM_READ]
connect_bd_intf_net [get_bd_intf_pins Processing_Subsystem/M03_AXI_0] [get_bd_intf_pins ADC_BRAM/ADC_BRAM_Reader]
connect_bd_intf_net [get_bd_intf_pins Processing_Subsystem/M04_AXI_0] [get_bd_intf_pins ADC_BRAM/adc_bram_enable]

# Create port connections
connect_bd_net [get_bd_pins ADC_BRAM/debug_0] [get_bd_ports debug]
connect_bd_net [get_bd_pins Processing_Subsystem/global_clk] [get_bd_pins SPI_Control/clk] [get_bd_pins LEDS/s_axi_aclk] [get_bd_pins bram_tester/clk] [get_bd_pins ADC_BRAM/clk] [get_bd_pins ad4134_data_0/clk] [get_bd_pins ila_0/clk]
connect_bd_net [get_bd_pins Processing_Subsystem/global_rst_n] [get_bd_pins SPI_Control/rstn] [get_bd_pins LEDS/s_axi_aresetn] [get_bd_pins bram_tester/rst_n] [get_bd_pins ADC_BRAM/rst_n] [get_bd_pins ad4134_data_0/rst_n]
connect_bd_net [get_bd_pins SPI_Control/spi_clk] [get_bd_ports spi_clk] [get_bd_pins ila_0/probe3]
connect_bd_net [get_bd_pins ad4134_data_0/data_out0] [get_bd_pins ADC_BRAM/data_in0_0]
connect_bd_net [get_bd_pins ad4134_data_0/data_out1] [get_bd_pins ADC_BRAM/data_in1_0]
connect_bd_net [get_bd_pins ad4134_data_0/data_out2] [get_bd_pins ADC_BRAM/data_in2_0]
connect_bd_net [get_bd_pins ad4134_data_0/data_out3] [get_bd_pins ADC_BRAM/data_in3_0]
connect_bd_net [get_bd_pins ad4134_data_0/data_rdy] [get_bd_pins ADC_BRAM/data_rdy_0]
connect_bd_net [get_bd_pins ad4134_data_0/dclk_out] [get_bd_ports dclk_out] [get_bd_pins ila_0/probe1]
connect_bd_net [get_bd_pins ad4134_data_0/odr_out] [get_bd_ports odr_out] [get_bd_pins ila_0/probe0]
# NOTE: No external clk connection for UltraZed - PS pl_clk0 is used internally
connect_bd_net [get_bd_ports data_in0] [get_bd_pins ad4134_data_0/data_in0] [get_bd_pins ila_0/probe2]
connect_bd_net [get_bd_ports data_in1] [get_bd_pins ad4134_data_0/data_in1]
connect_bd_net [get_bd_ports data_in2] [get_bd_pins ad4134_data_0/data_in2]
connect_bd_net [get_bd_ports data_in3] [get_bd_pins ad4134_data_0/data_in3]
connect_bd_net [get_bd_ports miso] [get_bd_pins SPI_Control/miso]
connect_bd_net [get_bd_pins SPI_Control/spi_cs_n] [get_bd_ports spi_cs_n] [get_bd_pins ila_0/probe4]
connect_bd_net [get_bd_pins SPI_Control/mosi] [get_bd_ports mosi] [get_bd_pins ila_0/probe5]
connect_bd_net [get_bd_pins LEDS/LEDS] [get_bd_ports LEDS]
connect_bd_net [get_bd_pins LEDS/hb_led] [get_bd_ports hb_led]

# Create address segments
assign_bd_address -offset 0xA0000000 -range 0x00002000 -target_address_space [get_bd_addr_spaces Processing_Subsystem/zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ADC_BRAM/ADC_BRAM_READ/S_AXI/Mem0] -force
assign_bd_address -offset 0xA0010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces Processing_Subsystem/zynq_ultra_ps_e_0/Data] [get_bd_addr_segs ADC_BRAM/adc_bram_enable/S_AXI/Reg] -force
assign_bd_address -offset 0xA0020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces Processing_Subsystem/zynq_ultra_ps_e_0/Data] [get_bd_addr_segs LEDS/axi_gpio_0/S_AXI/Reg] -force
assign_bd_address -offset 0xA0002000 -range 0x00002000 -target_address_space [get_bd_addr_spaces Processing_Subsystem/zynq_ultra_ps_e_0/Data] [get_bd_addr_segs bram_tester/bram_read/S_AXI/Mem0] -force
assign_bd_address -offset 0xA0030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces Processing_Subsystem/zynq_ultra_ps_e_0/Data] [get_bd_addr_segs bram_tester/bram_test_control/S_AXI/Reg] -force
assign_bd_address -offset 0xA0000000 -range 0x00002000 -target_address_space [get_bd_addr_spaces Processing_Subsystem/jtag_axi_0/Data] [get_bd_addr_segs ADC_BRAM/ADC_BRAM_READ/S_AXI/Mem0] -force
assign_bd_address -offset 0xA0010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces Processing_Subsystem/jtag_axi_0/Data] [get_bd_addr_segs ADC_BRAM/adc_bram_enable/S_AXI/Reg] -force
assign_bd_address -offset 0xA0020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces Processing_Subsystem/jtag_axi_0/Data] [get_bd_addr_segs LEDS/axi_gpio_0/S_AXI/Reg] -force
assign_bd_address -offset 0xA0002000 -range 0x00002000 -target_address_space [get_bd_addr_spaces Processing_Subsystem/jtag_axi_0/Data] [get_bd_addr_segs bram_tester/bram_read/S_AXI/Mem0] -force
assign_bd_address -offset 0xA0030000 -range 0x00010000 -target_address_space [get_bd_addr_spaces Processing_Subsystem/jtag_axi_0/Data] [get_bd_addr_segs bram_tester/bram_test_control/S_AXI/Reg] -force

current_bd_instance $oldCurInst

# ==============================================================================
# Step 5: Validate and Save Block Design
# ==============================================================================
puts "\n>>> Step 5: Validating block design..."

if {[catch {validate_bd_design} err]} {
    puts "WARNING: Block design validation reported issues:"
    puts "         $err"
    puts "         This may be normal - continuing..."
}

save_bd_design
puts "Block design saved."

# ==============================================================================
# Step 6: Generate Output Products
# ==============================================================================
puts "\n>>> Step 6: Generating output products..."

set bd_file [get_files ${design_name}.bd]
generate_target all $bd_file

# ==============================================================================
# Step 7: Create HDL Wrapper
# ==============================================================================
puts "\n>>> Step 7: Creating HDL wrapper..."

set wrapper_path [make_wrapper -files $bd_file -top]
add_files -norecurse $wrapper_path
set_property top ad4134fw_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "Wrapper created: $wrapper_path"

# ------------------------------------------------------------------------------
# Step 7a: Patch wrapper to expose ad4134_dclk_mode tied LOW (gated DCLK)
# ------------------------------------------------------------------------------
if {[file exists $wrapper_path]} {
  if {[string match "*.vhd" $wrapper_path]} {
    set fh [open $wrapper_path r]
    set txt [read $fh]
    close $fh

    if {![string match "*ad4134_dclk_mode*" $txt]} {
      # Add port to entity (first occurrence is entity, not component)
      set new_txt $txt
      if {[regsub {dclk_out : out STD_LOGIC;} $new_txt {dclk_out : out STD_LOGIC;
    ad4134_dclk_mode : out STD_LOGIC;} new_txt]} {
        # Tie the port low near end of architecture
        if {[regsub {end STRUCTURE;} $new_txt {  -- Force gated DCLK mode (DEC1/DCLKMODE = 0).
  ad4134_dclk_mode <= '0';
end STRUCTURE;} new_txt]} {
          set fh [open $wrapper_path w]
          puts -nonewline $fh $new_txt
          close $fh
          puts "Patched wrapper with ad4134_dclk_mode tied LOW."
        } else {
          puts "WARNING: Could not insert ad4134_dclk_mode assignment."
        }
      } else {
        puts "WARNING: Could not insert ad4134_dclk_mode port in wrapper."
      }
    } else {
      puts "Wrapper already includes ad4134_dclk_mode."
    }
  } else {
    puts "NOTE: Wrapper is not VHDL; skipping ad4134_dclk_mode patch."
  }
} else {
  puts "WARNING: Wrapper file not found; skipping ad4134_dclk_mode patch."
}

# ==============================================================================
# Step 8: Add Simulation Sources
# ==============================================================================
puts "\n>>> Step 8: Adding simulation sources..."

if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 -norecurse $sim_files
    puts "Added [llength $sim_files] testbench files"
}

# ==============================================================================
# Summary
# ==============================================================================
puts ""
puts "=============================================================================="
puts "Project Recreation Complete!"
puts "=============================================================================="
puts "Project location: $proj_dir/$proj_name.xpr"
puts ""
puts "Next steps:"
puts "  1. Open project: vivado $proj_dir/$proj_name.xpr"
puts "  2. Check for IP upgrade messages (Tools > Report > Report IP Status)"
puts "  3. If IPs are locked, upgrade them: upgrade_ip \[get_ips *\]"
puts "  4. Regenerate outputs: generate_target all \[get_files *.bd\]"
puts "  5. Run synthesis: launch_runs synth_1"
puts "  6. Run implementation: launch_runs impl_1"
puts "=============================================================================="
