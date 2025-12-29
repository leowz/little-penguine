# Assignment 06 - Linux-Next Kernel Report

A comprehensive guide to understanding and completing Assignment 06.

---

## Table of Contents

1. [Assignment Requirements](#assignment-requirements)
2. [What is linux-next?](#what-is-linux-next)
3. [The Linux Kernel Development Cycle](#the-linux-kernel-development-cycle)
4. [How Code Flows in the Kernel](#how-code-flows-in-the-kernel)
5. [Key Kernel Trees](#key-kernel-trees)
6. [Documentation/process/ Key Points](#documentationprocess-key-points)
7. [Step-by-Step Instructions](#step-by-step-instructions)
8. [Troubleshooting](#troubleshooting)

---

## Assignment Requirements

**From the subject:**

> **To Do:**
> - Download the latest `linux-next` kernel. It changes daily, so just use the most recent version.
> - Build it and boot it.
>
> **Turn In:**
> - Kernel boot log
>
> **Hint:** Check the documentation in `Documentation/development-process/` (or `Documentation/process/` in newer kernels) within the kernel source tree.

---

## What is linux-next?

### Definition

**linux-next** is a daily integration testing tree for the Linux kernel, maintained by Stephen Rothwell.

### Purpose

| Aspect | Description |
|--------|-------------|
| **What it contains** | All subsystem maintainer trees merged together |
| **Update frequency** | Daily (tagged like `next-20251229`) |
| **Primary goal** | Find integration bugs BEFORE patches reach Linus |
| **Stability** | Can be unstable - that's intentional |

### Why It Exists

When hundreds of developers work on different parts of the kernel simultaneously, their patches might conflict or cause bugs when combined. linux-next merges all these patches together daily to:

1. **Catch conflicts early** - Before the merge window opens
2. **Test integration** - Ensure patches from different subsystems work together
3. **Give developers feedback** - Build/boot failures are reported
4. **Preview the future** - Shows what the next kernel release will look like

### Characteristics

- **Bleeding edge** - Contains code not yet in mainline
- **May break** - Integration bugs are expected and fixed
- **Resets daily** - Each day is a fresh merge
- **Tagged by date** - `next-YYYYMMDD` format

---

## The Linux Kernel Development Cycle

### Overview

The kernel follows a **time-based release cycle** of approximately 9-10 weeks:

```
v6.7 Release
    │
    ├──► MERGE WINDOW (2 weeks)
    │    │
    │    ├── New features accepted
    │    ├── Subsystem trees merged into mainline
    │    └── Approximately 10,000+ patches merged
    │
    ├──► rc1 (Release Candidate 1)
    │
    ├──► STABILIZATION PERIOD (~7 weeks)
    │    │
    │    ├── rc2, rc3, rc4, rc5, rc6 (weekly)
    │    ├── Bug fixes ONLY - no new features
    │    └── Testing and regression fixes
    │
    ├──► rc7 (usually the last rc)
    │
    └──► v6.8 Release
         │
         └──► Cycle repeats...
```

### Timeline

| Phase | Duration | What Happens |
|-------|----------|--------------|
| **Merge Window** | ~2 weeks | New features merged from subsystem trees |
| **rc1** | Day 1 after merge window | First release candidate |
| **rc2-rc7** | ~1 week each | Bug fixes, stabilization |
| **Release** | After ~7 rc's | Stable kernel released |

### The Role of linux-next in This Cycle

```
                    BEFORE Merge Window
                           │
    Subsystem Trees ──────►│
    (net-next, usb, etc)   │
                           ▼
                    ┌─────────────┐
                    │  linux-next │  ◄── Tests integration daily
                    └─────────────┘
                           │
                           │  Problems found and fixed
                           │
                           ▼
                    MERGE WINDOW OPENS
                           │
                           ▼
                    Linus merges subsystem trees
                    (with fewer conflicts because
                     linux-next already found them)
```

---

## How Code Flows in the Kernel

### The Patch Journey

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   DEVELOPER                                                     │
│   └── Writes patch                                              │
│       └── Sends to subsystem maintainer                         │
│                                                                 │
│   SUBSYSTEM MAINTAINER (e.g., USB maintainer)                   │
│   └── Reviews patch                                             │
│       └── Applies to subsystem tree (e.g., usb-next)            │
│                                                                 │
│   LINUX-NEXT (Stephen Rothwell)                                 │
│   └── Merges ALL subsystem trees daily                          │
│       └── Reports conflicts/build failures                      │
│           └── Developers fix issues                             │
│                                                                 │
│   LINUS TORVALDS (during merge window)                          │
│   └── Pulls from subsystem maintainers                          │
│       └── Merges into mainline                                  │
│                                                                 │
│   STABLE TREE (Greg Kroah-Hartman)                              │
│   └── Backports critical fixes                                  │
│       └── Releases stable updates (6.7.1, 6.7.2, etc.)          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Visual Flow

```
Developer's Patch
       │
       ▼
Subsystem Tree (net-next, usb-next, driver-core, etc.)
       │
       ├────────────────────┐
       │                    │
       ▼                    ▼
  linux-next          Merge Window
  (daily test)             │
       │                   │
       │ (bugs found       │
       │  and fixed)       │
       │                   │
       └──────────────────►│
                           ▼
                    Linus's Mainline
                           │
                           ▼
                    Stable Releases
```

---

## Key Kernel Trees

| Tree | URL | Maintainer | Purpose |
|------|-----|-----------|---------|
| **mainline** | git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git | Linus Torvalds | Official development tree |
| **linux-next** | git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git | Stephen Rothwell | Integration testing |
| **stable** | git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git | Greg KH | Stable release updates |
| **linux-next (GitHub mirror)** | github.com/torvalds/linux | - | Convenient mirror |

### Which Tree for Which Assignment?

| Assignment | Tree to Use |
|------------|-------------|
| Assignment 00 | Linus's mainline (torvalds/linux) |
| Assignment 06 | linux-next |

---

## Documentation/process/ Key Points

The kernel's own documentation explains the development process. Key files:

### Important Documents

| File | Contents |
|------|----------|
| `1.Intro.rst` | Overview of kernel development |
| `2.Process.rst` | How the development cycle works |
| `submitting-patches.rst` | How to create and submit patches |
| `coding-style.rst` | Code formatting rules |
| `stable-kernel-rules.rst` | Rules for stable tree patches |

### Key Concepts from Documentation

#### 1. No Stable Internal API

> "There is no stable kernel internal API. The kernel to userspace API is stable, but internal APIs can and do change."

This means:
- Modules must be recompiled for each kernel version
- Don't rely on internal implementation details
- Use documented interfaces when possible

#### 2. GPL Requirement

> "The kernel is released under GPL-2.0, and modules using non-exported or GPL-only symbols must also be GPL."

This is why we use `MODULE_LICENSE("GPL")` in our modules.

#### 3. Coding Style

Key rules (relevant to Assignments 03 and 08):

```c
/* Tabs are 8 characters */
	if (condition) {
		do_something();	/* Brace on same line */
	}

/* Function opening brace on new line */
static int my_function(void)
{
	return 0;
}

/* Naming: lowercase with underscores */
int my_variable;
void my_function_name(void);
```

#### 4. The -next Trees

From the documentation:

> "The linux-next tree is where patches are gathered for testing before the next merge window. It is rebuilt daily."

Why this matters:
- Testing linux-next helps find bugs
- It's the closest preview of the next kernel release
- May be unstable - that's expected

---

## Step-by-Step Instructions

### Method 1: Fresh Clone

```bash
# 1. Clone linux-next repository
git clone https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
cd linux-next

# 2. Check the current version (dated tag)
git describe
# Output example: next-20251229

# 3. List available tags (optional)
git tag -l "next-*" | tail -10
```

### Method 2: Add to Existing Tree

```bash
# If you already have a kernel tree from Assignment 00
cd /path/to/linux

# Add linux-next as a remote
git remote add linux-next https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git

# Fetch linux-next
git fetch linux-next

# Checkout linux-next master
git checkout linux-next/master
```

### Building the Kernel

```bash
# 1. Copy existing config as starting point
cp /boot/config-$(uname -r) .config

# 2. Update config for new kernel version
make olddefconfig

# 3. Build kernel (use all CPU cores)
make -j$(nproc)

# 4. Build modules
make modules -j$(nproc)

# 5. Install modules
sudo make modules_install

# 6. Install kernel
sudo make install

# 7. Update bootloader
# For GRUB:
sudo update-grub
# Or on some systems:
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# 8. Reboot
sudo reboot
```

### After Reboot

```bash
# Verify you're running linux-next
uname -r
# Should show something like: 6.13.0-next-20251229

# Capture boot log for submission
dmesg > boot_log

# Or get full boot log
journalctl -b > boot_log
```

---

## Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| **Build fails** | linux-next can be unstable; try an older tag: `git checkout next-20251228` |
| **Missing dependencies** | Install build deps: `apt install build-essential libncurses-dev bison flex libssl-dev libelf-dev` |
| **Boot fails** | Select old kernel in GRUB menu; fix config and rebuild |
| **Config errors** | Run `make menuconfig` to fix specific options |
| **Disk space** | Kernel build needs ~20GB; clean with `make clean` |

### Build Dependencies

#### Debian/Ubuntu:
```bash
sudo apt install build-essential libncurses-dev bison flex libssl-dev libelf-dev bc
```

#### Fedora:
```bash
sudo dnf install gcc make ncurses-devel bison flex elfutils-libelf-devel openssl-devel bc
```

#### Arch:
```bash
sudo pacman -S base-devel bc
```

### If linux-next Doesn't Boot

1. Reboot and select your old kernel from GRUB menu
2. Try a different linux-next tag (previous day)
3. Check `dmesg` for error messages
4. Report the bug if you can identify it (good practice!)

---

## Files to Submit

For Assignment 06, you need to submit:

```
assignment06/
└── boot_log       # Output of 'dmesg' after booting linux-next
```

The boot log should show:
- Kernel version containing "next-YYYYMMDD"
- Successful boot messages
- No critical errors

### Example Boot Log Header

```
[    0.000000] Linux version 6.13.0-next-20251229 (user@host) (gcc version 12.2.0) #1 SMP PREEMPT_DYNAMIC Sun Dec 29 10:30:00 UTC 2025
[    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-6.13.0-next-20251229 root=/dev/sda1 ro quiet
...
```

---

## Summary

| Concept | Key Point |
|---------|-----------|
| **linux-next** | Daily integration tree for testing patches |
| **Purpose** | Find bugs before merge window |
| **Stability** | May be unstable - that's intentional |
| **Update frequency** | Daily, tagged by date |
| **Your task** | Clone, build, boot, capture log |

---

## References

- Linux Kernel Documentation: https://www.kernel.org/doc/html/latest/process/
- linux-next tree: https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
- Kernel Newbies: https://kernelnewbies.org/
- LWN.net (Linux Weekly News): https://lwn.net/
