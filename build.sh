dd if=/dev/zero of=gluos.img bs=512 count=4096 &> dd_log

# Assemble the kernel loader
cd kernel/boot
nasm kernel_loader.asm -o kernel_loader -f bin
cd -

mv kernel/boot/kernel_loader fsroot/boot/kernel_loader

./application/glufs/build/archiver --input ./fsroot/ --output ./tmp --preserve-index --preserve-data
rm tmp

dd if=glufs.data of=gluos.img bs=512 conv=notrunc seek=0 &> dd_log
dd if=glufs.index of=gluos.img bs=1 count=16 seek=494 conv=notrunc &> dd_log

cd kernel/boot
# Add the bootloader proper to the disk image
./gluos_bootloader.sh ../../gluos.img ../../glufs.index ../../glufs.data
cd -


dd if=glufs.index of=gluos.img bs=1 skip=16 seek=$(($(stat -c %s gluos.img) - $(stat -c %s glufs.index) + 16)) conv=notrunc &> dd_log

qemu-system-i386 -hda gluos.img -s &
gdb -ex 'target remote localhost:1234'
kill $?
