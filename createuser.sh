#!/bin/bash

_user="jdoe"
_script="$(pwd)/$(basename $0)";
_release=`rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release)`  # ex: 6 or 7
_distro=`more /etc/redhat-release | tr '[A-Z]' '[a-z]' | cut -d' ' -f1`  # ex: centos
_os_ver_arch="${_distro}-${_release}"
_dns1="8.8.8.8"

# For self delete of the script.
# Note if the script is in /root/bin/setup01.sh and you execute it from a different directory (ex: /root/), self delete will not work.
function rmScript(){
  rm -f /${_script};
}


function func_skel_vim(){
# _vim_skel_test=`grep set /etc/skel/.vimrc | wc -l`
  _vim_skel_test=`grep set /etc/skel/.vimrc 2> /dev/null | wc -l`

  if [ $_vim_skel_test -eq 4 ]; then
    echo -e "\n# /etc/skel/.vimrc already has required settings." | tee -a /${_logger}
  else
cat >>/etc/skel/.vimrc <<EOL
filetype plugin indent on
" show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

set paste
EOL
    echo -e "/vim/skel/.vimrc updated." | tee -a /${_logger}
  fi
}


function func_root_vim(){
#  _root_vimrc_test=`grep set /root/.vimrc | wc -l`
  _root_vimrc_test=`grep set /root/.vimrc 2> /dev/null | wc -l`
  if [ $_root_vimrc_test -eq 4 ]; then
    echo -e "\n# /root/.vimrc already has required settings." | tee -a /${_logger}
  else
cat >>/root/.vimrc <<EOL
filetype plugin indent on
" show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

set paste
EOL
    echo -e "/root/.vimrc updated." | tee -a /${_logger}
  fi
}


function func_dns(){
cat >>/etc/resolv.conf <<EOL
nameserver ${_dns1}
EOL
}

# Saves log of this script
function func_log(){
  _today=`date +"%F-%Z"`
  _log_dir="root/logs"
  _logger="${_log_dir}/${_today}.log"   # name of this script

  mkdir /${_log_dir} 2> /dev/null
  echo "#######################" | tee -a /${_logger}
  date -u +"%F--%H-%M-%Z" >> /${_logger}
}



function func_utc(){
  # Variables for verifying OS and version.
  rm /var/cache/yum/timedhosts.txt 2> /dev/null
  yum clean all
  yum --disableplugin=fastestmirror -y install ntp
#  sleep 2  # needed for ntpd service to start
  rm -f /etc/localtime
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime

  rm -f /etc/sysconfig/clock
cat <<EOM >/etc/sysconfig/clock
UTC=true
EOM

  echo -e "\n`date +%Y-%m-%d--%H-%M-%S-%Z` Server set to use UTC time." | tee -a /${_logger}
  if [[ ${_os_ver_arch} == *"centos-6"* ]]; then
    service ntpd restart
    chkconfig ntpd on
    echo -e "ntpd service started" | tee -a /${_logger}
  elif [[ ${_os_ver_arch} == *"centos-7"* ]]; then     # must be centos_
    systemctl restart ntpd
    systemctl enable ntpd
    echo -e "ntpd service started" | tee -a /${_logger}
  fi
}


function func_prompt(){
cat >/etc/profile.d/custom-prompt.sh <<EOL
if [ "\$PS1" ]; then
PS1="\n[\u@\h  `hostname`  \W]\\\\$ "
fi
EOL


echo "export PS1='\n\[\e[1;32m\][\u@\h  `hostname`  \W]$\[\e[0m\] '" >> /root/.bashrc
}


# This function is called in func_rpms, only on CentOS 6.
function func_epel(){
  wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
  rpm -Uvh epel-release-*6*.rpm
}



function func_rpms(){
  if [[ ${_os_ver_arch} == *"centos-6"* ]]; then
    func_epel
    yum -y install vim curl wget man screen bind-utils rsync && echo -e "rpms installed"  >> /${_logger}
  elif [[ ${_os_ver_arch} == *"centos-7"* ]]; then
    yum -y install epel-release vim curl wget man screen bind-utils rsync tmux && echo -e "rpms installed"  >> /${_logger}
  fi
}

# This function should be called whenever a user (ex: ansible) needs sudo privilege.
# This is idempotent.
function func_sudoers(){
  _wheel_test=`grep '^%wheel' /etc/sudoers | grep NOPASSWD | wc -l`
  if [ $_wheel_test -ge 1 ]; then
    echo -e '\n# %wheel group already has sudo privilege.' | tee -a /${_logger}
  else
    echo "Updating /etc/sudoers" | tee -a /${_logger}
    sed -i '/NOPASSWD/a %wheel\      ALL=(ALL)\      NOPASSWD:\ ALL' /etc/sudoers && echo "Granted to wheel group sudo root privilege."
  fi
}


