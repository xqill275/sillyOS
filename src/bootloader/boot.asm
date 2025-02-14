org 0x7C00
bits 16

;
;  prints a string to the screen
;  params:
;	- ds:si points to string


%define ENDL 0x0D, 0x0A

;
; FAT12 header
;
jmp short start
nop

bdp_oem:                     db 'MSWIN4.1'  ; 8 bytes
bdp_bytes_per_sector:        dw 512
bdp_bytes_per_cluster:       db 1
bdb_reserved_sectors:        dw 1
bdb_dat_count:               db 2
bdb_dir_entries_count:       dw 0E0h
bdb_total_sectors:           dw 2880         ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:   db 0F0h         ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:         dw 9            ;9 sectors/fat
bdb_sectors_per_track:       dw 18
bdb_heads:                   dw 2
bdb_hidden_sectors:          dd 0
bdb_large_sector_count:      dd 0

; extended boot record
ebr_drive_number: db 0
                  db 0
ebr_signature: dd 29h
ebr_volume_id: db 12h, 34h, 56h, 78h
ebr_volume_label: db 'SILLY OS   '
EBR_SYSTEM_ID: db 'FAT12    '



; CODE GOES HERE: 

start:
    jmp main

puts:
    push si
    push ax

.loop:
    lodsb  ;loads next character in al
    or al, al ;verify if next charachter is null?
    jz .done
    mov ah, 0x0e
    mov bh, 0
    int 0x10
    
    jmp .loop

.done:
    pop ax
    pop si
    ret


main:

    ; setup data segments
    mov ax, 0  ; can't write to ds/es directly
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00 ;stack grows downwards from where we are loaded in memory

    ; read something from disk
    ; BIOS should set dl to drive number
    mov [ebr_drive_number], dl
    mov ax, 1
    mov cl, 1
    mov bx, 0x7E00
    call disk_read

    ; print message
    mov si, msg_helloWorld
    call puts

    cli
    hlt

;
; error handlers
;
floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot
    hlt

wait_key_and_reboot:
    mov ah, 0
    int 16h
    jmp 0FFFFH:0

.halt:
    cli
    jmp .halt


;
; Disk routines
;

;
; converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head

lba_to_chs:

    push ax
    push dx

    xor dx, dx ;dx = 0
    div word [bdb_sectors_per_track] ;ax = LBA / SectorsPerTrack
                                     ; dx = LBA % SectorsPerTrack

    inc dx
    mov cx, dx

    xor dx, dx
    div word [bdb_heads]

    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah

    pop ax
    mov dl, al
    pop ax

    ret


;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store the data 

disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax
    mov ah, 02h
    mov di, 3

.retry:
    pusha
    stc 
    int 13h
    jnc .done

    ; read failed
    popa
    call disk_reset
    test di, di
    jnz .retry
.fail
    ; after all attempts are exhausted
    jmp floppy_error

.done:

    popa
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    

; Resets disk controller
; Parameters:
;   - dl: drive number
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_helloWorld: db 'Hello world!', ENDL, 0
msg_read_failed: db 'Failed to read from disk!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h


