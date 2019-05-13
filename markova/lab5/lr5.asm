.286

EOFLine EQU '$'                                       ; определение символьной константы
                                                      ; $ - "конец строки"
													  
ASTACK SEGMENT STACK
	DW 64 DUP (?)
ASTACK ENDS
;ДАННЫЕ
;--------------------------------------------------------------------------------------------
DATA SEGMENT
	interrupt_already_loaded DB 'Interrupt already loaded!',  0DH,0AH,EOFLine
	interrupt_was_unloaded   DB 'Interrupt was unloaded!',    0DH,0AH,EOFLine
	interrupt_was_loaded     DB 'Interrupt was loaded!',      0DH,0AH,EOFLine
DATA ENDS
;--------------------------------------------------------------------------------------------
CODE SEGMENT
        ASSUME CS:CODE, DS:DATA, ES:DATA, SS:ASTACK
START: JMP BEGINNING                                  ;переход на метку
;ПРОЦЕДУРЫ
;--------------------------------------------------------------------------------------------
LINE_OUTPUT PROC NEAR                                 ;вывод строки 
	mov AH, 0009h
	int 21h
	ret
LINE_OUTPUT ENDP

ROUT PROC FAR                                         ;обработчик прерывания
	jmp ROUT_BEGINNING 
;ДАННЫЕ
;--------------------------------------------------------------------------------------------
	signature db '0000'                           ;идентификация резидента
	keep_ip   dw 0                                ;для хранения смещения прерывания
	keep_cs   dw 0                                ;для хранения сегмента кода
	keep_psp  dw 0                                ;для хранения PSP
	keep_ss   dw 0                                ;для хранения сегмента стека
	keep_ax   dw 0	                              ;для хранения регистра AX
	keep_sp   dw 0                                ;для хранения регистра SP
	REQ_KEY   db 38h                              ;скан-код Alt Left
	MY_STACK  dw 64 DUP(?)
	END_STACK dw 0
;--------------------------------------------------------------------------------------------
        ROUT_BEGINNING:
	        mov  keep_ax, AX                      ;запоминаем ax
		mov  keep_ss, SS
		mov  keep_sp, SP
		mov  AX,  CS                          ;установка своего стека
		mov  SS,  AX
                mov  SP,  offset END_STACK		
		mov  AX,  keep_ax
		pusha                                 ;поместить в стек значения всех 16-битных регистров общего назначения
		in   AL,  60h                         ;читать скан-код клавиши (её порядковый номер), ввод значения из порта ввода-вывода
		cmp  AL,  REQ_KEY                     ;это требуемый код?
		je   DO_PROCESSING                    ;да, активизировать обработку REQ_KEY | нет, уйти на исходный обработчик
		call dword ptr CS: keep_ip            ;переход на первоначальный обработчик
		jmp  EXIT
		
	DO_PROCESSING:                                ;следующий код необходим для отработки аппаратного прерывания     	
	        push AX
		in   AL,  61h                         ;взять значение порта управления клавиатуры
		mov  AH,  AL                          ;сохранить его
		or   AL,  80h                         ;установить бит разрешения для клавиатуры
		out  61h, AL                          ;и вывести его в управляющий порт
		xchg AH,  AL                          ;извлечь исходное значение порта, позволяет обменять содержимое двух операндов 
		out  61h, AL                          ;и записать его обратно
		mov  AL,  20h                         ;послать сигнал "конец прерывания"
		out  20h, AL                          ;контроллеру прерываний 8259
		pop  AX
		
	SKIP:                                         ;записать символ в буфер клавиатуры
	        mov  CL,  127                         ;аски-код □
		mov  AH,  05h                         ;код функции
		and  CH,  00h
		int  16h
		or   AL,  AL                          ;проверка на переволнение буфера
		jz   EXIT                             ;если переполнение, то очищаем буфер клавиатуры
		cli
		mov  AX,  ES:[1Ah]                    ;взятие адреса начала буфера
		mov  ES:  [1Ch], AX                   ;записываем адрес начала в конец  
		sti                                   ;разрешение прерывания, путём изменения флага IF
		jmp  SKIP
		
	EXIT:
	        popa                                  ;восстановление всех регистров общего назначения
	        mov  SS,  keep_ss
	        mov  SP,  keep_sp
	        mov  AX,  keep_ax
                mov  AL,  20h
                out  20h, AL
                mov  AX,  keep_ax
                iret		
	
	LAST_BYTE:
                ROUT ENDP    
