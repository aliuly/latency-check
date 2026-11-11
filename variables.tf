variable "otc_access_key" {
  type        = string
  description = "T Cloud Public Access Key (AK)"
  sensitive   = true
}

variable "otc_secret_key" {
  type        = string
  description = "T Cloud Public Secret Key (SK)"
  sensitive   = true
}

variable "otc_project_name" {
  type    = string
  description = "Project (or region) to deploy the resources on"
  # default = "eu-de_your_project"
}


