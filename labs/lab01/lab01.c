#include "pico/stdlib.h"

/**
 * @brief Lab01
 *        Simple program to initialise the built-in LED on
 *        the Raspberry Pi Pico and then flash it forever. 
 * 
 * @return int  Application return code (zero for success).
 */

//state variable to track state of the LED
bool g_state = false; 

/**
 * @brief toggles the state of the specified LED and waits for specified time
 * 
 * @param led_pin   selects which LED pin to toggle
 * @param led_delay specifid time to wait after toggling
 */
void toggle_led(uint led_pin, uint led_delay){

        // Toggle the LED then sleep for delay period
        gpio_put(led_pin, !g_state);
        sleep_ms(led_delay);
        // Update the state of the LED
        g_state = !g_state;
}
int main() {

    // Specify the PIN number and sleep delay
    const uint LED_PIN   =  25;
    const uint LED_DELAY = 500;

    // Setup the LED pin as an output.
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    while (true){
        // toggle the state of the LED
        toggle_led(LED_PIN, LED_DELAY);
    }

    // Should never get here due to infinite while-loop.
    return 0;

}

