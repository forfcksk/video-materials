variable "vm_name" {
  description = "Virtual machine name"
  type        = string
  default     = "k8s-worker3"
}

variable "memory" {
  description = "RAM in MiB"
  type        = number
  default     = 6144
}

variable "vcpu" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 4
}

variable "disk_size_gib" {
  description = "OS disk size in GiB"
  type        = number
  default     = 30
}

variable "ssh_public_key" {
  description = "SSH public key for root"
  type        = string
}
