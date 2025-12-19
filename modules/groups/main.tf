variable "project_name" {
  description = "Project name used as prefix for groups"
  type        = string
  default     = "impulse"
}

locals {
  # Contract-driven group names (no env suffix as per requirements)
  groups = {
    infra     = "${var.project_name}-infra"
    devsecops = "${var.project_name}-devsecops"
    dev       = "${var.project_name}-dev"
    ia        = "${var.project_name}-ia"
    data      = "${var.project_name}-data"
    security  = "${var.project_name}-security"
    soc       = "${var.project_name}-soc"
  }
}

resource "azuread_group" "groups" {
  for_each = local.groups

  display_name     = each.value
  description      = "RBAC group for ${each.value}"
  security_enabled = true
  mail_enabled     = false
  visibility       = "Private"
}

output "object_ids" {
  description = "Object IDs for all RBAC groups"
  value       = { for k, g in azuread_group.groups : k => g.id }
}

output "display_names" {
  description = "Display names for all RBAC groups"
  value       = { for k, g in azuread_group.groups : k => g.display_name }
}
