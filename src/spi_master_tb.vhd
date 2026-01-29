library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_spi_master is
end entity;

architecture sim of tb_spi_master is

    ------------------------------------------------------------------
    -- DUT signals
    ------------------------------------------------------------------
    signal clk       : std_logic := '0';
    signal rst_n     : std_logic := '0';

    signal spi_write : std_logic := '0';
    signal spi_read  : std_logic := '0';

    signal datain    : std_logic_vector(7 downto 0) := x"A5";
    signal dataout   : std_logic_vector(7 downto 0);
    signal spiaddr   : std_logic_vector(7 downto 0) := x"12";

    signal spidone   : std_logic;

    signal mosi      : std_logic;
    signal miso      : std_logic := '0';
    signal cs_n      : std_logic;
    signal spi_clk   : std_logic;

    ------------------------------------------------------------------
    -- SPI slave model
    ------------------------------------------------------------------
    constant SLAVE_RESP : std_logic_vector(7 downto 0) := x"3C";
    signal slave_shift  : std_logic_vector(7 downto 0);
    signal slave_cnt    : integer range 0 to 7;

begin

    ------------------------------------------------------------------
    -- Clock generation (50 MHz)
    ------------------------------------------------------------------
    clk <= not clk after 10 ns;

    ------------------------------------------------------------------
    -- DUT instantiation
    ------------------------------------------------------------------
    dut : entity work.spi_master
        port map (
            clk       => clk,
            rst_n     => rst_n,
            spi_write => spi_write,
            spi_read  => spi_read,
            datain    => datain,
            dataout   => dataout,
            spiaddr   => spiaddr,
            spidone   => spidone,
            mosi      => mosi,
            miso      => miso,
            cs_n      => cs_n,
            spi_clk   => spi_clk
        );

    ------------------------------------------------------------------
    -- Reset
    ------------------------------------------------------------------
    reset_p : process
    begin
        rst_n <= '0';
        wait for 100 ns;
        rst_n <= '1';
        wait;
    end process;

    ------------------------------------------------------------------
    -- Stimulus
    ------------------------------------------------------------------
    stimulus_p : process
    begin
        wait until rst_n = '1';
        wait for 50 ns;

        spi_write <= '1';
        wait for 20 ns;
        spi_write <= '0';

        wait until spidone = '1';
        wait for 100 ns;

        assert dataout = SLAVE_RESP
            report "SPI READ DATA MISMATCH"
            severity failure;

        report "SPI transaction successful 🎉";
        wait;
    end process;

    ------------------------------------------------------------------
    -- Simple SPI slave model
    -- CPOL=0, CPHA=1:
    --  - Drive MISO on falling edge
    ------------------------------------------------------------------
    slave_p : process
    begin
        wait until cs_n = '0';

        slave_shift <= SLAVE_RESP;
        slave_cnt   <= 7;

        while cs_n = '0' loop
            wait until falling_edge(spi_clk);

            miso <= slave_shift(slave_cnt);

            if slave_cnt = 0 then
                slave_cnt <= 7;
            else
                slave_cnt <= slave_cnt - 1;
            end if;
        end loop;

        miso <= '0';
    end process;

    ------------------------------------------------------------------
    -- Optional MOSI monitor (for waveform clarity)
    ------------------------------------------------------------------
    monitor_p : process
    begin
        wait until cs_n = '0';
        report "SPI CS asserted";

        while cs_n = '0' loop
            wait until falling_edge(spi_clk);
            report "MOSI bit = " & std_logic'image(mosi);
        end loop;

        report "SPI CS deasserted";
    end process;

end architecture sim;
