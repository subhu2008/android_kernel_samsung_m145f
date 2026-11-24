### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=Kernel for Samsung Galaxy A05s / M14 4G
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=a05s
device.name2=a057f
device.name3=a057g
device.name4=m14
device.name5=m145f
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables (both upper and lower case for compatibility)
BLOCK=/dev/block/by-name/boot;
block=/dev/block/by-name/boot;
IS_SLOT_DEVICE=0;
is_slot_device=0;
RAMDISK_COMPRESSION=auto;
ramdisk_compression=auto;
PATCH_VBMETA_FLAG=auto;
patch_vbmeta_flag=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
dump_boot;
write_boot;
## end boot install
