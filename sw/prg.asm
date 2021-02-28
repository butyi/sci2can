; ==============================================================================
;                          MINI LAUSCH BOX
; ==============================================================================
; Hardware: https://github.com/butyi/sci2can/
; Software: janos.bencsik@knorr-bremse.com, 2020.05.23.
; ==============================================================================
#include "dz60.inc"
; ===================== CONFIG =================================================

APPLICATION     equ     0       ; Gateway applications ID (0: github example)
SW_REV          equ     2       ; Software revison
BUILD_DATE_YH   equ     $20     ; ${:year/100}
BUILD_DATE_YL   equ     $21     ; ${:year-2000}
BUILD_DATE_MO   equ     $02     ; ${:month}
BUILD_DATE_DA   equ     $28     ; ${:date}
BUILD_DATE_HO   equ     $09     ; ${:hour}
BUILD_DATE_MI   equ     $30     ; ${:min}
;OSCILL_SUPP     equ     1       ; To switch on oscillator support

BUFFLEN         equ     96      ; Number of bytes in received burst

; uC port definitions with line names in schematic
LED2            @pin    PTA,6
CANRX           @pin    PTE,7
CANTX           @pin    PTE,6
RxD1            @pin    PTE,1
RxD1_2          @pin    PTA,0
FET             @pin    PTD,2
;BTNL            @pin    PTA,2  ; My prototype
;BTNR            @pin    PTA,1  ; My prototype
BTNL            @pin    PTE,3
BTNR            @pin    PTE,2

#ifdef OSCILL_SUPP
; Debug pins to measure execution times (high level) by oscilloscope
OSC_SCIRX       @pin    PTD,0   ; Pin is high during SCI Rx burst
OSC_CANTX       @pin    PTD,1   ; Pin is high during CAN Tx burst
OSC_RTCIT       @pin    PTD,3   ; Pin is high during RTC Interrupt routine
OSC_SCIIT       @pin    PTD,4   ; Pin is high during SCI Rx Interrupt routine
OSC_CANIT       @pin    PTD,5   ; Pin is high during CAN Tx Interrupt routine
#endif

; ===================== INCLUDE FILES ==========================================

#include "cop.sub"
#include "mcg.sub"
#include "rtc.sub"
#include "iic.sub"
#include "ssd1780.sub"          ; 0.96" 128x64 OLED display
#include "lib.sub"
#include "sci.sub"
#include "can.sub"
#include "adc.sub"

; ====================  VARIABLES  =============================================
#RAM

uz              ds      2       ; Hysteresis filtered Uz voltage
btns            ds      1       ; Saved button states to detect change

; ====================  PROGRAM START  =========================================
#ROM

start:
        sei                     ; disable interrupts

        ldhx    #XRAM_END       ; H:X points to SP
        txs                     ; Init SP

        jsr     COP_Init
        jsr     PTX_Init        ; I/O ports initialization
        jsr     MCG_Init
        jsr     RTC_Init
        jsr     CAN_Init
        jsr     SCI_Init
        jsr     IIC_Init        ; Init IIC for fast clear (~100khz)
        bsr     ADC_Init

        cli                     ; Enable interrupts

        clr     uz              ; Init uz variable
        clr     uz+1
        jsr     update_btns     ; Init btns variable

        jsr     IIC_wfe         ; Wait for end of action list
        jsr     DISP_init       ; Initialize display
        lda     #$00            ; Set position to top-left
        ldhx    #startscreen    ; Get address of string
        jsr     DISP_print      ; Print string
        jsr     IIC_wfe         ; Wait for end of action list
;        jsr     IIC_Slow        ; Slow down IIC for update (~10khz)

main
        jsr     KickCop         ; Update watchdog

        brset   EVERY1SEC.,timeevents,m_onesec ; Check if 1s spent

        jsr     update_btns     ; Test button change
        bne     m_btn_event     ; In case of edge, jump to handle

        mov     #PIN5.,ADCSC1   ; Start Uz voltage measurement
m_meas
        jsr     KickCop         ; Update watchdog
        brclr   COCO.,ADCSC1,m_meas ; Wait for finish Uz measurement

        ldx     #0              ; Load uz to arit32
        stx     arit32
        stx     arit32+1
        lda     uz
        sta     arit32+2
        lda     uz+1
        sta     arit32+3

        stx     yy              ; *=255
        stx     yy+1
        stx     yy+2
        lda     #255
        sta     yy+3

        jsr     szor16bit

        ldx     #0              ; /=256
        stx     yy
        stx     yy+1
        lda     #1
        sta     yy+2
        stx     yy+3

        jsr     oszt32bit

        lda     arit32+3        ; +=ADCRL
        add     ADCRL
        sta     uz+1
        lda     arit32+2
        adc     #0
        sta     uz              ; Save back to uz

        bra     main            ; Repeat main cycle

m_onesec                        ; This path called once in every sec
        bclr    EVERY1SEC.,timeevents ; Clear event flag

        lda     uz              ; Load high byte

;        ldx     #18             ; *=18  ;My prototype
        ldx     #55             ; *=55
        mul

        pshx
        pulh
;        ldx     #10             ; /=10  ;My prototype
        ldx     #30             ; /=30
        div

        clrh
        ldx     #1              ; Length of fractional part is 1 digit
        mov     #5,str_bufidx   ; Set length of string
        jsr     str_val         ; Convert value to string
        lda     #$26            ; Screen position
        jsr     DISP_print      ; Print string

        ; Update SCI status
        ldhx    #ok_err_str
        brclr   SCIPACK_LED.,led_flags,m_sci_err
        aix     #2
m_sci_err
        lda     #$45            ; Screen position
        jsr     DISP_print      ; Print string

        ; Update CAN status
        ldhx    #ok_err_str
        brclr   CANSENT_LED.,led_flags,m_can_err
        aix     #2
m_can_err
        lda     #$4E            ; Screen position
        jsr     DISP_print      ; Print string

        jmp     main

m_btn_event                     ; Button state changed
        ldhx    #btn_str        ; Just show the new state, no real function yet
        lda     btns
        and     #BTNL_
        beq     m_btnl_err
        aix     #4
m_btnl_err
        lda     #$72            ; Screen position
        jsr     DISP_print      ; Print string

        ldhx    #btn_str        ; Just show the new state, no real function yet
        lda     btns
        and     #BTNR_
        beq     m_btnr_err
        aix     #4
m_btnr_err
        lda     #$7B            ; Screen position
        jsr     DISP_print      ; Print string

        jmp     main

; ===================== STRINGS ================================================

hexakars
        db '0123456789ABCDEF'
startscreen
        db "* sci2can 1v02 *"
        db "                "
        db "   Uz=      V   "
        db "                "
        db " SCI ?    CAN ? "
        db "                "
        db "Build 2102280930"
        db "                "
        db 0
ok_err_str
        db "-",0
        db $1F,0                ; Check mark symbol

btn_str
        db "   ",0
        db "vvv",0


; ===================== SUB-ROUTINES ===========================================

; ------------------------------------------------------------------------------
; Parallel Input/Output Control
; To prevent extra current consumption caused by flying not connected input
; ports, all ports shall be configured as output. I have configured ports to
; low level output by default.
; There are only a few exceptions for the used ports, where different
; initialization is needed.
; Default init states are proper for OSCILL_SUPP pins, no exception needed.
PTX_Init
        ; All ports to be low level
        clra
        sta     PTA
        sta     PTB
        sta     PTC
        sta     PTD
        sta     PTE
        sta     PTF
        sta     PTG
        bset    CANTX.,CANTX    ; CANTX to be high
        bset    LED2.,LED2      ; LED2 to be On

        ; All ports to be output
        lda     #$FF
        sta     DDRA
        sta     DDRB
        sta     DDRC
        sta     DDRD
        sta     DDRE
        sta     DDRF
        sta     DDRG
        bclr    CANRX.,CANRX+1  ; CANRX to be input
        bclr    RxD1.,RxD1+1    ; RxD1 to be input
        bclr    RxD1_2.,RxD1_2+1        ; RxD1_2 to be input
        bclr    BTNL.,BTNL+1    ; Button to be input
        bclr    BTNR.,BTNR+1    ; Button to be input
        lda     #BTNL_|BTNR_    ; Buttons to be pulled up
        sta     PTEPE           ;  to prevent instable state when not mounted
        lda     #RxD1_2_
        sta     PTAPE           ; RxD1_2 to be pulled up

        rts

update_btns
        lda     BTNL            ; Load current button state
        coma                    ; Change polarity to active low
        and     #BTNL_|BTNR_    ; Mask bits of two buttons
        tax                     ; Update btns later with this value
        eor     btns            ; Detect state change comparing to last value still in btns
        stx     btns            ; Update btns now with before saved value
        tsta                    ; Update status register with A to report any button edge
        rts


; ===================== IT VECTORS =============================================
#VECTORS

        org     Vreset
        dw      start

; ===================== END ====================================================



