# our list of objects
variable "resource_groups" {
  type = map(object({
    name       = string
    vpc_name   = string
    vpc_cidr   = string
    vpc_zone   = string
    user_group = string
    logname    = string
    cosname    = string
    vsi_name   = string
    namespace  = string
    pub_sshkey = string
    sshkey     = string
    profile    = string
    vsi_image  = string
    username   = string
    pwdhash    = string
  }))
}

# IAM resource groups
resource "ibm_resource_group" "rg" {
  for_each = var.resource_groups
  name     = each.value.name
}
# IAM access groups
resource "ibm_iam_access_group" "ag" {
  for_each    = var.resource_groups
  name        = each.value.user_group
  description = each.value.user_group
}
# Container Registry namespaces
resource "ibm_cr_namespace" "ns" {
  for_each          = var.resource_groups
  name              = each.value.namespace
  resource_group_id = ibm_resource_group.rg[each.key].id
}
# Cloud Logging Instances
resource "ibm_resource_instance" "log" {
  for_each          = var.resource_groups
  name              = each.value.logname
  resource_group_id = ibm_resource_group.rg[each.key].id
  service           = "logdna"
  plan              = "7-day"
  location          = var.region
}

# COS Instances
resource "ibm_resource_instance" "cos_instance" {
  for_each          = var.resource_groups
  name              = each.value.cosname
  resource_group_id = ibm_resource_group.rg[each.key].id
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
}

# VPC
resource "ibm_is_vpc" "vpc" {
  for_each                    = var.resource_groups
  name                        = each.value.vpc_name
  resource_group              = ibm_resource_group.rg[each.key].id
  classic_access              = false
  default_network_acl_name    = "${each.value.vpc_name}-acl"
  default_security_group_name = "${each.value.vpc_name}-sg"
}

# VPC SG rule port 22 ssh
resource "ibm_is_security_group_rule" "sgr-1" {
  for_each  = var.resource_groups
  group     = ibm_is_vpc.vpc[each.key].default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 22
    port_max = 22
  }
}
# VPC SG rule port 8080 vsi
resource "ibm_is_security_group_rule" "sgr-2" {
  for_each  = var.resource_groups
  group     = ibm_is_vpc.vpc[each.key].default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 8080
    port_max = 8080
  }
}
# VPC SG rule port 8443
resource "ibm_is_security_group_rule" "sgr-3" {
  for_each  = var.resource_groups
  group     = ibm_is_vpc.vpc[each.key].default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 8443
    port_max = 8443
  }
}

# VPC Subnet
resource "ibm_is_subnet" "subnet" {
  for_each        = var.resource_groups
  name            = "${each.value.vpc_name}-subnet"
  resource_group  = ibm_resource_group.rg[each.key].id
  vpc             = ibm_is_vpc.vpc[each.key].id
  zone            = each.value.vpc_zone
  ipv4_cidr_block = each.value.vpc_cidr
}
# VPC Public Gateway
resource "ibm_is_public_gateway" "pgw" {
  for_each       = var.resource_groups
  name           = "${each.value.vpc_name}-pgw"
  resource_group = ibm_resource_group.rg[each.key].id
  vpc            = ibm_is_vpc.vpc[each.key].id
  zone           = each.value.vpc_zone
}
# VPC Public Gateway Attachment
resource "ibm_is_subnet_public_gateway_attachment" "pgwa" {
  for_each       = var.resource_groups
  subnet         = ibm_is_subnet.subnet[each.key].id
  public_gateway = ibm_is_public_gateway.pgw[each.key].id
}

# VPC ssh key
resource "ibm_is_ssh_key" "sshkey" {
  for_each       = var.resource_groups
  name           = "${each.value.vpc_name}-sshkey"
  resource_group = ibm_resource_group.rg[each.key].id
  public_key     = file("${each.value.pub_sshkey}")
}

# VPC VSI
# get image
data "ibm_is_image" "image" {
  for_each = var.resource_groups
  name     = each.value.vsi_image
}
# create VSI
resource "ibm_is_instance" "vsi" {
  for_each = var.resource_groups
  name     = each.value.vsi_name
  resource_group = ibm_resource_group.rg[each.key].id
  vpc   = ibm_is_vpc.vpc[each.key].id
  primary_network_interface {
    subnet = ibm_is_subnet.subnet[each.key].id
    security_groups = [ibm_is_vpc.vpc[each.key].default_security_group]
  }
  zone      = each.value.vpc_zone
  profile   = each.value.profile
  image     = data.ibm_is_image.image[each.key].id
  keys      = [ibm_is_ssh_key.sshkey[each.key].id]
  #user_data = file("userdata.txt")
}
# attach VPC Floating IP
resource "ibm_is_floating_ip" "fip" {
  for_each = var.resource_groups
  name           = "${each.value.vpc_name}-fip"
  target = ibm_is_instance.vsi[each.key].primary_network_interface[0].id
  resource_group = ibm_resource_group.rg[each.key].id
}

