# Deployment of BOSH and Cloud Foundry

## Pre-requisites
1. Create a VM (below example is tested on CentOS) in AHV with minimum config of 8 GB RAM,  2 vCPU / 1 Core, and 40 GB disk.
2. Follow steps given in [Initializing Nutanix AHV](init-nutanix-ahv.md).
3. Clone the github repo from - https://github.com/nutanix/Cloud-Foundry-CPI-for-Nutanix-AHV.git
4. Build the CPI by following the steps in [Development](development.md). If you don't want to build it, you can download it from - https://drive.google.com/file/d/0BwOKNTtBoe4oSjNCYzcwTThJR0k/view?usp=sharing
3. Copy the CPI to the deployment_script directory (make sure you rename it to `bosh-acropolis-cpi-0+dev.1.tgz`)
4. Download the stemcell from - https://drive.google.com/file/d/0B1OFCdRVe6xqOHRmcThsdUlHMVE/view?usp=sharing , rename it to `acropolis_stemcell.tgz` and copy it to the deployment_script directory.

Now the deployment_script directory should look like this -
```
deployment_script
|---acropolis_stemcell.tgz <-- Stemcell for Nutanix
|---bosh-acropolis-cpi-0+dev.1.tgz <-- Nutanix CPI
|---bosh_ahv_template.yml <-- Template file for bosh-ahv.yml
|---cf_dea_manifest_template.yml <--  Template file for   deploying cloud foundry supporting DEA architecture.
|---cf_diego_manifest_template.yml <-- Template file for deploying cloud foundry supporting DIEGO architecture.
|---setup.sh <-- Nutanix CF setup script
|---setup.config <-- Configuration file for deployment.
```
## Update the Configuration Files
Update the setup.config file with instructions given below:

```
# subnet_name: This is the network name which will be used by CF deployed virtual machine
# subnet_range: The range of the subnet which will be used by CF [Network IP/Prefix Length e.g - 10.5.123.90/24]
# gateway_ip: IP Address of the gateway
# dns_ip: IP Address of DNS [If more than one DNS, Keep the IP separated by comma]
# static_ip_range: Range of static IP Address that the deployment will use. [Keep the IP as 10.5.123.90-10.5.123.110]
# bosh_director_vm_ip: Static IP Address which will be used by bosh director
# cluster_ip: Cluster IP Address [Cluster Virtual IP address]
# cluster_username: Prism login user of  the cluster
# cluster_password: Prism login password
# container_name: Name of the container [Taken from Prism UI]
# architecture: Possible values are '''dea'  or 'diego' . Specify 'diego' for deploying cloud foundry supporting DIEGO architecture else specify 'dea' for deploying cloud foundry supporting DEA architecture.
```
## Execute the auto deployment script

```
chmod +x setup.sh
./setup.sh
```
or
```
bash setup.sh
```
