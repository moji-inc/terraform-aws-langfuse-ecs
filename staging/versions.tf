terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "langfuse-tf-state-796012662922"
    key          = "langfuse-staging/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Service     = var.service_name
      User        = "ai-eval"
      ManagedBy   = "terraform"
      Environment = "staging"
    }
  }
}
