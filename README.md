# Little Penguin - Linux Kernel Development

A 42 school project based on the **Eudyptula Challenge**, teaching Linux kernel development through 10 progressive assignments.

## Overview

| | |
|-------------|----------------------------------|
| **Author**  | zweng                            |
| **School**  | 42                               |
| **Target**  | Linux From Scratch (LFS) system  |
| **Kernel**  | 6.18.x (Linus's git tree)        |

## Assignments

| # | Title | Description | Status |
|---|-------|-------------|--------|
| 00 | Custom Kernel Build | Build and boot a kernel from Linus's git tree | Completed |
| 01 | Hello World Module | Basic kernel module with load/unload messages | Completed |
| 02 | EXTRAVERSION Patch | Kernel Makefile patch adding "-thor_kernel" | Completed |
| 03 | Coding Style Fix | Fix C file to comply with kernel coding style | Completed |
| 04 | USB Keyboard Hotplug | Auto-load module on USB keyboard plug-in | Completed |
| 05 | Misc Character Device | `/dev/fortytwo` device with read/write ops | Completed |
| 06 | Linux-next Kernel | Build and boot latest linux-next kernel | Completed |
| 07 | Debugfs Interface | `/sys/kernel/debug/fortytwo/` with id, jiffies, foo | Completed |
| 08 | Reverse Device Fix | Fix coding style and behavior of reverse module | Completed |
| 09 | Mount Points Listing | `/proc/mymounts` showing all mount points | Completed |

## Assignment Details

### Assignment 00 - Custom Kernel Build
Build Linus Torvalds' kernel from `git.kernel.org` with `CONFIG_LOCALVERSION_AUTO=y`.

**Deliverables:** `boot_log`, `.config`

### Assignment 01 - Hello World Module
Create a loadable kernel module:
- Prints `"Hello world!"` on load
- Prints `"Cleaning up module."` on unload

**Deliverables:** `main.c`, `Makefile`

### Assignment 02 - EXTRAVERSION Patch
Modify kernel Makefile to append `-thor_kernel` to `EXTRAVERSION`, following Linux patch submission standards.

**Deliverables:** `boot_log`, patch file

### Assignment 03 - Coding Style Fix
Fix provided C file to comply with `Documentation/CodingStyle`.

**Deliverables:** Corrected `main.c`

### Assignment 04 - USB Keyboard Hotplug
Modify Hello World module to auto-load when a USB keyboard is connected.
- USB driver using `usb_device_id` table
- Matches HID boot keyboards (Class 0x03, Subclass 0x01, Protocol 0x01)
- udev rules for automatic loading

**Deliverables:** `hello_usb_keyboard.c`, `hello-usb-keyboard.rules`, `Makefile`

### Assignment 05 - Misc Character Device
Create `/dev/fortytwo` misc device:
- **Read:** Returns student login (`zweng`)
- **Write:** Validates login, returns success or `-EINVAL`

**Deliverables:** `main.c`, `Makefile`

### Assignment 06 - Linux-next Kernel
Download, build, and boot the latest `linux-next` kernel (6.19.0-rc1-next-20251219).

**Deliverables:** `boot_log`

### Assignment 07 - Debugfs Interface
Create `/sys/kernel/debug/fortytwo/` directory with:

| File | Permissions | Description |
|------|-------------|-------------|
| `id` | 0666 | Read/write student login validation |
| `jiffies` | 0444 | Returns current jiffies value |
| `foo` | 0644 | Stores up to PAGE_SIZE bytes with mutex locking |

**Deliverables:** `main.c`, `Makefile`

### Assignment 08 - Reverse String Device Fix
Fix coding style and behavior of the "reverse" misc device module:
- **Write:** Stores input string
- **Read:** Returns reversed string

**Deliverables:** Corrected `main.c`

### Assignment 09 - Mount Points Listing
Create `/proc/mymounts` that lists all mount points:
```
device_name    mount_point
root           /
sys            /sys
proc           /proc
```

**Deliverables:** `main.c`, `Makefile`

## Build Instructions

### Building a Module
```bash
cd assignment01/    # or any assignment directory
make                # Build the module
make clean          # Clean build artifacts
```

### Loading/Unloading Modules
```bash
sudo insmod module_name.ko    # Load module
sudo rmmod module_name        # Unload module
dmesg | tail                  # Check kernel messages
```

### Verifying Coding Style
```bash
/path/to/kernel/scripts/checkpatch.pl --no-tree -f main.c
```

## Kernel APIs Covered

| API | Assignments | Description |
|-----|-------------|-------------|
| Module Framework | 01-09 | `module_init`, `module_exit`, `MODULE_LICENSE` |
| USB Drivers | 04 | `usb_register`, `usb_device_id`, `MODULE_DEVICE_TABLE` |
| Misc Devices | 05, 08 | `misc_register`, `file_operations` |
| Debugfs | 07 | `debugfs_create_dir`, `debugfs_create_file` |
| Procfs | 09 | `proc_create`, `seq_file` |
| Synchronization | 07 | `DEFINE_MUTEX`, `mutex_lock`, `mutex_unlock` |
| User Space I/O | 05, 07, 08 | `copy_from_user`, `copy_to_user`, `simple_read_from_buffer` |

## Coding Style

All code follows Linux kernel coding style:
- Tabs are 8 characters
- K&R braces
- No GNU coding standards
- `checkpatch.pl` compliant

## References

- [Linux Device Drivers, 3rd Edition](https://lwn.net/Kernel/LDD3/)
- [Kernel Documentation: CodingStyle](https://www.kernel.org/doc/html/latest/process/coding-style.html)
- [Kernel Documentation: SubmittingPatches](https://www.kernel.org/doc/html/latest/process/submitting-patches.html)
- [Eudyptula Challenge](http://eudyptula-challenge.org/)

## License

Kernel modules are licensed under GPL as required by the Linux kernel.
