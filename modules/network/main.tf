terraform {
  required_version = ">= 1.8.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

variable "env" {
  type = string
}

variable "location" {
  type = string
}

variable "project_name" {
  type = string
}

variable "address_space" {
  type = string
}

locals {
  rg_name   = "${var.project_name}-rg-${var.env}"
  vnet_name = "${var.project_name}-vnet-${var.env}"
}

# --------------------------
# Resource Group
# --------------------------
resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
}

# --------------------------
# Virtual Network
# --------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  address_space       = [var.address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# --------------------------
# Subnets
# --------------------------

resource "azurerm_subnet" "backend" {
  name                 = "snet-backend"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "ia" {
  name                 = "snet-ia"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_subnet" "endpoints" {
  name                 = "snet-endpoints"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.4.0/24"]
}

# --------------------------
# Network Security Groups
# --------------------------

resource "azurerm_network_security_group" "nsg_backend" {
  name                = "nsg-backend-${var.env}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Allow 443 only from Front Door
resource "azurerm_network_security_rule" "backend_allow_frontdoor" {
  name                        = "allow-frontdoor-443"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "AzureFrontDoor.Backend"
  destination_port_range      = "443"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg_backend.name
  resource_group_name         = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "nsg_ia" {
  name                = "nsg-ia-${var.env}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Allow 443 only from backend subnet
resource "azurerm_network_security_rule" "ia_allow_backend" {
  name                        = "allow-backend-443"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "10.10.1.0/24"
  destination_port_range      = "443"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsg_ia.name
  resource_group_name         = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "nsg_endpoints" {
  name                = "nsg-endpoints-${var.env}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Allow backend + ia to access PEs
resource "azurerm_network_security_rule" "pe_allow_backend_ia" {
  name                        = "allow-backend-ia-443"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefixes     = ["10.10.1.0/24", "10.10.2.0/24"]
  destination_port_range      = "443"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_endpoints.name
}

# --------------------------
# Associate NSG to subnets
# --------------------------

resource "azurerm_subnet_network_security_group_association" "backend_assoc" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.nsg_backend.id
}

resource "azurerm_subnet_network_security_group_association" "ia_assoc" {
  subnet_id                 = azurerm_subnet.ia.id
  network_security_group_id = azurerm_network_security_group.nsg_ia.id
}

resource "azurerm_subnet_network_security_group_association" "endpoints_assoc" {
  subnet_id                 = azurerm_subnet.endpoints.id
  network_security_group_id = azurerm_network_security_group.nsg_endpoints.id
}

# --------------------------
# Outputs
# --------------------------

output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "subnet_backend_id" {
  value = azurerm_subnet.backend.id
}

output "subnet_ia_id" {
  value = azurerm_subnet.ia.id
}

output "subnet_endpoints_id" {
  value = azurerm_subnet.endpoints.id
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}
