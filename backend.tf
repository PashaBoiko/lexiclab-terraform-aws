terraform {
  backend "s3" {
    bucket         = "lexiclab-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "lexiclab-terraform-locks"
  }
}
