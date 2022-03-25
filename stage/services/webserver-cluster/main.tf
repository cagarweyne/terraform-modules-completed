terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  required_version = "0.15.3"
}

provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" { 
    bucket = "terraform-masterclass-bucket"
		key = "stage/services/webserver-cluster/terraform.tfstate"
		region = "us-east-2"
		
		dynamodb_table = "terraform-masterclass-locks-table"
		encrypt = true 
  }
}

module "webserver_cluster" {
	source = "../../../modules/services/webserver-cluster"

  cluster_name = "webserver-stage"
  instance_type = "t2.micro"
	min_size = 2
	max_size = 2
}