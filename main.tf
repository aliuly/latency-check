variable "cloud_user" {
  type    = string
  default = "clouduser"
  description = "User that will be created by cloud-init"
}

variable "cloud_passwd" {
  type      = string
  description = "Encrypted password use `openssl passwd -6 secret_password` to genrate"
  sensitive = true
  default = "x"
}

variable "cloud_ssh_keys" {
  type = list(string)
  description = "Copy ssh key that will be used to login to this system (there can only be one)"
  default = []
}

locals {
  common_tags = {
    environment = "testing"
    managed_by = "OpenTofu"
  }
  vpc_name = "test-vpc"
  subnet_name = "test-sn"
  #~ os_name           = "Standard_Ubuntu_22.04_latest"
  #~ os_name           = "Standard_Debian_13_amd64_bios_latest"
  #~ os_name           = "Standard_Debian_12_amd64_bios_latest"
  os_name           = "Standard_Ubuntu_24.04_amd64_bios_latest"
}

# 1. Networking: Virtual Private Cloud (VPC)
resource "opentelekomcloud_vpc_v1" "vpc_main" {
  name = local.vpc_name
  tags = local.common_tags
  cidr = "192.168.0.0/16"
}

# 2. Networking: Subnet
resource "opentelekomcloud_vpc_subnet_v1" "sn_main" {
  name       = local.subnet_name
  cidr       = "192.168.1.0/24"
  gateway_ip = "192.168.1.1"
  vpc_id     = opentelekomcloud_vpc_v1.vpc_main.id
  tags = local.common_tags
}

# 3. Security: Security Group for SSH & HTTP & HTTPS
resource "opentelekomcloud_networking_secgroup_v2" "sg_test" {
  name        = "sg-testing-access"
  description = "Allow SSH and HTTP(S)"
}

resource "opentelekomcloud_networking_secgroup_rule_v2" "allow_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = opentelekomcloud_networking_secgroup_v2.sg_test.id
}

resource "opentelekomcloud_networking_secgroup_rule_v2" "allow_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = opentelekomcloud_networking_secgroup_v2.sg_test.id
}

resource "opentelekomcloud_networking_secgroup_rule_v2" "allow_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = opentelekomcloud_networking_secgroup_v2.sg_test.id
}

# 4. Compute: The VM (Elastic Cloud Server)
resource "opentelekomcloud_compute_instance_v2" "test_vm" {
  name            = "customer-test-vm"
  #~ image_name      = var.os_name
  flavor_name     = "s9.medium.1"
  #~ key_pair        = "your-ssh-key-name" # Must exist in T Cloud console
  security_groups = [opentelekomcloud_networking_secgroup_v2.sg_test.name]

  network {
    uuid = opentelekomcloud_vpc_subnet_v1.sn_main.id
  }

  # 1. System Disk (Bootable)
  block_device {
    uuid                  = data.opentelekomcloud_images_image_v2.image.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 20   # System Disk: 20 GB
    delete_on_termination = true
  }

  # Cloud-init configuration
  user_data = replace(templatefile("${path.module}/cloud-init.yaml", {
      hostname = "test-vm"
      user = var.cloud_user
      passwd = var.cloud_passwd
      ssh_keys = var.cloud_ssh_keys
      region = split("_",var.otc_project_name)[0]
    }), "\r", "")

  tags = local.common_tags
}

# Add a data source for the image to get its ID for the block_device block
data "opentelekomcloud_images_image_v2" "image" {
  name = local.os_name
  most_recent = true
}

# Create the Elastic IP
resource "opentelekomcloud_vpc_eip_v1" "my_eip" {
  publicip {
    type = "5_bgp" # Standard BGP type for Open Telekom Cloud
  }
  bandwidth {
    name       = "testing-bandwidth"
    size       = 5 # Bandwidth in Mbps
    share_type = "PER"
    charge_mode = "traffic"
  }
}

# Associate the EIP with the VM
resource "opentelekomcloud_networking_floatingip_associate_v2" "eip_assoc" {
  floating_ip = opentelekomcloud_vpc_eip_v1.my_eip.publicip[0].ip_address
  port_id     = opentelekomcloud_compute_instance_v2.test_vm.network[0].port
}


# Output the Elastic IP
output "vm_eip" {
  value = opentelekomcloud_vpc_eip_v1.my_eip.publicip[0].ip_address
}

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = ">= 1.35.0"
    }
  }
}
