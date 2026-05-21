; ============================================================================
;  main.asm
;  Programa principal: menú interactivo del sistema de listas ligadas.
;  Incluye funciones auxiliares de E/S (imprimir_cadena, imprimir_entero,
;  leer_entero) usadas por los otros módulos.
;
;  Ensamblador: NASM, sintaxis Intel, x86 (32 bits), Linux.
;  Syscalls: sys_read (3), sys_write (4), sys_exit (1).
; ============================================================================

section .data
        msg_bienvenida  db "============================================", 10
                        db "  Sistema de listas ligadas y heap manual", 10
                        db "  UNAM - Estructuras y prog. de computadoras", 10
                        db "============================================", 10, 0

        menu            db 10
                        db "1. Crear nueva lista", 10
                        db "2. Seleccionar lista", 10
                        db "3. Insertar elemento", 10
                        db "4. Eliminar elemento", 10
                        db "5. Mostrar lista activa", 10
                        db "6. Mostrar todas las listas", 10
                        db "7. Mostrar estado del heap", 10
                        db "8. Salir", 10
                        db "Opción: ", 0

        msg_pide_dato   db "Dato (entero): ", 0
        msg_pide_idx    db "Índice de lista: ", 0
        msg_opc_inv     db "Opción inválida.", 10, 0
        msg_adios       db "Saliendo...", 10, 0

section .bss
        buffer          resb 32         ; buffer para entrada de texto

section .text
        global  _start
        global  imprimir_cadena
        global  imprimir_entero
        global  leer_entero

        extern  heap_init
        extern  heap_mostrar
        extern  lista_crear
        extern  lista_seleccionar
        extern  lista_insertar
        extern  lista_eliminar
        extern  lista_mostrar
        extern  lista_mostrar_todas

; ============================================================================
;  _start: punto de entrada
; ============================================================================
_start:
        call    heap_init

        push    msg_bienvenida
        call    imprimir_cadena
        add     esp, 4

.menu_loop:
        push    menu
        call    imprimir_cadena
        add     esp, 4

        call    leer_entero
        ; eax = opción

        cmp     eax, 1
        je      .op_crear
        cmp     eax, 2
        je      .op_sel
        cmp     eax, 3
        je      .op_ins
        cmp     eax, 4
        je      .op_elim
        cmp     eax, 5
        je      .op_mostrar
        cmp     eax, 6
        je      .op_todas
        cmp     eax, 7
        je      .op_heap
        cmp     eax, 8
        je      .salir

        push    msg_opc_inv
        call    imprimir_cadena
        add     esp, 4
        jmp     .menu_loop

.op_crear:
        call    lista_crear
        jmp     .menu_loop

.op_sel:
        push    msg_pide_idx
        call    imprimir_cadena
        add     esp, 4
        call    leer_entero
        push    eax
        call    lista_seleccionar
        add     esp, 4
        jmp     .menu_loop

.op_ins:
        push    msg_pide_dato
        call    imprimir_cadena
        add     esp, 4
        call    leer_entero
        push    eax
        call    lista_insertar
        add     esp, 4
        jmp     .menu_loop

.op_elim:
        push    msg_pide_dato
        call    imprimir_cadena
        add     esp, 4
        call    leer_entero
        push    eax
        call    lista_eliminar
        add     esp, 4
        jmp     .menu_loop

.op_mostrar:
        call    lista_mostrar
        jmp     .menu_loop

.op_todas:
        call    lista_mostrar_todas
        jmp     .menu_loop

.op_heap:
        call    heap_mostrar
        jmp     .menu_loop

.salir:
        push    msg_adios
        call    imprimir_cadena
        add     esp, 4

        mov     eax, 1                  ; sys_exit
        xor     ebx, ebx
        int     0x80

; ============================================================================
;  imprimir_cadena(ptr)
;  Imprime una cadena terminada en 0 (estilo C) a stdout.
; ============================================================================
imprimir_cadena:
        push    ebp
        mov     ebp, esp
        push    ebx
        push    ecx
        push    edx

        mov     ecx, [ebp + 8]          ; puntero a cadena
        xor     edx, edx                ; contador de longitud
.contar:
        cmp     byte [ecx + edx], 0
        je      .imprimir
        inc     edx
        jmp     .contar

