EOFLine EQU '$'                                       ;определение символьной константы
                                                      ;$ - "конец строки"
ASTACK SEGMENT STACK
	DW 64 DUP (?)
ASTACK ENDS
;ДАННЫЕ
;--------------------------------------------------------------------------------------------
DATA SEGMENT
	Load_1    DB 0DH, 0AH,'The overlay was not been loaded: non-existent function!',0DH,0AH,EOFLine
	Load_10   DB 0DH, 0AH,'The overlay was not been loaded: incorrect environment!',0DH,0AH,EOFLine
	Load_4    DB 0DH, 0AH,'The overlay was not been loaded: too many open files!',0DH,0AH,EOFLine
	Load_3    DB 0DH, 0AH,'The overlay was not been loaded: route not found!',0DH,0AH,EOFLine
	Load_2    DB 0DH, 0AH,'The overlay was not been loaded: file not found!',0DH,0AH,EOFLine
	Load_8    DB 0DH, 0AH,'The overlay was not been loaded: low memory!',0DH,0AH,EOFLine
	Load_5    DB 0DH, 0AH,'The overlay was not been loaded: no access!',0DH,0AH,EOFLine	
	Mem_8     DB 0DH, 0AH,'Not enough memory to perform the function!',0DH,0AH,EOFLine	
	Err_alloc DB 0DH, 0AH,'Failed to allocate memory to load overlay!',0DH,0AH,EOFLine	
	Mem_9     DB 0DH, 0AH,'Wrong address of the memory block!',0DH,0AH,EOFLine
	Mem_7     DB 0DH, 0AH,'Memory control unit destroyed!',0DH,0AH,EOFLine
	File_3    DB 0DH, 0AH,'The route was not found!',0DH,0AH,EOFLine
	File_2    DB 0DH, 0AH,'The file was not found!',0DH,0AH,EOFLine
	Path      DB 'Path to file: ',EOFLine
	Ovl1	  DB 'LR7_OVL1.ovl',0000h
	Ovl2	  DB 'LR7_OVL2.ovl',0000h	
	OvlPath   DB 64	DUP (?),EOFLine 	
	DTA       DB 43 DUP (?)
	Keep_psp  DW 0000h
	SegAdr    DW 0000h
	CallAdr	  DD 0000h
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
DTA_SET PROC NEAR                                     ;установка адреса DTA блока
        push DX
        lea  DX, DTA                                  ;вычисление эффективного адреса, DS:DX на строку, содержащую имя файла с оверлеем
        mov  AH, 1Ah                                  ;установить адрес области обмена с диском (DTA)
        int  21h                                      ;вызов функции
        pop  DX
DTA_SET ENDP   	

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
	
        END_ERROR:                                    ;вывод ошибки на экран
	     call LINE_OUTPUT 
	     xor  AL, AL
	     mov  AH, 4Ch
	     int  21h
FREE_MEMORY ENDP

FIND_PATH PROC NEAR                                   ;поиск пути к файлу оверлея
	push ES
	mov  ES,  ES:[2CH]                            ;сегментный адрес среды, передаваемой программе
	xor  SI,  SI
	lea  DI,  OvlPath
		
        FIRST: 
             inc  SI                                  ;взятие следующего символа строки      
             cmp  word ptr ES:[SI], 0000h             ;проверка на то, что это конец строки
	     jne  FIRST                               ;переход, если не конец строки
	     add  SI, 0004h                           ;взятие следующего символа строки      
		
        SECOND:
	     cmp  byte ptr ES:[SI], 0000h             ;проверка на то, что это конец строки
	     je   THIRD                               ;если конец строки (два нулевых байта подряд)
	     mov  DL, ES:[SI]
	     mov  [DI], DL
	     inc  SI
	     inc  DI
	     jmp  SECOND  
		
        THIRD:
	     dec  SI                                  ;взятие предыдущего символа строки
	     dec  DI
	     cmp  byte ptr ES:[SI], '\'
	     jne  THIRD                               ;переход, если символ текущий не "\"
	     inc  DI                                  ;взятие следующего символа строки
	     mov  SI, BX
	     push DS
	     pop  ES
		
        FOURTH:
	     lodsb                                    ;чтение байта из строки по адресу DS:SI в AL
	     stosb                                    ;запись байта в строку, сохранить AL по адресу ES:DI 
	     cmp  AL, 0000h                           ;проверка на то, что это конец строки
	     jne  FOURTH                              ;переход, если не конец строки
	     mov  byte ptr [DI], EOFLine
	     mov  DX, offset Path                               
	     call LINE_OUTPUT
	     lea  DX, OvlPath
	     call LINE_OUTPUT
	     pop  ES
	     ret
FIND_PATH ENDP	

