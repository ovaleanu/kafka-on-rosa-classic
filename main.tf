#
# Copyright (c) 2022 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.20.0"
    }
    rhcs = {
      version = ">= 1.5.0"
      source  = "terraform-redhat/rhcs"
    }
  }
}

provider "rhcs" {
  token = var.token
  url   = var.url
}

provider "aws" {
  region = local.region
}

data "rhcs_policies" "all_policies" {}
data "rhcs_versions" "all" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  path = coalesce(var.path, "/")

  sts_roles = {
    role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role_prefix}-Installer-Role",
    support_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role_prefix}-Support-Role",
    instance_iam_roles = {
      master_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role_prefix}-ControlPlane-Role",
      worker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role_prefix}-Worker-Role"
    },

    operator_role_prefix = var.operator_role_prefix,
    oidc_config_id       = module.oidc_config.id
  }

  name   = var.cluster_name
  region = var.cloud_region

  account_id = data.aws_caller_identity.current.account_id
  version    = var.openshift_version

  machine_cidr = var.machine_cidr
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
}

# Create managed OIDC config
module "oidc_config" {
  token                = var.token
  url                  = var.url
  source               = "./oidc_provider"
  managed              = true
  operator_role_prefix = var.operator_role_prefix
  account_role_prefix  = var.account_role_prefix
  tags                 = var.tags
  path                 = var.path
}

module "create_account_roles" {
  source  = "terraform-redhat/rosa-sts/aws"
  version = ">=0.0.14"

  create_operator_roles = false
  create_oidc_provider  = false
  create_account_roles  = true

  account_role_prefix    = var.account_role_prefix
  ocm_environment        = var.ocm_environment
  rosa_openshift_version = join(".", slice(split(".", local.version), 0, 2))
  account_role_policies  = data.rhcs_policies.all_policies.account_role_policies
  operator_role_policies = data.rhcs_policies.all_policies.operator_role_policies
  all_versions           = data.rhcs_versions.all
  path                   = var.path
  tags                   = var.tags
}

resource "rhcs_cluster_rosa_classic" "rosa_kafka_cluster" {
  name           = local.name
  sts            = local.sts_roles
  cloud_region   = local.region
  aws_account_id = local.account_id

  availability_zones = local.azs
  multi_az           = var.multi_az

  version                     = local.version
  machine_cidr                = local.machine_cidr
  worker_disk_size            = 300
  compute_machine_type        = "m5.xlarge"
  autoscaling_enabled         = true
  min_replicas                = 3
  max_replicas                = 6
  ec2_metadata_http_tokens    = "required"
  default_mp_labels           = { "MachinePool" = "core" }
  disable_workload_monitoring = true

  properties = {
    rosa_creator_arn = data.aws_caller_identity.current.arn
  }

  admin_credentials = {
    username = var.username,
    password = data.aws_secretsmanager_secret_version.admin_password_version.secret_string
  }

  wait_for_create_complete = true

  depends_on = [module.create_account_roles]
}

resource "rhcs_machine_pool" "kafka_machine_pool" {
  cluster             = rhcs_cluster_rosa_classic.rosa_kafka_cluster.id
  name                = "kafka"
  machine_type        = "r6i.2xlarge"
  disk_size           = 1000
  autoscaling_enabled = true
  min_replicas        = 3
  max_replicas        = 12
  labels              = { "MachinePool" = "kafka" }
  taints = [{
    key           = "dedicated",
    value         = "kafka",
    schedule_type = "NoSchedule"
  }]

  depends_on = [rhcs_cluster_rosa_classic.rosa_kafka_cluster]
}


#---------------------------------------------------------------
# Cluster Admin credentials resources
#---------------------------------------------------------------
data "aws_secretsmanager_secret_version" "admin_password_version" {
  secret_id  = aws_secretsmanager_secret.rosa_kafka.id
  depends_on = [aws_secretsmanager_secret_version.rosa_kafka]
}

resource "random_password" "rosa_kafka" {
  length           = 16
  special          = true
  override_special = "@_"
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "rosa_kafka" {
  name                    = local.name
  recovery_window_in_days = 0 # Set to zero for this example to force delete during Terraform destroy
}

resource "aws_secretsmanager_secret_version" "rosa_kafka" {
  secret_id     = aws_secretsmanager_secret.rosa_kafka.id
  secret_string = random_password.rosa_kafka.result
}
