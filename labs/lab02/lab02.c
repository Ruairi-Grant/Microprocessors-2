//#define WOKWI             // Uncomment if running on Wokwi RP2040 emulator.

#include <stdio.h>
#include <stdlib.h>
#include "pico/float.h"
#include "pico/double.h"
#include "pico/stdlib.h"    // Comment if running in Wowki simulator

/**
 * @brief calculates the wallis product to find pi using floating point numbers
 * 
 * @param iters The number of iterations used in calculation
 * @return float: the value for pi as a float
 */
float wallis_single_precision(int iters){
    float subtotal =1.0;
    for (int i = 1; i < iters; i++){
        subtotal = (float)subtotal * ((2.0*i)/((float)(2*i - 1))) * ((2.0*i)/((float)(2*i + 1)));
    }
    return 2.0*subtotal;
}
 /**
  * @brief calculates the wallis product to find pi using floating point numbers
  * 
  * @param iters The number of iterations used in calculation
  * @return double : the value for pi as a float
  */
double wallis_double_precision(int iters){
    double subtotal = 1.0;
    for (int i = 1; i < iters; i++){
        subtotal = (double)subtotal * ((2.0*i)/((double)(2*i - 1))) * ((2.0*i)/((double)(2*i + 1)));
    }
    return 2.0*subtotal;
}

/**
 * @brief   Prints out the value for pi calculated 
 *          using wallis product with float and double precision
 * 
 * @return int  Application return code (zero for success).
 */
int main() {

#ifndef WOKWI
    // Initialise the IO as we will be using the UART
    // Only required for hardware and not needed for Wokwi
    stdio_init_all();
#endif
    //declare constants for pi and number of iterations
    const double pi = 3.14159265359;
    const int iterations = 100000;

    //calculate the value for pi using floats and doubles
    float single_num = wallis_single_precision(iterations);
    double double_num = wallis_double_precision(iterations);

    // Print the value for each approximation and their error from the pi constant to the console
    printf("pi is: %.11f\n", pi);
    printf("Single Precision approximation is:\n" );
    printf("%f\n", single_num);
    printf("Single precision approximation error is: %f\n", (single_num - pi)/pi);
    printf("Double Precision approximation is:\n" );
    printf("%f\n", double_num);
    printf("Double precision approximation error is: %f\n", (double_num - pi)/pi);

    // Returning zero indicates everything went okay.
    return 0;
}