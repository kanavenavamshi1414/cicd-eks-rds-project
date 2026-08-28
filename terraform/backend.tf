terraform {
  backend "s3" {
    bucket       = "kanavenavamshi-terraform-state-364410975057"
    key          = "cicd-eks-rds/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}