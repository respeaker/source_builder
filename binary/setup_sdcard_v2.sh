#!/bin/bash 
#
# Copyright (c) 2009-2016 Robert Nelson <robertcnelson@gmail.com>
# Copyright (c) 2010 Mario Di Francesco <mdf-code@digitalexile.it>
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
#
# Latest can be found at:
# https://github.com/RobertCNelson/omap-image-builder/blob/master/tools/setup_sdcard.sh

#REQUIREMENTS:
#uEnv.txt bootscript support

BOOT_LABEL="BOOT"

unset USE_BETA_BOOTLOADER
unset USE_LOCAL_BOOT
unset LOCAL_BOOTLOADER

#Defaults
ROOTFS_TYPE=ext4
ROOTFS_LABEL=rootfs

DIR="$PWD"
TEMPDIR=$(mktemp -d)

keep_net_alive () {
	while : ; do
		echo "syncing media... $*"
		sleep 300
	done
}
keep_net_alive & KEEP_NET_ALIVE_PID=$!
cleanup_keep_net_alive () {
	[ -e /proc/$KEEP_NET_ALIVE_PID ] && kill $KEEP_NET_ALIVE_PID
}
trap cleanup_keep_net_alive EXIT

is_element_of () {
	testelt=$1
	for validelt in $2 ; do
		[ $testelt = $validelt ] && return 0
	done
	return 1
}

#########################################################################
#
#  Define valid "--rootfs" root filesystem types.
#
#########################################################################

VALID_ROOTFS_TYPES="ext2 ext3 ext4"

is_valid_rootfs_type () {
	if is_element_of $1 "${VALID_ROOTFS_TYPES}" ] ; then
		return 0
	else
		return 1
	fi
}

check_root () {
	if ! [ $(id -u) = 0 ] ; then
		echo "$0 must be run as sudo user or root"
		exit 1
	fi
}

find_issue () {
	check_root

}

check_for_command () {
	if ! which "$1" > /dev/null ; then
		echo -n "You're missing command $1"
		NEEDS_COMMAND=1
		if [ -n "$2" ] ; then
			echo -n " (consider installing package $2)"
		fi
		echo
	fi
}

detect_software () {
	unset NEEDS_COMMAND

	check_for_command mkfs.vfat dosfstools
	check_for_command wget wget
	check_for_command git git
	check_for_command partprobe parted

	if [ "x${build_img_file}" = "xenable" ] ; then
		check_for_command kpartx kpartx
	fi

	if [ "${NEEDS_COMMAND}" ] ; then
		echo ""
		echo "Your system is missing some dependencies"
		echo "Debian/Ubuntu: sudo apt-get install dosfstools git-core kpartx wget parted"
		echo "Fedora: yum install dosfstools dosfstools git-core wget"
		echo "Gentoo: emerge dosfstools git wget"
		echo ""
		exit
	fi

	unset test_sfdisk
	test_sfdisk=$(LC_ALL=C sfdisk -v 2>/dev/null | grep 2.17.2 | awk '{print $1}')
	if [ "x${test_sdfdisk}" = "xsfdisk" ] ; then
		echo ""
		echo "Detected known broken sfdisk:"
		echo "See: https://github.com/RobertCNelson/netinstall/issues/20"
		echo ""
		exit
	fi

	unset wget_version
	wget_version=$(LC_ALL=C wget --version | grep "GNU Wget" | awk '{print $3}' | awk -F '.' '{print $2}' || true)
	case "${wget_version}" in
	12|13)
		#wget before 1.14 in debian does not support sni
		echo "wget: [`LC_ALL=C wget --version | grep \"GNU Wget\" | awk '{print $3}' || true`]"
		echo "wget: [this version of wget does not support sni, using --no-check-certificate]"
		echo "wget: [http://en.wikipedia.org/wiki/Server_Name_Indication]"
		dl="wget --no-check-certificate"
		;;
	*)
		dl="wget"
		;;
	esac

	dl_continue="${dl} -c"
	dl_quiet="${dl} --no-verbose"
}


dl_v2_bootloader () {
	echo ""
	echo "Downloading ReSpeakerV2's Bootloader"
	echo "-----------------------------"	

	mkdir -p ${TEMPDIR}/dl/${DIST}
	mkdir -p "${DIR}/dl/${DIST}"

	${dl} --directory-prefix="${TEMPDIR}/dl/" ${conf_bl_http}/${idbloader_name}
	echo "blank_idbloader Bootloader: ${idbloader_name}"

	${dl} --directory-prefix="${TEMPDIR}/dl/" ${conf_bl_http}/${uboot_name}
	echo "blank_uboot Bootloader: ${uboot_name}"


	${dl} --directory-prefix="${TEMPDIR}/dl/" ${conf_bl_http}/${atf_name}
	echo "blank_trust Bootloader: ${atf_name}"

}


drive_error_ro () {
	echo "-----------------------------"
	echo "Error: for some reason your SD card is not writable..."
	echo "Check: is the write protect lever set the locked position?"
	echo "Check: do you have another SD card reader?"
	echo "-----------------------------"
	echo "Script gave up..."

	exit
}

