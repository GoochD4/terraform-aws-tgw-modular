# Security Groups
## Need to create 4 of them as our Security Groups are linked to a VPC


resource "aws_security_group" "NSG-vpc-sec-ssh-icmp-https" {
  name        = "NSG-vpc-sec-ssh-icmp-https"
  description = "Allow SSH, HTTPS and ICMP traffic"
  vpc_id      = aws_vpc.vpc_sec.id

  ingress {
    description = "Allow remote access to FGT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["45.19.226.46/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["45.19.226.46/32"]
  }

  tags = {
    Name     = "NSG-vpc-sec-ssh-icmp-https"
    scenario = var.scenario
  }
}