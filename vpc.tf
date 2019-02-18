### vpc definition ###

resource "aws_vpc" "vpc" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = "true"
  
  tags {
    Name  = "${var.environment}-vpc"
    Environment = "${var.environment}"
  }
}

### internet gateway ###

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
  
  tags = {
    Name = "${var.environment}-vpc"
    Environment = "${var.environment}"
  }
}

### subnets definition ###

resource "aws_subnet" "public-subnet-a" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.public-subnet-a}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  map_public_ip_on_launch = "true"
 
  tags = {
    Name = "${var.environment}-public-subnet-a"
    Environment = "${var.environment}"
  }
}

resource "aws_subnet" "public-subnet-b" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.public-subnet-b}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = "true"
  
  tags = {
    Name = "${var.environment}-public-subnet-b"
    Environment = "${var.environment}"
  }
}

### nacl ###

resource "aws_network_acl" "nacl" {
  vpc_id = "${aws_vpc.vpc.id}"
  subnet_ids = ["${aws_subnet.public-subnet-a.id}", "${aws_subnet.public-subnet-b.id}"]

  egress {
    protocol = "tcp"
    rule_no = 100
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 32768
    to_port = 65535
  }
  egress {
    protocol = "tcp"
    rule_no = 101
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 80
    to_port = 80
  }
  egress {
    protocol = "tcp"
    rule_no = 102
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 443
    to_port = 443
  }
  egress {
    protocol = "tcp"
    rule_no = 103
    action = "allow"
    cidr_block = "69.140.89.42/32"
    from_port = 22
    to_port = 22
  }
    
  ingress {
    protocol = "tcp"
    rule_no = 100
    action = "allow"    
    cidr_block = "0.0.0.0/0"
    from_port = 1024
    to_port = 65535
  }
  ingress {
    protocol = "tcp"
    rule_no = 101
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 80
    to_port = 80
  }
  ingress {
    protocol = "tcp"
    rule_no = 102
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 443
    to_port = 443
  }
  ingress {
    protocol = "tcp"
    rule_no = 103
    action = "allow"
    cidr_block = "69.140.89.42/32"
    from_port = 22
    to_port = 22
  }
  
  tags = {
    Name = "${var.environment}-nacl"
    Environment = "${var.environment}"
  }
}

### route table definitions ###

resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.vpc.id}"
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags = {
    Name = "${var.environment}-rtb"
    Environment = "${var.environment}"
  }
}

resource "aws_route_table_association" "rta-subnet-a" {
  subnet_id = "${aws_subnet.public-subnet-a.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}

resource "aws_route_table_association" "rta-subnet-b" {
  subnet_id = "${aws_subnet.public-subnet-b.id}"
  route_table_id = "${aws_route_table.rtb.id}"
}

### webserver security groups ###

resource "aws_security_group" "webserver-sg" {
  name = "${var.environment}-webserver-sg"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port = 0
    to_port = 0    
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.environment}-webserver-sg"
    Environment = "${var.environment}"
  }
}

### elb definition ###

resource "aws_security_group" "elb-sg" {
  name = "${var.environment}-nlb-sg"
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-nlb-sg"
    Environment = "${var.environment}"
  }
}

resource "aws_elb" "nlb" {
  name = "${var.environment}-nlb"
  subnets = ["${aws_subnet.public-subnet-a.id}", "${aws_subnet.public-subnet-b.id}"]
  security_groups = ["${aws_security_group.elb-sg.id}"]
  instances = ["${aws_instance.webserver-a.id}", "${aws_instance.webserver-b.id}"]
  
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  tags = {
    Name = "${var.environment}-nlb"
    Environment = "${var.environment}"
  }
}


### webservers ###

resource "aws_instance" "webserver-a" {
  ami = "ami-d5bf2caa"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public-subnet-a.id}"
  vpc_security_group_ids = ["${aws_security_group.webserver-sg.id}"]
  key_name = "${aws_key_pair.example-keypair2.id}"


  tags = {
    Name = "${var.environment}-webserver-a"
    Environment = "${var.environment}"
  } 

  connection {
    user  = "centos"
    private_key = "${file(var.private_key)}"
  }
 
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install epel-release -y",
      "sudo yum install nginx -y",
      "sudo service nginx start",
    ]
  }
}


resource "aws_instance" "webserver-b" {
  ami = "ami-d5bf2caa"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public-subnet-a.id}"
  vpc_security_group_ids = ["${aws_security_group.webserver-sg.id}"]
  key_name = "${aws_key_pair.example-keypair2.id}"


  tags = {
    Name = "${var.environment}-webserver-b"
    Environment = "${var.environment}"
  } 

  connection {
    user  = "centos"
    private_key = "${file(var.private_key)}"
  }
 
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install epel-release -y",
      "sudo yum install nginx -y",
      "sudo service nginx start",
    ]
  }
}

### outputs ###

output "aws_elb_public_dns" {
  value = "${aws_elb.nlb.dns_name}"
}
