EOFLine EQU '$'                                                  ; определение символьной константы
                                                                 ; $ - "конец строки"
TESTPC SEGMENT                                                   ; определение начала сегмента
	   ASSUME CS:TESTPC, DS:TESTPC, ES:NOTHING, SS:NOTHING    
	   ORG 100H                                                  ; смещение
START: JMP BEGIN                                                 ; переход на метку
;ДАННЫЕ
;--------------------------------------------------------------------------------------------
extended_memory_size db 'Extended memory size:       Kbyte',       0DH,0AH,EOFLine        
available_memory     db 'Amount of available memory:        byte', 0DH,0AH,EOFLine
data_of_mcb          db '         |       |          | ',          EOFLine                      
endl                 db ' ',0DH,0AH,                               EOFLine
mcb                  db ' Address | Owner |   Size   | Name     ', 0DH,0AH,EOFLine
;ПРОЦЕДУРЫ
;--------------------------------------------------------------------------------------------
TETR_TO_HEX PROC near                                            ; из двоичной в шестнадцатеричную сс
	and  AL, 0Fh                                                 ; PROC near - вызывается в том же сегменте, в котором определена
	cmp  AL, 09
	jbe  NEXT
	add  AL, 07
NEXT:    add AL, 30h
	ret
TETR_TO_HEX ENDP

BYTE_TO_HEX PROC near                                            ; байтовое число в шестнадцатеричную сс
	push CX
	mov  AH, AL
	call TETR_TO_HEX
	xchg AL, AH
	mov  CL, 4
	shr  AL, CL
	call TETR_TO_HEX
	pop  CX
	ret
BYTE_TO_HEX ENDP
 
WRD_TO_HEX PROC near                                             ; шестнадцатибитовое число в шестнадцатеричную сс
	push BX
	mov  BH, AH
	call BYTE_TO_HEX
	mov  [DI], AH
	dec  DI
	mov  [DI], AL
	dec  DI
	mov  AL, BH
	call BYTE_TO_HEX
	mov  [DI], AH
	dec  DI
	mov  [DI], AL
	pop  BX
	ret
WRD_TO_HEX ENDP

BYTE_TO_DEC PROC near                                            ; байтовое число в десятичную сс
	push CX
	push DX
	mov  CX, 10
loop_bd: div CX
	or   DL, 30h
	mov  [SI], DL
	dec  SI
	xor  DX, DX
	cmp  AX, 10
	jae  loop_bd
	cmp  AL, 00h
	je   end_l
	or   AL, 30h
	mov  [SI], AL
end_l:   pop DX
	pop  CX
	ret
BYTE_TO_DEC ENDP
;--------------------------------------------------------------------------------------------
LINE_OUTPUT PROC near                                            ; вывод строки
    push AX
    mov  AH, 09h
	int  21H
	pop  AX
	ret
LINE_OUTPUT ENDP

AVAILABLE_MEM PROC near                                          ;вывод информации о кол-ве доступной памяти
    mov  AH, 4Ah                                                 ;расширение блока памяти
	mov  BX, 0ffffh		                                         ;заведомо большое число => расширение неудачно
	int  21h				                                     ;запуск функции 4Ah прерывания int 21h
	mov  AX, BX                                                  ;в BX - записан наибольший доступный блок
	mov  BX, 0010h		                                         ;умножаем на 16, чтоб получить результат в байтах
	mul  BX				                                         ;dx:ax = ax*bx ,кол-во параграфов * 16 байт
	mov  SI, offset available_memory                             ;в результате получаем большое число, которое хранится в двух регистрах
	add  SI, 33		                                             
	call BYTE_TO_DEC
	mov  DX, offset available_memory
	call LINE_OUTPUT
	mov  dx, offset endl
	call LINE_OUTPUT
	ret
AVAILABLE_MEM ENDP

EXTENDED_MEMORY PROC near                                        ;вывод информации о размере расширенной памяти
    mov  AL,  30h		                                         ;запись адреса ячейки CMOS
	out  70h, AL		                                         ;вывод значения из al в порт 70h
	in   AL,  71h		                                         ;получение в al значение из 71h (младший байт)
	mov  BL,  AL		                                         ;перенос в bl
	mov  AL,  31h		                                         ;запись вдреса ячейки CMOS
	out  70h, AL		
	in   AL,  71h		                                         ;получение старшего байта
	mov  BH,  AL	
	mov  AX,  BX                                                 	
    xor  DX,  DX                                                 ;чтобы при выводе числа из dx и ax, не было лишнего
	mov  SI,  offset extended_memory_size
	add  SI,  26
	call BYTE_TO_DEC
	mov  DX,  offset extended_memory_size
	call LINE_OUTPUT
	mov  dx, offset endl
	call LINE_OUTPUT
	ret
EXTENDED_MEMORY ENDP

CHAIN_OF_MCB PROC
	mov  dx, offset mcb
	call LINE_OUTPUT
	mov  AH, 52h                                                 ;функция, которая в es:bx возвращает list of lists
	int  21h                                                     ;вызов функции
	mov  BX, ES:[BX-2]                                           ;получение адреса первого MCB блока
	mov  ES, BX
	
	print_MCB:
	    mov  AX, ES
		mov  DI, offset data_of_mcb                              ;заполнение адреса MCB блока
		add  DI, 5
		call WRD_TO_HEX
		mov  AX, ES:[0001h]                                      ;получение сегментного адреса PSP владельца
		mov  DI, offset data_of_mcb 
        add  DI, 15		
		call WRD_TO_HEX
		mov  AX, ES:[0003h]                                      ;получение размера участка в параграфах
		mov  SI, offset data_of_mcb 
        add  SI, 24		
		xor  DX, DX
		mov  BX, 0010h                                           
		mul  BX                                                  ;перевод в байты
		call BYTE_TO_DEC
		mov  DX, offset data_of_mcb
		call LINE_OUTPUT                       
		push BX
		mov  CX, 0008h
		mov  BX, 0008h                                           ;для вывода последних 8 байт
		mov  AH, 0002h
		
		print:
			mov DL, byte ptr ES:[BX]
			inc BX
			int 21h
		loop print
		
		pop  BX
		mov  DX, offset endl
		call LINE_OUTPUT
		mov  AX, ES
		inc  AX
		add  AX, ES:[0003h]
		mov  BL, ES:[0000h]
		mov  ES, AX
		cmp  BL, 4Dh
		je   print_MCB	
		
	ret
CHAIN_OF_MCB ENDP
;--------------------------------------------------------------------------------------------
BEGIN:
    call AVAILABLE_MEM
	call EXTENDED_MEMORY
	call CHAIN_OF_MCB
	xor  AL, AL
	mov  AH, 4Ch
	int  21h
	TESTPC   ENDS
        END START                                                ;конец модуля, START - точка входа