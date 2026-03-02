terraform {
  backend "s3" {
    bucket         = "tf-state-platform-lab"
    key            = "staging/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "tf-lock-platform-lab"
    encrypt        = true
  }
}