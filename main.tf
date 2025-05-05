# Variables
variable "prefix" {
  default = "Rahul"
  type    = string
}

# Resource Group for Networking
resource "azurerm_resource_group" "network" {
  name     = "${var.prefix}-rg-dev-network-01"
  location = "centralindia"
}

# Resource Group for Application
resource "azurerm_resource_group" "application" {
  name     = "${var.prefix}-rg-dev-application-01"
  location = "centralindia"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet-dev-01"
  address_space       = ["10.1.0.0/20"]
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
}

# Subnets
resource "azurerm_subnet" "web" {
  name                 = "${var.prefix}-snet-dev-web-01"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.0.0/22"]
}

resource "azurerm_subnet" "app" {
  name                 = "${var.prefix}-snet-dev-app-01"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.4.0/22"]
}

resource "azurerm_subnet" "data" {
  name                 = "${var.prefix}-snet-dev-data-01"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.8.0/22"]
}

resource "azurerm_subnet" "pep" {
  name                 = "${var.prefix}-snet-dev-pep-01"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.12.0/22"]
}

# Network Security Groups
resource "azurerm_network_security_group" "web_nsg" {
  name                = "${var.prefix}-nsg-snet-dev-web-01"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_network_security_group" "app_nsg" {
  name                = "${var.prefix}-nsg-snet-dev-app-01"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_network_security_rule" "allow_ssh_from_my_ip" {
  name                        = "Allow-SSH-From-My-IP-01"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*" # Replace with your IP address
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}

resource "azurerm_network_security_rule" "deny_other_ssh" {
  name                        = "Deny-Other-SSH-01"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}

resource "azurerm_network_security_group" "data_nsg" {
  name                = "${var.prefix}-nsg-snet-dev-data-01"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_network_security_group" "pep_nsg" {
  name                = "${var.prefix}-nsg-snet-dev-pep-01"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "pep" {
  subnet_id                 = azurerm_subnet.pep.id
  network_security_group_id = azurerm_network_security_group.pep_nsg.id
}

# Public IP for VM
resource "azurerm_public_ip" "vm_ip" {
  name                = "${var.prefix}-pip-dev-vm-01"
  location            = azurerm_resource_group.application.location
  resource_group_name = azurerm_resource_group.application.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

# NIC for VM
resource "azurerm_network_interface" "dev_vm_nic" {
  name                = "${var.prefix}-nic-dev-vm-01"
  location            = azurerm_resource_group.application.location
  resource_group_name = azurerm_resource_group.application.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_ip.id
  }
}

# VM
resource "azurerm_linux_virtual_machine" "dev_vm" {
  name                  = "${var.prefix}-dev-vm-01"
  location              = azurerm_resource_group.application.location
  resource_group_name   = azurerm_resource_group.application.name
  network_interface_ids = [azurerm_network_interface.dev_vm_nic.id]
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  disable_password_authentication = true
  
  identity {
    type = "SystemAssigned"
  }
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "dev-os-disk-01"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  
  custom_data = fileexists("docker-install.sh") ? filebase64("docker-install.sh") : null
}

# App service plan
resource "azurerm_service_plan" "asp" {
  name                = "${var.prefix}-asp-01"
  resource_group_name = azurerm_resource_group.application.name
  location            = azurerm_resource_group.application.location
  os_type             = "Linux"
  sku_name            = "B1"
}

# Application Insights
resource "azurerm_application_insights" "webapp_insights" {
  name                = "${var.prefix}-appinsights-01"
  location            = azurerm_resource_group.application.location
  resource_group_name = azurerm_resource_group.application.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.monitoring.id
}

# Web app
resource "azurerm_linux_web_app" "webapp" {
  name                = "${var.prefix}-webapp-01"
  resource_group_name = azurerm_resource_group.application.name
  location            = azurerm_service_plan.asp.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.webapp_insights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.webapp_insights.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION" = "~3"
    "XDT_MicrosoftApplicationInsights_Mode" = "recommended"
    "ASPNETCORE_HOSTINGSTARTUPASSEMBLIES" = "Microsoft.ApplicationInsights.StartupBootstrapper"
  }
  public_network_access_enabled = false
}

# Private DNS Zone for Web App
resource "azurerm_private_dns_zone" "webapp_dns" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.network.name
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "webapp_dns_link" {
  name                  = "${var.prefix}-webapp-dns-link-01"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.webapp_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Private Endpoint for Web App
resource "azurerm_private_endpoint" "webapp_pe" {
  name                = "${var.prefix}-pe-webapp-01"
  location            = azurerm_resource_group.application.location
  resource_group_name = azurerm_resource_group.application.name
  subnet_id           = azurerm_subnet.pep.id

  private_service_connection {
    name                           = "${var.prefix}-psc-webapp-01"
    private_connection_resource_id = azurerm_linux_web_app.webapp.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.webapp_dns.id]
  }
}

# Source control for web app
resource "azurerm_app_service_source_control" "scm" {
  app_id    = azurerm_linux_web_app.webapp.id
  repo_url  = "https://github.com/Thuppathi-Rahul/Rahul-capstone-webapp"  
  branch    = "main"
}
