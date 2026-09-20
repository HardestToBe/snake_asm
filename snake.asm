bits 16
org 0x8000

; 常量放最前面
; 移动方向
DIR_UP    equ 0
DIR_RIGHT equ 1
DIR_DOWN  equ 2
DIR_LEFT  equ 3

SNAKE_MAX_LENGTH equ 2000


init:
	cli
	xor ax, ax
	mov ds, ax
	mov ss, ax
	mov sp, 0x8000
	sti

; 进入80x25文本模式，在任意位置画一个O
; 初始化，进入80x25文本模式

menu:
.clear_screen:
	mov ah, 0x00
	mov al, 0x03
	int 0x10

	mov si, menu_message
	cld
.load_menu:

	lodsb
	
	cmp al, 0
	je .wait_key
	
	mov ah, 0x0e
	mov bh, 0
    int 0x10

    jmp .load_menu
.wait_key:
	; 阻塞地等待键盘输入，如果不加对于al的比较那就是任意键
	mov ah, 0
	int 0x16

; 在任意位置画一个O
game_init:
	; 清个屏先
	mov ax, 0x0003
	int 0x10
	;初始时间
	mov ah, 0
	int 0x1a
	mov [last_tick], dx
	; 初始化蛇的位置
	xor si, si
	push cx
	mov cl, [init_snake_x]
	mov ch, [init_snake_y]
.init_body:
	cmp si, [snake_length]
	jae .print_snake_head
	mov dl, cl
	mov byte [snake_x + si], dl
	mov dh, ch
	mov byte [snake_y + si], dh
	inc si
	dec cl		; 水平排列只要减少x
	jmp .init_body
	
	
.print_snake_head:
	pop cx
	; 蛇头
	; int10,ah=02为设置光标位置
	; BH = 显示页号,一般使用 0
	; DH = 行号 y,0 ~ 24
	; DL = 列号 x,0 ~ 79
	mov ah, 0x02
	mov bh, 0

	mov dh, [snake_y]
	mov dl, [snake_x]

	int 0x10
	
	; int10,ah=09为在光标位置输出字符
	; AL = 要输出的字符
	; BH = 显示页,通常 0
	; BL = 字符颜色属性
	; 常用颜色：00h  黑色，01h  蓝色，02h  绿色，04h  红色，07h  灰白色，0Ah  亮绿色，		
	; 0Ch; 亮红色，0Eh  黄色，0Fh  亮白色
	; CX = 输出多少次
	mov ah, 0x09
	mov al, 'O'
	mov bh, 0
	mov bl, 0x0A
	mov cx, 1
	int 0x10

	mov si, 1

.print_snake_body:
	;打印蛇身

	cmp si, [snake_length]
	jae  game_loop

	mov ah, 0x02
	mov bh, 0
	mov dh, [snake_y + si]
	mov dl, [snake_x + si]

	int 0x10

	mov ah, 0x09
	mov al, '*'
	mov bh, 0
	mov bl, 0x0A
	mov cx, 1
	int 0x10
	
	inc si
	jmp .print_snake_body

game_loop:
	
	call check_keyboard
	; 获取bios tick
	mov ah, 0
	int 0x1a

	mov ax, dx
	sub ax, [last_tick]

	cmp ax, [tick_interval]
	jb game_loop; 无符号小于

	mov [last_tick], dx

	call move_snake
	jmp game_loop


check_keyboard:
	; 有没有按键？
    mov ah, 0x01
    int 0x16
	jz .done	;没有按键就返回

	;读到按键就记录,AL = ASCII 码,AH = 键盘扫描码
    mov ah, 0x00
	int 0x16

    ; 检测之后，ah为扫描码，al为ascii码
    
    cmp ah, 0x48       ; ↑
    je .up

    cmp ah, 0x50       ; ↓
    je .down

    cmp ah, 0x4B       ; ←
    je .left

    cmp ah, 0x4D       ; →
    je .right

    jmp .done
    
; .up里面的.是一个局部标签，归属于离他最近的非局部标签，比如这里的.up全称就是check_keyboard.up
.up:
	cmp byte [direction], DIR_DOWN
	je .done
	mov byte [direction], DIR_UP
	jmp .done
.down:
	cmp byte [direction], DIR_UP
	je .done
    mov byte [direction], DIR_DOWN
    jmp .done
.left:
	cmp byte [direction], DIR_RIGHT
	je .done
    mov byte [direction], DIR_LEFT
    jmp .done
.right:
	cmp byte [direction], DIR_LEFT
	je .done
    mov byte [direction], DIR_RIGHT

.done:
    ret

; 检测蛇头
check_next_head:
	;先检测当前移动方向，如果操作数是内存则需要明确大小，不过另一边是寄存器的话就不用明确
	mov dl, [snake_x]
	mov dh, [snake_y]

	cmp byte [direction], DIR_UP
	je .up

	cmp byte [direction], DIR_DOWN
	je .down

	cmp byte [direction], DIR_LEFT
	je .left

	cmp byte [direction], DIR_RIGHT
	je .right
	;防止落入.up可以加一个明确的分支
	jmp .blocked

.up:
	cmp dh, 0
    je .blocked
	dec dh
	jmp .allowed

.down:
	cmp dh, 24
    jae .blocked
	inc dh
	jmp .allowed

.left:
	cmp dl, 0
    je .blocked
	dec dl
	jmp .allowed

.right:
	cmp dl, 79
    jae .blocked
	inc dl

.allowed:
	clc		; 清除进位标志，CF = 0，允许移动
	ret

.blocked:
	stc
	ret


; 移动蛇的位置
; 先检测蛇头下一步的边界，若有问题直接返回，无恙则清空原旧蛇，接着改变光标位置，最后在新位置生成蛇
move_snake:
	call check_next_head
	jc .end
	push dx		;保存蛇头坐标
	xor si, si

.clear:
	cmp si, [snake_length]
	jae .clean_si_before_change_xy
	; 设置光标
	mov ah, 0x02
	mov bh, 0
	mov dh, [snake_y + si]
	mov dl, [snake_x + si]
	int 0x10
	; 清空光标位置
	mov ah, 0x09
	mov al, ' '
	mov bh, 0
	mov bl, 0x0A
	mov cx, 1
	int 0x10

	inc si
	jmp .clear

.clean_si_before_change_xy:
	pop dx		; 恢复蛇头坐标
	xor si, si

.change_xy:
	cmp si, [snake_length]
	jae .draw

	; 把当前坐标先放入next_xy
	mov al, [snake_x + si]
	mov [next_x], al
	mov ah, [snake_y + si]
	mov [next_y], ah

	; 把x + 1 = x
	mov [snake_x + si], dl
	mov [snake_y + si], dh

	mov dl, [next_x]
	mov dh, [next_y]
	inc si
	jmp .change_xy

.draw:
	xor si, si

.set_cursor:
	cmp si, [snake_length]
    jae .end

	mov ah, 0x02
	mov bh, 0
	mov dh, [snake_y + si]
	mov dl, [snake_x + si]

	int 0x10

	mov al, '*'
	cmp si, 0
	jne .print
	mov al, 'O'
	
.print:
	mov ah, 0x09
	mov bh, 0
	mov bl, 0x0A
	mov cx, 1
	int 0x10

	inc si
	jmp .set_cursor

.end:
	ret

hang:
    jmp hang           ; 停留在这里，避免执行下面的数据
    
; 数据放代码之后
last_tick dw 0
tick_interval dw 6
direction db DIR_RIGHT	;蛇的方向
snake_length dw 10		;蛇当前长度
snake_x:				;蛇身x坐标
	times SNAKE_MAX_LENGTH db 0

snake_y:				;蛇身y坐标
	times SNAKE_MAX_LENGTH db 0
next_x db 0
next_y db 0
init_snake_x db 30
init_snake_y db 5


; 13,10分布代表光标回到当前行的开头以及光标移动到下一行
menu_message:
	db "Snake Game", 13, 10
	db "Press any button to enter...", 0

times 5632 - ($ - $$) db 0
