resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
      Name = "${var.environment}-hakan-test"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.vpc.id
  count = var.public_subnet_count
  cidr_block = element(var.public_subnet_cidr, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.environment}-hakan-test-pb-sb-${count.index +1}"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.vpc.id
  count = var.private_subnet_count
  cidr_block = element(var.private_subnet_cidr, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.environment}-hakan-test-pr-sb-${count.index +1}"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment}-pb-rt"
  }
}

resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment}-pr-rt"
  }
}

resource "aws_route_table_association" "pb-sn-association" {
  count = var.public_subnet_count
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "pr-sn-association" {
  count = var.private_subnet_count
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private-rt.id
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.environment}-gw"
  }
}

resource "aws_route" "gw-route" {
  route_table_id            = aws_route_table.public-rt.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id
}

data "aws_ami" "amazon-linux-2" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_instance" "hakan-ec2" {
  ami = data.aws_ami.amazon-linux-2.id
  instance_type = var.instancetype
  key_name = var.keypem
  vpc_security_group_ids = [aws_security_group.sec-gr.id]
  subnet_id = aws_subnet.public_subnet[0].id
  associate_public_ip_address = true
  user_data = file("userdata.sh")
  tags = {
    Name = "${var.environment}-EC2"
  }
}

resource "aws_security_group" "sec-gr" {
  name = "${var.environment}-vpc-secgr"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.environment}-vpc-secgr"
  }

  dynamic "ingress" {
      for_each = var.secgr-dynamic-ports
      iterator = port
      content {
          from_port = port.value
          to_port = port.value
          protocol = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
      }
  }

  egress {
      from_port = 0
      protocol = "-1"
      to_port = 0
      cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_route53_zone" "hakan-domain" {
  name = "hakancar-awsdevops.co.uk"
}

resource "aws_route53_record" "www" {
  name = "test.hakancar-awsdevops.co.uk"
  type = "A"
  ttl = "300"
  zone_id = data.aws_route53_zone.hakan-domain.id
  records = [aws_instance.hakan-ec2.public_ip]
}