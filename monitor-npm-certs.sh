#! /bin/sh
# This script looks for changes to SSL certificates managed
# by the Nginx Proxy Manager and runs an action script each time
# the certificate is updated.
#
# You can use it either by manually calling it, or by setting up
# a cron task.
#
# This script expects that all action scripts are located in the
# folder specified by the HOOKS_DIR. Each action script shall be
# named as the '<domain name>.sh'. If there is no action script
# for a domain, such domain is ignored.
#
# For example, if the HOOKS_DIR is '/var/npm-hooks' and NPM asks 
# for letsencrypt certificate for the 'my.mail.example.com' domain, 
# then the expected action script is '/var/npm-hooks/my.mail.example.com.sh'.
#
# Also, each time the script calls the action script for a domain,
# it touches the file '/var/npm-hooks/.my.mail.example.com.status'.
#
# PREREQUISITES:
# This script uses the following tools:
#   sqlite3      - to get id/name mapping from the NPM database
#   readlink     - to get actual certificate file names

SCRIPT_DIR=$(readlink -f -- "$0")
SCRIPT_DIR=$(dirname -- "${SCRIPT_DIR}")

source ${SCRIPT_DIR}/monitor-npm-certs.conf

# Request all currently present certificates from the NPM's database
# The CERT_DOMAINS will contain a multiline string, something like this:
#
# 1|webmail.example.com
# 2|www.example.com
# 5|www.example.net
CERT_DOMAINS=$($SQLITE $NPM_DATABASE "SELECT id, nice_name FROM certificate WHERE is_deleted=0 AND provider='letsencrypt';")


if [ "$1" = "--force" ]; then
	echo "Got --force argument. Clearing all .status files..."
	rm -f ${HOOKS_DIR}/.*.status
fi

for domain in $CERT_DOMAINS
do
	# Extract ID and NAME fields
	DOMAIN_ID=${domain%%|*}
	DOMAIN_NAME=${domain#*|}
	# and deduce file names.
	DOMAIN_CERT_DIR=${NPM_CERT_LIVE}/npm-${DOMAIN_ID}
	DOMAIN_PK=${DOMAIN_CERT_DIR}/privkey.pem
	DOMAIN_PK_PHYSPATH=$(readlink -f ${DOMAIN_PK})
	DOMAIN_FULLCHAIN=${DOMAIN_CERT_DIR}/fullchain.pem
	DOMAIN_FULLCHAIN_PHYSPATH=$(readlink -f ${DOMAIN_FULLCHAIN})
	DOMAIN_HOOK_ACTION=${HOOKS_DIR}/${DOMAIN_NAME}.sh
	DOMAIN_HOOK_STATUS=${HOOKS_DIR}/.${DOMAIN_NAME}.status
	DOMAIN_STATUS="OK"
	echo
	echo "${DOMAIN_NAME}:"

	echo "  Hook action file: \"${DOMAIN_HOOK_ACTION}\""
	if [ -x "${DOMAIN_HOOK_ACTION}" ]; then
		echo "    Status:      Present"
	else
		echo "    Status:      File is missing or not an executable. Domain skipped"
		continue
	fi


	echo "  Hook status file: \"${DOMAIN_HOOK_STATUS}\""
	if [ -f "${DOMAIN_HOOK_STATUS}" ]; then
		if [ -w "${DOMAIN_HOOK_STATUS}" ]; then
			MOD=$(stat -c %y "${DOMAIN_HOOK_STATUS}")
			echo "    Timestamp:   ${MOD}"
		else
			echo "    Status:      Status file not writable. Domain skipped."
			continue;
		fi
	else
		echo "    Status file not present, hook will be executed to create it"
		DOMAIN_STATUS="FORCE"
	fi


	echo "  Private Key: ${DOMAIN_PK}"
	echo "    Actual path: ${DOMAIN_PK_PHYSPATH}"
	if [ ! -z "${DOMAIN_PK_PHYSPATH}" ] && [ -f "${DOMAIN_PK_PHYSPATH}" ]; then
		MOD=$(stat -c %y "${DOMAIN_PK_PHYSPATH}")
		if [ "${DOMAIN_PK_PHYSPATH}" -nt "${DOMAIN_HOOK_STATUS}" ]; then
			DOMAIN_PK_IS_NEWER="UPDATED"
		fi
		echo "    Status:      Present"
		echo "    Modified:    ${MOD} ${DOMAIN_PK_IS_NEWER}"
	else
		echo "    Status:      File is missing. Domain skipped"
		continue
	fi

	echo "  Certificate: ${DOMAIN_FULLCHAIN}"
	echo "    Actual path: ${DOMAIN_FULLCHAIN_PHYSPATH}"

	if [ ! -z "${DOMAIN_FULLCHAIN_PHYSPATH}" ] && [ -f "${DOMAIN_FULLCHAIN_PHYSPATH}" ]; then
		MOD=$(stat -c %y "${DOMAIN_FULLCHAIN_PHYSPATH}")
		if [ "${DOMAIN_FULLCHAIN_PHYSPATH}" -nt "${DOMAIN_HOOK_STATUS}" ]; then
			DOMAIN_FULLCHAIN_IS_NEWER="UPDATED"
		fi
		echo "    Status:      Present"
		echo "    Modified:    ${MOD} ${DOMAIN_FULLCHAIN_IS_NEWER}"
	else
		echo "    Status:      File is missing"
		continue
	fi

	# Actual checks go here
	#echo "  Processing domain...."
	#echo "    DOMAIN_STATUS=${DOMAIN_STATUS}"
	#echo "    DOMAIN_PK_IS_NEWER=${DOMAIN_PK_IS_NEWER}"
	#echo "    DOMAIN_FULLCHAIN_IS_NEWER=${DOMAIN_FULLCHAIN_IS_NEWER}"

	if [ "${DOMAIN_STATUS}" = "FORCE" ] || \
	   [ "${DOMAIN_PK_IS_NEWER}" = "UPDATED" ] || \
	   [ "${DOMAIN_FULLCHAIN_IS_NEWER}" = "UPDATED" ]; then
		echo "  Domain certificate had changed. Running the hook action..."
		${DOMAIN_HOOK_ACTION} \
			"${DOMAIN_NAME}" \
			"${DOMAIN_FULLCHAIN_PHYSPATH}" \
			"${DOMAIN_PK_PHYSPATH}"

		touch "${DOMAIN_HOOK_STATUS}"
		echo "  Done."
		echo
	fi
done