resource "null_resource" "waiter" {
  for_each = var.resource_groups
  depends_on = [ibm_is_instance.vsi, ibm_is_floating_ip.fip]
  provisioner "file" {
    source      = "${path.module}/script.sh"
    destination = "/tmp/script.sh"
    connection {
      user = "root"
      host = ibm_is_floating_ip.fip[each.key].address
      private_key = file("${each.value.sshkey}")
      timeout = "2m"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "/tmp/script.sh '${each.value.pwdhash}' ${each.value.username} ",
    ]
    connection {
      user = "root"
      host = ibm_is_floating_ip.fip[each.key].address
      private_key = file("${each.value.sshkey}")
      timeout = "2m"
    }
  }
}

########### IAM mess ######################################
# Permission on Container Registry Namespace
resource "ibm_iam_access_group_policy" "cr-pol" {
  for_each        = var.resource_groups
  access_group_id = ibm_iam_access_group.ag[each.key].id
  roles           = ["Reader", "Writer", "Manager", "Viewer", "Operator", "Editor", "Administrator"]
  resource_attributes {
    name     = "region"
    operator = "stringEquals"
    value    = var.region
  }
  resource_attributes {
    name     = "serviceName"
    operator = "stringEquals"
    value    = "container-registry"
  }
  resource_attributes {
    name     = "resource"
    operator = "stringEquals"
    value    = each.value.namespace
  }
  resource_attributes {
    name     = "resourceType"
    operator = "stringEquals"
    value    = "namespace"
  }
}
# Permission on IBM Cloud Logging Instance
resource "ibm_iam_access_group_policy" "log-pol" {
  for_each        = var.resource_groups
  access_group_id = ibm_iam_access_group.ag[each.key].id
  roles           = ["Reader", "Manager", "Standard Member", "Viewer", "Operator", "Editor", "Administrator"]
  resource_attributes {
    name     = "resourceGroupId"
    operator = "stringEquals"
    value    = ibm_resource_group.rg[each.key].id
  }
  resource_attributes {
    name  = "serviceName"
    value = "logdna"
  }
}
# Permission on Resource Group
resource "ibm_iam_access_group_policy" "rg-pol" {
  for_each        = var.resource_groups
  access_group_id = ibm_iam_access_group.ag[each.key].id
  roles           = ["Administrator"]
  resources {
    resource_type = "resource-group"
    resource      = ibm_resource_group.rg[each.key].id
  }
}
# Permission on global catalog
resource "ibm_iam_access_group_policy" "catalog-pol" {
  for_each        = var.resource_groups
  access_group_id = ibm_iam_access_group.ag[each.key].id
  roles           = ["Administrator"]
  resource_attributes {
    name     = "resourceGroupId"
    operator = "stringEquals"
    value    = ibm_resource_group.rg[each.key].id
  }
  resource_attributes {
    name     = "serviceName"
    operator = "stringEquals"
    value    = "globalcatalog"
  }
}

# Permission on HPCS
resource "ibm_iam_access_group_policy" "hpcs-pol" {
  for_each        = var.resource_groups
  access_group_id = ibm_iam_access_group.ag[each.key].id
  roles           = ["Manager", "Reader Plus", "VMWare KMIP Manager", "Vault Administrator", "Key Custodian - Deployer", "Key Custodian - Creator", "KMS Key Purge Role", "Certificate Manager", "Administrator"]
  resource_attributes {
    name     = "resourceGroupId"
    operator = "stringEquals"
    value    = ibm_resource_group.rg[each.key].id
  }
  resource_attributes {
    name     = "serviceName"
    operator = "stringEquals"
    value    = "hs-crypto"
  }
}
# Permission on VPC
resource "ibm_iam_access_group_policy" "vpc-pol" {
  for_each        = var.resource_groups
  access_group_id = ibm_iam_access_group.ag[each.key].id

  roles = ["Administrator", "Console Administrator", "VPN Client", "Manager"]
  resource_attributes {
    name     = "resourceGroupId"
    operator = "stringEquals"
    value    = ibm_resource_group.rg[each.key].id
  }
  resource_attributes {
    name     = "serviceName"
    operator = "stringEquals"
    value    = "is"
  }
}

