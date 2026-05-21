; ============================================================================
;  lista.asm
;  Listas ligadas simples. Soporta múltiples listas independientes.
;
;  Estructura del nodo (8 bytes):
;     offset 0 : dato       (4 bytes)
;     offset 4 : siguiente  (4 bytes)
;
;  Cabeza de lista: cada lista se representa por un puntero al primer nodo.
;  Se mantiene un arreglo de hasta MAX_LISTAS cabezas.
;
;  Ensamblador: NASM, sintaxis Intel, x86 (32 bits), Linux.
; ============================================================================

section .data
        global  listas
        global  num_listas
        global  lista_activa

        MAX_LISTAS      equ 10
        TAM_NODO        equ 8
        OFF_DATO        equ 0
        OFF_SIG_N       equ 4

        ; Arreglo de cabezas de lista (punteros)
        listas          times MAX_LISTAS dd 0
        num_listas      dd 0          ; cuántas listas existen
        lista_activa    dd -1         ; índice de la lista actualmente activa

        msg_lista_n     db "Lista #", 0
        msg_dospuntos   db ": ", 0
        msg_flecha      db " -> ", 0
        msg_vacia       db "(vacía)", 10, 0
        msg_nl_l        db 10, 0
        msg_creada      db "Lista creada con índice ", 0
        msg_no_activa   db "No hay lista activa.", 10, 0
        msg_max         db "Máximo de listas alcanzado.", 10, 0
        msg_sel_ok      db "Lista activa establecida.", 10, 0
        msg_sel_err     db "Índice de lista inválido.", 10, 0
        msg_ins_ok      db "Nodo insertado.", 10, 0
        msg_ins_err     db "Error: no se pudo reservar memoria.", 10, 0
        msg_elim_ok     db "Nodo eliminado.", 10, 0
        msg_elim_err    db "Nodo no encontrado.", 10, 0

section .text
        extern  heap_alloc
        extern  heap_free
        extern  imprimir_cadena
        extern  imprimir_entero

        global  lista_crear
        global  lista_seleccionar
        global  lista_insertar
        global  lista_eliminar
        global  lista_mostrar
        global  lista_mostrar_todas

; ----------------------------------------------------------------------------
;  lista_crear
;  Crea una nueva lista vacía. La lista creada queda como activa.
;  Retorna eax = índice de la lista creada, o -1 si no caben más.
; ----------------------------------------------------------------------------
lista_crear:
        push    ebp
        mov     ebp, esp

        mov     eax, [num_listas]
        cmp     eax, MAX_LISTAS
        jge     .lleno

        ; listas[num_listas] = NULL (ya es 0, pero por claridad)
        mov     dword [listas + eax*4], 0
        mov     [lista_activa], eax
        inc     dword [num_listas]

        push    eax                 ; preservar índice en la pila

        push    msg_creada
        call    imprimir_cadena
        add     esp, 4

        mov     eax, [esp]          ; recuperar índice (sin sacarlo aún)
        push    eax
        call    imprimir_entero
        add     esp, 4

        push    msg_nl_l
        call    imprimir_cadena
        add     esp, 4

        pop     eax                 ; restaurar índice como valor de retorno
        pop     ebp
        ret

.lleno:
        push    msg_max
        call    imprimir_cadena
        add     esp, 4
        mov     eax, -1
        pop     ebp
        ret

; ----------------------------------------------------------------------------
;  lista_seleccionar(indice)
;  Cambia la lista activa.
; ----------------------------------------------------------------------------
lista_seleccionar:
        push    ebp
        mov     ebp, esp

        mov     eax, [ebp + 8]
        cmp     eax, 0
        jl      .err
        cmp     eax, [num_listas]
        jge     .err

        mov     [lista_activa], eax
        push    msg_sel_ok
        call    imprimir_cadena
        add     esp, 4
        pop     ebp
        ret

.err:
        push    msg_sel_err
        call    imprimir_cadena
        add     esp, 4
        pop     ebp
        ret

; ----------------------------------------------------------------------------
;  lista_insertar(dato)
;  Inserta un nuevo nodo al final de la lista activa.
; ----------------------------------------------------------------------------
lista_insertar:
        push    ebp
        mov     ebp, esp
        push    ebx
        push    ecx
        push    edx

        mov     eax, [lista_activa]
        cmp     eax, 0
        jl      .no_activa

        ; Reservar memoria para el nuevo nodo
        push    TAM_NODO
        call    heap_alloc
        add     esp, 4
        test    eax, eax
        jz      .sin_mem

        mov     ebx, eax                      ; ebx = nuevo nodo
        mov     ecx, [ebp + 8]
        mov     [ebx + OFF_DATO], ecx
        mov     dword [ebx + OFF_SIG_N], 0

        ; Insertar al final
        mov     edx, [lista_activa]
        mov     eax, [listas + edx*4]
        test    eax, eax
        jnz     .recorrer

        ; Lista vacía: el nuevo nodo es la cabeza
        mov     [listas + edx*4], ebx
        jmp     .ok

.recorrer:
        mov     ecx, [eax + OFF_SIG_N]
        test    ecx, ecx
        jz      .enlazar
        mov     eax, ecx
        jmp     .recorrer

.enlazar:
        mov     [eax + OFF_SIG_N], ebx

