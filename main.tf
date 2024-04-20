# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.8.1"
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.6.1"
    }
    # see https://registry.terraform.io/providers/bpg/proxmox
    # see https://github.com/bpg/terraform-provider-proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.54.0"
    }
  }
}

provider "proxmox" {
}

variable "prefix" {
  type    = string
  default = "example-terraform-debian"
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.54.0/docs/data-sources/virtual_environment_vms
data "proxmox_virtual_environment_vms" "debian_templates" {
  tags = ["debian-12", "template"]
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.54.0/docs/data-sources/virtual_environment_vm
data "proxmox_virtual_environment_vm" "debian_template" {
  node_name = data.proxmox_virtual_environment_vms.debian_templates.vms[0].node_name
  vm_id     = data.proxmox_virtual_environment_vms.debian_templates.vms[0].vm_id
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.54.0/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "example" {
  name      = var.prefix
  node_name = "pve"
  tags      = sort(["debian-12", "example", "terraform"])
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
  tpm_state {
    version = "v2.0"
  }
  agent {
    enabled = true
    trim    = true
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
      , <<-EOF
      sudo apt-get update
      sudo apt-get install -y tpm2-tools
      sudo systemd-cryptenroll --tpm2-device=list
      sudo tpm2 getekcertificate | openssl x509 -text -noout
      sudo tpm2 pcrread
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
