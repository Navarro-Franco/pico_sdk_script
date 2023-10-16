#!/bin/bash

# Exit on error
set -e
# Number of cores when running make
JNUM=4
# Default installation directory
DIR_INSTALL="$HOME/pico/"
# Dependencies
# Nota: Todo esto sacado de getting-started-with-pico 
GIT_DEPS="git"
SDK_DEPS="cmake gcc-arm-none-eabi libnewlib-arm-none-eabi build-essential libstdc++-arm-none-eabi-newlib"
OPENOCD_DEPS="gdb-multiarch automake autoconf texinfo libtool libftdi-dev libusb-1.0-0-dev"
UART_DEPS="minicom"
# Extra dependencies
EXTRA_DEPS=""
# Build full list of dependencies
DEPS="$GIT_DEPS $SDK_DEPS $OPENOCD_DEPS $UART_DEPS $EXTRA_DEPS"

echo "Installing Dependencies"
sudo apt update
sudo apt install -y $DEPS

echo "Creating $DIR_INSTALL"
# Create pico directory to put everything in
mkdir -p $DIR_INSTALL
cd $DIR_INSTALL

# Clone sw repos and add to ~/.bashrc variables like PICO_SDK_PATH
GITHUB_PREFIX="https://github.com/raspberrypi/"
GITHUB_SUFFIX=".git"
SDK_BRANCH="master"
for REPO in sdk examples extras playground
do
    DEST="$DIR_INSTALL/pico-$REPO"

    if [ -d $DEST ]; then
        echo "$DEST already exists so skipping"
    else
        REPO_URL="${GITHUB_PREFIX}pico-${REPO}${GITHUB_SUFFIX}"
        echo "Cloning $REPO_URL"
        git clone -b $SDK_BRANCH $REPO_URL

        # Any submodules
        cd $DEST
        git submodule update --init
        cd $DIR_INSTALL

        # Define PICO_SDK_PATH in ~/.bashrc
        VARNAME="PICO_${REPO^^}_PATH"
        echo "Adding $VARNAME to ~/.bashrc"
        echo "export $VARNAME=$DEST" >> ~/.bashrc
        export ${VARNAME}=$DEST
    fi
done

cd $DIR_INSTALL

# Pick up new variables we just defined
source ~/.bashrc

# Build examples
cd "$DIR_INSTALL/pico-examples"
mkdir build
cd build
cmake ../ -DCMAKE_BUILD_TYPE=Debug
make -j$JNUM

cd $DIR_INSTALL

# Picoprobe and picotool
for REPO in picoprobe picotool
do
    DEST="$DIR_INSTALL/$REPO"
    REPO_URL="${GITHUB_PREFIX}${REPO}${GITHUB_SUFFIX}"
    git clone $REPO_URL

    # Build both
    cd $DEST
    git submodule update --init
    mkdir build
    cd build
    cmake ../
    make -j$JNUM

    if [[ "$REPO" == "picotool" ]]; then
        echo "Installing picotool to /usr/local/bin/picotool"
        sudo cp picotool /usr/local/bin/
    fi

    cd $DIR_INSTALL
done

if [ -d openocd ]; then
    echo "openocd already exists so skipping"
    SKIP_OPENOCD=1
fi

if [[ "$SKIP_OPENOCD" == 1 ]]; then
    echo "Won't build OpenOCD"
else
    # Build OpenOCD
    echo "Building OpenOCD"
    cd $DIR_INSTALL
    # Should we include picoprobe support (which is a Pico acting as a debugger for another Pico)
    INCLUDE_PICOPROBE=1
    OPENOCD_BRANCH="rp2040-v0.12.0"
    OPENOCD_CONFIGURE_ARGS="--enable-ftdi --enable-sysfsgpio --enable-bcm2835gpio"
    if [[ "$INCLUDE_PICOPROBE" == 1 ]]; then
        OPENOCD_CONFIGURE_ARGS="$OPENOCD_CONFIGURE_ARGS --enable-picoprobe"
    fi

    git clone "${GITHUB_PREFIX}openocd${GITHUB_SUFFIX}" -b $OPENOCD_BRANCH --depth=1
    cd openocd
    ./bootstrap
    ./configure $OPENOCD_CONFIGURE_ARGS
    make -j$JNUM
    sudo make install
fi

cd $DIR_INSTALL
