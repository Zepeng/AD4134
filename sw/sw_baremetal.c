#include "xil_io.h"
#include "xil_printf.h"
#include "xil_cache.h"

#include <stdint.h>
#include "xparameters.h"

#define LEDS_BASE      XPAR_LEDS_AXI_GPIO_0_BASEADDR
#define BRAM_CTRL_BASE XPAR_ADC_BRAM_ADC_BRAM_ENABLE_BASEADDR
#define BRAM_BASE      XPAR_ADC_BRAM_ADC_BRAM_READ_S_AXI_BASEADDR

/* Simple delay loop - adjust multiplier for your clock speed */
static void delay_ms(uint32_t ms)
{
  volatile uint32_t i, j;
  for (i = 0; i < ms; i++) {
    for (j = 0; j < 50000; j++) {
      /* Empty loop */
    }
  }
}

//#define LEDS_BASE      0x41200000U
//#define BRAM_CTRL_BASE 0x41210000U
//#define BRAM_BASE      0x40000000U

static void leds_write(uint32_t value)
{
  Xil_Out32(LEDS_BASE, value);
}

static uint32_t leds_read(void)
{
  return Xil_In32(LEDS_BASE);
}

static void bram_enable(int enable)
{
  Xil_Out32(BRAM_CTRL_BASE, enable ? 0xFFFFFFFFU : 0x00000000U);
}

static uint32_t bram_read_word(uint32_t index)
{
  return Xil_In32(BRAM_BASE + (index * 4U));
}

static void bram_read_words(uint32_t start, uint32_t count)
{
  uint32_t i;

  for (i = 0; i < count; i++) {
    xil_printf("BRAM[%lu] : 0x%08lx\r\n",
               (unsigned long)(start + i),
               (unsigned long)bram_read_word(start + i));
  }
}


int main(void)
{
  uint32_t i;
  uint32_t led_val;

  Xil_DCacheDisable();

  xil_printf("\r\n");
  xil_printf("========================================\r\n");
  xil_printf("AD4134 Automatic Test\r\n");
  xil_printf("========================================\r\n\r\n");

  /* ===== Test 1: LED Test ===== */
  xil_printf("--- Test 1: LED Test ---\r\n");

  xil_printf("Reading LED register: 0x%08lx\r\n", (unsigned long)leds_read());

  /* Walk through LED patterns */
  for (i = 0; i < 8; i++) {
    led_val = (1U << i);
    leds_write(led_val);
    xil_printf("LEDs <= 0x%02lx\r\n", (unsigned long)led_val);
    delay_ms(200);
  }

  /* All LEDs on */
  leds_write(0x7F);
  xil_printf("LEDs <= 0x7F (all on)\r\n");
  delay_ms(500);

  /* All LEDs off */
  leds_write(0x00);
  xil_printf("LEDs <= 0x00 (all off)\r\n");
  delay_ms(500);

  xil_printf("LED test complete.\r\n\r\n");

  /* ===== Test 2: BRAM Read (before capture) ===== */
  xil_printf("--- Test 2: BRAM Read (before capture) ---\r\n");
  xil_printf("Reading first 8 BRAM words:\r\n");
  bram_read_words(0, 8);
  xil_printf("\r\n");

  /* ===== Test 3: Enable BRAM Capture ===== */
  xil_printf("--- Test 3: Enable BRAM Capture ---\r\n");
  bram_enable(1);
  xil_printf("BRAM capture ENABLED\r\n");

  /* Wait for data to be captured */
  xil_printf("Waiting 1 second for ADC data...\r\n");
  delay_ms(1000);

  /* Disable capture */
  bram_enable(0);
  xil_printf("BRAM capture DISABLED\r\n\r\n");

  /* ===== Test 4: BRAM Read (after capture) ===== */
  xil_printf("--- Test 4: BRAM Read (after capture) ---\r\n");
  xil_printf("Reading first 24 BRAM words:\r\n");
  bram_read_words(0, 24);
  xil_printf("\r\n");

  /* ===== Test 5: Read more BRAM data ===== */
  xil_printf("--- Test 5: BRAM Read (offset 100) ---\r\n");
  xil_printf("Reading 12 words starting at offset 100:\r\n");
  bram_read_words(100, 12);
  xil_printf("\r\n");

  /* ===== Summary ===== */
  xil_printf("========================================\r\n");
  xil_printf("Test Complete!\r\n");
  xil_printf("========================================\r\n");
  xil_printf("\r\n");
  xil_printf("Check results:\r\n");
  xil_printf("- If LEDs cycled: GPIO works\r\n");
  xil_printf("- If BRAM has non-zero data: ADC capture works\r\n");
  xil_printf("- If BRAM is all zeros: Check ADC connections\r\n");
  xil_printf("\r\n");

  /* Blink LED to show test is done */
  xil_printf("Blinking LED 0 to indicate test complete...\r\n");
  while (1) {
    leds_write(0x01);
    delay_ms(500);
    leds_write(0x00);
    delay_ms(500);
  }

  return 0;
}
