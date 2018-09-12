#!/bin/bash


### Define functions

function scriptHelp {
echo -e "\e[1;39mUsage:"
echo -e "\e[1;36m$(basename ${0})" \
    "\e[1;35m-f /path/to/account/details.file"
echo -e "\t\e[1;33m-r record.to.update [-r another.record.to.update -r ...]"
echo -e "\t\e[0;92m[optional parameters]\e[0m\n"
echo -e "\e[1;39mNotes:\e[0m"
echo -e "-f and -r parameters are REQUIRED."
echo -e "Multiple A/AAAA records to update can be specified by supplying"
echo -e "\tmultiple -r parameters (see examples below)."
echo "This script can operate only in either IP4 OR IP6 mode. See below."
echo "This script will NOT verify the format or validity of supplied IP"
echo -e "\taddresses."
echo -e "\n\e[1;39mOptional parameters\e[0m"
echo -e "-i\tUse this IP address when updating DNS records"
echo -e "\tIf NOT supplied, the script will attempt to auto-detect this"
echo -e "\tmachine's IP address (depending on -4 or -6 parameters) and"
echo -e "\tuse that address for DNS updates.  The script does NOT check"
echo -e "\tthe validity of an address supplied using this parameter nor"
echo -e "\tthe protocol type (IP4 vs IP6)."
echo -e "-4\tOperate in IP4 mode and update A records (default)"
echo -e "\tThis is the default operating mode and does not need to be"
echo -e "\texplicitly specified.  Ensure you have supplied a valid IP4"
echo -e "\taddress using the -i parameter or that your machine's IP4"
echo -e "\taddress can be correctly detected externally."
echo -e "-6\tOperate in IP6 mode and update AAAA records"
echo -e "\tONLY AAAA records will be updated.  Ensure you have supplied"
echo -e "\ta valid IP6 address using the -i parameter or that your"
echo -e "\tmachine's IP6 address can be correctly detected externally."
echo -e "-h\tDisplay this help page"
echo -e "-x\tDisplay script examples"
echo -e "\n\e[1;39mExamples:"
echo -e "\e[0;39mRun \e[1;36m$(basename ${0}) \e[1;92m-x\e[0m\n"
echo -e "\n"

# exit with any error code used to call this help screen
quit none $1
}


function scriptExamples {
echo -e "\n\e[1;39m$(basename ${0}) Examples:\e[0m"
echo -e "\n\e[1;39mExample: \e[0mUse details from myCloudFlareDetails.info"
echo -e "file in /home/janedoe directory. Update server.mydomain.com A record"
echo -e "with this machine's auto-detected IP4 address."
echo -e "\t\e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info"
echo -e "\t\e[1;33m-r server.mydomain.com\e[0m"
echo -e "\n\e[1;39mExample: \e[0mUse details from myCloudFlareDetails.info"
echo -e "file in /home/janedoe directory. Update server.mydomain.com AND"
echo -e "server2.mydomain.com A records with this machine's auto-detected IP6"
echo -e "address."
echo -e "\t\e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info"
echo -e "\t\e[1;33m-r server.mydomain.com" \
    "-r server2.mydomain.com \e[1;92m-6\e[0m"
echo -e "\n\e[1;39mExample: \e[0mUse details from myCloudFlareDetails.info"
echo -e "file in /home/janedoe directory. Update server.mydomain.com A record"
echo -e "using IP4 address 1.2.3.4."
echo -e "\t\e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info"
echo -e "\t\e[1;33m-r server.mydomain.com \e[1;92m-i 1.2.3.4\e[0m"
echo -e "\n\e[1;39mExample: \e[0mUse details from myCloudFlareDetails.info"
echo -e "file in /home/janedoe directory. Update server3.mydomain.com AND"
echo -e "server7.mydomain.com AAAA records using IP6 address FE80::286A:FF91."
echo -e "\t\e[1;36m$(basename ${0})" \
    "\e[1;35m-f /home/janedoe/myCloudFlareDetails.info"
echo -e "\t\e[1;33m-r server.mydomain.com" \
    "\e[1;33m-r server2.mydomain.com \e[1;92m-i FE80::286A:FF91\e[0m"

quit none
}


function quit {
    if [ -z "$1" ]; then
        # exit cleanly
        echo -e "\e[1;32m--[SUCCESS] Script completed --\e[0m"
        exit 0
    elif [ "$1" = "none" ]; then
        if [ -z "$2" ]; then
            # exit cleanly
            exit 0
        else
            # exit with error code but don't display it
            exit "$2"
        fi
    else
        # notify use that error has occurred and provide exit code
        echo -e "\e[1;31m-- [ERROR] Script exited with code $1 --"
        echo -e "\e[0;31m${errorExplain[$1]}\e[0m"
        exit "$1"
    fi
}

### end of functions


### unset environment variables used in this script and initialize arrays
unset PARAMS
unset accountFile
unset ipAddress
errorExplain=()
dnsRecords=()
cfDetails=()
cfRecords=()
currentIP=()
recordID=()
ip4=1
ip6=0


## define error code explainations
errorExplain[1]="Missing or invalid parameters on script invocation."
errorExplain[101]="Location of file with CloudFlare account details was NOT provided (-f parameter missing)."
errorExplain[102]="CloudFlare account details file is empty or does not exist"
errorExplain[103]="No DNS records to update were specified (-r parameter(s) missing)."
errorExplain[104]="There are no DNS records specified that match those found in your CloudFlare account to update."
errorExplain[201]="Could not detect this machine's IP address. Please re-run this script with the -i option."
errorExplain[254]="Could not connect with CloudFlare API. Please re-run this script later."


