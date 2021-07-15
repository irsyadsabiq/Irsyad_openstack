##############################################################################################################################
 ######################################## lab Deployment steps #################################################################
##############################################################################################################################
##1) edit networks interface
##2) change hostname of each OS
##3) disable selinux
##4) install dependencies (ansible, kolla-ansible pip)
##5) make directory /etc/kolla/
##6) copy /usr/share/kolla-ansible/etc_examples/kolla/* to /etc/kolla
##7) copy /usr/share/kolla-ansible/ansible/inventory/* to root
##8) edit globals.yml
##9) edit multinode/all-in-one file
##10) partlabel at ceph at each storage node
##11) kolla-bootstrap,prechecks
##12) install kolla-ansible with version based on targeted OpenStack version 
##13) deploy openstack
##14) Verify openstack operation

########################################################################################################################
########################################Error NOTES during openstack deployment######################################## 
########################################################################################################################
## If error there is an error on deployment of OpenStack, run this command to destroy before redeploying the build : kolla-ansible -i multinode destroy --yes-i-really-really-mean-it
## During OpenStack bootstrap or deploy, if error on HAproxy config, check for multinode format, each kolla-ansible version has different multinode and globals.yml 
## If mariadb failed : has the credentials. Exception message: (2002, \"Can't connect to MySQL server on '10.2.2.210'" )check the IP and hostname in /etc/hosts of the controller node
## Run command cinder service-list to check on the information volume function, if some of the cinder backend intermittently goes up and down after a minute, check the ntp and the time synchronization between servers, all servers must sync to the same timezone, must have equal time and date between servers.
## If OpenStack VIP disappear , run this command on controllers: docker restart haproxy keepalived  mariadb neutron_metadata_agent neutron_l3_agent neutron_dhcp_agent neutron_openvswitch_agent neutron_server horizon
## If ceph keyrings problem, run docker volume rm $(docker volume ls -f dangling=true -q) on all storage node
## If cannot find free port for nova ssh, add network interface for compute
## kolla ansible Creating haproxy mysql user error =  enable haproxy service
## run below command if oslo config error during deployment
pip install --upgrade 'oslo.utils<4.0.0'
pip install --upgrade 'oslo.config'

 ##run below command if mariadb failed to start ##
cd /var/lib/docker/volumes/mariadb/_data  ## if mariadb failed to start
mv grastate.dat grastate.dat.bak ## if mariadb failed to start

pip install --upgrade Jinja2 ## jinja error


## if error  on the python setup.py egg_info
pip install wheel
pip install --upgrade pip
pip install pip==6.0
pip install setuptools
pip install --upgrade decorator ##cannot import decorate error
pip install --upgrade urllib3 ##dependecy warning
########################################################################################################################
########################################################################################################################

########################################################################################################################
#################################### Deployment script start here ######################################################
########################################################################################################################

##Server network configuration: 
#vlan 810 DHCP, eno1.810
#vlan 820 manual, eno1.820

##Server storage partition: 
# /root 300 GB
# /swap 10 GB
# /boot 1 GB


cat >> /etc/hosts << EOF
## depends on the inventory: https://docs.google.com/spreadsheets/d/1zM8Ok0logeDMp_11uVj1mmxaqm0y6Fn0fS5mNyRp7Z8/edit?usp=sharing
10.20.20.2 controller
10.20.20.5 controller2
10.20.20.6 controller3
10.20.20.4 r-compute1
10.20.20.3 r-compute2
10.20.20.15 t-compute1
EOF

ssh-keygen
ssh-copy-id controller
ssh-copy-id controller2
ssh-copy-id controller3
ssh-copy-id r-compute1
ssh-copy-id r-compute2
ssh-copy-id t-compute1

##disable selinux
vi /etc/selinux/config
##change parameter as per below
SELLINUX=disabled
##reboot server after change SELLINUX
reboot
###
#### environment and dependencies setup ####
yum update -y
yum install epel-release -y
yum install python-pip -y
yum install wget ntp -y
systemctl start ntpd
timedatectl set-timezone Asia/Kuala_Lumpur
# pip install -U pip
yum install python-devel libffi-devel gcc openssl-devel libselinux-python -y
yum install ansible -y
rpm -e --nodeps PyYAML
rpm -e --nodeps python-idna
pip install ansible==2.8.4 
pip install kolla-ansible --ignore-installed PyYAML #run this command if there are docker version error during bootstrap servers
########################################################################################################################
########################################################################################################################

############ Optional ##################
pip install kolla-ansible==8.0.1 --ignore-installed PyYAML # this kolla-ansible version is for OpenStack stein development
pip install --upgrade pip ## optional
pip install -U ansible  ## Optional Works on stein, ansible will update to version 2.9.5
#########################################

########################################################################################################################
###################################################### CONTINUE HERE ###################################################
########################################################################################################################


#### -> Edit multinode file, refer multinode-rocky-2021
#### -> Edit globals.yml file, refer globals-rocky-2021.yml

########################################
#########Ceph configuration#############
########################################
### prepare part for ceph ##
#!/bin/bash
yum install -y gdisk
gdisk /dev/sda <<EOF ## for CentOS/OS boot
n

