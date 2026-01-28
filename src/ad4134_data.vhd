library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- AD4134 Data Capture Module (Slave Mode)
-- Based on ADI reference design axi_ad4134_sif.v
-- Uses state machine approach for clean DCLK generation and data sampling

entity ad4134_data is
    generic(
        DATA_WIDTH : integer := 24;
        -- Clock divider controls DCLK frequency
        -- DCLK LOW phase  = (CLK_DIV + 1) clock cycles
        -- DCLK HIGH phase = (CLK_DIV + 2) clock cycles (extra cycle for t6 setup)
        -- At 80 MHz with CLK_DIV=1: LOW=25ns, HIGH=37.5ns, period=62.5ns (~16 MHz)
        CLK_DIV    : integer := 1
    );
    port(
        -- Global signals:
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        -- AD4134 signals:
        data_in0  : in  std_logic;
        data_in1  : in  std_logic;
        data_in2  : in  std_logic;
        data_in3  : in  std_logic;
        dclk_out  : out std_logic;
        odr_out   : out std_logic;
        -- Output signals:
        data_out0 : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_out1 : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_out2 : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_out3 : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_rdy  : out std_logic
    );
end ad4134_data;

architecture rtl of ad4134_data is

    -- State machine states (following ADI design)
    type state_t is (
        STATE_IDLE,   -- Wait for ODR interval
        STATE_ODR,    -- Generate ODR pulse
        STATE_LOW,    -- DCLK low phase
        STATE_HIGH,   -- DCLK high phase (sample at end)
        STATE_DONE    -- Transfer data to output
    );
    signal state : state_t := STATE_IDLE;

    -- Timing constants
    -- ODR idle period between captures (adjustable for desired sample rate)
    constant ODR_IDLE_CLKS : integer := 12;  -- Idle time between captures
    constant ODR_PULSE_CLKS : integer := 8;  -- ODR high pulse width

    -- Clock divider counter (needs +1 for setup time in HIGH phase)
    signal clk_counter : integer range 0 to CLK_DIV + 1 := 0;

    -- Bit counter (counts down from DATA_WIDTH)
    signal bit_counter : integer range 0 to DATA_WIDTH := DATA_WIDTH;

    -- ODR interval counter
    signal odr_counter : integer range 0 to ODR_IDLE_CLKS + ODR_PULSE_CLKS := 0;

    -- Shift registers for incoming data
    signal shift_reg0 : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal shift_reg1 : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal shift_reg2 : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal shift_reg3 : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

    -- Internal output registers
    signal dclk_int : std_logic := '0';
    signal odr_int  : std_logic := '0';

