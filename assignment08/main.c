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
