EOFLine EQU '$'                                       ;определение символьной константы
                                                      ;$ - "конец строки"
													  
ASTACK SEGMENT STACK
	DW 64 DUP (?)
ASTACK ENDS
;ДАННЫЕ
;--------------------------------------------------------------------------------------------													  
DATA SEGMENT
ParameterBlock     dw 0000h                           ;сегментный адрес среды
                   dd 0000h                           ;сегмент и смещение командной строки
                   dd 0000h                           ;сегмент и смещение первого FCB (File Control Block)
                   dd 0000h                           ;сегмент и смещение второго FCB
	Mem_8      DB 0DH, 0AH,'Not enough memory to perform the function!',0DH,0AH,EOFLine	
        PATH 	   DB '                                               ',0DH,0AH,EOFLine,0	
	End_2      DB 0DH, 0AH,'The completion of the device error!',0DH,0AH,EOFLine
	Mem_9      DB 0DH, 0AH,'Wrong address of the memory block!',0DH,0AH,EOFLine
	Err_1      DB 0DH, 0AH,'The number of function is wrong!',0DH,0AH,EOFLine	
	Mem_7      DB 0DH, 0AH,'Memory control unit destroyed!',0DH,0AH,EOFLine
	Err_10     DB 0DH, 0AH,'Incorrect environment string!',0DH,0AH,EOFLine
	End_3      DB 0DH, 0AH,'Completion by function 31h!',0DH,0AH,EOFLine
	Err_8      DB 0DH, 0AH,'Insufficient memory!',0DH,0AH,EOFLine
	End_0      DB 0DH, 0AH,'Normal completion!',0DH,0AH,EOFLine
	End_1      DB 0DH, 0AH,'End by Ctrl-Break!',0DH,0AH,EOFLine	
        Err_2      DB 0DH, 0AH,'File not found!',0DH,0AH,EOFLine
	Err_11     DB 0DH, 0AH,'Wrong format!',0DH,0AH,EOFLine		
	Err_5      DB 0DH, 0AH,'Disk error!',0DH,0AH,EOFLine
	END_CODE   DB 'Exit code:   ',0DH,0AH,EOFLine 	
	KEEP_SS    DW 0000h
	KEEP_SP    DW 0000h
DATA ENDS
;--------------------------------------------------------------------------------------------
CODE SEGMENT
        ASSUME CS:CODE, DS:DATA, ES:DATA, SS:ASTACK
START: JMP BEGINNING                                  ;переход на метку
;ПРОЦЕДУРЫ
;--------------------------------------------------------------------------------------------
LINE_OUTPUT PROC NEAR                                 ;вывод строки 
	mov  AH, 0009h
	int  21h
	ret
LINE_OUTPUT ENDP
;--------------------------------------------------------------------------------------------
TETR_TO_HEX PROC near                                 ;из двоичной в шестнадцатеричную сс
	and  AL, 0Fh                                  ;PROC near - вызывается в том же сегменте, в котором определена
	cmp  AL, 09
	jbe  NEXT
	add  AL, 07
NEXT:   add  AL, 30h
	ret
TETR_TO_HEX ENDP

BYTE_TO_HEX PROC near                                 ;байтовое число в шестнадцатеричную сс
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
;--------------------------------------------------------------------------------------------
FREE_MEMORY PROC NEAR                                 ;освобождение места в памяти 
	                                              ;перед вызовом функции надо определить объём памяти, необходимый lr6 
	mov  BX, offset LAST_BYTE                     ;кладём в BX адрес конца программы
	mov  AX, ES                                   ;ES - начало программы
	sub  BX, AX                                   ;BX = BX - ES, число параграфов, которые будут выделяться прграмме
	mov  CL, 0004h
	shr  BX, CL                                   ;переводим в параграфы
	mov  AH, 4Ah                                  ;функция сжатия блока памяти
	int  21h
	jnc  WITHOUT_ERROR                            ;флаг CF = 0, если нет ошибки
	jmp  WITH_ERROR                               ;oбработка ошибок CF=1 AX = код ошибки, если CF установлен 
    
	WITHOUT_ERROR:
	     ret
		 
	WITH_ERROR:
        MEM_7_ERROR:	
	     cmp  AX, 0007h                           ;разрушен управляющий блок памяти
             jne  MEM_8_ERROR
	     mov  DX, offset Mem_7
	     jmp  END_ERROR
        MEM_8_ERROR:
	     cmp  AX, 0008h                           ;недостаточно памяти для выполнения функции
	     jne  MEM_9_ERROR
	     mov  DX, offset Mem_8
	     jmp  END_ERROR
	MEM_9_ERROR:
             mov  DX, offset Mem_9                    ;неверный адрес блока памяти
	
        END_ERROR:
	     call LINE_OUTPUT 
	     xor  AL, AL
	     mov  AH, 4Ch
	     int  21h
FREE_MEMORY ENDP

