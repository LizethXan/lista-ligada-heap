; ============================================================================
;  heap.asm
;  Gestión manual de memoria mediante una lista doblemente ligada de bloques.
;
;  Estructura de cada bloque (cabecera de 16 bytes + datos):
;     offset 0  : tamaño         (4 bytes)  - tamaño del área de datos
;     offset 4  : libre/ocupado  (4 bytes)  - 0 = libre, 1 = ocupado
;     offset 8  : siguiente      (4 bytes)  - puntero al siguiente bloque
;     offset 12 : anterior       (4 bytes)  - puntero al bloque anterior
;     offset 16 : datos...
;
;  El heap se reserva mediante la syscall brk (sys_brk = 45) de Linux x86.
;  Estrategia de asignación: First Fit.
;  Al liberar se fusionan bloques libres adyacentes (coalescing).
;
;  Ensamblador: NASM, sintaxis Intel, x86 (32 bits), Linux.
; ============================================================================

section .data
        global heap_inicio
        global heap_fin
        heap_inicio     dd 0        ; dirección base del heap
        heap_fin        dd 0        ; dirección final actual del heap
        TAM_HEAP        equ 65536   ; 64 KB de heap

; Offsets de los campos de la cabecera de un bloque
        OFF_TAM         equ 0
        OFF_LIBRE       equ 4
        OFF_SIG         equ 8
        OFF_ANT         equ 12
        TAM_CAB         equ 16      ; tamaño total de la cabecera

section .text
        global heap_init
        global heap_alloc
        global heap_free
        global heap_mostrar

; ----------------------------------------------------------------------------
;  heap_init
;  Inicializa el heap reservando TAM_HEAP bytes mediante sys_brk.
;  Crea un único bloque libre que abarca toda la zona.
;  Registros usados: eax, ebx, ecx
; ----------------------------------------------------------------------------
heap_init:
        push    ebp
        mov     ebp, esp
        push    ebx
        push    ecx

        ; Obtener el "program break" actual (brk(0))
        mov     eax, 45             ; sys_brk
        xor     ebx, ebx
        int     0x80
        mov     [heap_inicio], eax  ; guardamos el inicio del heap

        ; Solicitar nuevo break = inicio + TAM_HEAP
        mov     ebx, eax
        add     ebx, TAM_HEAP
        mov     eax, 45
        int     0x80
        mov     [heap_fin], eax     ; final del heap reservado

        ; Crear bloque inicial libre que ocupa todo el heap
        mov     ecx, [heap_inicio]
        mov     eax, TAM_HEAP
        sub     eax, TAM_CAB
        mov     [ecx + OFF_TAM], eax    ; tamaño del área de datos
        mov     dword [ecx + OFF_LIBRE], 0    ; libre
        mov     dword [ecx + OFF_SIG], 0      ; no hay siguiente
        mov     dword [ecx + OFF_ANT], 0      ; no hay anterior

        pop     ecx
        pop     ebx
        pop     ebp
        ret

; ----------------------------------------------------------------------------
;  heap_alloc(tam)
;  Reserva un bloque de al menos 'tam' bytes y devuelve un puntero al área
;  de datos del bloque (no a la cabecera).
;
;  Parámetro:  [ebp+8] = tamaño solicitado en bytes
;  Retorna:    eax = puntero a los datos, o 0 si no hay memoria suficiente.
;
;  Estrategia: First Fit. Si el bloque encontrado es lo bastante grande,
;  se divide para no desperdiciar memoria.
; ----------------------------------------------------------------------------
heap_alloc:
        push    ebp
        mov     ebp, esp
        push    ebx
        push    ecx
        push    edx
        push    esi

        mov     ecx, [ebp + 8]      ; tamaño solicitado
        mov     ebx, [heap_inicio]  ; bloque actual a examinar

.buscar:
        test    ebx, ebx
        jz      .sin_memoria        ; recorrimos todo y no hay bloque

        cmp     dword [ebx + OFF_LIBRE], 0
        jne     .siguiente          ; ocupado, saltar

        mov     eax, [ebx + OFF_TAM]
        cmp     eax, ecx
        jl      .siguiente          ; demasiado pequeño

        ; -- Encontrado: ¿conviene dividirlo? --
        ; Solo dividimos si sobra al menos TAM_CAB + 4 bytes
        mov     edx, eax
        sub     edx, ecx            ; espacio sobrante
        cmp     edx, TAM_CAB + 4
        jl      .usar_completo

        ; -- Dividir el bloque --
        ; nuevo_bloque = bloque + TAM_CAB + tam_solicitado
        mov     esi, ebx
        add     esi, TAM_CAB
        add     esi, ecx            ; esi = dirección del nuevo bloque libre

        ; Configurar nuevo bloque libre con el sobrante
        sub     edx, TAM_CAB        ; tamaño del nuevo bloque = sobrante - cabecera
        mov     [esi + OFF_TAM], edx
        mov     dword [esi + OFF_LIBRE], 0

        ; Enlazar: nuevo->sig = bloque->sig ; nuevo->ant = bloque
        mov     eax, [ebx + OFF_SIG]
        mov     [esi + OFF_SIG], eax
        mov     [esi + OFF_ANT], ebx

        ; Si bloque tenía siguiente, su anterior ahora es 'nuevo'
        test    eax, eax
        jz      .sin_sig_div
        mov     [eax + OFF_ANT], esi
