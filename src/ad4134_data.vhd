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
    -- AD4134 slave mode: t6 = 8.2 ns max (DCLK rise to data valid)
    -- At 80 MHz, SLOW_CLK_MAX=1: DCLK period = 50 ns, high time = 25 ns
    -- Sample 1 cycle after falling edge (T=37.5ns) gives 12.5 ns margin before next rise
    --
    -- IMPORTANT: Use dclk_active directly (not dclk_gate) because:
    --   - dclk_active goes HIGH on dclk_rise_en (at DCLK rising edge)
    --   - dclk_fall_en fires on DCLK falling edge (half period later)
    --   - So dclk_active is already stable when we check dclk_fall_d1
    --   - dclk_gate has 1-cycle alignment issue (set after dclk_int goes low)
    signal dclk_fall_d1    : std_logic := '0';  -- 1-cycle delayed falling edge for sampling
    signal dclk_active_d1  : std_logic := '0';  -- For detecting falling edge of dclk_active

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

                    -- Note: dclk_active must be set 1 cycle EARLY because:
                    --   - Case evaluates odr_tracker at cycle N
                    --   - dclk_active is assigned, takes effect at cycle N+1
                    --   - First dclk_fall_d1 occurs at cycle N+3 (1.5 DCLK periods after rise)
                    --   - At cycle N+3, we check dclk_active which was set at N
                    -- So set dclk_active=1 when odr_tracker = ODR_WAIT_FIRST-1 (one cycle early)
                    when ODR_HIGH_TIME to ODR_HIGH_TIME + ODR_WAIT_FIRST - 2 =>
                        odr_int     <= '0';
                        dclk_active <= '0';

                    when ODR_HIGH_TIME + ODR_WAIT_FIRST - 1 to ODR_HIGH_TIME + ODR_WAIT_FIRST + ODR_LOW_TIME - 1 =>
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
    -- AD4134 slave mode timing:
    --   t6 = 8.2 ns max (DCLK rise to data valid)
    --   t5 = 0 ns (data invalid at next DCLK rise)
    -- At 80 MHz with SLOW_CLK_MAX=1:
    --   DCLK period = 50 ns (20 MHz), high time = 25 ns
    --   DCLK rises at T=0, dclk_active set on this edge
    --   Data valid at T=8.2 ns
    --   DCLK falls at T=25 ns, dclk_fall_en fires
    --   Sample at T=37.5 ns (dclk_fall_d1), dclk_active still =1
    --   Margin before next DCLK rise = 50 - 37.5 = 12.5 ns
    ---------------------------------------------------------------------------
    delay_p : process(clk, rst_n)
    begin
        if (rst_n = '0') then
            dclk_fall_d1   <= '0';
            dclk_active_d1 <= '0';
        elsif (rising_edge(clk)) then
            dclk_fall_d1   <= dclk_fall_en;
            dclk_active_d1 <= dclk_active;  -- For edge detection
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Data read process
    -- Samples 1 clock cycle after DCLK falling edge
    -- Uses dclk_active directly (not dclk_gate) to avoid alignment issues
    -- At 80 MHz with SLOW_CLK_MAX=1: sample at T=37.5 ns, 12.5 ns before next rise
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

            -- Sample on falling edge when dclk_active is high
            -- dclk_active is set on dclk_rise_en, so it's stable by dclk_fall_d1
            if (dclk_fall_d1 = '1' and dclk_active = '1' and bit_count > 0) then
                -- Sample data_in directly (no intermediate register)
                shift_reg0(bit_count - 1) <= data_in0;
                shift_reg1(bit_count - 1) <= data_in1;
                shift_reg2(bit_count - 1) <= data_in2;
                shift_reg3(bit_count - 1) <= data_in3;
                bit_count <= bit_count - 1;
            end if;

            -- Transfer data on dclk_active falling edge (end of data phase)
            if (dclk_active_d1 = '1' and dclk_active = '0') then
                if (bit_count = 0) then
                    data_out0     <= shift_reg0;
                    data_out1     <= shift_reg1;
                    data_out2     <= shift_reg2;
                    data_out3     <= shift_reg3;
                    data_rdy_flag <= '1';
                end if;
                bit_count <= DATA_WIDTH;  -- Reset for next ODR cycle
            end if;

            -- Generate data_rdy pulse one cycle after transfer
            if (data_rdy_flag = '1') then
                data_rdy      <= '1';
                data_rdy_flag <= '0';
            end if;
        end if;
    end process;

end rtl;
