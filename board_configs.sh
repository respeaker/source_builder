#!/bin/bash -e
BOARD=$1
DEFCONFIG=""
DTB=""
KERNELIMAGE=""
CHIP=""
UBOOT_DEFCONFIG=""
DIR=$PWD

case ${BOARD} in
	"respeaker")
		DEFCONFIG=respeaker_defconfig
		UBOOT_DEFCONFIG=evb-rk3229_defconfig
		DTB=rk3229-respeaker-v2.dtb
		ARCH=arm
		CHIP="rk322x"
		toolchain="gcc_linaro_gnueabihf_6"
		;;
	*)
		echo "board '${BOARD}' not supported!"
		exit -1
		;;
esac


. $DIR/build/gcc.sh  

. "${DIR}/.CC"

export ARCH=arm
export CROSS_COMPILE=${CC}