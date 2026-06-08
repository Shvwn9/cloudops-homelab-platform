terraform {
  backend "oci" {
    bucket    = "terraform-state-masterops"
    namespace = "axmtqdl0oxyh"
    region    = "eu-paris-1"
    key       = "masterops/prod/terraform.tfstate"

    auth = "InstancePrincipal"
  }
}