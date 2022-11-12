locals {
  vpcs = {
    "vpc1" = {
      cidr    = "10.1.0.0/16"
      name    = "vpc1"
      subnet1 = "10.1.0.0/24"
    }
    "vpc2" = {
      cidr    = "10.2.0.0/16"
      name    = "vpc2"
      subnet1 = "10.2.0.0/24"
    }
  }
}

resource "aws_vpc" "vpcs" {
  for_each   = local.vpcs
  cidr_block = each.value.cidr

  tags = {
    Name = "${var.tag_name_prefix}-${each.value.name}-vpc"
    # scenario = var.scenario
  }
}

# Subnet 1
resource "aws_subnet" "subnet1" {
  for_each          = local.vpcs
  vpc_id            = aws_vpc.vpcs[each.value.name].id
  cidr_block        = each.value.subnet1
  availability_zone = var.availability_zone1

  tags = {
    Name = "${var.tag_name_prefix}-${each.value.name}-subnet1"
  }
}

#Create Spoke security Group
resource "aws_security_group" "NSG-spoke-ssh-icmp-https" {
  for_each    = local.vpcs
  name        = "NSG-${each.value.name}-ssh-icmp-https"
  description = "Allow SSH, HTTPS and ICMP traffic"
  vpc_id      = aws_vpc.vpcs[each.value.name].id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["45.19.226.46/32"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["45.19.226.46/32"]
  }

  ingress {
    from_port   = 8 # the ICMP type number for 'Echo'
    to_port     = 0 # the ICMP code
    protocol    = "icmp"
    cidr_blocks = ["45.19.226.46/32"]
  }

  ingress {
    from_port   = 0 # the ICMP type number for 'Echo Reply'
    to_port     = 0 # the ICMP code
    protocol    = "icmp"
    cidr_blocks = ["45.19.226.46/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["45.19.226.46/32"]
  }

  tags = {
    Name = "${var.tag_name_prefix}-${each.value.name}-NSG"
    #scenario = var.scenario
  }
}
# test device in spoke
resource "aws_instance" "instance-subnet1" {
  for_each               = local.vpcs
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet1[each.value.name].id
  vpc_security_group_ids = [aws_security_group.NSG-spoke-ssh-icmp-https[each.value.name].id]
  key_name               = var.keypair

  tags = {
    Name = "${var.tag_name_prefix}-${each.value.name}-instance"
    #scenario = var.scenario
    az = var.availability_zone1
  }
}

# Subnet 2
# resource "aws_subnet" "subnet2" {
#   for_each          = local.vpcs
#   vpc_id            = aws_vpc.vpcs[each.value.name].id
#   cidr_block        = each.value.subnet2
#   availability_zone = var.availability_zone2

#   tags = {
#     Name = "${var.tag_name_prefix}-${each.value.name}-subnet2"
#   }
# }


# Routes
resource "aws_route_table" "vpc-rt" {
  for_each = local.vpcs
  vpc_id   = aws_vpc.vpcs[each.value.name].id

  route {
    cidr_block         = "45.19.226.46/32"
    transit_gateway_id = aws_ec2_transit_gateway.TGW-XAZ.id
  }

  tags = {
    Name = "${var.tag_name_prefix}-${each.value.name}-route"
    #scenario = var.scenario
    az = var.availability_zone1
  }
}

# Route tables associations subnet1
resource "aws_route_table_association" "spoke_rt_association1" {
  for_each       = local.vpcs
  subnet_id      = aws_subnet.subnet1[each.value.name].id
  route_table_id = aws_route_table.vpc-rt[each.value.name].id
}

# # Route tables associations subnet2
# resource "aws_route_table_association" "spoke_rt_association2" {
#   for_each               = local.vpcs
#   subnet_id              = aws_subnet.subnet2[each.value.name].id
#   route_table_id         = aws_route_table.vpc-rt[each.value.name].id
# }

# Attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-att-spoke-vpc" {
  for_each                                        = local.vpcs
  subnet_ids                                      = [aws_subnet.subnet1[each.value.name].id]
  transit_gateway_id                              = aws_ec2_transit_gateway.TGW-XAZ.id
  vpc_id                                          = aws_vpc.vpcs[each.value.name].id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name = "${var.tag_name_prefix}-${each.value.name}-tgw-attach"
    # scenario = var.scenario
  }
}

# Route Tables Propagations
## This section defines which VPCs will be routed from each Route Table created in the Transit Gateway

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-prp-vpc" {
  for_each                       = local.vpcs
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-spoke-vpc[each.value.name].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-VPC-SEC-rt.id
}

# Route Tables Associations
resource "aws_ec2_transit_gateway_route_table_association" "tgw-rt-vpc-spoke1-assoc" {
  for_each                       = local.vpcs
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-spoke-vpc[each.value.name].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-spoke-rt.id
}