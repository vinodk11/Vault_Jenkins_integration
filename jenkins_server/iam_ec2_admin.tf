# iam_ec2_admin.tf

# IAM role that can be attached to EC2 instances and grants full administrative
# privileges via the AWS managed AdministratorAccess policy. This enables the
# instance to make any AWS API call programmatically.

resource "aws_iam_role" "ec2_admin" {
  name = "${var.cluster_name}-ec2-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach the AWS managed AdministratorAccess policy (full admin rights)
resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.ec2_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Create an instance profile so the role can be attached to an EC2 instance
resource "aws_iam_instance_profile" "ec2_admin_profile" {
  name = "${var.cluster_name}-ec2-admin-profile"
  role = aws_iam_role.ec2_admin.name
}

# Optional: Export the ARN for use in other modules or outputs
output "ec2_admin_role_arn" {
  description = "ARN of the EC2 admin role"
  value       = aws_iam_role.ec2_admin.arn
}
