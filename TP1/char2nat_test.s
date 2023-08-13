/*
	Respostas 
	1. 
	a) - Ocupa 18 bytes. Na arquitetura do processador P16 cada instrução ocupa 2 bytes em memoria, já que a rotina multiply tem 9 instruções, 9x2 = 18 bytes 
	b) = De acordo com as convenções de uso do processador P16 os registos R0 a R3 podem ser alterados no corpo da função, enquanto os registos R4 a R12 devem ser 
	preservados em memoria antes de utilizados de forma a reterem os valores que tinham antes da chamada da função depois do retorno da mesma, e como têm que ser preservados,
	devem ser utilizados apenas após os registos R0 a R3 terem sido esgotados. Tendo isto em conta, o uso de R2 em vez de R4 é mais apropriado na implementação desta rotina.

	2.
	a) Tendo em conta que a constante NAN é o maior valor possível de codificar numa variável sem sinal a 16 bits, o valor de NAN será 0xFFFF em hexadecimal ou 65535 em decimal
	b) Uma possível definição de NAN é NAN: .word 65535 ,Os requisitos de memória seriam a alocação de um espaço de 2 bytes de memória e a a inicialização desse espaço com o valor 0xFFFF



	*/

	.section .startup
	
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
	; sec��o com c�digo aplicacional
main:
    push lr
	bl char2nat_test 
	pop pc
	/*
	uint16_t char2nat ( char symbol , uint16_t radix ) {

 	uint16_t number = NAN ;

	if ( symbol >= '0 ' && symbol <= '9 ' ) {
		number = symbol - '0 ';
	} 	else if ( symbol >= 'A ' && symbol <= 'F ' ) {
 			number = symbol - 'A ' + 10;
 	}
	if ( radix > 16 || number >= radix ) {
 			number = NAN ;
 	}
 	return number ;
 	} */
	

char2nat_test:
	push	lr
	push 	r4
	push 	r5
    push    r6
	ldr     r4, symbol_test_addr
	ldr 	r5, radix_test_addr
    mov     r7, #symbol_test_end-symbol_test
char2nat_test_loop:
	ldrb	r0, [r4]	
    ldrb	r1, [r5]
	bl 		char2nat
	add		r4, r4, #1
	add		r5, r5, #1
	sub		r7, r7, #1
	bzc		char2nat_test_loop
    pop     r6
	pop 	r5
	pop 	r4
	pop		pc

symbol_test_addr:
    .word symbol_test
radix_test_addr:
    .word radix_test
	;r0 = symbol
	;r1 = radix
char2nat:
	ldr		r2, NAN			            ; r2 = number = NAN
	mov 	r3,	#'0'					; r3 = '0' (registo para valores temporários)
	cmp     r0, r3					
	blo 	char2nat_elsif 				; if symbol >= '0'
	mov 	r3,	#'9'					; r3 = '9'
	cmp 	r3, r0						; if symbol <= '9'
	blo     char2nat_elsif		
	mov 	r3,	#'0'		
	sub 	r2, r0, r3					; number = symbol - '0'
	b       char2nat_if
char2nat_elsif:
	mov 	r3,	#'A'	
	cmp     r0, r3 						
	blo     char2nat_if					; if symbol >= 'A'
	mov 	r3,	#'F'	
	cmp     r3, r0
	blo 	char2nat_if					; if symbol <= 'F'
    mov     r3,  #'A'
	sub     r2, r0, r3
    add     r2, r2, #10					; number = symbol - 'A' + 10
char2nat_if:
    mov 	r3, #16
    cmp     r3, r1
	blo     set_nan  					; if radix > 16
	cmp 	r2, r1
	bhs     set_nan						; if number >= radix
char2nat_end:
	mov 	r0, r2						; return number
	mov 	pc, lr
set_nan: 
	ldr 	r2, NAN
	b char2nat_end 





	.data
	; sec��o com dados globais iniciados
NAN:
     .word 65535
     
symbol_test: .byte  'A', 'B', 'C', 'D', 'E', 'C', '6','5','4','0','1','2', 'A', '2', '0'
symbol_test_end:

radix_test: .byte 16, 16, 16, 16, 10, 16, 2, 10, 2, 10, 16, 122, 142, 142
radix_test_end:





	;.section .bss
	; sec��o com dados globais n�o iniciados
	
	.equ STACK_SIZE, 64



	.section .stack
	; sec��o stack para armazenamento de dados tempor�rios
	.space	STACK_SIZE
stack_top:
