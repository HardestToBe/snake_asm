#!/bin/bash

nasm -f bin boot.asm -o boot.bin -l snake.lst
nasm -f bin snake.asm -o snake.bin -l snake.lst

if [ -f "os.img" ]; then
    echo "os.img已存在,直接写入"
else
    echo "生成os.img"
    dd if=/dev/zero of=os.img bs=512 count=2880 status=none
fi

dd if=boot.bin of=os.img bs=512 seek=0 conv=notrunc status=none

dd if=snake.bin of=os.img bs=512 seek=1 conv=notrunc status=none
