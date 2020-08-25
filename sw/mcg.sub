; ===================== Sub-Routines ==========================================
#ROM
; ------------------------------------------------------------------------------
; Using DZ60, the function will switch to PEE Mode (based on AN3499)
;  Fext = 4MHz (crystal)
;  Fmcgout = ((Fext/R)*M/B) - for PEE mode
;  Fbus = Fmcgout/2 (8MHz)
MCG_Init
        ; -- First, FEI must transition to FBE mode

        ; MCG Control Register 2 (MCGC2)
        ;  BDIV = 00 - Set clock to divide by 1
        ;  RANGE_SEL = 1 - High Freq range selected (i.e. 4MHz in high freq range)
        ;  HGO = 1 - Ext Osc configured for high gain
        ;  LP = 0 - FLL or PLL is not disabled in bypass modes
        ;  EREFS = 1 - Oscillator requested
        ;  ERCLKEN = 1 - MCGERCLK active
        ;  EREFSTEN = 0 - Ext Reference clock is disabled in stop
        mov     #RANGE_SEL_|EREFS_|ERCLKEN_,MCGC2 ; HGO_|

        ; Loop until OSCINIT = 1 - indicates crystal selected by EREFS bit has been initalised
imcg1
        brclr   OSCINIT.,MCGSC,imcg1

        ; MCG Control Register 1 (MCGC1)
        ;  CLKSx    = 10    Select Ext reference clk as clock source 
        ;  RDIVx    = 111   Set to divide by 128 (i.e. 4MHz/128 = 31.25kHz - in range required by FLL)
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
        ;  RDIVx    = 010   Set to divide by 4 (i.e. 4MHz/4 = 1 MHz - in range required by FLL)
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
        ;  RDIV     = 010   Set to divide by 4 (i.e. 4MHz/4 = 1 MHz - in range required by PLL)
        ;  IREFS    = 0     Ext Ref clock selected
        ;  IRCLKEN  = 0     MCGIRCLK inactive
        ;  IREFSTEN = 0     Internal ref clock disabled in stop
        mov     #RDIV1_,MCGC1

        ; Loop until CLKST = 11 - PLL O/P selected to feed MCGOUT in current clk mode
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


