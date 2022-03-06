#include "hardware/regs/addressmap.h"
#include "hardware/regs/m0plus.h"

.syntax unified                 @ Specify unified assembly syntax
.cpu    cortex-m0plus           @ Specify CPU type is Cortex M0+
.thumb                          @ Specify thumb assembly for RP2040
.global main_asm                @ Provide program starting address to the linker
.align 4                        @ Specify code alignment

.equ    SLEEP_TIME, 500         @ Specify the sleep time (in ms)
.equ    LED_GPIO_PIN, 25        @ Specify the pin that the LED is connected to
.equ    LED_GPIO_OUT, 1         @ Specify the direction of the GPIO pin
.equ    LED_VALUE_ON, 1         @ Specify the value that turns the LED "on"
.equ    LED_VALUE_OFF, 0        @ Specify the value that turns the LED "off"
.equ    SVC_ISR_OFFSET, 0x2C    @ The SVC is entry 11 in the vector table
.equ    SVC_MAX_INSTRS, 0x01    @ Maximum allowed SVC subroutines


@ Entry point to the ASM portion of the program
main_asm:
    bl      init_gpio_led       @ Initialise the GPIO LED pin
    bl      install_svc_isr     @ Install the SVC interrupt service routine
loop:
    svc     #0                  @ Call the SVC ISR with value 0 (turns on LED)
    nop                         @ Add a no-op instruction for alignment after SVC
    bl      do_sleep            @ Short pause before proceeding
    svc     #1                  @ Call the SVC ISR with value 1 (turns off LED)
    nop                         @ Add a no-op instruction for alignment after SVC
    bl      do_sleep            @ Add a short pause before proceeding
    b       loop                @ Always jump back to the start of the loop

@ Subroutine used to introduce a short delay in the application
do_sleep:
    push    {lr}                 @ Store the link register to the stack as we will call nested subroutines
    ldr     r0, =SLEEP_TIME     @ Set the value of SLEEP_TIME we want to wait for
    bl      sleep_ms            @sleep for duration SLEEP_TIME
    pop     {pc}                @ Pop the link register from the stack to the program counter

@ Subroutine used to initialise the PI Pico built-in LED
init_gpio_led:

    push    {lr}                        @ Store the link register to the stack as we will call nested subroutines
    movs    r0, #LED_GPIO_PIN           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO pin specified by r0
    movs    r0, #LED_GPIO_PIN           @ This value is the GPIO LED pin on the PI PICO board
    movs    r1, #LED_GPIO_OUT           @ We want this GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
    pop     {pc}                        @ Pop the link register from the stack to the program counter


@ Subroutine used to install the SVC interrupt service handler
install_svc_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Put address of ISR in r2
    ldr     r1, [r2]                                @ Load address pointed to by r2 in r1
    movs    r2, #SVC_ISR_OFFSET                     @ Store SVC_ISR_OFFSET in r2
    add     r2, r1                                  @ Add r2 and r1 and store in r2
    ldr     r0, =svc_isr                            @ Load address of svc_isr into r0
    str     r0, [r2]                                @ Store address of length r2 starting at r0
    bx      lr                                      @ return to main

@ SVC interrupt service handler routine
.thumb_func                     @ Required for all interrupt service routines
svc_isr:
    push    {lr}                @ Store the link register to the stack so that we can call nested subrutines
    ldr     r0, [sp, #0x1C]     @ Load the value pointed to in the sp register offset by #0x1c
    subs    r0, #0x2            @ Subtract #0x2 from r0 and store in r0
    ldr     r0, [r0]            @ load the address pointed to by r0 into r0
    ldr     r1, =#0xFF          @ Load the address #0xFF into r1
    ands    r0, r1              @ Logical and the values in r0 and r1, store in r0 update ASPR
    cmp     r0, #SVC_MAX_INSTRS @ compare the value in r0 with #SVC_MAX_INSTRS
    bgt     svc_done            @ branch to svc_done if r0 is greater then #SVC_MAX_INSTRS
    adr     r1, svc_jmptbl      @ Put register relitive address of svc_jmptbl in r1
    lsls    r0, #2              @ logical shift value in r0 left by 2
    ldr     r1, [r1, r0]        @ load the value pointed to by r1 + r0 into r1
    mov     pc, r1              @ Go to the Instruciton pointed to by r1
svc_done:
    pop     {pc}                @ Pop the link register from the stack to the program counter

@ First function of SVC subroutine - turn on the LED
svc_num0:
    @push    {lr}                        @ Store the link register to the stack as we will call nested subroutines
    movs    r1, #LED_VALUE_ON           @ Store the value 1 in r1 to turn LED on
    movs    r0, #LED_GPIO_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
    bl      asm_gpio_put                @ Update the the value of the LED GPIO pin (based on value in r1)
    b       svc_done                    @ Branch back to the main ISR when done
    pop     {pc}                        @ Pop the link register from the stack to the program counter

@ Second function of SVC subroutine - turn off the LED
svc_num1:
    movs    r1, #LED_VALUE_OFF           @ Store the value 1 in r1 to turn LED on
    movs    r0, #LED_GPIO_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
    bl      asm_gpio_put                @ Update the the value of the LED GPIO pin (based on value in r1)
    b       svc_done                    @ Branch back to the main ISR when done


@ SVC function entry jump table.
.align 2
svc_jmptbl:
    .word svc_num0              @ Entry zero goes to SVC function #0.
    .word svc_num1              @ Entry one goes to SVC function #1.
    .word 0                     @ Null termination of the jump table.




@ Set data alignment
.data
    .align 4
