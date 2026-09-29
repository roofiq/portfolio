output "static_web_app_url" {
  description = "Default URL of the portfolio Static Web App."
  value       = "https://${azurerm_static_web_app.portfolio.default_host_name}"
}

output "custom_domain_validation_token" {
  description = "TXT verification token for rglebocki.pl; Azure clears it after validation."
  value       = azurerm_static_web_app_custom_domain.portfolio.validation_token
}
