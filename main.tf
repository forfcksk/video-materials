locals {
  base_image_path = "/var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img"
  cloudinit_name  = "${var.vm_name}-cloudinit.iso"
  os_disk_name    = "${var.vm_name}.qcow2"
}

resource "libvirt_volume" "os" {
  name     = local.os_disk_name
  pool     = "default"
  capacity = var.disk_size_gib * 1024 * 1024 * 1024

  backing_store = {
    path = local.base_image_path
    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_cloudinit_disk" "init" {
  name = "${var.vm_name}-init"

  user_data = templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
    hostname       = var.vm_name
    ssh_public_key = var.ssh_public_key
  })

  meta_data = yamlencode({
    instance-id    = var.vm_name
    local-hostname = var.vm_name
  })
}

resource "libvirt_volume" "cloudinit" {
  name = local.cloudinit_name
  pool = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.init.path
    }
  }

  target = {
    format = {
      type = "iso"
    }
  }
}

resource "libvirt_domain" "vm" {
  name   = var.vm_name
  type   = "kvm"
  memory = var.memory * 1024
  vcpu   = var.vcpu

  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type      = "hvm"
    type_arch = "x86_64"
  }

  autostart = true

  devices = {
    disks = [
      {
        device = "disk"

        driver = {
          name = "qemu"
          type = "qcow2"
        }

        source = {
          volume = {
            pool   = "default"
            volume = libvirt_volume.os.name
          }
        }

        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"

        source = {
          volume = {
            pool   = "default"
            volume = libvirt_volume.cloudinit.name
          }
        }

        target = {
          dev = "sda"
          bus = "sata"
        }

        readonly = true
      }
    ]

    interfaces = [
      {
        source = {
          network = {
            network = "lab-net"
          }
        }

        model = {
          type = "virtio"
        }
      }
    ]
  }
}

output "vm_name" {
  value = libvirt_domain.vm.name
}

output "os_disk_path" {
  value = libvirt_volume.os.path
}

output "cloudinit_disk_path" {
  value = libvirt_volume.cloudinit.path
}

# Second worker without GPU
resource "libvirt_volume" "worker4_os" {
  name     = "k8s-worker4.qcow2"
  pool     = "default"
  capacity = 30 * 1024 * 1024 * 1024

  backing_store = {
    path   = local.base_image_path
    format = { type = "qcow2" }
  }

  target = {
    format = { type = "qcow2" }
  }
}

resource "libvirt_cloudinit_disk" "worker4_init" {
  name = "k8s-worker4-init"

  user_data = templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
    hostname       = "k8s-worker4"
    ssh_public_key = var.ssh_public_key
  })

  meta_data = yamlencode({
    instance-id    = "k8s-worker4"
    local-hostname = "k8s-worker4"
  })
}

resource "libvirt_volume" "worker4_cloudinit" {
  name = "k8s-worker4-cloudinit.iso"
  pool = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.worker4_init.path
    }
  }

  target = {
    format = { type = "iso" }
  }
}

resource "libvirt_domain" "worker4_vm" {
  name   = "k8s-worker4"
  type   = "kvm"
  memory = 4096 * 1024
  vcpu   = 2

  cpu = {
    mode = "host-passthrough"
  }
  autostart = true

  os = {
    type      = "hvm"
    type_arch = "x86_64"
  }

  devices = {
    disks = [
      {
        device = "disk"
        driver = { name = "qemu", type = "qcow2" }
        source = {
          volume = {
            pool   = "default"
            volume = libvirt_volume.worker4_os.name
          }
        }
        target = { dev = "vda", bus = "virtio" }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = "default"
            volume = libvirt_volume.worker4_cloudinit.name
          }
        }
        target   = { dev = "sda", bus = "sata" }
        readonly = true
      }
    ]

    interfaces = [
      {
        source = { network = { network = "lab-net" } }
        model  = { type = "virtio" }
      }
    ]
  }
}