### Process script parameters
if [ -z $1 ]; then
    echo -e "\e[1;31mNo parameter(s) provided\e[0m\n"
    scriptHelp 1
fi

while getopts ':f:r:i:46hx' PARAMS; do
    case "$PARAMS" in
        f)
            accountFile="${OPTARG}"
            ;;
        r)
            dnsRecords+=($OPTARG)
            ;;
        i)
            ipAddress="$OPTARG"
            ;;
        4)
            ip4=1
            ip6=0
            ;;
        6)
            ip4=0
            ip6=1
            ;;
        h)
            scriptHelp
            ;;
        x)
            scriptExamples
            ;;
        ?)
            echo -e "\e[1;31mInvalid parameter(s) provided\e[0m\n"
            scriptHelp 1
            ;;
    esac
done

# Check validity of parameters
if [ -z "$accountFile" ] || [[ $accountFile == -* ]]; then
    quit 101
elif [ ! -s "$accountFile" ]; then
    quit 102
elif [ -z ${dnsRecords} ]; then
    quit 103
fi


## Extract needed information from accountDetails file
mapfile -t cfDetails < "$accountFile"

## Get current IP address, if not provided in parameters
if [ -z "$ipAddress" ]; then
    echo -e "\e[0;36mNo IP address for update provided.  Detecting" \
        "this machine's IP address..."
    if [ $ip4 -eq 1 ]; then
        echo -e "\e[1;36m(set to IP4 mode)\e[0m"
        ipAddress=$(curl -s http://ipv4.icanhazip.com)
    elif [ $ip6 -eq 1 ]; then
        echo -e "\e[1;36m(set to IP6 mode)\e[0m"
        ipAddress=$(curl -s http://ipv6.icanhazip.com)
    fi
    ipLookupResult=$(echo "$?")
    if [ "$ipLookupResult" -ne 0 ]; then
        quit 201
    else
        echo -e "\e[0;36mUsing IP address: $ipAddress"
    fi
fi


## Check if desired record(s) exist at CloudFlare
echo -e "\e[0;36mPerforming CloudFlare lookup on specified DNS records...\e[0m"
# perform checks on A or AAAA records based on invocation options
if [ $ip4 -eq 1 ]; then
    echo -e "\t(IP4: ${dnsRecords[*]})"
    for cfLookup in "${dnsRecords[@]}"; do
    cfRecords+=("$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cfDetails[2]}/dns_records?name=$cfLookup&type=A" -H "X-Auth-Email: ${cfDetails[0]}" -H "X-Auth-Key: ${cfDetails[1]}" -H "Content-Type: application/json")")
    done
elif [ $ip6 -eq 1 ]; then
    echo -e "\t(IP6: ${dnsRecords[*]})"
    for cfLookup in "${dnsRecords[@]}"; do
    cfRecords+=("$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${cfDetails[2]}/dns_records?name=$cfLookup&type=AAAA" -H "X-Auth-Email: ${cfDetails[0]}" -H "X-Auth-Key: ${cfDetails[1]}" -H "Content-Type: application/json")")
    done
fi
# check for curl errors
cfLookupResult=$(echo "$?")
if [ "$cfLookupResult" -ne 0 ]; then
    quit 254
fi
# check for any non-existant domain names and remove from array
for recordIdx in "${!cfRecords[@]}"; do
    if [[ ${cfRecords[recordIdx]} == *"\"count\":0"* ]]; then
        # inform user that domain not found in CloudFlare DNS records
        echo -e "\e[0;31m***${dnsRecords[recordIdx]} not found in your" \
            "CloudFlare DNS records***\e[0m"
        # remove the entry from the dnsRecords array
        unset dnsRecords[$recordIdx]
        # remove the entry from the records array
        unset cfRecords[$recordIdx]
    fi
done
# contract the dnsRecords and cfRecords arrays to re-order them after any
# deleted records
dnsRecords=("${dnsRecords[@]}")
cfRecords=("${cfRecords[@]}")

# after trimming errant records, it's possible dnsRecords array is empty
# check for this condition and exit (nothing to do), otherwise list arrays
if [ -z ${dnsRecords} ]; then
    quit 104
else
    for recordIdx in "${!cfRecords[@]}"; do
        echo -e "\n\e[0;33mFound ${dnsRecords[recordIdx]}" \
            "(Index: $recordIdx):\e[0m"
        echo -e "${cfRecords[recordIdx]}"
    done
fi


## Get existing IP address and identifier in CloudFlare's DNS records
for recordIdx in "${!cfRecords[@]}"; do
    currentIP+=($(echo "${cfRecords[recordIdx]}" | \
        grep -Po '(?<="content":")[^"]*'))
    recordID+=($(echo "${cfRecords[recordIdx]}" | \
        grep -Po '(?<="id":")[^"]*'))
    echo -e "\e[1;36mIndex $recordIdx: \e[0mFor record\e[1;33m" \
        "${dnsRecords[recordIdx]}\e[0m" \
        "with ID: \e[1;33m${recordID[recordIdx]}\e[0m" \
        "the current IP is \e[1;35m ${currentIP[recordIdx]}\e[0m"
done

## Check whether new IP matches old IP and update if they do not match
for recordIdx in "${!currentIP[@]}"; do
    if [ ${currentIP[recordIdx]} = $ipAddress ]; then
        echo -e "\e[0;32m${dnsRecords[recordIdx]} is up-to-date."
    else
        echo -e "\e[0;31m${dnsRecords[recordIdx]} needs updating."
    fi
done



quit

# this code should never be executed
exit 99
