
; Definicao dos valores dos simbolos utilizados no programa
;
	.equ	CPSR_BIT_I, 0b010000          ; Mascara para o bit I do registo CPSR

	.equ	STACK_SIZE, 64                ; Dimensao do stack - 64 B

	; Definicoes do porto de entrada
	.equ	INPORT_ADDRESS, 0xFF80        ; Endereco do porto de entrada

	; Definicoes do porto de saida
	.equ	OUTPORT_ADDRESS, 0xFFC0       ; Endereco do porto de saida

	.equ	OUTPORT_INIT_VAL, 0x00        ; Valor inicial do porto de saida

	; Definicoes do circuito pTC

	.equ	PTC_ADDRESS,  0xFF40           ; Endereco do circuito pTC


	.equ	PTC_TCR, 0                    ; Deslocamento do registo TCR do pTC
	.equ	PTC_TMR, 2                    ; Deslocamento do registo TMR do pTC
	.equ	PTC_TC,  4                    ; Deslocamento do registo TC do pTC
	.equ	PTC_TIR, 6                    ; Deslocamento do registo TIR do pTC
 
	.equ	PTC_CMD_START, 0              ; Comando para iniciar a contagem no pTC
	.equ	PTC_CMD_STOP, 1               ; Comando para parar a contagem no pTC


	.equ	SYSCLK_FREQ, 0x09             ; Intervalo de contagem do circuito pTC 
                                          ; que suporta a implementação do sysclk.


	; Outras definicoes
    .equ    SYSTEM_INIT,      0xFF
	.equ    USER_MASK,        0x01
	.equ    TIME_MASK,        0xF0
    .equ    STIMULUS_MASK,    0x01
    .equ    RESULT_MASK,      0xFE
    .equ    AVG_TIME,         20          ; Tempo médio de reação em dezenas de ms. Definido tendo em conta ciclos de sysclk. 
    .equ    MIN_TIME,         0xFFC1      ; Limite inferior do domínio de resultado
    .equ    MAX_TIME,         0x0040      ; Limite superior do domínio de resultado. Foi incrementado por 1 para poder suportar o uso da instruçao bge.
    .equ    OUT_OF_RANGE,     0xFFC0      ; Valor para quando o resultado se encontra fora do domínio        
    .equ    STATE_STANDBY, 0              
    .equ    STATE_WAIT_STIMULUS, 1
    .equ    STATE_WAIT_USER_RES, 2
    .equ    RES_DISPLAY_TIME, 5            ; Tempo de display do resultado em segundos
    .equ    SLEEP_0,    50                 ; Tempos de espera em dezenas de ms.
    .equ    SLEEP_1,    100               
    .equ    SLEEP_2,    200
    .equ    SLEEP_3,    300
    .equ    SLEEP_4,    400
    .equ    SLEEP_5,    500
    .equ    SLEEP_6,    600
    .equ    SLEEP_7,    700
    .equ    SLEEP_8,    800
    .equ    SLEEP_9,    900
    .equ    SLEEP_10,   1000 
    .equ    SLEEP_11,   550    
    .equ    SLEEP_12,   650    
    .equ    SLEEP_13,   750    
    .equ    SLEEP_14,   850    
    .equ    SLEEP_15,   950    
; Seccao:    startup
; Descricao: Guarda o código de arranque do sistema
;
	.section startup
	b	_start
	ldr	pc, isr_addr
_start:
	ldr	sp, tos_addr
	ldr	pc, main_addr

tos_addr:
	.word	tos
main_addr:
	.word	main
isr_addr:
	.word	isr

; Seccao:    text
; Descricao: Guarda o código do programa
;
	.text

; Rotina:    main
; Descricao: Inicializa o sistema, ativando o atendimento a pedidos de interrupçao
main:
	mov	r0, #OUTPORT_INIT_VAL
	bl	outport_init
	mov	r0, #SYSCLK_FREQ
	bl	ptc_init
	mrs	r0, cpsr
	mov	r1, #CPSR_BIT_I
	orr	r0, r0, r1
	msr	cpsr, r0
    mov r0, #STATE_STANDBY

/* Máquina de estados.*/
asm:
    mov r1, #4
    cmp r0, r1  
    bcc asm
    lsl r1, r0, #1
    add pc, r1, pc
states:
    b state_standby
    b state_wait_stimulus
    b state_wait_user_res

