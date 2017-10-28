# Sentry on Docker

This collection of shell scripts will attempt to install [Sentry](https://sentry.io/welcome/) on [Docker](https://www.docker.com/) on a [CentOS](https://www.centos.org/), [Ubuntu](https://www.ubuntu.com/) or [Debian](https://www.debian.org/) machine (VM or bare metal).

The main script, `docker-sentry` will install `etcd`, `sentry` and `nginx` reverse proxy with SSL support. The SSL certificates will be generated using the help of  https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion



Please keep in mind that in order to use SSL, you will need a fully qualified domain name (FQDN) for your host, otherwise SSL certificate generation will fail. You can run sentry on port 80 but that's entirely not recommended.

The `sentry-exec` script will take care of "administrative tasks", such as stopping, starting, upgrading sentry components after installation. Please have a look at the help section for detailed info.

If this gets deployed on AWS EC2, use a machine with at least 2 GB of RAM. Same amount of RAM applies for bare metal

There are environment variables in the main script which need to be changed and set into etcd, according to your setup.

```
POSTGRES_PASSWORD supersecret
SENTRY_SINGLE_ORGANIZATION False
SENTRY_SERVER_EMAIL sentry@example.com
SENTRY_EMAIL_HOST smtp.example.com
SENTRY_EMAIL_PASSWORD super-secret
SENTRY_EMAIL_USER mailuser
SENTRY_EMAIL_PORT 587
SENTRY_EMAIL_USE_TLS True
VIRTUAL_HOST sentry.example.com
LETSENCRYPT_HOST sentry.example.com
LETSENCRYPT_EMAIL example@example.com
```

Please refer to https://hub.docker.com/_/sentry/ and https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion for more information

### Setup

#### Prerequisites:

1. Kernel 4.x for overlay2 storage driver
2. Docker

##### Kernel Installation:

- log on to your machine

```
# CentOS users
$ sudo yum -y install git
$ cd $HOME; git clone https://github.com/ssro/docker-sentry.git && git clone https://github.com/ssro/scripts.git
$ $HOME/scripts/centos-elrepo.sh
```
```
# Debian/Ubuntu users - kernel is at version 4 for Debian 9 or Ubuntu 16.04
# We just need to install git and clone repos
$ sudo apt-get -y update && sudo apt-get -y install git
$ cd $HOME; git clone https://github.com/ssro/docker-sentry.git && git clone https://github.com/ssro/scripts.git
```

- OS tuning (optional but recommended)

```
# CentOS & Debian/Ubuntu users
$ sudo bash -c "cat <<EOF > /etc/rc.local
#!/bin/bash

echo never > /sys/kernel/mm/transparent_hugepage/enabled
EOF"
$ sudo chmod +x /etc/rc.local

$ sudo bash -c "cat <<EOF > /etc/sysctl.d/user-tuning.conf
vm.overcommit_memory=1
net.core.somaxconn=65535
vm.swappiness=10
vm.vfs_cache_pressure=50
net.ipv4.tcp_congestion_control=htcp
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_slow_start_after_idle=0
EOF"
```

- reboot your machine

`$ sudo reboot`

#### Docker installation:

- log on to your machine and install docker:

`$ $HOME/scripts/docker-install.sh`

- enable overlay2 storage driver for docker (only for CentOS. Debian/Ubuntu setup is handled by the above script)

```
$ sudo mkdir /etc/docker
$ sudo bash -c 'cat <<EOF > /etc/docker/daemon.json
{
 "storage-driver": "overlay2",
 "storage-opts": [
   "overlay2.override_kernel_check=true"
  ]
}
EOF'
$ sudo systemctl start docker
```

- logout and re-login to your machine

#### Run the docker-sentry script

`$ $HOME/docker-sentry/docker-sentry`

This should take care of installing sentry along with nginx and SSL support.

Your new sentry installation will be available at https://your_host_name/

> NOTE In case your machine is not available, please give it time. `nginx-letsencrypt` container will generate
DH parameters and the SSL certificate, which can take some minutes, depending on how fast your machine's CPU is.
To be sure all is well, please check the logs of the container. On a succesful install,
the log should be similar to this:
```
$ docker logs nginx-letsencrypt
Creating Diffie-Hellman group (can take several minutes...)
Generating DH parameters, 2048 bit long safe prime, generator 2
This is going to take a long time
.....................................................................................................................................................................................................................................+.......+............................................................................+.......................................................................................................................+......................................................................................................................................................................................................................................+.+...............................................................................................................................................................................................................................................................................................................................................................................................................................................................................+.......+.............................+................+..................................................................................................................................................................................................................................................................................................................................................................................................+..............................................+.................................................................+...........................................................................+............................................................................................+...................................................................................................+......................................................+.......................................................................+.......+..............................................++*++*
Sleep for 3600s
2017/09/25 07:24:47 Generated '/app/letsencrypt_service_data' from 6 containers
2017/09/25 07:24:47 Running '/app/update_certs'
2017/09/25 07:24:47 Watching docker events
2017/09/25 07:24:47 Contents of /app/letsencrypt_service_data did not change. Skipping notification '/app/update_certs'
Reloading nginx docker-gen (using separate container e1c8dd1fae2fe975739dea57dc7a386a8b4e3470514b4e6a78fc00dbf32c1d24)...
Reloading nginx (using separate container 40b22338b9e3aa2c39a8b46d27ea784e38f7018803644c442e45d0966528e737)...
Creating/renewal sentry.example.com certificates... (sentry.example.com)
2017-09-25 07:24:47,547:INFO:simp_le:1213: Generating new account key
2017-09-25 07:24:50,313:INFO:simp_le:1306: sentry.example.com was successfully self-verified
2017-09-25 07:24:50,422:INFO:simp_le:1314: Generating new certificate private key
2017-09-25 07:24:52,211:INFO:simp_le:393: Saving account_key.json
2017-09-25 07:24:52,212:INFO:simp_le:393: Saving key.pem
2017-09-25 07:24:52,212:INFO:simp_le:393: Saving chain.pem
2017-09-25 07:24:52,212:INFO:simp_le:393: Saving fullchain.pem
2017-09-25 07:24:52,212:INFO:simp_le:393: Saving cert.pem
Reloading nginx docker-gen (using separate container e1c8dd1fae2fe975739dea57dc7a386a8b4e3470514b4e6a78fc00dbf32c1d24)...
Reloading nginx (using separate container 40b22338b9e3aa2c39a8b46d27ea784e38f7018803644c442e45d0966528e737)...
Sleep for 3600s
```

### Backing up the database
`$ ./sentry-exec backup`

The sql file will be written to the container's folder `/var/lib/postgresql/data/pgdata/`
and to the host's folder defined in the env variable `/sentry/PG_DIR`

### Restoring a database

Restoring a database from a backup (for example from another sentry install):
1. Get the secret key from the other sentry install and add it to etcd `/sentry/SENTRY_SECRET_KEY`;
2. Create a sql backup of the database (from the other sentry installation);
3. Start your postgresql container then stop it (this will create the `${WORKDIR}/sentry/postgres` directory) and copy the backed up sql file there (i.e. `$ sudo cp backed-up-sentry.sql ${WORKDIR}/sentry/postgres/`);
4. Do not run `$ etcdctl set /sentry/SENTRY_SECRET_KEY $(docker run --rm sentry config generate-secret-key)`
since we already have it;
5. Start your postgresql container and then run below command
`$ docker exec -it postgres bash -c 'psql -U sentry sentry < /var/lib/postgresql/data/pgdata/backed-up-sentry.sql'`
Wait for it to finish;
6. Proceed upgrading the database with `$ ./sentry_exec upgrade`

### Removing old entries from the database

`$ ./sentry-exec cleanup`

This will clean all entries from all projects older than 60 days. This can be adjusted in the `sentry_exec` script.
Also it's possible to trim down entries based on projects https://docs.sentry.io/server/cli/cleanup/
