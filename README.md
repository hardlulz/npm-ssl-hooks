# npm-ssl-hooks

## Description

Script to run custom actions whenever the docker-based NPM updates 
its letsencrypt ssl certificates.

This script looks for changes to SSL certificates managed
by the Nginx Proxy Manager and runs an action script each time
the certificate is updated.

You can use it either by manually calling it, or by setting up
a cron task.

This script expects that all action scripts are located in the
folder specified by the HOOKS_DIR. Each action script shall be
named as the `<domain name>.sh`. If there is no action script
for a domain, such domain is ignored.

For example, if the HOOKS_DIR is `/var/npm-hooks` and NPM asks
for letsencrypt certificate for the `my.mail.example.com` domain,
then the expected action script is `/var/npm-hooks/my.mail.example.com.sh`.

Also, each time the script calls the action script for a domain,
it touches the file '/var/npm-hooks/.my.mail.example.com.status'.

## Prerequisites

This script uses the following tools:

- **sqlite3** - to get id/name mapping from the NPM database
- **readlink** - to get actual certificate file names


## Usage

Clone the repo somewhere

```sh
cd /srv
git clone https://github.com/hardlulz/npm-ssl-hooks.git && cd ./npm-ssl-hooks
```

Edit monitor-npm-certs.conf and set `NPM_DATABASE` and `NPM_CERT_LIVE`
variables to reflect your server configuration.

Optionally, you may set a `HOOKS_DIR` with custom folder for your hook scripts
(by default, the script uses the `hooks` directory in the same folder with the script).

Create action scripts in the hooks folder.

Example for the `my.example.com` domain:

```sh
echo "#! /bin/sh
# ssl-update hook for the my.example.com domain
echo \"my.example.com\" certificate had been updated.
" > ./hooks/my.example.com.sh


# or something like this:
echo "#! /bin/sh
docker compose restart postfix
docker compose restart dovecot
" > ./hooks/my.example.com.sh

```

Fix permissions (running as root or other user that has access to certificate files)

```sh
chown root:root ./monitor-npm-certs.sh ./monitor-npm-certs.conf
chown root:root ./hooks/*.sh
chmod u=rwx,g=r,o=r ./monitor-npm-certs.sh
chmod u=rw,g=r,o=r ./monitor-npm-certs.conf
chmod u=rwx,g=r,o=r ./hooks/*.sh
```

Set up a cron job (running as root or other user that has access to certificate files)

```sh
crontab -e

# and add something like this to the file
0 1 * * * /srv/npm-ssl-hooks/monitor-npm-certs.sh

```
