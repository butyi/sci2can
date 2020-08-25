; ===================== Sub-Routines ==========================================
#ROM

; ------------------------------------------------------------------------------
; Computer Operating Properly (COP) Watchdog
COP_Init
        ; System Options Register 2
        ; COPCLKS = 0 (1kHz)
        ; COPW = 0 (No COP Window)
        ; ADHTS = 0 (ADC Hardware Trigger from RTC overflow)
        ; MCSEL = 0 (MCLK output on PTA0 is disabled)
        ; -> So, no change needed for SOPT2
        
        ; System Options Register 1
        ; COPT = 01b (2^5 cycles, 1kHz) ~= 32ms
        ; STOPE = 0 (Stop mode disabled)
        ; SCI2PS = 0 (TxD2 on PTF0, RxD2 on PTF1.)
        ; IICPS = 0 (SCL on PTF2, SDA on PTF3)
        lda     #COPT0_|IICPS_
        sta     SOPT1
        rts
        
        ; Refresh Watchdog
KickCop
        psha                    ; Save A, because function will change it
        lda       #$55          ; First pattern $55
        sta       COP
        coma                    ; Second pattern $AA
        sta       COP
        pula                    ; Restore original content of A
        rts


