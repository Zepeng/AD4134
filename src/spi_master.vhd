library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
    port(
        clk         : in  std_logic;
        rst_n       : in  std_logic;

        spi_write   : in  std_logic;
        spi_read    : in  std_logic;

        datain      : in  std_logic_vector(7 downto 0);
        dataout     : out std_logic_vector(7 downto 0);
        spiaddr     : in  std_logic_vector(7 downto 0);

        spidone     : out std_logic;

        mosi        : out std_logic;
        miso        : in  std_logic;
        cs_n        : out std_logic;
        spi_clk     : out std_logic
    );
end entity spi_master;

architecture rtl of spi_master is

    type spi_state_t is (IDLE, LOAD, TRANSFER, FINISH);
    signal state : spi_state_t;

    signal shift_out : std_logic_vector(15 downto 0);
    signal shift_in  : std_logic_vector(7 downto 0);

    signal bit_cnt   : integer range 0 to 15;
    signal sclk      : std_logic;

    signal spi_write_i, spi_write_ii : std_logic;
    signal spi_read_i,  spi_read_ii  : std_logic;

    signal spidone_i : std_logic;
    signal cs_n_i    : std_logic;

begin

    spidone <= spidone_i;
    dataout <= shift_in;
    cs_n    <= cs_n_i;
    spi_clk <= sclk;

    -------------------------------------------------------------------
    -- Double-flop control inputs
    -------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            spi_write_i  <= '0';
            spi_write_ii <= '0';
            spi_read_i   <= '0';
            spi_read_ii  <= '0';
        elsif rising_edge(clk) then
            spi_write_i  <= spi_write;
            spi_write_ii <= spi_write_i;
            spi_read_i   <= spi_read;
            spi_read_ii  <= spi_read_i;
        end if;
    end process;

    -------------------------------------------------------------------
    -- SPI FSM
    -------------------------------------------------------------------
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state     <= IDLE;
            cs_n_i    <= '1';
            sclk      <= '0';
            mosi      <= '0';
            bit_cnt   <= 0;
            shift_out <= (others => '0');
            shift_in  <= (others => '0');
            spidone_i <= '0';

        elsif rising_edge(clk) then
            spidone_i <= '0';

            case state is

                --------------------------------------------------------
                when IDLE =>
                    cs_n_i <= '1';
                    sclk   <= '0';

                    if (spi_write_ii = '1') or (spi_read_ii = '1') then
                        state <= LOAD;
                    end if;

                --------------------------------------------------------
                when LOAD =>
                    cs_n_i <= '0';

                    -- R/W bit + 7-bit address + data
                    shift_out <= spi_write_ii & spiaddr(6 downto 0) & datain;
                    bit_cnt   <= 15;
                    mosi      <= shift_out(15);
                    state     <= TRANSFER;

                --------------------------------------------------------
                when TRANSFER =>
                    sclk <= not sclk;
                                
                    -- Falling edge: drive MOSI
                    if sclk = '1' then
                        shift_out <= shift_out(14 downto 0) & '0';
                        mosi      <= shift_out(14);
                    
                    -- Rising edge: sample MISO
                    else
                        shift_in <= shift_in(6 downto 0) & miso;
                    
                        if bit_cnt = 0 then
                            state <= FINISH;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                --------------------------------------------------------
                when FINISH =>
                    cs_n_i    <= '1';
                    sclk      <= '0';
                    spidone_i <= '1';
                    state     <= IDLE;

            end case;
        end if;
    end process;

end architecture rtl;