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

MODULE_LICENSE("GPL");
MODULE_AUTHOR("zweng");
MODULE_DESCRIPTION("Debugfs module for fortytwo");

#define LOGIN "zweng"
#define LOGIN_LEN 5

/* debugfs directory entry */
static struct dentry *fortytwo_dir;

/* foo file storage and lock */
static char foo_buf[PAGE_SIZE];
static size_t foo_len;
static DEFINE_MUTEX(foo_mutex);

/*
 * id file operations - same as Assignment 05
 * Read: returns student login
 * Write: accepts only student login, else returns error
 */
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
	.owner	= THIS_MODULE,
	.read	= id_read,
	.write	= id_write,
};

/*
 * jiffies file operations
 * Read-only: returns current jiffies value
 */
static ssize_t jiffies_read(struct file *file, char __user *buf,
			    size_t count, loff_t *ppos)
{
	char tmp[32];
	int len;

	len = snprintf(tmp, sizeof(tmp), "%lu\n", jiffies);
	return simple_read_from_buffer(buf, count, ppos, tmp, len);
}

static const struct file_operations jiffies_fops = {
	.owner	= THIS_MODULE,
	.read	= jiffies_read,
};

/*
 * foo file operations
 * Write: root only, stores up to PAGE_SIZE bytes
 * Read: anyone, returns stored data
 * Uses mutex for concurrent access protection
 */
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
	if (*ppos ==0) {
		memset(foo_buf, 0, PAGE_SIZE);
		foo_len = 0;
	} 
	ret = simple_write_to_buffer(foo_buf, PAGE_SIZE, ppos, buf, count);
	if (ret > 0) {
  		if (*ppos > foo_len)
			foo_len = *ppos;
  	}
	mutex_unlock(&foo_mutex);

	return ret;
}

static const struct file_operations foo_fops = {
	.owner	= THIS_MODULE,
	.read	= foo_read,
	.write	= foo_write,
};

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

static void __exit fortytwo_exit(void)
{
	/* Remove directory and all files inside */
	debugfs_remove_recursive(fortytwo_dir);
	pr_info("fortytwo: debugfs interface removed\n");
}

module_init(fortytwo_init);
module_exit(fortytwo_exit);
