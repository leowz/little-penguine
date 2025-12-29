# Assignment 08 - Code Style Fix and Bug Correction

This document explains the original broken code, all its issues, and how they were fixed.

---

## Table of Contents

1. [What Does This Code Do?](#what-does-this-code-do)
2. [The Original Broken Code](#the-original-broken-code)
3. [Linux Kernel Coding Style Guide](#linux-kernel-coding-style-guide)
4. [Issues Found and Fixes Applied](#issues-found-and-fixes-applied)
   - [Coding Style Issues](#coding-style-issues)
   - [Bugs and Logic Errors](#bugs-and-logic-errors)
5. [The Fixed Code Explained](#the-fixed-code-explained)
6. [How to Verify Code Style](#how-to-verify-code-style)
7. [How to Build and Test](#how-to-build-and-test)

---

## What Does This Code Do?

The code implements a **"reverse" misc device**. It creates `/dev/reverse` where:

1. **Write** a string to the device → string is stored
2. **Read** from the device → stored string is returned **reversed**

```bash
# Example usage
echo "Hello" > /dev/reverse
cat /dev/reverse
# Output: olleH
```

This was the "challenge" mentioned in the assignment - figuring out what the broken code was supposed to do.

---

## The Original Broken Code

```c
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/slab.h>

// Dont have a license, LOL
MODULE_LICENSE("LICENSE");
MODULE_AUTHOR("Louis Solofrizzo <louis@ne02ptzero.me>");
MODULE_DESCRIPTION("Useless module");

static ssize_t myfd_read
(struct file *fp, char __user *user,
size_t size, loff_t *offs);
static ssize_t myfd_write(struct file *fp, const char __user *user,
size_t size, loff_t *offs);

static struct file_operations myfd_fops = {
.owner = THIS_MODULE, .read = &myfd_read, .write = &myfd_write
};

static struct miscdevice myfd_device = {
.minor = MISC_DYNAMIC_MINOR,.name = "reverse",
.fops = &myfd_fops };

char str[PAGE_SIZE];
char *tmp;

static int __init myfd_init
(void) {
int retval;
retval = misc_register(&(*(&(myfd_device))));
return 1;
}

static void __exit myfd_cleanup
(void) {
}

ssize_t myfd_read
(struct file *fp,
char __user *user,
size_t size,
loff_t *offs)
{
size_t t, i;
char *tmp2;
/***************
* Malloc like a boss
***************/
tmp2 = kmalloc(sizeof(char) * PAGE_SIZE * 2, GFP_KERNEL);
tmp = tmp2;
for (t = strlen(str) - 1, i = 0; t >= 0; t--, i++) {
tmp[i] = str[t];
}
tmp[i] = 0x0;
return simple_read_from_buffer(user, size, offs, tmp, i);
}

ssize_t myfd_write
(struct file *fp,
const char __user *user,
size_t size,
loff_t *offs) {
ssize_t res;
res = 0;
res = simple_write_to_buffer(str, size, offs, user, size) + 1;
// 0x0 = '\0'
str[size + 1] = 0x0;
return res;
}

module_init(myfd_init);
module_exit(myfd_cleanup);
```

---

## Linux Kernel Coding Style Guide

Before analyzing the issues, let's understand the key Linux kernel coding style rules (from `Documentation/process/coding-style.rst`):

### 1. Indentation

```c
/* RULE: Use tabs, and tabs are 8 characters wide */

/* CORRECT */
static int foo(void)
{
	if (condition) {
		do_something();
	}
}

/* WRONG - spaces or wrong tab width */
static int foo(void)
{
    if (condition) {
        do_something();
    }
}
```

### 2. Line Length

```c
/* RULE: Lines should not exceed 80 characters (soft limit: 100) */

/* CORRECT - split long lines */
static ssize_t myfd_read(struct file *fp, char __user *user,
			 size_t size, loff_t *offs)

/* WRONG - too long */
static ssize_t myfd_read(struct file *fp, char __user *user, size_t size, loff_t *offs)
```

### 3. Brace Placement

```c
/* RULE: Opening brace on same line (except for functions) */

/* CORRECT - functions: brace on new line */
static int foo(void)
{
	...
}

/* CORRECT - control statements: brace on same line */
if (condition) {
	do_something();
}

/* WRONG */
static int foo(void) {  /* function brace should be on new line */
	...
}

if (condition)
{                       /* should be on same line as if */
	do_something();
}
```

### 4. Spaces

```c
/* RULE: Space after keywords, no space after function names */

/* CORRECT */
if (condition)
while (condition)
for (i = 0; i < n; i++)
foo(arg);

/* WRONG */
if(condition)           /* need space after if */
foo (arg);              /* no space before ( in function calls */
```

### 5. Comments

```c
/* RULE: Use C-style comments, not C++ style */

/* CORRECT */
/* This is a comment */
/*
 * Multi-line comment
 * formatted like this
 */

/* WRONG */
// This is a C++ style comment
```

### 6. Function Declarations

```c
/* RULE: Return type and function name on same line */

/* CORRECT */
static int my_function(int arg)
{
	...
}

/* WRONG */
static int
my_function(int arg)
{
	...
}
```

### 7. Struct Initialization

```c
/* RULE: One member per line, proper alignment */

/* CORRECT */
static struct file_operations fops = {
	.owner	= THIS_MODULE,
	.read	= my_read,
	.write	= my_write,
};

/* WRONG */
static struct file_operations fops = {
.owner = THIS_MODULE, .read = my_read, .write = my_write };
```

### 8. Global Variables

```c
/* RULE: Global variables should be static if not used outside the file */

/* CORRECT */
static char buffer[PAGE_SIZE];

/* WRONG */
char buffer[PAGE_SIZE];  /* Missing static */
```

---

## Issues Found and Fixes Applied

### Coding Style Issues

#### Issue 1: C++ Style Comments

```c
/* ORIGINAL (wrong) */
// Dont have a license, LOL
// 0x0 = '\0'

/* FIXED */
/* Removed unnecessary comments or converted to C style */
```

**Rule:** Linux kernel uses C89/C90 standard which prefers `/* */` comments.

---

#### Issue 2: Function Name on Separate Line

```c
/* ORIGINAL (wrong) */
static ssize_t myfd_read
(struct file *fp, char __user *user,

static int __init myfd_init
(void) {

ssize_t myfd_read
(struct file *fp,

/* FIXED */
static ssize_t myfd_read(struct file *fp, char __user *user,
			 size_t size, loff_t *offs)

static int __init myfd_init(void)
```

**Rule:** Function name and opening parenthesis should be on the same line.

---

#### Issue 3: Bad Struct Initialization Formatting

```c
/* ORIGINAL (wrong) */
static struct file_operations myfd_fops = {
.owner = THIS_MODULE, .read = &myfd_read, .write = &myfd_write
};

static struct miscdevice myfd_device = {
.minor = MISC_DYNAMIC_MINOR,.name = "reverse",
.fops = &myfd_fops };

/* FIXED */
static const struct file_operations myfd_fops = {
	.owner	= THIS_MODULE,
	.read	= myfd_read,
	.write	= myfd_write,
};

static struct miscdevice myfd_device = {
	.minor	= MISC_DYNAMIC_MINOR,
	.name	= "reverse",
	.fops	= &myfd_fops,
};
```

**Rules:**
- One member per line
- Proper indentation with tabs
- Align values using tabs
- Closing brace and semicolon on separate line
- Use `const` for file_operations that don't change
- Don't use `&` for function pointers (it's implicit)

---

#### Issue 4: Missing `static` on Global Variables

```c
/* ORIGINAL (wrong) */
char str[PAGE_SIZE];
char *tmp;

/* FIXED */
static char str[PAGE_SIZE];
static char tmp[PAGE_SIZE];
```

**Rule:** Global variables should be `static` if only used within the file.

---

#### Issue 5: Missing `static` on Functions

```c
/* ORIGINAL (wrong) */
ssize_t myfd_read(...)
ssize_t myfd_write(...)

/* FIXED */
static ssize_t myfd_read(...)
static ssize_t myfd_write(...)
```

**Rule:** Functions not exported should be `static`.

---

#### Issue 6: Unnecessary Forward Declarations

```c
/* ORIGINAL (wrong) */
static ssize_t myfd_read
(struct file *fp, char __user *user,
size_t size, loff_t *offs);
static ssize_t myfd_write(struct file *fp, const char __user *user,
size_t size, loff_t *offs);

/* FIXED */
/* Removed - functions defined before they're used */
```

**Rule:** Prefer ordering functions so forward declarations aren't needed.

---

#### Issue 7: Ugly Comment Block

```c
/* ORIGINAL (wrong) */
/***************
* Malloc like a boss
***************/

/* FIXED */
/* Removed - unnecessary and unprofessional */
```

**Rule:** Comments should be useful and professional.

---

#### Issue 8: Bad Indentation in for Loop

```c
/* ORIGINAL (wrong) */
for (t = strlen(str) - 1, i = 0; t >= 0; t--, i++) {
tmp[i] = str[t];
}

/* FIXED */
for (t = len - 1, i = 0; t >= 0; t--, i++)
	tmp[i] = str[t];
```

**Rules:**
- Body must be indented
- Single statement doesn't need braces

---

#### Issue 9: 0x0 Instead of '\0'

```c
/* ORIGINAL (wrong) */
tmp[i] = 0x0;
str[size + 1] = 0x0;

/* FIXED */
tmp[i] = '\0';
str[ret] = '\0';
```

**Rule:** Use `'\0'` for null terminator - it's clearer and more semantic.

---

### Bugs and Logic Errors

#### Bug 1: Invalid License String

```c
/* ORIGINAL (wrong) */
MODULE_LICENSE("LICENSE");

/* FIXED */
MODULE_LICENSE("GPL");
```

**Problem:** "LICENSE" is not a valid license identifier. This would:
- Mark the kernel as "tainted"
- Prevent access to GPL-only symbols
- Cause warnings

**Valid licenses:** "GPL", "GPL v2", "GPL and additional rights", "Dual BSD/GPL", "Dual MIT/GPL", "Dual MPL/GPL", "Proprietary"

---

#### Bug 2: Wrong Return Value in init

```c
/* ORIGINAL (wrong) */
static int __init myfd_init(void) {
    int retval;
    retval = misc_register(&(*(&(myfd_device))));
    return 1;  /* BUG: returns 1 (error) instead of 0 (success) */
}

/* FIXED */
static int __init myfd_init(void)
{
    return misc_register(&myfd_device);
}
```

**Problem:**
- In kernel, return 0 = success, non-zero = error
- `return 1` means "module failed to load"
- Also: `&(*(&(myfd_device)))` is unnecessarily complex, just use `&myfd_device`

---

#### Bug 3: Missing misc_deregister in cleanup

```c
/* ORIGINAL (wrong) */
static void __exit myfd_cleanup(void) {
    /* Empty! Device never unregistered */
}

/* FIXED */
static void __exit myfd_cleanup(void)
{
    misc_deregister(&myfd_device);
}
```

**Problem:** Without `misc_deregister()`:
- `/dev/reverse` remains after module unload
- Resource leak
- System instability

---

#### Bug 4: Memory Leak in read Function

```c
/* ORIGINAL (wrong) */
tmp2 = kmalloc(sizeof(char) * PAGE_SIZE * 2, GFP_KERNEL);
tmp = tmp2;
/* ... use tmp ... */
/* Never freed! */

/* FIXED */
static char tmp[PAGE_SIZE];  /* Static buffer, no allocation needed */
```

**Problem:**
- Every read allocates memory that's never freed
- Eventually exhausts kernel memory
- `sizeof(char)` is always 1, unnecessary

**Solution:** Use a static buffer instead of dynamic allocation.

---

#### Bug 5: Unsigned Integer Underflow

```c
/* ORIGINAL (wrong) */
size_t t, i;  /* size_t is UNSIGNED */
for (t = strlen(str) - 1, i = 0; t >= 0; t--, i++) {
    /* When t reaches 0 and decrements, it wraps to SIZE_MAX */
    /* t >= 0 is ALWAYS true for unsigned! */
    /* INFINITE LOOP! */
}

/* FIXED */
ssize_t len;
ssize_t i;
ssize_t t;  /* ssize_t is SIGNED */

len = strlen(str);
for (t = len - 1, i = 0; t >= 0; t--, i++)
    tmp[i] = str[t];
```

**Problem:**
- `size_t` is unsigned (can't be negative)
- When `t` is 0 and decremented, it becomes `SIZE_MAX` (huge positive number)
- `t >= 0` is always true for unsigned types
- Results in infinite loop and buffer overflow

**Solution:** Use signed type (`ssize_t`) for loop counter.

---

#### Bug 6: Wrong Parameters to simple_write_to_buffer

```c
/* ORIGINAL (wrong) */
res = simple_write_to_buffer(str, size, offs, user, size) + 1;
/*                               ^^^^
 *                               Should be buffer size (PAGE_SIZE),
 *                               not input size!
 */

/* FIXED */
ret = simple_write_to_buffer(str, PAGE_SIZE, offs, user, size);
```

**Function signature:**
```c
ssize_t simple_write_to_buffer(
    void *to,           /* destination buffer */
    size_t available,   /* size of destination buffer */
    loff_t *ppos,       /* file position */
    const void __user *from,  /* source (userspace) */
    size_t count        /* bytes to write */
);
```

**Problem:** Using `size` (user input size) instead of `PAGE_SIZE` (buffer size) could cause buffer overflow.

---

#### Bug 7: Off-by-One Error in Null Termination

```c
/* ORIGINAL (wrong) */
str[size + 1] = 0x0;  /* Off by one! */

/* FIXED */
str[ret] = '\0';  /* ret is actual bytes written */
```

**Problem:**
- If user writes 5 bytes, `size` is 5
- Data is written to `str[0]` through `str[4]`
- `str[size + 1]` = `str[6]` leaves `str[5]` uninitialized
- Should null-terminate at `str[5]`

**Also:** Should use return value of `simple_write_to_buffer`, not input `size`.

---

#### Bug 8: Unnecessary "+ 1" on Return Value

```c
/* ORIGINAL (wrong) */
res = simple_write_to_buffer(str, size, offs, user, size) + 1;
return res;

/* FIXED */
ret = simple_write_to_buffer(str, PAGE_SIZE, offs, user, size);
if (ret < 0)
    return ret;
str[ret] = '\0';
return ret;
```

**Problem:** Adding 1 to the return value makes no sense and reports wrong bytes written.

---

#### Bug 9: Missing Error Handling

```c
/* ORIGINAL (wrong) */
tmp2 = kmalloc(...);  /* Could return NULL! */
/* No NULL check */

res = simple_write_to_buffer(...);  /* Could return negative error! */
/* No error check */

/* FIXED */
ret = simple_write_to_buffer(str, PAGE_SIZE, offs, user, size);
if (ret < 0)
    return ret;
```

**Problem:** Kernel functions can fail. Always check return values.

---

#### Bug 10: Missing Bounds Check on Write

```c
/* ORIGINAL (wrong) */
/* No check if size > PAGE_SIZE */

/* FIXED */
if (size >= PAGE_SIZE)
    return -EINVAL;
```

**Problem:** Without bounds checking, user could write more than buffer can hold.

---

## The Fixed Code Explained

### Complete Fixed Code

```c
// SPDX-License-Identifier: GPL-2.0
/*
 * Reverse string misc device driver
 *
 * Write a string to /dev/reverse, read it back reversed.
 */
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/string.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Louis Solofrizzo <louis@ne02ptzero.me>");
MODULE_DESCRIPTION("Reverse string module");

static char str[PAGE_SIZE];
static char tmp[PAGE_SIZE];

static ssize_t myfd_read(struct file *fp, char __user *user,
			 size_t size, loff_t *offs)
{
	ssize_t len;
	ssize_t i;
	ssize_t t;

	len = strlen(str);

	for (t = len - 1, i = 0; t >= 0; t--, i++)
		tmp[i] = str[t];

	tmp[i] = '\0';

	return simple_read_from_buffer(user, size, offs, tmp, len);
}

static ssize_t myfd_write(struct file *fp, const char __user *user,
			  size_t size, loff_t *offs)
{
	ssize_t ret;

	if (size >= PAGE_SIZE)
		return -EINVAL;

	ret = simple_write_to_buffer(str, PAGE_SIZE, offs, user, size);
	if (ret < 0)
		return ret;

	str[ret] = '\0';

	return ret;
}

static const struct file_operations myfd_fops = {
	.owner	= THIS_MODULE,
	.read	= myfd_read,
	.write	= myfd_write,
};

static struct miscdevice myfd_device = {
	.minor	= MISC_DYNAMIC_MINOR,
	.name	= "reverse",
	.fops	= &myfd_fops,
};

static int __init myfd_init(void)
{
	return misc_register(&myfd_device);
}

static void __exit myfd_cleanup(void)
{
	misc_deregister(&myfd_device);
}

module_init(myfd_init);
module_exit(myfd_cleanup);
```

### Code Flow

```
                    WRITE "Hello"
                         │
                         ▼
┌──────────────────────────────────────────┐
│  myfd_write()                            │
│                                          │
│  1. Check size < PAGE_SIZE               │
│  2. Copy "Hello" from userspace to str   │
│  3. Null-terminate: str = "Hello\0"      │
│  4. Return 5 (bytes written)             │
└──────────────────────────────────────────┘

                    READ
                      │
                      ▼
┌──────────────────────────────────────────┐
│  myfd_read()                             │
│                                          │
│  1. len = strlen("Hello") = 5            │
│  2. Reverse loop:                        │
│     t=4: tmp[0] = str[4] = 'o'           │
│     t=3: tmp[1] = str[3] = 'l'           │
│     t=2: tmp[2] = str[2] = 'l'           │
│     t=1: tmp[3] = str[1] = 'e'           │
│     t=0: tmp[4] = str[0] = 'H'           │
│  3. tmp[5] = '\0'                        │
│  4. tmp = "olleH\0"                      │
│  5. Copy to userspace                    │
│  6. Return 5 (bytes read)                │
└──────────────────────────────────────────┘

                      │
                      ▼
               Output: "olleH"
```

---

## How to Verify Code Style

### Using checkpatch.pl

The Linux kernel includes a script to check coding style:

```bash
# From kernel source directory
./scripts/checkpatch.pl --no-tree -f /path/to/main.c

# Expected output for fixed code:
# total: 0 errors, 0 warnings, XX lines checked
```

### Common checkpatch Warnings

| Warning | Meaning |
|---------|---------|
| "code indent should use tabs" | Spaces used instead of tabs |
| "line over 80 characters" | Line too long |
| "space required after ','" | Missing space |
| "trailing whitespace" | Spaces at end of line |
| "missing Signed-off-by line" | For patches |

---

## How to Build and Test

### Build

```bash
cd assignment08
make
```

### Load and Test

```bash
# Load module
sudo insmod main.ko

# Check device exists
ls -la /dev/reverse

# Test basic functionality
echo "Hello World" > /dev/reverse
cat /dev/reverse
# Output: dlroW olleH

# Test with different strings
echo -n "abcde" > /dev/reverse
cat /dev/reverse
# Output: edcba

echo -n "A" > /dev/reverse
cat /dev/reverse
# Output: A

echo -n "racecar" > /dev/reverse
cat /dev/reverse
# Output: racecar (palindrome!)

# Unload
sudo rmmod main
```

### Verify No Memory Leaks

```bash
# Before loading
cat /proc/meminfo | grep Slab

# Load and use module multiple times
sudo insmod main.ko
for i in {1..1000}; do
    echo "test$i" > /dev/reverse
    cat /dev/reverse > /dev/null
done

# Check memory didn't grow significantly
cat /proc/meminfo | grep Slab

sudo rmmod main
```

---

## Summary of All Fixes

### Coding Style Fixes

| Issue | Original | Fixed |
|-------|----------|-------|
| Comments | `// C++ style` | `/* C style */` |
| Function declaration | Name on separate line | Name with parenthesis |
| Struct init | All on one line | One member per line |
| Global variables | Missing `static` | Added `static` |
| Functions | Missing `static` | Added `static` |
| Indentation | Inconsistent | Tabs, 8 chars |
| Null character | `0x0` | `'\0'` |

### Bug Fixes

| Bug | Original | Fixed |
|-----|----------|-------|
| License | `"LICENSE"` | `"GPL"` |
| Init return | `return 1` | `return misc_register(...)` |
| Cleanup | Empty | `misc_deregister()` |
| Memory | `kmalloc` never freed | Static buffer |
| Loop variable | `size_t` (unsigned) | `ssize_t` (signed) |
| Buffer size | Wrong parameter | `PAGE_SIZE` |
| Null termination | Off by one | Correct index |
| Return value | `+ 1` | Correct value |
| Error handling | None | Check return values |
| Bounds check | None | Check size < PAGE_SIZE |

---

## References

- Linux Kernel Coding Style: https://www.kernel.org/doc/html/latest/process/coding-style.html
- checkpatch.pl documentation: https://www.kernel.org/doc/html/latest/dev-tools/checkpatch.html
