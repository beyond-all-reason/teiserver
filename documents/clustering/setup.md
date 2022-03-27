## OS install
I'm using Debian 11 from deabian.org. Specifically `debian-11.2.0-amd64-netinst.iso`

I give them 4 processors and 8192MB of RAM but you should be able to test the setup on 1 processor and 1 GB of RAM. More just means things will run faster.

hostname: barcluster{1..4}
domain: barlocal
username: deploy

#### Passwords
On the basis this is for local use only and designed with ease over security I have used a password of "123456" for my deploy users and configured the system to echo that password to them for sudo. In production this would of course be completely unacceptable but you also won't need to re-run these scripts all the time.

#### Quick note on IPs
I've saved everything with the IPs my setup came with, you will need to substitute the IPs of your VMs into all the steps. For reference the IP addresses I have are:

barcluster1 = 192.168.1.185
barcluster2 = 192.168.1.220
barcluster3 = 192.168.1.235
barcluster4 = 192.168.1.209

## SSH Setup
After installing I had to run `ip a` to find the ip address of the host. I also had to install openssh via the following:

```
su root
apt install openssh-server
sudo usermod -aG sudo deploy
```

You can now run [documents/clustering/scripts/ssh_setup.sh](scripts/ssh_setup.sh)

At this stage you should be able ssh into the boxes using `ssh deploy@ip_address` and not require a password.

## Software install
Next we need to install some of the software required to run Teiserver.

You can do this by running [documents/clustering/scripts/install.sh](scripts/install.sh)
