Sistema de listas ligadas y heap manual

Proyecto para la asignatura **Estructuras y programación de computadoras**, semestre 2026-2, Facultad de Ingeniería, UNAM.

Implementación en lenguaje ensamblador NASM (x86, 32 bits) de un sistema que permite crear y manipular múltiples listas ligadas simples, donde cada nodo se almacena en un heap administrado manualmente mediante una lista doblemente ligada de bloques de memoria.

Características

- Múltiples listas ligadas simples independientes.
- Menú interactivo por consola.
- Gestor de memoria propio (heap manual) basado en lista doblemente ligada.
- Estrategia de asignación **First Fit**.
- División de bloques cuando sobra espacio suficiente.
- Coalescencia: fusión automática de bloques libres adyacentes al liberar.
- Sin uso de funciones externas de memoria dinámica (no `malloc`, no `libc`).
- E/S por syscalls directas de Linux (`sys_read`, `sys_write`, `sys_brk`, `sys_exit`).

## Estructura del proyecto

```
proyecto/
├── src/
│   ├── heap.asm     # Gestor de memoria con lista doblemente ligada
│   ├── lista.asm    # Listas ligadas simples (múltiples listas)
│   └── main.asm     # Menú interactivo y funciones de E/S
├── Makefile
└── README.md
```

Modelo de datos

Nodo de lista simple 

| offset | campo      | tamaño |
|--------|------------|--------|
| 0      | dato       | 4 B    |
| 4      | siguiente  | 4 B    |

### Bloque del heap (cabecera de 16 bytes + datos)

| offset | campo          | tamaño |
|--------|----------------|--------|
| 0      | tamaño         | 4 B    |
| 4      | libre/ocupado  | 4 B    |
| 8      | siguiente      | 4 B    |
| 12     | anterior       | 4 B    |
| 16     | datos…         | n B    |

Compilación

```bash
make
```

Esto genera el ejecutable `listas` en la raíz del proyecto.

Otros objetivos del Makefile:

```bash
make run     # compila y ejecuta
make clean   # elimina objetos y binario
```

Uso

Al ejecutar `./listas` aparece el menú:

```
1. Crear nueva lista
2. Seleccionar lista
3. Insertar elemento
4. Eliminar elemento
5. Mostrar lista activa
6. Mostrar todas las listas
7. Mostrar estado del heap
8. Salir
```

Ejemplo de sesión

```
Opción: 1
Lista creada con índice 0
Opción: 3
Dato (entero): 10
Nodo insertado.
Opción: 3
Dato (entero): 20
Nodo insertado.
Opción: 1
Lista creada con índice 1
Opción: 3
Dato (entero): 100
Nodo insertado.
Opción: 6
Lista #0: 10 -> 20
Lista #1: 100
Opción: 7
--- Estado del heap ---
Bloque en 138915840  tam=8  [OCUPADO]
Bloque en 138915864  tam=8  [OCUPADO]
Bloque en 138915888  tam=8  [OCUPADO]
Bloque en 138915912  tam=65448 [LIBRE]
```

Detalles de implementación

Inicialización del heap

`heap_init` usa la syscall `sys_brk` (45) para reservar 64 KB del segmento de datos del proceso. Crea un único bloque libre que abarca todo el espacio.

Asignación (First Fit)

`heap_alloc(tam)` recorre la lista de bloques desde el inicio. El primer bloque libre con `tamaño >= tam` se utiliza. Si el sobrante es mayor a `TAM_CAB + 4`, el bloque se divide insertando un nuevo bloque libre con el remanente.

Liberación con coalescencia

`heap_free(ptr)` marca el bloque como libre y luego intenta fusionarlo con su vecino siguiente y con su vecino anterior si están libres. Esto evita la fragmentación.

Convenciones de registros

- Paso de parámetros: por pila (cdecl).
- Valor de retorno: `eax`.
- Registros preservados (callee-saved): `ebx`, `esi`, `edi`, `ebp`.
- Cada función documenta los registros que modifica.



Autor

Facultad de Ingeniería, UNAM.
Asignatura: Estructuras y programación de computadoras.
Profesora: Ing. Adara Mercado Martínez.

Integrantes: 
* Morales Basilio Alejandra Sofía
* Reyes García Miguel Ángel 
* Santos Cruz Lair Abraham
* Torres Rodriguez Lizeth Danae
