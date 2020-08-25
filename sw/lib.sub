; ===================== CONFIG =================================================

STRBUFFLEN      equ     8       ; Length of string manipulation buffer

; ====================  VARIABLES  =============================================
#RAM

str_bufidx      ds      1       ; Index of String manipulation buffer


arit32          ds      4       ; Variables for 32bit calculations
yy              ds      4
zz              ds      4
ww              ds      4

#XRAM

str_buffer      ds      STRBUFFLEN ; String manipulation buffer

; ===================== SUB-ROUTINES ===========================================
#ROM

; Convert value to decimal string
;   HA is dividend. Maximum value is 2559 !
;   X is length of fractional part. (0:no f.p., 1: 1 digit f.p., ...) 
;   Result is sting pointer in HX whoch can be printed immediately
; Example call: 
;       mov     #5,str_bufidx   ; Define length of string
;       ldhx    #2559           ; Value in A to be printed
;       txa                     ; Move X to A to be value in HA
;       ldx     #1              ; Define length of fractional part
;       jsr     str_val         ; String will be "255.9"
;       lda     #$27            ; Screen position
;       jsr     DISP_print      ; Print string
str_val
        pshh                    ; Save dividend high byte
        pshx                    ; Save length of fractional part
        psha                    ; Save dividend low byte
        lda     str_bufidx      ; Check string length
        cmp     #STRBUFFLEN     ; Compare with length of buffer 
        bhs     str_val_end     ; End if buffer is not enough long 
        clrh                    ; Clear H for indexing
        ldx     str_bufidx      ; Start from end of buffer
        clra                    ; Prepare terminator zero
        sta     str_buffer,x    ; Save string terminator zero
        lda     #' '            ; Space character into A
str_val_clrstr                  ; Loop to init the whole string with space
        sta     str_buffer-1,x  ; Init string with space
        dbnzx   str_val_clrstr  ; Repeat fill up till start of string
        lda     3,sp            ; Load dividend high byte
        psha
        pulh                    ; Move it to H

str_val_loop
        lda     1,sp            ; Load dividend low byte
        ldx     #10             ; Divider is 10 of course
        div                     ; Divide itself
        sta     1,sp            ; Save integer part
        pshh                    ; Transfer H (remainder) to A, step 1/2
        clrh                    ; Clear H for indexing
        pula                    ; Transfer H (remainder) to A, step 2/2
        add     #'0'            ; Convert to ASCII number
        dec     str_bufidx      ; Step back string pointer
        ldx     str_bufidx      ; Load string pointer for indexing
        sta     str_buffer,x    ; Put remainder into the string
        dec     2,sp            ; Decrease length of fractional part
        bne     str_val_np      ; When not zero, jump through its print
        lda     #'.'            ; Here when zero, print the point
        dec     str_bufidx      ; Step back string pointer
        ldx     str_bufidx      ; Load string pointer into X for indexing
        sta     str_buffer,x    ; Put the point into the string
str_val_np                      ; Target label when no point needed        
        tst     str_bufidx      ; Test string pointer
        beq     str_val_end     ; When it is zero, finished
        bra     str_val_loop    ; When integer part is not zero, continue
str_val_end                     ; Target label when string is prepared
        ais     #3              ; Drop out first three push
        clrh                    ; Start in string from left side character
        clrx                    ; Start in string from left side character
str_rn_loop                     ; Loop to change header '0' to ' '
        lda     str_buffer,x    ; Load character
        cmp     #'0'            ; Check if null
        bne     str_rn_end      ; If not null, it is 1..9, exit from loop
        lda     str_buffer+1,x  ; Load next character
        cmp     #'.'            ; Check if dot
        beq     str_rn_end      ; If dot, exit loop, '0' is needed before dot 
        lda     #' '            ; Prepare A to replace
        sta     str_buffer,x    ; Replace '0' to ' '
        incx                    ; Go to next character
        bra     str_rn_loop     ; Continue
str_rn_end                      ; Exit point of loop to change '0' to ' '
        ldhx    #str_buffer     ; Load buffer address
        rts                     ; Ready

; HX = HX + A
; Example call:
;       lda     #10
;       ldhx    #$3A8C
;       jsr     addhxanda
addhxanda
        psha                    ; Save A
        txa                     ; X (op1 lo)
        add     1,sp            ; + (op2 lo)
        tax                     ; Store to X (op1 lo)

        pshh                    ; H (op1 hi)
        pula                    ; ----||----
        adc     #0              ; Add carry
        psha                    ; Store to H (op1 hi)
        pulh                    ; ----||----            
        ais     #1              ; Drop out saved A from stack

        rts



; arit32[16] * yy[16] = arit32[32]
szor16bit
        clr     arit32    
        clr     arit32+1    
        ldx     #16
m_c                    
        clc            
        brclr   0,arit32+3,m_2
                       
        lda     arit32+1
        add     yy+3
        sta     arit32+1
        lda     arit32
        adc     yy+2
        sta     arit32
m_2                    
        ror     arit32    
        ror     arit32+1    
        ror     arit32+2    
        ror     arit32+3

        dbnzx   m_c


        rts


        

;Osztas
; arit32(32) / y(32) ==> arit32(32)
; arit32(msb)...arit32+3(lsb), y3...y0, z3...z0

;#macro divhx par16        // arit32 / par16 = HX
;        clr     yy
;        clr     yy+1
;        mov     par16,yy+2
;        mov     par16+1,yy+3
;        jsr     oszt32bit
;        ldhx    arit32+2
;#endm

; arit32[32] / yy[32] = arit32[32]
oszt32bit
        lda     yy+3      ;$00 0
        eor     #$FF      ;$FF 0
        add     #1        ;$00 1
        sta     yy+3      ;$00 1   !

        lda     yy+2      ;$03 1
        eor     #$FF      ;$FC 1
        adc     #0        ;$FD 0
        sta     yy+2      ;$FD 0   !

        lda     yy+1      ;$00 0
        eor     #$FF      ;$FF 0
        adc     #0        ;$FF 0
        sta     yy+1      ;$FF 0   !

        lda     yy        ;$00 0    
        eor     #$FF      ;$FF 0    
        adc     #0        ;$FF 0    
        sta     yy        ;$FF 0   !

        clr     zz+3
        clr     zz+2
        clr     zz+1      
        clr     zz
                         
        ldx     #33  

        clc
        bra     ud162    
                         
ud161             
                         
        lda     zz+3      
        add     yy+3      
        sta     ww+3       
        lda     zz+2      
        adc     yy+2      
        sta     ww+2       
        lda     zz+1      
        adc     yy+1      
        sta     ww+1       
        lda     zz      
        adc     yy
                         
        bcc     ud162    
                         
        sta     zz      
        mov     ww+1,zz+1   
        mov     ww+2,zz+2   
        mov     ww+3,zz+3   
                         
ud162             
        rol     arit32+3      ; C itt az elozo kivonas eredmenye!
        rol     arit32+2      
        rol     arit32+1      
        rol     arit32      
                         
        rol     zz+3      
        rol     zz+2      
        rol     zz+1      
        rol     zz      
                         
        dbnzx   ud161

        rts



