PROGRAM		EQU	$0000        
RAM             EQU      $00E4          

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
                
                LDAA    PORT_A, X
                ORAA    #%00001000      ; Set bit 3: VPROG_EN = 1
                STAA    PORT_A, X
                
                NOP                       
                JSR     BLANK_READ_SUBROUTINE  
                
; WRITING LOGIC START

                LDAA    PORT_A, X
                ORAA    #%00001000      ; Set bit 3: VPROG_EN = 1 
                STAA    PORT_A, X

                LDY     #PATTERN        
                JSR     DISABLE         ; Ensure EPROM is disabled (CE'=1, OE'=1, P'=1)
                JSR     LONG_DELAY      
                
                
                CLRA                   
                LDAB    #25             
                
WRITE           STAA    PORT_B, X       

                PSHA                    
                PSHB                    
                
                CLRA                  
                CLRB                    
                
RETRY           ; Check loop counter
                CMPB	#25             ; Compare retry counter with 25 (max retries)
                BEQ     END             
		INCB                   
                
               
                JSR     DATA_OUT   
                
               
                JSR     MS_DELAY        
                
                LDAA    PORT_A, X
                ANDA    #%10111111      ; Clear bit 6: P' = 1 (end programming pulse)
                ORAA    #%00110000      ; Set bits 5,4: CE'=0, OE'=1
                STAA    PORT_A, X       ; CE'=0 (chip enabled), OE'=1 (output disabled), P'=1
                
                JSR     MS_DELAY        
                

                JSR     DATA_IN         
                

                LDAA    PORT_C, X       
                SUBA    0, Y            
                BNE     RETRY          
                

                JSR     DATA_OUT        
                
LONG_PULSE      JSR     MS_DELAY3       
                DECB                    
                BNE     LONG_PULSE      
                
                JSR     DISABLE         ; Disable EPROM (CE'=1, OE'=1, P'=1)
                JSR     MS_DELAY        
                PULB                    
                PULA                    
                
                INY                     
                INCA                    
                DECB                    
                BNE     WRITE           ; Loop until all 25 bytes programmed
                
                

; WRITING LOGIC ENDS             
END             JSR     DISABLE        
                JSR     BLANK_READ_SUBROUTINE  
                JSR     DISABLE         
                
FIN             BRA     FIN             


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
                
                JSR     MS_DELAY       
                
                LDAA    PORT_A, X
                ANDA    #%10101111      ; Clear bit 4: OE' = 0 (enable output)
                STAA    PORT_A, X       ; CE'=0, OE'=0, P'=0
                
                RTS                     
                
DATA_IN         
                LDAA    #$00           
                STAA    DDRC, X         
                
                
                LDAA    PORT_A, X
                ANDA    #%10011111      ; Clear bits 5,4: CE'=0, OE'=0
                ORAA    #%00010000      ; Set bit 4: OE'=0
                STAA    PORT_A, X       ; CE'=0, OE'=0, P'=1 (from previous state)
                
                JSR     MS_DELAY        
                
                RTS                     
                

TRANSFER_DATA	BRCLR	SCSR,X #$80 TRANSFER_DATA  
		STAA	SCDR,X         
		RTS                     


DISABLE         ; DISABLE EPROM: CE' = 1, OE' = 1, P' = 1
                LDAA    PORT_A, X
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
                LDAB    #25             
                
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
                JSR     TRANSFER_DATA  
                
                JSR     MS_DELAY        ; Wait 1ms
                
                JSR     DISABLE         
                
                JSR     MS_DELAY        ; Wait 1ms before next read
                
                ; Loop termination logic
                PULA                    
                INCA                    
                DECB                    
                BNE     BLANK_READ      ; Loop until all 25 addresses read
                
                RTS                     