variable "aws_region" {
  type        = string
}
variable "aws_owner" {
  type        = string
}
variable "aws_access_key" {
  type        = string
}
variable "aws_secret_key" {
  type        = string
}

variable "public_key_file_path" {
  type        = string
}
variable "confluent_cloud_api_key" {
  description = "Cloud API key"
  type        = string
  default     = ""
}

variable "confluent_cloud_api_secret" {
  description = "Cloud API secret"
  type        = string
  default     = ""
}

variable "region" {
  description = "Cloud region"
  type        = string
}

variable "sr_region" {
  description = "Cloud region"
  type        = string
  default     = "sgreg-6"
}

variable "cloud" {
  description = "Cloud provider"
  type        = string
  default     = "GCP"
}

variable "confluent_cloud_environment" {
  description = "Name of environment on CCloud"
  type        = string
  default     = ""
}


variable "db_password" {
  type        = string
}
variable "open_api_key" {
  type        = string
}







