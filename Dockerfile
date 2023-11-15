FROM ubuntu:20.04
LABEL Description="Cross-compiler for RPi"

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /app

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    unzip \
    pkg-config \
    libjpeg-dev \
    libtiff5-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev \
    libgtk2.0-dev \
    libatlas-base-dev \
    gfortran \
    ccache \
    libneon27-dev \
    python2 python3 \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    nano vim \
    libssl-dev \
    && \
    rm -rf /var/lib/apt/lists/*

COPY cmake/rpi_aarch64.cmake /app/rpi_aarch64.cmake
ENV SYSROOT=/usr/aarch64-linux-gnu

RUN wget https://boostorg.jfrog.io/artifactory/main/release/1.83.0/source/boost_1_83_0.tar.gz

RUN mkdir ~/boost_install && mv boost_1_83_0.tar.gz ~/boost_install && \
    cd ~/boost_install && tar -zxf boost_1_83_0.tar.gz

RUN cd ~/boost_install/boost_1_83_0/ && \
    echo "using gcc : arm : aarch64-linux-gnu-g++ ;" > tools/build/src/user-config.jam && \
    ./bootstrap.sh --prefix=${SYSROOT} && \
    ./b2 install -j$(nproc) -d2 -a toolset=gcc-arm target-os=linux --prefix=${SYSROOT}

RUN rm -rf ~/boost_install

RUN mkdir ~/eigen_build && cd ~/eigen_build && \
    git clone https://gitlab.com/libeigen/eigen.git eigen && \
    cd eigen && git checkout 3.3.7

RUN cd ~/eigen_build/eigen && mkdir build && cd build && \
    cmake -DCMAKE_TOOLCHAIN_FILE=/app/rpi_aarch64.cmake \
    -DCMAKE_INSTALL_PREFIX=${SYSROOT} \
    .. && \
    make -j$(nproc) && make install

RUN rm -rf ~/eigen_build

RUN mkdir ~/grpc_build && cd ~/grpc_build && \
    git clone --recurse-submodules -b v1.50.0 --depth 1 --shallow-submodules https://github.com/grpc/grpc .

# Install gRPC for host system as is required for cross-compiling
RUN cd ~/grpc_build && \
    mkdir -p cmake/build && cd cmake/build && \
    cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DgRPC_INSTALL=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DgRPC_SSL_PROVIDER=package \
    ../.. && \
    make -j$(nproc) && make install

RUN cd ~/grpc_build && \
    mkdir build && cd build && \
    cmake -DCMAKE_TOOLCHAIN_FILE=/app/rpi_aarch64.cmake \
    -DgRPC_INSTALL=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX=${SYSROOT} \
    .. && \
    make -j$(nproc) && make install

RUN mkdir ~/glog_build && cd ~/glog_build && \
    git clone https://github.com/google/glog.git . && \
    git checkout v0.6.0

RUN cd ~/glog_build && mkdir build && cd build && \
    cmake -DCMAKE_TOOLCHAIN_FILE=/app/rpi_aarch64.cmake \
    -DCMAKE_INSTALL_PREFIX=${SYSROOT} \
    .. && \
    make -j$(nproc) && make install

RUN rm -rf ~/glog_build

RUN mkdir ~/gflags_build && cd ~/gflags_build && \
    git clone https://github.com/gflags/gflags.git . && \
    git checkout v2.2.0

RUN cd ~/gflags_build && mkdir build && cd build && \
    cmake -DCMAKE_TOOLCHAIN_FILE=/app/rpi_aarch64.cmake \
    -DCMAKE_INSTALL_PREFIX=${SYSROOT} \
    .. && \
    make -j$(nproc) && make install

RUN rm -rf ~/gflags_build

# Install aaarch64 cross-compiler for fortran
RUN apt-get update && apt-get install -y \
    gfortran-aarch64-linux-gnu

# Clone OpenBLAS and Build from source
RUN mkdir ~/openblas_build && cd ~/openblas_build && \
    git clone -b v0.3.20 --single-branch --depth 1 \
    https://github.com/xianyi/OpenBLAS && \
    cd ~/openblas_build/OpenBLAS && \
    make -j$(nproc) \
    HOSTCC=gcc CC=aarch64-linux-gnu-gcc \
    FC=aarch64-linux-gnu-gfortran \
    TARGET=CORTEXA72 V=1 && \
    make PREFIX=${SYSROOT} install

# Clone Ceressolver and Build from source
RUN mkdir ~/ceres_build && cd ~/ceres_build && \
    git clone https://github.com/ceres-solver/ceres-solver.git . && \
    git checkout 2.1.0

RUN cd ~/ceres_build && mkdir build && cd build && \
    cmake -DCMAKE_TOOLCHAIN_FILE=/app/rpi_aarch64.cmake \
    -DCMAKE_INSTALL_PREFIX=${SYSROOT} \
    .. && \
    make -j$(nproc) && make install

RUN rm -rf ~/ceres_build

# # Check if LAPACK is installed
# RUN find ${SYSROOT} -name liblapack.a

RUN mkdir ~/opencv_build && cd ~/opencv_build && \
    git clone https://github.com/opencv/opencv.git && \
    git clone https://github.com/opencv/opencv_contrib.git

RUN cd ~/opencv_build/opencv && git checkout 4.5.1
RUN cd ~/opencv_build/opencv_contrib && git checkout 4.5.1

# Build JPEG from source for Raspberry Pi
RUN mkdir ~/jpeg_build && cd ~/jpeg_build && \
    wget http://www.ijg.org/files/jpegsrc.v9d.tar.gz && \
    tar -zxf jpegsrc.v9d.tar.gz && \
    cd jpeg-9d && \
    ./configure \
    --prefix=${SYSROOT} \
    --target=aarch64-linux-gnu \
    --host=aarch64-linux-gnu \
    CC=aarch64-linux-gnu-gcc \
    CXX=aarch64-linux-gnu-g++ \
    FC=aarch64-linux-gnu-gfortran && \
    make -j$(nproc) && make install

# Check if JPEG is installed
RUN find ${SYSROOT} -name libjpeg.a

# Build TIFF from source for Raspberry Pi
RUN mkdir ~/tiff_build && cd ~/tiff_build && \
    wget http://download.osgeo.org/libtiff/tiff-4.3.0.tar.gz && \
    tar -zxf tiff-4.3.0.tar.gz && \
    cd tiff-4.3.0 && \
    ./configure \
    --host=aarch64-linux-gnu \
    --prefix=${SYSROOT} \
    CC=aarch64-linux-gnu-gcc \
    CXX=aarch64-linux-gnu-g++ && \
    make -j$(nproc) && make install

# Check if TIFF is installed
RUN find ${SYSROOT} -name libtiff.a

# BUild WEBP from source for Raspberry Pi
RUN mkdir ~/webp_build && cd ~/webp_build && \
    wget https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.2.0.tar.gz && \
    tar -zxf libwebp-1.2.0.tar.gz && \
    cd libwebp-1.2.0 && \
    ./configure \
    --host=aarch64-linux-gnu \
    --prefix=${SYSROOT} \
    CC=aarch64-linux-gnu-gcc \
    CXX=aarch64-linux-gnu-g++ && \
    make -j$(nproc) && make install

# Check if WEBP is installed
RUN find ${SYSROOT} -name libwebp.a

# Build PNG from source for Raspberry Pi
RUN mkdir ~/png_build && cd ~/png_build && \
    wget https://download.sourceforge.net/libpng/libpng-1.6.37.tar.gz && \
    tar -zxf libpng-1.6.37.tar.gz && \
    cd libpng-1.6.37 && \
    ./configure \
    --host=aarch64-linux-gnu \
    --prefix=${SYSROOT} \
    CC=aarch64-linux-gnu-gcc \
    CXX=aarch64-linux-gnu-g++ && \
    make -j$(nproc) && make install

# Check if PNG is installed
RUN find ${SYSROOT} -name libpng.a

# Build Raspberry Pi userland from source for Raspberry Pi
RUN mkdir ~/userland_build && cd ~/userland_build && \
    git clone https://github.com/raspberrypi/userland.git . && \
    git checkout 291f9cb826d51ac30c1114cdc165836eacd8db52 && \
    ./buildme --aarch64 && \
    cd build/arm-linux/release && \
    make install DESTDIR=${SYSROOT}

# Build Neon from source for Raspberry Pi
RUN mkdir ~/neon_build && cd ~/neon_build && \
    wget https://notroj.github.io/neon/neon-0.32.5.tar.gz && \
    tar -zxf neon-0.32.5.tar.gz && \
    cd neon-0.32.5 && \
    ./configure \
    --host=aarch64-linux-gnu \
    --prefix=${SYSROOT} \
    && \
    make -j$(nproc) && make install

# Check if Neon is installed
RUN find ${SYSROOT} -name libneon.a

# VPX BUILD IS NOT WORKING requires Neon
# Build VPX from source for Raspberry Pi
RUN mkdir ~/vpx_build && cd ~/vpx_build && \
    git clone -b 'v1.11.0' --single-branch --depth 1 \
    https://chromium.googlesource.com/webm/libvpx . && \
    export CROSS=aarch64-linux-gnu- && \
    ./configure \
    --enable-install-srcs \
    --disable-install-docs \
    --enable-shared \
    --target=arm64-linux-gcc \
    --prefix=${SYSROOT} \
    && \
    make -j$(nproc) && make install

# Build x264 from source for Raspberry Pi
RUN mkdir ~/x264_build && cd ~/x264_build && \
    git clone https://code.videolan.org/videolan/x264.git . && \
    git checkout stable && \
    ./configure \
    --host=aarch64-linux-gnu \
    --prefix=${SYSROOT} \
    --cross-prefix=aarch64-linux-gnu- \
    --enable-shared && \
    make -j$(nproc) && make install

# Check if x264 is installed
RUN find ${SYSROOT} -name libx264.a

# Build xvid from github source for Raspberry Pi
RUN mkdir ~/xvid_build && cd ~/xvid_build && \
    wget https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz && \
    tar -zxf xvidcore-1.3.7.tar.gz && \
    cd xvidcore/build/generic && \
    ./configure \
    --host=aarch64-linux-gnu \
    --prefix=${SYSROOT} \
    && \
    make -j$(nproc) && make install

# Check if xvid is installed
RUN find ${SYSROOT} -name libxvidcore.a

# Check if mmal is installed
RUN find ${SYSROOT} -name libmmal.a

# Install pkg-config for cross-compiling
RUN apt-get install pkg-config-aarch64-linux-gnu

# Build FFmpeg from source for Raspberry Pi
RUN mkdir ~/ffmpeg_build && cd ~/ffmpeg_build && \
    wget https://ffmpeg.org/releases/ffmpeg-4.3.6.tar.gz && \
    tar -zxf ffmpeg-4.3.6.tar.gz && \
    cd ffmpeg-4.3.6 && \
    ./configure --prefix=${SYSROOT} \
    --arch="aarch64" \
    --target-os="linux" \
    --enable-cross-compile \
    --cross-prefix="aarch64-linux-gnu-" \
    --toolchain=hardened \
    --enable-gpl --enable-nonfree \
    --enable-neon --enable-shared \
    --disable-static --disable-doc \
    --enable-libx264 --enable-libxvid \
    --enable-libvpx --enable-mmal \
    --extra-ldflags="-L/usr/aarch64-linux-gnu/opt/vc/lib -lvcos -lmmal_core -lmmal_util -lmmal_vc_client -lbcm_host -lvchiq_arm -lvcsm -L/usr/aarch64-linux-gnu/lib" \
    --extra-cflags="-I/usr/aarch64-linux-gnu/include -I/usr/aarch64-linux-gnu/opt/vc/include -I/usr/aarch64-linux-gnu/opt/vc/lib" \
        && make -j$(nproc) && make install

ENV PKG_CONFIG_LIBDIR="${SYSROOT}/lib:${SYSROOT}/opt/vc/lib"
ENV PKG_CONFIG_PATH="${SYSROOT}/lib/pkgconfig:${SYSROOT}/opt/vc/lib/pkgconfig"
ENV PKG_CONFIG_SYSROOT_DIR=${SYSROOT}

# Build OpenCV from source for Raspberry Pi
RUN cd ~/opencv_build/opencv && mkdir build && cd build && \
    cmake -DCMAKE_TOOLCHAIN_FILE=/app/rpi_aarch64.cmake \
    -D OPENCV_EXTRA_MODULES_PATH=~/opencv_build/opencv_contrib/modules \
    -D WITH_EIGEN=ON \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=${SYSROOT} \
    -D OPENCV_GENERATE_PKGCONFIG=ON \
    -D ENABLE_NEON=ON \
    -D INSTALL_C_EXAMPLES=OFF \
    -D INSTALL_PYTHON_EXAMPLES=OFF \
    -D BUILD_EXAMPLES=OFF \
    -D WITH_FFMPEG=ON \
    .. && \
    make -j12 && make install

RUN rm -rf ~/opencv_build


# RUN mkdir ~/gtsam_build && cd ~/gtsam_build && \
#     git clone https://github.com/borglab/gtsam.git . && \
#     git checkout 4.1.1 && mkdir build && cd build && \
#     cmake -DCMAKE_TOOLCHAIN_FILE=/app/rpi_aarch64.cmake \
#     -DCMAKE_INSTALL_PREFIX=${SYSROOT} \
#     -DGTSAM_BUILD_DOCS=OFF \
#     -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
#     -DGTSAM_BUILD_TESTS=ON \
#     -DGTSAM_BUILD_WITH_CCACHE=OFF \
#     -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
#     -DGTSAM_INSTALL_CPPUNITLITE=OFF \
#     -DGTSAM_INSTALL_GEOGRAPHICLIB=OFF \
#     -DGTSAM_USE_SYSTEM_EIGEN=ON \
#     .. && make -j4 && make install

# RUN rm -rf ~/gtsam_build

# ENV LD_LIBRARY_PATH=/usr/local:$LD_LIBRARY_PATH