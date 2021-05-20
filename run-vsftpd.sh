#!/bin/bash

#################################
# Variables
#################################
VIRTUAL_USERS_FILE="/etc/vsftpd/virtual_users.txt"
VIRTUAL_USERS_DB_FILE="/etc/vsftpd/virtual_users.db"
VSFTPD_CONFIG_FILE="/etc/vsftpd/vsftpd.conf"
VSFTPD_HOME_DIR="/home/vsftpd/"

# If no env var for FTP_USER has been specified, use 'admin':
if [[ "$FTP_USER" = "**String**" ]]; then
    export FTP_USER='admin'
fi

# If no env var has been specified, generate a random password for FTP_USER:
if [[ "$FTP_PASS" = "**Random**" ]]; then
    export FTP_PASS=$(cat /dev/urandom | tr -dc A-Z-a-z-0-9 | head -c${1:-16})
fi

# Do not log to STDOUT by default:
if [[ "$LOG_STDOUT" = "**Boolean**" ]]; then
    export LOG_STDOUT=''
else
    export LOG_STDOUT='Yes.'
fi

# Set passive mode parameters:
if [[ "$PASV_ADDRESS" = "**IPv4**" ]]; then
    export PASV_ADDRESS=$(/sbin/ip route|awk '/default/ { print $3 }')
fi

info(){
	echo -e "INFO: $1"
}

# Verify if 'main' user exist, if so do nothing.
verify_user(){
	if [[ ! -e $VIRTUAL_USERS_FILE ]]; then
		info "Fresh deployment"
		info "Creating virtual user: ${FTP_USER}"
		echo -e "${FTP_USER}\n${FTP_PASS}" > $VIRTUAL_USERS_FILE
	else
		local exist=$(grep -o "$1" $VIRTUAL_USERS_FILE && grep -o "$2" $VIRTUAL_USERS_FILE)
		if [[ $exist -ne 0 ]]; then
			echo "Creating virtual user: ${FTP_USER}"
			echo -e "${FTP_USER}\n${FTP_PASS}" >> $VIRTUAL_USERS_FILE
		fi
	fi
}

# Generate database file based on txt file
db_load(){
	/usr/bin/db_load -T -t hash -f $1 $2
}

# Create home dir and update vsftpd user db:
mkdir -p "${VSFTPD_HOME_DIR}/${FTP_USER}"
chown -R ftp:ftp $VSFTPD_HOME_DIR

verify_user $FTP_USER $FTP_PASS
db_load $VIRTUAL_USERS_FILE $VIRTUAL_USERS_DB_FILE


echo "pasv_address=${PASV_ADDRESS}" >> $VSFTPD_CONFIG_FILE
echo "pasv_max_port=${PASV_MAX_PORT}" >> $VSFTPD_CONFIG_FILE
echo "pasv_min_port=${PASV_MIN_PORT}" >> $VSFTPD_CONFIG_FILE
echo "pasv_addr_resolve=${PASV_ADDR_RESOLVE}" >> $VSFTPD_CONFIG_FILE
echo "pasv_enable=${PASV_ENABLE}" >> $VSFTPD_CONFIG_FILE
echo "file_open_mode=${FILE_OPEN_MODE}" >> $VSFTPD_CONFIG_FILE
echo "local_umask=${LOCAL_UMASK}" >> $VSFTPD_CONFIG_FILE
echo "xferlog_std_format=${XFERLOG_STD_FORMAT}" >> $VSFTPD_CONFIG_FILE
echo "reverse_lookup_enable=${REVERSE_LOOKUP_ENABLE}" >> $VSFTPD_CONFIG_FILE
echo "pasv_promiscuous=${PASV_PROMISCUOUS}" >> $VSFTPD_CONFIG_FILE
echo "port_promiscuous=${PORT_PROMISCUOUS}" >> $VSFTPD_CONFIG_FILE

# Get log file path
export LOG_FILE=$(grep xferlog_file $VSFTPD_CONFIG_FILE|cut -d'=' -f2)

# stdout server info:
if [[ ! $LOG_STDOUT ]]; then
cat << EOB
	*************************************************
	* Based on:                                     *
	* Docker image: fauria/vsftpd                   *
	* https://github.com/fauria/docker-vsftpd       *
	*************************************************
EOB
else
    /usr/bin/ln -sf /dev/stdout $LOG_FILE
fi

info "
	--------------- \n
	· FTP User: $FTP_USER
	· FTP Password: $FTP_PASS
	· Log file: $LOG_FILE
	· Redirect vsftpd log to STDOUT: No. \n"

# Run vsftpd:
&>/dev/null /usr/sbin/vsftpd $VSFTPD_CONFIG_FILE

