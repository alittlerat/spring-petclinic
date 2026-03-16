terraform {
  backend "s3" {
    bucket = "petclinic-tfstate-079760567327"
    key    = "petclinic/terraform.tfstate"
    region = "eu-west-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "petclinic-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Project = "petclinic"
  }
}

# EKS
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.0.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      instance_types = [var.node_instance_type]
    }
  }

  tags = {
    Project = "petclinic"
  }
}

# ECR
resource "aws_ecr_repository" "petclinic" {
  name                 = "petclinic"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Project = "petclinic"
  }
}

# Access entry dla użytkownika damian
resource "aws_eks_access_entry" "damian" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::079760567327:user/damian"
  type          = "STANDARD"

  tags = {
    Project = "petclinic"
  }
}

resource "aws_eks_access_policy_association" "damian_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::079760567327:user/damian"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.damian]
}
