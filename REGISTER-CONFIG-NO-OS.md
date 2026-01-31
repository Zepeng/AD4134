# Analog Devices Register Configuration 

| REG # | REG NAME                    | VAL   | Verified | Notes                                                   |
|-------|-----------------------------|-------|----------|---------------------------------------------------------|
| 00    | INTERFACE_CONFIG_A          | 0x18  | [X]      | SOFT_RESET                                              |
| 01    | INTERFACE_CONFIG_B          | 0x80  | []       |                                                         |
| 02    | DEVICE_CONFIG               | 0xc1  | [X]      |                                                         |
| 03    | CHIP_TYPE                   | 0x07  | [O]      | READ-ONLY                                               |
| 04    | PRODUCT_ID_LSB              | 0xd3  | [O]      | READ-ONLY                                               |
| 05    | PRODUCT_ID_MSB              | 0xc2  | [O]      | READ-ONLY                                               |
| 06    | CHIP_GRADE                  | 0x00  | [O]      | READ-ONLY                                               |
| 07    | SILICON_REV                 | 0x02  | [O]      | READ-ONLY                                               |
| 0a    | SCRATCH_PAD                 | 0x00  | []       |                                                         |
| 0b    | SPI_REVISION                | 0x02  | [O]      | READ-ONLY                                               |
| 0c    | VENDOR_ID_LSB               | 0x56  | [O]      | READ-ONLY                                               |
| 0d    | VENDOR_ID_MSB               | 0x04  | [O]      | READ-ONLY                                               |
| 0e    | STREAM_MODE                 | 0x00  | []       |                                                         |
| 0f    | TRANSFER_REGISTER           | 0x00  | [X]      | Master_SLAVE_TX_BIT is set to 1 in HDL                 |
| 10    | DEVICE_CONFIG_1             | 0x01  | [X]      | Changed REG_GAIN_CORR_EN to 0                          |
| 11    | DATA_PACKET_CONFIG          | 0x20  | [X]      |                                                         |
| 12    | DIGITAL_INTERFACE_CONFIG    | 0x02  | [X]      |                                                         |
| 13    | POWER_DOWN_CONTROL          | 0x00  | [X]      |                                                         |
| 14    | RESERVED                    | 0x00  | []       |                                                         |
| 15    | DEVICE_STATUS               | 0x05  | [O]      | READ-ONLY                                               |
| 16    | ODR_VAL_INT_LSB             | 0x40  | []       |                                                         |
| 17    | ODR_VAL_INT_MID             | 0x00  | []       |                                                         |
| 18    | ODR_VAL_INT_MSB             | 0x00  | []       |                                                         |
| 19    | ODR_VAL_FLT_LSB             | 0x72  | []       |                                                         |
| 1a    | ODR_VAL_FLT_MID0            | 0xb7  | []       |                                                         |
| 1b    | ODR_VAL_FLT_MID1            | 0xce  | []       |                                                         |
| 1c    | ODR_VAL_FLT_MSB             | 0x2b  | []       |                                                         |
| 1d    | CHANNEL_ODR_SELECT          | 0x00  | []       |                                                         |
| 1e    | CHAN_DIG_FILTER_SEL         | 0xaa  | [X]      |                                                         |
| 1f    | FIR_BW_SEL                  | 0x00  | []       |                                                         |
| 20    | GPIO_DIR_CTRL               | 0x00  | [X]      |                                                         |
| 21    | GPIO_DATA                   | 0xff  | []       |                                                         |
| 22    | ERROR_PIN_SRC_CONTROL       | 0x00  | []       |                                                         |
| 23    | ERROR_PIN_CONTROL           | 0x00  | []       |                                                         |
| 24    | VCMBUF_CTRL                 | 0x00  | []       |                                                         |
| 25    | DIAGNOSTIC_CONTROL          | 0x00  | []       |                                                         |
| 26    | MPC_CONFIG                  | 0x00  | []       |                                                         |
| 27    | CH0_GAIN_LSB                | 0x00  | []       |                                                         |
| 28    | CH0_GAIN_MID                | 0x00  | []       |                                                         |
| 29    | CH0_GAIN_MSB                | 0x00  | []       |                                                         |
| 2a    | CH0_OFFSET_LSB              | 0x00  | []       |                                                         |
| 2b    | CH0_OFFSET_MID              | 0x00  | []       |                                                         |
| 2c    | CH0_OFFSET_MSB              | 0x00  | []       |                                                         |
| 2d    | CH1_GAIN_LSB                | 0x00  | []       |                                                         |
| 2e    | CH1_GAIN_MID                | 0x00  | []       |                                                         |
| 2f    | CH1_GAIN_MSB                | 0x00  | []       |                                                         |
| 30    | CH1_OFFSET_LSB              | 0x00  | []       |                                                         |
| 31    | CH1_OFFSET_MID              | 0x00  | []       |                                                         |
| 32    | CH1_OFFSET_MSB              | 0x00  | []       |                                                         |
| 33    | CH2_GAIN_LSB                | 0x00  | []       |                                                         |
| 34    | CH2_GAIN_MID                | 0x00  | []       |                                                         |
| 35    | CH2_GAIN_MSB                | 0x00  | []       |                                                         |
| 36    | CH2_OFFSET_LSB              | 0x00  | []       |                                                         |
| 37    | CH2_OFFSET_MID              | 0x00  | []       |                                                         |
| 38    | CH2_OFFSET_MSB              | 0x00  | []       |                                                         |
| 39    | CH3_GAIN_LSB                | 0x00  | []       |                                                         |
| 3a    | CH3_GAIN_MID                | 0x00  | []       |                                                         |
| 3b    | CH3_GAIN_MSB                | 0x00  | []       |                                                         |
| 3c    | CH3_OFFSET_LSB              | 0x00  | []       |                                                         |
| 3d    | CH3_OFFSET_MID              | 0x00  | []       |                                                         |
| 3e    | CH3_OFFSET_MSB              | 0x00  | []       |                                                         |
| 3f    | MCLK_COUNTER                | 0x00  | [O]      | READ-ONLY                                               |
| 40    | DIG_FILTER_OFUF             | 0x00  | [O]      | READ-ONLY                                               |
| 41    | DIG_FILTER_SETTLED          | 0x0f  | [O]      | READ-ONLY                                               |
| 42    | INTERNAL_ERROR              | 0x22  | [O]      | READ-ONLY                                               |
| 47    | SPI_Error                   | 0x00  | [O]      | READ-ONLY                                               |
| 48    | AIN_OR_ERROR                | 0x    | [O]      | READ-ONLY                                               |
