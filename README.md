# Install Docker on Oracle Linux 7 (using a BTRFS file system)

## System information
* Installed as a VM on **VirtualBox**
* `/etc/oracle-release`: **Oracle Linux Server release 7.4**  
* `/etc/redhat-release`: *Red Hat Enterprise Linux Server release 7.4 (Maipo)*
* `$ uname -a`: **Linux ramingo 4.1.12-94.5.9.el7uek.x86_64 #2 SMP Tue Aug 15 13:56:37 PDT 2017 x86_64 x86_64 x86_64 GNU/Linux**

## SELinux
Easier if **Secure Linux** (SELinux) is disabled or switched to permissive  

```shell
$ sudo grep '^SELINUX=' /etc/selinux/config
SELINUX=permessive
```
and then **reboot** the machine.

## Firewall  
Easier if the **firewall** is disabled

```shell
$ sudo systemctl stop firewalld
$ sudo systemctl disable firewalld
Removed symlink /etc/systemd/system/multi-user.target.wants/firewalld.service.
Removed symlink /etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service.
```

## Enabled package repositories
Check if `ol7_addons` and `ol7_optional_latest` package repositories are enabled

```shell
$ yum repolist enabled|grep ol7_addons
ol7_addons/x86_64          Oracle Linux 7Server Add ons (x86_64)             240
$ yum repolist enabled|grep ol7_optional_latest
ol7_optional_latest/x86_64 Oracle Linux 7Server Optional Latest (x86_64)  16,198
```

Otherwise edit `/etc/yum.repos.d/public-yum-ol7.repo` and set `enabled=1` for the mentioned repositories

## Install docker and btrfs packages
Check if docker and btrfs are installed

```shell
$ yum list installed docker-engine btrfs-progs btrfs-progs-devel
Loaded plugins: langpacks, ulninfo
Installed Packages
btrfs-progs.x86_64              4.9.1-1.0.2.el7             @anaconda/7.4       
btrfs-progs-devel.x86_64        4.9.1-1.0.2.el7             @ol7_optional_latest
docker-engine.x86_64            17.03.1.ce-3.0.1.el7        @ol7_addons         
```

Otherwise install them with

```shell
$ sudo yum install docker-engine btrfs-progs btrfs-progs-devel -y
```  

## Create a btrfs file system for docker images
Create a virtual disk with VirtualBox and attach it to the VM. In my case the device name is `/dev/sdb`. Create a single partition using `# fdisk /dev/sdb`. Make the btrfs file system on the partition `sdb1`.

```shell
$ sudo mkfs.btrfs -f -L docker1 /dev/sdb1
```

Replace the `/var/lib/docker` directory with a mount point to the new filesystem (stopping the docker service before).

```shell
$ sudo systemctl stop docker.service
$ sudo rm -Rf /var/lib/docker
$ sudo mkdir /var/lib/docker
$ sudo echo "LABEL=docker1  /var/lib/docker btrfs defaults 0 0" >> /etc/fstab
$ sudo mount /var/lib/docker
```
Edit configuration file `/etc/sysconfig/docker`

```shell
$ grep OPTIONS /etc/sysconfig/docker
#OPTIONS='--selinux-enabled'
OPTIONS='-s btrfs'
```

Enable and start th docker service

```shell
$ sudo  systemctl enable docker.service
$ sudo systemctl start docker.service
```

## Docker configuration

### Manage docker as a non-root user

Check or create a `docker` group

```shell
$ sudo groupadd docker
```

Check or add the user to the `docker` group

```shell
$ sudo usermode -aG docker arnabold
```

and then relogin the user and restart the docker service.

Verify if you can manage docker with a non-root user

```shell
$ docker run --rm hello-world
```

### Check kernel compatibility

```shell
$ curl https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh > check-config.sh
$ bash ./check-config.sh
```

### Check docker daemon host

```shell
$ echo $DOCKER_HOST
```

### Check ip forwarding (systemd)
TODO

```shell
$ sudo sysctl -a --pattern '\.forwarding$
```

### Specify DNS servers for docker

Include at least one DNS server which can resolve public IP adresses in `/etc/docker/daemon.json`.

```shell
$  sudo cat /etc/docker/daemon.json
{
	"dns": ["192.135.82.44", "8.8.8.8", "8.8.4.4"]
}
```

Restart the docker daemon.

Verify that the docker container resolves internal hostnames

```shell
$ docker run --rm -it alpine ping -c4 www-proxy.uk.oracle.com
PING www-proxy.uk.oracle.com (10.254.203.53): 56 data bytes
64 bytes from 10.254.203.53: seq=0 ttl=251 time=35.566 ms
64 bytes from 10.254.203.53: seq=1 ttl=251 time=37.841 ms
64 bytes from 10.254.203.53: seq=2 ttl=251 time=34.406 ms
64 bytes from 10.254.203.53: seq=3 ttl=251 time=34.901 ms

--- www-proxy.uk.oracle.com ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max = 34.406/35.678/37.841 ms
```

### Kernel support cgroup swap limit capabilities
Edit `/etc/default/grub` adding `cgroup_enable=memory swapaccount=1` to `GRUB_CMDLINE_LINUX`. After that update GRUB with

```shell
$ sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

and reboot the system.

### Docker configuration files:

```shell
/etc/systemd/system/docker.service.d/*.conf
/etc/default/docker
/etc/sysconfig/docker
/etc/docker/daemon.json
```


 sudo cat /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://www-proxy.uk.oracle.com:80/"
Environment="HTTPS_PROXY=http://www-proxy.uk.oracle.com:80/"
Environment="NO_PROXY=localhost,127.0.0.0/8,docker-registry.somecorporation.com"
