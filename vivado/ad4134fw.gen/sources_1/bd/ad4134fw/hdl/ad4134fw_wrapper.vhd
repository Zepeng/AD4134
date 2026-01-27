--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
--Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2024.2 (win64) Build 5239630 Fri Nov 08 22:35:27 MST 2024
--Date        : Tue Dec  2 20:25:06 2025
--Host        : DESKTOP-NG70LRJ running 64-bit major release  (build 9200)
--Command     : generate_target ad4134fw_wrapper.bd
--Design      : ad4134fw_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity ad4134fw_wrapper is
  port (
    LEDS : out STD_LOGIC_VECTOR ( 6 downto 0 );
    clk : in STD_LOGIC;
    data_in0 : in STD_LOGIC;
    data_in1 : in STD_LOGIC;
    data_in2 : in STD_LOGIC;
    data_in3 : in STD_LOGIC;
    dclk_out : out STD_LOGIC;
    ad4134_dclk_mode : out STD_LOGIC;
    debug : out STD_LOGIC_VECTOR ( 3 downto 0 );
    hb_led : out STD_LOGIC_VECTOR ( 0 to 0 );
    miso : in STD_LOGIC;
    mosi : out STD_LOGIC;
    odr_out : out STD_LOGIC;
    spi_clk : out STD_LOGIC;
    spi_cs_n : out STD_LOGIC
  );
end ad4134fw_wrapper;

architecture STRUCTURE of ad4134fw_wrapper is
  component ad4134fw is
  port (
    spi_clk : out STD_LOGIC;
    miso : in STD_LOGIC;
    mosi : out STD_LOGIC;
    spi_cs_n : out STD_LOGIC;
    debug : out STD_LOGIC_VECTOR ( 3 downto 0 );
    LEDS : out STD_LOGIC_VECTOR ( 6 downto 0 );
    hb_led : out STD_LOGIC_VECTOR ( 0 to 0 );
    dclk_out : out STD_LOGIC;
    ad4134_dclk_mode : out STD_LOGIC;
    odr_out : out STD_LOGIC;
    data_in0 : in STD_LOGIC;
    data_in1 : in STD_LOGIC;
    data_in2 : in STD_LOGIC;
    data_in3 : in STD_LOGIC;
    clk : in STD_LOGIC
  );
  end component ad4134fw;
begin
ad4134fw_i: component ad4134fw
     port map (
      LEDS(6 downto 0) => LEDS(6 downto 0),
      clk => clk,
      data_in0 => data_in0,
      data_in1 => data_in1,
      data_in2 => data_in2,
      data_in3 => data_in3,
      dclk_out => dclk_out,
      debug(3 downto 0) => debug(3 downto 0),
      hb_led(0) => hb_led(0),
      miso => miso,
      mosi => mosi,
      odr_out => odr_out,
      spi_clk => spi_clk,
      spi_cs_n => spi_cs_n
    );
  -- Force gated DCLK mode (DEC1/DCLKMODE = 0).
  ad4134_dclk_mode <= '0';
end STRUCTURE;
