output "static_web_app_url" {
  description = "Default URL of the portfolio Static Web App."
  value       = "https://${azurerm_static_web_app.portfolio.default_host_name}"
}
