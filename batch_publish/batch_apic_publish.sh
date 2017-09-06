#!/bin/bash

# batch_apic_publish
# version 2
# rewrite using process subsitution so this work with earlier bash shell without support for lastpipe support
# Last Revision: sept 1, 2017 aldenchan@ca.ibm.com

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


function usage
{
    echo "usage: batch_publish [[-d inputdirectory ] [-o org] [-s] [server] [-c catalog] | [-h]]"
}


if [ $# -eq 0 ]
	then
		usage
		exit
fi

while [ "$1" != "" ]; do
    case $1 in
        -d | --directory )      shift
                                inputdirectory=$1
                                ;;
		-o | --organization )	shift
								apic_organization=$1
								;;
		-s | --server )			shift
								apic_server=$1
								;;
		-c | --catalog )		shift
								apic_catalog=$1
								;;								
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if test -z $inputdirectory; then usage;	exit 1; fi
if test -z $apic_organization; then usage;	exit 1; fi
if test -z $apic_server; then usage;	exit 1; fi
if test -z $apic_catalog; then usage;	exit 1; fi


current_dir=$(pwd)
batch_publish_success=true
failed_publish_list=()
succcess_publish_list=()

echo begin publishing....


cd $inputdirectory
while IFS= read -r -d '' productfile; do
	product_filename=$(basename "$productfile")
	product_directory=$(dirname "$productfile")
	
	cd $product_directory
	
	# only publish files less than 500k
	if [[ ! -n $(find . -regex '.*zip\|.*yaml' -size +500000c) ]]
	then
		# invoke api publish and publish the api
		if (apic products:publish --server $apic_server -o $apic_organization -c $apic_catalog $product_filename); then
			succcess_publish_list+=("$productfile")
		else	
			batch_publish_success=false
			failed_publish_list+=("$productfile")
		fi
	else
		batch_publish_success=false
		failed_publish_list+=("$productfile")
	fi
		
	cd "$current_dir"
	cd "$inputdirectory"
done  < <(find . -name '*-product.yaml' -print0)

echo

if $batch_publish_success; then
	printf "${GREEN}all products published under $inputdirectory/${NC}\n"
	for i in "${succcess_publish_list[@]}"; do echo $i; done
	printf "${GREEN}publishing completed - success ${NC}\n"
	echo
	exit
else
	printf "${RED}publishing failed${NC}\n"
	echo the following products were published under "$inputdirectory"/
	for i in "${succcess_publish_list[@]}"; do echo $i; done
	printf "the following products under $inputdirectory/ failed to published\n"
	for i in "${failed_publish_list[@]}"; do echo $i; done	
	printf "${RED}publishing completed - failed ${NC}"
	echo
	exit 1
fi
