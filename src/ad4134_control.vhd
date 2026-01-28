library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library ad4134_lib;
use ad4134_lib.all;

entity ad4134_control is
    port(
        clk        : in  std_logic;
        rstn       : in  std_logic;
        --start : in std_logic;
        write      : out std_logic;
        read       : out std_logic;
        datain     : out std_logic_vector(7 downto 0);
        dataout    : in  std_logic_vector(7 downto 0);
        spiaddr    : out std_logic_vector(7 downto 0);
        ch_en      : in  std_logic_vector(3 downto 0);
        spi_clk_en : out std_logic;
        spidone    : in  std_logic;
        debug      : out std_logic_vector(3 downto 0)
    );
end entity ad4134_control;

architecture rtl of ad4134_control is

    type setup_states is (
        IDLE,
        --CHEN,                           --Enable ADC channels
        --ADID,   
        RESETWAIT,                      --Read device ID to confirm functioning
        ADRESET,                        --Reset ADC 
        --CLKCONFIG,                      --Configure specific clock interface and output 
        ODRCONFIG,
        ODRCHANNEL,
        --INTERFACECONFIGA,
        --INTERFACECONFIGB,
        --SCRATCHPAD,
        DEVICECONFIG_0,
        DEVICECONFIG_1,
        DATAPACKETCONFIG,
        DIGITALINTERFACECONFIG,
        POWERCONTROL,
        FILTERCONFIG,
        GPIOCONFIG,
        TRANSFERREGISTER
        --GAINCONFIG_CH0,
        --GAINCONFIG_CH1,
        --GAINCONFIG_CH2,
        --GAINCONFIG_CH3
    );
    signal setup_state : setup_states;

    type operational_states is (
        POWERCONTROL_OP,
        GPIODATA_OP,
        FILTERCONFIG_OP,
        GAINCONFIG_CH0_OP,
        GAINCONFIG_CH1_OP,
        GAINCONFIG_CH2_OP,
        GAINCONFIG_CH3_OP
    );

    signal operational_state : operational_states;

    --SPI Procedure signals

    signal INTERFACE_CONFIG_A       : std_logic_vector(7 downto 0) := X"00";
    signal INTERFACE_CONFIG_B       : std_logic_vector(7 downto 0) := X"01";
    signal DEVICE_CONFIG            : std_logic_vector(7 downto 0) := X"02";
    signal CHIP_TYPE                : std_logic_vector(7 downto 0) := X"03";
    signal PRODUCT_ID_LSB           : std_logic_vector(7 downto 0) := X"04";
    signal PRODUCT_ID_MSB           : std_logic_vector(7 downto 0) := X"05";
    signal CHIP_GRADE               : std_logic_vector(7 downto 0) := X"06";
    signal SILICON_REV              : std_logic_vector(7 downto 0) := X"07";
    signal SCRATCH_PAD              : std_logic_vector(7 downto 0) := X"0A";
    signal SPI_REVISION             : std_logic_vector(7 downto 0) := X"0B";
    signal VENDOR_ID_LSB            : std_logic_vector(7 downto 0) := X"0C";
    signal VENDOR_ID_MSB            : std_logic_vector(7 downto 0) := X"0D";
    signal STREAM_MODE              : std_logic_vector(7 downto 0) := X"0E";
    signal TRANSFER_REGISTER        : std_logic_vector(7 downto 0) := X"0F";
    signal DEVICE_CONFIG_1          : std_logic_vector(7 downto 0) := X"10";
    signal DATA_PACKET_CONFIG       : std_logic_vector(7 downto 0) := X"11";
    signal DIGITAL_INTERFACE_CONFIG : std_logic_vector(7 downto 0) := X"12";
    signal POWER_DOWN_CONTROL       : std_logic_vector(7 downto 0) := X"13";
    signal RESERVED                 : std_logic_vector(7 downto 0) := X"14";
    signal DEVICE_STATUS            : std_logic_vector(7 downto 0) := X"15";
    signal ODR_VAL_INT_LSB          : std_logic_vector(7 downto 0) := X"16";
    signal ODR_VAL_INT_MID          : std_logic_vector(7 downto 0) := X"17";
    signal ODR_VAL_INT_MSB          : std_logic_vector(7 downto 0) := X"18";
    signal ODR_VAL_FLT_LSB          : std_logic_vector(7 downto 0) := X"19";
    signal ODR_VAL_FLT_MID0         : std_logic_vector(7 downto 0) := X"1A";
    signal ODR_VAL_FLT_MID1         : std_logic_vector(7 downto 0) := X"1B";
    signal ODR_VAL_FLT_MSB          : std_logic_vector(7 downto 0) := X"1C";
    signal CHANNEL_ODR_SELECT       : std_logic_vector(7 downto 0) := X"1D";
    signal CHAN_DIG_FILTER_SEL      : std_logic_vector(7 downto 0) := X"1E";
    signal FIR_BW_SEL               : std_logic_vector(7 downto 0) := X"1F";
    signal GPIO_DIR_CTRL            : std_logic_vector(7 downto 0) := X"20";
    signal GPIO_DATA                : std_logic_vector(7 downto 0) := X"21";
    signal ERROR_PIN_SRC_CONTROL    : std_logic_vector(7 downto 0) := X"22";
    signal ERROR_PIN_CONTROL        : std_logic_vector(7 downto 0) := X"23";
    signal VCMBUF_CTRL              : std_logic_vector(7 downto 0) := X"24";
    signal DIAGNOSTIC_CONTROL       : std_logic_vector(7 downto 0) := X"25";
    signal MPC_CONFIG               : std_logic_vector(7 downto 0) := X"26";
    signal CH0_GAIN_LSB             : std_logic_vector(7 downto 0) := X"27";
    signal CH0_GAIN_MID             : std_logic_vector(7 downto 0) := X"28";
    signal CH0_GAIN_MSB             : std_logic_vector(7 downto 0) := X"29";
    signal CH0_OFFSET_LSB           : std_logic_vector(7 downto 0) := X"2A";
    signal CH0_OFFSET_MID           : std_logic_vector(7 downto 0) := X"2B";
    signal CH0_OFFSET_MSB           : std_logic_vector(7 downto 0) := X"2C";
    signal CH1_GAIN_LSB             : std_logic_vector(7 downto 0) := X"2D";
    signal CH1_GAIN_MID             : std_logic_vector(7 downto 0) := X"2E";
    signal CH1_GAIN_MSB             : std_logic_vector(7 downto 0) := X"2F";
    signal CH1_OFFSET_LSB           : std_logic_vector(7 downto 0) := X"30";
    signal CH1_OFFSET_MID           : std_logic_vector(7 downto 0) := X"31";
    signal CH1_OFFSET_MSB           : std_logic_vector(7 downto 0) := X"32";
    signal CH2_GAIN_LSB             : std_logic_vector(7 downto 0) := X"33";
    signal CH2_GAIN_MID             : std_logic_vector(7 downto 0) := X"34";
    signal CH2_GAIN_MSB             : std_logic_vector(7 downto 0) := X"35";
    signal CH2_OFFSET_LSB           : std_logic_vector(7 downto 0) := X"36";
    signal CH2_OFFSET_MID           : std_logic_vector(7 downto 0) := X"37";
    signal CH2_OFFSET_MSB           : std_logic_vector(7 downto 0) := X"38";
    signal CH3_GAIN_LSB             : std_logic_vector(7 downto 0) := X"39";
    signal CH3_GAIN_MID             : std_logic_vector(7 downto 0) := X"3A";
    signal CH3_GAIN_MSB             : std_logic_vector(7 downto 0) := X"3B";
    signal CH3_OFFSET_LSB           : std_logic_vector(7 downto 0) := X"3C";
    signal CH3_OFFSET_MID           : std_logic_vector(7 downto 0) := X"3D";
    signal CH3_OFFSET_MSB           : std_logic_vector(7 downto 0) := X"3E";
    signal MCLK_COUNTER             : std_logic_vector(7 downto 0) := X"3F";
    signal DIG_FILTER_OFUF          : std_logic_vector(7 downto 0) := X"40";
    signal DIG_FILTER_SETTLED       : std_logic_vector(7 downto 0) := X"41";
    signal INTERNAL_ERROR           : std_logic_vector(7 downto 0) := X"42";
    signal SPI_Error                : std_logic_vector(7 downto 0) := X"47";
    signal AIN_OR_ERROR             : std_logic_vector(7 downto 0) := X"48";

    signal read_i  : std_logic;
    signal write_i : std_logic;

    signal setup_done : std_logic;

    signal datain_i     : std_logic_vector(7 downto 0);
    signal spiaddr_i    : std_logic_vector(7 downto 0);
    signal reset_count  : integer range 0 to 5000;
    signal spi_clk_en_i : std_logic;
    signal spidone_pre  : std_logic;
    signal spidone_post : std_logic;

    signal ODR_COUNT   : integer range 0 to 7;
    signal ODR_VAL_INT : std_logic_vector(23 downto 0);
    signal ODR_VAL_FLT : std_logic_vector(31 downto 0);

