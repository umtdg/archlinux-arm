# archlinux-arm

## Creating VM

### Automated image creation

Running `bootstrap.sh` will:

- Install `qemu-full`, `parted`, and `wget` via `pacman`
- Create a 64GiB qcow2 image
- Load nbd kernel module and assign /dev/nbd0 to newly created qcow2 image
- Format /dev/nbd0:
  - Create a GPT partition table on /dev/nbd0
  - Create an 500MiB EFI partition
  - Create an ext4 partition for the rest of the disk
- Create UEFI flash images under `firmware.efi` and `efivars.efi`
  - Download nightly build of edk2 images from
    [retrage/edk2-nightly](https://github.com/retrage/edk2-nightly) since as
    of writing, images that come from Arch Linux's `edk2-aarch64` package
    doesn't seem to be working
  - Create `firmware.efi` and `efivars.efi` with size `64MiB` for both
  - `dd` the edk2 nightly image to `firmware.efi`
- Mount newly created partition under `rootfs` folder in the current directory
  - Create the mount point `rootfs`
  - Mount `/dev/nbd0p2` to `rootfs`
  - Create mount point for `/boot` in `rootfs/boot`
  - Mount `/dev/nbd0p1` to `rootfs/boot`
- Download the latest generic armv8 root tarball from Arch Linux ARM project:
  [http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz](http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz)
- Extract the tarball to `rootfs`
- Add `/` and `/boot` to `rootfs/etc/fstab` using their `UUID`s as identifiers
- Create `startup.nsh` for UEFI to read at `rootfs/boot/startup.nsh`
- Unmount `rootfs`
- Disconnect `/dev/nbd0` using `qemu-nbd`
- Remove `nbd` kernel module

## Running the system

```shell
$ qemu-system-aarch64 \
  -M virt \
  -m 8192 \
  -cpu cortex-a72 \
  -smp 8 \
  -drive if=pflash,media=disk,format=raw,cache=writethrough,file=firmware.img \
  -drive if=pflash,media=disk,format=raw,cache=writethrough,file=efivars.img \
  -drive if=none,file=arch-aarch64.qcow2,format=qcow2,id=hd0 \
  -device virtio-scsi-pci,id=scsi0 \
  -device scsi-hd,bus=scsi0.0,drive=hd0,bootindex=1 \
  -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22 \
  -monitor none -display none -vga none
```

- `-M virt`: Use latest available QEMU ARM Virtual Machine platform
- `-m 8192`: Give 8GiB RAM to the virtual machine, this value is in bytes
- `-cpu cortex-a72`: Use `cortex-a72` cpu. This cpu is chosen because it is the
  latest armv8 cpu available in QEMU
- `-smp 8`: Number of CPU cores to assign to the VM
- `-drive ... firmware.img`: This is for UEFI firmware
- `-drive ... efivars.img`: This is for writing EFI vars
- `-drive if=none,file=arch-aarch64.qcow2,format=qcow2,id=hd0`: This is the
  qcow2 image created by `bootstrap.sh`, name of this can be changed by moving
  or changing it in `bootstrap.sh` before running. Id `hd0` is given to use
  with `scsi-hd` configuration
- `-device virtio-scsi-pci,id=scsi0`: Adds VirtIO SCSI driver with id `scsi0`
- `-device scsi-hd,bus=scsi0.0,drive=hd0,bootindex=1`: Use `scsi-hd` for drive
  with id `hd0`, using `scsi0.0` and put it to the top of boot order
- `-nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22`: Use user mode
  networking using VirtIO drivers and forward guest port 22 to host port 2222.
  Port forwarding is for ssh access after running the system using
  `ssh -p 2222 alarm@localhost`
- `-monitor none -display none -vga none`: Do not open QEMU monitor, do not use
  display, and do not emulate any VGA card

### First Run

- Run the machine using [Running the system](#running-the-system)
- SSH using `alarm:alarm`
- Change to root user
- Initialize and populate Arch Linux ARM keyring,
- Update the system
- Install `efibootmgr` and write
- Poweroff

```shell
host$ ssh -o PreferredAuthentications=password -p 2222 alarm@localhost

guest$ su
guest# pacman-key --init
guest# pacman-key --populate archlinuxarm
guest# pacman -Syu
guest# pacman -S efibootmgr
guest# efibootmgr \
  --verbose \
  --unicode \
  --create \
  --disk /dev/sda \
  --part 1 \
  --label 'Arch Linux ARM' \
  --loader /Image \
  'root=UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX rw initrd=\initramfs-linux.img'
```

Where `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX` is root partition UUID, which can be obtained from either
`/etc/fstab` or `/boot/startup.nsh` in the **GUEST** machine.

### Second run

- Run the machine using [Running the system](#running-the-system)
- Do normal Arch Linux configuration (time, locales, users, software,
  configuration, etc.)

## TODO

- [ ] Automate the [First run](#first-run) step to reduce manual intervention
- [ ] Install GRUB and use it as a bootloader
- [ ] Automatically rename `alarm` user with a username of preference
- [ ] Have `bootstrap.sh` highly configurable
- [ ] Turn this into an installer ISO if possible
