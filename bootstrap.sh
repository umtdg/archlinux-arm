#!/usr/bin/env bash

set -e

nbd='/dev/nbd0'
root_part="${nbd}p2"
boot_part="${nbd}p1"

root_part_uuid=''
boot_part_uuid=''

vm_image='arch-aarch64.qcow2'
root_dir='rootfs'
boot_dir="$root_dir/boot"

archlinux_arm_archive='ArchLinuxARM-aarch64-latest.tar.gz'
efi_img_file='RELEASEAARCH64_QEMU_EFI.fd'

assume_all_yes='true'
if [ "$assume_all_yes" = 'true' ]; then
    set -x
fi

function run() {
    printf '%s ' "run '$@' (y|s|n)?" > /dev/tty
    local answer='y'
    if [ "$assume_all_yes" = 'false' ]; then
        IFS= read -r answer < /dev/tty
    fi
    case $answer in
        [yY]*) "$@" ;; # run
        [sS]*) true ;; # do not run but continue
        *) false ;; # do not run and terminate
    esac

    echo
}

function set_part_uuids() {
    root_part_uuid="$(sudo blkid "$root_part" -o json | jq -r .uuid)"
    boot_part_uuid="$(sudo blkid "$boot_part" -o json | jq -r .uuid)"

    echo "$root_part: $root_part_uuid"
    echo "$boot_part: $boot_part_uuid"
}

function mount_vm_img() {
    run sudo modprobe -v nbd
    run sudo qemu-nbd -c "$nbd" "$vm_image"

    run sleep 1

    run sudo mkdir -pv "$root_dir"
    run sudo mount -v "$root_part" "$root_dir"

    run sudo mkdir -pv "$boot_dir"
    run sudo mount -v "$boot_part" "$boot_dir"
}

function umount_vm_img() {
    run sudo umount -v -R "$root_dir"
    run sudo sync
    run sudo qemu-nbd -d "$nbd"
    run sudo rmmod nbd
}

function create_vm_img() {
    run qemu-img create -f qcow2 "$vm_image" 64G

    run sudo modprobe -v nbd
    run sudo qemu-nbd -c "$nbd" "$vm_image"

    run sleep 1

    run sudo parted "$nbd" mklabel gpt
    run sudo parted "$nbd" mkpart P1 fat32 1MiB 501MiB
    run sudo parted "$nbd" set 1 esp on

    run sudo parted "$nbd" mkpart P2 ext4 501MiB 100%

    run sudo mkfs.fat -F32 "$boot_part"
    run sudo mkfs.ext4 "$root_part"

    run sudo fdisk -l "$nbd"

    run sudo qemu-nbd -d "$nbd"
}

function extract_archlinux_arm() {
    if [ ! -f "$archlinux_arm_archive" ]; then
        echo "Arch Linux ARM archive '$archlinux_arm_archive' is not found"
        run wget -q --show-progress "http://os.archlinuxarm.org/os/$archlinux_arm_archive"
    fi

    run sudo bsdtar -xpf "$archlinux_arm_archive" -C "$root_dir"
}

function create_flash_img() {
    run truncate -s 64M firmware.img
    run truncate -s 64M efivars.img

    if [ ! -f "$efi_img_file" ]; then
        echo "retrage/edk2-nightly $efi_img_file is required since as of writing this script, images in edk2-aarch64 doesn't work"
        run wget -q --show-progress "https://github.com/retrage/edk2-nightly/blob/master/bin/$efi_img_file"
    fi
    run dd if=RELEASEAARCH64_QEMU_EFI.fd of=firmware.img conv=notrunc
}

function modify_fstab() {
    {
        echo "UUID=$root_part_uuid  /       ext4    defaults    0 0"
        echo "UUID=$boot_part_uuid  /boot   vfat    defaults    0 0"
    } | sudo tee -a "$root_dir/etc/fstab"

    echo
    run cat "$root_dir/etc/fstab"
}

function create_startup_nsh() {
    {
        printf 'Image root=UUID=%s rw initrd=\initramfs-linux.img' "$root_part_uuid"
    } | sudo tee -a "$boot_dir/startup.nsh"

    echo
    run cat "$boot_dir/startup.nsh"
}

run sudo pacman -S qemu-full parted wget

run create_vm_img

run create_flash_img

run mount_vm_img

run extract_archlinux_arm

run set_part_uuids
run modify_fstab
run create_startup_nsh

run umount_vm_img
