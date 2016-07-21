; ============================================
; HD44780 LCD Assembly driver
; Available routines
; LCD_Init - initialization of LCD
; LCD_WriteCommand - write to command register
; LCD_WriteData - write to data register
; LCD_WriteString - display string from program memory
; LCD_SetAddress - sets address in Display Data RAM
; ============================================

;*********************************************
; Definizione delle costanti usate per LCD
; si utilizza la PortD i cui piedini sono indicati sotto

.include "hd44780.inc"           ; definizione di tutte le costanti di comando per LCD

.equ	LCD_PORT 	= PORTD
.equ	LCD_DDR		= DDRD
.equ    LCD_PIN		= PIND

.equ	LCD_D4 		= 0
.equ	LCD_D5 		= 1
.equ 	LCD_D6 		= 2
.equ	LCD_D7 		= 3

.equ	LCD_RS		= 7
.equ	LCD_EN		= 6


;------------------------------------------------------------------------------
;    SI INIZIALIZZA LCD CON LA RISPETTIVA PIEDINATURA
;    SI ESEGUE ANCHE UN RITARDO PERCHE' LA CPU DELL'LCD NON
;    E' VELOCE QUANTO QUELLA DEL MICROPROCESSORE
;------------------------------------------------------------------------------

Init_LCD:
	push r16
	push r17
	
	sbi		LCD_DDR, LCD_D4
	sbi		LCD_DDR, LCD_D5
	sbi		LCD_DDR, LCD_D6
	sbi		LCD_DDR, LCD_D7
	
	sbi		LCD_DDR, LCD_RS
	sbi		LCD_DDR, LCD_EN

	cbi		LCD_PORT, LCD_RS
	cbi		LCD_PORT, LCD_EN

	ldi		r16, 20
	rcall	WaitMilliseconds      ;; carico 20 millisecondi da aspettare per fase handshaking

	ldi		r17, 3
InitLoop:
	ldi		r16, 0x03
	rcall	LCD_WriteNibble       ; carico 2 millisecondo per inizializzare LCD
	ldi		r16, 2
	rcall	WaitMilliseconds
	dec		r17
	brne	InitLoop

	ldi		r16, 0x02
	rcall	LCD_WriteNibble

	ldi		r16, 1
	rcall	WaitMilliseconds

	ldi		r16, HD44780_FUNCTION_SET | HD44780_FONT5x7 | HD44780_TWO_LINE | HD44780_4_BIT
	rcall	LCD_WriteCommand

	ldi		r16, HD44780_DISPLAY_ONOFF | HD44780_DISPLAY_OFF
	rcall	LCD_WriteCommand

	ldi		r16, HD44780_CLEAR
	rcall	LCD_WriteCommand

	ldi		r16, HD44780_ENTRY_MODE |HD44780_EM_SHIFT_CURSOR | HD44780_EM_INCREMENT
	rcall	LCD_WriteCommand

	ldi		r16, HD44780_DISPLAY_ONOFF | HD44780_DISPLAY_ON | HD44780_CURSOR_OFF | HD44780_CURSOR_NOBLINK
	rcall	LCD_WriteCommand
    
	pop r17
	pop r16
ret



;------------------------------------------------------------------------------
;   Manda 1 nibble di dati a LCD. I dati sono passati mediante il registro r16
;------------------------------------------------------------------------------

LCD_WriteNibble:
	sbi		LCD_PORT, LCD_EN   

	sbrs	r16, 0                ; Salta istruzione successiva se il bit nel registro è 1
	cbi		LCD_PORT, LCD_D4
	sbrc	r16, 0                ; Salta istruzione successiva se il bit nel registro è 0
	sbi		LCD_PORT, LCD_D4
	
	sbrs	r16, 1
	cbi		LCD_PORT, LCD_D5
	sbrc	r16, 1
	sbi		LCD_PORT, LCD_D5
	
	sbrs	r16, 2
	cbi		LCD_PORT, LCD_D6
	sbrc	r16, 2
	sbi		LCD_PORT, LCD_D6
	
	sbrs	r16, 3
	cbi		LCD_PORT, LCD_D7
	sbrc	r16, 3
	sbi		LCD_PORT, LCD_D7

	cbi		LCD_PORT, LCD_EN
