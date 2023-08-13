
.equ	ADDR_INPUT_PORT, 0xF000
.equ	ADDR_OUTPUT_PORT, 0xE000

.section .startup
	; sec  o com c digo de arranque
	b		_start	
	b 		.	    
_start:
	ldr		sp, addr_stack_top
	mov		r0, pc
	add		lr, r0, #4
	ldr		pc, addr_main
	b		.
addr_main:
	.word main
addr_stack_top:
	.word stack_top

	.text
	; sec  o com c digo aplicacional
main:
	bl inport_read
    lsl r1, r0, #15
    bzs main     
    lsl r0, r0, #8
    asr r0, r0, #8
    bl outport_write
    b main

	
/* -------------------------------------------------------
 * Implementa  o de API para portos paralelos 
 * -----------------------------------------------------*/
/* Devolve o valor atual do estado dos bits do porto de entrada. */
; uint8_t inport_read ();
inport_read:
	ldr	r1, inport_addr
	ldrb r0, [r1, #0]
	mov	pc, lr

inport_addr:
	.word ADDR_INPUT_PORT

/* Faz a inicia  o do porto, atribuindo o valor value aos seus bits. */
; void outport_write ( uint16_t value );
outport_write:
	ldr	r1, outport_addr
	str	r0, [r1, #0]
	mov	pc, lr

outport_addr:
	.word ADDR_OUTPUT_PORT
	
	.data
	; sec  o com dados globais iniciados
	; ...

	.section .bss
	; sec  o com dados globais n o iniciados

	.equ STACK_SIZE, 64
	.section .stack
	; sec  o stack para armazenamento de dados tempor rios
	.space	STACK_SIZE
stack_top:
