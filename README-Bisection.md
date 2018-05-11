# Ragnar Bisection

## Usage

rekernel-rootfs is a utility that takes a given rootfs image file, builds a
kernel using build-kernel, and replaces the kernel in the rootfs with the new
kernel.

bisect-lkft uses rekernel-rootfs and lavacli to do a bisection.

Both utilities are written to be idempotent, so that if a bisection fails for
some reason, bisect-lkft can be restarted and most of the builds and test will
not be re-run. Rather, it will pick up where it left off.

rekernel-rootfs artifacts can be found in ~/ragnar-artifacts/rekernel-rootfs,
and bisect-lkft artifacts can be fonud in ~/ragnar-artifacts/bisect-lkft.

Before bisecting, bisect-lkft will verify the GOOD and BAD commits to ensure
the test setup is correct.

### Setup

- rekernel-rootfs requires sudo access to be able to mount and update the
  rootfs image. The following sudoers rule will allow it without password.
  - `username ALL=NOPASSWD: /usr/bin/mount, /usr/bin/umount, /usr/bin/cp,
    /usr/bin/ln`
- The following utilities should be installed:
  - ext2simg
  - lavacli (with default lava destination set up with a key that can submit
    jobs)

### Running a bisection

Create a run file such as the following:

```sh
export URL=http://snapshots.linaro.org/openembedded/lkft/morty/hikey/rpb/linux-next/237
export LINUX_GIT_URL=git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
export LINUX_GIT_REFERENCE=/home/drue/src/linux/mainline

export BAD=next-20180413
export GOOD=next-20180411
export LAVA_JOB=job_181558.yaml
export LAVA_TEST_SUITE="1_bisect"
export LAVA_TEST_CASE="bisect"
```

- URL - a snapshots build url to use as a base OE image.
- LINUX_GIT_URL - git repo to use for the bisection
- LINUX_GIT_REFERENCE - (optional) local git path to use during clone (clone
  --reference)
- BAD - git revision of the first bad commit
- GOOD - git revision of the last good commit
- LAVA_JOB - filename with lava job. system url should be replaced with string
  "BISECT_URL"
- LAVA_TEST_SUITE - test suite name in LAVA_JOB file
- LAVA_TEST_CASE - test case name in LAVA_JOB file

To build a lava job file, take an example job from production and make three
modifications:
- Set priority to 100.
- Set system url to BISECT_URL (for hikey)
- Create an inline test job such as the following, and remove the actual test
  (to save time):

```yaml
    - from: inline
      repository:
        metadata:
          format: Lava-Test Test Definition 1.0
          name: bisect
          description: Bisect
        run:
          steps:
          - lava-test-case bisect --shell /opt/kselftests/default-in-kernel/bpf/test_xdp_meta.sh
      name: bisect
      path: inline/bisect
```

Where the 'lava-test-case' arguments are the actual failing test, that returns
an exit code of 0 when it passes.

To bisect, source your run file and then run 'bisect-lkft'.

See example runfiles in runs/.

Example run:

```sh
. test_xdp_meta.sh
bisect-lkft
```

### TODO

- rebuild kselftest, when possible (mainline/next)..
- Remove hard coded rsync paths for people.linaro.org
- Add support for x15, db410c
- Support for qemu? (local or using lava?)

## Design

### Build

- Rebuild kernel (use build-kernel and linaro's docker container)
- Insert kernel into existing OE build output based on machine type

Parameters:
- Kernel git url
- Machine

### Bisection

- LAVA for running tests

Parameters - Everything from 'Build', plus:
- good commit
- bad commit
- lava test case (in some format TBD)


## Image types per board

Below is the list of supported boards and the example files that are passed to
LAVA.

x15:
- userdata: rpb-console-image-am57xx-evm-20180427145356-17.rootfs.img.gz

qemu_arm32 (based on x15):
- zImage--4.16+git0+e5ce9f6879-r0-am57xx-evm-20180426095506-16.bin
- rpb-console-image-am57xx-evm-20180426095506-16.rootfs.ext4

db410c
- boot: boot--4.16+git0+d804f93aa2-r0-dragonboard-410c-20180427144900-17-17.img
- rootfs: rpb-console-image-dragonboard-410c-20180427144900-17.rootfs.img.gz

hikey-6220
- ptable: ptable-linux-8g.img
- boot: boot-0.0+AUTOINC+06e4def583-fb1158a365-r0-hikey-20180427152124-17.uefi.img
- system: rpb-console-image-hikey-20180427152124-17.rootfs.img.gz

juno:
- dtb: Image--4.16+git0+d804f93aa2-r0-juno-r2-20180427145541-17.dtb
- kernel: Image--4.16+git0+d804f93aa2-r0-juno-20180427145541-17.bin
- nfsrootfs: rpb-console-image-juno-20180427145541-17.rootfs.tar.xz

x86_64
- kernel: bzImage--4.16+git0+d804f93aa2-r0-intel-core2-32-20180427152152-17.bin
- nfsrootfs: rpb-console-image-intel-core2-32-20180427152152-17.rootfs.tar.xz


## X15

This works in qemu but not in LAVA (boot hangs while loading kernel).

```
# extract tar
mkdir rootfs
sudo tar xpf rpb-console-image-am57xx-evm-20180423192219-12.rootfs.tar.xz -C rootfs/

# add init script for test
# build kernel
drue@xps:~/src/linux/mainline$ build-kernel -c -m am57xx-evm -k linux-mainline

# Also had to make uImage for x15 rootfs:
drue@xps:~/src/linux/mainline$ make -j 4 CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm KDIR=/home/drue/src/linux/mainline O=/home/drue/ragnar-artifacts/build_output/arm/v4.15-3279-g7b1cd95d65eb uImage LOADADDR=0x80008000


# copy kernel to tar
sudo cp /home/drue/ragnar-artifacts/staging/arm/v4.15-3279-g7b1cd95d65eb/zImage-v4.15-3279-g7b1cd95d65eb rootfs/boot/
sudo cp -r /home/drue/ragnar-artifacts/staging/arm/v4.15-3279-g7b1cd95d65eb/lib/modules/4.15.0-03279-g7b1cd95d65eb rootfs/lib/modules/
drue@xps:~/src/linaro-scratch/qemu/3769$ sudo cp /home/drue/ragnar-artifacts/build_output/arm/v4.15-3279-g7b1cd95d65eb/arch/arm/boot/uImage rootfs/boot/uImage-v4.15-3279-g7b1cd95d65eb
sudo ln -sf zImage-v4.15-3279-g7b1cd95d65eb rootfs/boot/zImage


# make ext4 from tar
## XXX Not sure about sizing here - existing x15 image looks to be 1.2G.
rm -f rootfs.ext4 && dd if=/dev/zero of=rootfs.ext4 seek=2097152 count=120 bs=1024
sudo mkfs.ext4 rootfs.ext4 -d rootfs/

# make an img file from ext4
ext2simg -zv rootfs.ext4 v4.15-3279-g7b1cd95d65eb-rootfs.img.gz
```

## hikey

```
wget http://snapshots.linaro.org/openembedded/lkft/morty/hikey/rpb/linux-mainline/816/rpb-console-image-hikey-20180423032146-816.rootfs.tar.xz

mkdir rootfs
sudo tar xpf rpb-console-image-hikey-20180423032146-816.rootfs.tar.xz -C rootfs/

sudo cp /home/drue/ragnar-artifacts/staging/arm64/v4.17-rc3-10-gf2125992e7cb/Image-v4.17-rc3-10-gf2125992e7cb rootfs/boot/
sudo cp -r /home/drue/ragnar-artifacts/staging/arm64/v4.17-rc3-10-gf2125992e7cb/lib/modules/4.17.0-rc3-00010-gf2125992e7cb rootfs/lib/modules/
sudo ln -sf Image-v4.17-rc3-10-gf2125992e7cb rootfs/boot/Image

rm -f rootfs.ext4 && dd if=/dev/zero of=rootfs.ext4 seek=2629636 count=120 bs=1024
sudo mkfs.ext4 rootfs.ext4 -d rootfs/ -L rootfs

ext2simg -zv rootfs.ext4 v4.17-rc3-10-gf2125992e7cb-rootfs.img.gz

scp v4.17-rc3-10-gf2125992e7cb-rootfs.img.gz people.linaro.org:~/public_html/files/
```

Alternative:
```
drue@xps:~/src/ragnar-esque/hikey$ sudo mount -o loop rpb-console-image-hikey-20180423032146-816.rootfs.ext4 mnt/
drue@xps:~/src/ragnar-esque/hikey$ sudo cp /home/drue/ragnar-artifacts/staging/arm64/v4.17-rc3-10-gf2125992e7cb/Image-v4.17-rc3-10-gf2125992e7cb mnt/boot/
drue@xps:~/src/ragnar-esque/hikey$ sudo cp -r /home/drue/ragnar-artifacts/staging/arm64/v4.17-rc3-10-gf2125992e7cb/lib/modules/4.17.0-rc3-00010-gf2125992e7cb mnt/lib/modules/
drue@xps:~/src/ragnar-esque/hikey$ sudo ln -sf Image-v4.17-rc3-10-gf2125992e7cb mnt/boot/Image
drue@xps:~/src/ragnar-esque/hikey$ sudo umount mnt
drue@xps:~/src/ragnar-esque/hikey$ mv rpb-console-image-hikey-20180423032146-816.rootfs.ext4  v4.17-rc3-10-gf2125992e7cb-rootfs-live.ext4
drue@xps:~/src/ragnar-esque/hikey$ ext2simg -zv v4.17-rc3-10-gf2125992e7cb-rootfs-live.ext4 v4.17-rc3-10-gf2125992e7cb-rootfs-live.img.gz
scp v4.17-rc3-10-gf2125992e7cb-rootfs-live.img.gz people.linaro.org:~/public_html/files/
```

