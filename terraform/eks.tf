# =========================
# EKS CLUSTER IAM ROLE
# =========================

resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-cluster-role"
  }
}


# =========================
# EKS CLUSTER IAM POLICY
# =========================

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


# =========================
# EKS CLUSTER
# =========================

resource "aws_eks_cluster" "main" {
  name     = var.project_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = concat(
      aws_subnet.public[*].id,
      aws_subnet.private[*].id
    )

    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = var.project_name
  }
}


# =========================
# EKS NODE GROUP IAM ROLE
# =========================

resource "aws_iam_role" "node_role" {
  name = "${var.project_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-node-role"
  }
}


# =========================
# NODE GROUP IAM POLICIES
# =========================

# Allows worker nodes to join EKS
resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


# Allows Amazon VPC CNI networking
resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


# Allows pulling images from ECR
resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}


# =========================
# EKS MANAGED NODE GROUP
# =========================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"

  node_role_arn = aws_iam_role.node_role.arn

  # Run worker nodes in private subnets
  subnet_ids = aws_subnet.private[*].id


  # =========================
  # SCALING CONFIGURATION
  # =========================

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }


  # =========================
  # INSTANCE CONFIGURATION
  # =========================

  instance_types = [
    "t3.medium"
  ]

  disk_size = 20


  # =========================
  # DEPENDENCIES
  # =========================

  depends_on = [
    aws_eks_cluster.main,
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy
  ]


  tags = {
    Name = "${var.project_name}-nodes"
  }
}
