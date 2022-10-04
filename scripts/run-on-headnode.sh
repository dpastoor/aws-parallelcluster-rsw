#!/bin/bash

myip=`curl http://checkip.amazonaws.com`
cat > /opt/rstudio/etc/rstudio/rserver.conf << EOF
# Shared storage
server-shared-storage-path=/opt/rstudio/shared-storage

# Launcher Config
launcher-address=127.0.0.1
launcher-port=5559
launcher-sessions-enabled=1
launcher-default-cluster=Slurm
launcher-sessions-callback-address=http://${myip}:8787
audit-r-sessions=1
audit-r-sessions-format=json
audit-r-sessions-limit-mb=0
audit-data-path=/audit-data

EOF
chown rstudio-server:rstudio-server /opt/rstudio/etc/rstudio/rserver.conf 


# prepare renv package cache 
mkdir -p /scratch/renv
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


sed -i '/^include.*/i NodeName=DEFAULT RealMemory=3928' /opt/slurm/etc/slurm.conf
sed -i '/^include.*/i SrunPortRange=59000-59999' /opt/slurm/etc/slurm.conf

systemctl restart slurmctld

grep slurm /etc/exports | sed 's/slurm/R/' | sudo tee -a /etc/exports 
grep slurm /etc/exports | sed 's/slurm/rstudio/' | sudo tee -a /etc/exports      
grep slurm /etc/exports | sed 's#/opt/slurm#/usr/lib/rstudio-server#' | sudo tee -a /etc/exports
grep slurm /etc/exports | sed 's#/opt/slurm#/scratch#' | sudo tee -a /etc/exports

exportfs -ar 

mount -a

rm -rf /etc/profile.d/modules.sh

groupadd --system --gid 10001 rstudio
useradd -s /bin/bash -m --system --gid rstudio --uid 10001 rstudio
echo -e "rstudio\nrstudio" | passwd rstudio

systemctl enable rstudio-launcher
systemctl start rstudio-launcher
systemctl enable rstudio-server 
systemctl start rstudio-server 
