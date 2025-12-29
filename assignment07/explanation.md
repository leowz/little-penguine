# Assignment 07 - Debugfs Module Explanation

A comprehensive guide covering background knowledge, code explanation, and usage.

---

## Table of Contents

1. [Background: Virtual Filesystems](#background-virtual-filesystems)
   - [procfs](#1-procfs-proc)
   - [sysfs](#2-sysfs-sys)
   - [debugfs](#3-debugfs-syskerneldebug)
   - [Comparison](#comparison-table)
2. [Assignment Requirements](#assignment-requirements)
3. [Code Explanation](#code-explanation)
4. [How to Build and Test](#how-to-build-and-test)
5. [Key Takeaways](#key-takeaways)

---

## Background: Virtual Filesystems

Linux provides several **virtual filesystems** that create interfaces between kernel space and user space. These filesystems don't store data on disk - they generate content dynamically when read.

### 1. procfs (`/proc`)

#### What is it?

**procfs** (process filesystem) was originally designed to expose process information but evolved to include various kernel information.

#### Mount Point
```
/proc
```

#### Structure

```
/proc/
├── 1/                  # Process PID 1 (init/systemd)
│   ├── cmdline         # Command line arguments
│   ├── status          # Process status
│   ├── fd/             # Open file descriptors
│   ├── maps            # Memory mappings
│   └── ...
├── self/               # Symlink to current process
├── cpuinfo             # CPU information
├── meminfo             # Memory statistics
├── mounts              # Mounted filesystems
├── version             # Kernel version string
├── uptime              # System uptime
└── sys/                # Tunable kernel parameters
    ├── kernel/
    │   ├── hostname
    │   └── pid_max
    └── net/
        └── ipv4/
```

#### Usage Examples

```bash
# Process information
cat /proc/self/status          # Current process info
cat /proc/1234/cmdline         # Command line of PID 1234
ls -la /proc/1234/fd           # Open file descriptors

# System information
cat /proc/cpuinfo              # CPU details
cat /proc/meminfo              # Memory usage
cat /proc/version              # Kernel version
cat /proc/uptime               # Uptime in seconds

# Kernel tuning
cat /proc/sys/kernel/hostname
sudo sh -c 'echo 65536 > /proc/sys/kernel/pid_max'
```

#### Characteristics

| Aspect | Description |
|--------|-------------|
| **Primary use** | Process information |
| **Secondary use** | Legacy kernel info, tuning |
| **ABI stability** | Partial (process info is stable) |
| **Problem** | Became cluttered over time |

#### Kernel API

```c
#include <linux/proc_fs.h>

/* Create a file in /proc */
struct proc_dir_entry *proc_create(
    const char *name,
    umode_t mode,
    struct proc_dir_entry *parent,
    const struct proc_ops *proc_ops
);

/* Remove a /proc entry */
void proc_remove(struct proc_dir_entry *entry);
```

---

### 2. sysfs (`/sys`)

#### What is it?

**sysfs** exposes the kernel's **device model** - a structured representation of devices, drivers, buses, and their relationships.

#### Mount Point
```
/sys
```

#### Structure

```
/sys/
├── block/              # Block devices
│   ├── sda/
│   │   ├── size        # Size in 512-byte sectors
│   │   ├── queue/      # I/O scheduler settings
│   │   └── device -> ../devices/...
│   └── nvme0n1/
├── bus/                # Bus types
│   ├── usb/
│   │   ├── devices/
│   │   └── drivers/
│   ├── pci/
│   └── i2c/
├── class/              # Device classes (by function)
│   ├── net/
│   │   ├── eth0 -> ../../devices/.../net/eth0
│   │   └── wlan0
│   ├── input/
│   └── tty/
├── devices/            # All devices (hierarchical)
│   ├── system/
│   │   └── cpu/
│   └── pci0000:00/
├── module/             # Loaded kernel modules
│   └── mymodule/
│       └── parameters/
├── fs/                 # Filesystem info
└── kernel/             # Kernel subsystems
    ├── mm/
    └── debug -> /sys/kernel/debug
```

#### Usage Examples

```bash
# Network device info
cat /sys/class/net/eth0/address       # MAC address
cat /sys/class/net/eth0/mtu           # MTU size
cat /sys/class/net/eth0/operstate     # up/down

# Block device info
cat /sys/block/sda/size               # Size in sectors
cat /sys/block/sda/queue/scheduler    # I/O scheduler

# CPU info
ls /sys/devices/system/cpu/
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq

# Module parameters
cat /sys/module/usbcore/parameters/autosuspend

# Power management
cat /sys/class/power_supply/BAT0/capacity
```

#### The "One Value Per File" Rule

sysfs enforces a strict rule: **each file should contain one value**.

```bash
# CORRECT - sysfs way
/sys/class/net/eth0/mtu         -> "1500"
/sys/class/net/eth0/address     -> "aa:bb:cc:dd:ee:ff"
/sys/class/net/eth0/operstate   -> "up"

# WRONG - would violate sysfs philosophy
/sys/class/net/eth0/info        -> "mtu=1500,addr=aa:bb:cc..."
```

#### Characteristics

| Aspect | Description |
|--------|-------------|
| **Primary use** | Device/driver model |
| **ABI stability** | **Yes** - strict rules |
| **File content** | One value per file |
| **Structure** | Reflects kernel object hierarchy |

#### Kernel API

```c
#include <linux/kobject.h>
#include <linux/sysfs.h>

/* Create a sysfs attribute */
static ssize_t my_show(struct kobject *kobj,
                       struct kobj_attribute *attr,
                       char *buf)
{
    return sprintf(buf, "%d\n", my_value);
}

static ssize_t my_store(struct kobject *kobj,
                        struct kobj_attribute *attr,
                        const char *buf, size_t count)
{
    sscanf(buf, "%d", &my_value);
    return count;
}

static struct kobj_attribute my_attr = __ATTR(my, 0664, my_show, my_store);
```

---

### 3. debugfs (`/sys/kernel/debug`)

#### What is it?

**debugfs** is a simple filesystem for kernel debugging with **no ABI guarantees**. Its philosophy is "there are no rules."

#### Mount Point
```
/sys/kernel/debug
```

#### Why debugfs Exists

| Problem | debugfs Solution |
|---------|------------------|
| sysfs has strict rules | debugfs has no rules |
| procfs is cluttered | debugfs is for debug only |
| Need quick debug interface | Easy API, minimal code |
| Don't want ABI commitment | No stability guarantee |

#### Structure

```
/sys/kernel/debug/
├── tracing/            # ftrace - kernel tracer
│   ├── trace           # Trace output
│   ├── trace_pipe      # Streaming trace
│   └── available_tracers
├── gpio                # GPIO pin states
├── clk/                # Clock tree debug
├── usb/                # USB debug info
├── dri/                # GPU/DRM debug
├── bdi/                # Block device info
├── kprobes/            # Kprobes debug
└── fortytwo/           # Our module!
    ├── id
    ├── jiffies
    └── foo
```

#### Usage Examples

```bash
# Mount debugfs (if not mounted)
sudo mount -t debugfs none /sys/kernel/debug

# Check if mounted
mount | grep debugfs

# Kernel tracing
sudo cat /sys/kernel/debug/tracing/trace
sudo cat /sys/kernel/debug/tracing/available_tracers

# GPIO debug (if available)
sudo cat /sys/kernel/debug/gpio

# Our module
cat /sys/kernel/debug/fortytwo/jiffies
```

#### Characteristics

| Aspect | Description |
|--------|-------------|
| **Primary use** | Kernel debugging |
| **ABI stability** | **None** - can change anytime |
| **Default permissions** | Root only (0700) |
| **Philosophy** | "No rules" |
| **Production use** | Not recommended |

#### Kernel API

```c
#include <linux/debugfs.h>

/* Create a directory */
struct dentry *debugfs_create_dir(
    const char *name,
    struct dentry *parent    /* NULL = root of debugfs */
);

/* Create a file with custom operations */
void debugfs_create_file(
    const char *name,
    umode_t mode,
    struct dentry *parent,
    void *data,
    const struct file_operations *fops
);

/* Helper functions for common types */
void debugfs_create_u32(const char *name, umode_t mode,
                        struct dentry *parent, u32 *value);
void debugfs_create_bool(const char *name, umode_t mode,
                         struct dentry *parent, bool *value);

/* Remove files/directories */
void debugfs_remove(struct dentry *dentry);
void debugfs_remove_recursive(struct dentry *dentry);
```

---

### Comparison Table

| Feature | procfs | sysfs | debugfs |
|---------|--------|-------|---------|
| **Mount point** | `/proc` | `/sys` | `/sys/kernel/debug` |
| **Primary purpose** | Process info | Device model | Debugging |
| **ABI stable?** | Partial | Yes | No |
| **Default perms** | Varies | 0644 | 0700 |
| **One value/file** | No | Yes | No |
| **Rules** | Some | Strict | None |
| **Production use** | Yes | Yes | No |

### Visual Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USERSPACE                                   │
│                                                                     │
│   Process tools        Hardware info      Kernel debugging          │
│   (ps, top)            (lspci, lsusb)     (development)             │
│        │                    │                    │                  │
│        ▼                    ▼                    ▼                  │
│   ┌─────────┐         ┌─────────┐         ┌──────────┐             │
│   │ /proc   │         │  /sys   │         │ debugfs  │             │
│   └────┬────┘         └────┬────┘         └────┬─────┘             │
└────────┼───────────────────┼───────────────────┼────────────────────┘
         │                   │                   │
═════════╪═══════════════════╪═══════════════════╪═══════ KERNEL BOUNDARY
         │                   │                   │
┌────────┼───────────────────┼───────────────────┼────────────────────┐
│        ▼                   ▼                   ▼                    │
│   ┌─────────┐         ┌─────────┐         ┌──────────┐             │
│   │ procfs  │         │  sysfs  │         │ debugfs  │             │
│   │ code    │         │ kobject │         │  code    │             │
│   └────┬────┘         └────┬────┘         └────┬─────┘             │
│        │                   │                   │                    │
│        └───────────────────┴───────────────────┘                    │
│                            │                                        │
│                     Kernel Data                                     │
│              (processes, devices, debug info)                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### When to Use Which?

| Scenario | Filesystem |
|----------|------------|
| Process information | procfs |
| Kernel tuning parameters | procfs (`/proc/sys/`) |
| Device attributes | sysfs |
| Driver parameters | sysfs |
| Stable userspace API | sysfs |
| Quick debugging | debugfs |
| Development/testing | debugfs |
| No ABI commitment needed | debugfs |

---

## Assignment Requirements

From the subject:

> **To Do:**
> - Modify the module from Assignment 01 to create a debugfs subdirectory named `fortytwo`
> - In this directory, create three virtual files: `id`, `jiffies`, and `foo`
>
> **File specifications:**
> - `id`: Behaves exactly as Assignment 05. Readable and writable by all users.
> - `jiffies`: Read-only by any user. Returns current kernel jiffies value.
> - `foo`: Writable only by root; readable by everyone. Stores up to one page. Use proper locking.
>
> **Turn In:**
> - Your code
> - Proof that the module works

---

## Code Explanation

### Part 1: Headers (Lines 1-11)

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/debugfs.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/string.h>
#include <linux/jiffies.h>
#include <linux/mutex.h>
```

| Header | Purpose |
|--------|---------|
| `linux/debugfs.h` | debugfs API (`debugfs_create_*`, `debugfs_remove_*`) |
| `linux/fs.h` | `struct file_operations` |
| `linux/uaccess.h` | `simple_read_from_buffer()`, `simple_write_to_buffer()` |
| `linux/string.h` | `strncmp()` |
| `linux/jiffies.h` | `jiffies` global variable |
| `linux/mutex.h` | `DEFINE_MUTEX()`, `mutex_lock()`, `mutex_unlock()` |

---

### Part 2: Module Metadata and Constants (Lines 13-19)

```c
MODULE_LICENSE("GPL");
MODULE_AUTHOR("zweng");
MODULE_DESCRIPTION("Debugfs module for fortytwo");

#define LOGIN "zweng"
#define LOGIN_LEN 5
```

Standard module metadata. `LOGIN` is the student login for the `id` file.

---

### Part 3: Global Variables (Lines 21-26)

```c
/* debugfs directory entry */
static struct dentry *fortytwo_dir;

/* foo file storage and lock */
static char foo_buf[PAGE_SIZE];
static size_t foo_len;
static DEFINE_MUTEX(foo_mutex);
```

| Variable | Purpose |
|----------|---------|
| `fortytwo_dir` | Pointer to debugfs directory, needed for cleanup |
| `foo_buf` | Storage buffer for foo file (one page = 4096 bytes typically) |
| `foo_len` | Current length of data in foo_buf |
| `foo_mutex` | Mutex to protect concurrent access to foo_buf |

**What is a dentry?**

A `dentry` (directory entry) is a kernel structure representing a path component. debugfs functions return `dentry` pointers to reference created files/directories.

**What is PAGE_SIZE?**

`PAGE_SIZE` is the memory page size for the architecture (typically 4096 bytes on x86_64). It's defined in kernel headers.

**What is DEFINE_MUTEX?**

`DEFINE_MUTEX(name)` is a macro that statically declares and initializes a mutex:
```c
/* This: */
static DEFINE_MUTEX(foo_mutex);

/* Is equivalent to: */
static struct mutex foo_mutex = __MUTEX_INITIALIZER(foo_mutex);
```

---

### Part 4: id File Operations (Lines 28-56)

```c
static ssize_t id_read(struct file *file, char __user *buf,
                       size_t count, loff_t *ppos)
{
    return simple_read_from_buffer(buf, count, ppos, LOGIN, LOGIN_LEN);
}

static ssize_t id_write(struct file *file, const char __user *buf,
                        size_t count, loff_t *ppos)
{
    char kbuf[LOGIN_LEN + 1];
    ssize_t len;

    if (count != LOGIN_LEN)
        return -EINVAL;

    len = simple_write_to_buffer(kbuf, LOGIN_LEN, ppos, buf, count);
    if (len < 0)
        return len;

    kbuf[len] = '\0';

    if (strncmp(kbuf, LOGIN, LOGIN_LEN) != 0)
        return -EINVAL;

    return count;
}

static const struct file_operations id_fops = {
    .owner  = THIS_MODULE,
    .read   = id_read,
    .write  = id_write,
};
```

This is identical to Assignment 05:
- **Read**: Returns "zweng"
- **Write**: Accepts only "zweng", returns error otherwise

---

### Part 5: jiffies File Operations (Lines 58-73)

```c
static ssize_t jiffies_read(struct file *file, char __user *buf,
                            size_t count, loff_t *ppos)
{
    char tmp[32];
    int len;

    len = snprintf(tmp, sizeof(tmp), "%lu\n", jiffies);
    return simple_read_from_buffer(buf, count, ppos, tmp, len);
}

static const struct file_operations jiffies_fops = {
    .owner  = THIS_MODULE,
    .read   = jiffies_read,
};
```

**What is jiffies?**

`jiffies` is a global kernel variable that counts timer ticks since boot. It's incremented by the timer interrupt (typically 100-1000 times per second depending on `CONFIG_HZ`).

```c
/* jiffies increments every timer tick */
HZ = 1000  ->  jiffies increments 1000 times per second
HZ = 100   ->  jiffies increments 100 times per second

/* Convert jiffies to seconds */
seconds = jiffies / HZ;

/* Convert jiffies to milliseconds */
ms = jiffies_to_msecs(jiffies);
```

**Why no write function?**

We only define `.read` in the file_operations. Any write attempt will return an error automatically because there's no `.write` handler.

---

### Part 6: foo File Operations (Lines 75-111)

```c
static ssize_t foo_read(struct file *file, char __user *buf,
                        size_t count, loff_t *ppos)
{
    ssize_t ret;

    mutex_lock(&foo_mutex);
    ret = simple_read_from_buffer(buf, count, ppos, foo_buf, foo_len);
    mutex_unlock(&foo_mutex);

    return ret;
}

static ssize_t foo_write(struct file *file, const char __user *buf,
                         size_t count, loff_t *ppos)
{
    ssize_t ret;

    if (count > PAGE_SIZE)
        return -EINVAL;

    mutex_lock(&foo_mutex);
    ret = simple_write_to_buffer(foo_buf, PAGE_SIZE, ppos, buf, count);
    if (ret > 0)
        foo_len = ret;
    mutex_unlock(&foo_mutex);

    return ret;
}

static const struct file_operations foo_fops = {
    .owner  = THIS_MODULE,
    .read   = foo_read,
    .write  = foo_write,
};
```

**Why do we need locking?**

Multiple processes might access `foo` simultaneously:
- Process A writing while Process B is reading
- Two processes writing at the same time

Without locking, this could cause:
- Corrupted data
- Partial reads/writes
- Race conditions

**Mutex operations:**

```c
mutex_lock(&foo_mutex);    /* Acquire lock (blocks if held by another) */
/* ... critical section ... */
mutex_unlock(&foo_mutex);  /* Release lock */
```

**Flow diagram:**

```
Process A (write)              Process B (read)
      │                              │
      ▼                              ▼
 mutex_lock()                   mutex_lock()
      │                              │
      │ (acquires lock)              │ (BLOCKED - waiting)
      ▼                              │
 write to foo_buf                    │
      │                              │
      ▼                              │
 mutex_unlock()                      │
      │                              ▼
      │                         (acquires lock)
      │                              │
      │                         read from foo_buf
      │                              │
      │                         mutex_unlock()
```

---

### Part 7: Init Function (Lines 113-133)

```c
static int __init fortytwo_init(void)
{
    /* Create /sys/kernel/debug/fortytwo directory */
    fortytwo_dir = debugfs_create_dir("fortytwo", NULL);
    if (!fortytwo_dir) {
        pr_err("fortytwo: failed to create debugfs directory\n");
        return -ENOMEM;
    }

    /* Create id file: read/write by all (0666) */
    debugfs_create_file("id", 0666, fortytwo_dir, NULL, &id_fops);

    /* Create jiffies file: read-only by all (0444) */
    debugfs_create_file("jiffies", 0444, fortytwo_dir, NULL, &jiffies_fops);

    /* Create foo file: write by root, read by all (0644) */
    debugfs_create_file("foo", 0644, fortytwo_dir, NULL, &foo_fops);

    pr_info("fortytwo: debugfs interface created\n");
    return 0;
}
```

**debugfs_create_dir():**

```c
struct dentry *debugfs_create_dir(const char *name, struct dentry *parent);
```
- `name`: Directory name
- `parent`: Parent directory (`NULL` = root of debugfs)
- Returns: dentry pointer (or NULL/error pointer on failure)

**debugfs_create_file():**

```c
void debugfs_create_file(
    const char *name,      /* Filename */
    umode_t mode,          /* Permissions (e.g., 0644) */
    struct dentry *parent, /* Parent directory */
    void *data,            /* Private data (passed to fops) */
    const struct file_operations *fops
);
```

**Permission bits:**

```
0666 = rw-rw-rw- (read/write by owner, group, others)
0644 = rw-r--r-- (read/write by owner, read by others)
0444 = r--r--r-- (read-only by all)
```

---

### Part 8: Exit Function (Lines 135-140)

```c
static void __exit fortytwo_exit(void)
{
    /* Remove directory and all files inside */
    debugfs_remove_recursive(fortytwo_dir);
    pr_info("fortytwo: debugfs interface removed\n");
}
```

**debugfs_remove_recursive():**

Removes a directory and ALL its contents. This is convenient - we don't need to remove each file individually.

```c
/* Alternative: remove files one by one */
debugfs_remove(id_dentry);
debugfs_remove(jiffies_dentry);
debugfs_remove(foo_dentry);
debugfs_remove(fortytwo_dir);

/* Better: remove everything at once */
debugfs_remove_recursive(fortytwo_dir);
```

---

### Part 9: Module Entry Points (Lines 142-143)

```c
module_init(fortytwo_init);
module_exit(fortytwo_exit);
```

Register init and exit functions with the kernel.

---

## How to Build and Test

### Prerequisites

Ensure `CONFIG_DEBUG_FS=y` is set in your kernel config:
```bash
# Check if debugfs is enabled
zcat /proc/config.gz | grep DEBUG_FS
# Or
cat /boot/config-$(uname -r) | grep DEBUG_FS
```

### Build

```bash
cd assignment07
make
```

### Load Module

```bash
sudo insmod main.ko

# Check if loaded
lsmod | grep main

# Check kernel messages
dmesg | tail -5
```

### Verify debugfs is Mounted

```bash
# Check mount
mount | grep debugfs

# If not mounted:
sudo mount -t debugfs none /sys/kernel/debug

# Verify our directory exists
ls -la /sys/kernel/debug/fortytwo/
```

Expected output:
```
drwxr-xr-x 2 root root 0 Dec 29 12:00 .
drwx------ 47 root root 0 Dec 29 12:00 ..
-rw-rw-rw- 1 root root 0 Dec 29 12:00 id
-r--r--r-- 1 root root 0 Dec 29 12:00 jiffies
-rw-r--r-- 1 root root 0 Dec 29 12:00 foo
```

### Test id File

```bash
# Read (should return "zweng")
cat /sys/kernel/debug/fortytwo/id

# Write correct value (should succeed)
echo -n "zweng" | sudo tee /sys/kernel/debug/fortytwo/id
echo $?   # Should be 0

# Write wrong value (should fail)
echo -n "wrong" | sudo tee /sys/kernel/debug/fortytwo/id
# Error: Invalid argument
```

### Test jiffies File

```bash
# Read multiple times (values should differ)
cat /sys/kernel/debug/fortytwo/jiffies
sleep 1
cat /sys/kernel/debug/fortytwo/jiffies

# Try to write (should fail - read only)
echo "123" | sudo tee /sys/kernel/debug/fortytwo/jiffies
# Error: Permission denied or Invalid argument
```

### Test foo File

```bash
# Write as root
sudo sh -c 'echo "Hello from kernel!" > /sys/kernel/debug/fortytwo/foo'

# Read (anyone can read)
cat /sys/kernel/debug/fortytwo/foo
# Output: Hello from kernel!

# Try write as non-root (should fail)
echo "test" > /sys/kernel/debug/fortytwo/foo
# Error: Permission denied

# Write longer data
sudo sh -c 'echo "Line 1
Line 2
Line 3" > /sys/kernel/debug/fortytwo/foo'

cat /sys/kernel/debug/fortytwo/foo
# Output:
# Line 1
# Line 2
# Line 3
```

### Unload Module

```bash
sudo rmmod main

# Verify cleanup
ls /sys/kernel/debug/fortytwo
# Error: No such file or directory
```

---

## Key Takeaways

### 1. debugfs Philosophy

> "There are no rules"

debugfs is meant for debugging, not production interfaces. It has:
- No ABI stability guarantees
- Simple API
- Minimal requirements

### 2. Virtual Filesystem Hierarchy

```
/proc      -> Process info (legacy kernel info)
/sys       -> Device model (stable ABI)
/sys/kernel/debug -> Debugging (no rules)
```

### 3. Mutex for Concurrent Access

Always protect shared data with proper locking:
```c
mutex_lock(&lock);
/* access shared data */
mutex_unlock(&lock);
```

### 4. Kernel Jiffies

`jiffies` is the kernel's tick counter - useful for timing and delays:
```c
unsigned long j = jiffies;           /* Current tick count */
unsigned long later = j + HZ;        /* 1 second from now */
unsigned long ms = jiffies_to_msecs(j);  /* Convert to ms */
```

### 5. debugfs Cleanup

Always use `debugfs_remove_recursive()` to clean up directories:
```c
/* One call removes everything */
debugfs_remove_recursive(fortytwo_dir);
```

### 6. File Permissions

```
0666 = -rw-rw-rw-  (everyone can read/write)
0644 = -rw-r--r--  (owner writes, everyone reads)
0444 = -r--r--r--  (everyone can only read)
```

---

## Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "No such file or directory" | debugfs not mounted | `sudo mount -t debugfs none /sys/kernel/debug` |
| "Permission denied" on debugfs | Root-only by default | Use `sudo` or adjust mount options |
| NULL from debugfs_create_dir | debugfs disabled in kernel | Enable `CONFIG_DEBUG_FS=y` |
| Module won't unload | File still open | Close all open file handles |

---

## References

- Linux Kernel Documentation: https://www.kernel.org/doc/html/latest/filesystems/debugfs.html
- LWN Article on debugfs: https://lwn.net/Articles/115405/
- Kernel source: `fs/debugfs/` directory
