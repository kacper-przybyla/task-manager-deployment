resource "aws_iam_openid_connect_provider" "github" {
    url = "https://token.actions.githubusercontent.com"
    client_id_list = ["sts.amazonaws.com"]
    thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "trust" {
    statement {
        effect = "Allow"
        actions = ["sts:AssumeRoleWithWebIdentity"]

        principals {
            type = "Federated"
            identifiers = [aws_iam_openid_connect_provider.github.arn]
        }

        condition {
            test = "StringEquals"
            variable = "token.actions.githubusercontent.com:aud"
            values = ["sts.amazonaws.com"]
        }

        condition {
            test = "StringLike"
            variable = "token.actions.githubusercontent.com:sub"
            values = ["repo:kacper-przybyla/task-manager-deployment:*"]
        }
    }
}

resource "aws_iam_role" "github_actions" {
    name = "github-actions-task-manager"
    assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy_attachment" "ec2" {
    role = aws_iam_role.github_actions.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

data "aws_iam_policy_document" "s3_state" {
  statement {
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject", 
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::kacper-przybyla-terraform-state",
      "arn:aws:s3:::kacper-przybyla-terraform-state/*"
    ]
  }
}

resource "aws_iam_policy" "s3_state" {
    name = "github-actions-task-manager-s3-state"
    policy = data.aws_iam_policy_document.s3_state.json
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.s3_state.arn
}

resource "aws_iam_role_policy_attachment" "iam_read" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}