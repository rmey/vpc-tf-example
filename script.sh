#/bin/bash
# enable plain passwords because workshop attendies are unable to use private keys from Cloud Shell
rm -f /etc/ssh/sshd_config.d/50-cloudimg-settings.conf
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
# update the system and install required packages
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl gnupg unattended-upgrades git jq qemu binfmt-support qemu-user-static
# install ibm cloud CLI
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
# install all ibm cloud cli plugins in root account
ibmcloud plugin install --all -f
# install docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable docker
systemctl start docker  
# install terraform
apt-get update -y && apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
apt update -y
apt-get install -y terraform
# add user with password hash called from Terraform remote-exec
useradd -m -p "${1}" -s /bin/bash -g users -G docker $2
su -s /bin/bash -c "ibmcloud plugin install --all -f" $2
