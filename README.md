## Usage
build u-boot image:

	build/mk-uboot.sh respeaker

build kernel image:

	build/mk-kernel.sh respeaker
    
    
build rootfs image:

	fllow readme in rk-rootfs-build

build one system image:

	build/mk-image.sh -c rk322x -t system -s 4000 -r rk-rootfs-build/linaro-rootfs.img
