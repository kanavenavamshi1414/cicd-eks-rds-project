# ============================================================
# CURRENT AWS ACCOUNT / IAM IDENTITY
# ============================================================

data "aws_caller_identity" "current" {}


# ============================================================
# EKS CLUSTER IAM ROLE
# ============================================================

resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"

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
    Name = "${var.project_name}-eks-cluster-role"
  }
}


# ============================================================
# EKS CLUSTER POLICY
# ============================================================

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role = aws_iam_role.eks_cluster_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


# ============================================================
# EKS CLUSTER
# ============================================================

resource "aws_eks_cluster" "main" {

  name = var.project_name

  role_arn = aws_iam_role.eks_cluster_role.arn

  version = "1.33"

  # ----------------------------------------------------------
  # EKS AUTHENTICATION
  # ----------------------------------------------------------

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  # ----------------------------------------------------------
  # NETWORK CONFIGURATION
  # ----------------------------------------------------------

  vpc_config {

    subnet_ids = concat(
      aws_subnet.public[*].id,
      aws_subnet.private[*].id
    )

    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # ----------------------------------------------------------
  # DEPENDENCY
  # ----------------------------------------------------------

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = "${var.project_name}-eks-cluster"
  }
}


# ============================================================
# EKS ACCESS ENTRY
#
# Gives the IAM identity running Terraform access to EKS.
# This does NOT create a new IAM user.
# ============================================================

resource "aws_eks_access_entry" "terraform" {

  cluster_name = aws_eks_cluster.main.name

  principal_arn = data.aws_caller_identity.current.arn

  type = "STANDARD"

  depends_on = [
    aws_eks_cluster.main
  ]
}


# ============================================================
# EKS CLUSTER ADMIN ACCESS
# ============================================================

resource "aws_eks_access_policy_association" "terraform_admin" {

  cluster_name = aws_eks_cluster.main.name

  principal_arn = data.aws_caller_identity.current.arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.terraform
  ]
}


# ============================================================
# EKS NODE IAM ROLE
# ============================================================

resource "aws_iam_role" "eks_node_role" {

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


# ============================================================
# EKS WORKER NODE POLICY
# ============================================================

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {

  role = aws_iam_role.eks_node_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


# ============================================================
# EKS CNI POLICY
# ============================================================

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {

  role = aws_iam_role.eks_node_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


# ============================================================
# ECR PULL POLICY
# ============================================================

resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {

  role = aws_iam_role.eks_node_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}


# ============================================================
# EKS MANAGED NODE GROUP
# ============================================================

resource "aws_eks_node_group" "main" {

  # ----------------------------------------------------------
  # CLUSTER
  # ----------------------------------------------------------

  cluster_name = aws_eks_cluster.main.name

  node_group_name = "${var.project_name}-nodes"

  # ----------------------------------------------------------
  # NODE IAM ROLE
  # ----------------------------------------------------------

  node_role_arn = aws_iam_role.eks_node_role.arn

  # ----------------------------------------------------------
  # PRIVATE SUBNETS
  # ----------------------------------------------------------

  subnet_ids = aws_subnet.private[*].id

  # ----------------------------------------------------------
  # INSTANCE TYPE
  # ----------------------------------------------------------

  instance_types = [
    "t3.medium"
  ]

  capacity_type = "ON_DEMAND"

  # ----------------------------------------------------------
  # SCALING
  # ----------------------------------------------------------

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  # ----------------------------------------------------------
  # UPDATE CONFIGURATION
  # ----------------------------------------------------------

  update_config {
    max_unavailable = 1
  }

  # ----------------------------------------------------------
  # DEPENDENCIES
  # ----------------------------------------------------------

  depends_on = [

    aws_eks_cluster.main,

    aws_iam_role_policy_attachment.eks_worker_node_policy,

    aws_iam_role_policy_attachment.eks_cni_policy,

    aws_iam_role_policy_attachment.eks_ecr_policy
  ]

  tags = {
    Name = "${var.project_name}-nodes"
  }
}
