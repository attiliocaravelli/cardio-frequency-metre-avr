; ********************************************
; * [Progetto Dispositi Impiantabili]        *
; * [Cardio Frequenzimetro]                  *
; ********************************************
;
; ============================================
;      H E A D E R     F I L E S
; ============================================

.NOLIST
.INCLUDE "m8def.inc" ; Header for Atmega8
.LIST

; ==============================================
;   D E F I N I Z I O N E     R E G I S T R I
; ==============================================

.def minimo_bpm       = r9
.def max_bpm          = r10
.def indice_avr_array = r19
.def battiti_secondo  = r20
.def battiti          = r0
.def timer_minuti     = r1
; ============================================
; HD44780 LCD Assembly driver
; Available routines
; LCD_Init - initialization of LCD
; LCD_WriteCommand - write to command register
; LCD_WriteData - write to data register
; LCD_WriteString - display string from program memory
; LCD_SetAddress - sets address in Display Data RAM
; ============================================

; ============================================
;     S R A M    S E G M E N T
; ============================================
.DSEG
.org 0x0060

average:   ; dati che mi servono per costruire la media
.byte 11


; ============================================
;     E E P R O M   S E G M E N T
; ============================================
.eseg
.org 0x0000

last_bpm:
.BYTE 1    ; riservo il byte per poter salvare il battito voluto

; ============================================
;     C O D E      S E G M E N T
; ============================================

.CSEG                      
.org 0x0000

; ============================================
;     I N T E R R U P T   S E R V I C E S
; ============================================

	rjmp ProgramEntryPoint ; Reset
	reti ; Int0
	reti ; Int1
	reti ; TC2 Comp
    reti ; TC2 Ovf
	rjmp count_Pulse ; TC1 Capt
	reti ; TC1 Comp A
	reti ; TC1 Comp B
	rjmp every_Second ; TC1 Ovf
	reti ; TC0 Ovf
	reti ; SPI STC
	reti ; USART RX
	reti ; USART UDRE
	reti ; USART TXC
	reti ; ADC Conv Compl
	reti ; EERDY
	reti ; ANA_COMP
	reti ; TWI
	reti ; SPM_RDY


; ============================================
;     S T R I N G 
; ============================================
Blank: .db "   ",0
Save: .db "Saved",0
Min: .db "m",0
Max: .db "M",0
Media: .db "ME",0,0
Last: .db "L",0
Bpm: .db "Bpm:",0,0
Secondi: .db "Sec:",0,0

; ============================================
;     I N C L U D E     F I L E S
; ============================================
.include "div8u.asm"    ; file che contiene tutte le operazioni matematiche
.include "hd44780.asm"  ; file driver per lo schermo LCD
;
; ============================================
;     M A I N    P R O G R A M    I N I T
; ============================================
;

ProgramEntryPoint:
     
	; configuro lo stack    
	ldi r16,high(RAMEND); Main program start
    out SPH,r16 ; Set Stack Pointer to top of RAM
    ldi r16,low(RAMEND)
    out SPL,r16
    
	; inizializziamo la memoria Sram azzerando l'array di dati
	rcall init_Sram

	; inizializzo LCD
  	rcall init_LCD

	; inizializzo tutte le porte per la pressione dei bottoni
    rcall init_My_Port
   
   	; mi serve per contare 1 secondo
	; contanto poi il numero di cicli in questa finestra temporale
	; con modalità rising edge input capture
	rcall init_window_Pulse_Counter_Interrupt
    
	; inizializzo la maschera LCD
	rcall init_LCD_mask
    
    ; recupero il data precedentemente salvato dei battiti
 	ldi		r16,53                  
	rcall	LCD_SetAddress     ; go to 13,1
	rcall   EEPROM_read        ; dato letto dalla EEPROM e restituito in battiti
	mov     r16, battiti
    rcall	LCD_WriteDecimal   ; conversione e scrittura su LCD

    
	; azzero tutti i contatori e tutti i registri che andrò ad utilizzare
	clr battiti
	clr battiti_secondo        
    clr minimo_bpm      
    clr max_bpm          
   	clr indice_avr_array     ; azzero il contatore array per la media
    clr timer_minuti

    sei