/* Estado standby. Coloca todos os bits RESULT e STIMULUS a 1. Espera para user ser colocado a 1*/
state_standby: 
    mov r0, #SYSTEM_INIT
    bl outport_set_bits
wait_user_clr:
    bl  check_user
    bzc wait_user_clr
    mov r0, #STATE_WAIT_STIMULUS
    b asm

/* Estado wait stimulus. Coloca os bits Result a 0 e espera o tempo definido pelos bits TIME para baixar stimulus e proceder
à medição do tempo de reação do utilizador. Caso o utilizador coloque user a 0 antes do tempo ser atingido, volta ao estado inicial.*/ 
state_wait_stimulus:
    bl check_user
    bzs state_wait_stimulus         ; espera para user ser colocado a 1
    mov r0, #RESULT_MASK    
    bl outport_clear_bits           ; limpa os bits result
    mov r0, #TIME_MASK
    bl inport_read_mask    
    bl get_time_value         
    bl get_sleep_time               ; obter tempo de espera em dezenas de ms
    mov r4, r0              
    bl  sysclk_get_ticks	        ; guardar valor sysclk inicial em r5
    mov r5, r0
wait_loop:
    bl check_user                   ; caso o utilizador desative USER, volta para o primeiro estado.
    bzs goto_init
    mov r0, r5                      ; verifica se passou o tempo timeout ou não. 
    mov r1, r4                      ; se ainda não passou, permanece em loop.
	bl  is_elapsed	
	and r0, r0, r0
    bzs wait_loop
goto_wait_user_res:
    mov r0, #STATE_WAIT_USER_RES    ; obter tempo de reacao
    b asm
goto_init:
    mov r0, #STATE_STANDBY          ; voltar ao estado inicial de espera
    b asm


/* Estado wait user response. Coloca o bit Stimulus a 0 e espera para o utilizador reagir através da ativação do sinal USER. 
Após a reação do utilizador, é medido o tempo de reação e é mostrado nos LEDS o resultado no domínio -63 a 63, em relação ao tempo 200ms.
Caso o resultado não se encontre neste domínio, é mostrado o resultado -64.*/
state_wait_user_res:
    mov r0, #STIMULUS_MASK
    bl outport_clear_bits           ; coloca stimulus a 0
    bl sysclk_get_ticks             
    mov r4, r0                      ; guardar valor inicial sysclk
user_react:
    bl check_user                   ; esperar  pela reação do utilizador
    bzc user_react
user_time:
    bl  sysclk_get_ticks            ; obter tempo decorrido ao subtrair valor inicial de valor atual
    sub r0, r0, r4              
    mov r1, #AVG_TIME               ; verificar se resultado se encontra no domínio
    sub r0, r0, r1 
    mov r1, #MAX_TIME
    cmp r0, r1                 
    bge out_of_range
    ldr r1, MIN_TIME_ADDR
    cmp r0, r1
    blt out_of_range
    b show_res
out_of_range:
    ldr r0, OUT_OF_RANGE_ADDR
show_res:
    bl get_res                     ; Escrever resultado nos bits RESULT
    bl outport_set_bits
    mov r0, #RES_DISPLAY_TIME
    bl get_sleep_time              ; Esperar tempo definido para display de resultado.
    bl delay
    mov r0, #STATE_STANDBY          ; Voltar ao estado inicial
    b asm

;Verifica o estado do bit USER
check_user:
    push lr 
    mov r0, #USER_MASK
    bl inport_read_mask
    pop pc

; Rotina:    is_elapsed
; Descricao: Verifica se ja passou o tempo definido por timeout, tendo como referencia um tempo inicial
;            r0 = tempo inicial
;            r1 = timeout
is_elapsed:
    push lr
    push r0
    push r1
    bl sysclk_get_ticks
    pop r2
    pop r1
    sub r0, r0, r1
    cmp r0, r2
    bhs is_elapsed_end
elapsed_return_false:
    mov r0, #0
is_elapsed_end: 
    pop pc     

MIN_TIME_ADDR:
    .word MIN_TIME

OUT_OF_RANGE_ADDR:
    .word OUT_OF_RANGE

; Rotina : get_sleep_time
; Descrição : Obtem o valor sleep pertencente ao array, com base no indice passado em r0
; r0 = Indice do array sleep
get_sleep_time: 
    lsl r0, r0, #1
    ldr r1, sleep_ADDR
    ldr r0, [r1, r0]
    mov pc, lr 

; Rotina : get_time_value
; Descrição : Obtem o valor de 1-15 definido pelos bits TIME
get_time_value:
    lsr r0, r0, #4
    mov pc, lr

