; ==============================================================================
; ============================  SCI to CAN gateway  ============================
; ==============================================================================
; Details: https://github.com/butyi/sci2can/
; ==============================================================================

; ===================== INCLUDE FILES ==========================================

#include "dz60.inc"

; ===================== DEFINES ================================================

APPLICATION     def     0       ; Gateway applications ID (0: github example)
SW_REV          def     1       ; Software revison

OSCILL_SUPP     def     1       ; To switch on oscillator support

BUFFLEN         def     96      ; Number of bytes in received burst

; uC port definitions with line names in schematic
LED2            @pin    PTA,6
CANRX           @pin    PTE,7
CANTX           @pin    PTE,6
RxD1            @pin    PTE,1
RxD1_2          @pin    PTA,0
FET             @pin    PTD,2

#ifdef OSCILL_SUPP
; Debug pins to measure execution times (high level) by oscilloscope
OSC_SCIRX       @pin    PTD,0   ; Pin is high during SCI Rx burst
OSC_CANTX       @pin    PTD,1   ; Pin is high during CAN Tx burst
OSC_RTCIT       @pin    PTD,3   ; Pin is high during RTC Interrupt routine
OSC_SCIIT       @pin    PTD,4   ; Pin is high during SCI Rx Interrupt routine
OSC_CANIT       @pin    PTD,5   ; Pin is high during CAN Tx Interrupt routine
#endif

; ====================  VARIABLES  =============================================
#RAM

led_timer       ds      1       ; Timer for flash status LED

led_flags       ds      1       ; Flag bits for flash status LED
                @bitnum POWERED,4
                @bitnum SCIBYTE,5
                @bitnum SCIPACK,6
                @bitnum CANSENT,7

sci_ptr         ds      1       ; Pointer for fill up sci_buffer from SCI

can_ptr         ds      1       ; Pointer for read data from sci_buffer to CAN

sci_buffer      ds      BUFFLEN ; Data buffer

; ====================  PROGRAM START  =========================================
#ROM

start:
        sei                     ; disable interrupts

        ldhx    #XRAM_END       ; H:X points to SP
        txs                     ; Init SP

        clra                    ; Clear A
        sta     SOPT1           ; Disable COP

        bsr     PTX_Init        ; I/O ports initialization
        bsr     MCG_Init
        bsr     RTC_Init
        jsr     CAN_Init
        jsr     SCI_Init
        
        cli                     ; Enable interrupts

main
        bra     main


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
        bset    CANTX.,CANTX            ; CANTX to be high

        ; All ports to be output
        lda     #$FF
        sta     DDRA
        sta     DDRB
        sta     DDRC
        sta     DDRD
        sta     DDRE
        sta     DDRF
        sta     DDRG
        bclr    CANRX.,CANRX+1          ; CANRX to be input
        bclr    RxD1.,RxD1+1            ; RxD1 to be input
        bclr    RxD1_2.,RxD1_2+1        ; RxD1_2 to be input

        rts


; ------------------------------------------------------------------------------
; Multi-Purpose Clock Generator (S08MCGV1) 
; Using DZ60, this will switch MCG to PEE Mode (based on AN3499)
;  Fext = 4MHz (crystal)
;  Fmcgout = ((Fext/R)*M/B) - for PEE mode
;  Fbus = Fmcgout/2 (8MHz)
MCG_Init
        ; -- First, FEI must transition to FBE mode

        ; MCG Control Register 2 (MCGC2)
        ;  BDIV = 00 - Set clock to divide by 1
        ;  RANGE_SEL = 1 - High Freq range selected (4MHz is in high freq range)
        ;  HGO = 1 - Ext Osc configured for high gain
        ;  LP = 0 - FLL or PLL is not disabled in bypass modes
        ;  EREFS = 1 - Oscillator requested
        ;  ERCLKEN = 1 - MCGERCLK active
        ;  EREFSTEN = 0 - Ext Reference clock is disabled in stop
        mov     #RANGE_SEL_|HGO_|EREFS_|ERCLKEN_,MCGC2

        ; Loop until OSCINIT = 1 - indicates crystal selected by EREFS bit
        ;   has been initalised
imcg1
        brclr   OSCINIT.,MCGSC,imcg1

        ; MCG Control Register 1 (MCGC1)
        ;  CLKSx    = 10    Select Ext reference clk as clock source 
        ;  RDIVx    = 111   Set to divide by 128 
        ;    (i.e. 4MHz/128 = 31.25kHz - in range required by FLL)
        ;  IREFS    = 0     Ext Ref clock selected
        ;  IRCLKEN  = 0     MCGIRCLK inactive
        ;  IREFSTEN = 0     Internal ref clock disabled in stop  
        mov     #CLKS1_|RDIV2_|RDIV1_|RDIV0_,MCGC1

        ; Loop until IREFST = 0 - indicates ext ref is current source
imcg2
        brset  IREFST.,MCGSC,imcg2

        ; Loop until CLKST = 10 - indiates ext ref clk selected to feed MCGOUT
imcg3
        lda     MCGSC
        and     #CLKST1_|CLKST0_        ; mask CLKST bits
        cmp     #CLKST1_
        bne     imcg3

        ; -- Next FBE must transition to PBE mode

        ; MCG Control Register 1 (MCGC1)
        ;  CLKSx    = 10    Select Ext reference clk as clock source 
        ;  RDIVx    = 010   Set to divide by 4
        ;    (i.e. 4MHz/4 = 1 MHz - in range required by FLL)
        ;  IREFS    = 0     Ext Ref clock selected
        ;  IRCLKEN  = 0     MCGIRCLK inactive
        ;  IREFSTEN = 0     Internal ref clock disabled in stop  
        mov     #CLKS1_|RDIV1_,MCGC1

        ; MCG Control Register 3 (MCGC3)
        ;  LOLIE = 0    No request on loss of lock
        ;  PLLS  = 1    PLL selected
        ;  CME   = 0    Clock monitor is disabled
        ;  VDIV  = 0100 Set to multiply by 16 (1Mhz ref x 16 = 16MHz)
        mov     #PLLS_|4,MCGC3

        ; Loop until PLLST = 1 - indicates current source for PLLS is PLL
imcg4
        brclr   PLLST.,MCGSC,imcg4

        ; Loop until LOCK = 1 - indicates PLL has aquired lock
imcg5
        brclr   LOCK.,MCGSC,imcg5

        ; -- Last, PBE mode transitions into PEE mode

        ; MCG Control Register 1 (MCGC1)
        ;  CLKS     = 00    Select PLL clock source 
        ;  RDIV     = 010   Set to divide by 4
        ;    (i.e. 4MHz/4 = 1 MHz - in range required by PLL)
        ;  IREFS    = 0     Ext Ref clock selected
        ;  IRCLKEN  = 0     MCGIRCLK inactive
        ;  IREFSTEN = 0     Internal ref clock disabled in stop
        mov     #RDIV1_,MCGC1

        ; Loop until CLKST = 11 - PLL O/P selected to
        ;   feed MCGOUT in current clk mode
imcg6  
        lda     MCGSC
        and     #CLKST1_|CLKST0_        ; mask CLKST bits
        cmp     #CLKST1_|CLKST0_
        bne     imcg6

        ; ABOVE CODE ALLOWS ENTRY FROM PBE TO PEE MODE

        ; Since RDIV = 4, BDIV = 1, VDIV = 16
        ; Now
        ;  Fmcgout = ((4MHz/4)*16)/1 = 16MHz
        ;  Fbus = Fmcgout/2 = 8MHz

        rts


; ------------------------------------------------------------------------------
; Real-Time Counter (S08RTCV1)
; This is periodic timer. (Like PIT in AZ60, TBM in GZ60 in the past) 
;  - Select external clock (RTCLKS = 1)
;  - Use interrupt to handle software timer variables (RTIE = 1)
;  - RTCPS = 11 (10^4 means 4MHz/10000 = 400Hz)
;  - RTCMOD = 100 (400Hz/100 = 4Hz -> 250ms)
; This will result 250ms periodic interrupt.
RTC_Init
        ; Set up registers
        mov     #RTIE_|RTCLKS0_|11,RTCSC
        mov     #100,RTCMOD

        clr     led_timer       ; Init timer
        mov     #POWERED_,led_flags ; Init request nibble
        
        rts

; RTC periodic interrupt service routine, hits in every 250ms
; This is used only to flash status LED.
; There are 4 status bits. Each notifies an event of sequence in the below order.
; - POWERED: always set. (#$1)
; - SCIBYTE: At least one byte was received from SCI (#$2)
; - SCIPACK: Complete burst was received from SCI (#$4)
; - CANSENT: All CAN messages of burst were sent on CAN (#$8)
; At every 1s, the high nibble will be copied to low nibble.
; Low nibble bits are saved value, this will be shown on LED.
; High nibble bits are request bits. These are set by SCI and CAN IT routines
; during execution in sequence. If a prevoius event did not happen, next events
; will not happen. This means, bits (events) can only be set in the order.
; Therefore only the following values are possible:
; - #$1: Only POWERED, no byte was received from SCI. (LED flash: ___X)
; - #$3: Some bytes were received from SCI but not enough. (LED flash: __XX)
; - #$7: All bytes of burst were received from SCI. (LED flash: _XXX)
; - #$F: All bytes were transmitted on CAN successfully. (LED flash: XXXX)
; Below 250ms task will go through on these bits in the above order and set LED
; On if the current bit is set. So, the following error codes are visible on LED.
; - ___X, Short 25% flash: There is no SCI communication.
;   Check proper connection, cable, check signal on SCI line. 
; - __XX, Medium 50% flash: SCI burst is short, received bytes are not enough.
;   Check if transmitter system and baud rate are proper. 
; - _XXX, Long 75% flash: SCI is OK, but data cannot be sent to CAN.
;   Check CAN lines (Low and High), Check CAN baud rate (shall be 250k)  
; - XXXX, Always On: Everything are OK, data is gatewayed to CAN properly.
RTC_IT
        bset    RTIF.,RTCSC     ; Clear flag
#ifdef OSCILL_SUPP
        bset    OSC_RTCIT.,OSC_RTCIT ; Set debug measure pin
#endif        
        ; Handle Status LED
        inc     led_timer
        lda     led_timer
        and     #3              ; check only 2 LSB bits
        tax
        bne     RTC_IT_no1sec
        ; Move 4bits request to 4bits execute and reinit 4bits request 
        lda     led_flags
        nsa                     ; Move high nibble to low 
        and     #$0F            ; Keep only low nibble
        ora     #POWERED_       ; Set Powered bit in high nibble 
        sta     led_flags
RTC_IT_no1sec

        pshh                    ; Save H, because it will be used
        clrh
        incx
        clra
        sec
RTC_IT_2                        ; A = 1<<X
        rola
        dbnzx   RTC_IT_2
        and     led_flags       ; See masked bit of led_flags 
        pulh                    ; Restore H 
        bne     RTC_IT_LED_On
        bclr    LED2.,LED2      ; Switch LED Off
        bra     RTC_IT_end
RTC_IT_LED_On        
        bset    LED2.,LED2      ; Switch LED On
RTC_IT_end
#ifdef OSCILL_SUPP
        bclr    OSC_RTCIT.,OSC_RTCIT ; Clear debug measure pin
#endif
        rti
        
; ------------------------------------------------------------------------------
; Freescale Controller Area Network (S08MSCANV1)
; Set up CAN for 250 kbit/s using 4 MHz external clock
; CAN will use in interrupt mode, but init does not enable interrupt.
; It will be enabled when transmission can be started, so when
; all bytes have been received from SCI.
;
;   Baud = fCANCLK / Prescaler / (1 + Tseg1 + Tseg2) = 
;     4MHz / 2 / (1+5+2) = 250k
;   Sample point = 75% 
;     (1 + Tseg1)/(1 + Tseg1 + Tseg2) = (1+5)/(1+5+2) = 0.75
CAN_Init
        ; MSCAN Enable
        lda     #CAN_CANE_
        sta     CANCTL1

        ; Wait for Initialization Mode Acknowledge
ican1
        lda     CANCTL1
        and     #CAN_INITAK_
        beq     ican1

        ; SJW = 1 Tq, Prescaler value (P) = 2
        lda     #1
        sta     CANBTR0
        
        ; One sample per bit, Tseg2 = 2, Tseg1 = 5
        lda     #$14
        sta     CANBTR1

        ; Leave Initialization Mode
        clra
        sta     CANCTL0

        ; Wait for exit Initialization Mode Acknowledge
ican2
        lda     CANCTL1
        and     #CAN_INITAK_
        bne     ican2

        ; Send info message
        
        ; Select first buffer
        lda     #1
        sta     CANTBSEL

        ; Set ID
        lda     #$FF
        sta     CANTIDR0
        sta     CANTIDR1        ; Set IDE and SRR
        sta     CANTIDR2
        and     #$FE            ; Clear RTR bit
        sta     CANTIDR3
        
        ; Set message data
        lda     #APPLICATION
        sta     CANTDSR0
        lda     #SW_REV
        sta     CANTDSR1
        lda     #${:year/100}
        sta     CANTDSR2
        lda     #${:year-2000}
        sta     CANTDSR3
        lda     #${:month}
        sta     CANTDSR4
        lda     #${:date}
        sta     CANTDSR5
        lda     #${:hour}
        sta     CANTDSR6
        lda     #${:min}
        sta     CANTDSR7

        ; Set data length
        lda     #8
        sta     CANTDLR

        ; Transmit the message
        lda     CANTBSEL
        sta     CANTFLG

        rts


; CAN Tx interrupt service routine. This will send automatic all 20 messages in
; burst. When last message was transmitted, interrupt disables itself to stop
; transmission.
CAN_TX_IT
#ifdef OSCILL_SUPP
        bset    OSC_CANIT.,OSC_CANIT ; Set debug measure pin
#endif        
        ; Save H, because it will be used but not saved by CPU.
        pshh
        
        ; Set index register
        clrh
        ldx     can_ptr
        
        ; Select first buffer
        lda     #1
        sta     CANTBSEL
        
        ; Set ID
        stx     CANTIDR0        ; byte pointer is ID
        clra
        sta     CANTIDR1
        sta     CANTIDR2
        sta     CANTIDR3
        
        ; Set message data
        lda     sci_buffer+0,x
        sta     CANTDSR0
        lda     sci_buffer+1,x
        sta     CANTDSR1
        lda     sci_buffer+2,x
        sta     CANTDSR2
        lda     sci_buffer+3,x
        sta     CANTDSR3
        lda     sci_buffer+4,x
        sta     CANTDSR4
        lda     sci_buffer+5,x
        sta     CANTDSR5
        lda     sci_buffer+6,x
        sta     CANTDSR6
        lda     sci_buffer+7,x
        sta     CANTDSR7

        ; Set data length
        lda     #8
        sta     CANTDLR

        ; Transmit the message
        lda     CANTBSEL
        sta     CANTFLG
        
        ; Select next message
        lda     can_ptr
        add     #8
        sta     can_ptr
        ; Check if last message was sent
        cmp     #BUFFLEN
        blo     CAN_TX_IT_1
        ; Disable interrupt to stop CAN transmission
        lda     #0
        sta     CANTIER
        bset    CANSENT.,led_flags      ; Notify successfully sent CAN messages
#ifdef OSCILL_SUPP
        bclr    OSC_CANTX.,OSC_CANTX ; Clear debug measure pin
#endif
CAN_TX_IT_1
        
        ; Resore H before return from interrupt
        pulh
#ifdef OSCILL_SUPP
        bclr    OSC_CANIT.,OSC_CANIT ; Clear debug measure pin
#endif
        rti


; ------------------------------------------------------------------------------
; Serial Communications Interface (S08SCIV4)
; Init SCI to receive serial data with baud rate 125k
SCI_Init
        clr     SCI1BDH
        mov     #4,SCI1BDL      ; Baud (8MHz / 16 / 4 = 125k )
        mov     #RE_|RIE_|ILIE_,SCI1C2 ; Rx enable with IT
        clr     sci_ptr         ; Init buffer pointer of SCI
        clr     can_ptr         ; Init buffer pointer of CAN
        rts
        
; SCI RX interrupt service.
; Two interrupts are used. RX and IDLE. RX interrupt is invoked when byte is
; received. Byte is stored in sci_buffer. IDLE interrupt is invoked once when
; bus line is idle for one byte long time after active communication. This is
; used to detect end of bujrst data packet, to trigger CAN transmission.
SCIRX_IT
#ifdef OSCILL_SUPP
        bset    OSC_SCIIT.,OSC_SCIIT ; Set debug measure pin
#endif
        lda     SCI1S1          ; Clear RDRF by read the register
        tax                     ; Save value of SCIxS1 for further check
        and     #RDRF_          ; Check if byte reception happened 
        bne     SCIRX_IT_char   ; If yes, jump to char handling
        txa                     ; Check if saved SCIxS1 notifies
        and     #IDLE_          ;  line idle event
        bne     SCIRX_IT_idle   ; If yes, jump to complete frame handling
        lda     SCI1D           ; Load data register is needed to clear flags
        bra     SCIRX_IT_end

SCIRX_IT_char
        clrh                    ; H not needed for short pointer
        ldx     sci_ptr         ; X = sci_ptr
        cmp     #BUFFLEN        ; Check number of already received bytes
        bhs     SCIRX_IT_much   ; Too much byte, not needed
        lda     SCI1D           ; Load received byte
        sta     sci_buffer,x    ; Store in sci_buffer[sci_ptr]
        inc     sci_ptr         ; Next byte in sci_buffer
SCIRX_IT_much
        bset    SCIBYTE.,led_flags ; Notify received SCI byte
#ifdef OSCILL_SUPP
        bset    OSC_SCIRX.,OSC_SCIRX ; Set debug measure pin
#endif
        bra     SCIRX_IT_end

SCIRX_IT_idle        
        lda     SCI1D           ; Load data register, needed to clear IDLE
        clr     can_ptr
        lda     sci_ptr         ; Check if num of received bytes
        cmp     #BUFFLEN        ;  are a complete pack
        blo     SCIRX_IT_incomplete ; If not, skip CAN TX
        bset    SCIPACK.,led_flags ; Notify received complete SCI burst
#ifdef OSCILL_SUPP
        bset    OSC_CANTX.,OSC_CANTX ; Set debug measure pin
#endif
        lda     #1              ; Enable TX_IT for first CAN Tx buffer
        sta     CANTIER         ;  to start CAN transmission
SCIRX_IT_incomplete        
#ifdef OSCILL_SUPP
        bclr    OSC_SCIRX.,OSC_SCIRX ; Clear debug measure pin
#endif
        clr     sci_ptr         ; First byte in sci_buffer
SCIRX_IT_end        
#ifdef OSCILL_SUPP
        bclr    OSC_SCIIT.,OSC_SCIIT ; Set debug measure pin
#endif
        rti
        
; ===================== IT VECTORS =============================================
        
        org     Vcantx
        dw      CAN_TX_IT
        
        org     Vsci1rx
        dw      SCIRX_IT
        
        org     Vrtc
        dw      RTC_IT
        
        org     Vreset
        dw      start

; ===================== END ====================================================