# allow sudo access
function func_adduser(){
  useradd ${_user} 2> /dev/null
  usermod -a -G wheel ${_user} 2> /dev/null
  mkdir /home/${_user}/.ssh 2> /dev/null
  touch /home/${_user}/.ssh/authorized_keys 2> /dev/null
  #passwd $_user

  if grep --quiet '^ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQfYTUuey' /home/${_user}/.ssh/authorized_keys; then
    echo -e "\n# SSH key for $_user is already in /home/${_user}/.ssh/authorized_keys.\n" | tee -a /${_logger}
  else
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQfYTUueyxGlFb8qT+XNZq0JqKHNwfNZVDzVurb7+J8DihosWqSOWgCcU4hDYMg8EOsTHM/nzn0P6h5WVP2oM9VsZ2LEa6m/R+xbU0Aiyoab/0Qhf6RzkPUxpOeV55ovIKGyGilAHr4hhhZuVlPdyLNwNMgbDyZFL1nxflWQEAiJhUQJJvoAu1wzI5H1Rg5VnM5Xwa67DddGN7rPD4WpB6hGyARm4wuVgLR2GOM3kn90KFiE3AVarJQ8szvkTJlXsZhBpae7uKmA/UqxVFKewb8v4xZkXONjShI4DtYiTtLtqZJ/tZRsqnmBxKnbkqqFGJmPixTJIu6/FCzBes3asN paul@PCs-MacBook-Pro.local" >> /home/${_user}/.ssh/authorized_keys && echo -e "Added ${_user} and gave sudo privilege." | tee -a /${_logger}
  fi

  chmod 755 /home/${_user}/.ssh
  chmod 644 /home/${_user}/.ssh/authorized_keys
  chown -R ${_user}: /home/${_user}/.ssh
}


# Disable selinux
function func_selinux_off(){
  sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config && echo -e "SELinux turned off." | tee -a /${_logger}
}


# Sets up ansible user, ssh key, install rpm
function func_ansible() {
  _user_ansible="ansible"
  yum install -y ansible
  useradd ${_user_ansible} 2> /dev/null
  # passwd ${_user_ansible}
  usermod -aG wheel ${_user_ansible} 2> /dev/null
  mkdir /home/${_user_ansible}/.ssh 2> /dev/null
  touch /home/${_user_ansible}/.ssh/authorized_keys 2> /dev/null

  # Latest ansible_mac.pub is here:
  #  http://paulchu.xyz/scripts/sshkeys/ansible_mac.pub


  if grep --quiet '^ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFc' /home/${_user_ansible}/.ssh/authorized_keys; then
    echo -e "\n# public key for ${_user_ansible} is already in /home/${_user_ansible}/.ssh/authorized_keys." | tee -a /${_logger}
  else
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFcFcKOi8yNuE05UJbe32UnXL0SMdthHlbhGrH+gAqH2D+2SgrBj0ynOg+oMIIiJntjSju84tTOYPs/snh8O3qYzXEB4ET8qupf7azyjhzJIR9PhO8W78r0rzhFBWyrhdQ4UpaHVElCth9LMS1YSVnc4zw2jSbuW1ZEENYLU4ieARuqVU+sdH//WfZyUGKu6bWATpGMqKs/3teJP7+S+4gcpjDQtbX7m4oEM6gr0VkModUuRp4KSJuT/okxQuTt2z4/U+yygM/F91sV38Z87L6RkYL9Zzzt4qR0kXVCAO3YfuOPkncfsvURkZdP6mTICX11Vc49zrDfRQx91iLDQRf paul@Mac-542696cebd0b" >> /home/${_user_ansible}/.ssh/authorized_keys && echo -e "Ansible client installed." | tee -a /${_logger}
  fi

  chmod 755 /home/${_user_ansible}
  chmod 644 /home/${_user_ansible}/.ssh/authorized_keys
  chown -R ${_user_ansible}: /home/${_user_ansible}/.ssh
}


# Create group backupadmin for handling backups, add users pchu and ansible to the group
function func_backupadmin(){
  _groupname="backupadmin"
  groupadd ${_groupname} 2> /dev/null
  usermod -aG ${_groupname} pchu 2> /dev/null
  usermod -aG ${_groupname} ansible 2> /dev/null
}

# Up eth1
function func_ifup(){
  ifup eth1
}


# Stop and disable NetworkManager service on CentOS 7
function func_network_manager(){
if [[ ${_os_ver_arch} == *"centos-7"* ]]; then
  systemctl stop NetworkManager
  systemctl disable NetworkManager
  echo -e "NetworkManager service on CentOS 7 stopped and disabled." | tee -a /${_logger}
fi
}


# Edit motd
function func_motd(){
  if grep --quiet '^Installed' /etc/motd; then
    echo -e "\n# Not updating /etc/motd now as it already has content.\n# You can always update it manually later.\\n" | tee -a /${_logger}
  else
    echo -e "\nSetting up MOTD. \n" | tee -a /${_logger}
    echo "==========" >> /etc/motd
    echo "Installed `date +"%F"`" >> /etc/motd
    echo "`hostname -f`" >> /etc/motd
    echo "==========" >> /etc/motd
    echo -e "/etc/motd updated." | tee -a /${_logger}
  fi
}


function func_firewall(){
  if [[ ${_os_ver_arch} == *"centos-6"* ]]; then
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
    iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
    iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P INPUT DROP
    iptables-save | tee /etc/sysconfig/iptables
    service iptables restart
    echo -e "Firewall updated and running" | tee -a /${_logger}
  elif [[ ${_os_ver_arch} == *"centos-7"* ]]; then     # must be centos_
    # echo -e "Still needs firewalld updated" | tee -a /${_logger}
    yum install -y firewalld
    systemctl start firewalld
    systemctl enable firewalld
    firewall-cmd --zone=public --list-services --permanent
    firewall-cmd --zone=public --permanent  --add-service=https
    firewall-cmd --zone=public --permanent  --add-service=http
    firewall-cmd --reload
    firewall-cmd --list-all  | tee -a /${_logger}
  fi

}


trap rmScript SIGINT SIGTERM

#func_dns
func_log
func_skel_vim
func_root_vim
#func_utc
#func_prompt
#func_rpms
func_adduser
func_sudoers
#func_selinux_off
#func_ansible
#func_backupadmin
#func_ifup
#func_network_manager
#func_motd
#func_firewall
rmScript # This allows self delete of the script AND reboot at the same time.
#rmScript; bash -c 'sleep 3 && reboot'  # This allows self delete of the script AND reboot at the same time.
