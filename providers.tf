provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Project     = "lexiclab"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
