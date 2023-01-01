#!/bin/bash

set -ex

# just in case services running 
systemctl stop rstudio-launcher
systemctl stop rstudio-server

myip=`curl http://checkip.amazonaws.com`
cat > /etc/rstudio/rserver.conf << EOF
# Launcher Config
launcher-address=127.0.0.1
launcher-port=5559
launcher-sessions-enabled=1
launcher-default-cluster=Local
launcher-sessions-callback-address=http://${myip}:8787
audit-r-sessions=1
audit-r-sessions-format=json
audit-r-sessions-limit-mb=0
audit-data-path=/audit-data

server-health-check-enabled=1

admin-enabled=1
admin-group=rstudio-admins
admin-superuser-group=rstudio-superuser-admins

EOF

cat > /etc/rstudio/launcher.conf<<EOF
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

cat > /etc/rstudio/launcher.slurm.profiles.conf<<EOF 
[*]
default-cpus=1
default-mem-mb=1024
max-cpus=4
max-mem-mb=8096
EOF

cat > /etc/rstudio/launcher.slurm.conf << EOF 
# Enable debugging
enable-debug-logging=1

# Basic configuration
slurm-service-user=slurm
slurm-bin-path=/opt/slurm/bin

# Singularity specifics
#constraints=Container=singularity-container

EOF


sed -i '/^include.*/i NodeName=DEFAULT RealMemory=3928' /opt/slurm/etc/slurm.conf
sed -i '/^include.*/i SrunPortRange=59000-59999' /opt/slurm/etc/slurm.conf

systemctl restart slurmctld

# grep slurm /etc/exports | sed 's/slurm/R/' | sudo tee -a /etc/exports 
# grep slurm /etc/exports | sed 's/slurm/rstudio/' | sudo tee -a /etc/exports      
# grep slurm /etc/exports | sed 's#/opt/slurm#/usr/lib/rstudio-server#' | sudo tee -a /etc/exports
# grep slurm /etc/exports | sed 's#/opt/slurm#/scratch#' | sudo tee -a /etc/exports

# exportfs -ar 

# mount -a

rm -rf /etc/profile.d/modules.sh

groupadd --system --gid 10001 rstudio
useradd -s /bin/bash -m --system --gid rstudio --uid 10001 rstudio

# use this hack to set me up as a user
username=dpastoor
apt-get install -y ec2-instance-connect
useradd --create-home --shell /bin/bash --user-group ${username} 
usermod -aG sudo ${username}
su ${username} -c "mkdir -p /home/${username}/.ssh && chmod 0700 /home/${username}/.ssh"
su ${username} -c "curl -o /home/${username}/.ssh/authorized_keys https://github.com/${username}.keys"
su ${username} -c "chmod 0600 /home/${username}/.ssh/authorized_keys"
echo "# Created by userdata\n ${username} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/999-${username}"
chmod 0440 "/etc/sudoers.d/999-${username}"

systemctl enable rstudio-launcher
systemctl start rstudio-launcher
systemctl enable rstudio-server 
systemctl start rstudio-server 
