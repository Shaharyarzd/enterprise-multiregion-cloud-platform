locals {
  deployment_role_name = "careflow-deployment-role"
  platform_admin_name  = "careflow-platform-admin"
  github_publish_name  = "careflow-github-ecr-publisher"
  primary_state_key    = "careflow/primary/terraform.tfstate"
  ecr_repository_name  = "${var.project_name}/careflow-api"

  deployment_role_arn = "arn:aws:iam::${var.account_id}:role/${local.deployment_role_name}"
  platform_admin_arn  = "arn:aws:iam::${var.account_id}:role/${local.platform_admin_name}"
  bootstrap_user_arn  = "arn:aws:iam::${var.account_id}:user/${var.bootstrap_user_name}"
  state_bucket_arn    = "arn:aws:s3:::${var.state_bucket_name}"

  common_tags = {
    Project     = var.project_name
    Environment = "portfolio"
    ManagedBy   = "TerraformBootstrap"
    Portfolio   = "true"
    DataClass   = "synthetic-only"
  }
}

data "aws_iam_policy_document" "deployment_trust" {
  statement {
    sid     = "ReadOnlyUserWithMFA"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [local.bootstrap_user_arn]
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role" "deployment" {
  name                 = local.deployment_role_name
  description          = "Short-lived Terraform execution role for the CareFlow sandbox"
  assume_role_policy   = data.aws_iam_policy_document.deployment_trust.json
  max_session_duration = 3600
  tags                 = local.common_tags
}

resource "aws_iam_role_policy" "deployment" {
  name   = "careflow-sandbox-deployment"
  role   = aws_iam_role.deployment.id
  policy = data.aws_iam_policy_document.deployment.json

  depends_on = [aws_iam_role.platform_admin, aws_s3_bucket.state]
}

data "aws_iam_policy_document" "caller" {
  statement {
    sid       = "AssumeOnlyCareFlowDeploymentRoleWithMFA"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [local.deployment_role_arn]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_user_policy" "caller" {
  name   = "careflow-assume-deployment-role"
  user   = var.bootstrap_user_name
  policy = data.aws_iam_policy_document.caller.json

  depends_on = [aws_iam_role.deployment]
}

data "aws_iam_policy_document" "platform_admin_trust" {
  statement {
    sid     = "DeploymentRoleOnly"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [local.deployment_role_arn]
    }
  }
}

resource "aws_iam_role" "platform_admin" {
  name                 = local.platform_admin_name
  description          = "Separate kubectl identity granted cluster access by an EKS access entry"
  assume_role_policy   = data.aws_iam_policy_document.platform_admin_trust.json
  max_session_duration = 3600
  tags                 = local.common_tags

  depends_on = [aws_iam_role.deployment]
}

data "aws_iam_policy_document" "platform_admin" {
  statement {
    sid       = "DescribeCareFlowCluster"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:${var.aws_region}:${var.account_id}:cluster/${var.project_name}-primary"]
  }
}

resource "aws_iam_role_policy" "platform_admin" {
  name   = "describe-careflow-cluster"
  role   = aws_iam_role.platform_admin.id
  policy = data.aws_iam_policy_document.platform_admin.json
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name
  tags   = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# trivy:ignore:AVD-AWS-0132 -- SSE-S3 is the deliberate low-cost sandbox choice; state access is role-scoped and TLS-only.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    actions = [
      "s3:*",
    ]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "DenyStateListingOutsideDeploymentRole"
    effect    = "Deny"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = [local.deployment_role_arn, local.bootstrap_user_arn]
    }
  }

  statement {
    sid    = "DenyStateObjectsOutsideDeploymentRole"
    effect = "Deny"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "${local.state_bucket_arn}/${local.primary_state_key}",
      "${local.state_bucket_arn}/${local.primary_state_key}.tflock",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = [local.deployment_role_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_repository == null ? 0 : 1

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = local.common_tags
}

data "aws_iam_policy_document" "github_publish_trust" {
  count = var.github_repository == null ? 0 : 1

  statement {
    sid     = "ExactRepositoryEnvironment"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_publish" {
  count = var.github_repository == null ? 0 : 1

  name                 = local.github_publish_name
  description          = "GitHub OIDC role restricted to publishing the CareFlow ECR image"
  assume_role_policy   = data.aws_iam_policy_document.github_publish_trust[0].json
  max_session_duration = 3600
  tags                 = local.common_tags
}

data "aws_iam_policy_document" "github_publish" {
  count = var.github_repository == null ? 0 : 1

  statement {
    sid       = "EcrLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PublishCareFlowOnly"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/${local.ecr_repository_name}"]
  }
}

resource "aws_iam_role_policy" "github_publish" {
  count = var.github_repository == null ? 0 : 1

  name   = "publish-careflow-image"
  role   = aws_iam_role.github_publish[0].id
  policy = data.aws_iam_policy_document.github_publish[0].json
}
