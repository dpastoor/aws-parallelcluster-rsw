#!/bin/bash

# Install and configure R
apt-get update -y
apt-get install -y gdebi-core
apt-get install -y openjdk-11-jdk openjdk-8-jdk
apt-get install -y libfreetype6-dev libpng-dev libtiff5-dev
aws s3 cp s3://devin-hpcscripts1234/run.R /tmp

for R_VERSION in "$@" 
do
  echo "xxx R_VERSION : ${R_VERSION}"
  curl -O https://cdn.rstudio.com/r/ubuntu-2004/pkgs/r-${R_VERSION}_1_amd64.deb
  gdebi -n r-${R_VERSION}_1_amd64.deb
  dpkg --info r-${R_VERSION}_1_amd64.deb | grep " Depends" | cut -d ":" -f 2 > /opt/R/$R_VERSION/.depends
  rm -f r-${R_VERSION}_1_amd64.deb
  if [ ${R_VERSION:0:1} == '3' ]; then 
	export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/
  else 
	export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/
  fi
  /opt/R/$R_VERSION/bin/R CMD javareconf 
  /opt/R/$R_VERSION/bin/Rscript /tmp/run.R
done

# prepare renv package cache 
sudo mkdir -p /scratch/renv
cat << EOF > /tmp/acl
user::rwx
group::rwx
mask::rwx
other::rwx
default:user::rwx
default:group::rwx
default:mask::rwx
default:other::rwx
EOF

setfacl -R --set-file=/tmp/acl /scratch/renv


# Install RSWB
groupadd --system --gid 900 rstudio-server
useradd -s /bin/bash -m --system --gid rstudio-server --uid 900 rstudio-server
RSWB_VER=2022.11.0-daily-213.pro2
curl -O https://s3.amazonaws.com/rstudio-ide-build/server/bionic/amd64/rstudio-workbench-${RSWB_VER}-amd64.deb 
gdebi -n rstudio-workbench-${RSWB_VER}-amd64.deb
rm -f rstudio-workbench-${RSWB_VER}.pro6-amd64.deb

for i in server launcher 
do 
mkdir -p /etc/systemd/system/rstudio-$i.service.d
mkdir -p /opt/rstudio/etc/rstudio
cat <<EOF > /etc/systemd/system/rstudio-$i.service.d/override.conf
[Service]
Environment="RSTUDIO_CONFIG_DIR=/opt/rstudio/etc/rstudio"
EOF
done

# Add sample user 
groupadd --system --gid 1001 rstudio
useradd -s /bin/bash -m --system --gid rstudio --uid 1001 rstudio

echo -e "rstudio\nrstudio" | passwd rstudio

cat <<EOF > /home/rstudio/.Rprofile
#set SLURM binaries PATH so that RSW Launcher jobs work
slurm_bin_path<-"/opt/slurm/bin"

curr_path<-strsplit(Sys.getenv("PATH"),":")[[1]]

if (!(slurm_bin_path %in% curr_path)) {
  if (length(curr_path) == 0) {
     Sys.setenv(PATH = slurm_bin_path)
  } else {
     Sys.setenv(PATH = paste0(Sys.getenv("PATH"),":",slurm_bin_path))
}

}

options(
    clustermq.scheduler = "slurm",
    clustermq.template = "~/slurm.tmpl" 
)
EOF

cat << EOF > /home/rstudio/slurm.tmpl
#!/bin/bash -l

# File: slurm.tmpl
# Template for using clustermq against a SLURM backend

#SBATCH --job-name={{ job_name }}
#SBATCH --error={{ log_file | /dev/null }}
#SBATCH --mem-per-cpu={{ memory | 1024 }}
#SBATCH --array=1-{{ n_jobs }}
#SBATCH --cpus-per-task={{ cores | 1 }}


export OMP_NUM_THREADS={{ cores | 1 }}
#ulimit -v $(( 1024 * {{ memory | 1024 }} ))
CMQ_AUTH={{ auth }} ${R_HOME}/bin/R --no-save --no-restore -e 'clustermq:::worker("{{ master }}")'
EOF

chown rstudio:rstudio /home/rstudio/{.Rprofile,slurm.tmpl}


# Add SLURM integration 
myip=`curl http://checkip.amazonaws.com`

mkdir -p /tmp/rstudio
mkdir -p /opt/rstudio/shared-storage

echo "RSTUDIO_DISABLE_PACKAGE_INSTALL_PROMPT=yes" > /etc/rstudio/launcher-env

cat > /tmp/rstudio/rserver.conf << EOF
# Shared storage
server-shared-storage-path=/opt/rstudio/shared-storage

# Launcher Config
launcher-address=127.0.0.1
launcher-port=5559
launcher-sessions-enabled=1
launcher-default-cluster=Slurm
launcher-sessions-callback-address=http://${myip}:8787
EOF

