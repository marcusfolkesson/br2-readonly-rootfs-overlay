=============================
br2-readonly-rootfs-overlay
=============================

This is a Buildroot external module that could be used as a reference design 
when building your own system with an overlayed root filesystem.
It is created as an external module to make it easy to adapt for your to your own application.

The goal is to achieve the same functionality I have in ``meta-readonly-rootfs-overlay`` [1]_ but for Buildroot.

Why does this exists?
=======================

Having a read-only root file system is useful for many scenarios:

* Separate user specific changes from system configuration, and being able to find differences
* Allow factory reset, by deleting the user specific changes
* Have a fallback image in case the user specific changes made the root file system no longer bootable.

Because some data on the root file system changes on first boot or while the
system is running, just mounting the complete root file system as read-only
breaks many applications. There are different solutions to this problem:

* Symlinking/Bind mounting files and directories that could potentially change while the system is running to a writable partition
* Instead of having a read-only root files system, mounting a writable overlay root file system, that uses a read-only file system as its base and writes changed data to another writable partition.

To implement the first solution, the developer needs to analyse which file
needs to change and then create symlinks for them. When doing factory reset,
the developer needs to overwrite every file that is linked with the factory
configuration, to avoid dangling symlinks/binds. While this is more work on the
developer side, it might increase the security, because only files that are
symlinked/bind-mounted can be changed.

This meta-layer provides the second solution. Here no investigation of writable
files are needed and factory reset can be done by just deleting all files or
formatting the writable volume.


How does it work?
==================

This external module makes use of ``Dracut`` [2]_ to create a rootfs.cpio that is
embedded into the Linux kernel as an initramfs.

The initramfs mounts the base root filsystem as read-only and the read-write filesystem as
the upper layer in an overlay filesystem structure.

Dependencies
=============

The setup requires the following kernel configuration (added as fragment file in `board/qemu-x86_64/linux.fragment`): ::

	CONFIG_OVERLAY_FS=y
	CONFIG_BLK_DEV_INITRD=y


Patches
==========

Please submit any patches against the br2-readonly-rootfs-overlay via pull request.

Test it out
=========================

This module will build a x86_64 target that is prepared to be emulated with qemu.

Clone this repository
----------------------

::

	git clone https://github.com/marcusfolkesson/br2-readonly-rootfs-overlay.git

Build
------

Run ``build.sh`` to make a full build.

The script is simple, it just update the Buildroot submodule and start a build:

::

	git clone https://github.com/marcusfolkesson/br2-readonly-rootfs-overlay.git
	#!/bin/bash

	# Update submodules
	git submodule init
	git submodule update

	# Build buildroot
	cd ./buildroot
	make BR2_EXTERNAL=../ readonly-rootfs-overlay_defconfig
	make

Artifacts
----------

The following artifacts are generated in `./buildroot/output/images/` :

* **bzImage** - The Linux kernel

* **start-qemu.sh** - script that will start qemu-system-x86_64 and emulate the whole setup

* **sdcard.img** - The disk image containing two partitions, one for the read-only rootfs and one for the writable upper filesystem

* **rootfs.cpio** - The initramfs file system that is embedded into the kernel

* **rootfs.ext2** - The root filesystem image

* **overlay.ext4** - Empty filsystem image used for the writable layer

Emulate in QEMU
----------------

An script to emulate the whole thing is generated in the output directory.
Execute the `./buildroot/output/images/start-qemu.sh` script to start the emulator.

Once the system has booted, you are able to login as `root`:

::

	Welcome to Buildroot
	buildroot login: root

And as you can see, the root filesystem is overlayed as it should: ::

	$ mount
	...
	/dev/vda1 on /media/rfs/ro type ext2 (ro,noatime,nodiratime)
	/dev/vda2 on /media/rfs/rw type ext4 (rw,noatime,errors=remount-ro)
	overlay on / type overlay (rw,relatime,lowerdir=/media/rfs/ro,upperdir=/media/rfs/rw/upperdir,workdir=/media/rfs/rw/work)
	...

Kernel command line parameters
================================

These examples are not meant to be complete. They just contain parameters that
are used by the initscript of this repository. Some additional paramters might
be necessary.

Example using initrd
---------------------

::

	root=/dev/sda1 rootrw=/dev/sda2

This cmd line start `/sbin/init` with the `/dev/sda1` partition as the read-only
rootfs and the `/dev/sda2` partition as the read-write persistent state.

::

	root=/dev/sda1 rootrw=/dev/sda2 init=/bin/sh

The same as before but it now starts `/bin/sh` instead of `/sbin/init`.

Example without initrd
-------------------------

::

	root=/dev/sda1 rootrw=/dev/sda2 init=/init

This cmd line starts `/sbin/init` with `/dev/sda1` partition as the read-only
rootfs and the `/dev/sda2` partition as the read-write persistent state. When
using this init script without an initrd, `init=/init` has to be set.

::

	root=/dev/sda1 rootrw=/dev/sda2 init=/init rootinit=/bin/sh

The same as before but it now starts `/bin/sh` instead of `/sbin/init`

Details
=========

All kernel parameters that is used to configure `br2-readonly-rootfs-overlay`:

* **root** - specifies the read-only root file system device. If this is not specified, the current rootfs is used.

* **`rootfstype** if support for the read-only file system is not build into the kernel, you can specify the required module name here. It will also be used in the mount command.

* **rootoptions** specifies the mount options of the read-only file system.  Defaults to `noatime,nodiratime`.

* **rootinit** if the `init` parameter was used to specify this init script, `rootinit` can be used to overwrite the default (`/sbin/init`).

* **rootrw** specifies the read-write file system device. If this is not specified, `tmpfs` is used.

* **rootrwfstype** if support for the read-write file system is not build into the kernel, you can specify the required module name here. It will also be used in the mount command.

* **rootrwoptions** specifies the mount options of the read-write file system.  Defaults to `rw,noatime,mode=755`.

* **rootrwreset** set to `yes` if you want to delete all the files in the read-write file system prior to building the overlay root files system.

References
------------

.. [1] https://github.com/marcusfolkesson/meta-readonly-rootfs-overlay
.. [2] https://github.com/dracutdevs/dracut/wiki/

