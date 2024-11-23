#!/bin/bash

# Parse command line arguments
case $# in
    3) ;;
    *) printf "Usage: gluos_bootloader.sh <gluos.img> <glufs.index> <glufs.data>\n"; exit 1;;
esac

# Function to get the file size
size_from_path() {
    echo $(stat -c %s "$1")
}

# Paths and sizes
GLUOS_IMAGE_PATH="$1"
GLUOS_IMAGE_SIZE=$(size_from_path "$GLUOS_IMAGE_PATH")

GLUFS_INDEX_PATH="$2"
GLUFS_INDEX_SIZE=$(size_from_path "$GLUFS_INDEX_PATH")

GLUFS_DATA_PATH="$3"
GLUFS_DATA_SIZE=$(size_from_path "$GLUFS_DATA_PATH")

# Compute the offset for the binary tree metadata
GLUFS_INDEX_OFFSET=$( printf "$GLUOS_IMAGE_SIZE - $GLUFS_INDEX_SIZE - 16\n" | bc )

# Compute the block offset for the binary tree metadata
GLUFS_INDEX_BLOCK=$( printf "obase=16;($GLUFS_INDEX_OFFSET+32) / 512\n" | bc )

# Assemble the bootloader fragments
printf "
global index_block 
index_block: dq 0x$GLUFS_INDEX_BLOCK
" > index_metadata.inc

# Assemble the bootloader proper
nasm boot.asm -o boot -f bin

# Write the index metadata to the bootloader
dd if=$GLUFS_INDEX_PATH of=boot bs=1 seek=494 count=16 conv=notrunc &> dd_log

# Write the bootloader to the boot sector of the target image
dd if=boot of="$GLUOS_IMAGE_PATH" bs=512 conv=notrunc &> dd_log
