#!/bin/bash

# Update submodules
git submodule init
git submodule update

# Build buildroot
cd ./buildroot
make BR2_EXTERNAL=../ readonly-rootfs-overlay_defconfig
make