; Rotina : get_res
; Descrição : Obtem o valor de resultado de 7 bits a colocar nos LEDS.
; r0 = Valor de resultado a 8 bits.
get_res:
    lsl r0, r0, #1
    mov pc, lr

print_result:
    push lr
    lsl r1, r0, #RESULT_SHIFT
    mov r0, #RESULT_MASK
    bl outport_write_bits
    pop pc
; Rotina:    delay
; Descricao: Rotina bloqueante que realiza uma espera ativa por teste sucessivo
;            do valor da variável global sysclk. O tempo a esperar, em
;            dezenas de milissegundos, e passado em R0.
delay:
    push lr
    push r5
    push r4
    mov r4, r0
    bl sysclk_get_ticks    ;guardar valor sysclk inicial em r5
    mov r5, r0
delay_loop:
    bl sysclk_get_ticks    ;obter valor atual
    sub r0, r0, r5         ;obter número de incrementações em sysclk desde inicio
    cmp r0, r4             ;parar se sysclk foi incrementado hms ou mais vezes
    blo delay_loop
delay_end:
    pop r4
    pop r5
    pop pc

; Rotina:    sysclk_get_ticks
; Descricao: Devolve o valor corrente da variável global sysclk.
;            Interface exemplo: uint16_t sysclk_get_ticks ( );
; Entradas:  -
; Saidas:    *** Para completar ***
; Efeitos:   -
sysclk_get_ticks:
	ldr r0, sysclk_ADDR
	ldr r0, [r0, #0]
	mov pc, lr


; *** Inicio de troco para completar ***

; *** Fim de troco para completar ***

; Rotina:    isr
; Descricao: Incrementa o valor da variável global sysclk.
; Entradas:  -
; Saidas:    -
; Efeitos:   *** Para completar ***
isr:
    push lr
	push r0
	push r1
    push r2 
    push r3
    bl clear_tir
	ldr r0, sysclk_ADDR	; incrementar
	ldr r1, [r0, #0]
	add r1, r1, #1
	str r1, [r0, #0]
    pop r3
    pop r2
	pop r1
	pop r0
    pop lr
	movs	pc, lr

sysclk_ADDR: 
	.word sysclk
	

sleep_ADDR:
    .word sleep_times

clear_tir:
    ldr r0, PTC_ADDR
	strb r0, [r0, #PTC_TIR] ; limpar o pedido
    mov pc, lr


; Gestor de periférico para o porto de entrada
;

; Rotina:    inport_read
; Descricao: Adquire e devolve o valor corrente do porto de entrada.
;            Interface exemplo: uint8_t inport_read( );
; Entradas:  -
; Saidas:    R0 - valor adquirido do porto de entrada
; Efeitos:   -
inport_read:
	ldr	r1, inport_addr
	ldrb	r0, [r1, #0]
	mov	pc, lr

; Rotina:    inport_read_mask
; Descricao: Adquire e devolve o valor corrente do porto de entrada nos bits mask.
;            Interface exemplo: uint8_t inport_read( uint8_t mask );
; Entradas:  R0 - valor mask
; Saidas:    R0 - valor adquirido do porto de entrada nos bits mask
; Efeitos:   -
inport_read_mask:
	ldr r1, inport_addr
	ldrb r1, [r1, #0]
	and r0, r0, r1
	mov pc, lr 

inport_addr:
	.word	INPORT_ADDRESS



; Gestor de periférico para o porto de saída
;

; Rotina:    outport_set_bits
; Descricao: Atribui o valor logico 1 aos bits do porto de saida identificados
;            com o valor 1 em R0. O valor dos outros bits nao e alterado.
;            Interface exemplo: void outport_set_bits( uint8_t pins_mask );
; Entradas:  R0 - Mascara com a especificacao do indice dos bits a alterar.
; Saidas:    -
; Efeitos:   Altera o valor da variavel global outport_img.
outport_set_bits:
	push	lr
	ldr	r1, outport_img_addr
	ldrb	r2, [r1, #0]
	orr	r0, r2, r0
	strb	r0, [r1, #0]
	bl	outport_write
	pop	pc

; Rotina:    outport_clear_bits
; Descricao: Atribui o valor logico 0 aos bits do porto de saida identificados
;            com o valor 1 em R0. O valor dos outros bits nao e alterado.
;            Interface exemplo: void outport_clear_bits( uint8_t pins_mask );
; Entradas:  R0 - Mascara com a especificacao do indice dos bits a alterar.
; Saidas:    -
; Efeitos:   Altera o valor da variavel global outport_img.
outport_clear_bits:
	push	lr
	ldr	r1, outport_img_addr
	ldrb	r2, [r1, #0]
	mvn	r0, r0
	and	r0, r2, r0
	strb	r0, [r1]
	bl	outport_write
	pop	pc

; Rotina:    outport_init
; Descricao: Faz a iniciacao do porto de saida, nele estabelecendo o valor
;            recebido em R0.
;            Interface exemplo: void outport_init( uint8_t value );
; Entradas:  R0 - Valor a atribuir ao porto de saida.
; Saidas:    -
; Efeitos:   Altera o valor da variavel global outport_img.
outport_init:
	push	lr
	ldr	r1, outport_img_addr
	strb	r0, [r1]
	bl	outport_write
	pop	pc

outport_img_addr:
	.word	outport_img

; Rotina:    outport_write
; Descricao: Escreve no porto de saida o valor recebido em R0.
;            Interface exemplo: void outport_write( uint8_t value );
; Entradas:  R0 - valor a atribuir ao porto de saida.
; Saidas:    -
; Efeitos:   -
outport_write:
	ldr	r1, outport_addr
	strb	r0, [r1, #0]
	mov	pc, lr

outport_addr:
	.word	OUTPORT_ADDRESS

; Gestor de periférico para o Pico Timer/Counter (pTC)
;

; Rotina:    ptc_start
; Descricao: Habilita a contagem no periferico pTC.
;            Interface exemplo: void ptc_start( );
; Entradas:  -
; Saidas:    -
; Efeitos:   -
ptc_start:
	ldr	r0, PTC_ADDR
	mov	r1, #PTC_CMD_START
	strb	r1, [r0, #PTC_TCR]
	mov	pc, lr



; Rotina:    ptc_stop
; Descricao: Para a contagem no periferico pTC.
;            Interface exemplo: void ptc_stop( );
; Entradas:  -
; Saidas:    -
; Efeitos:   O valor do registo TC do periferico e colocado a zero.
ptc_stop:
	ldr	r0, PTC_ADDR
	mov	r1, #PTC_CMD_STOP
	strb	r1, [r0, #PTC_TCR]
	mov	pc, lr


; Rotina:    ptc_get_value
; Descricao: Devolve o valor corrente da contagem do periferico pTC.
;            Interface exemplo: uint8_t ptc_get_value( );
; Entradas:  -
; Saidas:    R0 - O valor corrente do registo TC do periferico.
; Efeitos:   -
ptc_get_value:
	ldr	r1, PTC_ADDR
	ldrb r0, [r1, #PTC_TC]
	mov	pc, lr

; Rotina:    ptc_init
; Descricao: Inicia uma nova contagem no periferico pTC com o intervalo de
;            contagem recebido em R0, em ticks.
;            Interface exemplo: void ptc_init( uint8_t interval );
; Entradas:  R0 - Valor do novo intervalo de contagem, em ticks.
; Saidas:    -
; Efeitos:   Inicia a contagem no periferico a partir do valor zero, limpando
;            o pedido de interrupcao eventualmente pendente.
ptc_init:
    push    lr
    push    r0
    bl        ptc_stop
    pop        r0
    ldr        r1, PTC_ADDR
    strb    r0, [r1, #PTC_TMR]
    strb    r1, [r1, #PTC_TIR]
	bl ptc_start
    pop        pc


PTC_ADDR:	
	.word	PTC_ADDRESS

; Seccao:    data
; Descricao: Guarda as variáveis globais com um valor inicial definido
;
	.data

; array com os tempos sleep do sistema.
sleep_times: 
     .word SLEEP_0, SLEEP_1, SLEEP_2, SLEEP_3, SLEEP_4, SLEEP_5, SLEEP_6, SLEEP_7, SLEEP_8, SLEEP_9, SLEEP_10, SLEEP_11, SLEEP_12, SLEEP_13, SLEEP_14, SLEEP_15

; Seccao:    bss
; Descricao: Guarda as variáveis globais sem valor inicial definido
;
	.bss
outport_img:
	.space	1
	.align

sysclk:
	.space	2
; Seccao:    stack
; Descricao: Implementa a pilha com o tamanho definido pelo simbolo STACK_SIZE
;
	.stack
	.space	STACK_SIZE
tos:
