resource "aws_instance" "jenkins-vm" {
  iam_instance_profile = aws_iam_instance_profile.ec2_admin_profile.name
    ami = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    key_name = var.aws_keypair
    user_data = file("${path.module}/install_script.sh")
    vpc_security_group_ids = [ aws_security_group.ssh-sg.id, aws_security_group.jenkis-sg.id ]
    root_block_device {
      volume_size = var.disk_size
      volume_type = var.root_volume_type
      delete_on_termination = true
    }
    tags = {
        Name = "jenkins-vm"
    }

  
}