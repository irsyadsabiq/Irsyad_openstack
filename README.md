# irsyad_OpenStack
Notes of OpenStack deployment

OpenStack Rocky version

This is version of mine to deploy the Kolla-ansible Openstack rocky version

OpenStack_deployment_notes.sh is not an automation script. Its a notes on how I deploy the OpenStack cloud successfully after did some research and testing with sleepless night.

For globals.yml or multinode file, you can request from me by contacting my email: irsyadsabiq94@gmail.com

Globals.yml or Globals-rocky-2021.yml is the file where all the configuration of the services are happening. Deployer can choose what service to be enable and not to be enable. A mistake in this file can cause the deployment to be failed, which led to destroying the "half" built and deploy it again from scratch

Multinode.yml or Multinode-rocky-2021.yml is the file to declare which server either assigned as controller nodes, compute nodes, or network nodes. This file is quite straight forward, the only confusing part is the network interface if there are VLAN involve in the design.


Please do reach me at irsyadsabiq94@gmail.com if you have any questions. Thanks
