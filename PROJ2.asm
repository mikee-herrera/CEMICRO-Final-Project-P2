PROGRAM		EQU	$0000        
RAM             EQU     $00E4          

BASE		EQU	$1000         
PORT_A		EQU	$00            ; Port A (CE', OE', P', VPROG_EN)
PORT_B		EQU	$04            ; Port B
PORT_C		EQU	$03            ; Port C
DDRC		EQU	$07            

BAUD		EQU	$2B            
SCCR2		EQU	$2D           
SCSR		EQU	$2E            
SCDR		EQU	$2F            

MODE_S		EQU	$3C           
STACK		EQU	$00FF          

                ORG     RAM
PATTERN         DB      $48, $65, $6C, $6C, $6F, $20, $57, $6F, $72, $6C, $64, $64, $21, $21, $21, $21, $21, $21, $21, $00, $FE, $FE, $FE, $FE, $FE
                ; should print "Hello World!!!!!"

                ORG     PROGRAM

START           LDS     #STACK          

                LDX     #BASE         
                
                ; Serial Communication Setup
                LDAA    #$30           
                STAA    BAUD, X         
                
                LDAA    #$0C            
                STAA    SCCR2, X       
                                       
                JSR BLANK_READ_SUBROUTINE
                TSTB
                BNE  END        ; if not blank, END
  
                
; WRITING LOGIC START

                LDY     #PATTERN
                CLRA                   
                LDAB    #25             
                
         
WRITE           STAA    PORT_B, X   

                LDAA    PORT_A, X
                ORAA    #%00001000      ; Set bit 3: VPROG_EN = 1 
                STAA    PORT_A, X
                
                JSR     DISABLE
                JSR     MS_DELAY    

                PSHA                    
                PSHB                    
                
                CLRB                    
                
           ; Check loop counter
RETRY           CMPB	#25             ; Compare retry counter with 25 (max retries)
                BEQ     END             
		INCB                   
                
               
                JSR     DATA_OUT                  
                JSR     MS_DELAY        
                
                LDAA    PORT_A, X
                ANDA    #%10111111      ; Clear bit 6: P' = 1 (end programming pulse)
                ORAA    #%00110000      ; Set bits 5,4: CE'=0, OE'=1
                STAA    PORT_A, X       ; CE'=0 (chip enabled), OE'=1 (output disabled), P'=1
                JSR     MS_DELAY   
                
                LDAA    PORT_A, X
                ANDA    #%11110111      ; VPROG_EN = 0
                STAA    PORT_A, X
                     
                JSR     DATA_IN         
                LDAA    PORT_C, X       
                CMPA    0, Y            
                BNE     RETRY          
                
                JSR     MS_DELAY3
                JSR     MS_DELAY3
                JSR     MS_DELAY3

                PULB
                PULA
    
                INY
                INCA
                DECB
                BNE     WRITE        
                


; WRITING LOGIC ENDS             
END             JSR     DISABLE        
                JSR     BLANK_READ_SUBROUTINE  
                JSR     DISABLE  
                RTS                   


MS_DELAY        PSHX                   
                LDX     #$014B          
MS1             DEX                     
                BNE     MS1            
                
                PULX                    
                RTS                     
                

MS_DELAY3       PSHX                    
                LDX     #$03E6          
MS3             DEX                     
                BNE     MS3             
                
                PULX                    
                RTS                     
                
LONG_DELAY      LDAB    #$FF            
LD              JSR     MS_DELAY3       
                DECB                    
                BNE     LD              
                RTS                     
                
; 2764 Program Logic - DATA_OUT subroutine
DATA_OUT        ; Setup PORT C as output
                LDAA    #$FF           
                STAA    DDRC, X        
                
             
                LDAA    0, Y            
                STAA    PORT_C, X       
                
                ; PROGRAM control signals
                LDAA    PORT_A, X
                ANDA    #%10111111      ; Clear bit 6: P' = 0 (start programming pulse)
                ORAA    #%00110000      ; Set bits 5,4: CE'=0, OE'=1
                STAA    PORT_A, X       ; CE'=0 (chip enabled), OE'=1 (output disabled), P'=0
                
                RTS                     
                
DATA_IN         
                LDAA    #$00           
                STAA    DDRC, X         
                
                
                LDAA    PORT_A, X
                ANDA    #%10011111      ; Clear bits 5,4: CE'=0, OE'=0
                STAA    PORT_A, X       ; CE'=0, OE'=0, P'=1 (from previous state)
                
                JSR     MS_DELAY        
                
                RTS                     
                

TRANSFER_DATA	BRCLR	SCSR,X #$80 TRANSFER_DATA  
		STAA	SCDR,X         
		RTS                     


         ; DISABLE EPROM: CE' = 1, OE' = 1, P' = 1
DISABLE         LDAA    PORT_A, X
                ORAA    #%01110000      ; Set bits 6,5,4: P'=1, CE'=1, OE'=1
                STAA    PORT_A, X      
                RTS                 
                
                
BLANK_READ_SUBROUTINE

                LDAA    #$00            
                STAA    DDRC, X     
                

                LDAA    PORT_A, X
                ANDA    #%11110111    
                STAA    PORT_A, X

                JSR     DISABLE         
                JSR     LONG_DELAY      
                
                CLRA    
                LDAB    #0               
                LDY    #25             
                
BLANK_READ      STAA    PORT_B, X      
                PSHA                    
                

                LDAA    PORT_A, X
                ANDA    #%10111111      
                STAA    PORT_A, X       ; CE'=1, OE'=1, P'=1, VPROG_EN=0
                
                JSR     MS_DELAY        
                
                LDAA    PORT_A, X
                ANDA    #%10011111      ; Clear bits 5,4: CE'=0, OE'=0
                STAA    PORT_A, X       ; CE'=0 (chip enabled), OE'=0 (output enabled)
                
                JSR     MS_DELAY        
                
                ; Get data from the 2764
                LDAA    PORT_C, X  
                CMPA    #$00    ;checks first if byte is equal to FFh
                BEQ     BYTE_OK
                INCB
                     
BYTE_OK         JSR     TRANSFER_DATA  
                
                JSR     MS_DELAY        ; Wait 1ms
                
                JSR     DISABLE         
                
                JSR     MS_DELAY        ; Wait 1ms before next read
                
                ; Loop termination logic
                PULA                    
                INCA                    
                DEY                    
                BNE     BLANK_READ      ; Loop until all 25 addresses read
                
                RTS                     