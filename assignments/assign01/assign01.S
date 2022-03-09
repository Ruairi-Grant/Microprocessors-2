
#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                 @ Specify unified assembly syntax
.cpu    cortex-m0plus           @ Specify CPU type is Cortex M0+
.thumb                          @ Specify thumb assembly for RP2040
.global main_asm                @ Provide program starting address to the linker
.align 4                        @ Specify code alignment

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20              @ Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              @ Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

@ Entry point to the ASM portion of the program
main_asm:
        bl      init_led                @ Initialise the GPIO LED pin
        bl      init_all_btns           @ Initialize each GPIO Button
        bl      install_alrm_isr        @
main_loop:
        b       main_loop

@ Initialise the PI Pico built-in LED
init_led:
        push    {lr}                    @ Store the link register to the stack as we will call nested subroutines
        movs    r0, #GPIO_LED_PIN       @ This value is the GPIO LED pin on the PI PICO board
        bl      asm_gpio_init           @ Call the subroutine to initialise the GPIO pin specified by r0
        movs    r0, #GPIO_LED_PIN       @ This value is the GPIO LED pin on the PI PICO board
        movs    r1, #GPIO_DIR_OUT       @ We want this GPIO pin to be setup as an output pin
        bl      asm_gpio_set_dir        @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
        pop     {pc}                    @ Pop the link register from the stack to the program counter

@ Initialise each button using the init_btn subroutine
init_all_btns:
        push    {lr}                    @ Store link reg to the stack so we can call nested subroutines
        movs    r4, #GPIO_BTN_DN        @ Set r4 as the Down Button Pin
        bl      init_btn                @ Initialise the GPIO Button down pins as inputs and with falling edge interupts
        movs    r4, #GPIO_BTN_EN        @ Set r4 as the Enter Button Pin
        bl      init_btn                @ Initialise the GPIO Button Enter pins as inputs and with falling edge interupts
        movs    r4, #GPIO_BTN_UP        @ Set r4 as the Up Button Pin
        bl      init_btn                @ Initialise the GPIO Button Up pins as inputs and with falling edge interupts
        pop     {pc}                    @ Pop the lr from the stack to return to main_asm

@ Subroutine to initialise a Button with falling edge sensitive interupt
init_btn:
        push    {lr}                    @ Store the link reg on the stack so we can call subrouitnes
        movs    r0, r4                  @ This value is the GPIO pin on the PI Pico board that the down button is connected to 
        bl      asm_gpio_init           @ Call the subroutine to initialise the GPIO pin 
        movs    r0, r4                  @ This value is the GPIO pin on the PI Pico board that the button is connected to 
        movs    r1, #GPIO_DIR_IN        @ We want this GPIO pin to be setup as an input pin
        bl      asm_gpio_set_dir        @ Call the subroutine to set the GPIO pin as an input
        movs    r0, r4                  @ Set the value of the GPIO pin for the gpio_set_irq_enabled function
        bl      gpio_set_irq_enabled    @ Enable interrupts at the falling edge for the button
        pop     {pc}                    @ Pop lr into pc to return to previous subroutine

@ Set up the alrm_isr in the RAM vector table and enables the correct interrupt
install_alrm_isr:
        ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Store address of vector table in r2
        ldr     r1, [r2]                                @ Load address pointed to by the vecor table into r1
        movs    r2, #ALRM_ISR_OFFSET                    @ Store the alarm isr offset in r2
        add     r2, r1                                  @ Add the vector table address and the alarm offset
        ldr     r0, =alrm_isr                           @ Load address of alrm_isr into r0
        str     r0, [r2]                                @ Store the address of alrm_isr handler to correct offset in vector table

.thumb_func            
alrm_isr:
        push    {lr}                    @ Push lr to stack to call other subroutines
        ldr     r2, timerbase           @ Load the locaition pointed to by TIMER_BASE into r0

                .align 4
timerbase:      .word TIMER_BASE        

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME