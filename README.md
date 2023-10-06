# Usage (from a Ubuntu 22.04 host)

[![Lint](https://github.com/rgl/terraform-proxmox-debian-example/actions/workflows/lint.yml/badge.svg)](https://github.com/rgl/terraform-proxmox-debian-example/actions/workflows/lint.yml)

Create and install the [base Debian 12 vagrant box](https://github.com/rgl/debian-vagrant).

In the Proxmox Virtual Environment web management interface, tag the
`template-debian-12` template with the `debian-12` and `template` tags.

Install Terraform:

```bash
wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
unzip terraform_1.5.7_linux_amd64.zip
sudo install terraform /usr/local/bin
rm terraform terraform_*_linux_amd64.zip
```

Set your proxmox details:

```bash
# see https://registry.terraform.io/providers/bpg/proxmox/latest/docs#argument-reference
# see https://github.com/bpg/terraform-provider-proxmox/blob/v0.33.0/proxmoxtf/provider/provider.go#L47-L53
cat >secrets-proxmox.sh <<EOF
export PROXMOX_VE_INSECURE='1'
export PROXMOX_VE_ENDPOINT='https://192.168.1.21:8006'
export PROXMOX_VE_USERNAME='root@pam'
export PROXMOX_VE_PASSWORD='vagrant'
EOF
source secrets-proxmox.sh
```

Create the infrastructure:

```bash
terraform init
terraform plan -out=tfplan
time terraform apply tfplan
```

Login into the machine:

```bash
ssh-keygen -f ~/.ssh/known_hosts -R "$(terraform output --raw ip)"
ssh "vagrant@$(terraform output --raw ip)"
```

Destroy the infrastructure:

```bash
time terraform destroy -auto-approve
```
