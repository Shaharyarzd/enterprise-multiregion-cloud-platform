locals {
  oidc_issuer = replace(var.oidc_provider, "https://", "")
}

data "aws_iam_policy_document" "careflow_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:careflow:careflow-api"]
    }
  }
}

resource "aws_iam_role" "careflow_secrets" {
  name               = "${var.name}-careflow-secrets"
  assume_role_policy = data.aws_iam_policy_document.careflow_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "careflow_secrets" {
  statement {
    sid       = "ReadOnlyManagedDatabaseSecret"
    actions   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue"]
    resources = [var.database_secret_arn]
  }
}

resource "aws_iam_role_policy" "careflow_secrets" {
  name   = "read-database-secret"
  role   = aws_iam_role.careflow_secrets.id
  policy = data.aws_iam_policy_document.careflow_secrets.json
}

data "aws_iam_policy_document" "load_balancer_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "${var.name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "load_balancer_controller" {
  name   = "manage-alb-resources"
  role   = aws_iam_role.load_balancer_controller.id
  policy = file("${path.module}/policies/aws-load-balancer-controller-v3.5.0.json")
}