loop:	
 	; verifico che non vi sia un tasto premuto
	rcall is_Key_Pressed
 ; non faccio nulla
rjmp loop






;---------------------------------------------------------------------------------
;   Funzione Calcola BPM calcola i battiti per minuto
;---------------------------------------------------------------------------------
calcola_BPM:
   
    ; in registro battiti ho i battiti al secondo
    ; moltiplico questo dato semplicemente per 60

	mov battiti, battiti_secondo    ; ho ottenuto i battiti medi per secondo
	                                ; tanto so che i battiti non saranno superiori a 240

ret






;---------------------------------------------------------------------------------
;   Funzione STORE BPM memorizza il dato acquisito sulla SRAM
;---------------------------------------------------------------------------------

store_BPM:
       
    ldi YL, low(average)       ; calcolo la base dell'array
    ldi YH, high(average)
   
	add YL, indice_avr_array     ; indicizzo sul byte corretto

    st Y, battiti                ; memorizzo il dato 

ret




;---------------------------------------------------------------------------------
;   Funzione index_array_Manager gestisce l'indice dell'array in SRAM
;   e se raggiunge 10 lo resetta
;---------------------------------------------------------------------------------
index_array_Manager:
 
	; incremento ed eseguo il check per vedere se l'indice è superiore a 10 
	; (nel qualcaso lo azzero)
    tst battiti                    ; se il dato è diverso da zero lo memorizzo
	                               ; altrimenti vado in uscita senza far nulla
    breq   exit_index_Manager

	inc indice_avr_array
    
	cpi  indice_avr_array, 10
    brlo exit_index_Manager       ; se indice avr array è inferiore a 10 esco senza far
	                              ; nulla altrimenti azzero il contatore
    clr indice_avr_array
exit_index_Manager:
    
ret




;---------------------------------------------------------------------------------
;   Funzione Visualizza BPM per visualizzare su LCD i battiti per minuto
;---------------------------------------------------------------------------------
visualizza_BPM:

	ldi		r16,44                   
	rcall	LCD_SetAddress     ; coordinate 4,1
    
	ldi		ZL,LOW(Blank << 1)     ;
	ldi		ZH,HIGH(Blank << 1)    ;  3 spazi bianchi
	rcall	LCD_WriteString  
    
	ldi		r16,44                   
	rcall	LCD_SetAddress     ; coordinate 4,1
 
 	mov		r16,battiti             ; visualizza i battiti per minuto
	rcall	LCD_WriteDecimal     

ret



;---------------------------------------------------------------------------------
;   Funzione UPDATE Min aggiorna il valore del minimo rilevato su LCD
;---------------------------------------------------------------------------------

update_Min:
    
	push r16
	
    tst  minimo_bpm      
	breq aggiorna_Min       ; se il registro è 0 significa che siamo in inizializzazione
		
	cp battiti, minimo_bpm  ; dato che non siamo all'inizio allora confrontiamo per
	                        ; vedere se sono da aggiornare dei dati
                            ; se i battiti rilevati sono superiori al minimo precedentemente
							; rilevato non devo fare nulla e quindi vado all'uscita
	brsh uscita_Update_Min    

aggiorna_Min:
    mov     minimo_bpm, battiti   

	ldi		r16,9              ; coordinata di base per visualizzare il dato Min bpm
	rcall	LCD_SetAddress     ; go to 9,0 
 
 	ldi		ZL,LOW(Blank << 1)     ;
	ldi		ZH,HIGH(Blank << 1)    ;  3 spazi bianchi
	rcall	LCD_WriteString  

	ldi		r16,9              ; coordinata di base per visualizzare il dato Min bpm
	rcall	LCD_SetAddress     ; go to 9,0 

 	mov		r16,battiti            ;
	rcall	LCD_WriteDecimal    

uscita_Update_Min:
	pop r16
ret





;---------------------------------------------------------------------------------
;   Funzione UPDATE Max aggiorna il valore del max rilevato su LCD
;---------------------------------------------------------------------------------