PROCESSING PROC NEAR
    mov  ES,  ES:[2Ch]                                ;сегментный адрес среды, передаваемый программе
    mov  SI,  0000h
    cycle:
	     mov  DL, ES:[SI]
	     cmp  DL, 0000h		              ;проверка: конец строки? 
	     je   end_cycle	
	     inc  SI
	     jmp  cycle
    end_cycle:
	     inc  SI
	     mov  DL, ES:[SI]
	     cmp  DL, 0000h	                      ;проверка: конец среды?	               	
	     jne  cycle
	     add  SI, 0003h	                      ;SI указывает на начало маршрута	
	     push DI
	     lea  DI, PATH
    loop_:
             mov  DL, ES:[SI]
	     cmp  DL, 0000h	                      ;проверка: конец маршрута?               		                          
	     je   end_loop	
	     mov  [DI], DL	
	     inc  DI			
	     inc  SI			
	     jmp  loop_
    end_loop:
	     sub  DI,           0007h		 
	     mov  [DI],         byte ptr 'L'	
	     mov  [DI + 0001h], byte ptr 'R'
	     mov  [DI + 0002h], byte ptr '2'
	     mov  [DI + 0003h], byte ptr '.'
	     mov  [DI + 0004h], byte ptr 'C'
	     mov  [DI + 0005h], byte ptr 'O'
	     mov  [DI + 0006h], byte ptr 'M'
	     mov  [DI + 0007h], byte ptr 0h
	     pop  DI
;--------------------------------------------------------------------------------------------		 
	mov  KEEP_SP, SP	                      ;сохраняем содержимое регистров SS и SP
	mov  KEEP_SS, SS
	push DS
	pop  ES
	mov  BX, offset ParameterBlock
	mov  DX, offset PATH
	mov  AX, 4B00h                                ;вызываем загрузчик OS
	int  21h
	jnc  is_loaded                                ;если вызываемая программа не была загружена, 
	                                              ;то устанавливается флаг переноса CF=1 и в AX заносится код ошибки
	push AX
	mov  AX, DATA
	mov  DS, AX
	pop  AX
	mov  SS,KEEP_SS;восстанавление DS, SS, SP
	mov  SP,KEEP_SP
	call NOT_LOADED_ERROR

	is_loaded:
	     mov  AX, 4d00h                           ;в AH - причина, в AL - код завершения
	     int  21h
             call RETURN_CODE 
	     ret		 
PROCESSING ENDP

CREATE_BP PROC NEAR
        mov AX, ES:[2Ch]
	mov ParameterBlock,  AX
	mov ParameterBlock + 0002h, ES                ;сегментный адрес параметров командной строки 
	mov ParameterBlock + 0004h, 0080h             ;смещение параметров комадной строки
	ret
CREATE_BP ENDP

RETURN_CODE PROC NEAR
	cmp  AH, 0000h                                ;нормальное завершение
	mov  DX, offset End_0       
	je   EXIT_CODE
	cmp  AH, 0001h                                ;завершение по Ctrl-Break
	mov  DX, offset End_1
	je   EXIT_CODE
	cmp  AH, 0002h                                ;завершение по ошибке устройства
	mov  DX, offset End_2
	je   EXIT_CODE
	cmp  AH, 0003h                                ;завершение по функции 31h, оставляющей программу резидентной
	mov  DX, offset End_3 

    EXIT_CODE:
             call LINE_OUTPUT                         ;выводим код завершения на экран
	     mov  DI, offset END_CODE
	     call BYTE_TO_HEX
	     add  DI, 000Bh
	     mov  [DI], AL
	     add  DI, 0001h
	     xchg AH, AL
	     mov  [DI], AL
	     mov  DX, offset END_CODE
	     call LINE_OUTPUT
	     xor  AL, AL
	     mov  AH, 4Ch
	     int  21h
RETURN_CODE ENDP

NOT_LOADED_ERROR PROC NEAR                            ;обработка ошибок, если программа не была выполнена
	cmp  AX, 0001h                                ;если номер функции неверен
	mov  DX, offset Err_1
	je   NOT_LOADED
	cmp  AX, 0002h                                ;если файл не найден
	mov  DX, offset Err_2
	je   NOT_LOADED
	cmp  AX, 0005h                                ;при ошибке диска
	mov  DX, offset Err_5
	je   NOT_LOADED
	cmp  AX, 0008h                                ;при недостаточном объёме памяти
	mov  DX, offset Err_8
	je   NOT_LOADED
	cmp  AX, 000Ah                                ;при неправильной строке среды
	mov  DX, offset Err_10
	je   NOT_LOADED
	cmp  AX, 000Bh                                ;если неверен формат
	mov  DX, offset Err_11
	
	NOT_LOADED:
	         call LINE_OUTPUT
		 xor  AL, AL
		 mov  AH, 4Ch
		 int  21h
NOT_LOADED_ERROR ENDP
;--------------------------------------------------------------------------------------------
BEGINNING:
	mov AX,DATA
	mov DS,AX
	call FREE_MEMORY
        call CREATE_BP	
	call PROCESSING
	xor  AL, AL
	mov  AH, 4Ch                                  ;выход 
	int  21h
    LAST_BYTE:
         CODE ENDS
         END START   
