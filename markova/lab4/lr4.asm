EOFLine EQU '$'                                       ; определение символьной константы
                                                      ; $ - "конец строки"

MY_STACK SEGMENT STACK
	DW 64 DUP (?)
MY_STACK ENDS

STACK SEGMENT STACK
	DW 64 DUP (?)
STACK ENDS
;ДАННЫЕ
;--------------------------------------------------------------------------------------------
DATA SEGMENT
	interrupt_already_loaded DB 'Interrupt already loaded!',  0DH,0AH,EOFLine
	interrupt_was_unloaded   DB 'Interrupt was unloaded!',    0DH,0AH,EOFLine
	interrupt_was_loaded     DB 'Interrupt was loaded!',      0DH,0AH,EOFLine
DATA ENDS
;--------------------------------------------------------------------------------------------
CODE SEGMENT
 ASSUME CS:CODE, DS:DATA, ES:DATA, SS:STACK
START: JMP BEGINNING                                  ;переход на метку
;ПРОЦЕДУРЫ
;--------------------------------------------------------------------------------------------
LINE_OUTPUT PROC NEAR                                 ;вывод строки 
	mov AH, 0009h
	int 21h
	ret
LINE_OUTPUT ENDP

SET_CURS PROC                                         ;установка позиции курсора; установка на строку 25 делает курсор невидимым
	push AX
	push BX
	push CX
	mov  AH, 0002h
	mov  BH, 0000h
	int  0010h                                    ;выполнение функции 0002h
	pop  CX                                       ;Вход: BH = видео страница
	pop  BX                                       ;      DH,DL = строка, колонка (считая от 0)
	pop  AX
	ret
SET_CURS ENDP

GET_CURS PROC                                         ;функция, определяющая позицию и размер курсора 
	push AX
	push BX
	push CX
	mov  AH, 0003h                                ;0003h читать позицию и размер курсора
	mov  BH, 0000h                                ;Вход: BH = видео страница
	int  10h                                      ;выполнение функции 0003h
	pop  CX                                       ;Выход: DH, DL = текущая строка, колонка курсора
	pop  BX                                       ;       CH, CL = текущая начальная, конечная строки курсора
	pop  AX
	ret
GET_CURS ENDP
;--------------------------------------------------------------------------------------------
ROUT PROC FAR                                         ;обработчик прерывания
	jmp ROUT_BEGINNING 
;ДАННЫЕ
;--------------------------------------------------------------------------------------------
	signature db '0000'                           ;некоторый код, который идентифицирует резидента
	keep_cs   dw 0                                ;для хранения сегмента кода
	keep_ip   dw 0                                ;для хранения смещения прерывания
	keep_psp  dw 0                                ;для хранения PSP
	check     dw 0                                ;проверяем надо выгружать прерывание или нет
	keep_ss   dw 0                                ;для хранения сегмента стека
	keep_ax   dw 0	                              ;для хранения регистра AX
	keep_sp   dw 0                                ;для хранения регистра SP
	timer     db 'Interrupt call 1Ch: 0000 $'     ;счётчик
