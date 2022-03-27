#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "pico/stdlib.h"
#include "pico/float.h"     // Required for using single-precision variables.
#include "pico/double.h"    // Required for using double-precision variables.
#include "pico/multicore.h" // Required for using multiple cores on the RP2040. 


/**
 * @brief This function acts as the main entry-point for core #1.
 *        A function pointer is passed in via the FIFO with one
 *        incoming int32_t used as a parameter. The function will
 *        provide an int32_t return value by pushing it back on 
 *        the FIFO, which also indicates that the result is ready.
 */
void core1_entry() {
    while (1) {
        // 
        int32_t (*func)() = (int32_t(*)()) multicore_fifo_pop_blocking();
        int32_t p = multicore_fifo_pop_blocking();
        int32_t result = (*func)(p);
        multicore_fifo_push_blocking(result);
    }
}

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

    const int    ITER_MAX   = 100000;

    // variables to store the timestamps and values for pi
    uint32_t start_time = 0;
    uint32_t end_time = 0;
    float pi_float_approx = 0;
    double pi_double_approx = 0;

    // Initialise the IO as we will be using the UART
    stdio_init_all();

    multicore_launch_core1(core1_entry);


    // Code for sequential run goes here…
    //    Take snapshot of timer and store
    start_time = time_us_32();
    //    Run the single-precision Wallis approximation
    pi_float_approx = wallis_single_precision(ITER_MAX);
    //    Run the double-precision Wallis approximation
    pi_double_approx = wallis_double_precision(ITER_MAX);
    //    Take snapshot of timer and store
    end_time = time_us_32();
    //    Display time taken for application to run in sequential mode
    printf("Sequential run time: %u\n", (end_time-start_time));
    printf("float pi approx: %f \n Double pi approx: %f \n", pi_float_approx, pi_double_approx);

    // set the pi approximations to 0 so that the function calls dontt get optimized away
    pi_float_approx = 0;
    pi_double_approx = 0;

    // Code for parallel run goes here…
    //    Take snapshot of timer and store
    start_time = time_us_32();
    //    Run the single-precision Wallis approximation on one core
    multicore_fifo_push_blocking((uintptr_t) &wallis_single_precision);
    multicore_fifo_push_blocking(ITER_MAX);
    //    Run the double-precision Wallis approximation on the other core
    pi_double_approx = wallis_double_precision(ITER_MAX);
    //  return the value from core 1.
    pi_float_approx = multicore_fifo_pop_blocking();
    //    Take snapshot of timer and store
    end_time = time_us_32();
    //    Display time taken for application to run in parallel mode
    printf("Parallel run time: %u\n", (end_time-start_time));
    printf("Float pi approx: %f \nDouble pi approx: %f \n", pi_float_approx, pi_double_approx);

    // Returning zero indicates everything went okay.
    return 0;
}