format_media () {
	echo ""
	echo "formating media"
	echo "-----------------------------"

	echo "Zeroing out Drive"
	echo "-----------------------------"
	dd if=/dev/zero of=${media} bs=1M count=100 || drive_error_ro
	sync
	dd if=${media} of=/dev/null bs=1M count=100
	sync
}




format_partition_error () {
	echo "LC_ALL=C ${mkfs} ${mkfs_partition} ${mkfs_label}"
	echo "Failure: formating partition"
	exit
}

format_partition_try2 () {
	unset mkfs_options
	if [ "x${mkfs}" = "xmkfs.ext4" ] ; then
		mkfs_options="${ext4_options}"
	fi

	echo "-----------------------------"
	echo "BUG: [${mkfs_partition}] was not available so trying [${mkfs}] again in 5 seconds..."
	partprobe ${media}
	sync
	sleep 5
	echo "-----------------------------"

	echo "Formating with: [${mkfs} ${mkfs_options} ${mkfs_partition} ${mkfs_label}]"
	echo "-----------------------------"
	LC_ALL=C ${mkfs} ${mkfs_options} ${mkfs_partition} ${mkfs_label} || format_partition_error
	sync
}

format_partition () {
	unset mkfs_options
	if [ "x${mkfs}" = "xmkfs.ext4" ] ; then
		mkfs_options="${ext4_options}"
	fi

	echo "Formating with: [${mkfs} ${mkfs_options} ${mkfs_partition} ${mkfs_label}]"
	echo "-----------------------------"
	LC_ALL=C ${mkfs} ${mkfs_options} ${mkfs_partition} ${mkfs_label} || format_partition_try2
	sync
}

format_boot_partition () {
	mkfs_partition="${media_prefix}${media_boot_partition}"

	if [ "x${conf_boot_fstype}" = "xfat" ] ; then
		mount_partition_format="vfat"
		mkfs="mkfs.vfat -F 16"
		mkfs_label="-n ${BOOT_LABEL}"
	else
		mount_partition_format="${conf_boot_fstype}"
		mkfs="mkfs.${conf_boot_fstype}"
		mkfs_label="-L ${BOOT_LABEL}"
	fi

	format_partition
}

format_rootfs_partition () {
	if [ "x${option_ro_root}" = "xenable" ] ; then
		mkfs="mkfs.ext2"
	else
		mkfs="mkfs.${ROOTFS_TYPE}"
	fi
	mkfs_partition="${media_prefix}${media_rootfs_partition}"
	mkfs_label="-L ${ROOTFS_LABEL}"

	format_partition

	rootfs_drive="${conf_root_device}p${media_rootfs_partition}"

	if [ "x${option_ro_root}" = "xenable" ] ; then

		mkfs="mkfs.${ROOTFS_TYPE}"
		mkfs_partition="${media_prefix}${media_rootfs_var_partition}"
		mkfs_label="-L var"

		format_partition
		rootfs_var_drive="${conf_root_device}p${media_rootfs_var_partition}"
	fi
}

