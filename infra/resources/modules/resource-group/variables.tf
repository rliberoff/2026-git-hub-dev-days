variable "name" {
  description = "Required resource group name."
  type        = string
  nullable    = false
}

variable "location" {
  description = "Required Azure region."
  type        = string
  nullable    = false
}

variable "tags" {
  description = "Required resource tags."
  type        = map(string)
  nullable    = false
}
