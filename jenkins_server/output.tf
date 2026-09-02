output "aws_instance_dns" { 
    description = "instance public dns name"
    value = aws_instance.jenkins-vm.public_dns
}

output "aws_instance_public_ip" { 
    description = "instance public ip"
    value = aws_instance.jenkins-vm.public_ip
  
}

output "aws_instance_id" {
    description = "instance id"
    value = aws_instance.jenkins-vm.id
  
}

resource "local_file" "instance-details" {
    content = <<EOT
  Instance ID: ${aws_instance.jenkins-vm.public_dns}
  Public IP:   ${aws_instance.jenkins-vm.public_ip}
  Private IP:  ${aws_instance.jenkins-vm.id}
  EOT

  filename = "${path.module}/instance-details.txt"

  
}
