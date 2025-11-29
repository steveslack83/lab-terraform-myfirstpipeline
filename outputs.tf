# Resource Group Outputs
output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "The location of the resource group"
  value       = azurerm_resource_group.main.location
}

# Network Outputs
output "vnet_name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vm_subnet_id" {
  description = "The ID of the VM subnet"
  value       = azurerm_subnet.vm.id
}

output "bastion_subnet_id" {
  description = "The ID of the Bastion subnet"
  value       = azurerm_subnet.bastion.id
}

# Bastion Outputs
output "bastion_name" {
  description = "The name of the Azure Bastion host"
  value       = azurerm_bastion_host.main.name
}

output "bastion_public_ip" {
  description = "The public IP address of the Bastion host"
  value       = azurerm_public_ip.bastion.ip_address
}

# VM Outputs
output "vm_name" {
  description = "The name of the virtual machine"
  value       = azurerm_windows_virtual_machine.main.name
}

output "vm_id" {
  description = "The ID of the virtual machine"
  value       = azurerm_windows_virtual_machine.main.id
}

output "vm_private_ip" {
  description = "The private IP address of the virtual machine"
  value       = azurerm_network_interface.main.private_ip_address
}

output "admin_username" {
  description = "The admin username for the VM"
  value       = azurerm_windows_virtual_machine.main.admin_username
}

# Connection Instructions
output "connection_instructions" {
  description = "Instructions for connecting to the VM via Bastion"
  value       = <<-EOT
    To connect to your Windows Server 2025 VM:
    1. Go to the Azure Portal (https://portal.azure.com)
    2. Navigate to your VM: ${azurerm_windows_virtual_machine.main.name}
    3. Click 'Connect' → 'Bastion'
    4. Enter username: ${azurerm_windows_virtual_machine.main.admin_username}
    5. Enter the admin password you configured
    6. Click 'Connect' to open Remote Desktop session
    
    VM Private IP: ${azurerm_network_interface.main.private_ip_address}
    OS: Windows Server 2025 Datacenter (Azure Edition)
  EOT
}
