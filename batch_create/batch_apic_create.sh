 #!/bin/bash
 
 # script tested on cywin 2.8.0(0.309/5/3)

function usage
{
    echo "usage: batch_apic_create [[-i inputdirectory ] [-o outputdirectory] | [-h]]"
}


if [ $# -eq 0 ]
	then
		usage
		exit
fi

while [ "$1" != "" ]; do
    case $1 in
        -i | --inputs )     shift
                                inputdirectory=$1
                                ;;
		-o | --outputs )	shift
								outputdirectory=$1
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
if test -z $outputdirectory; then usage;	exit 1; fi


WSDL_INPUTDIR=$inputdirectory/*.wsdl
WSDLZIP_INPUTDIR=$inputdirectory/*.zip
BUILD_PATH=$outputdirectory


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

batch_create_success=true
failed_create_list=()
succcess_create_list=()


echo Creating API Swagger for wsdl under $outputdirectory directory
if !(mkdir $BUILD_PATH); then exit 1; fi


# parsing the single wsdl file
for wsdlfile in $WSDL_INPUTDIR; do
	if [[ -e $wsdlfile ]]; then
		filenameonly=${wsdlfile##*/}
		filenameonly=${filenameonly%.*}
		mkdir $BUILD_PATH/$filenameonly"_wsdl"
		cp $wsdlfile $BUILD_PATH/$filenameonly"_wsdl"
		cd $BUILD_PATH/$filenameonly"_wsdl"
		
		# compress the wsdl file to avoid upload file size issue. APIC causes issues if the file size is large
		zip $filenameonly.zip $filenameonly.wsdl
		
		if (apic create --type api --wsdl $filenameonly.zip --version "$filenameonly.wsdl"); then
			succcess_create_list+=("$wsdlfile")
		else	
			batch_create_success=false
			failed_create_list+=("$wsdlfile")
		fi
		
		# create product for all apis defined in the wsdl
		allapis=
		for apis in *.yaml; do
			if [[ -e $apis ]]; then
				allapis="$allapis $apis"
				
				# apic create api wsdl ignore version field. changing the generated version using sed
				sed -i -e "0,/^    version:/ s/^    version: \"1.0.0\"/    version: \"$filenameonly.wsdl\"/g" $apis
				
				
				# change the x-ibm-name by appending the wsdl name, making it unique
				cleanedfilename=$filenameonly.wsdl
				cleanedfilename=${cleanedfilename//[^[:alnum:]]/_}
				sed -i -e "0,/^    x-ibm-name:/ s/^    x-ibm-name: \"\(.*\)\"/    x-ibm-name: \1-$cleanedfilename/g" $apis
				

			fi
		done
		apic create --type product --title "$filenameonly Product" --apis "$allapis" --version "$filenameonly.wsdl"

		cd ../..
	fi
done

# parsing the wsdl zip files first
for wsdlzipfile in $WSDLZIP_INPUTDIR; do
	if [[ -e $wsdlzipfile ]]; then
		filenameonly=${wsdlzipfile##*/}
		filenameonly=${filenameonly%.*}
		mkdir $BUILD_PATH/$filenameonly"_zip"
		cp $wsdlzipfile $BUILD_PATH/$filenameonly"_zip"
		cd $BUILD_PATH/$filenameonly"_zip"
		if (apic create --type api --wsdl $filenameonly.zip --version "$filenameonly.zip"); then
			succcess_create_list+=("$wsdlzipfile")
		else	
			batch_create_success=false
			failed_create_list+=("$wsdlzipfile")
		fi

		# create product for all apis defined in the wsdl
		allapis=
		for apis in *.yaml; do
			if [[ -e $apis ]]; then
				allapis="$allapis $apis" 
				
				# apic create api wsdl ignore version field. changing the generated version using sed
				# may only work using GNU sed; assume the first appearance of "^    version" is api version where ^ is new line
				sed -i -e "0,/^    version:/ s/^    version: \"1.0.0\"/    version: \"$filenameonly.zip\"/g" $apis

				# change the x-ibm-name by appending the wsdl name, making it unique
				cleanedfilename=$filenameonly.zip
				cleanedfilename=${cleanedfilename//[^[:alnum:]]/_}
				sed -i -e "0,/^    x-ibm-name:/ s/^    x-ibm-name: \"\(.*\)\"/    x-ibm-name: \1-$cleanedfilename/g" $apis
				
			fi
		done
		apic create --type product --title "$filenameonly Product" --apis "$allapis" --version "$filenameonly.zip"
		
		cd ../..
	fi
done

echo
if $batch_create_success; then
	printf "${GREEN}all api swagger successfully created${NC}\n"
	for i in "${succcess_create_list[@]}"; do echo $i; done
	printf "${GREEN}api swaggercreation completed - success ${NC}\n"
	echo
	exit
else
	printf "${RED}api swagger creation failed${NC}\n"
	echo the following api swagger were created for:
	for i in "${succcess_create_list[@]}"; do echo $i; done
	printf "api swagger creation failed for:\n"
	for i in "${failed_create_list[@]}"; do echo $i; done	
	printf "${RED}sapi swagger creation completed - failed ${NC}"
	echo
	exit 1
fi


