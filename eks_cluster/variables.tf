variable "region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "eks_cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
  default     = "CloudForge-cluster"
}

variable "eks_version" {
  description = "The desired Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.31"
}

# List of subnet IDs for the VPC where the cluster will be created
variable "subnet_ids" {
  description = "Subnet IDs for the EKS cluster VPC."
  type        = list(string)
  default = [
    "subnet-09b776ddd0e3df31e",
    "subnet-04f146e9df890e9d4",
    "subnet-0c88fddb536cf0d7f",
    "subnet-0e3daac08f57e1830",
    "subnet-08169c980b22b36ca",
    #"subnet-06a234fead00ffeaf"
  ]
}

# Node group instance type
variable "instance_type" {
  description = "EC2 instance type for EKS worker nodes."
  type        = string
  default     = "t3.large"
}

# Disk size (GiB) for worker nodes
variable "disk_size" {
  description = "Root disk size (GiB) for each worker node."
  type        = number
  default     = 30
}

# Scaling configuration for the node group
variable "desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 3
}
variable "min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}
variable "max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 5
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster and SGs will be created."
  type        = string
  default     = "vpc-0d7dfc3c42d0f39c0"
}

variable "key_pair_name" {
  description = "key pair name"
  type        = string
  default     = "CloudForge"

}