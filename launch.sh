#!/usr/bin/env bash

machine='virt'
cpu='cortex-a72'
cores='6'
memory='8192'

firmware='firmware.img'
efivars='efivars.img'

image='arch-aarch64.qcow2'
image_format='qcow2'

iso=''
use_display='n'

_image_boot_index='1'
[ -n "${iso}" ] && _image_boot_index='2'

qemu='qemu-system-aarch64'
qemu_opts=(
    -M "${machine}"
    -cpu "${cpu}"
    -smp "${cores}"
    -m "${memory}"
    -monitor none
    -drive "if=pflash,media=disk,format=raw,cache=writethrough,file=${firmware}"
    -drive "if=pflash,media=disk,format=raw,cache=writethrough,file=${efivars}"
    -drive "if=none,file=${image},format=${image_format},id=hd0"
    -device "virtio-scsi-pci,id=scsi0"
    -device "scsi-hd,bus=scsi0.0,drive=hd0,bootindex=${_image_boot_index}"
)

if [ -n "${iso}" ]; then
    qemu_opts+=(
        -drive "if=none,file=${iso},media=cdrom,id=cd0"
        -device "virtio-scsi-pci,id=scsi1"
        -device "scsi-hd,bus=scsi0.0,drive=hd0,bootindex=${_image_boot_index}"
        -device "scsi-cd,bus=scsi1.0,drive=hd0,bootindex=1"
    )
fi

if [[ "${use_display}" =~ ^[nN]* ]]; then
    qemu_opts+=(-display none -vga none)
fi

echo "${qemu} ${qemu_opts[*]}"
"${qemu}" "${qemu_opts[@]}"
