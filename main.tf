provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "terraform-vpc"
  }
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "terraform-IGW"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.0.0/26"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-pub-snet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.0.64/26"
  availability_zone = "us-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-pub-snet-2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.0.128/26"
  availability_zone = "us-west-2a"

  tags = {
    Name = "terraform-pvt-snet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.0.192/26"
  availability_zone = "us-west-2b"

  tags = {
    Name = "terraform-pvt-snet-2"
  }
}

resource "aws_security_group" "example" {
  name        = "example"
  description = "Allow inbound HTTP, HTTPS, 8080, and SSH traffic"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "terraform-pub-RT"
  }
}

resource "aws_route" "public_route_internet_gateway" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.example.id
}

resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "terraform-pvt-RT"
  }
}

resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Create a new target group for an Application Load Balancer
resource "aws_lb_target_group" "new_target_group" {
  name     = "terraform-new-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.example.id

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = 200
  }

  tags = {
    Name = "terraform-new-TG"
  }
}

# Attach the newly created instances to the new target group
resource "aws_lb_target_group_attachment" "new_target_group_attachment" {
  count            = 10
  target_group_arn = aws_lb_target_group.new_target_group.arn
  target_id        = aws_instance.example[count.index].id 
  port             = 80
}

resource "aws_instance" "example" {
  count           = 10
  ami             = "ami-08d8ac128e0a1b91c"
  instance_type   = "t2.micro"
  subnet_id       = count.index % 2 == 0 ? aws_subnet.public_subnet_1.id : aws_subnet.public_subnet_2.id
  security_groups = [aws_security_group.example.id]

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "terraform-ec2-${count.index + 1}"
  }
}

#terraform graph
#sudo yum/apt-get install graphviz
#brew install graphviz
#terraform graph | dot -Tsvg > graph.svg
#terraform graph | dot -Tpng > graph.png
