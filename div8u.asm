;***************************************************************************
;* "div8u"  - Divisione 8/8 Bit - senza segno
;*
;* La subroutine divide 2 numeri a 8 bit
;* - dd8u    (dividendo)  r16
;* - dv8u    (divisore)   r17 
;* Il risultato è posto in 
;* - dres8u  (quoziente)  r16
;* - drem8u  (resto)      r15
;*
;* dividendo: divisore = quoziente + resto
;*
;* "div16u" - Divisione 16/16 Bit - senza segno
;*
;* La subroutine divide 2 numeri a 16 bit
;* - "dd16uH:dd16uL"        (dividendo)  r17:r16
;* - "dv16uH:dv16uL"        (divisore)   r19:r18
;* Il risultato è posto in 
;* - "dres16uH:dres16uL"    (quoziente)  r17:r16
;* - "drem16uH:drem16uL"    (resto)      r15:r14
;*  
;***************************************************************************

;***** Registri usati per la funzione a 8 bit

.def	drem8u	=r15		;resto
.def	dres8u	=r16		;risultato
.def	dd8u	=r16		;dividendo
.def	dv8u	=r17		;divisore
.def	dcnt8u	=r18		;contatore



;***** Registri usati per la funzione a 16 bit

.def drem16uL=r14          ; resto
.def drem16uH=r15          ; resto
.def dres16uL=r16          ; risultato
.def dres16uH=r17          ; risultato
.def dd16uL =r16           ; dividendo          
.def dd16uH =r17           ; dividendo
.def dv16uL =r18           ; divisore
.def dv16uH =r19           ; divisore
.def dcnt16u =r20          ; contatore



;***** FUNZIONE A 8 BIT *************************
div8u:
    push    dcnt8u          ; salvo il dato in r18
	sub		drem8u,drem8u	; cancello resto ed il Flag di riporto
	ldi		dcnt8u,9		; inizializzo il contatore
d8u_1:	
	rol		dd8u			; shifto a sinistra il dividendo caricando il Flag Carry 
	                        ; da inserire poi nel registro del resto
	dec		dcnt8u			; decremento il contatore
	brne	d8u_2			; se ho finito e quindi dcnt8u è <> 0
	pop     dcnt8u          ; ripristino il dato in r18 
	ret						; ritorno
d8u_2:	
	rol		drem8u			; shifto a sinistra il resto con il flag Carry del dividendo
	sub		drem8u,dv8u		; verifico che il resto = resto - divisore
	brcc	d8u_3			; se ho un risultato negativo 
	add		drem8u,dv8u		; ripristino il resto 
	clc						; cancello il flag carry affinchè non vada nel risultato
	rjmp	d8u_1			; altrimenti
d8u_3:	
	sec						; imposto il flag carry perchè vada nel risultato
	rjmp	d8u_1




;***** FUNZIONE A 16 BIT ***********************************

div16u: 
    push dcnt16u            ; salvo il dato in r20
    clr drem16uL            ; cancello il byte Low del resto
    sub drem16uH,drem16uH   ; cancello resto High ed il Flag di riporto
    ldi dcnt16u,17          ; inizializzo il counter
d16u_1: 
    rol dd16uL              ; shifto a sinistra il dividendo caricando il Flag Carry 
	                        ; da inserire poi nel registro del resto
    rol dd16uH
    dec dcnt16u             ; decremento il contatore
    brne d16u_2             ; se ho finito e quindi dcnt18u è <> 0
	pop dcnt16u             ; ripristino il dato in r20
    ret                     ; ritorno
d16u_2: 
    rol drem16uL            ; shifto a sinistra il resto con il flag Carry del dividendo
    rol drem16uH
    sub drem16uL,dv16uL     ; verifico che il resto = resto - divisore 
    sbc drem16uH,dv16uH     ;
    brcc d16u_3             ; se ho un risultato negativo 
    add drem16uL,dv16uL     ; ripristino il resto 
    adc drem16uH,dv16uH
    clc                     ; cancello il flag carry affinchè non vada nel risultato
    rjmp d16u_1             ; altrimenti
d16u_3: 
    sec                     ; imposto il flag carry perchè vada nel risultato
    rjmp d16u_1

