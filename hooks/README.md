# Folder for domain-specific scripts

Place your domain ssl-update hook scripts here.
Only scripts named as `<domain name>.sh` will be called.

For example, if the NPM issues certificate for the `example.com`,
the script shall be named `example.com.sh`.

NOTES:

- In order to be run, the script shall have exec attribute.
- The script is called with the following arguments:
  - $1 - Name of the domain
  - $2 - Path to the actual `fullchain.pem` file (not the symlink)
  - $3 - Path to the actual `privkey.pem` file (not the symlink)
