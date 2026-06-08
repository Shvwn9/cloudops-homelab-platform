terraform {
  backend "oci" {
    bucket    = "masterops-tfstate"
    namespace = "axmtqdl0oxyh"
    region    = "eu-paris-1"
    key       = "masterops/prod/terraform.tfstate"
  }
}
