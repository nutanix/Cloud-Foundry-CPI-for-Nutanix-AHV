#!/bin/bash

#======================================================
#title           :setup.sh
#description     :This script will install Acropolis CPI, Bosh Director and Cloud Foundy on Nutanix cluster.
#author          :paresh.lohakare@nutanix.com
#company         :Nutanix Inc.
#version         :1.0
#usage           :bash setup.sh
#notes           :Update setup.config before running the script.
#bash_version    :4.0
#======================================================

# Forecolor codes
R='\033[0;31m'
G='\033[0;32m'
B='\033[0;34m'

# Text formatting
BOLD=$(tput bold)

# Clear the terminal
clear

GRAY='\033[1;34m'
echo -e "${GRAY}${BOLD}======== NUTANIX CLOUD FOUNDRY DEPLOYMENT ========\n\n"
tput sgr0


# Declare all required file variables.
bosh_ahv_template_file="bosh_ahv_template.yml"
cf_dea_manifest_template_file="cf_dea_manifest_template.yml"
cf_diego_manifest_template_file="cf_diego_manifest_template.yml"
stemcell_file="acropolis_stemcell.tgz"
cpi_file="bosh-acropolis-cpi-0+dev.1.tgz"
config_file="setup.config"

#--------------------------------------------------------------------
# Making sure that all the required file present in the current directory, else Exit.
#--------------------------------------------------------------------
if [ ! -f "$bosh_ahv_template_file" ]; then
  echo 1>&2 "${R}$0: $bosh_ahv_template_file file not present in current directory."
  tput sgr0
  exit 2
elif [ ! -f "$cf_dea_manifest_template_file" ]; then
  echo 1>&2 "${R}$0: $cf_dea_manifest_template_file file not present in current directory."
  tput sgr0
  exit 2
elif [ ! -f "$cf_diego_manifest_template_file" ]; then
  echo 1>&2 "${R}$0: $cf_diego_manifest_template_file file not present in current directory."
  tput sgr0
  exit 2
elif [ ! -f "$stemcell_file" ]; then
  echo 1>&2 "${R}$0: $stemcell_file file not present in current directory."
  tput sgr0
  exit 2
elif [ ! -f "$cpi_file" ]; then
  echo 1>&2 "${R}$0: $cpi_file file not present in current directory."
  tput sgr0
  exit 2
elif [ ! -f "$config_file" ]; then
  echo 1>&2 "${R}$0: $config_file file not present in current directory."
  tput sgr0
  exit 2
fi

logfile="NutanixAHV_CF_setup.log"
touch $logfile

dir=$(pwd)
#--------------------------------------------------------------------
# Take the backup of the bosh_ahv.yml file if it aready exists in current directory.
#--------------------------------------------------------------------
bosh_ahv_file="bosh_ahv.yml"
if [ -f "$bosh_ahv_file" ]; then
  mv -f $bosh_ahv_file bosh_ahv_bkp.yml #overwrite old backup file.
  echo "bosh_ahv_bkp.yml created." >> $logfile
fi
#--------------------------------------------------------------------
# Creating bosh_ahv.yml from the template file.
#--------------------------------------------------------------------
cp "$dir/bosh_ahv_template.yml" "$dir/bosh_ahv.yml" 

#--------------------------------------------------------------------
# Take the backup of the cf_dea_manifest.yml file if it aready exists in current directory.
#--------------------------------------------------------------------
cf_dea_manifest_file="cf_dea_manifest.yml"
if [ -f "$cf_dea_manifest_file" ]; then
  mv -f $cf_dea_manifest_file cf_dea_manifest_bkp.yml #overwrite old backup file.
  echo "cf_dea_manifest_bkp.yml created." >> $logfile
fi
#--------------------------------------------------------------------
# Creating cf_dea_manifest.yml from the template file.
#--------------------------------------------------------------------
cp "$dir/cf_dea_manifest_template.yml" "$dir/cf_dea_manifest.yml" 

#--------------------------------------------------------------------
# Take the backup of the cf_diego_manifest.yml file if it aready exists in current directory.
#--------------------------------------------------------------------
cf_diego_manifest_file="cf_diego_manifest.yml"
if [ -f "$cf_diego_manifest_file" ]; then
  mv -f $cf_diego_manifest_file cf_diego_manifest_bkp.yml #overwrite old backup file.
  echo "cf_diego_manifest_bkp.yml created." >> $logfile
fi
#--------------------------------------------------------------------
# Creating cf_diego_manifest.yml from the template file.
#--------------------------------------------------------------------
cp "$dir/cf_diego_manifest_template.yml" "$dir/cf_diego_manifest.yml" 

