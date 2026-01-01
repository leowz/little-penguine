// SPDX-License-Identifier: GPL-2.0
/*
 * /proc/mymounts - List mount points with device names
 */
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
#include <linux/rbtree.h>
#include <../fs/mount.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("zweng");
MODULE_DESCRIPTION("List mount points in /proc/mymounts");

static struct proc_dir_entry *proc_entry;

static int mymounts_show(struct seq_file *m, void *v)
{
	struct mount *mnt;
	struct mnt_namespace *ns;
	struct path mnt_path;
	struct rb_node *node;
	char *buf;
	char *path_name;

	buf = kmalloc(PATH_MAX, GFP_KERNEL);
	if (!buf)
		return -ENOMEM;

	/* Get current mount namespace */
	ns = current->nsproxy->mnt_ns;

	/* Iterate through all mounts in the namespace (rb_tree in 6.16+) */
	for (node = rb_first(&ns->mounts); node; node = rb_next(node)) {
		mnt = rb_entry(node, struct mount, mnt_node);

		/* Get the mount point path */
		mnt_path.mnt = &mnt->mnt;
		mnt_path.dentry = mnt->mnt.mnt_root;
		path_name = d_path(&mnt_path, buf, PATH_MAX);
		if (IS_ERR(path_name))
			continue;

		/* Print: device_name mount_point */
		seq_printf(m, "%s %s\n",
			   mnt->mnt_devname ? mnt->mnt_devname : "none",
			   path_name);
	}

	kfree(buf);
	return 0;
}

static int mymounts_open(struct inode *inode, struct file *file)
{
	return single_open(file, mymounts_show, NULL);
}

static const struct proc_ops mymounts_ops = {
	.proc_open	= mymounts_open,
	.proc_read	= seq_read,
	.proc_lseek	= seq_lseek,
	.proc_release	= single_release,
};

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

static void __exit mymounts_exit(void)
{
	proc_remove(proc_entry);
	pr_info("mymounts: /proc/mymounts removed\n");
}

module_init(mymounts_init);
module_exit(mymounts_exit);