update_Max:
    
	push r16
	
    tst  max_bpm      
	breq aggiorna_Max         ; se il registro è 0 significa che siamo in inizializzazione
		
	cp battiti, max_bpm     ; dato che non siamo all'inizio allora confrontiamo per
	                        ; vedere se sono da aggiornare dei dati
                            ; se i battiti rilevati sono inferiori al max precedentemente
							; rilevato non devo fare nulla e quindi vado all'uscita
	brlo uscita_Update_Max    

aggiorna_Max:
    mov     max_bpm, battiti
   
 	ldi		r16,13              ; coordinata di base per visualizzare il dato Max bpm
	rcall	LCD_SetAddress     ; go to 13,0 
 

 	ldi		ZL,LOW(Blank << 1)     ;
	ldi		ZH,HIGH(Blank << 1)    ;  3 spazi bianchi
	rcall	LCD_WriteString  
    
	ldi		r16,13              ; coordinata di base per visualizzare il dato Max bpm
	rcall	LCD_SetAddress     ; go to 13,0 
 
 	mov		r16,battiti            ;
	rcall	LCD_WriteDecimal    

uscita_Update_Max:
	pop r16
ret








;---------------------------------------------------------------------------------
;   Funzione Init Sram che serve per azzera la memoria
;---------------------------------------------------------------------------------
init_Sram:
    clr r1

	; inizializzo l'array che contiene gli ultimi 10 dati per poi fare la media
	ldi indice_avr_array, 11

   	ldi YL, low(average)
    ldi YH, high(average)

loop_init_Sram:
    st Y+, r1
	dec indice_avr_array
brne loop_init_Sram
   
ret



; ============================================
;     INIT LCD MASK
;     Creo la maschera su LCD statica
; ============================================
;
;******************************************************
;  0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|
;0 S|E|C|:|X|X|X| |m|X|X |X	|M |X |X |X |
;1 B|P|M|:|X|X|X|S|A|V|E |D |L |X |X |X |
;1  | | | | | | |M|E|X|X |X |L |X |X |X |
;
;SEC: sono i secondi trascorsi dall'ultima rilevazione
;m è il minimo battito registrato
;M è il max battito registrato
;L è il dato salvato in EEPROM
;ME è la media degli ultimi 10 campioni raccolti
;BPM: sono i battiti per minuto
;Saved si ha quando il dato è salvato in EEPROM
;*******************************************************
init_LCD_mask:
;-------------------- Secondi ------------------------------    
	ldi		r16,0                       ; go to 0,0
	rcall	LCD_SetAddress            ;

	ldi		ZL,LOW(Secondi << 1)     ;
	ldi		ZH,HIGH(Secondi << 1)    ;  "Sec:"
	rcall	LCD_WriteString  


;--------------------- Minimo ---------------------------
	ldi		r16,8                       ; go to 8,0
	rcall	LCD_SetAddress            ;

	ldi		ZL,LOW(Min << 1)     ;
	ldi		ZH,HIGH(Min << 1)    ;  "m"
	rcall	LCD_WriteString  


;--------------------- Max ------------------------------
    ldi		r16,12                       ; go to 12,0
	rcall	LCD_SetAddress            ;

	ldi		ZL,LOW(Max << 1)     ;
	ldi		ZH,HIGH(Max << 1)    ;  "M"
	rcall	LCD_WriteString  

;-------------------- Bpm ------------------------------    
	ldi		r16,40                       ; go to 0,1
	rcall	LCD_SetAddress            ;

	ldi		ZL,LOW(Bpm << 1)     ;
	ldi		ZH,HIGH(Bpm << 1)    ;  "Bpm:"
	rcall	LCD_WriteString  



;--------------------- Dato salvato EEPROM ---------------
	ldi		r16,52                       ; go to 12,1
	rcall	LCD_SetAddress            ;

	ldi		ZL,LOW(Last << 1)     ;
	ldi		ZH,HIGH(Last << 1)    ; "L"
	rcall	LCD_WriteString  

        

ret
;==========================================================


; ============================================
;     INIT INTERRUPT
; ============================================
;
;***********************************************************************
; la funzione  mi serve per gestire in Input Mode il contatore
; degli impulsi (rising/falling edge) e
; mi serve per contare 1 secondo
; ottenendo gli impulsi captati nell'unità di tempo e quindi la frequenza
init_window_Pulse_Counter_Interrupt:
   push r16
    