cat > /tmp/rstudio/launcher.conf<<EOF
[server]
address=127.0.0.1
port=5559
server-user=rstudio-server
admin-group=rstudio-server
authorization-enabled=1
thread-pool-size=4
enable-debug-logging=1

[cluster]
name=Slurm
type=Slurm

[cluster]
name=Local
type=Local

EOF

cat > /tmp/rstudio/launcher.slurm.profiles.conf<<EOF 
[*]
default-cpus=1
default-mem-mb=512
max-cpus=2
max-mem-mb=1024
EOF

cat > /tmp/rstudio/launcher.slurm.conf << EOF 
# Enable debugging
enable-debug-logging=1

# Basic configuration
slurm-service-user=slurm
slurm-bin-path=/opt/slurm/bin

# Singularity specifics
#constraints=Container=singularity-container

EOF

# Install VSCode
if [ ! -d /opt/rstudio/vscode ]; then
  # create directory to house code-server
  mkdir -p /opt/rstudio/vscode
  pushd /opt/rstudio/vscode

  # download the code server package
  wget https://rstd.io/vs-code-server-3-9-3 -O vs-code-server.tar.gz

  # extract code-server binary
  tar zxf vs-code-server.tar.gz --strip 1

  # remove the archive
  rm vs-code-server.tar.gz
  popd
  /opt/rstudio/vscode/bin/code-server --extensions-dir /opt/rstudio/vscode/extensions --install-extension ms-python.python
  curl -L https://rstd.io/vs-code-r-ext -o /tmp/Ikuyadeu.r-1.1.0.vsix.gz && gunzip /tmp/Ikuyadeu.r-1.1.0.vsix.gz
  /opt/rstudio/vscode/bin/code-server --extensions-dir /opt/rstudio/vscode/extensions --install-extension /tmp/Ikuyadeu.r-1.1.0.vsix
  rm -f /tmp/Ikuyadeu.r-1.1.0.vsix 
fi 

cat > /tmp/rstudio/vscode.conf << EOF
exe=/opt/rstudio/vscode/bin/code-server
enabled=1
default-session-cluster=Slurm
EOF

cp /tmp/rstudio/* /opt/rstudio/etc/rstudio
rm -rf /tmp/rstudio

systemctl daemon-reload
rstudio-server restart
rstudio-launcher restart

#little hack to get the memory allocation working

sed -i '/^include.*/i NodeName=DEFAULT RealMemory=3928' /opt/slurm/etc/slurm.conf
sed -i '/^include.*/i SrunPortRange=59000-59999' /opt/slurm/etc/slurm.conf

systemctl restart slurmctld

# Packages for R packages
apt-get install -y libzmq5  libglpk40 libnode-dev

grep slurm /etc/exports | sed 's/slurm/R/' | sudo tee -a /etc/exports 
grep slurm /etc/exports | sed 's/slurm/rstudio/' | sudo tee -a /etc/exports      
grep slurm /etc/exports | sed 's#/opt/slurm#/usr/lib/rstudio-server#' | sudo tee -a /etc/exports
grep slurm /etc/exports | sed 's#/opt/slurm#/scratch#' | sudo tee -a /etc/exports

exportfs -ar 

mount -a

rm -rf /etc/profile.d/modules.sh

#remove default R version (too old)
apt remove -y r-base-core
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
   bat \
   libglpk-dev \
   libgmp3-dev \
   libxml2-dev

#Install apptainer
export APPTAINER_VER=1.0.3
wget https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VER}/apptainer_${APPTAINER_VER}_amd64.deb && \
	dpkg -i apptainer_${APPTAINER_VER}_amd64.deb && \
	rm -f apptainer_${APPTAINER_VER}_amd64.deb*

#Configure container folder and export to nodes
mkdir -p /opt/apptainer/containers
grep slurm /etc/exports | sed 's#/opt/slurm#/opt/apptainer#' | sudo tee -a /etc/exports
exportfs -ar

aws s3 cp s3://devin-hpcscripts1234/run.R /tmp
aws s3 cp s3://devin-hpcscripts1234/r-session.bionic.sdef /tmp
aws s3 cp s3://devin-hpcscripts1234/r-session.centos7.sdef /tmp
aws s3 cp s3://devin-hpcscripts1234/build-container.sh /tmp 
aws s3 cp s3://devin-hpcscripts1234/spank.tgz /tmp

cd /tmp
tar xvfz spank.tgz
pushd slurm-singularity-exec
make && make install 
popd
rm -f spank.tgz

#( cd /tmp
#for i in *.sdef
#do
#/usr/bin/apptainer build /opt/apptainer/containers/${i/sdef/simg} $i
#done ) & 