ALLOCATE_MEMORY_FOR_OVL PROC NEAR                     ;считывание размера оверлея и выделение памяти под этот файл
	push DS
	push DX
	push CX
	xor  CX, CX                                   ;CX - значение байта атрибутов для сравнения (для файла 0)
	lea  DX, OvlPath                              ;вычисление эффективного адреса, DS:DX = адрес ASCIIZ-строки с именем файла
	                                              ;ASCIIZ-строка - способ представления строки, при котором используется массив символов,а конец - нуль-символ
	mov  AH, 4Eh                                  ;функция 4Eh - поиск первого совпадающего символа
	int  21h                                      ;вызов функции
	jnc  FILE_IS_FOUND                            ;переход, если флаг CF=0 (нет ошибок, найдено совпадение)
	cmp  AX, 0003h                                ;в AX хранится код ошибки, если CF установлен
	je   ERROR_3                                  ;переход, если ошибка с кодом 0003h
	mov  DX, offset File_2                        ;если файл не был найден
	jmp  EXIT_ERROR
	
        ERROR_3:
	     mov  DX, offset File_3                   ;если маршрут не был найден
		 
        EXIT_ERROR:                                   ;вывод ошибки на экран
	     call LINE_OUTPUT
	     pop  CX
	     pop  DX
	     pop  DS
	     xor  AL, AL
	     mov  AH, 4Ch
	     int  21h
		 
        FILE_IS_FOUND:                                ;если файл был найден
	     push ES
	     push BX
	     mov  BX, offset DTA                      ;смещение на DTA
	     mov  DX, [BX + 1Ch]                      ;старшее слово размера памяти в байтах
	     mov  AX, [BX + 1Ah]                      ;младшее слово размера файла
	     mov  CL, 0004h                           ;перевод в параграфы младшего слова
	     shr  AX, CL                              ;сдвиг бит операнда вправо 
	     mov  CL, 000Ch 
	     sal  DX, CL                              ;переводим в байты и параграфы, сдвиг влево
	     add  AX, DX 
	     inc  AX                                  ;взятие большего целого числа параграфов
	     mov  BX, AX                              ;BX - запрошенное количество памяти в 16-байтовых параграфах
	     mov  AH, 48h                             ;распределить память (дать размер памяти)
	     int  21h 
	     jnc  MEMORY_ALLOCATED                    ;переход, если CF=0 (память выделена)
	     mov  DX, offset Err_alloc                ;вывод сообщеня об ошибке
	     call LINE_OUTPUT
	     xor  AL, AL
	     mov  AH, 4Ch
	     int  21h
		 
        MEMORY_ALLOCATED:
	     mov  SegAdr, AX                          ;SegAdr - сегментный адрес распределенного блока
	     pop  BX
	     pop  ES
	     pop  CX
	     pop  DX
	     pop  DS
	     ret
ALLOCATE_MEMORY_FOR_OVL ENDP    
	
PROGRAM_CALL_OVL PROC NEAR                            ;вызов программы оверлея
	push DX
	push BX
	push AX
	mov  BX, seg SegAdr
	mov  ES, BX
	lea  BX, SegAdr	                              ;ES:BX = адрес EPB (EXEC Parameter Block - блока параметров EXEC)
	lea  DX, OvlPath                              ;DS:DX = адрес строки ASCIIZ с именем файла, содержащего программу	
	mov  AX, 4B03h                                ;функция, которая загружает программный оверлей
	int  21h
	jnc  IS_LOADED                                ;переход, если нет ошибок
	
	ERROR_CHECK:
	     cmp  AX, 0001h                           ;несуществующий файл
	     lea  DX, Load_1
	     je   PRINT_ERROR
	     cmp  AX, 0002h                           ;файл не найден
	     lea  DX, Load_2
	     je   PRINT_ERROR
	     cmp  AX, 0003h                           ;маршрут не найден
	     lea  DX, Load_3
	     je   PRINT_ERROR
	     cmp  AX, 0004h                           ;слишком много открытых файлов
	     lea  DX, Load_4
	     je   PRINT_ERROR
	     cmp  AX, 0005h                           ;нет доступа
	     lea  DX, Load_5
	     je   PRINT_ERROR		 
	     cmp  AX, 0008h                           ;мало памяти
	     lea  DX, Load_8
	     je   PRINT_ERROR
	     cmp  AX, 000Ah                           ;неправильная среда
	     lea  DX, Load_10                 
		 
	PRINT_ERROR:                                  ;вывод сообщения об ошибки на экран
	     call LINE_OUTPUT
	     jmp  FINISH

        IS_LOADED:
	     mov  AX, DATA                            ;восстанавливаем DS
	     mov  DS, AX
	     mov  AX, SegAdr
	     mov  word ptr CallAdr + 0002h, AX
	     call CallAdr                             ;вызываем оверлейную программу
	     mov  AX, SegAdr
	     mov  ES, AX
	     mov  AX, 4900h                           ;освободить распределенный блок памяти
	     int  21h
	     mov  AX, DATA
	     mov  DS, AX
		 
	FINISH:
	     mov  ES, Keep_psp
	     pop  AX
	     pop  BX
	     pop  DX
	     ret
PROGRAM_CALL_OVL ENDP

PROCESSING PROC NEAR                                  ;обработка оверлея
        call FIND_PATH
        call ALLOCATE_MEMORY_FOR_OVL
        call PROGRAM_CALL_OVL
	ret
PROCESSING ENDP    
;--------------------------------------------------------------------------------------------
BEGINNING:
        mov  AX, DATA
	mov  DS, AX
	mov  Keep_psp, ES
	call FREE_MEMORY
	call DTA_SET
	lea  BX, Ovl1
	call PROCESSING
	lea  BX, Ovl2
	call PROCESSING
	xor  AL, AL
	mov  AH, 4Ch                                  ;выход
	int  21h
LAST_BYTE:
	CODE ENDS
        END  START
