data "azurerm_resource_group" "portfolio" {
  name = "rg-portfolio-prod"
}

resource "azurerm_static_web_app_custom_domain" "portfolio" {
  static_web_app_id = azurerm_static_web_app.portfolio.id
  domain_name       = "rglebocki.pl"
  validation_type   = "dns-txt-token"
}

resource "azurerm_static_web_app" "portfolio" {
  name                = "swa-portfolio-prod"
  resource_group_name = data.azurerm_resource_group.portfolio.name
  location            = "westeurope"
  sku_tier            = "Free"
  sku_size            = "Free"

  tags = {
    environment = "prod"
    managed_by  = "terraform"
    project     = "portfolio"
  }
}
