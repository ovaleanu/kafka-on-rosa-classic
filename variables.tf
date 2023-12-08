variable "token" {
  type      = string
  sensitive = true
}

variable "url" {
  type        = string
  description = "Provide OCM environment by setting a value to url"
  default     = "https://api.openshift.com"
}

variable "operator_role_prefix" {
  type    = string
  default = "kafka-on-rosa"
}

variable "account_role_prefix" {
  type    = string
  default = "kafka-on-rosa"
}

variable "cluster_name" {
  type    = string
  default = "kafka-on-rosa"
}

variable "username" {
  description = "Admin username that will be created with the cluster"
  type        = string
  default     = "cluster-admin"
}

variable "openshift_version" {
  type    = string
  default = "4.14.4"
}

variable "tags" {
  description = "List of AWS resource tags to apply."
  type        = map(string)
  default = {
    "rosa_cluster" = "kafka"
  }
}

variable "cloud_region" {
  type    = string
  default = "eu-central-1"
}

variable "multi_az" {
  type    = bool
  default = true
}

variable "machine_cidr" {
  description = "Block of IP addresses for nodes"
  type        = string
  default     = "10.1.0.0/16"
}

variable "ocm_environment" {
  type    = string
  default = "production"
}

variable "path" {
  description = "(Optional) The arn path for the account/operator roles as well as their policies."
  type        = string
  default     = null
}
