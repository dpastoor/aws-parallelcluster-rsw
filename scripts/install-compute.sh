#!/bin/bash

apt-get update -y

#Install Java support
apt-get install -y openjdk-11-jdk openjdk-8-jdk

# install venv support 
apt-get install -y python3.8-venv

#R package deps (ragg)
apt-get install -y libfreetype6-dev libpng-dev libtiff5-dev

# Add sample user 
groupadd --system --gid 1001 rstudio
useradd -s /bin/bash -m --system --gid rstudio --uid 1001 rstudio

echo -e "rstudio\nrstudio" | passwd rstudio

apt-get install -y libzmq3-dev  libglpk40 libnode-dev

#mount various FS
grep slurm /etc/fstab | sed 's#/opt/slurm#/usr/lib/rstudio-server#g' | sudo tee -a /etc/fstab
grep slurm /etc/fstab | sed 's#/opt/slurm#/opt/R#g' | sudo tee -a /etc/fstab
grep slurm /etc/fstab | sed 's#/opt/slurm#/opt/rstudio#g' | sudo tee -a /etc/fstab
grep slurm /etc/fstab | sed 's#/opt/slurm#/scratch#g' | sudo tee -a /etc/fstab
grep slurm /etc/fstab | sed 's#/opt/slurm#/opt/apptainer#g' | sudo tee -a /etc/fstab

mkdir -p /usr/lib/rstudio-server /opt/{R,rstudio,apptainer} /scratch

mount -a

#Install RSW Dependencies
apt-get install -y rrdtool psmisc libapparmor1 libedit2 sudo lsb-release  libclang-dev libsqlite3-0 libpq5  libc6

#Install R dependencies
apt-get install -y `cat /opt/R/$/.depends | sed 's#,##g'`

rm -rf /etc/profile.d/modules.sh

#remove default R version (too old)
apt remove -y r-base-core

#Install apptainer
export APPTAINER_VER=1.0.2
wget https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VER}/apptainer_${APPTAINER_VER}_amd64.deb && \
        dpkg -i apptainer_${APPTAINER_VER}_amd64.deb && \
        rm -f apptainer_${APPTAINER_VER}_amd64.deb*


#Update CUDA and add cuDNN
if ( lspci | grep NVIDIA ); then 
   wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
   mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
   apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub
   add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /"
   apt-get update
   apt-get -y install cuda libcudnn8-dev
fi

apt-get install -y --no-install-recommends \
        bzip2 \
        ca-certificates \
        gdebi-core \
        git \
        libcap2 \
        libglib2.0-0 \
        libpam-sss \
        libpq5 \
        libsm6 \
        openssl \
        libnss-sss \
        libssl-dev \
        libuser \
        libuser1-dev \
        libxext6 \
        libxrender1 \
        oddjob-mkhomedir \
        openssh-client \
        rrdtool \
        librrd-dev \
        sssd \
        sudo \
        supervisor \
        wget \
        awscli \
        nginx-core \
        nginx \
        locales \
        software-properties-common \
        jq \
        make \
        vim \
        chrony \
        cargo \
   gdal-bin \
   git \
   gsfonts \
   imagemagick \
   libcurl4-openssl-dev \
   libfontconfig1-dev \
   libfreetype6-dev \
   libfribidi-dev \
   libgdal-dev \
   libgeos-dev \
   libgit2-dev \
   libharfbuzz-dev \
   libjpeg-dev \
   libmagick++-dev \
   libpng-dev \
   libpoppler-cpp-dev \
   libproj-dev \
   libprotobuf-dev \
   libsodium-dev \
   libssh2-1-dev \
   libssl-dev \
   libtiff-dev \
   libudunits2-dev \
   make \
   pandoc \
   pandoc-citeproc \
   protobuf-compiler \
   rustc \
   zlib1g-dev \
   ripgrep \
   htop \
   fd-find \
   bat