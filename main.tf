
# Provision the VPC
resource "aws_vpc" "craft-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Craft VPC"
  }
}

# Provision Public Subnet for EC2 Servers
resource "aws_subnet" "ec2-subnet-1" {
  vpc_id                  = aws_vpc.craft-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "ec2subnet-1a"
  }
}

resource "aws_subnet" "ec2-subnet-2" {
  vpc_id                  = aws_vpc.craft-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "ec2subnet-2b"
  }
}

# Provision Database 
resource "aws_subnet" "dbapp-subnet-1" {
  vpc_id            = aws_vpc.craft-vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Database-1a"
  }
}


resource "aws_subnet" "dbapp-subnet-2" {
  vpc_id            = aws_vpc.craft-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Database-2b"
  }
}

# Provision the Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.craft-vpc.id

  tags = {
    Name = "craft IGW"
  }
}

# Provision Web layer route table
resource "aws_route_table" "ec2-rt" {
  vpc_id = aws_vpc.craft-vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "WebRT"
  }
}

# Provision ec2 Subnet association with Web route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.ec2-subnet-1.id
  route_table_id = aws_route_table.ec2-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.ec2-subnet-2.id
  route_table_id = aws_route_table.ec2-rt.id
}

#Provision EC2 Instance
resource "aws_instance" "ec2server1" {
  ami                    = "ami-052efd3df9dad4825"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  vpc_security_group_ids = [aws_security_group.app-sg.id]
  subnet_id              = aws_subnet.ec2-subnet-1.id
 
  tags = {
    Name = "ec2 Server"
  }

}

resource "aws_instance" "ec2server2" {
  ami                    = "ami-052efd3df9dad4825"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1b"
  vpc_security_group_ids = [aws_security_group.app-sg.id]
  subnet_id              = aws_subnet.ec2-subnet-2.id
 

  tags = {
    Name = "ec2 Server"
  }

}

resource "aws_s3_bucket" "Craft-S3" {
   bucket = "Craft-S3"
   acl = "private"  
}

resource "aws_elasticache_cluster" "craft-redis" {
  cluster_id           = "craft-redis"
  engine               = "redis"
  node_type            = "cache.m4.large"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis3.2"
  engine_version       = "3.2.10"
  port                 = 6379
}


# Provision ec2 Security Group
resource "aws_security_group" "ec2-sg" {
  name        = "ec2-SG"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.craft-vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-SG"
  }
}

# Provision Application LB Security Group
resource "aws_security_group" "app-sg" {
  name        = "app-sg"
  description = "Allow inbound traffic from ALB"
  vpc_id      = aws_vpc.craft-vpc.id

  ingress {
    description     = "Allow traffic from ec2 layer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

# Provision Database Security Group
resource "aws_security_group" "database-sg" {
  name        = "Database-SG"
  description = "Allow inbound traffic from application layer"
  vpc_id      = aws_vpc.craft-vpc.id

  ingress {
    description     = "Allow traffic from application layer"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app-sg.id]
  }

  egress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database-SG"
  }
}

resource "aws_lb" "external-elb" {
  name               = "External-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2-sg.id]
  subnets            = [aws_subnet.ec2-subnet-1.id, aws_subnet.ec2-subnet-2.id]
}

resource "aws_lb_target_group" "external-elb" {
  name     = "ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.craft-vpc.id
}

resource "aws_lb_target_group_attachment" "external-elb1" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.ec2server1.id
  port             = 80

  depends_on = [
    aws_instance.ec2server1,
  ]
}

resource "aws_lb_target_group_attachment" "external-elb2" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.ec2server2.id
  port             = 80

  depends_on = [
    aws_instance.ec2server2,
  ]
}

resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external-elb.arn
  }
}

resource "aws_db_instance" "default" {
  allocated_storage      = 10
  db_subnet_group_name   = aws_db_subnet_group.default.id
  engine                 = "mysql"
  engine_version         = "8.0.20"
  instance_class         = "db.t2.micro"
  multi_az               = true
  name                   = "mydb"
  username               = "username"
  password               = "password"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.database-sg.id]
}

resource "aws_db_subnet_group" "default" {
  name       = "dbgroup"
  subnet_ids = [aws_subnet.dbapp-subnet-1.id, aws_subnet.dbapp-subnet-2.id]

  tags = {
    Name = "craft DB subnet group"
  }
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.external-elb.dns_name
}
