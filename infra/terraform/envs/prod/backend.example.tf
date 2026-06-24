terraform {
  backend "oci" {
    bucket    = "terraform-state-Example"
    namespace = "Name.Example"
    region    = "eu-paris-1"
    key       = "masterops/prod/terraform.tfstate"

    auth = "InstancePrincipal"
  }
}