[bits 16]
[org 0x07c00]

start:
  xor ax, ax
  mov ds, ax
  mov es, ax
  mov ss, ax
  mov sp, 0x7C00

  mov si, loading_system
  call print_string

  ; Włącz A20
  call enable_a20

  mov ah, 0x02
  mov al, 1
  mov ch, 0
  mov cl, 2
  mov dh, 0
  mov dl, 0x80
  mov bx, 0x8000
  int 0x13
  jc disk_error

  jmp 0x8000:0x0000

disk_error:
  mov si, disk_error_msg
  call print_string
  cli
  hlt

print_string:
  mov ah, 0x0E
.repeat_next_char:
  lodsb
  cmp al, 0
  je .done_print
  int 0x10
  jmp .repeat_next_char
.done_print:
  ret

enable_a20:
  in al, 0x92
  or al, 0x02
  out 0x92, al
  ret

loading_system    db 'Loading CoreKernelOS...', 13, 10, 0
disk_error_msg    db 'Disk read error!', 13, 10, 0

times 510-($-$$) db 0x00
dw 0xAA55