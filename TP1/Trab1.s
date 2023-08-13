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




/*

 int main ( void ) {

 error = 0;

 if ( str2nat ( tst_str0 , 2 ) != tst_results [0] )
 error |= 1;
 if ( str2nat ( tst_str1 , 8 ) != tst_results [1] )
 error |= 2;
 if ( str2nat ( tst_str2 , 16 ) != tst_results [2] )
 error |= 4;

 return error ;
 }
*/

main:
	push	lr
	push 	r4
	push    r5
	ldr     r4, error_addr
	mov 	r5, #0
	strb    r5, [r4]
TEST1:
	ldr		r0, tst_str0_addr ; parametros de str2nat
	mov 	r1, #2
	bl		str2nat 
	ldr     r1, tst_res_addr
	ldr     r2, [r1]
	cmp     r2, r0
	beq 	TEST2			; verificacao de resultado
	mov 	r3, #1
	orr     r5, r5, r3
	strb    r5, [r4]
TEST2:
	ldr		r0, tst_str1_addr
	mov 	r1, #8
	bl		str2nat 
	ldr     r1, tst_res_addr
	ldr     r2, [r1,#2]
	cmp 	r2, r0
	beq 	TEST3
	mov 	r3, #2
	orr     r5, r5, r3
	strb    r5, [r4]
TEST3:
	ldr		r0, tst_str2_addr
	mov 	r1, #16
	bl		str2nat 
	ldr     r1, tst_res_addr
	ldr     r2, [r1,#4]
	cmp 	r2, r0
	beq 	endmain
	mov     r3, #4
	orr     r5, r5, r3
	strb    r5, [r4]
endmain:
	mov 	r0, r5
	pop 	r5
	pop		r4
	pop		pc
	
tst_str0_addr:
	.word	tst_str0
tst_str1_addr:
	.word	tst_str1
tst_str2_addr:
	.word	tst_str2
tst_res_addr:
	.word	tst_res
error_addr:
	.word error

multiply:
	mov 	r2, #0
	cmp 	r0, r1
	bhs 	skipswitch 
    mov 	r3, r1
    mov 	r1, r0
    mov 	r0, r3
skipswitch:
    		mov r3, #0
while:
	cmp		r3, r1
	bhs		multiply_end
	add		r2, r2, r0
	sub		r1, r1, #1
	b		while
multiply_end:
	mov 	r0,	r2
	mov 	pc, lr



/*

uint16_t str2nat ( char numeral [] , uint16_t radix ) {

 uint16_t number = 0;
 int8_t error = 0;
 uint16_t idx , tmp ;

 for ( idx = 0; error == 0 && numeral [ idx ] != '\0'; idx ++ ) {
 tmp = char2nat ( numeral [ idx ], radix );
 if ( tmp == 65535 ) {
 number = 65535 ;
 error = 1;
 } else {
 number = number * radix + tmp ;
 }
 }
 return number ;
 }
 */

; r0 = numeral
; r1 = radix
str2nat:
	push 	lr
	push 	r4
	push 	r5
	push 	r6
	push 	r7
	push 	r8
	push 	r9
	mov 	r4, r0							; r4 = numeral
	mov 	r5, #0							; idx = 0
	mov 	r6, #0 							; number = 0
	mov 	r7, #0 							; error = 0
	mov 	r8, r1							; r8 = radix
	b 		str2nat_for_cond
str2nat_for:
	mov 	r1, r8
	add     r5, r5, #1						; i++					
    bl 		char2nat						; tmp = char2nat(numeral[idx], radix)
	ldr		r3, NAN
	cmp 	r0, r3							; if tmp == NAN 
	bne 	str2nat_for_else		
	mov 	r6, r3							; number = NAN
	mov 	r7, #1							; error = 1
	b 		str2nat_for_cond					
str2nat_for_else:	
	mov 	r9, r0							; guardar tmp
	mov 	r0, r6							; parametros de multiply
	mov 	r1, r8							
	bl 		multiply						; r0 = number * radix	
	add		r6, r0, r9						; number = number * radix + tmp
str2nat_for_cond:
	ldrb 	r0, [r4, r5] 					; r0 = numeral[idx]
	sub 	r7, r7, #0
	bne 	str2nat_end						; if error == 0
	sub  	r0, r0, #0
	beq 	str2nat_end						; if numeral [idx] != '\0'
	b 		str2nat_for					
str2nat_end:
    mov 	r0, r6						
	pop 	r9
	pop 	r8
	pop	 	r7
	pop 	r6
	pop 	r5
	pop 	r4
	pop 	pc


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
	
tst_res: 
	.word 11, 457, 39439
NAN: 		
	.word 65535
tst_str0: 
	.asciz "01011"
tst_str1: 
	.asciz "709"
tst_str2: 
	.asciz "9A0F"
	
		



	.section .bss
	error: .space 1

	
	.equ STACK_SIZE, 64


	.section .stack
	
	.space	STACK_SIZE
stack_top:
