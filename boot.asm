bits 16
org 0x7c00

start:
	; 初始化寄存器时关闭硬件中断,sti再打开
	cli
	xor ax, ax
	; mov [ds:boot_drive], dl
	mov ds, ax
	; bios中断都需要用栈，ss:sp
	mov ss, ax
	mov sp, 0x7c00
	; 保存bios传入的启动盘号
	mov [boot_drive], dl
	sti
	
read_loader:				;CHS定位法：扇区、柱面、磁头
	;设置读取数据目的地,es:bx
	xor ax, ax
	mov es, ax
	mov bx, 0x8000
	; 读取扇区
	mov ah, 0x02			;子功能号
	mov al, 10				;要读取的扇区数量
	mov ch, 0				;柱面号的低8位
	mov cl, 2				;低六位是扇区号，高2位是柱面号的高2位
	mov dh, 0				;磁头号
	mov dl, [boot_drive]	;驱动器号
	int 0x13
	; 返回结果放在CF和AH里，CF为0则读取成功，AH为状态码
	jc disk_error
	
	; 复位磁盘，如果不重试则没必要复位
	; 恢复启动盘号，通过 DL 传给 loader
	mov dl, [boot_drive]
	mov si, boot_message
	cld
.print:
	lodsb
	cmp al, 0
	je launch_loader
	
	mov ah, 0x0e
	mov bh, 0
	mov bl, 0x07
	int 0x10
	jmp .print
	
launch_loader:
	; 读取成功要跳转至新地址
	jmp 0x0000:0x8000

disk_error:
	; 打印失败信息
	mov si, disk_error_message
	; 清除方向标志DF，打印时根据DF决定si的加减
	cld
.print:
	lodsb
	cmp al, 0
	je hang
	
	mov ah, 0x0e
	mov bh, 0
	mov bl, 0x07
	int 0x10
	jmp .print
	
hang:
	jmp hang
	
	
boot_drive db 0
boot_message db "start boot...", 13, 10, 0
disk_error_message db "read loader error", 0
	
times 510 - ($ - $$) db 0
dw 0xaa55
