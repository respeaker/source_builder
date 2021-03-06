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
EXTLINUXPATH=${LOCALPATH}/build/extlinux
BOARD=$1
KERNEL_VERSION=-respeaker-r1
KVERSION=4.4.92${KERNEL_VERSION}

version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }

finish() {
	echo -e "\e[31m MAKE KERNEL IMAGE FAILED.\e[0m"
	exit -1
}
trap finish ERR

if [ $# != 1 ]; then
	BOARD=respeaker
fi

[ ! -d ${OUT} ] && mkdir ${OUT}
[ ! -d ${OUT}/kernel ] && mkdir ${OUT}/kernel
[ ! -d ${OUT}/deploy ] && mkdir ${OUT}/deploy

if [ ! "${CORES}" ] ; then
        CORES=$(getconf _NPROCESSORS_ONLN)
fi



. $LOCALPATH/build/board_configs.sh $BOARD

if [ $? -ne 0 ]; then
	exit
fi

echo -e "\e[36m Building kernel for ${BOARD} board! \e[0m"
echo -e "\e[36m Using ${DEFCONFIG} \e[0m"

build_opts="-j${CORES}"
build_opts="${build_opts} LOCALVERSION=${KERNEL_VERSION}"
build_opts="${build_opts} KDEB_PKGVERSION=1stable"


git_generic () {
	if [ -d ${LOCALPATH}/kernel-src ] ; then
		rm -rf ${LOCALPATH}/kernel-src || true
	fi
	git clone --share  ${LOCALPATH}/kernel  ${LOCALPATH}/kernel-src
	cd ${LOCALPATH}/kernel-src
	#we use this tag
	#git checkout release-20170705 
	echo "-----------------------------"
}
git="git am"
if [ ! -f ${LOCALPATH}/.develop ] ; then
	case "${BOARD}" in
		respeaker)
			git_generic
			p_dir="${DIR}/build/patches/kernel"
			echo "patch -p1 < \"${p_dir}/kernel.inc/0001-apply-kernel.org-patch-4.4.83-84.patch\""
			 ${git}  "${p_dir}/kernel.inc/0001-apply-kernel.org-patch-4.4.83-84.patch"

			echo "patch -p1 < \"${p_dir}/kernel.inc/0002-apply-kernel.org-patch-4.4.84-85.patch\""
			 ${git}  "${p_dir}/kernel.inc/0002-apply-kernel.org-patch-4.4.84-85.patch"

			echo "patch -p1 < \"${p_dir}/kernel.inc/0003-apply-kernel.org-patch-4.4.85-86.patch\""
			 ${git}  "${p_dir}/kernel.inc/0003-apply-kernel.org-patch-4.4.85-86.patch"

			echo "patch -p1 < \"${p_dir}/kernel.inc/0004-apply-kernel.org-patch-4.4.86-87.patch\""
			 ${git}  "${p_dir}/kernel.inc/0004-apply-kernel.org-patch-4.4.86-87.patch"

			echo "patch -p1 < \"${p_dir}/kernel.inc/0005-apply-kernel.org-patch-4.4.87-88.patch\""
			 ${git}  "${p_dir}/kernel.inc/0005-apply-kernel.org-patch-4.4.87-88.patch"

			echo "patch -p1 < \"${p_dir}/kernel.inc/0006-apply-kernel.org-patch-4.4.88-89.patch\""
			 ${git}  "${p_dir}/kernel.inc/0006-apply-kernel.org-patch-4.4.88-89.patch"

			echo "patch -p1 < \"${p_dir}/kernel.inc/0007-apply-kernel.org-patch-4.4.89-90.patch\""
			 ${git}  "${p_dir}/kernel.inc/0007-apply-kernel.org-patch-4.4.89-90.patch"

			echo "patch -p1 < \"${p_dir}/kernel.inc/0008-apply-kernel.org-patch-4.4.90-91.patch\""
			 ${git}  "${p_dir}/kernel.inc/0008-apply-kernel.org-patch-4.4.90-91.patch"

			echo "patch -p1 < \"${p_dir}/kernel.inc/0009-apply-kernel.org-patch-4.4.91-92.patch\""
			 ${git}  "${p_dir}/kernel.inc/0009-apply-kernel.org-patch-4.4.91-92.patch"			 			 			 			 			 			 			 

			echo "patch -p1 < \"${p_dir}/0001-driver-dma-fix-some-bugs-on-alsa-play-music.patch\""
			 ${git}  "${p_dir}/0001-driver-dma-fix-some-bugs-on-alsa-play-music.patch"

			echo "patch -p1 < \"${p_dir}/0002-sound-soc-rockchip-set-the-i2s-default-mclk-when-the.patch\""
			 ${git}  "${p_dir}/0002-sound-soc-rockchip-set-the-i2s-default-mclk-when-the.patch"

			echo "patch -p1 < \"${p_dir}/0003-sound-soc-add-dt-name-to-alsa-dummy-driver.patch\""
			 ${git}  "${p_dir}/0003-sound-soc-add-dt-name-to-alsa-dummy-driver.patch"

			echo "patch -p1 < \"${p_dir}/0004-sound-codecs-add-x-power-ac108-multichannel-ADC.patch\""
			 ${git}  "${p_dir}/0004-sound-codecs-add-x-power-ac108-multichannel-ADC.patch"

			echo "patch -p1 < \"${p_dir}/0005-sound-codecs-add-rk322x-on-chip-DAC-driver.patch\""
			 ${git}  "${p_dir}/0005-sound-codecs-add-rk322x-on-chip-DAC-driver.patch"

			echo "patch -p1 < \"${p_dir}/0006-sound-codecs-add-ac108-and-rk3228-dac-to-makefile.patch\""
			 ${git}  "${p_dir}/0006-sound-codecs-add-ac108-and-rk3228-dac-to-makefile.patch"

			echo "patch -p1 < \"${p_dir}/0007-arch-arm-dts-add-rk3229-respeaker-v2-device-tree.patch\""
			 ${git}  "${p_dir}/0007-arch-arm-dts-add-rk3229-respeaker-v2-device-tree.patch"

			echo "patch -p1 < \"${p_dir}/0008-arch-arm-dts-add-rk3229-respeaker-v2.dts-to-makefile.patch\""
			 ${git}  "${p_dir}/0008-arch-arm-dts-add-rk3229-respeaker-v2.dts-to-makefile.patch"

			echo "patch -p1 < \"${p_dir}/0009-arch-arm-dts-change-spi-default-pins.patchh\""
			 ${git}  "${p_dir}/0009-arch-arm-dts-change-spi-default-pins.patch"		

			echo "patch -p1 < \"${p_dir}/0010-clk-fractional-divider-fix-up-the-fractional-clk-s-j.patch\""
			 ${git}  "${p_dir}/0010-clk-fractional-divider-fix-up-the-fractional-clk-s-j.patch"			 	 			 			 			 			 			 

			echo "patch -p1 < \"${p_dir}/0011-sound-soc-when-codec-is-ac108-need-set-pll.patch\""
			 ${git}  "${p_dir}/0011-sound-soc-when-codec-is-ac108-need-set-pll.patch"

			echo "patch -p1 < \"${p_dir}/0012-arch-arm-configs-add-respeaker_defconfig.patch\""
			 ${git}  "${p_dir}/0012-arch-arm-configs-add-respeaker_defconfig.patch"		 			 			 

			echo "patch -p1 < \"${p_dir}/0013-scripts-change-dtb-install-dir.patch\""
			 ${git}  "${p_dir}/0013-scripts-change-dtb-install-dir.patch"	


			echo "patch -p1 < \"${p_dir}/pageattr.patch\""
			 ${git}  "${p_dir}/pageattr.patch"				 						
			;;
		esac