begin

    write      <= write_i;
    read       <= read_i;
    spiaddr    <= spiaddr_i;
    datain     <= datain_i;
    spi_clk_en <= spi_clk_en_i;

    input_sync : process(clk, rstn) is
    begin
        if rstn = '0' then
            spidone_pre  <= '0';
            spidone_post <= '0';
        elsif rising_edge(clk) then
            spidone_pre  <= spidone;
            spidone_post <= spidone_pre;
        else
            null;
        end if;

    end process input_sync;

    setup_adc : process(clk, rstn) is
    begin
        if rstn = '0' then
        
            debug <= b"0000";
        
            --Default addresses

            INTERFACE_CONFIG_A       <= X"00";
            INTERFACE_CONFIG_B       <= X"01";
            DEVICE_CONFIG            <= X"02";
            CHIP_TYPE                <= X"03";
            PRODUCT_ID_LSB           <= X"04";
            PRODUCT_ID_MSB           <= X"05";
            CHIP_GRADE               <= X"06";
            SILICON_REV              <= X"07";
            SCRATCH_PAD              <= X"0A";
            SPI_REVISION             <= X"0B";
            VENDOR_ID_LSB            <= X"0C";
            VENDOR_ID_MSB            <= X"0D";
            STREAM_MODE              <= X"0E";
            TRANSFER_REGISTER        <= X"0F";
            DEVICE_CONFIG_1          <= X"10";
            DATA_PACKET_CONFIG       <= X"11";
            DIGITAL_INTERFACE_CONFIG <= X"12";
            POWER_DOWN_CONTROL       <= X"13";
            RESERVED                 <= X"14";
            DEVICE_STATUS            <= X"15";
            ODR_VAL_INT_LSB          <= X"16";
            ODR_VAL_INT_MID          <= X"17";
            ODR_VAL_INT_MSB          <= X"18";
            ODR_VAL_FLT_LSB          <= X"19";
            ODR_VAL_FLT_MID0         <= X"1A";
            ODR_VAL_FLT_MID1         <= X"1B";
            ODR_VAL_FLT_MSB          <= X"1C";
            CHANNEL_ODR_SELECT       <= X"1D";
            CHAN_DIG_FILTER_SEL      <= X"1E";
            FIR_BW_SEL               <= X"1F";
            GPIO_DIR_CTRL            <= X"20";
            GPIO_DATA                <= X"21";
            ERROR_PIN_SRC_CONTROL    <= X"22";
            ERROR_PIN_CONTROL        <= X"23";
            VCMBUF_CTRL              <= X"24";
            DIAGNOSTIC_CONTROL       <= X"25";
            MPC_CONFIG               <= X"26";
            CH0_GAIN_LSB             <= X"27";
            CH0_GAIN_MID             <= X"28";
            CH0_GAIN_MSB             <= X"29";
            CH0_OFFSET_LSB           <= X"2A";
            CH0_OFFSET_MID           <= X"2B";
            CH0_OFFSET_MSB           <= X"2C";
            CH1_GAIN_LSB             <= X"2D";
            CH1_GAIN_MID             <= X"2E";
            CH1_GAIN_MSB             <= X"2F";
            CH1_OFFSET_LSB           <= X"30";
            CH1_OFFSET_MID           <= X"31";
            CH1_OFFSET_MSB           <= X"32";
            CH2_GAIN_LSB             <= X"33";
            CH2_GAIN_MID             <= X"34";
            CH2_GAIN_MSB             <= X"35";
            CH2_OFFSET_LSB           <= X"36";
            CH2_OFFSET_MID           <= X"37";
            CH2_OFFSET_MSB           <= X"38";
            CH3_GAIN_LSB             <= X"39";
            CH3_GAIN_MID             <= X"3A";
            CH3_GAIN_MSB             <= X"3B";
            CH3_OFFSET_LSB           <= X"3C";
            CH3_OFFSET_MID           <= X"3D";
            CH3_OFFSET_MSB           <= X"3E";
            MCLK_COUNTER             <= X"3F";
            DIG_FILTER_OFUF          <= X"40";
            DIG_FILTER_SETTLED       <= X"41";
            INTERNAL_ERROR           <= X"42";
            SPI_Error                <= X"47";
            AIN_OR_ERROR             <= X"48";

            --ODR Initial Values

            ODR_COUNT   <= 0;
            -- ODR_VAL_INT must match the desired external ODR rate!
            -- Formula: ODR_VAL_INT = MCLK / target_ODR (MCLK ≈ 19.2 MHz)
            -- OLD: x"023C34" = 146,484 → ~131 Hz (WAY too slow for 500+ kHz external ODR)
            -- For 500 kHz: 19.2M / 500k = 38 = 0x000026
            -- For 1 MHz:   19.2M / 1M   = 19 = 0x000013
            ODR_VAL_INT <= x"000026";  -- 38 decimal → ~505 kHz internal ODR
            ODR_VAL_FLT <= (others => '0');

            --End of addresses

            setup_state <= ADRESET;
            setup_done  <= '0';

            --SPI Procedure reset signals

            read_i      <= '0';
            write_i     <= '0';
            datain_i    <= (others => '0');
            spiaddr_i   <= (others => '0');
            reset_count <= 0;

        elsif rising_edge(clk) then

            case setup_state is

                when IDLE =>
                
                debug <= b"0001";

                    if setup_done = '0' then
                        setup_state <= ADRESET;
                    else
                        setup_state <= IDLE;
                    end if;

                when ODRCONFIG =>
                
                    debug <= b"1001";
                
                    write_i <= '1';
                    read_i  <= '0';

                    if ODR_COUNT >= 1 then
                        case ODR_COUNT is
                            when 1 =>
                                ODR_COUNT <= ODR_COUNT - 1;
                                spiaddr_i <= '0' & ODR_VAL_FLT_MSB(6 downto 0); --Write bit msb
                                datain_i  <= ODR_VAL_FLT(31 downto 24); --All channels enabled, LDO powered, Sleep mode disabled
                            when 2 =>
                                ODR_COUNT <= ODR_COUNT - 1;
                                spiaddr_i <= '0' & ODR_VAL_FLT_MID1(6 downto 0); --Write bit msb
                                datain_i  <= ODR_VAL_FLT(23 downto 16); --All channels enabled, LDO powered, Sleep mode disabled
                            when 3 =>
                                ODR_COUNT <= ODR_COUNT - 1;
                                spiaddr_i <= '0' & ODR_VAL_FLT_MID0(6 downto 0); --Write bit msb
                                datain_i  <= ODR_VAL_FLT(15 downto 8); --All channels enabled, LDO powered, Sleep mode disabled
                            when 4 =>
                                ODR_COUNT <= ODR_COUNT - 1;
                                spiaddr_i <= '0' & ODR_VAL_FLT_LSB(6 downto 0); --Write bit msb
                                datain_i  <= ODR_VAL_FLT(7 downto 0); --All channels enabled, LDO powered, Sleep mode disabled
                            when 5 =>
                                ODR_COUNT <= ODR_COUNT - 1;
                                spiaddr_i <= '0' & ODR_VAL_INT_MSB(6 downto 0); --Write bit msb
                                datain_i  <= ODR_VAL_INT(23 downto 16); --All channels enabled, LDO powered, Sleep mode disabled
                            when 6 =>
                                ODR_COUNT <= ODR_COUNT - 1;
                                spiaddr_i <= '0' & ODR_VAL_INT_MID(6 downto 0); --Write bit msb
                                datain_i  <= ODR_VAL_INT(15 downto 8); --All channels enabled, LDO powered, Sleep mode disabled
                            when 7 =>
                                ODR_COUNT <= ODR_COUNT - 1;
                                spiaddr_i <= '0' & ODR_VAL_INT_LSB(6 downto 0); --Write bit msb
                                datain_i  <= ODR_VAL_INT(7 downto 0); --All channels enabled, LDO powered, Sleep mode disabled
                            when others =>
                                null;
                        end case;
                    else
                        null;
                    end if;

                    if spidone_post = '1' and spidone_pre = '0' then
                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        ODR_COUNT    <= 7;
                        setup_state  <= ODRCHANNEL;
                    else
                        null;
                    end if;

                when ODRCHANNEL =>
                
                    debug <= b"1010";

                    spi_clk_en_i <= '1';
                    write_i      <= '1';
                    read_i       <= '0';

                    spiaddr_i <= '0' & CHANNEL_ODR_SELECT(6 downto 0); --Write bit msb
                    datain_i  <= "00000000"; --Configure ODR data rate

                    if spidone_post = '1' and spidone_pre = '0' then
                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        setup_state  <= FILTERCONFIG;
                    else
                        null;
                    end if;

                when DEVICECONFIG_0 =>
                
                    debug <= b"0100";

                    spi_clk_en_i <= '1';
                    write_i      <= '1';
                    read_i       <= '0';

                    spiaddr_i <= '0' & DEVICE_CONFIG(6 downto 0); --Write bit msb
                    datain_i  <= "11101001"; --Device is configured in high performance mode if LSB then low power mode

                    if spidone_post = '1' and spidone_pre = '0'  then
                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        setup_state  <= DEVICECONFIG_1;
                    else
                        null;
                    end if;
                when DEVICECONFIG_1 =>

                    debug <= b"0101";

                    spi_clk_en_i <= '1';
                    write_i      <= '1';
                    read_i       <= '0';

                    spiaddr_i <= '0' & DEVICE_CONFIG_1(6 downto 0); --Write bit msb
                    -- Bit 0: CLKOUT_EN, Bit 1: REF_GAIN_CORR_EN (matches ADI reference)
                    datain_i  <= "00000011";

                    if spidone_post = '1' and spidone_pre = '0'  then
                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        setup_state  <= DATAPACKETCONFIG;
                    else
                        null;
                    end if;

                when DATAPACKETCONFIG =>
                
                    debug <= b"0110";
                
                    spi_clk_en_i <= '1';
                    write_i      <= '1';
                    read_i       <= '0';

                    spiaddr_i <= '0' & DATA_PACKET_CONFIG(6 downto 0); --Write bit msb
                    -- fdclk = 375 kHz, register DCLK_FREQ_SEL[3:0] = 0b0111
                    -- for fdclk = 24 MHz, set DCLK_FREQ_SEL[3:0] = 0b0000, so datain_i <= "01000000"
                    datain_i  <= "00101111"; 

                    if spidone_post = '1' and spidone_pre = '0' then
                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        setup_state  <= DIGITALINTERFACECONFIG;
                    else
                        null;
                    end if;
                when DIGITALINTERFACECONFIG =>
                
                    debug <= b"0111";
                        
                    spi_clk_en_i <= '1';
                    write_i      <= '1';
                    read_i       <= '0';

                    spiaddr_i <= '0' & DIGITAL_INTERFACE_CONFIG(6 downto 0); --Write bit msb
                    datain_i  <= "00110010"; --Quad channel output 

                    if spidone_post = '1' and spidone_pre = '0' then
                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        setup_state  <= POWERCONTROL;
                    else
                        null;
                    end if;

                when POWERCONTROL =>

                    debug <= b"1000";

                    spi_clk_en_i <= '1';
                    write_i      <= '1';
                    read_i       <= '0';

                    spiaddr_i <= '0' & POWER_DOWN_CONTROL(6 downto 0); --Write bit msb
                    datain_i  <= "00000000"; --All channels enabled, LDO powered, Sleep mode disabled

                    if spidone_post = '1' and spidone_pre = '0' then
                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        ODR_COUNT    <= 7;
                        setup_state  <= ODRCONFIG;
                    else
                        null;
                    end if;
                when FILTERCONFIG =>
                
                    debug <= b"1011";
                
                    spi_clk_en_i <= '1';
                    write_i      <= '1';
                    read_i       <= '0';

                    spiaddr_i <= '0' & CHAN_DIG_FILTER_SEL(6 downto 0); --Write bit msb
                    -- Filter selection: 00=FIR (max 365kSPS), 01=Sinc6 (max 1460kSPS), 10=Sinc3, 11=Sinc3_50_60
                    -- For 500+ kHz ODR, must use Sinc6 (01 for each channel)
                    -- Format: CH3[7:6] | CH2[5:4] | CH1[3:2] | CH0[1:0]
                    datain_i  <= "01010101"; -- 0x55 = Sinc6 for all channels (supports up to 1460 kSPS)

                    if spidone_post = '1' and spidone_pre = '0' then
                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        setup_state  <= GPIOCONFIG;
                    else
                        null;
                    end if;
                when GPIOCONFIG =>
                
                    debug <= b"1100";
                
                    spi_clk_en_i <= '1';
                    write_i      <= '1';
                    read_i       <= '0';

                    spiaddr_i <= '0' & GPIO_DIR_CTRL(6 downto 0); --Write bit msb
                    datain_i  <= "00000000"; --Configure all GPIOs as inputs

                    if spidone_post = '1' and spidone_pre = '0' then
                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        setup_done   <= '1';
                        setup_state  <= TRANSFERREGISTER;
                    else
                        null;
                    end if;
                    
                when TRANSFERREGISTER =>
                
                    debug <= b"1101";
                    
                    spiaddr_i <= '0' & TRANSFER_REGISTER(6 downto 0); 
                    datain_i  <= "00000001"; 
                
                    spi_clk_en_i <= '1';
                    write_i      <= '1';
                    read_i       <= '0';
                
                    if spidone_post = '1' and spidone_pre = '0' then
                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        setup_done   <= '1';
                        setup_state  <= IDLE;
                    else
                        null;
                    end if;

                when ADRESET =>

                    debug <= b"0010";
                    
                    spi_clk_en_i <= '1';
                    write_i      <= '1';
                    read_i       <= '0';

                    spiaddr_i <= '0' & INTERFACE_CONFIG_A(6 downto 0); --Write bit msb
                    datain_i  <= "10011000"; --Data to be written msb 1 for soft reset

                    if spidone_post = '1' and spidone_pre = '0' then

                        write_i      <= '0';
                        read_i       <= '0';
                        spi_clk_en_i <= '0';
                        setup_state  <= RESETWAIT;

                    else
                        null;
                    end if;

                when RESETWAIT =>
                
                    debug <= b"0011";

                    if (reset_count = 2000) then
                        setup_state <= DEVICECONFIG_0;
                    else
                        reset_count <= reset_count + 1;
                    end if;

                when others =>
                    setup_state <= IDLE;

            end case;
        end if;
    end process setup_adc;

    operational_adc : process(clk, rstn) is
    begin
    end process operational_adc;
end architecture;
