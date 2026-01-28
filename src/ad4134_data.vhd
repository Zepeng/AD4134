library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ad4134_data is
    generic(
        DATA_WIDTH : integer := 24
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

    -- Constants:
    -- Timing constants based on ADI reference design analysis:
    -- ADI uses ODR high ~130 ns, DCLK starts 30 ns after ODR starts
    -- Increased margins for reliable high-speed operation
    constant ODR_HIGH_TIME  : integer := 6;   -- Longer ODR pulse (~300 ns)
    constant ODR_LOW_TIME   : integer := 24;  -- 24 bits of data
    constant ODR_WAIT_FIRST : integer := 4;   -- More setup time before DCLK
    constant ODR_WAIT_LAST  : integer := 6;   -- Reduced to maintain ODR rate

    -- ODR Tracker signals:
    constant ODR_TOTAL_CLKS : integer := ODR_HIGH_TIME + ODR_WAIT_FIRST + ODR_LOW_TIME + ODR_WAIT_LAST;
    signal   odr_tracker    : integer range 0 to ODR_TOTAL_CLKS;

    -- Internal control registers:
    signal odr_int     : std_logic := '0';
    signal dclk_int    : std_logic := '0';
    signal dclk_out_r  : std_logic := '0';
    signal bit_count   : integer range 0 to DATA_WIDTH;

    signal shift_reg0 : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal shift_reg1 : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal shift_reg2 : std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal shift_reg3 : std_logic_vector(DATA_WIDTH - 1 downto 0);

    -- Flags:
    signal dclk_active : std_logic;
    signal dclk_gate   : std_logic := '0';  -- Gating signal for complete DCLK pulses

    -- Clock divider for DCLK timing
    constant SLOW_CLK_MAX : integer := 1;
    signal slow_clk_counter : integer range 0 to SLOW_CLK_MAX;

    -- Clock enable signals (active for one clk cycle)
    signal dclk_rise_en : std_logic;
    signal dclk_fall_en : std_logic;

    -- Read flags:
    signal data_rdy_flag : std_logic;

    -- Delayed sampling signals for timing margin
    -- ADI reference design approach: sample on falling edge for better margin
    -- AD4134 slave mode: t6 = 8.2 ns max (DCLK rise to data valid)
    -- Falling edge gives ~(DCLK_high - t6) margin before next edge
    signal dclk_fall_d1   : std_logic := '0';
    signal dclk_fall_d2   : std_logic := '0';  -- Delayed falling edge for sampling
    signal dclk_gate_d1   : std_logic := '0';
    signal dclk_gate_d2   : std_logic := '0';  -- Aligned with sampling

begin

    -- Registered outputs to avoid glitches
    dclk_out <= dclk_out_r;
    odr_out  <= odr_int;

    ---------------------------------------------------------------------------
    -- Clock divider: generates clock enables for DCLK edges
    ---------------------------------------------------------------------------
    clk_div_p : process(clk, rst_n)
    begin
        if (rst_n = '0') then
            slow_clk_counter <= 0;
            dclk_int         <= '0';
            dclk_rise_en     <= '0';
            dclk_fall_en     <= '0';
        elsif (rising_edge(clk)) then
            dclk_rise_en <= '0';
            dclk_fall_en <= '0';

            if (slow_clk_counter < SLOW_CLK_MAX) then
                slow_clk_counter <= slow_clk_counter + 1;
            else
                slow_clk_counter <= 0;
                dclk_int <= not dclk_int;

                if (dclk_int = '0') then
                    dclk_rise_en <= '1';
                else
                    dclk_fall_en <= '1';
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- ODR and DCLK output control
    ---------------------------------------------------------------------------
    odr_p : process(clk, rst_n)
    begin
        if (rst_n = '0') then
            odr_tracker <= 0;
            odr_int     <= '0';
            dclk_active <= '0';
            dclk_gate   <= '0';
            dclk_out_r  <= '0';
        elsif (rising_edge(clk)) then
            -- Gating logic: ensures complete DCLK pulses
            -- Start gating only when dclk_int is low (about to start fresh cycle)
            -- Stop gating only when dclk_int is low (completed current cycle)
            if (dclk_active = '1' and dclk_gate = '0' and dclk_int = '0') then
                dclk_gate <= '1';  -- Start on low phase
            elsif (dclk_active = '0' and dclk_gate = '1' and dclk_int = '0') then
                dclk_gate <= '0';  -- Stop on low phase
            end if;

            -- Register DCLK output using clean gating
            if (dclk_gate = '1') then
                dclk_out_r <= dclk_int;
            else
                dclk_out_r <= '0';
            end if;

            if (dclk_rise_en = '1') then
                case odr_tracker is
                    when 0 to ODR_HIGH_TIME - 1 =>
                        odr_int     <= '1';
                        dclk_active <= '0';

                    when ODR_HIGH_TIME to ODR_HIGH_TIME + ODR_WAIT_FIRST - 1 =>
                        odr_int     <= '0';
                        dclk_active <= '0';

                    when ODR_HIGH_TIME + ODR_WAIT_FIRST to ODR_HIGH_TIME + ODR_WAIT_FIRST + ODR_LOW_TIME - 1 =>
                        odr_int     <= '0';
                        dclk_active <= '1';

                    when ODR_HIGH_TIME + ODR_WAIT_FIRST + ODR_LOW_TIME to ODR_TOTAL_CLKS - 1 =>
                        odr_int     <= '0';
                        dclk_active <= '0';

                    when others =>
                        odr_int     <= '0';
                        dclk_active <= '0';
                end case;

                if (odr_tracker < ODR_TOTAL_CLKS - 1) then
                    odr_tracker <= odr_tracker + 1;
                else
                    odr_tracker <= 0;
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Delay process for sampling timing margin
    -- ADI reference design insight: Sample on DCLK falling edge for better margin
    -- AD4134 slave mode timing:
    --   t6 = 8.2 ns max (DCLK rise to data valid)
    --   t5 = 0 ns (data invalid at next DCLK rise)
    -- Falling edge sampling: Data valid for (DCLK_high_time - t6) before sample
    -- At 80 MHz with SLOW_CLK_MAX=1: DCLK high = 25 ns, margin = 25 - 8.2 = 16.8 ns
    ---------------------------------------------------------------------------
    delay_p : process(clk, rst_n)
    begin
        if (rst_n = '0') then
            dclk_fall_d1 <= '0';
            dclk_fall_d2 <= '0';
            dclk_gate_d1 <= '0';
            dclk_gate_d2 <= '0';
        elsif (rising_edge(clk)) then
            -- Use falling edge for sampling (more margin than rising edge delay)
            dclk_fall_d1 <= dclk_fall_en;
            dclk_fall_d2 <= dclk_fall_d1;  -- 1-cycle delay for IOB timing
            dclk_gate_d1 <= dclk_gate;
            dclk_gate_d2 <= dclk_gate_d1;  -- Aligned with sampling
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Data read process
    -- Samples on DCLK falling edge (inspired by ADI reference design)
    -- Timing advantage:
    --   - DCLK rises at T=0
    --   - Data valid at T=8.2 ns (t6)
    --   - DCLK falls at T=12.5 ns (SLOW_CLK_MAX=1) or T=25 ns (SLOW_CLK_MAX=2)
    --   - Sample 1 cycle after fall = plenty of margin
    -- This is safer than sampling near the next rising edge
    ---------------------------------------------------------------------------
    read_p : process(clk, rst_n)
    begin
        if (rst_n = '0') then
            bit_count     <= DATA_WIDTH;
            shift_reg0    <= (others => '0');
            shift_reg1    <= (others => '0');
            shift_reg2    <= (others => '0');
            shift_reg3    <= (others => '0');
            data_out0     <= (others => '0');
            data_out1     <= (others => '0');
            data_out2     <= (others => '0');
            data_out3     <= (others => '0');
            data_rdy      <= '0';
            data_rdy_flag <= '0';
        elsif (rising_edge(clk)) then
            data_rdy <= '0';

            -- Sample on delayed falling edge for maximum timing margin
            if (dclk_fall_d2 = '1') then
                if (dclk_gate_d2 = '1') then
                    if (bit_count > 0) then
                        -- Sample data_in directly (no intermediate register)
                        shift_reg0(bit_count - 1) <= data_in0;
                        shift_reg1(bit_count - 1) <= data_in1;
                        shift_reg2(bit_count - 1) <= data_in2;
                        shift_reg3(bit_count - 1) <= data_in3;
                        bit_count <= bit_count - 1;
                    end if;
                    data_rdy_flag <= '0';
                else
                    if (bit_count = 0 and data_rdy_flag = '0') then
                        data_out0     <= shift_reg0;
                        data_out1     <= shift_reg1;
                        data_out2     <= shift_reg2;
                        data_out3     <= shift_reg3;
                        data_rdy_flag <= '1';
                        bit_count     <= DATA_WIDTH;
                    elsif (data_rdy_flag = '1') then
                        data_rdy      <= '1';
                        data_rdy_flag <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

end rtl;
