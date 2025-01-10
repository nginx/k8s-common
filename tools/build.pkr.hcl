packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "1.1.3"
    }
  }
}

variable "project_id" {
  type = string
}

variable "builder_sa" {
  type = string
}

source "googlecompute" "ngf-image" {
  project_id                  = var.project_id
  source_image_family         = "debian-12"
  zone                        = "us-west1-a"
  image_description           = "Debian VM for NGF testing"
  ssh_username                = "username"
  tags                        = ["test-packer"]
  impersonate_service_account = var.builder_sa
  image_name                  = "ngf-debian-12-{{timestamp}}"
  image_family                = "ngf-debian"
  machine_type                = "n2-standard-4"
}

build {
  sources = ["sources.googlecompute.ngf-image"]

  provisioner "shell" {
    inline = [
      "curl -L https://nixos.org/nix/install -o install-nix.sh",
      "chmod +x install-nix.sh",
      "bash install-nix.sh --daemon",
      "rm install-nix.sh",
      "sed -i '1i. /etc/bashrc' ~/.bashrc"
    ]
  }

  provisioner "file" {
    source      = "packages.nix"
    destination = "/tmp/packages.nix"
  }

  provisioner "file" {
    source      = "license.jwt"
    destination = "/tmp/license.jwt"
  }

  provisioner "shell" {
    inline = [
      "nix-env -if /tmp/packages.nix",
      "sudo apt-get update",
      "sudo apt-get install -y --no-install-recommends --no-install-suggests google-cloud-sdk-gke-gcloud-auth-plugin locales cloud-init",
      "echo 'en_US.UTF-8 UTF-8' | sudo tee /etc/locale.gen",
      "sudo locale-gen",
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'alias k='kubectl'' >> .bashrc",
      "git clone https://github.com/nginxinc/nginx-gateway-fabric.git",
      "cd nginx-gateway-fabric/tests",
      "go mod download",
      "cp /tmp/license.jwt ../license.jwt",
    ]
  }

}