ret


;------------------------------------------------------------------------------
;   La funzione invia il comando di scrivire i dati presenti in r16
;------------------------------------------------------------------------------
LCD_WriteData:
	sbi		LCD_PORT, LCD_RS
	push	r16
	swap	r16
	rcall	LCD_WriteNibble
	pop		r16
	rcall	LCD_WriteNibble

	clr		XH
	ldi		XL,250                ; aspetta 250 microsecondi
	rcall	Wait4xCycles
ret


;------------------------------------------------------------------------------
;   Manda il comando caricato in r16 al LCD
;------------------------------------------------------------------------------
LCD_WriteCommand:
	cbi		LCD_PORT, LCD_RS
	push	r16
	swap	r16
	rcall	LCD_WriteNibble
	pop		r16
	rcall	LCD_WriteNibble
	ldi		r16,2
	rcall	WaitMilliseconds
ret


;------------------------------------------------------------------------------
;   Scrive un'intera stringa terminata con 0. Nel registro a 16 bit Z vi è
;   l'indirizzo della stringa da scrivere   
;------------------------------------------------------------------------------
LCD_WriteString:
	lpm		r16, Z+
	cpi		r16, 0
	breq	exit
	rcall	LCD_WriteData
	rjmp	LCD_WriteString
exit:
ret



;------------------------------------------------------------------------------
;   Conversione dei caratteri da Hex a Decimali
;   In input ho il dato da convertire in r16 che quindi non viene salvato
;------------------------------------------------------------------------------
LCD_WriteDecimal:
    push    r14
	push    r17
	push    r15

	clr		r14                    ; conta le cifre convertite da 1 a 3 (registro 8 bit->255)
LCD_WriteDecimalLoop:
	ldi		r17,10                 ; base di conversione decimale
	rcall	div8u                  ; funzione di divisione
	inc		r14                    ; incremento il contatore di cifre
	push	r15                    ; salva il resto della divisione (guarda la funz div8u)
	cpi		r16,0 
	brne	LCD_WriteDecimalLoop	

LCD_WriteDecimalLoop2:
	ldi		r17,'0'                ; inserisco il riferimento base dello 0 dal set di caratteri
	pop		r16                    
	add		r16,r17                ; aggiunge al resto il riferimento
	rcall	LCD_WriteData
	dec		r14
	brne	LCD_WriteDecimalLoop2
    
	pop r15
	pop r17
	pop r14    
ret



;------------------------------------------------------------------------------
;   Comanda la possibilità di scrivere in un qualsiasi posto sull'LCD di
;   cordinate x,y. 
;   Per la prima riga la x = 0 mentre per la seconda è = a 40.
;   La y puo' variare fino a 16 (x un LCD 2x16)
;------------------------------------------------------------------------------
LCD_SetAddress:
	ori		r16, HD44780_DDRAM_SET
	rcall	LCD_WriteCommand
ret




;***********************************************************************************
;* Funzioni di utlità che mi permettono di ritardare l'esecuzione del comando
;* Per una frequenza di CPU = 4MHz ho che per ogni ciclo impiego 0.25 microsecondi
;* La funzione ha:
;* - in XH:XL   ho il numero di microsecondi da aspettare prima
;*              di avviare il comando successivo  si noti che ho 2 istruzioni che mi 
;*              fanno perdere già 1 microsecondo perchè ci mettono 2 colpi di clock
;***********************************************************************************
Wait4xCycles:
	sbiw	XH:XL, 1		; x-- (2 cicli)
	brne	Wait4xCycles	; salta se non è zero (2 cicli)
ret

;------------------------------------------------------------------------------
; Input : r16 - numbero di milliseconds da aspettare
;------------------------------------------------------------------------------
WaitMilliseconds:
	push	r16
WaitMsLoop:	
	ldi		XH,HIGH(1000)
	ldi		XL,LOW(1000)
	rcall	Wait4xCycles
	dec		r16
	brne	WaitMsLoop
	pop		r16
ret

