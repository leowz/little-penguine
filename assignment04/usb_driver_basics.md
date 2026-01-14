# USB Driver Basics for Linux Kernel

## Assignment 04 Overview

### What the Subject Asks

**Task:** Modify the Hello World module from Assignment 01 so that it **automatically loads** when any USB keyboard is plugged in.

The module should be triggered by userspace hotplug tools (depmod, kmod, udev, mdev, or systemd - depending on your distribution).

**Turn in:**
- A **udev rules file** (or equivalent for your system)
- Your **updated module code**
- **Proof** that it works

### The Challenge

The tricky part is making the module **auto-load**. This requires two things:

1. **MODULE_DEVICE_TABLE** in the code - tells the kernel which devices this driver supports
2. **udev rules file** (optional but recommended) - explicitly triggers module loading

### Files in This Assignment

| File | Purpose |
|------|---------|
| `hello_usb_keyboard.c` | The kernel module that registers as a USB driver |
| `Makefile` | Build script for the module |
| `hello-usb-keyboard.rules` | udev rules file to trigger auto-loading |

---

## The udev Rules File Explained

The file `hello-usb-keyboard.rules` tells the udev daemon when to load our module:

```
ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", RUN+="/sbin/modprobe hello_usb_keyboard"
```

| Part | Meaning |
|------|---------|
| `ACTION=="add"` | Trigger when a device is **plugged in** |
| `SUBSYSTEM=="usb"` | Only for **USB** devices |
| `ATTR{bInterfaceClass}=="03"` | Only if interface class is **03** (HID devices - keyboards, mice, etc.) |
| `RUN+="/sbin/modprobe hello_usb_keyboard"` | Execute this command to **load the module** |

### Installation

```bash
# Copy rules file to udev directory
sudo cp hello-usb-keyboard.rules /etc/udev/rules.d/

# Reload udev rules
sudo udevadm control --reload-rules

# Install the module to /lib/modules/
sudo make install  # or manually: sudo cp hello_usb_keyboard.ko /lib/modules/$(uname -r)/

# Update module dependencies
sudo depmod -a
```

### Why Two Mechanisms?

1. **MODULE_DEVICE_TABLE** creates entries in `/lib/modules/.../modules.alias`. On systems with kmod/systemd, this alone can trigger auto-loading.

2. **udev rules** provide an explicit fallback that works on any Linux system, regardless of how module auto-loading is configured.

---

## 1. How USB Works (High Level)

```
┌─────────────────────────────────────────────────────────────┐
│                      YOUR COMPUTER                          │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │ Your Driver │◄──►│ USB Core     │◄──►│ USB Host      │  │
│  │ (this code) │    │ (kernel)     │    │ Controller    │  │
│  └─────────────┘    └──────────────┘    └───────┬───────┘  │
└─────────────────────────────────────────────────┼──────────┘
                                                  │ USB Cable
                                          ┌───────▼───────┐
                                          │  USB Keyboard │
                                          └───────────────┘
```

**Key insight**: You don't talk to hardware directly. The **USB Core** subsystem handles all the low-level USB protocol. Your driver just:
1. Tells the kernel "I handle these types of devices"
2. Gets notified when matching devices appear/disappear
3. Communicates through USB Core APIs

---

## 2. USB Device Identification

Every USB device identifies itself with **descriptors**. When you plug in a device, it announces:

```
Device Descriptor
├── Vendor ID:  0x046D (Logitech)
├── Product ID: 0xC534 (Receiver)
└── Configurations
    └── Configuration 1
        └── Interfaces
            └── Interface 0
                ├── Class:    0x03 (HID)
                ├── Subclass: 0x01 (Boot Interface)
                └── Protocol: 0x01 (Keyboard)
```

### Two Ways to Match Devices:

| Method | Macro | Use Case |
|--------|-------|----------|
| **Vendor/Product ID** | `USB_DEVICE(vendor, product)` | Specific device (e.g., your Logitech keyboard) |
| **Interface Class** | `USB_INTERFACE_INFO(class, subclass, proto)` | Category of devices (e.g., ANY keyboard) |

Your code uses the second approach:
```c
{ USB_INTERFACE_INFO(USB_CLASS_HID, 0, 0) }
//                   ^^^^^^^^^^^^  ^  ^
//                   Class=0x03    |  Protocol (0=any)
//                                 Subclass (0=any)
```

This matches **any HID device** (keyboards, mice, gamepads, etc.)

---

## 3. USB Class Codes

USB defines standard classes so generic drivers can work:

| Class | Code | Examples |
|-------|------|----------|
| HID | 0x03 | Keyboard, mouse, gamepad |
| Mass Storage | 0x08 | USB flash drives |
| Audio | 0x01 | USB headsets |
| Video | 0x0E | Webcams |
| Hub | 0x09 | USB hubs |

For keyboards specifically:
- **Class**: 0x03 (HID)
- **Subclass**: 0x01 (Boot Interface - works in BIOS)
- **Protocol**: 0x01 (Keyboard) or 0x02 (Mouse)

---

## 4. The Driver Lifecycle

```
┌────────────────────────────────────────────────────────────────┐
│                        KERNEL BOOT / insmod                    │
│                              │                                 │
│                              ▼                                 │
│                    ┌─────────────────┐                         │
│                    │  module_init()  │                         │
│                    │  usb_register() │──► Driver registered    │
│                    └─────────────────┘    with USB Core        │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                     DEVICE PLUGGED IN                          │
│                              │                                 │
│  USB Core reads device descriptors                             │
│                              │                                 │
│  USB Core checks all registered drivers' id_table              │
│                              │                                 │
│            ┌─────────────────┴─────────────────┐               │
│            │ Match found?                      │               │
│            ▼                                   ▼               │
│     ┌─────────────┐                    No match, try           │
│     │   probe()   │                    other drivers           │
│     └─────────────┘                                            │
│            │                                                   │
│     Return 0 = "I'll handle this device"                       │
│     Return negative = "Not mine, try others"                   │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                     DEVICE UNPLUGGED                           │
│                              │                                 │
│                              ▼                                 │
│                    ┌────────────────┐                          │
│                    │  disconnect()  │                          │
│                    └────────────────┘                          │
│                              │                                 │
│                    Clean up resources                          │
└────────────────────────────────────────────────────────────────┘
```

---

## 5. Key Data Structures

### `struct usb_device_id` - What devices to match

```c
static const struct usb_device_id hello_kbd_table[] = {
    { USB_INTERFACE_INFO(USB_CLASS_HID, 0, 0) },
    { }  // <-- MUST end with empty entry (sentinel)
};
```

### `struct usb_driver` - Your driver's identity

```c
static struct usb_driver hello_kbd_driver = {
    .name       = "hello_usb_keyboard",  // Shows in /sys/bus/usb/drivers/
    .probe      = hello_kbd_probe,       // Called on device plug-in
    .disconnect = hello_kbd_disconnect,  // Called on device removal
    .id_table   = hello_kbd_table,       // What to match
};
```

### `struct usb_interface` - The device you're talking to

Passed to `probe()` and `disconnect()`. Represents one interface of a USB device. A single physical device can have multiple interfaces (e.g., keyboard + media keys).

---

## 6. What a Real Keyboard Driver Would Do

Your current code just prints messages. A real driver would:

```c
static int real_kbd_probe(struct usb_interface *intf,
                          const struct usb_device_id *id)
{
    struct usb_device *udev = interface_to_usbdev(intf);

    // 1. Allocate memory for device state
    // 2. Find the interrupt endpoint (keyboards send data via interrupts)
    // 3. Allocate a URB (USB Request Block) for receiving keystrokes
    // 4. Set up input device (/dev/input/eventX)
    // 5. Submit the URB to start receiving data

    return 0;
}
```

The data flow for keypresses:

```
┌──────────┐    USB     ┌──────────┐   URB    ┌────────────┐   Event   ┌─────────┐
│ Keyboard │──Interrupt─►│ USB Core │─Complete─►│ Your Driver│──Report──►│ /dev/   │
│ Hardware │            │          │          │ (callback) │          │ input/  │
└──────────┘            └──────────┘          └────────────┘          └─────────┘
```

---

## 7. Important Concepts Glossary

| Term | Meaning |
|------|---------|
| **URB** | USB Request Block - a packet of data to/from device |
| **Endpoint** | A "pipe" on the device (IN=device→host, OUT=host→device) |
| **Interrupt Transfer** | Periodic data transfer (keyboards use this for keypresses) |
| **Probe** | Kernel asking "do you want to handle this device?" |
| **Hotplug** | Devices appearing/disappearing at runtime |
| **Interface** | A logical function of a device (one device can have many) |

---

## 8. Try It Yourself

To see USB device info on your system:

```bash
# List all USB devices with class info
lsusb -v 2>/dev/null | grep -E "(Bus|bInterfaceClass|bInterfaceSubClass|bInterfaceProtocol)"

# See which driver handles each device
lsusb -t

# Detailed info for a specific device
lsusb -d 046d:c534 -v   # Replace with your device's vendor:product
```

---

## Summary

Your module does the **minimum viable USB driver**:

1. **Register** with USB Core saying "I want HID devices"
2. **Probe** gets called when matching device plugs in → print message
3. **Disconnect** gets called when device unplugs → print message
4. **Unregister** when module unloads

The actual keyboard functionality (reading keys, reporting to input subsystem) would require much more code involving URBs, endpoints, and the input subsystem.
