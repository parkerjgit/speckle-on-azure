locals {
  prefix          = join("-", ["${var.namespace}","${var.env}"])
  prefix_nospace  = join("", ["${var.namespace}","${var.env}"])
  common_tags = {
    project = var.project,
    env = var.env,
    terraform = "true"
  }
}