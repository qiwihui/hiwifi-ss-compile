#!/bin/bash
set -e
# -----------创建编译目录
rm -rf /mnt/build/shadowsocks-$MLIB
mkdir -p /mnt/build/shadowsocks-$MLIB && cd /mnt/build/shadowsocks-$MLIB
BASE=$(pwd)
SRC=$BASE/src
PREFIX=$BASE/local
PRE=$BASE/lib
mkdir -p $SRC $PRE $PREFIX
PKG_CONFIG_PATH=$PRE/lib/pkgconfig/
LD_LIBRARY_PATH=$PRE/lib/

export STAGING_DIR=/mnt/hc5962/staging_dir

# ------------编译mbedTLS
mkdir -p $SRC/mbedTLS && cd $SRC/mbedTLS
ver=2.6.0
wget -q --no-check-certificate https://tls.mbed.org/download/mbedtls-$ver-gpl.tgz
tar zxf mbedtls-$ver-gpl.tgz
cd mbedtls-$ver
CC=$HOST-gcc AR=$HOST-ar LD=$HOST-ld LDFLAGS=-static make DESTDIR=$PREFIX install

# ------------编译pcre
mkdir -p $SRC/pcre && cd $SRC/pcre
ver=8.41
wget -q ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$ver.tar.gz
tar zxf pcre-$ver.tar.gz
cd pcre-$ver
./configure --host=$HOST --prefix=$PREFIX --disable-shared --enable-utf8 --enable-unicode-properties
make -j`nproc` && make install

# ------------编译libsodium
mkdir -p $SRC/libsodium && cd $SRC/libsodium
ver=1.0.16
wget -q --no-check-certificate https://download.libsodium.org/libsodium/releases/libsodium-$ver.tar.gz
tar zxf libsodium-$ver.tar.gz
cd libsodium-$ver
./configure --host=$HOST --prefix=$PREFIX --disable-ssp --disable-shared
make -j`nproc` && make install

# ------------编译libev
mkdir -p $SRC/libev && cd $SRC/libev
ver=4.24
# wget -q http://dist.schmorp.de/libev/libev-$ver.tar.gz
wget -q https://sources.voidlinux.eu/libev-$ver/libev-$ver.tar.gz
tar zxf libev-$ver.tar.gz
cd libev-$ver
./configure --host=$HOST --prefix=$PREFIX --disable-shared
make -j`nproc` && make install

# ------------编译libudns
mkdir -p $SRC/libudns && cd $SRC/libudns
git clone git://github.com/shadowsocks/libudns
cd libudns
./autogen.sh
./configure --host=$HOST --prefix=$PREFIX
make -j`nproc` && make install

# ------------编译c-ares
mkdir -p $SRC/c-ares && cd $SRC/c-ares
ver=1.13.0
wget -q https://c-ares.haxx.se/download/c-ares-$ver.tar.gz
tar zxvf c-ares-$ver.tar.gz
cd c-ares-$ver
sed -i 's#\[-\]#[1.13.0]#' configure.ac
./buildconf
./configure --prefix=$PREFIX --host=$HOST CC=$HOST-gcc --enable-shared=no --enable-static=yes
make -j`nproc` && make install

# ------------编译shadowsocks-libev
mkdir -p $SRC/shadowsocks-libev && cd $SRC/shadowsocks-libev
ver=3.2.0
git clone git://github.com/shadowsocks/shadowsocks-libev
cd shadowsocks-libev
git checkout v$ver -b v$ver
git submodule init && git submodule update

# TODO: modify to disable pthread check
./autogen.sh
LIBS="-lpthread -lm" LDFLAGS="-Wl,-static -static -static-libgcc -L$PREFIX/lib" CFLAGS="-I$PREFIX/include"  ./configure --host=$HOST --prefix=$PREFIX --disable-ssp --disable-documentation --with-mbedtls=$PREFIX --with-pcre=$PREFIX --with-sodium=$PREFIX
make -j`nproc` && make install

# ------------编译simple-obfs
mkdir -p $SRC/simple-obfs && cd $SRC/simple-obfs
ver=0.0.5
git clone https://github.com/shadowsocks/simple-obfs
cd simple-obfs
git checkout v$ver -b v$ver
git submodule init && git submodule update
./autogen.sh
LIBS="-lpthread -lm" LDFLAGS="-Wl,-static -static -static-libgcc -L$PREFIX/lib" CFLAGS="-I$PREFIX/include" \
	./configure --host=$HOST --prefix=$PREFIX --disable-ssp --disable-documentation
make -j`nproc` && make install

# ------------压缩体积
cp $PREFIX/bin/ss-* $BASE
cp $PREFIX/bin/obfs-* $BASE
# compress
$HOST-strip $BASE/obfs-*
upx $BASE/obfs-*

find $BASE/ss-* ! -name 'ss-nat' -type f | xargs $HOST-strip 
find $BASE/ss-* ! -name 'ss-nat' -type f | xargs upx
cd $BASE

# ------------还原环境变量
# PATH=$PATH_A
echo
echo "Done!"