.sin_sig_div:
        mov     [ebx + OFF_SIG], esi
        mov     [ebx + OFF_TAM], ecx    ; ajustar tamaño del bloque usado

.usar_completo:
        mov     dword [ebx + OFF_LIBRE], 1    ; marcar como ocupado
        lea     eax, [ebx + TAM_CAB]          ; puntero a los datos
        jmp     .fin

.siguiente:
        mov     ebx, [ebx + OFF_SIG]
        jmp     .buscar

.sin_memoria:
        xor     eax, eax

.fin:
        pop     esi
        pop     edx
        pop     ecx
        pop     ebx
        pop     ebp
        ret

; ----------------------------------------------------------------------------
;  heap_free(ptr)
;  Libera el bloque cuyo área de datos comienza en 'ptr' y fusiona con
;  bloques libres adyacentes si los hay.
;
;  Parámetro: [ebp+8] = puntero al área de datos a liberar
; ----------------------------------------------------------------------------
heap_free:
        push    ebp
        mov     ebp, esp
        push    ebx
        push    ecx
        push    edx

        mov     ebx, [ebp + 8]
        test    ebx, ebx
        jz      .fin                ; ptr nulo, nada que hacer

        sub     ebx, TAM_CAB        ; ebx = dirección de la cabecera
        mov     dword [ebx + OFF_LIBRE], 0    ; marcar como libre

        ; -- Intentar fusionar con el siguiente si está libre --
        mov     ecx, [ebx + OFF_SIG]
        test    ecx, ecx
        jz      .check_anterior
        cmp     dword [ecx + OFF_LIBRE], 0
        jne     .check_anterior

        ; Fusionar bloque actual con el siguiente
        mov     eax, [ecx + OFF_TAM]
        add     eax, TAM_CAB
        add     [ebx + OFF_TAM], eax        ; sumar tamaño + cabecera

        mov     edx, [ecx + OFF_SIG]
        mov     [ebx + OFF_SIG], edx
        test    edx, edx
        jz      .check_anterior
        mov     [edx + OFF_ANT], ebx

.check_anterior:
        ; -- Intentar fusionar con el anterior si está libre --
        mov     ecx, [ebx + OFF_ANT]
        test    ecx, ecx
        jz      .fin
        cmp     dword [ecx + OFF_LIBRE], 0
        jne     .fin

        ; Fusionar anterior con el actual
        mov     eax, [ebx + OFF_TAM]
        add     eax, TAM_CAB
        add     [ecx + OFF_TAM], eax

        mov     edx, [ebx + OFF_SIG]
        mov     [ecx + OFF_SIG], edx
        test    edx, edx
        jz      .fin
        mov     [edx + OFF_ANT], ecx

.fin:
        pop     edx
        pop     ecx
        pop     ebx
        pop     ebp
        ret

; ----------------------------------------------------------------------------
;  heap_mostrar
;  Recorre el heap e imprime el estado de cada bloque para depuración.
; ----------------------------------------------------------------------------
section .data
        msg_estado_h    db "--- Estado del heap ---", 10, 0
        msg_bloque      db "Bloque en ", 0
        msg_tam_h       db "  tam=", 0
        msg_libre       db "  [LIBRE]", 10, 0
        msg_ocupado     db "  [OCUPADO]", 10, 0
        msg_nl          db 10, 0

section .text
        extern  imprimir_cadena
        extern  imprimir_entero

heap_mostrar:
        push    ebp
        mov     ebp, esp
        push    ebx

        push    msg_estado_h
        call    imprimir_cadena
        add     esp, 4

        mov     ebx, [heap_inicio]
.recorrer:
        test    ebx, ebx
        jz      .fin_h

        push    msg_bloque
        call    imprimir_cadena
        add     esp, 4

        push    ebx
        call    imprimir_entero
        add     esp, 4

        push    msg_tam_h
        call    imprimir_cadena
        add     esp, 4

        push    dword [ebx + OFF_TAM]
        call    imprimir_entero
        add     esp, 4

        cmp     dword [ebx + OFF_LIBRE], 0
        jne     .ocupado
        push    msg_libre
        jmp     .imp
.ocupado:
        push    msg_ocupado
.imp:
        call    imprimir_cadena
        add     esp, 4

        mov     ebx, [ebx + OFF_SIG]
        jmp     .recorrer

.fin_h:
        pop     ebx
        pop     ebp
        ret
