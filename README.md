# AD4134

AD4134 Driver Development

## Usage

## Scripts

### tq15eg_project.tcl:

### tq15eg_preset.tcl

## Pins for Each ADC

All pins beside CS can be shared for all ADCs.

**SPI Configuration**

1. SPI_CLK/SCLK x 1
2. MISO/SDO x 1
3. MOSI/SDI x 1
4. CS_N x 1

**Data**

1. DOUT x 4
2. ODR x 1
3. DLCK x 1

## Source Files

### AD4134_control.vhd:

DATA_PACKET_CONFIG (0x11): Set to 00111111
DATA_PACKET_CONFIG[5:4] (Frame) = 24-bit + 6-bit CRC

### AD4134_data.vhd:

**Generics:**
DATA_WIDTH:
CLK_DIV: For effective DLCK and ODR

## Startup Sequence

ADRESET -> RESETWAIT -> DEVICE_CONFIG_0 -> DEVICE_CONFIG_1 ->
DATAPACKETCONFIG -> DIGITALINTERFACECONFIG -> POWERCONTROL ->
ODRCONFIG -> ODRCHANNEL -> FILTERCONFIG -> GPIOCONFIG ->
TRANSFERREGISTER -> [INSERT_ADDITONAL_CONFIGS] -> IDLE