fi

cd  ${LOCALPATH}/kernel-src
make ${DEFCONFIG}
make -j8
make -j8 modules
if [ ! -f ${LOCALPATH}/.develop ] ; then
	fakeroot make  ${build_opts}  bindeb-pkg
	cd ${LOCALPATH}

	KERNEL_VERSION=$(cat ${LOCALPATH}/kernel-src/include/config/kernel.release)

	if version_gt "${KERNEL_VERSION}" "4.5"; then
		if [ "${DTB_MAINLINE}" ]; then
			DTB=${DTB_MAINLINE}
		fi
	fi

	if [ "${ARCH}" == "arm" ]; then
		mv ${LOCALPATH}/*.deb "${OUT}/deploy/" || true
		mv ${LOCALPATH}/*.debian.tar.gz "${OUT}/deploy/" || true
		mv ${LOCALPATH}/*.dsc "${OUT}/deploy/" || true
		mv ${LOCALPATH}/*.changes "${OUT}/deploy/" || true
		mv ${LOCALPATH}/*.orig.tar.gz "${OUT}/deploy/" || true
	fi
fi

cp ${LOCALPATH}/kernel-src/arch/arm/boot/dts/${DTB} ${OUT}/kernel/
cp ${LOCALPATH}/kernel-src/arch/arm/boot/zImage ${OUT}/kernel/

if [  -f ${LOCALPATH}/.develop ] ; then
	#sed -i -e 's:#PermitEmptyPasswords no:PermitEmptyPasswords yes:g' /etc/ssh/sshd_config
	#sed -i -e 's:UsePAM yes:UsePAM no:g' /etc/ssh/sshd_config
	#sed -i -e 's:#PermitRootLogin prohibit-password:PermitRootLogin yes:g' /etc/ssh/sshd_config

	name="root"
	ip=192.168.199.239
	if [ "x${name}" != "x" ] ; then
		scp ${OUT}/kernel/${DTB} ${name}@${ip}:/boot/dtb/${KVERSION}/
		echo "scp vmlinuz-${KVERSION}"
		scp ${OUT}/kernel/zImage ${name}@${ip}:/boot/vmlinuz-${KVERSION}
		timeout 3 ssh  ${name}@${ip} "reboot -f " || true
	fi
fi
# Change extlinux.conf according board
sed -e "s,fdt .*,fdt /$DTB,g" \
	-i ${EXTLINUXPATH}/${CHIP}.conf
cd ${LOCALPATH}
./build/mk-image.sh -c ${CHIP} -t boot

echo -e "\e[36m Kernel build success! \e[0m"
