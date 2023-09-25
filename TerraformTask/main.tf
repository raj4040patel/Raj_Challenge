terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.5.0"
    }
  }
}

provider "aws" {
  region     = var.region_Name
  access_key = var.access_key
  secret_key = var.secret_key
}
# genrate key using tls module 
resource "tls_private_key" "ins_key" {
  algorithm = "RSA"
}

# genrate key pair on aws 
resource "aws_key_pair" "mykey" {
  key_name   = "ins_test_key"
  public_key = tls_private_key.ins_key.public_key_openssh
}

# crate a custom vpc 
resource "aws_vpc" "myvpc" {
  cidr_block       = var.vpc_cidrblock
  instance_tenancy = "default"

  tags = {
    Name = var.vpc_name
  }
} # create subnet1 as public 
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet1_cidrblock
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet1_Public_Myvpc"
  }
}
# create subnet2 as public 
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.subnet2_cidrblock
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet2_Public_Myvpc"
  }
}
# create security group for instance 
resource "aws_security_group" "public_grp" {
  name        = "Allow RULES"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "ALLOW SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "ALLOW Http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "ALLOW Https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "Public-grp"
  }
}

# create a route table for Public Sudbnet 
resource "aws_route_table" "Publicrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myvpcigw.id
  }

  tags = {
    "Name" = "PublicRT_MyVpc"
  }
}
# crate a internetgateway for vpc
resource "aws_internet_gateway" "myvpcigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "MyVpc_igw"
  }
}

# Associate subnet1 with publicRT 
resource "aws_route_table_association" "publicsubnet1assosiate" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.Publicrt.id
}

# Associate subnet2 with publicRT 
resource "aws_route_table_association" "publicsubnet2assosiate" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.Publicrt.id
}
# create Public instance 
resource "aws_instance" "instance1" {
  ami                    = var.instance_ami
  instance_type          = var.server_instance
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.public_grp.id]
  key_name               = aws_key_pair.mykey.key_name
  tags = {
    "Name" = "Ins1"
  }
  connection {
    type        = "ssh"
    user        = "ec2-user"                              # Adjust the SSH user based on your instance configuration
    private_key = tls_private_key.ins_key.private_key_pem # Adjust the SSH private key path
    host        = aws_instance.instance1.public_ip        # Use the instance's public IP
  }
  provisioner "file" {
    source      = "./user_data.sh"
    destination = "/home/ec2-user/user_data.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ec2-user/user_data.sh",
      "sudo sh /home/ec2-user/user_data.sh",
    ]
  }
}
# create Public instance2 
resource "aws_instance" "instance2" {
  ami                    = var.instance_ami
  instance_type          = var.server_instance
  subnet_id              = aws_subnet.subnet2.id
  vpc_security_group_ids = [aws_security_group.public_grp.id]
  key_name               = aws_key_pair.mykey.key_name
  tags = {
    "Name" = "Ins2"
  }
  connection {
    type        = "ssh"
    user        = "ec2-user"                              # Adjust the SSH user based on your instance configuration
    private_key = tls_private_key.ins_key.private_key_pem # Adjust the SSH private key path
    host        = aws_instance.instance1.public_ip        # Use the instance's public IP
  }
  provisioner "file" {
    source      = "./user_data.sh"
    destination = "/home/ec2-user/user_data.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ec2-user/user_data.sh",
      "sudo sh /home/ec2-user/user_data.sh",
    ]
  }
}
resource "aws_lb" "my_load_balancer" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  security_groups    = [aws_security_group.elb_sg.id]
  ip_address_type    = "ipv4"
  tags = {
    Name = "my-load-balancer"
  }
  enable_deletion_protection = false
}

resource "aws_lb_listener" "INS2_Http_listener" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http_target_group.arn
  }
}

resource "aws_lb_listener" "INS2_Https_listener" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port              = 443
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https_target_group.arn
  }
}
resource "aws_security_group" "elb_sg" {
  name        = "Allow_http_elb"
  description = "Allow http inbound traffic for elb"
  vpc_id      = aws_vpc.myvpc.id
  ingress {
    description      = "ALLOW ICMP"
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "terraform-elb-security-group"
  }
}

resource "aws_lb_target_group" "http_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    enabled             = true
    path                = "/"
    interval            = 30
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200-299"

  }
  depends_on = [
    aws_instance.instance1, aws_instance.instance2
  ]
}

resource "aws_lb_target_group" "https_target_group" {
  name        = "https-target-group"
  port        = 80 # We'll use a listener rule to forward to port 443
  protocol    = "HTTP"
  target_type = "instance" # Change this to "ip" if using IP targets
  vpc_id      = aws_vpc.myvpc.id
  depends_on = [
    aws_instance.instance1, aws_instance.instance2
  ]
}

resource "aws_lb_target_group_attachment" "my_Http_target_group_attachment1" {
  target_group_arn = aws_lb_target_group.http_target_group.arn
  target_id        = aws_instance.instance1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "my_Https_target_group_attachment2" {
  target_group_arn = aws_lb_target_group.https_target_group.arn
  target_id        = aws_instance.instance1.id
  port             = 443
}
resource "aws_lb_target_group_attachment" "my_Http_target_group_attachment3" {
  target_group_arn = aws_lb_target_group.http_target_group.arn
  target_id        = aws_instance.instance2.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "my_Https_target_group_attachment4" {
  target_group_arn = aws_lb_target_group.https_target_group.arn
  target_id        = aws_instance.instance2.id
  port             = 443
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      content      = "OK"
    }
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08" # Use an appropriate SSL policy
  certificate_arn = "arn:aws:acm:ap-south-1:123456789012:certificate/your-certificate-arn"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      content      = "OK"
    }
  }
}
# Listener Rule for Http
resource "aws_lb_listener_rule" "http_rule" {
  listener_arn = aws_lb_listener.http_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}
# Listener Rule for https
resource "aws_lb_listener_rule" "https_rule" {
  listener_arn = aws_lb_listener.https_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

#output of Loadbalancer dNS
output "load_balancer_dns" {
  value = aws_lb.my_load_balancer.dns_name
}

# download key pair file in local system 
resource "local_file" "private_key" {
  content  = tls_private_key.ins_key.private_key_pem
  filename = "Host.pem"
}

# output of public ip
output "outputip_Public_Instance1" {
  value = aws_instance.instance1.public_ip
}
# output of public ip
output "outputip_Public_Instance2" {
  value = aws_instance.instance2.public_ip
}
# output of key pair file 
output "ins_key" {
  value     = tls_private_key.ins_key.private_key_pem
  sensitive = true
}
