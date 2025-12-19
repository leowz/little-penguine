// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/usb.h>
#include <linux/usb/ch9.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("zweng");
MODULE_DESCRIPTION("Little Penguin - Assignment 04: USB keyboard hello module");

#define DRIVER_NAME "hello_usb_keyboard"

/*
 * Match any USB HID boot keyboard:
 *  - Class:    0x03 (HID)
 *  - Subclass: 0x01 (Boot Interface)
 *  - Protocol: 0x01 (Keyboard)
 */
static const struct usb_device_id hello_kbd_table[] = {
	{ USB_INTERFACE_INFO(USB_CLASS_HID, 0, 0) },
	{ } /* terminating entry */
};
MODULE_DEVICE_TABLE(usb, hello_kbd_table);

static int hello_kbd_probe(struct usb_interface *interface,
			   const struct usb_device_id *id)
{
	pr_info(DRIVER_NAME ": USB keyboard plugged in\n");
	return 0;	/* we accept the device */
}

static void hello_kbd_disconnect(struct usb_interface *interface)
{
	pr_info(DRIVER_NAME ": USB keyboard unplugged\n");
}

static struct usb_driver hello_kbd_driver = {
	.name       = DRIVER_NAME,
	.probe      = hello_kbd_probe,
	.disconnect = hello_kbd_disconnect,
	.id_table   = hello_kbd_table,
};

static int __init hello_init(void)
{
	int ret;

	pr_info(DRIVER_NAME ": init\n");

	ret = usb_register(&hello_kbd_driver);
	if (ret) {
		pr_err(DRIVER_NAME ": usb_register failed (%d)\n", ret);
		return ret;
	}

	return 0;
}

static void __exit hello_exit(void)
{
	usb_deregister(&hello_kbd_driver);
	pr_info(DRIVER_NAME ": exit\n");
}

module_init(hello_init);
module_exit(hello_exit);