.ok:
        push    msg_ins_ok
        call    imprimir_cadena
        add     esp, 4
        jmp     .fin

.no_activa:
        push    msg_no_activa
        call    imprimir_cadena
        add     esp, 4
        jmp     .fin

.sin_mem:
        push    msg_ins_err
        call    imprimir_cadena
        add     esp, 4

.fin:
        pop     edx
        pop     ecx
        pop     ebx
        pop     ebp
        ret

; ----------------------------------------------------------------------------
;  lista_eliminar(dato)
;  Elimina el primer nodo cuyo valor coincide con 'dato' en la lista activa.
;  Libera la memoria del nodo en el heap.
; ----------------------------------------------------------------------------
lista_eliminar:
        push    ebp
        mov     ebp, esp
        push    ebx
        push    ecx
        push    edx
        push    esi

        mov     eax, [lista_activa]
        cmp     eax, 0
        jl      .no_act

        mov     ecx, [ebp + 8]                ; dato buscado
        mov     edx, [lista_activa]
        mov     ebx, [listas + edx*4]         ; nodo actual
        xor     esi, esi                      ; anterior = NULL

        test    ebx, ebx
        jz      .no_encontrado

.buscar_n:
        cmp     [ebx + OFF_DATO], ecx
        je      .encontrado
        mov     esi, ebx
        mov     ebx, [ebx + OFF_SIG_N]
        test    ebx, ebx
        jnz     .buscar_n
        jmp     .no_encontrado

.encontrado:
        mov     eax, [ebx + OFF_SIG_N]
        test    esi, esi
        jz      .es_cabeza
        mov     [esi + OFF_SIG_N], eax
        jmp     .liberar
.es_cabeza:
        mov     [listas + edx*4], eax

.liberar:
        push    ebx
        call    heap_free
        add     esp, 4

        push    msg_elim_ok
        call    imprimir_cadena
        add     esp, 4
        jmp     .fin_e

.no_encontrado:
        push    msg_elim_err
        call    imprimir_cadena
        add     esp, 4
        jmp     .fin_e

.no_act:
        push    msg_no_activa
        call    imprimir_cadena
        add     esp, 4

.fin_e:
        pop     esi
        pop     edx
        pop     ecx
        pop     ebx
        pop     ebp
        ret

; ----------------------------------------------------------------------------
;  lista_mostrar
;  Imprime la lista activa.
; ----------------------------------------------------------------------------
lista_mostrar:
        push    ebp
        mov     ebp, esp
        push    ebx

        mov     eax, [lista_activa]
        cmp     eax, 0
        jl      .no_act_m

        push    msg_lista_n
        call    imprimir_cadena
        add     esp, 4

        push    dword [lista_activa]
        call    imprimir_entero
        add     esp, 4

        push    msg_dospuntos
        call    imprimir_cadena
        add     esp, 4

        mov     eax, [lista_activa]
        mov     ebx, [listas + eax*4]
        test    ebx, ebx
        jz      .vacia

.recorrer_m:
        push    dword [ebx + OFF_DATO]
        call    imprimir_entero
        add     esp, 4

        mov     ebx, [ebx + OFF_SIG_N]
        test    ebx, ebx
        jz      .terminar
        push    msg_flecha
        call    imprimir_cadena
        add     esp, 4
        jmp     .recorrer_m

.terminar:
        push    msg_nl_l
        call    imprimir_cadena
        add     esp, 4
        jmp     .fin_m

.vacia:
        push    msg_vacia
        call    imprimir_cadena
        add     esp, 4
        jmp     .fin_m

.no_act_m:
        push    msg_no_activa
        call    imprimir_cadena
        add     esp, 4

.fin_m:
        pop     ebx
        pop     ebp
        ret

; ----------------------------------------------------------------------------
;  lista_mostrar_todas
;  Muestra todas las listas existentes (útil para verificar independencia).
; ----------------------------------------------------------------------------
lista_mostrar_todas:
        push    ebp
        mov     ebp, esp
        push    ebx
        push    ecx
        push    edx

        xor     ecx, ecx                      ; índice 0
.bucle:
        cmp     ecx, [num_listas]
        jge     .fin_t

        push    msg_lista_n
        call    imprimir_cadena
        add     esp, 4

        push    ecx
        call    imprimir_entero
        add     esp, 4

        push    msg_dospuntos
        call    imprimir_cadena
        add     esp, 4

        mov     ebx, [listas + ecx*4]
        test    ebx, ebx
        jz      .vacia_t

.rec_t:
        push    dword [ebx + OFF_DATO]
        call    imprimir_entero
        add     esp, 4

        mov     ebx, [ebx + OFF_SIG_N]
        test    ebx, ebx
        jz      .nl_t
        push    msg_flecha
        call    imprimir_cadena
        add     esp, 4
        jmp     .rec_t

.nl_t:
        push    msg_nl_l
        call    imprimir_cadena
        add     esp, 4
        jmp     .sig_lista

.vacia_t:
        push    msg_vacia
        call    imprimir_cadena
        add     esp, 4

.sig_lista:
        inc     ecx
        jmp     .bucle

.fin_t:
        pop     edx
        pop     ecx
        pop     ebx
        pop     ebp
        ret
