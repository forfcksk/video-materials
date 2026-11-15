terraform {
  required_version = ">= 1.9.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "= 0.9.9"
    }
  }
}

provider "libvirt" {
  uri = "qemu+ssh://root@10.13.13.15/system"
}