;--------------------------------------------------------------------------------------------
    ROUT_BEGINNING:
	    mov  keep_ax, AX                          ;запоминаем ax
	    mov  keep_ss, SS                          ;запоминаем начало стека
	    mov  keep_sp, SP                          ;запоминаем регистр SP
	    mov  AX, MY_STACK                         ;устанавливаем собственный стек
	    mov  SS, AX
	    mov  SP, 64h
	    mov  AX, keep_ax
	    push DX                                   ;сохраняем все изменяемые регистры
	    push DS
	    push ES
	    cmp  check, 1
	    je   ROUT_REC
	    call GET_CURS                             ;получаем текущее положение курсора 
	    push DX                                   ;сохраняем положения курсора в стеке
	    mov  DH, 17h                              ;DH, DL - строка, колонка (считая от 0) 
	    mov  DL, 1Ah                              ;определяем местоположение надписи
	    call SET_CURS                             ;устанавливаем курсор
    
	ROUT_COUNT:	                              ;счётчик количества прерываний
	    push SI                                   ;сохраняем все изменяемые регистры
	    push CX 
	    push DS
	    mov  AX, seg timer
	    mov  DS, AX
	    mov  SI, offset timer 
	    add  SI, 0017h                            ;смещение на последнюю цифру (23 знак)
	    
	    count:
		mov  AH, [SI]                         ;получаем цифру
	        inc  AH                               ;увеличиваем её на 1
		mov  [SI], AH                         ;возвращаем
	        cmp  AH, 3Ah                          ;если не равно 9
	        jne  END_COUNT                        ;завершение и вывод результата
	        mov  AH, 30h                          ;обнуляем
		mov  [SI], AH
                dec  SI
            loop     count			
		
    END_COUNT:                                        ;печать счётчика-строки на экран
            pop  DS
            pop  CX
	    pop  SI
	    push ES 
	    push BP
	    mov  AX, seg timer
	    mov  ES, AX
	    mov  AX, offset timer
	    mov  BP, AX                               ;Вход: ES:BP выводимая строка 
	    mov  AH, 00013h                           ;функция 13h прерывания 10h, выдаёт строку в позиции курсора
	    mov  AL, 0000h                            ;режим вывода
	    mov  CX, 0019h                            ;длина строки = 25 символов
	    mov  BH, 0000h                            ;видео страница, её номер
	    mov  BL, 0002h                            ;установка атрибута
	    int  10h                                      
	    pop  BP
	    pop  ES
	    pop  DX                                   ;возвращение курсора
	    call SET_CURS
	    jmp  ROUT_END

    ROUT_REC:                                         ;восстановление вектора прерывания
	    CLI                                       ;запрещение прерывания, путём сбрасывания флага IF
	    mov DX, keep_ip
	    mov AX, keep_cs
	    mov DS, AX                                ;DS:DX = вектор прерывания: адрес программы обработки прерывания
	    mov AH, 25h                               ;функция 25h прерывания 21h, устанавливает вектор прерывания
	    mov AL, 1Ch                               ;Вход: AL = номер вектора прерывания
	    int 21h                                       
	    mov ES, keep_psp                              
	    mov ES, ES:[2Ch]                          ;ES = сегментный адрес (параграф) освобождаемого блока памяти 
	    mov AH, 49h                               ;функция 49h прерывания 21h, освободить распределённый блок памяти   
	    int 21h                                       
	    mov ES, keep_psp                              
	    mov AH, 49h                                   
	    int 21h	                                      
	    STI                                       ;разрешение прерывания
		
    ROUT_END:
	    pop ES                                    ;восстановление регистров
	    pop DS
	    pop DX
	    mov SS, keep_ss
	    mov SP, keep_sp
	    mov AX, keep_ax
	    iret
		
    LAST_BYTE:
        ROUT ENDP
;--------------------------------------------------------------------------------------------
CHECK_INT PROC                                        ;проверка, установлено ли пользовательское прерывание с вектором 1Ch
	mov AH, 35h                                   ;функция 35h прерывания 21h, даёт вектор прерывания
	mov AL, 1Ch                                   ;AL = номер прерывания
	int 21h                                       ;Выход: ES:BX = адрес обработчика прерывания	
	mov SI, offset signature                          
	sub SI, offset ROUT                           ;SI = смещение signature относительно начала функции прерывания
	mov AX, '00'                                  ;сравнив известное значение сигнатуры
	cmp AX, ES:[BX+SI]                            ;с реальным кодом, находящимся в резиденте
	jne NOT_LOADED                                ;если значения не совпадают, то резидент не установлен
	cmp AX, ES:[BX+SI+2]
	jne NOT_LOADED
	jmp LOADED                                        
	
    NOT_LOADED:                                       
	    call MY_INT                               ;установка пользовательского прерывания
	    mov  DX, offset LAST_BYTE                 ;размер в байтах от начала
	    mov  CL, 4                                ;перевод в параграфы
	    shr  DX, CL                               ;сдвиг на 4 разряда вправо
	    inc  DX	                                     
	    add  DX, CODE                             ;прибавляем адрес сегмента CODE
	    sub  DX, keep_psp                           
	    xor  AL, AL
	    mov  AH, 31h                              ;номер функции 31h прерывания 21h, оставляем нужное количество памяти
	    int  21h                                      	      
		
    LOADED:                                           ;смотрим, есть ли в хвосте /un , тогда нужно выгружать
	    push ES
	    push AX
	    mov AX, keep_psp 
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
	    mov  byte ptr ES:[BX+SI+10], 1            ;check = 1
	    mov  dx, offset interrupt_was_unloaded 
	    call LINE_OUTPUT
	    ret
CHECK_INT ENDP

MY_INT PROC                                           ;установка написанного прерывания в поле векторов прерываний
	push DX
	push DS
	mov  AH, 35h                                  ;функция получения вектора
	mov  AL, 1Ch                                  ;номер вектора
	int  21h
	mov  keep_ip, BX                              ;запоминание смещения
	mov  keep_cs, ES 
	mov  DX, offset ROUT                          ;смещение для процедуры в DX
	mov  AX, seg ROUT 
	mov  DS, AX 
	mov  AH, 25h                                  ;функция установки вектора
	mov  AL, 1Ch                                  ;номер вестора
	int  21h                                          
	pop  DS
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