begin

    -- Output assignments
    dclk_out <= dclk_int;
    odr_out  <= odr_int;

    ---------------------------------------------------------------------------
    -- Main state machine process
    -- Follows ADI axi_ad4134_sif.v design pattern
    ---------------------------------------------------------------------------
    fsm_p : process(clk, rst_n)
    begin
        if (rst_n = '0') then
            state       <= STATE_IDLE;
            dclk_int    <= '0';
            odr_int     <= '0';
            data_rdy    <= '0';
            clk_counter <= 0;
            bit_counter <= DATA_WIDTH;
            odr_counter <= 0;
            shift_reg0  <= (others => '0');
            shift_reg1  <= (others => '0');
            shift_reg2  <= (others => '0');
            shift_reg3  <= (others => '0');
            data_out0   <= (others => '0');
            data_out1   <= (others => '0');
            data_out2   <= (others => '0');
            data_out3   <= (others => '0');

        elsif (rising_edge(clk)) then
            -- Default: clear single-cycle pulses
            data_rdy <= '0';

            case state is
                ---------------------------------------------------------------
                -- STATE_IDLE: Wait between ODR cycles
                ---------------------------------------------------------------
                when STATE_IDLE =>
                    dclk_int <= '0';
                    odr_int  <= '0';

                    if (odr_counter < ODR_IDLE_CLKS) then
                        odr_counter <= odr_counter + 1;
                    else
                        -- Start new ODR cycle
                        odr_counter <= 0;
                        state <= STATE_ODR;
                    end if;

                ---------------------------------------------------------------
                -- STATE_ODR: Generate ODR pulse, then start DCLK
                ---------------------------------------------------------------
                when STATE_ODR =>
                    dclk_int <= '0';
                    odr_int  <= '1';  -- ODR high

                    if (odr_counter < ODR_PULSE_CLKS - 1) then
                        odr_counter <= odr_counter + 1;
                    else
                        -- End ODR pulse, start data phase
                        odr_counter <= 0;
                        odr_int     <= '0';
                        bit_counter <= DATA_WIDTH;
                        clk_counter <= CLK_DIV;
                        -- Clear shift registers
                        shift_reg0 <= (others => '0');
                        shift_reg1 <= (others => '0');
                        shift_reg2 <= (others => '0');
                        shift_reg3 <= (others => '0');
                        state <= STATE_LOW;
                    end if;

                ---------------------------------------------------------------
                -- STATE_LOW: DCLK low phase
                -- Wait for clock divider, then transition to HIGH
                ---------------------------------------------------------------
                when STATE_LOW =>
                    dclk_int <= '0';
                    odr_int  <= '0';

                    if (clk_counter = 0) then
                        -- Add 1 extra cycle for setup time in HIGH phase
                        -- This ensures data is valid before sampling
                        -- (AD4134 t6 = 8.2ns, 1 cycle at 80MHz = 12.5ns)
                        clk_counter <= CLK_DIV + 1;
                        state <= STATE_HIGH;
                    else
                        clk_counter <= clk_counter - 1;
                    end if;

                ---------------------------------------------------------------
                -- STATE_HIGH: DCLK high phase
                -- Sample data at end of HIGH phase (like ADI design)
                -- Timing at 80 MHz with CLK_DIV=1:
                --   T=0:    DCLK rises (dclk_int becomes '1')
                --   T=8.2:  Data valid (AD4134 t6 spec)
                --   T=12.5: First clock edge after DCLK rise
                --   T=25.0: Sample data (clk_counter=0), margin=25-8.2=16.8ns
                --   T=37.5: DCLK falls (transition to STATE_LOW)
                ---------------------------------------------------------------
                when STATE_HIGH =>
                    dclk_int <= '1';
                    odr_int  <= '0';

                    if (clk_counter = 0) then
                        clk_counter <= CLK_DIV;

                        -- Sample data at end of DCLK high phase (ADI approach)
                        -- Shift in MSB first
                        shift_reg0 <= shift_reg0(DATA_WIDTH - 2 downto 0) & data_in0;
                        shift_reg1 <= shift_reg1(DATA_WIDTH - 2 downto 0) & data_in1;
                        shift_reg2 <= shift_reg2(DATA_WIDTH - 2 downto 0) & data_in2;
                        shift_reg3 <= shift_reg3(DATA_WIDTH - 2 downto 0) & data_in3;

                        if (bit_counter <= 1) then
                            -- All bits captured
                            state <= STATE_DONE;
                        else
                            bit_counter <= bit_counter - 1;
                            state <= STATE_LOW;
                        end if;
                    else
                        clk_counter <= clk_counter - 1;
                    end if;

                ---------------------------------------------------------------
                -- STATE_DONE: Transfer data to outputs
                ---------------------------------------------------------------
                when STATE_DONE =>
                    dclk_int <= '0';
                    odr_int  <= '0';

                    -- Transfer shift registers to output
                    data_out0 <= shift_reg0;
                    data_out1 <= shift_reg1;
                    data_out2 <= shift_reg2;
                    data_out3 <= shift_reg3;
                    data_rdy  <= '1';

                    -- Reset for next cycle
                    odr_counter <= 0;
                    state <= STATE_IDLE;

                ---------------------------------------------------------------
                -- Default
                ---------------------------------------------------------------
                when others =>
                    state <= STATE_IDLE;

            end case;
        end if;
    end process;

end rtl;
