resource "aws_security_group" "ssh-sg" {
    name = "ssh-sg"
    description = "allow tarfic to prot 22"
    ingress {
        description = "allows port 22"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]

    }

    egress {
        description = "allows all ports"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "jenkins-sg"
    } 

  
}


resource "aws_security_group" "jenkis-sg" {
    name = "jenkins-sg"
    description = "allow tarfic to prot 8080"
    ingress {
        description = "allows port 8080"
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]

    }

    egress {
        description = "allows all ports"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "jenkins-gs"
    }
   
  
}

