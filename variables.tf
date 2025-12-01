# General Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-myfirstpipeline"
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "uksouth"
}

variable "environment" {
  description = "Environment name (e.g., dev, test, prod)"
  type        = string
  default     = "dev"
}

# Network Variables
variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "vnet-myfirstpipeline"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vm_subnet_name" {
  description = "Name of the VM subnet"
  type        = string
  default     = "snet-vm"
}

variable "vm_subnet_address_prefix" {
  description = "Address prefix for the VM subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "bastion_subnet_address_prefix" {
  description = "Address prefix for the Bastion subnet (must be /26 or larger)"
  type        = string
  default     = "10.0.2.0/26"
}

# Bastion Variables
variable "bastion_name" {
  description = "Name of the Azure Bastion host"
  type        = string
  default     = "bas-myfirstpipeline"
}

variable "bastion_public_ip_name" {
  description = "Name of the public IP for Bastion"
  type        = string
  default     = "pip-bastion"
}

# VM Variables
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "vm-firstVM"
}

variable "vm_nic_name" {
  description = "Name of the VM network interface"
  type        = string
  default     = "nic-vm"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the virtual machine"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Admin password for the virtual machine"
  type        = string
  sensitive   = true
}