34
2047
ef02
w
y
partprobe
grub2-install /dev/sda
yum install -y fdisk
EOF
fdisk /dev/sda <<EOF ## to label disk as a reserve partition for ceph
n
3 

+10G
n
4


w
EOF
partprobe
lsblk

gdisk /dev/sda <<EOF ## to label disk as a reserve partition for ceph
c
3
KOLLA_CEPH_OSD_BOOTSTRAP_FOO_J
c
4
KOLLA_CEPH_OSD_BOOTSTRAP_FOO
w
y
partprobe
sleep 2
lsblk -o NAME,PARTLABEL
EOF
 
###################################################################################################
####################### Optional (automate ceph configuration)#####################################
###################################################################################################
ansible -i multinode storage -m copy -a "src=prepare_part_for_ceph.sh dest=/tmp/prepare_part_for_ceph.sh" ## run from controllers
ansible -i multinode storage -m shell -a "sh /tmp/prepare_part_for_ceph.sh"
ansible -i multinode storage -m shell -a "lsblk -o NAME,PARTLABEL|grep KOLLA"
###################################################################################################
###################################################################################################

###################################################################################################
############################### CONTINUE HERE AFTER CEPH CONFIG ###################################
###################################################################################################
kolla-ansible -i multinode bootstrap-servers

kolla-ansible -i multinode prechecks
pip install kolla-ansible==7.2.1 --ignore-installed PyYAML #run this before deploy
kolla-ansible -i multinode deploy

#First deployment if something wrong:
kolla-ansible -i multinode destroy --yes-i-really-really-mean-it

#if we have a working deployment, reconfigure:
kolla-ansible -i multinode reconfigure


#########################################################################################
################################## Post deploy ##########################################
#########################################################################################
#After deploy, install openstack CLI client
pip install python-openstackclient python-glanceclient python-neutronclient
kolla-ansible -i multinode post-deploy
source /etc/kolla/admin-openrc.sh
env|grep OS ## to check OpenStack UI password
cp /etc/kolla/admin-openrc.sh /root
cat > /root/admin-openrc.sh  <<EOF ## change below info as per build or result from env | grep OS command
#!/bin/bash
unset $(env |grep OS_|cut -d= -f1)
export OS_USERNAME=admin
export OS_PASSWORD=l8ZXm5DMkQ4BqbABh2gV50N0XEltPMuaB1kkx0Lx
export OS_AUTH_URL=http://10.20.30.10:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export PS1="\u@\h (${OS_PROJECT_NAME})$>"
export OS_TENANT_NAME=admin
export OS_REGION_NAME=RegionOne
export OS_AUTH_PLUGIN=password
EOF


pip install virtualenv==20.0.7 'zipp<2' ##virtualenv can cause error, solution is to uninstall first
virtualenv openstack
source admin-openrc.sh
source openstack/bin/activate


#######################################################################################################
################################## verify OpenStack operation ##########################################
#######################################################################################################

# create public private network and subnet
openstack network create --external --share --provider-network-type flat --provider-physical-network physnet1 admin-public
openstack subnet create --network admin-public --dns-nameserver 8.8.8.8 --subnet-range 10.20.30.0/24 --gateway=10.20.30.1 --no-dhcp floatingip_subnet

# create private network and subnet
openstack network create admin-private
openstack subnet create --network admin-private --dns-nameserver 8.8.8.8 --subnet-range 192.168.220.0/24 admin-private-subnet


#image download
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
openstack image create --file cirros-0.4.0-x86_64-disk.img --public --container-format bare --disk-format qcow2 cirros
openstack image create --file CentOS-7-x86_64-GenericCloud-1804_02.qcow2 --public --container-format bare --disk-format qcow2 Centos-7

#If vm not supported (VM ware) error
vi /etc/kolla/nova-compute/nova.conf
    virt_type = qemu
docker ps | grep nova
docker restart nova_compute

#########################################################################################
### copy paste to configuration during instance creation for a password authorization ###
#########################################################################################
#cloud-config
password: Id*dgsb#
chpasswd: { expire: False }
ssh_pwauth: True


##accee OpenStack database
docker exec -it mariadb mysql -u haproxy -p
docker exec -it mariadb mysql -u root -p
8f5U7wMF089NFXEajkZnueWGMXz5pvNIeuVUs0Al
select host from mysql.user where User = 'root'; ## verify


## solve ceph rgw issue, every docker service can be bash
for i in .rgw.root default.rgw.control default.rgw.meta default.rgw.log cephfs_data cephfs_metadata images volumes backups vms default.rgw.buckets.index default.rgw.buckets.data scbench; do ceph osd pool set $i size 1; done
docker exec -it neutron_server bash
docker exec -it ceph_mgr bash
docker exec -it ceph_mds bash
docker exec -it ceph_rgw bash
docker exec -it ceph_osd_0 bash


## automate restart service at every host sample
ansible -i multinode controller,controller2,controller3 -m shell -a "docker restart ceph_rgw ceph_mgr ceph_mon ceph_mds"
ansible -i multinode storage -m shell -a "docker restart ceph_osd_0"


