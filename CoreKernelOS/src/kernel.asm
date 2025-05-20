[bits 32]

; Definicje stałych GDT
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

kernel_start:
  ; Przejście do trybu chronionego
  cli
  ; A20 zostało włączone przez bootloader, więc nie robimy tego tutaj
  lgdt [gdt_descriptor]

  mov eax, cr0
  or eax, 1
  mov cr0, eax

  jmp dword CODE_SEG:protected_mode_main

; --- Global Descriptor Table (GDT) ---
gdt_start:
; Null Descriptor
gdt_null:
  dd 0x0
  dd 0x0

; Code Segment Descriptor
gdt_code:
  dw 0xFFFF
  dw 0x0000
  db 0x00
  db 10011010b
  db 11001111b
  db 0x00

; Data Segment Descriptor
gdt_data:
  dw 0xFFFF
  dw 0x0000
  db 0x00
  db 10010010b
  db 11001111b
  db 0x00

gdt_end:

gdt_descriptor:
  dw gdt_end - gdt_start - 1
  dd gdt_start

[bits 32]
protected_mode_main:
  mov ax, DATA_SEG
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax
  mov esp, 0x90000

  push ebp
  mov ebp, esp
  sub esp, 4

  mov ah, 0x00
  int 0x1A
  mov ebx, ecx
  mov ecx, 0x0978

.wait_loop_32:
  mov ah, 0x00
  int 0x1A
  sub ecx, ebx
  jnz .wait_loop_32

  add esp, 4
  pop ebp

  pusha
  mov esi, system_version_msg
  call print_string_32
  popa

  call mini_shell_32

print_string_32:
  pusha
  mov ebx, 0x0002
  mov ah, 0x0E
.repeat_next_char_32:
  lodsb
  cmp al, 0
  je .done_print_32
  int 0x10
  jmp .repeat_next_char_32
.done_print_32:
  popa
  ret

mini_shell_32:
  pusha
.shell_loop_32:
  mov esi, prompt_string
  call print_string_32

  mov ecx, 0
  mov edi, command_buffer_32
.read_command_32:
  mov ah, 0x00
  int 0x16
  cmp al, 0x0D
  je .command_ready_32
  cmp al, 0x08
  je .handle_backspace_32
  cmp ecx, 255
  je .read_command_32

  mov [edi+ecx], al
  mov ah, 0x0E
  int 0x10
  inc ecx
  jmp .read_command_32

.handle_backspace_32:
  cmp ecx, 0
  je .read_command_32
  dec ecx
  mov ah, 0x0E
  mov al, ' '
  int 0x10
  mov al, 0x08
  int 0x10
  jmp .read_command_32

.command_ready_32:
  mov ah, 0x0E
  mov al, 0x0A
  int 0x10
  mov al, 0x0D
  int 0x10
  mov [edi+ecx], byte 0
  call execute_command_32
  jmp .shell_loop_32

execute_command_32:
  pusha
  mov esi, command_buffer_32

  ; Porównaj "help"
  mov edi, help_command
  call string_compare_32
  cmp eax, 0
  je .handle_help_command_32

  ; Porównaj "clear"
  mov edi, clear_command
  call string_compare_32
  cmp eax, 0
  je .handle_clear_command_32

  ; Nieznane polecenie
  mov esi, unknown_command_message
  call print_string_32
  jmp .command_end_32

.handle_help_command_32:
  mov esi, help_message
  call print_string_32
  jmp .command_end_32

.handle_clear_command_32:
  call clear_screen_32
  jmp .command_end_32

.command_end_32:
  popa
  ret

clear_screen_32:
  pusha
  mov ah, 0x00
  mov al, 0x03
  int 0x10

  mov ah, 0x02
  mov bh, 0x00
  mov dh, 0x00
  mov dl, 0x00
  int 0x10
  popa
  ret

string_compare_32:
  pusha
  xor eax, eax
.compare_loop_32:
  mov al, [esi]
  mov bl, [edi]
  cmp al, 0
  je .end_of_string_32
  cmp al, bl
  jne .not_equal_32
  inc esi
  inc edi
  jmp .compare_loop_32
.end_of_string_32:
  cmp bl, 0
  je .equal_32
.not_equal_32:
  mov eax, 1
.equal_32:
  popa
  ret

; Dane dla jądra
system_version_msg db 'CoreKernelOS version: Alpha 1.0.0', 13, 10, 0
prompt_string      db 'CKS> ', 0
command_buffer_32  db 256 dup (0)
unknown_command_message db 'Unknown command', 13, 10, 0
help_command       db 'help', 0
clear_command      db 'clear', 0
help_message       db 'Available commands: help, clear', 13, 10, 0