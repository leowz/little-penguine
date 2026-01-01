// SPDX-License-Identifier: GPL-2.0
#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/miscdevice.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/string.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("zweng");
MODULE_DESCRIPTION("Misc character device for fortytwo");

#define LOGIN "zweng"
#define LOGIN_LEN 5

static ssize_t fortytwo_read(struct file *file, char __user *buf,
			     size_t count, loff_t *ppos)
{
	return simple_read_from_buffer(buf, count, ppos, LOGIN, LOGIN_LEN);
}

static ssize_t fortytwo_write(struct file *file, const char __user *buf,
			      size_t count, loff_t *ppos)
{
	char kbuf[LOGIN_LEN + 1];
	ssize_t len;

	if (count != LOGIN_LEN)
		return -EINVAL;

	len = simple_write_to_buffer(kbuf, LOGIN_LEN, ppos, buf, count);
	if (len < 0) return len;

	kbuf[len] = '\0';

	if (strncmp(kbuf, LOGIN, LOGIN_LEN) != 0)
		return -EINVAL;

	return count;
}

static const struct file_operations fortytwo_fops = {
	.owner	= THIS_MODULE,
	.read	= fortytwo_read,
	.write	= fortytwo_write,
};

static struct miscdevice fortytwo_device = {
	.minor	= MISC_DYNAMIC_MINOR,
	.name	= "fortytwo",
	.fops	= &fortytwo_fops,
	.mode	= 0666,
};

static int __init fortytwo_init(void)
{
	int ret;

	ret = misc_register(&fortytwo_device);
	if (ret) {
		pr_err("fortytwo: failed to register misc device\n");
		return ret;
	}

	pr_info("fortytwo: misc device registered\n");
	return 0;
}

static void __exit fortytwo_exit(void)
{
	misc_deregister(&fortytwo_device);
	pr_info("fortytwo: misc device unregistered\n");
}

module_init(fortytwo_init);
module_exit(fortytwo_exit);
