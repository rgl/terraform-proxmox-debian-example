# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.6.4"
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    # see https://registry.terraform.io/providers/hashicorp/template
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
    # see https://registry.terraform.io/providers/bpg/proxmox
    # see https://github.com/bpg/terraform-provider-proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.38.1"
    }
  }
}

provider "proxmox" {
}

variable "prefix" {
  type    = string
  default = "terraform-example"
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.38.1/docs/data-sources/virtual_environment_vms
data "proxmox_virtual_environment_vms" "debian_templates" {
  tags = ["debian-12", "template"]
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.38.1/docs/data-sources/virtual_environment_vm
data "proxmox_virtual_environment_vm" "debian_template" {
  node_name = data.proxmox_virtual_environment_vms.debian_templates.vms[0].node_name
  vm_id     = data.proxmox_virtual_environment_vms.debian_templates.vms[0].vm_id
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.38.1/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "example" {
  name      = var.prefix
  node_name = "pve"
  tags      = ["debian-12", "example", "terraform"]
  clone {
    vm_id = data.proxmox_virtual_environment_vm.debian_template.vm_id
    full  = false
  }
  cpu {
    type  = "host"
    cores = 4
  }
  memory {
    dedicated = 4 * 1024
  }
  network_device {
    bridge = "vmbr0"
  }
  disk {
    interface   = "scsi0"
    file_format = "raw"
    iothread    = true
    ssd         = true
    discard     = "on"
    size        = 40
  }
  agent {
    enabled = true
  }
  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
  provisioner "remote-exec" {
    inline = [
      <<-EOF
      cloud-init status --long --wait
      set -x
      id
      uname -a
      cat /etc/os-release
      echo "machine-id is $(cat /etc/machine-id)"
      hostname --fqdn
      cat /etc/hosts
      sudo sfdisk -l
      lsblk -x KNAME -o KNAME,SIZE,TRAN,SUBSYSTEMS,FSTYPE,UUID,LABEL,MODEL,SERIAL
      mount | grep ^/dev
      df -h
      EOF
    ]
    connection {
      type     = "ssh"
      host     = self.ipv4_addresses[index(self.network_interface_names, "eth0")][0]
      user     = "vagrant"
      password = "vagrant"
    }
  }
}

output "ip" {
  value = proxmox_virtual_environment_vm.example.ipv4_addresses[index(proxmox_virtual_environment_vm.example.network_interface_names, "eth0")][0]
}
