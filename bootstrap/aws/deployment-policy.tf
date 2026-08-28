data "aws_iam_policy_document" "deployment" {
  statement {
    sid    = "ReadDeploymentDependencies"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ecr:Describe*",
      "ecr:Get*",
      "eks:Describe*",
      "eks:List*",
      "iam:Get*",
      "iam:List*",
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "logs:Describe*",
      "logs:List*",
      "rds:Describe*",
      "rds:ListTagsForResource",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
      "ssm:GetParameter",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageProjectNetworking"
    effect = "Allow"
    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:CreateInternetGateway",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:CreateNetworkAclEntry",
      "ec2:CreateNatGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:CreateVpcEndpoint",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteLaunchTemplate",
      "ec2:DeleteLaunchTemplateVersions",
      "ec2:DeleteNatGateway",
      "ec2:DeleteNetworkAclEntry",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVpc",
      "ec2:DeleteVpcEndpoints",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateAddress",
      "ec2:DisassociateRouteTable",
      "ec2:ModifyLaunchTemplate",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:ReleaseAddress",
      "ec2:ReplaceNetworkAclEntry",
      "ec2:ReplaceRoute",
      "ec2:ReplaceRouteTableAssociation",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "RunApprovedProjectInstances"
    effect    = "Allow"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:${var.aws_region}:${var.account_id}:instance/*"]

    condition {
      test     = "ArnLike"
      variable = "ec2:LaunchTemplate"
      values   = ["arn:aws:ec2:${var.aws_region}:${var.account_id}:launch-template/*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:InstanceType"
      values   = ["c7i-flex.large"]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:MetadataHttpTokens"
      values   = ["required"]
    }
  }

  statement {
    sid     = "RunInstancesWithProjectCreatedResources"
    effect  = "Allow"
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${var.account_id}:network-interface/*",
      "arn:aws:ec2:${var.aws_region}:${var.account_id}:volume/*",
    ]

    condition {
      test     = "ArnLike"
      variable = "ec2:LaunchTemplate"
      values   = ["arn:aws:ec2:${var.aws_region}:${var.account_id}:launch-template/*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid     = "RunInstancesWithTaggedProjectDependencies"
    effect  = "Allow"
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${var.account_id}:launch-template/*",
      "arn:aws:ec2:${var.aws_region}:${var.account_id}:security-group/*",
      "arn:aws:ec2:${var.aws_region}:${var.account_id}:subnet/*",
    ]

    condition {
      test     = "ArnLike"
      variable = "ec2:LaunchTemplate"
      values   = ["arn:aws:ec2:${var.aws_region}:${var.account_id}:launch-template/*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid     = "RunInstancesFromAmazonOwnedImages"
    effect  = "Allow"
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:aws:ec2:${var.aws_region}::image/ami-*",
      "arn:aws:ec2:${var.aws_region}:*:snapshot/*",
    ]

    condition {
      test     = "ArnLike"
      variable = "ec2:LaunchTemplate"
      values   = ["arn:aws:ec2:${var.aws_region}:${var.account_id}:launch-template/*"]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:Owner"
      values   = ["amazon"]
    }
  }

  statement {
    sid       = "ReadAccountPlanForApplyGate"
    effect    = "Allow"
    actions   = ["freetier:GetAccountPlanState"]
    resources = ["*"]
  }

  statement {
    sid    = "ManageProjectEks"
    effect = "Allow"
    actions = [
      "eks:AssociateAccessPolicy",
      "eks:CreateAccessEntry",
      "eks:CreateAddon",
      "eks:DeleteAccessEntry",
      "eks:DeleteAddon",
      "eks:DeleteCluster",
      "eks:DeleteNodegroup",
      "eks:DescribeAccessEntry",
      "eks:DescribeAccessPolicy",
      "eks:DisassociateAccessPolicy",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:UpdateAddon",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion",
    ]
    resources = [
      "arn:aws:eks:${var.aws_region}:${var.account_id}:cluster/${var.project_name}-*",
      "arn:aws:eks:${var.aws_region}:${var.account_id}:nodegroup/${var.project_name}-*/*/*",
      "arn:aws:eks:${var.aws_region}:${var.account_id}:addon/${var.project_name}-*/*/*",
      "arn:aws:eks:${var.aws_region}:${var.account_id}:access-entry/${var.project_name}-*/*/*/*/*",
    ]
  }

  statement {
    sid    = "CreateEksWithProjectTag"
    effect = "Allow"
    actions = [
      "eks:CreateCluster",
      "eks:CreateNodegroup",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "ManageProjectDatabase"
    effect = "Allow"
    actions = [
      "rds:AddTagsToResource",
      "rds:DeleteDBInstance",
      "rds:DeleteDBParameterGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:ModifyDBInstance",
      "rds:ModifyDBParameterGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:RemoveTagsFromResource",
      "rds:ResetDBParameterGroup",
    ]
    resources = [
      "arn:aws:rds:${var.aws_region}:${var.account_id}:db:${var.project_name}-*",
      "arn:aws:rds:${var.aws_region}:${var.account_id}:pg:${var.project_name}-*",
      "arn:aws:rds:${var.aws_region}:${var.account_id}:subgrp:${var.project_name}-*",
    ]
  }

  statement {
    sid    = "CreateTaggedDatabaseResources"
    effect = "Allow"
    actions = [
      "rds:CreateDBInstance",
      "rds:CreateDBParameterGroup",
      "rds:CreateDBSubnetGroup",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "ManageProjectEcr"
    effect = "Allow"
    actions = [
      "ecr:DeleteLifecyclePolicy",
      "ecr:DeleteRepository",
      "ecr:ListTagsForResource",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:PutLifecyclePolicy",
      "ecr:TagResource",
      "ecr:UntagResource",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/${var.project_name}/*"]
  }

  statement {
    sid       = "CreateTaggedProjectEcrRepository"
    effect    = "Allow"
    actions   = ["ecr:CreateRepository"]
    resources = ["arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/${var.project_name}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "ManageProjectIam"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:TagRole",
      "iam:UntagPolicy",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRoleDescription",
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:role/${var.project_name}-*",
      "arn:aws:iam::${var.account_id}:policy/${var.project_name}-*",
    ]
  }

  statement {
    sid    = "ManageEksWorkloadOidcProviders"
    effect = "Allow"
    actions = [
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
    ]
    resources = ["arn:aws:iam::${var.account_id}:oidc-provider/oidc.eks.${var.aws_region}.amazonaws.com/id/*"]
  }

  statement {
    sid       = "CreateTaggedEksWorkloadOidcProvider"
    effect    = "Allow"
    actions   = ["iam:CreateOpenIDConnectProvider"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid       = "CreateRequiredServiceLinkedRoles"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${var.account_id}:role/aws-service-role/*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "autoscaling.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "eks.amazonaws.com",
        "rds.amazonaws.com",
        "spot.amazonaws.com",
      ]
    }
  }

  statement {
    sid       = "CreateEksNodegroupServiceLinkedRole"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${var.account_id}:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["eks-nodegroup.amazonaws.com"]
    }
  }

  statement {
    sid     = "PassOnlyProjectRolesToEksAndEc2"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${var.account_id}:role/${var.project_name}-*",
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com", "eks.amazonaws.com"]
    }
  }

  statement {
    sid       = "AssumePlatformAdminForKubectl"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [local.platform_admin_arn]
  }

  statement {
    sid       = "CreateTaggedProjectKmsKey"
    effect    = "Allow"
    actions   = ["kms:CreateKey"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "ManageTaggedProjectKmsKey"
    effect = "Allow"
    actions = [
      "kms:CancelKeyDeletion",
      "kms:CreateGrant",
      "kms:DisableKey",
      "kms:EnableKey",
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateKeyDescription",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "ManageProjectKmsAliases"
    effect = "Allow"
    actions = [
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:UpdateAlias",
    ]
    resources = [
      "arn:aws:kms:${var.aws_region}:${var.account_id}:alias/${var.project_name}-*",
      "arn:aws:kms:${var.aws_region}:${var.account_id}:alias/eks/${var.project_name}-*",
      "arn:aws:kms:${var.aws_region}:${var.account_id}:key/*",
    ]
  }

  statement {
    sid    = "ManageProjectLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:ListTagsForResource",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/eks/${var.project_name}-*"]
  }

  statement {
    sid    = "ReadManagedDatabaseSecretMetadata"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:rds!db-*"]
  }

  statement {
    sid       = "CreateRdsManagedDatabaseSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:CreateSecret"]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:rds!db-*"]

    condition {
      test     = "StringLike"
      variable = "secretsmanager:Name"
      values   = ["rds!db-*"]
    }
  }

  statement {
    sid       = "TagRdsManagedDatabaseSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:TagResource"]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:rds!db-*"]
  }

  statement {
    sid    = "ReadPrimaryTerraformStateBucketMetadata"
    effect = "Allow"
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
    ]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid       = "ListOnlyPrimaryTerraformStatePath"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        local.primary_state_key,
        "${local.primary_state_key}.*",
      ]
    }
  }

  statement {
    sid    = "PrimaryTerraformStateObjects"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "${local.state_bucket_arn}/${local.primary_state_key}",
      "${local.state_bucket_arn}/${local.primary_state_key}.tflock",
    ]
  }
}
