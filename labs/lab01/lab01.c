#include "pico/stdlib.h"

/**
 * @brief EXAMPLE - BLINK_C
 *        Simple example to initialise the built-in LED on
 *        the Raspberry Pi Pico and then flash it forever. 
 * 
 * @return int  Application return code (zero for success).
 */


//Funcion to continuously blink an LED at specified pin and delay
void blink_led(uint led_pin, uint led_delay){
    while (true) {

        // Toggle the LED on and then sleep for delay period
        gpio_put(led_pin, 1);
        sleep_ms(led_delay);

        // Toggle the LED off and then sleep for delay period
        gpio_put(led_pin, 0);
        sleep_ms(led_delay);

    }
}
int main() {

    // Specify the PIN number and sleep delay
    const uint LED_PIN   =  25;
    const uint LED_DELAY = 500;

    // Setup the LED pin as an output.
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    // blink the led at LED_PIN continuously at delay LED_DELAY
     blink_led(LED_PIN, LED_DELAY);
    

    // Should never get here due to infinite while-loop.
    return 0;

}

