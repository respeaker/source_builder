#!/bin/bash -e
#
# Copyright (c) 2017 Baozhu Zuo  <zuobaozhu@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
LOCALPATH=$(pwd)
OUT=${LOCALPATH}/out
TOOLPATH=${LOCALPATH}/rkbin/tools
EXTLINUXPATH=${LOCALPATH}/build/extlinux
CHIP=""
PART=""
SIZE=""
TARGET=""
ROOTFS_PATH=""
DATE=`date +%Y%m%d`
PATH=$PATH:$TOOLPATH
IMAGE_NAME=respeaker-v2-stretch-${DATE}

source $LOCALPATH/build/partitions.sh

usage() {
	echo -e "\nUsage: build/mk-image.sh -c rk322x -t system -i desktop -s 4000 -r  rootfs/linaro-rootfs.img \n"
	echo -e "       build/mk-image.sh -c rk3288 -t boot\n"
}
finish() {
	echo -e "\e[31m MAKE IMAGE FAILED.\e[0m"
	exit -1
}
trap finish ERR

OLD_OPTIND=$OPTIND
while getopts "c:t:i:s:r:h" flag; do
	case $flag in
		c)
			CHIP="$OPTARG"
			;;
		t)
			PART="$OPTARG"
			;;
		i)
			TARGET="$OPTARG"
			;;
		s)
			SIZE="$OPTARG"
			if [ $SIZE -le 120 ]; then
				echo -e "\e[31m SYSTEM IMAGE SIZE TOO SMALL \e[0m"
				exit -1
			fi
			;;
		r)
			ROOTFS_PATH="$OPTARG"
			;;
	esac
done
OPTIND=$OLD_OPTIND

if [ ! -e ${EXTLINUXPATH}/${CHIP}.conf ]; then
	CHIP="rk322x"
fi

if [ ! $CHIP ] && [ ! $PART ]; then
	usage
	exit
fi

generate_boot_image() {
	BOOT=${OUT}/boot.img
	rm -rf ${BOOT}

	echo -e "\e[36m Generate Boot image start\e[0m"

	# 100 Mb
	mkfs.vfat -n "boot" -S 512 -C ${BOOT} $((100 * 1024))

	mmd -i ${BOOT} ::/extlinux
	mcopy -i ${BOOT} -s ${EXTLINUXPATH}/${CHIP}.conf ::/extlinux/extlinux.conf
	mcopy -i ${BOOT} -s ${OUT}/kernel/* ::

	echo -e "\e[36m Generate Boot image : ${BOOT} success! \e[0m"
}

generate_system_image() {
	SYSTEM=${OUT}/${IMAGE_NAME}.img
	rm -rf ${SYSTEM}

	echo "Generate System image : ${SYSTEM} !"

	dd if=/dev/zero of=${SYSTEM} bs=1M count=0 seek=$SIZE

	echo "parted -s ${SYSTEM} mklabel gpt"
	parted -s ${SYSTEM} mklabel gpt
	
	echo "parted -s ${SYSTEM} unit s mkpart loader1 ${LOADER1_START} $(expr ${RESERVED1_START} - 1)"
	parted -s ${SYSTEM} unit s mkpart loader1 ${LOADER1_START} $(expr ${RESERVED1_START} - 1)
	
	echo "parted -s ${SYSTEM} unit s mkpart reserved1 ${RESERVED1_START} $(expr ${RESERVED2_START} - 1)"
	parted -s ${SYSTEM} unit s mkpart reserved1 ${RESERVED1_START} $(expr ${RESERVED2_START} - 1)

	echo "parted -s ${SYSTEM} unit s mkpart reserved2 ${RESERVED2_START} $(expr ${LOADER2_START} - 1)"
	parted -s ${SYSTEM} unit s mkpart reserved2 ${RESERVED2_START} $(expr ${LOADER2_START} - 1)

	echo "parted -s ${SYSTEM} unit s mkpart loader2 ${LOADER2_START} $(expr ${ATF_START} - 1)"
	parted -s ${SYSTEM} unit s mkpart loader2 ${LOADER2_START} $(expr ${ATF_START} - 1)

	echo "parted -s ${SYSTEM} unit s mkpart atf ${ATF_START} $(expr ${BOOT_START} - 1)"
	parted -s ${SYSTEM} unit s mkpart atf ${ATF_START} $(expr ${BOOT_START} - 1)

	echo "parted -s ${SYSTEM} unit s mkpart boot ${BOOT_START} $(expr ${ROOTFS_START} - 1)"
	parted -s ${SYSTEM} unit s mkpart boot ${BOOT_START} $(expr ${ROOTFS_START} - 1)

	echo "parted -s ${SYSTEM} set 6 boot on"
	parted -s ${SYSTEM} set 6 boot on

	echo "parted -s ${SYSTEM} unit s mkpart root ${ROOTFS_START} 100%"
	parted -s ${SYSTEM} unit s mkpart root ${ROOTFS_START} 100%

	#burn idbloader
	echo "dd if=${OUT}/u-boot/idbloader.img of=${SYSTEM} seek=${LOADER1_START} conv=notrunc"
	dd if=${OUT}/u-boot/idbloader.img of=${SYSTEM} seek=${LOADER1_START} conv=notrunc
	
	#burn  u-boot
	echo "dd if=${OUT}/u-boot/uboot.img of=${SYSTEM} seek=${LOADER2_START} conv=notrunc"
	dd if=${OUT}/u-boot/uboot.img of=${SYSTEM} seek=${LOADER2_START} conv=notrunc

	#burn trust.img
	echo "dd if=${LOCALPATH}}/build/binary/trust.img  of=${SYSTEM} seek=${ATF_START} conv=notrunc"
	dd if=${LOCALPATH}/build/binary/trust.img of=${SYSTEM} seek=${ATF_START} conv=notrunc

	#burn kernel
	echo "dd if=${OUT}/boot.img of=${SYSTEM} conv=notrunc seek=${BOOT_START} "
	dd if=${OUT}/boot.img of=${SYSTEM} conv=notrunc seek=${BOOT_START} status=progress

	#burn rootfs
	echo "dd if=${ROOTFS_PATH} of=${SYSTEM} seek=${ROOTFS_START}"
	dd if=${ROOTFS_PATH} of=${SYSTEM} seek=${ROOTFS_START} status=progress

	#compress the image
	echo "7z a ${OUT}/${IMAGE_NAME}.7z ${SYSTEM}"
	7z a ${OUT}/${IMAGE_NAME}.7z ${SYSTEM}
}


generate_rootfs(){
	cd $LOCALPATH/rootfs
	sudo ./mk-base-debian.sh
	sudo ./mk-rootfs.sh
	sudo ./mk-rootfs-image.sh
	cd $LOCALPATH
}

if [ "$PART" = "boot" ]; then
	generate_boot_image
elif [ "$PART" == "system" ] || [ "$CHIP" == "rk322x" ]; then
	generate_rootfs
	generate_system_image
fi
