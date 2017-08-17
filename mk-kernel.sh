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
build_opts="${build_opts} LOCALVERSION=-respeaker-v2"
build_opts="${build_opts} KDEB_PKGVERSION=1stable"


git_generic () {
	if [ -d ${LOCALPATH}/kernel-src ] ; then
		rm -rf ${LOCALPATH}/kernel-src || true
	fi
	git clone --share  ${LOCALPATH}/kernel  ${LOCALPATH}/kernel-src
	cd ${LOCALPATH}/kernel-src
	#we use this tag
	git checkout release-20170705 
	echo "-----------------------------"
}
git="git am"
if [ ! -f ${LOCALPATH}/.without_patch ] ; then
	case "${BOARD}" in
		respeaker)
			git_generic
			p_dir="${DIR}/build/patches/kernel"
			
			echo "patch -p1 < \"${p_dir}/0001-sound-codecs-add-x-power-ac108-multichannel-ADC.patch\""
			${git}  "${p_dir}/0001-sound-codecs-add-x-power-ac108-multichannel-ADC.patch"
			
			echo "patch -p1 < \"${p_dir}/0002-sound-codecs-add-rk322x-on-chip-DAC-driver.patch\""
			${git}  "${p_dir}/0002-sound-codecs-add-rk322x-on-chip-DAC-driver.patch"
			
			echo "patch -p1 < \"${p_dir}/0003-sound-soc-rockchip-set-the-i2s-default-mclk-when-the.patch\""
			${git}  "${p_dir}/0003-sound-soc-rockchip-set-the-i2s-default-mclk-when-the.patch"
			
			echo "patch -p1 < \"${p_dir}/0004-sound-soc-add-dt-name-to-alsa-dummy-driver.patch\""
			${git}  "${p_dir}/0004-sound-soc-add-dt-name-to-alsa-dummy-driver.patch"
			
			echo "patch -p1 < \"${p_dir}/0005-clk-fractional-divider-fix-up-the-fractional-clk-s-j.patch\""
			${git}  "${p_dir}/0005-clk-fractional-divider-fix-up-the-fractional-clk-s-j.patch"
			
			echo "patch -p1 < \"${p_dir}/0006-usb-dwc2-gadget-fix-usb-gadget-a-bug.patchh\""
			${git}  "${p_dir}/0006-usb-dwc2-gadget-fix-usb-gadget-a-bug.patch"
			
			echo "patch -p1 < \"${p_dir}/0007-sound-codecs-add-ac108-and-rk3228-dac-to-makefile.patch\""
			${git}  "${p_dir}/0007-sound-codecs-add-ac108-and-rk3228-dac-to-makefile.patch"
			
			echo "patch -p1 < \"${p_dir}/0008-arch-arm-dts-add-respeaker-v2-board-device-tree.patch\""
			${git}  "${p_dir}/0008-arch-arm-dts-add-respeaker-v2-board-device-tree.patch"

			echo "patch -p1 < \"${p_dir}/0009-driver-dma-fix-some-bugs-on-alsa-play-music.patch\""
			${git}  "${p_dir}/0009-driver-dma-fix-some-bugs-on-alsa-play-music.patch"

			echo "patch -p1 < \"${p_dir}/0010-scripts-allow-some-waining-in-high-gcc-version.patch\""
			${git}  "${p_dir}/0010-scripts-allow-some-waining-in-high-gcc-version.patch"

			echo "patch -p1 < \"${p_dir}/0011-arch-arm-configs-add-respeaker-linux-kernel-configs.patch\""
			${git}  "${p_dir}/0011-arch-arm-configs-add-respeaker-linux-kernel-configs.patch"

			echo "patch -p1 < \"${p_dir}/0012-arm-dts-add-spi0-configurtion-to-rk322x.patch\""
			${git}  "${p_dir}/0012-arm-dts-add-spi0-configurtion-to-rk322x.patch"
			
			echo "patch -p1 < \"${p_dir}/0013-arm-dts-enable-spidev-and-gpio-leds.patch\""
			${git}  "${p_dir}/0013-arm-dts-enable-spidev-and-gpio-leds.patch"

			echo "patch -p1 < \"${p_dir}/0014-arch-arm-dts-add-reserved-memory-fragment-and-gpio-l.patch\""
			${git}  "${p_dir}/0014-arch-arm-dts-add-reserved-memory-fragment-and-gpio-l.patch"

			echo "patch -p1 < \"${p_dir}/0015-arch-arm-configs-add-leds-trigger-and-cpu-freq.patch\""
			${git}  "${p_dir}/0015-arch-arm-configs-add-leds-trigger-and-cpu-freq.patch"

			;;
		esac
fi

cd  ${LOCALPATH}/kernel-src
make ${DEFCONFIG}
make -j8
fakeroot make  ${build_opts}  bindeb-pkg
cd ${LOCALPATH}

KERNEL_VERSION=$(cat ${LOCALPATH}/kernel-src/include/config/kernel.release)

if version_gt "${KERNEL_VERSION}" "4.5"; then
	if [ "${DTB_MAINLINE}" ]; then
		DTB=${DTB_MAINLINE}
	fi
fi

if [ "${ARCH}" == "arm" ]; then
	cp ${LOCALPATH}/kernel-src/arch/arm/boot/zImage ${OUT}/kernel/
	cp ${LOCALPATH}/kernel-src/arch/arm/boot/dts/${DTB} ${OUT}/kernel/
	mv ${LOCALPATH}/*.deb "${OUT}/deploy/" || true
	mv ${LOCALPATH}/*.debian.tar.gz "${OUT}/deploy/" || true
	mv ${LOCALPATH}/*.dsc "${OUT}/deploy/" || true
	mv ${LOCALPATH}/*.changes "${OUT}/deploy/" || true
	mv ${LOCALPATH}/*.orig.tar.gz "${OUT}/deploy/" || true
	
else
	cp ${LOCALPATH}/kernel-src/arch/arm64/boot/Image ${OUT}/kernel/
	cp ${LOCALPATH}/kernel-src/arch/arm64/boot/dts/rockchip/${DTB} ${OUT}/kernel/
fi

# Change extlinux.conf according board
sed -e "s,fdt .*,fdt /$DTB,g" \
	-i ${EXTLINUXPATH}/${CHIP}.conf

./build/mk-image.sh -c ${CHIP} -t boot

echo -e "\e[36m Kernel build success! \e[0m"