;--------------------------------------------------------------------------------------------
CHECK_INT PROC                                        ;проверка, установлено ли пользовательское прерывание с вектором 09h
	mov AH, 35h                                   ;функция 35h прерывания 21h, даёт вектор прерывания
	mov AL, 09h                                       
	int 21h                                       ;Выход: ES:BX = адрес обработчика прерывания	
	mov SI, offset signature                          
	sub SI, offset ROUT                           ;SI = смещение signature относительно начала функции прерывания
	mov AX, '00'                                      
	cmp AX, ES:[BX+SI]                                
	jne NOT_LOADED                                    
	cmp AX, ES:[BX+SI+0002h]
	jne NOT_LOADED
	jmp LOADED                                        
	
        NOT_LOADED:                                       
	        call MY_INT                           ;установка пользовательского прерывания
	        mov  DX, offset LAST_BYTE             ;размер в байтах от начала
	        mov  CL, 4                            ;перевод в параграфы
	        shr  DX, CL                           ;сдвиг на 4 разряда вправо
	        inc  DX	                                     
	        add  DX, CODE                                 
	        sub  DX, keep_psp                           
	        xor  AL, AL
	        mov  AH, 31h                          ;номер функции 31h прерывания 21h, оставляем нужное количество памяти
	        int  21h                                      	      
		
        LOADED:                                       ;смотрим, есть ли в хвосте /un , тогда нужно выгружать
	        push ES
	        push AX
	        mov AX, CS: keep_psp 
	        mov ES, AX
	        cmp byte ptr ES:[0082h], '/' 
	        jne NOT_UNLOAD 
	        cmp byte ptr ES:[0083h], 'u' 
	        jne NOT_UNLOAD 
	        cmp byte ptr ES:[0084h], 'n' 
	        je UNLOAD 
		
        NOT_UNLOAD:
	        pop  AX
	        pop  ES
	        mov  dx, offset interrupt_already_loaded
	        call LINE_OUTPUT
	        ret
		
        UNLOAD: 
	        pop  AX
	        pop  ES
	        call DELETE
	        mov  dx, offset interrupt_was_unloaded 
	        call LINE_OUTPUT
	        ret
CHECK_INT ENDP

DELETE PROC                                           ;восстановление вектора прерывания                                          
	push AX
	push DS
	push ES
	CLI                                           ;запрещение прерывания, путём сбрасывания флага IF
	mov  DX, ES: [BX+SI+0004h] 
	mov  AX, ES: [BX+SI+0006h]
	mov  DS, AX                                   ;DS:DX = вектор прерывания: адрес программы обработки прерывания
	mov  AH, 25h                                  ;функция 25h прерывания 21h, устанавливает вектор прерывания
	mov  AL, 09h                                        
	int  21h                                           
	mov  AX, ES: [BX+SI+0008h]
	mov  ES, AX
	mov  ES, ES:[2Ch]                             ;ES = сегментный адрес освобождаемого блока памяти 
	mov  AH, 49h                                  ;функция 49h прерывания 21h, освободить распределённый блок памяти    
	int  21h 
	pop  ES
	mov  ES, ES: [BX+SI+0008h]
	mov  AH, 49h
	int  21h
	STI                                           ;разрешение прерывания
	pop  DS
	pop  AX
	ret
DELETE ENDP  
	
;--------------------------------------------------------------------------------------------
MY_INT PROC                                           ;установка написанного прерывания в поле векторов прерываний
	push DS
	mov  AH, 35h                                  ;функция получения вектора
	mov  AL, 09h                                  ;номер вектора
	int  21h
	mov  keep_ip, BX                              ;запоминание смещения
	mov  keep_cs, ES 
	mov  DX, offset ROUT                          ;смещение для процедуры в DX
	mov  AX, seg ROUT 
	mov  DS, AX 
	mov  AH, 25h                                  ;функция установки вектора
	mov  AL, 09h                                  ;номер вектора
	int  21h                                          
	pop  DS
	push DX
	mov  DX, offset interrupt_was_loaded 
	call LINE_OUTPUT
	pop  DX
	ret
MY_INT ENDP 
;--------------------------------------------------------------------------------------------
BEGINNING:
	mov  AX, DATA
	mov  DS, AX
	mov  keep_psp, ES 
	call CHECK_INT 
	xor  AL, AL
	mov  AH, 4Ch                                  ;выход 
	int  21H
CODE ENDS
	END  START
