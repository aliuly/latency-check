
# Provider configuration
# Use environment variables (OS_USERNAME, OS_PASSWORD, etc.) for authentication
provider "opentelekomcloud" {
  auth_url = "https://iam.eu-de.otc.t-systems.com/v3"
  region = split("_",var.otc_project_name)[0]
  access_key  = var.otc_access_key
  secret_key  = var.otc_secret_key
  tenant_name = var.otc_project_name
}

