variable "cluster_name" {
  description = "Name prefix for resources (e.g., cluster or project name)"
  type        = string
  default     = "jenkins"
}

variable "aws_region" {
    description = "resource going to be created"
    type = string
    default = "us-east-1"
} 

variable "aws_ami" {
    description = "aim id from sources"
    type = string
    default = "data.aws_ami.ubuntu.id"
  
}

variable "aws_keypair" {
    description = "to login to the server"
    type = string
    default = "CloudForge"
  
}

variable "instance_type" {
    description = "EC2 instance type to be created"
    type        = string
    default     = "t2.medium"
}

# Root volume size in GiB for the EC2 instance
variable "disk_size" {
    description = "Root EBS volume size (GiB)"
    type        = number
    default     = 50
}

# Root volume type (gp2, gp3, etc.)
variable "root_volume_type" {
    description = "Root EBS volume type"
    type        = string
    default     = "gp2"
}