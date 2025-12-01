
terraform {
  required_version = ">= 1.6.0"

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"       # Change this
    storage_account_name = "sttfstatess123"           # Change this (must be globally unique)
    container_name       = "tfstatess"                # Usually leave as-is
    key                  = "myfirstpipeline.tfstate"  # Change per project
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "My-First-Pipeline"
    BuildDate   = formatdate("YYYY-MM-DD", timestamp())  # e.g., 2025-12-01
    BuildTime   = formatdate("HH:mm:ss", timestamp())    # e.g., 10:45:00

  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = azurerm_resource_group.main.tags
}

# Subnet for VM
resource "azurerm_subnet" "vm" {
  name                 = var.vm_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.vm_subnet_address_prefix]
}

# Azure Bastion Subnet (must be named exactly "AzureBastionSubnet")
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.bastion_subnet_address_prefix]
}

# Public IP for Bastion
resource "azurerm_public_ip" "bastion" {
  name                = var.bastion_public_ip_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = azurerm_resource_group.main.tags
}

# Azure Bastion Host
resource "azurerm_bastion_host" "main" {
  name                = var.bastion_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = azurerm_resource_group.main.tags
}

# Network Interface for VM
resource "azurerm_network_interface" "main" {
  name                = var.vm_nic_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = azurerm_resource_group.main.tags
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "main" {
  name                = var.vm_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition"
    version   = "latest"
  }

  patch_mode = "AutomaticByPlatform"

  tags = azurerm_resource_group.main.tags
}
