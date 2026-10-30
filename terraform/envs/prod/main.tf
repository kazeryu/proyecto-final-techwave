terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Se activa después de aplicar terraform/bootstrap.
  # terraform init -backend-config="bucket=techwave-tfstate-CUENTA"
  backend "s3" {
    bucket         = "techwave-tfstate-917950986415"
    key            = "eks/terraform.tfstate"
    region         = "eu-west-1"
    profile        = "devops-personal"
    dynamodb_table = "techwave-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "devops-personal"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.17.0"

  name = "techwave"
  cidr = "10.40.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets  = ["10.40.1.0/24", "10.40.2.0/24"]
  private_subnets = ["10.40.11.0/24", "10.40.12.0/24"]

  # Sin NAT: en un laboratorio el gateway (~32 USD/mes) no aporta a la defensa.
  # Los nodos salen a internet por las subredes públicas. Para dejarlos en
  # privadas, enable_nat_gateway = true y subnet_ids = module.vpc.private_subnets.
  enable_nat_gateway = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Project = "techwave"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.6"

  cluster_name    = "techwave"
  # 1.32 ya no admite clústeres nuevos. 1.34 sigue en soporte estándar.
  cluster_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    lab = {
      ami_type                       = "AL2023_x86_64_STANDARD"
      use_latest_ami_release_version = true
      instance_types                 = ["t3.small"]
      min_size                       = 1
      max_size                       = 2
      desired_size                   = 2
      subnet_ids                     = module.vpc.public_subnets
    }
  }

  tags = {
    Project = "techwave"
  }
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "update_kubeconfig" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
