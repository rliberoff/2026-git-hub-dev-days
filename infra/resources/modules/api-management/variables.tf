variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "publisher_name" {
  type = string
}

variable "publisher_email" {
  type = string
}

variable "sku_name" {
  type = string
}

variable "tokens_per_minute" {
  type = number
}

variable "token_quota" {
  type = number
}

variable "token_quota_period" {
  type = string
}

variable "ratelimit_tokens_per_minute" {
  type = number
}

variable "foundry_account_ids" {
  type = map(string)
}

variable "foundry_endpoints" {
  type = map(string)
}

variable "application_insights_id" {
  type = string
}

variable "application_insights_connection_string" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
}
