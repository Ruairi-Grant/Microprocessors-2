
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
	bl      install_alrm_isr        @ intall and setup the alarm isr
        bl      install_gpio_isr        @ install and setup the gpio isr
main_loop:
        bl      set_alarm               @ Set a new alarm
        movs    r0, #GPIO_BTN_DN
        bl      asm_gpio_get
        wfi                             @ Wait untill an interupt fires
        b       main_loop               @ loop back to the start   
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
        bl      asm_gpio_set_irq        @ Enable interrupts at the falling edge for the button
        pop     {pc}                    @ Pop lr into pc to return to previous subroutine


set_alarm:
	@ Enable timer interupts
        ldr     r2, =TIMER_BASE                 @ load the location pointed to by TIMER_BASE into r2
        movs    r1, #1                          @ Move 1 into r1 to set timer_inte high
        str     r1, [r2, #TIMER_INTE_OFFSET]    @ Enable alarm timer interupts
	@ get current time count and add time delay to this 
	ldr     r1, [r2, #TIMER_TIMELR_OFFSET]  @ Load current timer count into r1
        ldr     r3, =ltimer                     @ Load address of current alarm time into r3
        ldr     r0, [r3]                        @ Load the value of current alarm time intto r0
        add     r1, r0                          @ Add default alarm time to curretn timer count
	str     r1, [r2, #TIMER_ALARM0_OFFSET]  @ Store this value at alarm 0 

        bx      lr                              @ return to main loop


.thumb_func	@ necessary for interrupt handlers
@ Alarm 0 interrupt handler and state machine.
alarm_isr:
	push	{lr}	                        @ calls other routines

	@ Disable the pending interrupt from TIMER
        ldr     r2, =TIMER_BASE                 @ Load the locaition pointed to by TIMER_BASE into r0
        movs    r1, #1                          @ Move 1 into r1 so that NVIC_ICPR can be set high
        str     r1, [r2, #TIMER_INTR_OFFSET]    @ Set NVIC_ICPR high to disable the alarm irq

	@ Toggle the state of the LED then set the alarm
        ldr     r2, =lstate                     @ Load address of the state of the LED into r2
        ldr     r1, [r2]                        @ load value of the state into r1
        movs    r3, #1                          @ Case that state = 1
        cmp     r1, r3                          @ compare the state with 1
        beq     LED_off                         @ Turn the LED off
LED_on:	
        movs    r1, #LED_VAL_ON                 @ set lstate to 1
        ldr     r2, =lstate                     @ load the address of next_state
        str     r1, [r2]                        @ store state = 0
        b       led_set_state                   @ Set the state of 
LED_off:	
        movs    r1, #LED_VAL_OFF                @ set lstate to 1
        ldr     r2, =lstate                     @ load the address of state
        str     r1, [r2]                        @ store state = 1
led_set_state:	
        movs    r0, #GPIO_LED_PIN               @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
        bl      asm_gpio_put                    @ Update the the value of the LED GPIO pin (based on value in r1)
	pop     {pc}                            @ Return from the interrupt



	
@ Set up the alrm_isr in the RAM vector table and enables the correct interrupt
install_alrm_isr:
	@ Set alarm_isr handler to the correct address
        ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Store address of vector table in r2
        ldr     r1, [r2]                                @ Load address pointed to by the vecor table into r1
        movs    r2, #ALRM_ISR_OFFSET                    @ Store the alarm isr offset in r2
        add     r2, r1                                  @ Add the vector table address and the alarm offset
        ldr     r0, =alarm_isr                          @ Load address of alrm_isr handler into r0
        str     r0, [r2]                                @ Store the address of alrm_isr handler to correct offset in vector table

	@ Disable then enable the ALARM IRQ
        movs    r0, #1                                  @ Move 1 into r1 so that we can set values high
        ldr     r1, =(PPB_BASE+M0PLUS_NVIC_ICPR_OFFSET) @ Load address of the nvic_ipcr to r1
        str     r0, [r1]                                @ Store 1 in nvic_icpr to disable the alarm irq
        ldr     r1, =(PPB_BASE+M0PLUS_NVIC_ISER_OFFSET) @ load address of the nvic_iser to r1
        str     r0, [r1]                                @ Store 1 in the nvic_iser to enable the alarm irq
	
	bx      lr                                      @return to main


//
// Sets up the gpio_isr in the RAM vector table and enables the correct interrupt
//
install_gpio_isr:
        @ Set alarm_isr handler to the correct address
        ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Store address of vector table in r2
        ldr     r1, [r2]                                @ Load address pointed to by the vecor table into r1
        movs    r2, #GPIO_ISR_OFFSET                    @ Store the gpio isr offset in r2
        add     r2, r1                                  @ Add the vector table address and the gpio offset
        ldr     r0, =gpio_isr                           @ Load address of gpio_isr handler into r0
        str     r0, [r2]                                @ Store the address of gpio_isr handler to correct offset in vector table

        @ Disable then enable the GPIO IRQ 
        ldr    r0, =0x2000                              @ Move 0x2000 into r1 so that we can set values high
        ldr     r1, =(PPB_BASE+M0PLUS_NVIC_ICPR_OFFSET) @ Load address of the nvic_ipcr to r1
        str     r0, [r1]                                @ Store 0x2000 in nvic_icpr to disable the gpio irq
        ldr     r1, =(PPB_BASE+M0PLUS_NVIC_ISER_OFFSET) @ load address of the nvic_iser to r1
        str     r0, [r1]                                @ Store 0x2000 in the nvic_iser to enable the gpio irq


//
// Service the pending interrupt from the GPIO
//
gpio_isr:
        @ Read the interrupt status and detect which button was pressed
        push    {lr}                                                    @ Push lr to the stack
        ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)      @ Load address of interupt status event register
        ldr     r1, [r2]                                                @ Load the interupt status into r1
        ldr     r0, =GPIO_BTN_DN_MSK                                    @ Load mask for the down button into r0
        cmp     r1, r0                                                  @ Check if r1 and compare are the same
        beq     btn_dn                                                  @ If down button was pressed branch ...
        ldr     r0, =GPIO_BTN_UP_MSK                                    @ Load mask for the down button into r0
        cmp     r1, r0                                                  @ Check if r1 and compare are the same
        beq     btn_up                                                  @ If down button was pressed branch ...
        ldr     r0, =GPIO_BTN_EN_MSK                                    @ Load mask for the down button into r0
        cmp     r1, r0                                                  @ Check if r1 and compare are the same
        beq     btn_en                                                  @ If down button was pressed branch ..
        b       disable_irq                                             @ else disable irq
btn_dn: 
        ldr     r2, =ltimer                     @ Load address of the alarm delay into r2
        ldr     r1, [r2]                        @ load value of the delay into r1
        movs    r0, r1, lsl #4                  @ shift bits to the right to devide by 2
        ldr     r2, =ltimer                     @ Load address of the alarm delay into r2
        str     r0, [r2]                        @ store new delay
        b       disable_irq
btn_up: 
        ldr     r2, =ltimer                     @ Load address of the alarm delay into r2
        ldr     r1, [r2]                        @ load value of the delay into r1
        movs    r0, r1, lsl #1                  @ shift bits to the right to devide by 2
        ldr     r2, =ltimer                     @ Load address of the alarm delay into r2
        str     r0, [r2]                        @ store new delay
        b       disable_irq
btn_en:

disable_irq:
        ldr     r2, =(IO_BANK0_BASE+IO_BANK0_INTR2_OFFSET)      @ Load the locaition pointed to by TIMER_BASE into r0
        movs    r1, #1                                          @ Move 1 into r1 so that NVIC_ICPR can be set high
        str     r1, [r2]                                        @ Set NVIC_ICPR high to disable the gpio irq
       

        pop     {pc}




.data
lstate:		.word	0
ltimer:         .word   DFLT_ALARM_TIME
enstate:        .word   1       @ if =1 then allow flashing, otherwise dont