create_v2_partitions () {
	if [ "${conf_board}" = "respeaker_v2" ] ; then

		reserved1_start=$(expr ${idbloader_start} + ${idbloader_size})
		reserved2_start=$(expr ${reserved1_start} + ${reserved1_size})
		uboot_start=$(expr ${reserved2_start} + ${reserved2_size})
		atf_start=$(expr ${uboot_start} + ${uboot_size})
		boot_start=$(expr ${atf_start} + ${atf_size})
		rootfs_start=$(expr ${boot_start} + ${boot_size})

		echo "parted -s ${media} mklabel gpt"
		parted -s ${media} mklabel gpt
		
		echo "parted -s ${media} unit s mkpart loader1 ${idbloader_start} $(expr ${reserved1_start} - 1)"
		parted -s ${media} unit s mkpart loader1 ${idbloader_start} $(expr ${reserved1_start} - 1)
		
		echo "parted -s ${media} unit s mkpart reserved1 ${reserved1_start} $(expr ${reserved2_start} - 1)"
		parted -s ${media} unit s mkpart reserved1 ${reserved1_start} $(expr ${reserved2_start} - 1)

		echo "parted -s ${media} unit s mkpart reserved2 ${reserved2_start} $(expr ${uboot_start} - 1)"
		parted -s ${media} unit s mkpart reserved2 ${reserved2_start} $(expr ${uboot_start} - 1)

		echo "parted -s ${media} unit s mkpart loader2 ${uboot_start} $(expr ${atf_start} - 1)"
		parted -s ${media} unit s mkpart loader2 ${uboot_start} $(expr ${atf_start} - 1)

		echo "parted -s ${media} unit s mkpart atf ${atf_start} $(expr ${boot_start} - 1)"
		parted -s ${media} unit s mkpart atf ${atf_start} $(expr ${boot_start} - 1)

		echo "parted -s ${media} unit s mkpart ${BOOT_LABEL} ${boot_start} $(expr ${rootfs_start} - 1)"
		parted -s ${media} unit s mkpart ${BOOT_LABEL} ${boot_start} $(expr ${rootfs_start} - 1)

		echo "parted -s ${media} set 6 boot on"
		parted -s ${media} set 6 boot on

		echo "parted -s ${media} unit s mkpart root ${rootfs_start} 100%"
		parted -s ${media} unit s mkpart root ${rootfs_start} 100%
	fi

	media_loop=$(losetup -f || true)
	if [ ! "${media_loop}" ] ; then
		echo "losetup -f failed"
		echo "Unmount some via: [sudo losetup -a]"
		echo "-----------------------------"
		losetup -a
		echo "sudo kpartx -d /dev/loopX ; sudo losetup -d /dev/loopX"
		echo "-----------------------------"
		exit
	fi

	losetup ${media_loop} "${media}"
	kpartx -av ${media_loop}
	sleep 1
	sync
	test_loop=$(echo ${media_loop} | awk -F'/' '{print $3}')
	if [ -e /dev/mapper/${test_loop}p${media_boot_partition} ] && [ -e /dev/mapper/${test_loop}p${media_rootfs_partition} ] ; then
		media_prefix="/dev/mapper/${test_loop}p"
	else
		ls -lh /dev/mapper/
		echo "Error: not sure what to do (new feature)."
		exit
	fi

	conf_boot_fstype="fat"
	format_boot_partition
	format_rootfs_partition
}
populate_loaders(){
	echo "Populating idbloader atf  uboot Partition"
	echo "-----------------------------"
	partprobe ${media}
	echo "dd if=${idbloader_name} of=${media_prefix}${media_idbloader_partition} conv=notrunc"
	dd if=${idbloader_name} of=${media_prefix}${media_idbloader_partition} conv=notrunc

	echo "dd if=${atf_name} of=${media_prefix}${media_atf_partition} conv=notrunc"
	dd if=${atf_name} of=${media_prefix}${media_atf_partition} conv=notrunc

	echo "dd if=${uboot_name} of=${media_prefix}${media_uboot_partition} conv=notrunc"
	dd if=${uboot_name} of=${media_prefix}${media_uboot_partition} conv=notrunc

	echo "Finished populating idbloader atf  uboot Partition"
	echo "-----------------------------"
}

