LR7_OVL1 SEGMENT 
ASSUME CS:LR7_OVL1, DS:LR7_OVL1, ES:NOTHING, SS:NOTHING
;--------------------------------------------------------------------------------------------
BEGINNING PROC FAR
	push DS
	push DX
	push DI
	push AX
	mov  AX, CS
	mov  DS, AX
	lea  BX, StrForPrint
	add  BX, 46h			
	mov  DI, BX	
	mov  AX, CS			
	call WRD_TO_HEX
	lea  DX, StrForPrint	
	call LINE_OUTPUT
	pop  AX
	pop  DI
	pop  DX	
	pop  DS
	retf
BEGINNING ENDP
;--------------------------------------------------------------------------------------------
LINE_OUTPUT PROC NEAR                                 ;вывод строки 
	mov  AH, 0009h
	int  21h
	ret
LINE_OUTPUT ENDP
;--------------------------------------------------------------------------------------------
TETR_TO_HEX PROC near                                            
	and  AL, 0Fh                                                  
	cmp  AL, 09
	jbe  NEXT
	add  AL, 07
NEXT:   add AL, 30h
	ret
TETR_TO_HEX ENDP

BYTE_TO_HEX PROC near                                            
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
 
WRD_TO_HEX PROC near                                             
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
;--------------------------------------------------------------------------------------------
StrForPrint DB 0DH,0AH,'The address of the segment to which the first overlay is loaded:                 ',0DH,0AH,'$'
;--------------------------------------------------------------------------------------------
LR7_OVL1 ENDS
END
