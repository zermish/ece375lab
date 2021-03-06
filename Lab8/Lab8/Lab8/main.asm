.include "m128def.inc"				; Include definition file

;************************************************************
;* Variable and Constant Declarations
;************************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	cmd = r17				; Command register

.equ	RightBt = 0				
.equ	LeftBt = 1				
.equ	ForBt = 7
.equ	BackBt = 4
.equ	HaltBt = 5
.equ	FreezeBt = 6

;**************************************************************
;* Beginning of code segment
;**************************************************************
.cseg

;--------------------------------------------------------------
; Interrupt Vectors
;--------------------------------------------------------------
.org	$0000				; Reset and Power On Interrupt
		rjmp	INIT		; Jump to program initialization

.org	$0046				; End of Interrupt Vectors
;--------------------------------------------------------------
; Program Initialization
;--------------------------------------------------------------
INIT:
    ; Initialize the Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND

	; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

			    ; Initialize Port B for output
		ldi		mpr, $ff		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low		

	;USART1
		;Set baudrate at 2400bps, double data rate
		ldi		mpr, $01
		sts		UBRR1H, mpr
		ldi		mpr, $A0
		sts		UBRR1L, mpr

		ldi		mpr, (1<<TXC1|1<<U2X1) ;enable transfer
		sts		UcSR1A, mpr

		;Enable transfer and enable transfer interrupts
		ldi mpr, (1<<TXEN1)
		sts UCSR1B, mpr

		ldi		mpr, (1<<UPM10|1<<UPM11|1<<UCSZ11|1<<UCSZ10|USBS1) ;ensure settings match remote
		sts UCSR1C, mpr

		;Set frame format: 8 data bits, 2 stop bits

;---------------------------------------------------------------
; Main Program
;---------------------------------------------------------------
MAIN:
		clr		cmd
		clr		mpr
		in		mpr, PIND		; Get whisker input from Port D
		com		mpr
		andi	mpr, (1<<LeftBt|1<<RightBt|1<<ForBt|1<<BackBt|1<<HaltBt|1<<FreezeBt)
		cpi		mpr, (1<<LeftBt)
				out		PORTB, mpr

		brne	RIGHT			; Continue with next check
		rcall	SendLeft		
		rjmp	MAIN			; Continue with program

RIGHT:	cpi		mpr, (1<<RightBt)	
		brne	FORWARD			
		rcall	SendRight			
		rjmp	MAIN			; Continue through main

FORWARD:	cpi		mpr, (1<<ForBt)
		brne	BACKWARD			
		rcall	SendForward			
		rjmp	MAIN			; Continue through main

BACKWARD:	cpi		mpr, (1<<BackBt)	
		brne	HALT			
		rcall	SendBackward	
		rjmp	MAIN			; Continue through main

HALT:	cpi		mpr, (1<<HaltBt)
		brne	FREEZE			
		rcall	SendHalt		
		rjmp	MAIN			; Continue through main

FREEZE:	cpi		mpr, (1<<FreezeBt)
		brne	MAIN			
		rcall	SendFreeze		
		rjmp	MAIN			; Continue through main

;****************************************************************
;* Subroutines and Functions
;****************************************************************

;----------------------------------------------------------------
; Sub:	Send[CMD]
; each of these uses sendCmd and SendAddr to send the appropriate command
;----------------------------------------------------------------
SendLeft:
		rcall	SendAddr 
		ldi		cmd, 0b10010000
		rcall	SendCmd
		ret

SendRight:
		rcall	SendAddr
		; write out the right command to usart
		ldi cmd, 0b10100000
		rcall SendCmd
		ret

SendForward:
		rcall	SendAddr
		; write out the forward command to usart
		ldi cmd, 0b10110000
		rcall SendCmd
		ret

SendBackward:
		rcall	SendAddr
		; write out the backward command to usart
		ldi cmd, 0b10000000
		rcall SendCmd
		ret

SendHalt:
		rcall	SendAddr
		; write out the halt command to usart
		ldi cmd, 0b11001000
		rcall SendCmd
		ret

SendFreeze:
		rcall	SendAddr
		; write out the freeze command to usart
		ldi cmd, 0b11111000
		rcall SendCmd
		ret

SendAddr:
		push	mpr
		ldi cmd, 0b00110101
		rcall SendCmd
		pop		mpr
		ret 

SendCmd:
		push mpr ;save mpr
		lds mpr, UCSR1A ;ensure buffer is empty before writing
		ANDI mpr, (1<<UDRE1)
		CPI mpr,  (1<<UDRE1)
		BRNE SendCmd ;write the data to the remote
		sts UDR1, cmd
		pop mpr ;restore mpr
		ret