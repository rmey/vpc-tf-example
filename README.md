# IBM Cloud VPC Terraform example 
The following project could be used as starting point to create a bunch of resources in IBM Cloud. It uses the following capabilities:
- for_each Terraform Meta-Arguments to created many resources
- Definition of IBM Cloud components:
    - Resource Groups
    - IAM Group Policies
    - VPCs, Subnets, ACL, Security Groups, Floating IPs
    - VSIs
    - Service instances (COS, Cloud Logging)
- Terraform remote file provisioning and remote-exec of script including null_resource and argument passing with Terraform (this could be handled much better with Ansible), to install needed software packages for workshop and add users to the VSI instances (example [script.sh](./script.sh))

The concrete example creates for each use a separate Resource Group, VPC, Logging Instance and Ubuntu VSI. On each Ubuntu VSI Terraform executes a script with the username and Linux password hash, which will be created in the machine. This is only an example on how to use parameters in remote-exec of Terraform. In my case the workshop attendees I create the envioronments for could not use private keys for SSH logins. The Linux password hashes could be created with:
```bash
echo <YOURREALLYSECUREPASSWORD> | mkpasswd -s
```
## Prerequisites
- Install the [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) for your operating system.
- Create an [IBM Cloud API Key](https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui) with appropiate permissions.
- clone the Git repository

## How to use
1. From within the cloned git repo folder execute the following command
    ```bash
    export TF_VAR_ibmcloud_api_key=<YOUR IBM Cloud API Key>
    ```
2. From within the cloned git repo folder execute the following command
    ```bash
    cp terraform.tfvars-template terraform.tfvars
    ```
3. Adopt the values in the file terraform.tfvars list of map items. Each list items has the following attributes.
    ```bash
    name       = "rg1"    # the Resource Group Name
    vpc_name   = "vpc1"   # the name of the VPC created
    vpc_cidr   = "10.242.0.0/24" # CIDR of the VPC subnet
    vpc_zone   = "eu-gb-1" # the zone the VPC will be created
    user_group = "usergroup1" # the IAM access group created
    logname    = "log1" # the name of the Cloud logging instance created
    vsi_name   = "vsi1" # the name of the VSI created
    namespace  = "ns-tk-ws-1" # the Container Registry Namespace created
    pub_sshkey = ".ssh/mykey1.pub" # the public ssh key for the root user
    sshkey     = ".ssh/mykey1" # the private ssh key for the root user
    profile    = "cx2-2x4" # the profile of the VSI 
    vsi_image  = "ibm-ubuntu-22-04-1-minimal-amd64-4" # the image of the VSI
    username   = "user1" # the normal username created by the script.sh with password based login (only example)
    pwdhash   = "$6...." # the Linux password hash (could be created with mkpassword)
    ```

4. Run Terraform init
    ```bash
    # this will install the IBM Cloud Terraform plugin
    terraform init
    ```
5. Run Terraform plan
    ```bash
    terraform plan
    ```
6. Run Terraform apply
    ```bash
    terraform apply
    ```
    Watch also the script execution [script.sh](./script.sh) which is executed if the VSI is ready and the public floating IP is assigned. Review the resources created in the IBM Cloud Console.
6. Run Terraform destroy to destroy all resources created before.
    ```bash
    terraform destroy
    ```
## References
The following articles were really helpful in achieving my goals:
- [Example with Terraform null_resource in IBM Cloud Patterns](https://ibm.github.io/cloud-enterprise-examples/iac-conf-mgmt/ansible/)
- [Terraform for_each docs](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- [Terraform remote-exec with arguments to script](https://developer.hashicorp.com/terraform/language/resources/provisioners/remote-exec#script-arguments)
- [IBM Cloud Terraform Provider documentation](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs)


