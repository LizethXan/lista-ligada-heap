# =============================================================================
#  Makefile - Sistema de listas ligadas y heap manual
#  NASM x86 (32 bits) en Linux
# =============================================================================

ASM      = nasm
LD       = ld
ASMFLAGS = -f elf32 -g -F dwarf
LDFLAGS  = -m elf_i386

SRCDIR   = src
OBJS     = $(SRCDIR)/main.o $(SRCDIR)/lista.o $(SRCDIR)/heap.o
TARGET   = listas

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

$(SRCDIR)/%.o: $(SRCDIR)/%.asm
	$(ASM) $(ASMFLAGS) $< -o $@

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(SRCDIR)/*.o $(TARGET)