populate_boot () {
	echo "Populating Boot Partition"
	echo "-----------------------------"

	if [ ! -d ${TEMPDIR}/disk ] ; then
		mkdir -p ${TEMPDIR}/disk
	fi



	partprobe ${media}
	if ! mount -t ${mount_partition_format} ${media_prefix}${media_boot_partition} ${TEMPDIR}/disk/; then

		echo "-----------------------------"
		echo "BUG: [${media_prefix}${media_boot_partition}] was not available so trying to mount again in 5 seconds..."
		partprobe ${media}
		sync
		sleep 5
		echo "-----------------------------"

		if ! mount -t ${mount_partition_format} ${media_prefix}${media_boot_partition} ${TEMPDIR}/disk; then
			echo "-----------------------------"
			echo "Unable to mount ${media_prefix}${media_boot_partition} at ${TEMPDIR}/disk to complete populating Boot Partition"
			echo "Please retry running the script, sometimes rebooting your system helps."
			echo "-----------------------------"
			exit
		fi
	fi

	lsblk | grep -v sr0
	echo "-----------------------------"


	if [ "x${conf_board}" = "xrespeaker_v2" ] ; then
		mv ${TEMPDIR}/boot/*  ${TEMPDIR}/disk/
		ls -lh ${TEMPDIR}/disk/ 
		umount ${TEMPDIR}/disk || true
		sync
		kpartx -d ${media_loop} || true
		losetup -d ${media_loop} || true
		echo "Finished populating Boot Partition"
		echo "-----------------------------"
		exit
	fi
	if [ "${spl_name}" ] ; then
		if [ -f ${TEMPDIR}/dl/${SPL} ] ; then
			if [ ! "${bootloader_installed}" ] ; then
				cp -v ${TEMPDIR}/dl/${SPL} ${TEMPDIR}/disk/${spl_name}
				echo "-----------------------------"
			fi
		fi
	fi


	if [ "${boot_name}" ] ; then
		if [ -f ${TEMPDIR}/dl/${UBOOT} ] ; then
			if [ ! "${bootloader_installed}" ] ; then
				cp -v ${TEMPDIR}/dl/${UBOOT} ${TEMPDIR}/disk/${boot_name}
				echo "-----------------------------"
			fi
		fi
	fi


	if [ -f "${DIR}/ID.txt" ] ; then
		cp -v "${DIR}/ID.txt" ${TEMPDIR}/disk/ID.txt
	fi

	if [ ${has_uenvtxt} ] ; then
		if [ ! "x${bbb_old_bootloader_in_emmc}" = "xenable" ] ; then
			cp -v "${DIR}/uEnv.txt" ${TEMPDIR}/disk/uEnv.txt
			echo "-----------------------------"
		fi
	fi

	cd ${TEMPDIR}/disk
	sync
	cd "${DIR}"/

	echo "Debug: Contents of Boot Partition"
	echo "-----------------------------"
	ls -lh ${TEMPDIR}/disk/
	du -sh ${TEMPDIR}/disk/
	echo "-----------------------------"

	sync
	sync


	umount ${TEMPDIR}/disk || true
	echo "Finished populating Boot Partition"
	echo "-----------------------------"
}

kernel_detection () {
	unset has_multi_armv7_kernel
	unset check
	check=$(ls "${dir_check}" | grep vmlinuz- | grep armv7 | grep -v lpae | head -n 1)
	if [ "x${check}" != "x" ] ; then
		armv7_kernel=$(ls "${dir_check}" | grep vmlinuz- | grep armv7 | grep -v lpae | head -n 1 | awk -F'vmlinuz-' '{print $2}')
		echo "Debug: image has: v${armv7_kernel}"
		has_multi_armv7_kernel="enable"
	fi

	unset has_multi_armv7_lpae_kernel
	unset check
	check=$(ls "${dir_check}" | grep vmlinuz- | grep armv7 | grep lpae | head -n 1)
	if [ "x${check}" != "x" ] ; then
		armv7_lpae_kernel=$(ls "${dir_check}" | grep vmlinuz- | grep armv7 | grep lpae | head -n 1 | awk -F'vmlinuz-' '{print $2}')
		echo "Debug: image has: v${armv7_lpae_kernel}"
		has_multi_armv7_lpae_kernel="enable"
	fi

	unset has_bone_kernel
	unset check
	check=$(ls "${dir_check}" | grep vmlinuz- | grep bone | head -n 1)
	if [ "x${check}" != "x" ] ; then
		bone_dt_kernel=$(ls "${dir_check}" | grep vmlinuz- | grep bone | head -n 1 | awk -F'vmlinuz-' '{print $2}')
		echo "Debug: image has: v${bone_dt_kernel}"
		has_bone_kernel="enable"
	fi

	unset has_ti_kernel
	unset check
	check=$(ls "${dir_check}" | grep vmlinuz- | grep ti | head -n 1)
	if [ "x${check}" != "x" ] ; then
		ti_dt_kernel=$(ls "${dir_check}" | grep vmlinuz- | grep ti | head -n 1 | awk -F'vmlinuz-' '{print $2}')
		echo "Debug: image has: v${ti_dt_kernel}"
		has_ti_kernel="enable"
	fi

	unset has_xenomai_kernel
	unset check
	check=$(ls "${dir_check}" | grep vmlinuz- | grep xenomai | head -n 1)
	if [ "x${check}" != "x" ] ; then
		xenomai_dt_kernel=$(ls "${dir_check}" | grep vmlinuz- | grep xenomai | head -n 1 | awk -F'vmlinuz-' '{print $2}')
		echo "Debug: image has: v${xenomai_dt_kernel}"
		has_xenomai_kernel="enable"
	fi

	unset has_respeaker_kernel
	unset check
	check=$(ls "${dir_check}" | grep vmlinuz- | grep respeaker | head -n 1)
	if [ "x${check}" != "x" ] ; then
		respeaker_dt_kernel=$(ls "${dir_check}" | grep vmlinuz- | grep respeaker | head -n 1 | awk -F'vmlinuz-' '{print $2}')
		echo "Debug: image has: v${respeaker_dt_kernel}"
		has_respeaker_kernel="enable"
	fi	
}

kernel_select () {
	unset select_kernel
	if [ "x${conf_kernel}" = "xarmv7" ] || [ "x${conf_kernel}" = "x" ] ; then
		if [ "x${has_multi_armv7_kernel}" = "xenable" ] ; then
			select_kernel="${armv7_kernel}"
		fi
	fi

	if [ "x${conf_kernel}" = "xarmv7_lpae" ] ; then
		if [ "x${has_multi_armv7_lpae_kernel}" = "xenable" ] ; then
			select_kernel="${armv7_lpae_kernel}"
		else
			if [ "x${has_multi_armv7_kernel}" = "xenable" ] ; then
				select_kernel="${armv7_kernel}"
			fi
		fi
	fi

	if [ "x${conf_kernel}" = "xbone" ] ; then
		if [ "x${has_ti_kernel}" = "xenable" ] ; then
			select_kernel="${ti_dt_kernel}"
		else
			if [ "x${has_bone_kernel}" = "xenable" ] ; then
				select_kernel="${bone_dt_kernel}"
			else
				if [ "x${has_multi_armv7_kernel}" = "xenable" ] ; then
					select_kernel="${armv7_kernel}"
				else
					if [ "x${has_xenomai_kernel}" = "xenable" ] ; then
						select_kernel="${xenomai_dt_kernel}"
					fi
				fi
			fi
		fi
	fi

	if [ "x${conf_kernel}" = "xti" ] ; then
		if [ "x${has_ti_kernel}" = "xenable" ] ; then
			select_kernel="${ti_dt_kernel}"
		else
			if [ "x${has_multi_armv7_kernel}" = "xenable" ] ; then
				select_kernel="${armv7_kernel}"
			fi
		fi
	fi

	if [ "x${conf_kernel}" = "xrespeaker" ] ; then
		if [ "x${has_respeaker_kernel}" = "xenable" ] ; then
			select_kernel="${respeaker_dt_kernel}"
		fi
	fi

	if [ "${select_kernel}" ] ; then
		echo "Debug: using: v${select_kernel}"
	else
		echo "Error: [conf_kernel] not defined [armv7_lpae,armv7,bone,ti]..."
		exit
	fi
}

populate_rootfs () {
	echo "Populating rootfs Partition"
	echo "Please be patient, this may take a few minutes, as its transfering a lot of data.."
	echo "-----------------------------"

	if [ ! -d ${TEMPDIR}/disk ] ; then
		mkdir -p ${TEMPDIR}/disk
	fi

	partprobe ${media}
	if ! mount -t ${ROOTFS_TYPE} ${media_prefix}${media_rootfs_partition} ${TEMPDIR}/disk; then

		echo "-----------------------------"
		echo "BUG: [${media_prefix}${media_rootfs_partition}] was not available so trying to mount again in 5 seconds..."
		partprobe ${media}
		sync
		sleep 5
		echo "-----------------------------"

		if ! mount -t ${ROOTFS_TYPE} ${media_prefix}${media_rootfs_partition} ${TEMPDIR}/disk; then
			echo "-----------------------------"
			echo "Unable to mount ${media_prefix}${media_rootfs_partition} at ${TEMPDIR}/disk to complete populating rootfs Partition"
			echo "Please retry running the script, sometimes rebooting your system helps."
			echo "-----------------------------"
			exit
		fi
	fi

	if [ "x${option_ro_root}" = "xenable" ] ; then

		if [ ! -d ${TEMPDIR}/disk/var ] ; then
			mkdir -p ${TEMPDIR}/disk/var
		fi

		if ! mount -t ${ROOTFS_TYPE} ${media_prefix}${media_rootfs_var_partition} ${TEMPDIR}/disk/var; then

			echo "-----------------------------"
			echo "BUG: [${media_prefix}${media_rootfs_var_partition}] was not available so trying to mount again in 5 seconds..."
			partprobe ${media}
			sync
			sleep 5
			echo "-----------------------------"

			if ! mount -t ${ROOTFS_TYPE} ${media_prefix}${media_rootfs_var_partition} ${TEMPDIR}/disk/var; then
				echo "-----------------------------"
				echo "Unable to mount ${media_prefix}${media_rootfs_var_partition} at ${TEMPDIR}/disk/var to complete populating rootfs Partition"
				echo "Please retry running the script, sometimes rebooting your system helps."
				echo "-----------------------------"
				exit
			fi
		fi

	fi

	lsblk | grep -v sr0
	echo "-----------------------------"

	if [ -f "${DIR}/${ROOTFS}" ] ; then
		if which pv > /dev/null ; then
			pv "${DIR}/${ROOTFS}" | tar --numeric-owner --preserve-permissions -xf - -C ${TEMPDIR}/disk/
		else
			echo "pv: not installed, using tar verbose to show progress"
			tar --numeric-owner --preserve-permissions --verbose -xf "${DIR}/${ROOTFS}" -C ${TEMPDIR}/disk/
		fi

		echo "Transfer of data is Complete, now syncing data to disk..."
		echo "Disk Size"
		du -sh ${TEMPDIR}/disk/
		sync
		sync

		echo "-----------------------------"
		if [ -f /usr/bin/stat ] ; then
			echo "-----------------------------"
			echo "Checking [${TEMPDIR}/disk/] permissions"
			/usr/bin/stat ${TEMPDIR}/disk/
			echo "-----------------------------"
		fi

		echo "Setting [${TEMPDIR}/disk/] chown root:root"
		chown root:root ${TEMPDIR}/disk/
		echo "Setting [${TEMPDIR}/disk/] chmod 755"
		chmod 755 ${TEMPDIR}/disk/

		if [ -f /usr/bin/stat ] ; then
			echo "-----------------------------"
			echo "Verifying [${TEMPDIR}/disk/] permissions"
			/usr/bin/stat ${TEMPDIR}/disk/
		fi
		echo "-----------------------------"

		if [ ! "x${oem_flasher_img}" = "x" ] ; then
			if [ ! -d "${TEMPDIR}/disk/opt/emmc/" ] ; then
				mkdir -p "${TEMPDIR}/disk/opt/emmc/"
			fi
			cp -v "${oem_flasher_img}" "${TEMPDIR}/disk/opt/emmc/"
			sync
			if [ ! "x${oem_flasher_bmap}" = "x" ] ; then
				cp -v "${oem_flasher_bmap}" "${TEMPDIR}/disk/opt/emmc/"
				sync
			fi
			if [ ! "x${oem_flasher_eeprom}" = "x" ] ; then
				cp -v "${oem_flasher_eeprom}" "${TEMPDIR}/disk/opt/emmc/"
				sync
			fi
			if [ ! "x${oem_flasher_job}" = "x" ] ; then
				cp -v "${oem_flasher_job}" "${TEMPDIR}/disk/opt/emmc/job.txt"
				sync
				if [ ! "x${oem_flasher_eeprom}" = "x" ] ; then
					echo "conf_eeprom_file=${oem_flasher_eeprom}" >> "${TEMPDIR}/disk/opt/emmc/job.txt"
					if [ ! "x${conf_eeprom_compare}" = "x" ] ; then
						echo "conf_eeprom_compare=${conf_eeprom_compare}" >> "${TEMPDIR}/disk/opt/emmc/job.txt"
					else
						echo "conf_eeprom_compare=335" >> "${TEMPDIR}/disk/opt/emmc/job.txt"
					fi
				fi
			fi
			echo "-----------------------------"
			cat "${TEMPDIR}/disk/opt/emmc/job.txt"
			echo "-----------------------------"
			echo "Disk Size, with *.img"
			du -sh ${TEMPDIR}/disk/
		fi

		echo "-----------------------------"
	fi

	dir_check="${TEMPDIR}/disk/boot/"
	kernel_detection
	kernel_select

	if [ ! "x${uboot_eeprom}" = "x" ] ; then
		echo "board_eeprom_header=${uboot_eeprom}" > "${TEMPDIR}/disk/boot/.eeprom.txt"
	fi

	wfile="${TEMPDIR}/disk/boot/uEnv.txt"
	#echo "#Docs: http://elinux.org/Beagleboard:U-boot_partitioning_layout_2.0" > ${wfile}
	#echo "" >> ${wfile}

	if [ "x${kernel_override}" = "x" ] ; then
		echo "uname_r=${select_kernel}" >> ${wfile}
	else
		echo "uname_r=${kernel_override}" >> ${wfile}
	fi

	echo "#uuid=" >> ${wfile}

	if [ ! "x${dtb}" = "x" ] ; then
		echo "dtb=${dtb}" >> ${wfile}
	else

		if [ ! "x${forced_dtb}" = "x" ] ; then
			echo "dtb=${forced_dtb}" >> ${wfile}
		else
			echo "#dtb=" >> ${wfile}
		fi
	fi
	
	if [  "x${conf_board}" = "xrespeaker_v2" ] ; then
		cmdline="coherent_pool=1M quiet"
	else
		cmdline="coherent_pool=1M net.ifnames=0 quiet"
	fi
	
	if [ "x${enable_systemd}" = "xenabled" ] ; then
		cmdline="${cmdline} init=/lib/systemd/systemd"
	fi

	if [ "x${enable_cape_universal}" = "xenable" ] ; then
		cmdline="${cmdline} cape_universal=enable"
	fi

	unset kms_video

	drm_device_identifier=${drm_device_identifier:-"HDMI-A-1"}
	drm_device_timing=${drm_device_timing:-"1024x768@60e"}
	if [ ! "x${conf_board}" = "xrespeaker_v2" ] ; then
		if [ "x${drm_read_edid_broken}" = "xenable" ] ; then
			cmdline="${cmdline} video=${drm_device_identifier}:${drm_device_timing}"
			echo "cmdline=${cmdline}" >> ${wfile}
			echo "" >> ${wfile}
		else
			echo "cmdline=${cmdline}" >> ${wfile}
			echo "" >> ${wfile}

			echo "#In the event of edid real failures, uncomment this next line:" >> ${wfile}
			echo "#cmdline=${cmdline} video=${drm_device_identifier}:${drm_device_timing}" >> ${wfile}
			echo "" >> ${wfile}
		fi
	else
		echo "cmdline=${cmdline}" >> ${wfile}
	fi

	if [ "x${conf_board}" = "xrespeaker_v2" ] ; then
		echo "##enable respeaker: eMMC Flasher:" >> ${wfile}
		echo "##make sure, these tools are installed: dosfstools rsync" >> ${wfile}
		echo "#cmdline=init=/opt/scripts/tools/eMMC/init-eMMC-flasher-respeaker.sh" >> ${wfile}
	fi

	#am335x_boneblack is a custom u-boot to ignore empty factory eeproms...
	if [ "x${conf_board}" = "xam335x_boneblack" ] ; then
		board="am335x_evm"
	else
		board=${conf_board}
	fi

	echo "/boot/uEnv.txt---------------"
	cat ${wfile}
	echo "-----------------------------"

	wfile="${TEMPDIR}/disk/boot/SOC.sh"
	if [ "x${conf_board}" = "xrespeaker_v2" ] ; then 
		cp "${DIR}"/hwpack/${dtb_board}.conf ${wfile}
		echo "/dev/mmcblk1" > ${TEMPDIR}/disk/resizerootfs
	else	
		generate_soc
	fi	

	#RootStock-NG
	if [ -f ${TEMPDIR}/disk/etc/rcn-ee.conf ] ; then
		. ${TEMPDIR}/disk/etc/rcn-ee.conf

		mkdir -p ${TEMPDIR}/disk/boot/uboot || true

		wfile="${TEMPDIR}/disk/etc/fstab"
		echo "# /etc/fstab: static file system information." > ${wfile}
		echo "#" >> ${wfile}
		echo "# Auto generated by RootStock-NG: setup_sdcard.sh" >> ${wfile}
		echo "#" >> ${wfile}

		if [ "x${conf_board}" = "xrespeaker_v2" ] ; then
			echo "LABEL=${BOOT_LABEL}       /boot vfat   rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro 0      2" >>  ${wfile}
		else
			if [ "x${option_ro_root}" = "xenable" ] ; then
				echo "#With read only rootfs, we need to boot once as rw..." >> ${wfile}
				echo "${rootfs_drive}  /  ext2  noatime,errors=remount-ro  0  1" >> ${wfile}
				echo "#" >> ${wfile}
				echo "#Switch to read only rootfs:" >> ${wfile}
				echo "#${rootfs_drive}  /  ext2  noatime,ro,errors=remount-ro  0  1" >> ${wfile}
				echo "#" >> ${wfile}
				echo "${rootfs_var_drive}  /var  ${ROOTFS_TYPE}  noatime  0  2" >> ${wfile}
			else
				echo "${rootfs_drive}  /  ${ROOTFS_TYPE}  noatime,errors=remount-ro  0  1" >> ${wfile}
			fi

			echo "debugfs  /sys/kernel/debug  debugfs  defaults  0  0" >> ${wfile}

		fi

		if [ "x${distro}" = "xDebian" ] ; then
			#/etc/inittab is gone in Jessie with systemd...
			if [ -f ${TEMPDIR}/disk/etc/inittab ] ; then
				wfile="${TEMPDIR}/disk/etc/inittab"
				serial_num=$(echo -n "${SERIAL}"| tail -c -1)
				echo "" >> ${wfile}
				echo "T${serial_num}:23:respawn:/sbin/getty -L ${SERIAL} 115200 vt102" >> ${wfile}
				echo "" >> ${wfile}
			fi
		fi

		if [ "x${distro}" = "xUbuntu" ] ; then
			wfile="${TEMPDIR}/disk/etc/init/serial.conf"
			echo "start on stopped rc RUNLEVEL=[2345]" > ${wfile}
			echo "stop on runlevel [!2345]" >> ${wfile}
			echo "" >> ${wfile}
			echo "respawn" >> ${wfile}
			echo "exec /sbin/getty 115200 ${SERIAL}" >> ${wfile}
		fi

		if [ -f ${TEMPDIR}/disk/var/www/index.html ] ; then
			rm -f ${TEMPDIR}/disk/var/www/index.html || true
		fi

		if [ -f ${TEMPDIR}/disk/var/www/html/index.html ] ; then
			rm -f ${TEMPDIR}/disk/var/www/html/index.html || true
		fi
		sync

	fi #RootStock-NG

	if [ ! "x${uboot_name}" = "x" ] ; then
		echo "Backup version of u-boot: /opt/backup/uboot/"
		mkdir -p ${TEMPDIR}/disk/opt/backup/uboot/
		cp -v ${TEMPDIR}/dl/${uboot_name} ${TEMPDIR}/disk/opt/backup/uboot/${uboot_name}
		cp -v ${TEMPDIR}/dl/${idbloader_name} ${TEMPDIR}/disk/opt/backup/uboot/${idbloader_name}
		cp -v ${TEMPDIR}/dl/${atf_name} ${TEMPDIR}/disk/opt/backup/uboot/${atf_name}
	fi

	if [ ! "x${spl_uboot_name}" = "x" ] ; then
		mkdir -p ${TEMPDIR}/disk/opt/backup/uboot/
		cp -v ${TEMPDIR}/dl/${SPL} ${TEMPDIR}/disk/opt/backup/uboot/${spl_uboot_name}
	fi


	if [  "x${conf_board}" = "xrespeaker_v2" ] ; then 
		if [ ! -f ${TEMPDIR}/disk/opt/scripts/init-eMMC-flasher-respeaker.sh ] ; then
			mkdir -p  ${TEMPDIR}/disk/opt/scripts/
			git clone https://github.com/Pillar1989/flasher-scripts ${TEMPDIR}/disk/opt/scripts/ --depth 1
			sudo chown -R 1000:1000 ${TEMPDIR}/disk/opt/scripts/
		else
			cd ${TEMPDIR}/disk/opt/scripts/
			git pull
			cd -
			sudo chown -R 1000:1000 ${TEMPDIR}/disk/opt/scripts/
		fi
	fi
	if [ "x${conf_board}" = "xrespeaker_v2" ]; then
		wfile="${TEMPDIR}/disk/lib/udev/rules.d/90-pulseaudio.rules"
		sed -i '/0x384e/a#\ Seeed\ Voicecard' ${wfile}
		sed -i '/Voicecard/aATTR{id}=="seeed8micvoicec",ATTR{number}=="0",ENV{PULSE_PROFILE_SET}="seeed-voicecard.conf"' ${wfile}
	fi


	# setuid root ping+ping6 - capabilities does not survive tar
	if [ -x  ${TEMPDIR}/disk/bin/ping ] ; then
		echo "making ping/ping6 setuid root"
		chmod u+s ${TEMPDIR}/disk//bin/ping ${TEMPDIR}/disk//bin/ping6
	fi

	cd ${TEMPDIR}/disk/
	sync
	sync

	if [ ! -d ${TEMPDIR}/boot ] ; then
		mkdir -p ${TEMPDIR}/boot
	fi

	if [ "${conf_board}" = "respeaker_v2" ] ; then
		sed -i "s|/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games|/usr/local/bin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games|g" ${TEMPDIR}/disk/etc/profile  
		mv ${TEMPDIR}/disk/boot/* ${TEMPDIR}/boot
	fi



	cd "${DIR}/"

	if [ "x${option_ro_root}" = "xenable" ] ; then
		umount ${TEMPDIR}/disk/var || true
	fi

	umount ${TEMPDIR}/disk || true


	echo "Finished populating rootfs Partition"
	echo "-----------------------------"

	echo "setup_sdcard.sh script complete"
	if [ -f "${DIR}/user_password.list" ] ; then
		echo "-----------------------------"
		echo "The default user:password for this image:"
		cat "${DIR}/user_password.list"
		echo "-----------------------------"
	fi
	if [ "x${build_img_file}" = "xenable" ] ; then
		echo "Image file: ${imagename}"
		echo "-----------------------------"

		if [ "x${usb_flasher}" = "x" ] && [ "x${emmc_flasher}" = "x" ] ; then
			wfile="${imagename}.xz.job.txt"
			echo "abi=aaa" > ${wfile}
			echo "conf_image=${imagename}.xz" >> ${wfile}
			bmapimage=$(echo ${imagename} | awk -F ".img" '{print $1}')
			echo "conf_bmap=${bmapimage}.bmap" >> ${wfile}
			echo "conf_resize=enable" >> ${wfile}
			echo "conf_partition1_startmb=${conf_boot_startmb}" >> ${wfile}

			case "${conf_boot_fstype}" in
			fat)
				echo "conf_partition1_fstype=0xE" >> ${wfile}
				;;
			ext2|ext3|ext4)
				echo "conf_partition1_fstype=0x83" >> ${wfile}
				;;
			esac

			if [ "x${media_rootfs_partition}" = "x2" ] ; then
				echo "conf_partition1_endmb=${conf_boot_endmb}" >> ${wfile}
				echo "conf_partition2_fstype=0x83" >> ${wfile}
			fi
			echo "conf_root_partition=${media_rootfs_partition}" >> ${wfile}
		fi
	fi
}

check_mmc () {
	FDISK=$(LC_ALL=C fdisk -l 2>/dev/null | grep "Disk ${media}:" | awk '{print $2}')

	if [ "x${FDISK}" = "x${media}:" ] ; then
		echo ""
		echo "I see..."
		echo ""
		echo "lsblk:"
		lsblk | grep -v sr0
		echo ""
		unset response
		echo -n "Are you 100% sure, on selecting [${media}] (y/n)? "
		read response
		if [ "x${response}" != "xy" ] ; then
			exit
		fi
		echo ""
	else
		echo ""
		echo "Are you sure? I Don't see [${media}], here is what I do see..."
		echo ""
		echo "lsblk:"
		lsblk | grep -v sr0
		echo ""
		exit
	fi
}

process_dtb_conf () {
	if [ "${conf_warning}" ] ; then
		show_board_warning
	fi

	echo "-----------------------------"

	#defaults, if not set...
	case "${bootloader_location}" in
	fatfs_boot)
		conf_boot_startmb=${conf_boot_startmb:-"1"}
		;;
	dd_uboot_boot|dd_spl_uboot_boot)
		conf_boot_startmb=${conf_boot_startmb:-"4"}
		;;
	*)
		conf_boot_startmb=${conf_boot_startmb:-"4"}
		;;
	esac

	#https://wiki.linaro.org/WorkingGroups/KernelArchived/Projects/FlashCardSurvey
	conf_root_device=${conf_root_device:-"/dev/mmcblk0"}

	#error checking...
	if [ ! "${conf_boot_fstype}" ] ; then
		conf_boot_fstype="${ROOTFS_TYPE}"
	fi

	case "${conf_boot_fstype}" in
	fat)
		sfdisk_fstype="0xE"
		;;
	ext2|ext3|ext4)
		sfdisk_fstype="L"
		;;
	*)
		echo "Error: [conf_boot_fstype] not recognized, stopping..."
		exit
		;;
	esac
}

check_dtb_board () {
	error_invalid_dtb=1


	#${dtb_board}.conf
	if [ -f "${DIR}"/${dtb_board}.conf ] ; then
		. "${DIR}"/${dtb_board}.conf

	else
		cat <<-__EOF__
			-----------------------------
			ERROR: This script does not currently recognize the selected: [--dtb ${dtb_board}] option..
			Please rerun $(basename $0) with a valid [--dtb <device>] option from the list below:
			-----------------------------
		__EOF__
		cat "${DIR}"/*.conf | grep supported
		echo "-----------------------------"
		exit
	fi
}

checkparm () {
	if [ "$(echo $1|grep ^'\-')" ] ; then
		echo "E: Need an argument"
		usage
	fi
}


find_issue
detect_software
dtb_board="respeaker_v2"
check_dtb_board

format_media
create_v2_partitions

populate_loaders
#populate_rootfs
#populate_boot


kpartx -d ${media_loop} || true
losetup -d ${media_loop} || true
exit 0
#
