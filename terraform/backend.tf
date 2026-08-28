terraform {
  backend "s3" {
    bucket       = "kanavenavamshi-terraformstate"
    key          = "cicd-eks-rds/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}