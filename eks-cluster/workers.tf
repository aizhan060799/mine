#creates IAM role for EKS worker nodes, allowing ec2 instances assume the role
resource "aws_iam_role" "worker_role" {
  name = "${var.eks_cluster_name}-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.eks_cluster_name}-worker-role"
  }
}

# Attach Policies to Worker IAM Role
#Node policy allow worker nodes join the cluster
resource "aws_iam_role_policy_attachment" "workers-AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

#Allows nodes to manage networking via aws vpc cni
resource "aws_iam_role_policy_attachment" "workers-AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
#enables nodes to pull container images from ecr
resource "aws_iam_role_policy_attachment" "workers-AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


# IAM Instance Profile for Worker Nodes
#Creates an IAM instance profile to attach the IAM role to worker EC2 instances
resource "aws_iam_instance_profile" "worker_profile" {
  name = "${var.eks_cluster_name}-worker-profile"
  role = aws_iam_role.worker_role.name
}

# Security Group for Worker Nodes
resource "aws_security_group" "worker_sg" {
  name   = "${var.eks_cluster_name}-worker-sg"
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.eks_cluster_name}-worker-sg"
  }

  ingress {
    description     = "Allow inbount trafic from EKS cluster control plane security group"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_sg.id]
    self            = false
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Data Source to Fetch EKS Optimized AMI
data "aws_ami" "eks_worker" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.k8s_version}-v*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["602401143452"] # Amazon EKS AMI Owner ID
}

# Launch Template for Worker Nodes
resource "aws_launch_template" "eks_worker_template" {
  name_prefix   = "${var.eks_cluster_name}-worker-nodes-"
  description   = "Launch template for ${var.eks_cluster_name} EKS node group"
  image_id      = data.aws_ami.eks_worker.id
  instance_type = var.instance_types[0] # Primary instance type

  iam_instance_profile {
    name = aws_iam_instance_profile.worker_profile.name
  }

  user_data = base64encode(
    <<-EOF
    #!/bin/bash
    set -o xtrace
    /etc/eks/bootstrap.sh ${var.eks_cluster_name} --kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=spot'
    EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                                            = "${var.eks_cluster_name}-eks-node-group"
      "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
    }
  }

  tags = {
    Name = "${var.eks_cluster_name}-worker-nodes"
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.worker_sg.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }
}

# Auto Scaling Group for Worker Nodes with Mixed Instances Policy
resource "aws_autoscaling_group" "eks_worker_asg" {
  name                = "${var.eks_cluster_name}-worker-asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.public_subnets

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.eks_worker_template.id
        version            = "$Latest"
      }

      override {
        instance_type = var.instance_types[0]
      }

      override {
        instance_type = var.instance_types[1]
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 20
      spot_allocation_strategy                 = "lowest-price"
      spot_instance_pools                      = 2
    }
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.eks_cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.eks_cluster_name}-eks-worker-nodes"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_launch_template.eks_worker_template
  ]
}