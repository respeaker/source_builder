#!/bin/sh -e
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

DIR=$PWD
OUT=${DIR}/out

HOST_ARCH=$(uname -m)
HOST_SYST=$(uname -n)
TEMPDIR=$(mktemp -d)

BOARD=$1

if [ "x${ARCH}" = "xi686" ] ; then
	echo "Linaro no longer supports 32bit cross compilers, thus 32bit is no longer suppored by this script..."
	exit
fi

# Number of jobs for make to run in parallel.
CORES=$(getconf _NPROCESSORS_ONLN)
git="git am"

. $DIR/build/board_configs.sh ${BOARD}

git_generic () {
	if [ -d ${TEMPDIR}/u-boot ] ; then
		rm -rf ${TEMPDIR}/u-boot || true
	fi
	git clone --share ${DIR}/u-boot $TEMPDIR}/u-boot
	cd $TEMPDIR}/u-boot
	echo "Starting ${project}  build for: $BOARD"
	echo "-----------------------------"
}

build_u_boot () {
	project="u-boot"
	git_generic

	make ARCH=arm CROSS_COMPILE="${CC}" distclean

	p_dir="${DIR}/build/patches/u-boot"
	case "${board}" in
	respeaker)
		echo "patch -p1 < \"${p_dir}/0001-rockchip-rk322x-remove-default-parts-and-CONFIG_BOOT.patch\""

		${git} "${p_dir}/0001-rockchip-rk322x-remove-default-parts-and-CONFIG_BOOT.patch"
		;;
	esac


	# if [ "x${board}" = "xam57xx_evm_ti" ] ; then
	# 	if [ "x${GIT_SHA}" = "xv2017.01" ] ; then
	# 		git pull ${git_opts} https://github.com/rcn-ee/ti-uboot ti-u-boot-2017.01
	# 		#r1: initial build
	# 		#r2: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=acfdcab5ce406c8cfb607bd0731b7a6d41757679
	# 		#r3: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=438d0991e5a913323f6e38293a3d103d82284d9d
	# 		#r4: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=3ca4ec25c8a6a3586601e8926bac4f5861ccaa2d
	# 		#r5: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=8369eec4f36f4eb8c30e769b3b0ad35d5148f636
	# 		#r6: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=2127a54b2aca99cc0290ff79cba0fe9e2adfd794
	# 		#r7: blank eeprom
	# 		#r8: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=9fd60700db4562ffac00317a9a44761b8c3255f1
	# 		#r9: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=40e76546f34e77cf12454137a3f16322b9610d4c
	# 		#r10: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=5861b3bd349184df97ea26a93fc9b06c65e0ff5e
	# 		#r11: fix new board
	# 		#r12: http://git.ti.com/gitweb/?p=ti-u-boot/ti-u-boot.git;a=commit;h=b79c87e6f7e2d24f262754845c6fc5f45b71bf15
	# 		#r13: (pending)
	# 		RELEASE_VER="-r12" #bump on every change...

	# 		p_dir="${DIR}/patches/ti-2017.01"
	# 		echo "patch -p1 < \"${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch\""
	# 		#halt_patching_uboot
	# 		${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
	# 	fi
	# fi


	if [ -f "${DIR}/stop.after.patch" ] ; then
		echo "-----------------------------"
		pwd
		echo "-----------------------------"
		echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${UBOOT_DEFCONFIG} all"
		echo "-----------------------------"
		exit
	fi
	make ARCH=arm CROSS_COMPILE="${CC}" ${UBOOT_DEFCONFIG} all

	if [ "${CHIP}" = "rk3288" ] || [ "${CHIP}" = "rk322x" ] || [ "${CHIP}" = "rk3036" ]; then
		tools/mkimage -n ${CHIP} -T \
			rksd -d spl/u-boot-spl-dtb.bin idbloader.img
		cat u-boot-dtb.bin >>idbloader.img
		cp idbloader.img ${OUT}/u-boot/
		${DIR}/rkbin/tools/loaderimage --pack --uboot u-boot-dtb.bin uboot.img 0x60000000
		cp uboot.img ${OUT}/u-boot/
		
	fi

	#git_generic
}



respeaker () {
	board=$BOARD
	uboot_config=$UBOOT_DEFCONFIG
	#GIT_SHA="v2015.07"
	build_u_boot
}

echo -e "\e[36m Building U-boot for ${BOARD} board! \e[0m"
echo -e "\e[36m Using ${UBOOT_DEFCONFIG} \e[0m"

respeaker

echo -e "\e[36m U-boot IMAGE READY! \e[0m"