; uso un prescaler di 1024 quindi 4.000.000 Hz / 64 = 62500
; Hex(3906) = F42 ma il contatore conta in avanti quindi
; devo inizializzare il contatore non da 0 ma da 0x000 - 0xF424 = 0BDC
; quindi non riesco a temporizzare 1 secondo se non con i contatori
; a 16 bit
	ldi r16, high(0x0BDC)
    out TCNT1H, r16
    ldi r16, low(0x0BDC)
    out TCNT1L, r16
 
; configuro il prescaler a 64
; abilito input capture edge sul rising ICES1 -> 1
; abilito il noise canceler ICNC1 -> 1
    ldi r16, (1 << CS11) | (1 << CS10) 
    out TCCR1B, r16
     
 	
; abilito l'interrupt di Overflow del contatore nel qual caso
; si richiamerà la funzione every_Second nella quale
; si procederà a vedere gli impulsi contati da Counter0, visualizzarli
; e verificare il max e min e soprattutto azzera il contatore Counter0 per
; ricominciare a contare da capo

; abilito l'interrupt su CAPTURE INPUT gestito dalla relativa routine
; che incrementerà il contatore di inpulsi ricevuti
    
	ldi r16, (1 << TOIE1)
    out TIMSK, r16

   pop r16
ret




; ============================================
;     INIT PORT
;
;     INIZIALIZZA LE PORTE D4 COME INPUT PER 
;     POTER RILEVARE IL BATTITO
;     CONFIGURATO COME INPUT CLOCK PER IL 
;     COUNTER 0.
;
;     DICHIARO LE PORTE B0 E B1 COME INPUT
;     PER LA PRESSIONE DEI TASTI
; ============================================
;

init_My_Port:

;   dichiaro la porta B0 come input per il CAPTURE INPUT 
	cbi DDRB, 0
	sbi PORTB, 0

;   dichiaro la porta B1 come input per salvataggio EEPROM
	cbi DDRB, 1
	sbi PORTB, 1

;   dichiaro la porta B2 come input per calcolo Media
	cbi DDRB, 2
	sbi PORTB, 2

ret



; ============================================
;     IS KEY PRESSED
;     Funzione che gestisce l'eventuale pressione
;     di un bottone
; ============================================
;

is_Key_Pressed:

;------attivazione salvataggio EEProm -----------------
	sbis PINB, 1
    rcall key_save_pressed

    ;------attivazione calcolo media -----------------
	sbis PINB, 2
    rcall key_avr_pressed
    
ret


; ============================================
;     KEY SAVE PRESSED
;     GESTISCE IL SALVATAGGIO IN EEPROM DEL BATTITO
; ============================================
;


key_save_pressed:
    push r16

 	ldi		r16,47                  
	rcall	LCD_SetAddress     ; go to 7,1
    
 	rcall   EEPROM_write   
	 
	ldi		ZL,LOW(Save << 1)     ;
	ldi		ZH,HIGH(Save << 1)    ; visualizza "Saved"
	rcall	LCD_WriteString  
    
    ; visualizzo il nuovo dato salvato
 	ldi		r16,53                  
	rcall	LCD_SetAddress     ; go to 13,1
	
  	ldi		ZL,LOW(Blank << 1)     ;
	ldi		ZH,HIGH(Blank << 1)    ;  3 spazi bianchi
	rcall	LCD_WriteString  

	ldi		r16,53                  
	rcall	LCD_SetAddress     ; go to 13,1

	mov     r16, battiti       
    rcall	LCD_WriteDecimal   ; conversione e scrittura su LCD
    

	pop r16    
ret




; ============================================
;    KEY AVR PRESSED 
;    GESTISCE LA PRESSIONE DEL TASTO AVR PER 
;    IL CALCOLO DELLA MEDIA
; ============================================
;

key_avr_pressed:

; carico la base dell'array di dati
; inizio il ciclo per sommare i dati
; incremento il contatore di disione
; se un dato è zero mi fermo
; non posso utilizzare l'indice modulo 10 visto che
; potrebbe essere stato azzerato
; faccio la divisione a 16 bit
; La subroutine prevede:
; - "dd16uH:dd16uL"        (dividendo)  r17:r16
; - "dv16uH:dv16uL"        (divisore)   r19:r18
; Il risultato è posto in 
; - "dres16uH:dres16uL"    (quoziente)  r17:r16
; - "drem16uH:drem16uL"    (resto)      r15:r14
;
; visualizzo il dato quoziente della divisione

; utilizzo il registro r15 come registro temporaneo per 
; caricare il dato precedentemente memorizzato
    push r13   ; mi serve come contatore di indice array
	push r14   ; il registro che andrò poi a sommare avrà forma r15:r14 
    push r15   ; salvo tutti i registri 
	push r16
	push r17
	push r18
	push r19   ; ricordo che questo registro l'ho fissato come index dell'array

    ldi YL, low(average)       ; calcolo la base dell'array
    ldi YH, high(average)
    

	ldi		r16,47                       ; go to 7,1
	rcall	LCD_SetAddress            ;

	ldi		ZL,LOW(Media << 1)     ;
	ldi		ZH,HIGH(Media << 1)    ; display text "ME"
	rcall	LCD_WriteString  
    
	ldi		r16,49              ; coordinata di base per visualizzare la media
	rcall	LCD_SetAddress     ; go to 9,1 
 
 	ldi		ZL,LOW(Blank << 1)     ;
	ldi		ZH,HIGH(Blank << 1)    ;  3 spazi bianchi
	rcall	LCD_WriteString  
    
	; azzero tutto
	clr r13
	clr r16
	clr r17
	clr r18
	clr r19

	; azzero high byte del mio registro per fare la somma a 16 bit
	clr r15
	 
somma:            ; costruisco il dividendo
	ld  r14,Y+    ; carico il dato in r15 ed incremento
 
   	tst  r14       ; se il dato è 0 significa che abbiamo
	               ; raggiunto la fine dell'array
    breq divisione
    inc r13
	

	add r16,r14   ; aggiungo il dato in r16
	adc r17,r15   ; aggiungo il riporto
		
rjmp somma   

divisione:
    
	tst r13
	breq uscita_Senza_Divisione         ; se il contatore r13 è = 0 significa che mi sono 
	              ; fermato al primo elemento dell'array ovvero non ci sono
				  ; ancora dati memorizzati e quindi devo uscire
    ldi r19, 0
	mov r18, r13  ; costruisco il divisore
  
	rcall div16u  ; ottengo il risulato a 16 bit sui registri r17:r16
    
	push r16
	push r17   ; salvo il quoziente della divisione
	; vado sulla posizione 6,1 per poi alla fine scrivere direttamente la media
    ldi		r16, 49                  
	rcall	LCD_SetAddress     ; go to 9,1
    
	pop r17
	pop r16    ; ripristino il quoziente per lanciare la procedura di visualizzazione
 
 	rcall	LCD_WriteDecimal     
 
uscita_Senza_Divisione:

    pop r19   ; ricordo che questo registro l'ho fissato come index dell'array
	pop r18
	pop r17
	pop r16
	pop r15
	pop r14   
    pop r13
ret


; ============================================
;     E E P R O M     S A V E
;     il valore da salvare è in registro battiti
; ============================================
;

EEPROM_write:
    push    r18
	push    r17

    ldi     r18, high(last_bpm)
	ldi     r17, low(last_bpm)

EEPROM_write_loop:
    ; Aspetta il completamente di operazioni precedenti di scrittura
    sbic EECR,EEWE
rjmp EEPROM_write_loop

    ; Inizializzo l'indirizzo (r18:r17)
    out EEARH, r18
    out EEARL, r17

    ; Scrivo il dato (battiti) 
    out EEDR,battiti

    ; Setto a livello logico 1 -> EEMWE
    sbi EECR,EEMWE

    ; Avvio la scrittura impostando ad 1 EEWE
    sbi EECR,EEWE
    
	pop   r17
	pop   r18
ret



