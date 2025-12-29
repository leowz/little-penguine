# Assignment 09 - Mount Points Listing Module

A comprehensive guide covering background knowledge, code explanation, and usage.

---

## Table of Contents

1. [Assignment Requirements](#assignment-requirements)
2. [Background Knowledge](#background-knowledge)
   - [The procfs Filesystem](#the-procfs-filesystem)
   - [The seq_file Interface](#the-seq_file-interface)
   - [VFS and Mount Structures](#vfs-and-mount-structures)
   - [Mount Namespaces](#mount-namespaces)
3. [Code Explanation](#code-explanation)
4. [How to Build and Test](#how-to-build-and-test)
5. [Key Takeaways](#key-takeaways)

---

## Assignment Requirements

From the subject:

> **To Do:**
> - Create a module that can list mount points on your system, with the associated name.
> - Your file must be named `/proc/mymounts`.
>
> **Example Output:**
> ```
> $> cat /proc/mymounts
> root /
> sys /sys
> proc /proc
> run /run
> dev /dev
> ```
>
> **Turn In:**
> - The module source code and a Makefile.

---

## Background Knowledge

### The procfs Filesystem

#### What is procfs?

**procfs** (process filesystem) is a virtual filesystem that provides an interface to kernel data structures. It's mounted at `/proc`.

#### History and Purpose

```
Original Purpose: Process information (/proc/[pid]/)
Extended To:      System information, kernel tunables
Mount Point:      /proc
Filesystem Type:  proc
```

#### Structure of /proc

```
/proc/
│
├── [pid]/                    # Per-process directories
│   ├── cmdline               # Command line arguments
│   ├── status                # Process status
│   ├── fd/                   # File descriptors
│   ├── maps                  # Memory maps
│   └── ...
│
├── self/                     # Symlink to current process
│
├── sys/                      # Kernel tunables (sysctl)
│   ├── kernel/
│   ├── net/
│   └── vm/
│
├── meminfo                   # Memory information
├── cpuinfo                   # CPU information
├── mounts                    # Mount points (what we're recreating!)
├── filesystems               # Supported filesystems
├── version                   # Kernel version
│
└── mymounts                  # Our module creates this!
```

#### Existing Mount Information

Linux already provides mount information in several places:

| File | Content |
|------|---------|
| `/proc/mounts` | All mounts (symlink to `/proc/self/mounts`) |
| `/proc/self/mounts` | Mounts in current namespace |
| `/proc/self/mountinfo` | Detailed mount information |
| `/proc/self/mountstats` | Mount statistics |

Our module creates a simplified version at `/proc/mymounts`.

---

### The seq_file Interface

#### Why seq_file?

When outputting data to `/proc`, we could use simple `read` callbacks, but this has problems:

| Problem | Description |
|---------|-------------|
| Buffer management | Manually handle partial reads |
| Large output | Must handle output larger than buffer |
| Offset tracking | Complex `ppos` management |
| Memory allocation | Risk of large allocations |

**seq_file** solves these by providing:
- Automatic buffer management
- Iterator interface for sequences
- Handles partial reads automatically
- Simple API

#### seq_file Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Space                              │
│                                                             │
│    cat /proc/mymounts                                       │
│         │                                                   │
│         │  read(fd, buf, size)                              │
│         ▼                                                   │
└─────────────────────────────────────────────────────────────┘
          │
          │  System Call
          ▼
┌─────────────────────────────────────────────────────────────┐
│                     Kernel Space                            │
│                                                             │
│    VFS Layer                                                │
│         │                                                   │
│         ▼                                                   │
│    proc_ops.proc_read = seq_read()                          │
│         │                                                   │
│         ▼                                                   │
│    seq_file Framework                                       │
│    ┌─────────────────────────────────────────────────────┐  │
│    │  - Allocates buffer                                 │  │
│    │  - Calls your show() function                       │  │
│    │  - Handles partial reads                            │  │
│    │  - Manages file position                            │  │
│    └─────────────────────────────────────────────────────┘  │
│         │                                                   │
│         ▼                                                   │
│    Your show() function                                     │
│    - seq_printf(m, "data\n")                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### seq_file API

##### For Simple Output (single_open)

When your entire output can be generated in one `show()` call:

```c
#include <linux/seq_file.h>

/* Your show function - called to generate output */
static int my_show(struct seq_file *m, void *v)
{
    seq_printf(m, "Hello, World!\n");
    seq_printf(m, "Value: %d\n", some_value);
    return 0;
}

/* Open handler - use single_open helper */
static int my_open(struct inode *inode, struct file *file)
{
    return single_open(file, my_show, NULL);
}

/* File operations */
static const struct proc_ops my_ops = {
    .proc_open    = my_open,
    .proc_read    = seq_read,      /* Provided by seq_file */
    .proc_lseek   = seq_lseek,     /* Provided by seq_file */
    .proc_release = single_release, /* Provided by seq_file */
};
```

##### For Iterator-based Output (seq_open)

When iterating through a list of items:

```c
/* start: Initialize iteration */
static void *my_start(struct seq_file *m, loff_t *pos)
{
    return seq_list_start(&my_list, *pos);
}

/* next: Move to next item */
static void *my_next(struct seq_file *m, void *v, loff_t *pos)
{
    return seq_list_next(v, &my_list, pos);
}

/* stop: Cleanup after iteration */
static void my_stop(struct seq_file *m, void *v)
{
    /* Release locks, etc. */
}

/* show: Output current item */
static int my_show(struct seq_file *m, void *v)
{
    struct my_item *item = list_entry(v, struct my_item, list);
    seq_printf(m, "%s\n", item->name);
    return 0;
}

static const struct seq_operations my_seq_ops = {
    .start = my_start,
    .next  = my_next,
    .stop  = my_stop,
    .show  = my_show,
};
```

#### seq_printf Function

```c
void seq_printf(struct seq_file *m, const char *fmt, ...);
```

Works like `printf()` but outputs to the seq_file buffer:

```c
seq_printf(m, "String: %s\n", str);
seq_printf(m, "Integer: %d\n", num);
seq_printf(m, "Pointer: %p\n", ptr);
seq_printf(m, "Device: %s Mount: %s\n", dev, mount);
```

---

### VFS and Mount Structures

#### Virtual File System (VFS)

VFS is the kernel's abstraction layer for filesystems:

```
┌──────────────────────────────────────────────────────────────────┐
│                         User Space                               │
│                                                                  │
│    Application: open("/home/user/file.txt", O_RDONLY)            │
└───────────────────────────────┬──────────────────────────────────┘
                                │ System Call
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                         VFS Layer                                │
│                                                                  │
│    - Path resolution (/home/user/file.txt)                       │
│    - Find correct filesystem (ext4, xfs, nfs...)                 │
│    - Delegate to filesystem-specific code                        │
└───────────────────────────────┬──────────────────────────────────┘
                                │
           ┌────────────────────┼────────────────────┐
           ▼                    ▼                    ▼
    ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
    │    ext4     │      │    xfs      │      │    nfs      │
    │  filesystem │      │  filesystem │      │  filesystem │
    └─────────────┘      └─────────────┘      └─────────────┘
```

#### Key VFS Structures

##### struct super_block

Represents a mounted filesystem:

```c
struct super_block {
    struct list_head    s_list;        /* List of all superblocks */
    dev_t               s_dev;         /* Device identifier */
    unsigned long       s_blocksize;   /* Block size */
    struct file_system_type *s_type;   /* Filesystem type */
    struct dentry       *s_root;       /* Root dentry */
    /* ... many more fields ... */
};
```

##### struct vfsmount

Represents a mount point (visible to other parts of kernel):

```c
struct vfsmount {
    struct dentry *mnt_root;    /* Root of this mount */
    struct super_block *mnt_sb; /* Superblock */
    int mnt_flags;              /* Mount flags */
};
```

##### struct mount (internal)

Internal mount structure with more details:

```c
struct mount {
    struct vfsmount mnt;           /* Embedded vfsmount */
    struct mount *mnt_parent;      /* Parent mount */
    struct dentry *mnt_mountpoint; /* Dentry of mount point */
    const char *mnt_devname;       /* Device name (e.g., "/dev/sda1") */
    struct list_head mnt_list;     /* List in namespace */
    /* ... more fields ... */
};
```

#### Mount Structure Relationships

```
                    struct mnt_namespace
                           │
                           │ list of mounts
                           ▼
    ┌──────────────────────────────────────────────────────────┐
    │                                                          │
    │   struct mount          struct mount         struct mount │
    │   ┌────────────┐       ┌────────────┐       ┌──────────┐ │
    │   │mnt_devname │       │mnt_devname │       │mnt_devname│ │
    │   │ "/dev/sda1"│       │ "sysfs"    │       │ "proc"   │ │
    │   │            │       │            │       │          │ │
    │   │mnt.mnt_root│       │mnt.mnt_root│       │mnt.mnt_root│
    │   │  (dentry)  │       │  (dentry)  │       │ (dentry) │ │
    │   │    "/"     │       │  "/sys"    │       │ "/proc"  │ │
    │   └────────────┘       └────────────┘       └──────────┘ │
    │        │                    │                    │       │
    │        └────────────────────┴────────────────────┘       │
    │                         │                                │
    │                    mnt_list                              │
    │                (linked list)                             │
    │                                                          │
    └──────────────────────────────────────────────────────────┘
```

---

### Mount Namespaces

#### What is a Namespace?

Linux namespaces provide isolation for system resources. Each namespace type isolates a different resource:

| Namespace | Isolates |
|-----------|----------|
| **mnt** | Mount points |
| pid | Process IDs |
| net | Network stack |
| uts | Hostname |
| ipc | IPC objects |
| user | User/group IDs |
| cgroup | Cgroup root |

#### Mount Namespace

A mount namespace contains a set of mount points. Processes in different mount namespaces see different filesystem hierarchies.

```
┌─────────────────────────────────────────────────────────────────┐
│                      Mount Namespace A                          │
│                                                                 │
│    /                                                            │
│    ├── home/          (mounted)                                 │
│    ├── var/           (mounted)                                 │
│    └── tmp/           (mounted)                                 │
│                                                                 │
│    Processes: bash, vim, ...                                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Mount Namespace B (Container)              │
│                                                                 │
│    /                                                            │
│    ├── home/          (different mount!)                        │
│    ├── var/           (different mount!)                        │
│    └── tmp/           (different mount!)                        │
│                                                                 │
│    Processes: container processes                               │
└─────────────────────────────────────────────────────────────────┘
```

#### Accessing Mount Namespace

```c
/* Current process's namespace proxy */
struct nsproxy *nsproxy = current->nsproxy;

/* Mount namespace */
struct mnt_namespace *mnt_ns = nsproxy->mnt_ns;

/* List of mounts in this namespace */
struct list_head *mounts = &mnt_ns->list;
```

#### The `current` Macro

`current` is a macro that returns the `task_struct` of the currently running process:

```c
/* current points to the running task */
struct task_struct *current;

/* Access process information */
current->pid            /* Process ID */
current->comm           /* Process name */
current->fs             /* Filesystem information */
current->nsproxy        /* Namespace proxy */
current->nsproxy->mnt_ns /* Mount namespace */
```

---

## Code Explanation

### Headers (Lines 1-15)

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/mount.h>
#include <linux/nsproxy.h>
#include <linux/mnt_namespace.h>
#include <linux/fs_struct.h>
#include <linux/path.h>
#include <../fs/mount.h>
```

| Header | Purpose |
|--------|---------|
| `proc_fs.h` | procfs creation functions |
| `seq_file.h` | seq_file interface |
| `mount.h` | Mount-related definitions |
| `nsproxy.h` | Namespace proxy structure |
| `mnt_namespace.h` | Mount namespace definitions |
| `fs_struct.h` | `get_fs_root()` function |
| `path.h` | Path structure |
| `../fs/mount.h` | Internal mount structure (struct mount) |

**Note:** Including `../fs/mount.h` accesses internal kernel structures. This is necessary because `struct mount` is not part of the public API.

---

### Module Metadata (Lines 17-19)

```c
MODULE_LICENSE("GPL");
MODULE_AUTHOR("zweng");
MODULE_DESCRIPTION("List mount points in /proc/mymounts");
```

Standard module information.

---

### Global Variable (Line 21)

```c
static struct proc_dir_entry *proc_entry;
```

Stores the proc entry pointer for cleanup on module unload.

---

### The show Function (Lines 23-51)

```c
static int mymounts_show(struct seq_file *m, void *v)
{
    struct mount *mnt;
    struct mnt_namespace *ns;
    struct path root_path;
    char *buf;
    char *path_name;

    buf = kmalloc(PATH_MAX, GFP_KERNEL);
    if (!buf)
        return -ENOMEM;

    /* Get current process root for path resolution */
    get_fs_root(current->fs, &root_path);

    /* Get current mount namespace */
    ns = current->nsproxy->mnt_ns;

    /* Iterate through all mounts in the namespace */
    list_for_each_entry(mnt, &ns->list, mnt_list) {
        /* Get the mount point path */
        path_name = dentry_path_raw(mnt->mnt.mnt_root, buf, PATH_MAX);
        if (IS_ERR(path_name))
            continue;

        /* Print: device_name mount_point */
        seq_printf(m, "%s %s\n",
                   mnt->mnt_devname ? mnt->mnt_devname : "none",
                   path_name);
    }

    path_put(&root_path);
    kfree(buf);
    return 0;
}
```

#### Step-by-Step Breakdown:

##### 1. Allocate Path Buffer

```c
buf = kmalloc(PATH_MAX, GFP_KERNEL);
if (!buf)
    return -ENOMEM;
```

- `PATH_MAX` is typically 4096 bytes
- `GFP_KERNEL` - normal kernel allocation (can sleep)
- Always check for allocation failure

##### 2. Get Root Path

```c
get_fs_root(current->fs, &root_path);
```

- Gets the root directory of the current process
- Needed for path resolution

##### 3. Get Mount Namespace

```c
ns = current->nsproxy->mnt_ns;
```

Navigation:
```
current (task_struct)
    └── nsproxy (struct nsproxy)
            └── mnt_ns (struct mnt_namespace)
                    └── list (list of struct mount)
```

##### 4. Iterate Through Mounts

```c
list_for_each_entry(mnt, &ns->list, mnt_list) {
```

This macro iterates through a linked list:
- `mnt` - loop variable (struct mount *)
- `&ns->list` - list head
- `mnt_list` - name of list_head member in struct mount

##### 5. Get Mount Path

```c
path_name = dentry_path_raw(mnt->mnt.mnt_root, buf, PATH_MAX);
if (IS_ERR(path_name))
    continue;
```

- `dentry_path_raw()` converts a dentry to a path string
- Returns pointer into `buf` (not necessarily at start)
- `IS_ERR()` checks for error pointer

##### 6. Output the Information

```c
seq_printf(m, "%s %s\n",
           mnt->mnt_devname ? mnt->mnt_devname : "none",
           path_name);
```

- `mnt_devname` - device name (e.g., "/dev/sda1", "tmpfs", etc.)
- Some mounts have no device name, use "none"
- `path_name` - mount point path

##### 7. Cleanup

```c
path_put(&root_path);
kfree(buf);
return 0;
```

- `path_put()` releases the path reference
- Free allocated buffer
- Return 0 for success

---

### The open Function (Lines 53-56)

```c
static int mymounts_open(struct inode *inode, struct file *file)
{
    return single_open(file, mymounts_show, NULL);
}
```

`single_open()` is a helper that:
- Sets up seq_file for a single show() call
- Links our `mymounts_show` function
- Third parameter is private data (NULL here)

---

### File Operations (Lines 58-63)

```c
static const struct proc_ops mymounts_ops = {
    .proc_open    = mymounts_open,
    .proc_read    = seq_read,
    .proc_lseek   = seq_lseek,
    .proc_release = single_release,
};
```

| Operation | Function | Description |
|-----------|----------|-------------|
| `proc_open` | `mymounts_open` | Our custom open |
| `proc_read` | `seq_read` | Standard seq_file read |
| `proc_lseek` | `seq_lseek` | Standard seq_file seek |
| `proc_release` | `single_release` | Cleanup for single_open |

**Note:** Kernel 5.6+ uses `struct proc_ops` instead of `struct file_operations` for procfs.

---

### Init Function (Lines 65-74)

```c
static int __init mymounts_init(void)
{
    proc_entry = proc_create("mymounts", 0444, NULL, &mymounts_ops);
    if (!proc_entry) {
        pr_err("mymounts: failed to create /proc/mymounts\n");
        return -ENOMEM;
    }

    pr_info("mymounts: /proc/mymounts created\n");
    return 0;
}
```

`proc_create()` parameters:
- `"mymounts"` - filename
- `0444` - permissions (r--r--r--)
- `NULL` - parent directory (NULL = /proc root)
- `&mymounts_ops` - file operations

---

### Exit Function (Lines 76-80)

```c
static void __exit mymounts_exit(void)
{
    proc_remove(proc_entry);
    pr_info("mymounts: /proc/mymounts removed\n");
}
```

`proc_remove()` removes the proc entry.

---

### Module Entry Points (Lines 82-83)

```c
module_init(mymounts_init);
module_exit(mymounts_exit);
```

---

## How to Build and Test

### Build

```bash
cd assignment09
make
```

### Load Module

```bash
sudo insmod main.ko

# Verify loaded
lsmod | grep main

# Check kernel messages
dmesg | tail -5
```

### Test

```bash
# Check file exists
ls -la /proc/mymounts

# Read mount points
cat /proc/mymounts

# Example output:
# /dev/sda1 /
# sysfs /sys
# proc /proc
# devtmpfs /dev
# tmpfs /run
# ...

# Compare with system mount info
cat /proc/mounts

# Compare with mount command
mount
```

### Example Output

```
$ cat /proc/mymounts
/dev/nvme0n1p2 /
sysfs /sys
proc /proc
devtmpfs /dev
securityfs /sys/kernel/security
tmpfs /dev/shm
devpts /dev/pts
tmpfs /run
cgroup2 /sys/fs/cgroup
pstore /sys/fs/pstore
bpf /sys/fs/bpf
debugfs /sys/kernel/debug
tmpfs /tmp
/dev/nvme0n1p1 /boot
tmpfs /run/user/1000
```

### Unload

```bash
sudo rmmod main

# Verify removed
ls /proc/mymounts
# ls: cannot access '/proc/mymounts': No such file or directory
```

---

## Code Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  User: cat /proc/mymounts                                       │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  VFS: open("/proc/mymounts")                                    │
│       └── calls mymounts_open()                                 │
│              └── single_open(file, mymounts_show, NULL)         │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  VFS: read()                                                    │
│       └── calls seq_read()                                      │
│              └── calls mymounts_show()                          │
│                     │                                           │
│                     ├── Get mount namespace                     │
│                     │   ns = current->nsproxy->mnt_ns           │
│                     │                                           │
│                     ├── For each mount in ns->list:             │
│                     │   ├── Get device name                     │
│                     │   ├── Get mount path                      │
│                     │   └── seq_printf(m, "%s %s\n", ...)       │
│                     │                                           │
│                     └── return 0                                │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  User receives output:                                          │
│  /dev/sda1 /                                                    │
│  sysfs /sys                                                     │
│  proc /proc                                                     │
│  ...                                                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Takeaways

### 1. procfs Creation

```c
/* Create */
proc_entry = proc_create("name", mode, parent, &ops);

/* Remove */
proc_remove(proc_entry);
```

### 2. seq_file for Output

For simple output, use `single_open`:
```c
static int my_show(struct seq_file *m, void *v)
{
    seq_printf(m, "output\n");
    return 0;
}

static int my_open(struct inode *inode, struct file *file)
{
    return single_open(file, my_show, NULL);
}
```

### 3. Accessing Mount Information

```c
/* Get current mount namespace */
struct mnt_namespace *ns = current->nsproxy->mnt_ns;

/* Iterate mounts */
list_for_each_entry(mnt, &ns->list, mnt_list) {
    /* mnt->mnt_devname - device name */
    /* mnt->mnt.mnt_root - root dentry */
}
```

### 4. Kernel Linked Lists

```c
/* Iterate through list */
list_for_each_entry(item, &list_head, member_name) {
    /* process item */
}
```

### 5. Path Resolution

```c
/* Convert dentry to path string */
char *path = dentry_path_raw(dentry, buffer, buffer_size);
```

---

## Important Notes

### Internal Structures

This module uses internal kernel structures (`struct mount` from `fs/mount.h`). These are not part of the stable kernel API and may change between kernel versions.

### Namespace Awareness

The output shows mounts in the **current process's mount namespace**. Different processes (e.g., containers) may see different mounts.

### Comparison with /proc/mounts

| Feature | /proc/mymounts | /proc/mounts |
|---------|----------------|--------------|
| Format | Simple (dev path) | Full mount options |
| Namespace | Current | Current |
| Complexity | Basic | Full details |

---

## References

- Linux Kernel procfs documentation
- seq_file interface: `Documentation/filesystems/seq_file.rst`
- VFS documentation: `Documentation/filesystems/vfs.rst`
- Namespaces: `man 7 namespaces`
