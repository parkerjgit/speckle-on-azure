variable "resource_group_name" {
  description = "Name of resource group"
  type        = string
}
variable "env" {
  description = "Name of environment"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "AWS region"
  type        = string
  default     = "eastus"
}

variable "namespace" {
  description = "Resource namespace (prefix)"
  type        = string
  default     = "saz"
}

variable "project" {
  description = "Project name (no spaces)"
  type        = string
  default     = "speckle-on-azure"
}

variable "db_username" {
  description = "Delivery Management database user name"
  type        = string
}

variable "db_password" {
  description = "Delivery Management database user password"
  type        = string
}