; ============================================
;     E E P R O M     R E A D
;     valore letto è in registro battiti
; ============================================
;


EEPROM_read:
    push    r18
	push    r17

    ldi     r18, high(last_bpm)
	ldi     r17, low(last_bpm)

EEPROM_read_loop:
    ; Aspetto il completamento di eventuali scritture precedenti
    sbic EECR,EEWE
rjmp EEPROM_read_loop

    ; Set up dell'indirizzo (r18:r17) 
    out EEARH, r18
    out EEARL, r17

    ; Avvio la lettura impostando ad 1 EERE
    sbi EECR,EERE

    ; Leggo il dato
    in battiti,EEDR
    
	pop   r17
	pop   r18
ret


; ============================================
;      I N T 0    M O D E 
; ============================================
; conta i battiti al secondo
; bisogna però sincronizzare l'impulso
; incrementando il contatore solo 
; e soltanto quando sento all'interno del secondo
; sia il falling che il rising edge
; per fare questo cambio il bit ICES1 passandolo
; da 1 (rising) a 0 e se è zeo incremento
count_Pulse:

	in r5,SREG ; 1, save SREG
    
	cli
	; non disabilito gli interrupt perchè potrebbe passare 1 secondo nel
	; frattempo
    
    push r16
    
	in r16, TCCR1B

	sbrs r16, ICES1       ; l'istruzione successiva sarà eseguita solo se il bit
	                      ; ICES1 non è settato ad 1 che sta ad indicare che siamo
						  ; in falling edge pertanto dobbiamo incrementare il nostro
						  ; contatore e cambiare la modalità su rising edge
    rjmp cambia_Modalita
    
	rjmp incrementa_Contatore

cambia_Modalita:    
	;falling edge
    ldi r16, (1 << CS11) | (1 << CS10) | (0 << ICES1) | (1 << ICNC1)
    out TCCR1B, r16
    
	rjmp esci_Senza_Fare_Altro

incrementa_Contatore:
    
    inc battiti_secondo

 	; rising edge ripristinato
    ldi r16, (1 << CS11) | (1 << CS10) | (1 << ICES1) | (1 << ICNC1)
    out TCCR1B, r16


esci_Senza_Fare_Altro:

   

    pop r16

	out SREG,r5

reti 



;---------------------------------------------------------------------------------
;   Funzione WAIT_ONE_SECOND Aspetta un secondo per contare i battiti
;---------------------------------------------------------------------------------
every_Second:

	cli
    
	push r16

	; visualizzo i secondi trascorsi
	ldi		r16,4
	rcall	LCD_SetAddress     ; coordinate 4,0
    
	ldi		ZL,LOW(Blank << 1)     ;
	ldi		ZH,HIGH(Blank << 1)    ;  3 spazi bianchi
	rcall	LCD_WriteString  

 
	ldi		r16, 4                  
	rcall	LCD_SetAddress     ; go to 4,0
    mov     r16, timer_minuti
	rcall	LCD_WriteDecimal     
    
    inc timer_minuti

    ldi   r16, 60
    cp    timer_minuti, r16          ; confronto il contatore con 60 
    brlo  uscita_Senza_Fare_Nulla  ; se il contatore è inf ai 60s non devo fare nulla
                                   ; altrimenti calcolo e visualizzo BPM
    rcall calcola_BPM

	rcall store_BPM	
	
	rcall index_array_Manager

	rcall visualizza_BPM

	rcall update_Min

	rcall update_Max
    
 	clr battiti_secondo   ; azzero i battiti per secondo
	                      ; azzero il contatore
	clr timer_minuti


uscita_Senza_Fare_Nulla:	
 
  	; rising edge ripristinato
    ldi r16, (1 << CS11) | (1 << CS10) | (1 << ICES1) | (1 << ICNC1)
    out TCCR1B, r16

    ldi r16, (1 << TOIE1) | ( 1<< TICIE1)
    out TIMSK, r16
  
	; ricarica il timer per generare un'interruzione ogni secondo
	ldi r16, high(0x0BDC)
    out TCNT1H, r16
    ldi r16, low(0x0BDC)
    out TCNT1L, r16
  
   
	pop r16
    
	sei
reti
