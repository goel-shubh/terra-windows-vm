provider "azurerm" {
    subscription_id = "your subscription id"
    client_id       = "enter client id"
    client_secret   = "enter client secret key"
    tenant_id       = "enter tenant id"
}
#Variables
variable "rsg"         { default = "EXTEDO_US_EASTUS" }
variable "location"    { default = "East US" }
variable "hostname"    { default = "EXTPSUS1" }
variable "username"    { default = "shubham	" }
variable "password"    { default = "Password@123" }
variable "vmsize"      { default = "Basic_A2" } 
variable "storagetype" { default = "Standard_LRS" } 
variable "add-space"   { default = "10.0.2.0/24" }
variable "add-subnet1" { default = "10.0.2.0/24" }
variable "sku"         { default = "2016-Datacenter" }
variable "environment" { default = "Publishing"}


# Build the Resource Group 
resource "azurerm_resource_group" "rsg" {
  name     = "${var.rsg}"
  location = "${var.location}"
}

# Build the Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.rsg}-vnet"
  address_space       = ["${var.add-space}"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rsg.name}"
}

# Build subnet
resource "azurerm_subnet" "subnet1" {
  name                 = "mysubnet"
  resource_group_name  = "${azurerm_resource_group.rsg.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "${var.add-subnet1}"
}


# Create Public IP
resource "azurerm_public_ip" "pip" {
  name                         = "${var.hostname}-pip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.rsg.name}"
  public_ip_address_allocation = "static"

  tags {
    environment = "Production"
  }
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.rsg}-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rsg.name}"

  security_rule {
    name                       = "RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 3389
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "Production"
  }
}


# Set the private and public IP 
resource "azurerm_network_interface" "ni" {
  name                      = "${var.hostname}-ni"
  location                  = "${var.location}"
  resource_group_name       = "${azurerm_resource_group.rsg.name}"
  network_security_group_id = "${azurerm_network_security_group.nsg.id}"

  # dynamic IP configuration
  ip_configuration {
    name                          = "${var.hostname}-ipconfig"
    subnet_id                     = "${azurerm_subnet.subnet1.id}"
    private_ip_address_allocation = "dynamic"
  }
}



# Build Virtual Machine
resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.hostname}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.rsg.name}"
  network_interface_ids = ["${azurerm_network_interface.ni.id}"]
  vm_size               = "${var.vmsize}"

  storage_os_disk {
    name          = "${var.hostname}-osdisk"
    caching       = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "${var.storagetype}"
  }
  
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "${var.sku}"
    version   = "latest"
  }

  os_profile {
    computer_name  = "${var.hostname}"
    admin_username = "${var.username}"
    admin_password = "${var.password}"
  }
   os_profile_windows_config {
        enable_automatic_upgrades = false
    }

  tags {
    environment = "production"
  }
}