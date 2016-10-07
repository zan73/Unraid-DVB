#!/bin/bash

##Pull variables from github
wget -nc https://raw.githubusercontent.com/CHBMB/Unraid-DVB/master/files/variables.sh
. "$(dirname "$(readlink -f ${BASH_SOURCE[0]})")"/variables.sh

##Remove old folders
rm -rf $D/bzroot-ddexp $D/bzroot-master-* $D/bzroot-libreelec $D/bzroot-tbs $D/bzroot-tbs-dvbc $D/kernel $D/lib $D/media_build_experimental $D/libreelec-drivers $D/tbs-drivers $D/tbs-drivers-dvbc $D/unraid $D/.config $D/linux-*.tar.xz $D/unRAIDServer-*.zip $D/variables.sh $D/ddexp-*.zip $D/FILE_LIST $D:/packages

##Pull slackware64-current FILE_LIST to get packages
wget -nc http://mirrors.slackware.com/slackware/slackware64-current/slackware64/FILE_LIST

#Download patchutils
mkdir $D/packages
cd $D/packages
wget -nc https://github.com/CHBMB/Unraid-DVB/raw/master/files/patchutils-0.3.4-x86_64-1.tgz

##Instal perl-process-table for CrazyCat
export PERL_MM_USE_DEFAULT=1
cpan> install Proc::ProcessTable

#Change to current directory
cd $D

##Install pkg modules
[ ! -d "$D/packages" ] && mkdir $D/packages
  wget -nc -P $D/packages -i $D/URLS
  installpkg $D/packages/*.*

##Download and Install Kernel
[[ $(uname -r) =~ ([0-9.]*) ]] &&  KERNEL=${BASH_REMATCH[1]} || return 1
  LINK="https://www.kernel.org/pub/linux/kernel/v4.x/linux-${KERNEL}.tar.xz"
  rm -rf $D/kernel; mkdir $D/kernel
  [[ ! -f $D/linux-${KERNEL}.tar.xz ]] && wget $LINK -O $D/linux-${KERNEL}.tar.xz

  tar -C $D/kernel --strip-components=1 -Jxf $D/linux-${KERNEL}.tar.xz
  rsync -av /usr/src/linux-$(uname -r)/ $D/kernel/
  cd $D/kernel
  for p in $(find . -type f -iname "*.patch"); do patch -N -p 1 < $p
  done
  make oldconfig

##Make menuconfig
cd $D
wget https://files.linuxserver.io/unraid-dvb/$VERSION/stock/.config
cd $D/kernel
if [ -e $D/.config ]; then
   rm -f .config
   rsync $D/.config $D/kernel/.config
else
   make menuconfig
fi

##Compile Kernel
cd $D/kernel
make -j $(cat /proc/cpuinfo | grep -m 1 -Po "cpu cores.*?\K\d")

##Install Kernel Modules
cd $D/kernel
make all modules_install install

##Download Unraid
cd $D
wget -nc http://dnld.lime-technology.com/stable/unRAIDServer-"$(grep -o '".*"' /etc/unraid-version | sed 's/"//g')"-x86_64.zip
if [ -e $D/unRAIDServer-"$(grep -o '".*"' /etc/unraid-version | sed 's/"//g')"-x86_64.zip]; then
  unzip unRAIDServer-"$(grep -o '".*"' /etc/unraid-version | sed 's/"//g')"-x86_64.zip -d $D/unraid
else
  wget -nc http://dnld.lime-technology.com/next/unRAIDServer-"$(grep -o '".*"' /etc/unraid-version | sed 's/"//g')"-x86_64.zip
  unzip unRAIDServer-"$(grep -o '".*"' /etc/unraid-version | sed 's/"//g')"-x86_64.zip -d $D/unraid
fi

##Extract bzroot
rm -rf $D/bzroot-master-$VERSION; mkdir $D/bzroot-master-$VERSION; cd $D/bzroot-master-$VERSION
xzcat $D/unraid/bzroot | cpio -i -d -H newc --no-absolute-filenames

##Copy default Mediabuild Kernel Modules to bzroot
cd $D/kernel/
make modules_install
find /lib/modules/$(uname -r) -type f -exec cp -r --parents '{}' $D/bzroot-master-$VERSION/ \;

##Backup /lib/modules/ & /lib/firmware/
find /lib/modules/$(uname -r) -type f -exec cp -r --parents '{}' $D/ \;
find /lib/firmware -type f -exec cp -r --parents '{}' $D/ \;

##Copy default Unraid bz files to folder prior to uploading
mkdir -p $D/$VERSION/stock/
cp -f $D/unraid/bzimage $D/$VERSION/stock/
cp -f $D/unraid/bzroot $D/$VERSION/stock/
cp -f $D/unraid/bzroot-gui $D/$VERSION/stock/
cp -f $D/kernel/.config $D/$VERSION/stock/

##Calculate md5 on stock files
cd $D/$VERSION/stock/
md5sum bzroot > bzroot.md5
md5sum bzimage > bzimage.md5
md5sum bzroot-gui > bzroot-gui.md5
md5sum .config > .config.md5

#Return to original directory
cd $D
