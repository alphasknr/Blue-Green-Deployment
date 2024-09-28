provider "aws" {
  region = "ap-south-1"
}

//VPC Creation
resource "aws_vpc" "bankops_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bankops-vpc"
  }
}

resource "aws_subnet" "bankops_subnet" {
  count = 2
  vpc_id                  = aws_vpc.bankops_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.bankops_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "bankops-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "bankops_igw" {
  vpc_id = aws_vpc.bankops_vpc.id

  tags = {
    Name = "bankops-igw"
  }
}

resource "aws_route_table" "bankops_route_table" {
  vpc_id = aws_vpc.bankops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bankops_igw.id
  }

  tags = {
    Name = "bankops-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.bankops_subnet[count.index].id
  route_table_id = aws_route_table.bankops_route_table.id
}

resource "aws_security_group" "bankops_cluster_sg" {
  vpc_id = aws_vpc.bankops_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bankops-cluster-sg"
  }
}

resource "aws_security_group" "bankops_node_sg" {
  vpc_id = aws_vpc.bankops_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bankops-node-sg"
  }
}

//EKS Cluster Creation
resource "aws_eks_cluster" "bankops" {
  name     = "bankops-cluster"
  role_arn = aws_iam_role.bankops_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.bankops_subnet[*].id
    security_group_ids = [aws_security_group.bankops_cluster_sg.id]
  }
}

resource "aws_eks_node_group" "bankops" {
  cluster_name    = aws_eks_cluster.bankops.name
  node_group_name = "bankops-node-group"
  node_role_arn   = aws_iam_role.bankops_node_group_role.arn
  subnet_ids      = aws_subnet.bankops_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.large"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.bankops_node_sg.id]
  }
}

resource "aws_iam_role" "bankops_cluster_role" {
  name = "bankops-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "bankops_cluster_role_policy" {
  role       = aws_iam_role.bankops_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "bankops_node_group_role" {
  name = "bankops-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "bankops_node_group_role_policy" {
  role       = aws_iam_role.bankops_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "bankops_node_group_cni_policy" {
  role       = aws_iam_role.bankops_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "bankops_node_group_registry_policy" {
  role       = aws_iam_role.bankops_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