.imprimir:
        mov     eax, 4                  ; sys_write
        mov     ebx, 1                  ; stdout
        int     0x80

        pop     edx
        pop     ecx
        pop     ebx
        pop     ebp
        ret

; ============================================================================
;  imprimir_entero(n)
;  Imprime un entero de 32 bits con signo a stdout.
; ============================================================================
imprimir_entero:
        push    ebp
        mov     ebp, esp
        push    ebx
        push    ecx
        push    edx
        push    esi
        push    edi

        mov     eax, [ebp + 8]          ; número a imprimir

        ; Reservar 16 bytes en la pila para el buffer de dígitos
        sub     esp, 16
        mov     edi, esp
        add     edi, 15                 ; apuntar al final del buffer
        mov     byte [edi], 0           ; terminador nulo
        dec     edi

        ; ¿Negativo?
        xor     ebx, ebx                ; flag de signo
        test    eax, eax
        jns     .check_cero
        neg     eax
        mov     ebx, 1

.check_cero:
        xor     esi, esi                ; contador de dígitos escritos
        test    eax, eax
        jnz     .dividir
        ; Caso especial: n=0
        mov     byte [edi], '0'
        dec     edi
        inc     esi
        jmp     .firma

.dividir:
        xor     edx, edx
        mov     ecx, 10
        div     ecx                     ; eax = eax/10, edx = resto
        add     dl, '0'
        mov     [edi], dl
        dec     edi
        inc     esi
        test    eax, eax
        jnz     .dividir

.firma:
        ; Si era negativo, agregar '-'
        test    ebx, ebx
        jz      .imp_num
        mov     byte [edi], '-'
        dec     edi

.imp_num:
        inc     edi                     ; edi apunta al primer carácter válido
        push    edi
        call    imprimir_cadena
        add     esp, 4

        add     esp, 16                 ; liberar buffer

        pop     edi
        pop     esi
        pop     edx
        pop     ecx
        pop     ebx
        pop     ebp
        ret

; ============================================================================
;  leer_entero
;  Lee caracteres de stdin uno a uno hasta encontrar '\n' y convierte a entero.
;  Esto evita que múltiples números enviados juntos queden mezclados.
; ============================================================================
leer_entero:
        push    ebp
        mov     ebp, esp
        push    ebx
        push    ecx
        push    edx
        push    esi
        push    edi

        xor     eax, eax                ; acumulador
        xor     ebx, ebx                ; signo (0 = positivo)
        xor     edi, edi                ; flag: ¿ya leímos algún dígito?
        xor     esi, esi                ; flag: ¿ya pasamos el signo?

.leer_char:
        push    eax                     ; preservar acumulador
        mov     eax, 3                  ; sys_read
        mov     ebx, 0                  ; stdin
        mov     ecx, buffer
        mov     edx, 1                  ; un byte
        int     0x80
        mov     edx, eax                ; bytes leídos
        pop     eax

        test    edx, edx
        jle     .fin_l                  ; EOF o error

        movzx   ecx, byte [buffer]
        cmp     cl, 10                  ; '\n'
        je      .fin_signo
        cmp     cl, 13                  ; '\r' (por si acaso)
        je      .fin_signo

        ; Si aún no hay dígitos y no se ha leído signo, permitir '-' o '+'
        test    edi, edi
        jnz     .es_digito
        test    esi, esi
        jnz     .es_digito
        cmp     cl, '-'
        jne     .check_pos2
        mov     ebx, 1
        mov     esi, 1
        jmp     .leer_char
.check_pos2:
        cmp     cl, '+'
        jne     .es_digito
        mov     esi, 1
        jmp     .leer_char

.es_digito:
        cmp     cl, '0'
        jl      .leer_char              ; ignorar caracteres no dígitos
        cmp     cl, '9'
        jg      .leer_char
        sub     cl, '0'
        imul    eax, eax, 10
        add     eax, ecx
        mov     edi, 1                  ; ya tenemos al menos un dígito
        jmp     .leer_char

.fin_signo:
        test    ebx, ebx
        jz      .fin_l
        neg     eax

.fin_l:
        pop     edi
        pop     esi
        pop     edx
        pop     ecx
        pop     ebx
        pop     ebp
        ret