#--------------------------------------------------------------------
# Read setup.config and create config array. 
#--------------------------------------------------------------------
declare -A config
config+=( 
  ["subNetName"]=$(grep 'SubnetName' $config_file | awk '{ print $2}')
  ["subnetRange"]=$(grep 'SubnetRange' $config_file | awk '{ print $2}')
  ["gateway"]=$(grep 'Gateway' $config_file | awk '{ print $2}')
  ["dns"]=$(grep 'DNS' $config_file | awk '{ print $2}')
  ["staticIPRange"]=$(grep 'StaticIpRange' $config_file | awk '{ print $2,$3}')
  ["directorIP"]=$(grep 'DirectorIP' $config_file | awk '{ print $2}')
  ["clusterIP"]=$(grep 'ClusterIP' $config_file | awk '{ print $2}')
  ["clusterUsername"]=$(grep 'Username' $config_file | awk '{ print $2}')
  ["clusterPassword"]=$(grep 'Password' $config_file | awk '{ print $2}')
  ["clusterContainerName"]=$(grep 'ContainerName' $config_file | awk '{ print $2}')
  ["cfarchitecture"]=$(grep 'Architecture' $config_file | awk '{ print $2}')
   )
#Ensure that none of the value is empty, else Exit.
for key in ${!config[@]}; do
    size=${#config[${key}]}
    if [ "$size" -lt 2 ]; then
      echo "${key}" "value is not defined in" $config_file
      tput sgr0
      exit 2
  fi
done
#--------------------------------------------------------------------
#Construct CPI and Stmecell path to be updated in bosh_ahv.yml file.
#--------------------------------------------------------------------
cpi_filePath="file://$dir/$cpi_file"
stemcell_filePath="file://$dir/$stemcell_file"
#--------------------------------------------------------------------
#Updating bosh_ahv.yml file.
#--------------------------------------------------------------------
sed -i "s|BOSH_ACROPOLIS_CPI_RELEASE_URL|$cpi_filePath|" $bosh_ahv_file
sed -i "s|BOSH_ACROPOLIS_STEMCELL_URL|$stemcell_filePath|" $bosh_ahv_file
sed -i "s|NETWORK_SUBNET_RANGE|${config["subnetRange"]}|" $bosh_ahv_file
sed -i "s|NETWORK_GATEWAY_IP|${config["gateway"]}|" $bosh_ahv_file
sed -i "s|NETWORK_DNS_IP|[${config["dns"]}]|" $bosh_ahv_file
sed -i "s|NETWORK_SUBNET_NAME|${config["subNetName"]}|" $bosh_ahv_file
sed -i "s|DIRECTOR_IP|${config["directorIP"]}|g" $bosh_ahv_file
sed -i "s|ACROPOLIS_CLUSTER_IP|${config["clusterIP"]}|" $bosh_ahv_file
sed -i "s|ACROPOLIS_CLUSTER_USERNAME|${config["clusterUsername"]}|" $bosh_ahv_file
sed -i "s|ACROPOLIS_CLUSTER_PASSWORD|${config["clusterPassword"]}|" $bosh_ahv_file
sed -i "s|ACROPOLIS_CLUSTER_CONTAINER_NAME|${config["clusterContainerName"]}|" $bosh_ahv_file
#--------------------------------------------------------------------
# Construct IP Addresss array from the IP range provided in setup.config file.
#--------------------------------------------------------------------
startIP=$(echo ${config["staticIPRange"]} | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | head -n1)
endIP=$(echo ${config["staticIPRange"]} | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | tail -n1)
startIPLastOctect=$(echo $startIP | cut -f 4 -d '.')
endIPLastOctect=$(echo $endIP | cut -f 4 -d '.')
IPSeq=$(seq -f "${startIP%.*}.%g" $startIPLastOctect $endIPLastOctect)
IFS=' ' read -r -a IPArry <<< $IPSeq

# Ensure IP Array length shouldn't be less than 10.
if [ ${#IPArry[@]} -lt 10 ]; then
  echo "Static IP Range provided in setup.config is < 10 IPs."
  tput sgr0
  exit 2
fi
#--------------------------------------------------------------------
#Updating cf_dea_manifest.yml file.
#--------------------------------------------------------------------

# Updating Job's IPs
sed -i "s|CONSSUL_Z1_IP|${IPArry[0]}|g" $cf_dea_manifest_file
sed -i "s|NATS_Z1_IP|${IPArry[1]}|g" $cf_dea_manifest_file
sed -i "s|ETCD_Z1_IP|${IPArry[2]}|g" $cf_dea_manifest_file
sed -i "s|POSTGRES_Z1_IP|${IPArry[3]}|g" $cf_dea_manifest_file
sed -i "s|UAA_PROXY_SERVER1_IP|${IPArry[4]}|g" $cf_dea_manifest_file
sed -i "s|UAA_PROXY_SERVER2_IP|${IPArry[5]}|g" $cf_dea_manifest_file
sed -i "s|HA_PROXY_Z1_IP|${IPArry[6]}|g" $cf_dea_manifest_file
sed -i "s|ETCD_Z1_2_IP|${IPArry[7]}|g" $cf_dea_manifest_file
# Updating Network's details
sed -i "s|NETWORK_SUBNET_NAME|${config["subNetName"]}|" $cf_dea_manifest_file
sed -i "s|NETWORK_SUBNET_RANGE|${config["subnetRange"]}|g" $cf_dea_manifest_file
sed -i "s|NETWORK_GATEWAY_IP|${config["gateway"]}|g" $cf_dea_manifest_file
sed -i "s|NETWORK_DNS_IP|${config["dns"]}|g" $cf_dea_manifest_file
sed -i "s|NETWORK_STATIC_IP_RANGE|${config["staticIPRange"]}|g" $cf_dea_manifest_file

#--------------------------------------------------------------------
#Updating cf_diego_manifest.yml file.
#--------------------------------------------------------------------

# Updating Job's IPs
sed -i "s|NATS_Z1_IP|${IPArry[0]}|g" $cf_diego_manifest_file
sed -i "s|ETCD_Z1_IP|${IPArry[1]}|g" $cf_diego_manifest_file
sed -i "s|CONSUL_Z1_IP|${IPArry[2]}|g" $cf_diego_manifest_file
sed -i "s|POSTGRES_Z1_IP|${IPArry[3]}|g" $cf_diego_manifest_file
sed -i "s|HA_PROXY_Z1_IP|${IPArry[4]}|g" $cf_diego_manifest_file
sed -i "s|ROUTER_Z1_IP|${IPArry[5]}|g" $cf_diego_manifest_file
# Updating Network's details
sed -i "s|NETWORK_SUBNET_NAME|${config["subNetName"]}|" $cf_diego_manifest_file
sed -i "s|NETWORK_SUBNET_RANGE|${config["subnetRange"]}|g" $cf_diego_manifest_file
sed -i "s|NETWORK_GATEWAY_IP|${config["gateway"]}|g" $cf_diego_manifest_file
sed -i "s|NETWORK_DNS_IP|${config["dns"]}|g" $cf_diego_manifest_file
sed -i "s|NETWORK_STATIC_IP_RANGE|${config["staticIPRange"]}|g" $cf_diego_manifest_file


start=$SECONDS


#--------------------------------------------------------------------
# Install required packages
#--------------------------------------------------------------------
echo -ne "${B}1. Installing required packages...\r" 
yum install -y gcc gcc-c++ ruby ruby-devel mysql-devel postgresql-devel postgresql-libs sqlite-devel libxslt-devel libxml2-devel yajl-ruby patch openssl genisoimage wget bzip2 > "$logfile"

if [ $? -eq 1 ]; then
  echo -e "${R}$0:\n\nDeployment failed. Please check the $logfile for more details."
  tput sgr0
  exit 1
fi
echo -e "${G}1. All packages installed successfully.\n"
#--------------------------------------------------------------------
# Install bosh cli gem
#--------------------------------------------------------------------
echo -ne "${B}2. Installing bosh cli gem...\r"
gem install bosh_cli --no-ri --no-rdoc  >> "$logfile"

if [ $? -eq 1 ]; then
  echo -e "${R}$0:\n\nBosh CLI gem installation failed. Please check the $logfile for more details."
  tput sgr0
  exit 1
fi

echo -e "${G}2. Installed bosh cli gem successfully.\n"
#--------------------------------------------------------------------
# Get bosh-init executable
#--------------------------------------------------------------------
echo -ne "${B}3. Downloading bosh-init...\r"
wget https://s3.amazonaws.com/bosh-init-artifacts/bosh-init-0.0.99-linux-amd64  > /dev/null 2>&1
echo -e "${G}3. Finished downloading bosh-init.\n"

# Give execution rights to it
echo -ne "${B}4. Installing bosh-init...\r"
chmod +x bosh-init-*
# Move it to /usr/local/bin so that it's available in the $PATH
sudo mv bosh-init-* /usr/local/bin/bosh-init
# Confirm that bosh-init is working
boshinitversion="$(bosh-init -v)"
echo -e "${G}4. Finished installing bosh-init [$boshinitversion]\n"
#--------------------------------------------------------------------
# Deploy the director
#--------------------------------------------------------------------
echo -e "${B}5. Deploying director.....\n"
tput sgr0
BOSH_INIT_LOG_LEVEL=DEBUG bosh-init deploy "$bosh_ahv_file" >> $logfile 2>/dev/null

if [ $? -eq 1 ]; then
  echo -e "${R}$0:\n\nDeployment failed. Please check the $logfile for more details."
  tput sgr0
  exit 1
fi

echo -e "${G}\nDirector deployment successful.\n"

# Once the director is deployed successfully, set its IP address as the target
bosh -n target ${config["directorIP"]}
echo -e "${G}6. BOSH target set to ${config["directorIP"]} \n"
#--------------------------------------------------------------------
#Logging into bosh diretor using default admin credentials.
#--------------------------------------------------------------------
echo -e "${B}7. Logging into bosh director using the credentials specified into bosh-ahv.yml file. \n"
bosh login admin admin

if [ $? -eq 1 ]; then
  echo -e "${R}$0:\n\nBosh Director login failed. Please check the $logfile for more details."
  tput sgr0
  exit 1
fi

# Extract director's uuid from bosh status commmand output
directorUUID=$(bosh status | grep UUID | awk '{ print $2}')
# Insert current director_uuid in the cf dea manifest file.
sed -i "s/DIRECTOR_UUID/$directorUUID/g" $cf_dea_manifest_file

# Insert current director_uuid in the cf diego manifest file.
sed -i "s/DIRECTOR_UUID/$directorUUID/g" $cf_diego_manifest_file

#--------------------------------------------------------------------
# Upload stemcell
#--------------------------------------------------------------------
echo -e "${B}8. Uploading stemcell... \n"
tput sgr0
bosh upload stemcell $stemcell_file >> $logfile
echo -e "${G}\nStemcell uploaded.\n"

if [ ${config["cfarchitecture"]} = "dea" ]; then
  #--------------------------------------------------------------------
  # Upload cloudfoundry release
  #--------------------------------------------------------------------
  echo -e "${B}9. Uploading cloudfoundry release...\n"
  tput sgr0
  bosh upload release https://bosh.io/d/github.com/cloudfoundry/cf-release?v=247 >> $logfile
  echo -e "${G}\nCloud foundry release uploaded.\n"
  #--------------------------------------------------------------------
  # Set the dea deployment manifest
  #--------------------------------------------------------------------
  bosh deployment $cf_dea_manifest_file >> "$logfile"
  echo -e "${G}10. Deployement manifest set to $cf_dea_manifest_file\n"

elif [ "${config["cfarchitecture"]}" = "diego" ]; then
  #--------------------------------------------------------------------
  # Upload cloudfoundry release 
  #--------------------------------------------------------------------
  echo -e "${B}9. Uploading cloudfoundry release...\n"
  tput sgr0
  bosh upload release https://bosh.io/d/github.com/cloudfoundry/cf-release?v=256 >> $logfile
  echo -e "${G}\nCloud foundry release uploaded.\n"
  #--------------------------------------------------------------------
  #--------------------------------------------------------------------
  # Upload Diego release
  #--------------------------------------------------------------------
  echo -e "${B}9. Uploading Diego release...\n"
  tput sgr0
  bosh upload release https://bosh.io/d/github.com/cloudfoundry/diego-release?v=1.12.0 >> $logfile
  echo -e "${G}\nDiego release uploaded.\n"
  #--------------------------------------------------------------------
  #--------------------------------------------------------------------
  # Upload cflinuxfs2 release
  #--------------------------------------------------------------------
  echo -e "${B}9. Uploading cflinuxfs2 release...\n"
  tput sgr0
  bosh upload release https://bosh.io/d/github.com/cloudfoundry/cflinuxfs2-rootfs-release?v=1.60.0 >> $logfile
  echo -e "${G}\ncflinuxfs2 release uploaded.\n"
  #--------------------------------------------------------------------
  #--------------------------------------------------------------------
  # Upload garden-runc release
  #--------------------------------------------------------------------
  echo -e "${B}9. Uploading garden-runc release...\n"
  tput sgr0
  bosh upload release https://bosh.io/d/github.com/cloudfoundry/garden-runc-release?v=1.4.0 >> $logfile
  echo -e "${G}\ngarden-runc release uploaded.\n"
  #--------------------------------------------------------------------
  # Set the diego deployment manifest
  #--------------------------------------------------------------------
  bosh deployment $cf_diego_manifest_file >> "$logfile"
  echo -e "${G}10. Deployement manifest set to $cf_diego_manifest_file\n"
fi

#--------------------------------------------------------------------
# Start cloudfoundry deployment
#--------------------------------------------------------------------
echo -e "${B}11. Deploying cloudfoundry....\n"
tput sgr0
bosh -n deploy
echo -e "${G}\nCloud foundry deployment complete.\n"  

duration=$(( SECONDS - start ))
#--------------------------------------------------------------------
# Run bosh vms to list all deployed vms
#--------------------------------------------------------------------
bosh vms

echo -e "${B}Total time taken for deployment = $duration seconds.\n"
tput sgr0
exit 0
