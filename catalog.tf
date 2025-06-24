resource "random_id" "rand" {
  byte_length = 4
}

resource "aws_s3_bucket" "my-bucket" {
  bucket        = "ser-catalog-usecase-${random_id.rand.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "test" {
  bucket                  = aws_s3_bucket.my-bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "my-object" {
  bucket        = aws_s3_bucket.my-bucket.id
  key           = "my-ec2-template.yml"
  source        = "${path.module}/my-ec2-template.yml"
  etag          = filemd5("${path.module}/my-ec2-template.yml")
  content_type  = "text/yaml"
}


# IAM role for Service Catalog to launch EC2
resource "aws_iam_role" "test_role" {
  name = "sc-ec2-launch-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "servicecatalog.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_full_access" {
  role       = aws_iam_role.test_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "cloudformation_full_access" {
  role       = aws_iam_role.test_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
}

resource "aws_s3_bucket_policy" "allow_sc_launch_role_read" {
  bucket     = aws_s3_bucket.my-bucket.id
  depends_on = [aws_iam_role.test_role]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "AllowCloudFormationAndSCAccess",
        Effect   = "Allow",
        Principal = "*",
        Action   = ["s3:GetObject"],
        Resource = "${aws_s3_bucket.my-bucket.arn}/*",
        Condition = {
          StringEquals = {
            "aws:PrincipalArn" = aws_iam_role.test_role.arn
          }
        }
      }
    ]
  })
}


# Service Catalog portfolio
resource "aws_servicecatalog_portfolio" "portfolio" {
  name          = "DemoTools"
  description   = "Portfolio for launching EC2 with Hello World"
  provider_name = "Terraform"
}


# Service Catalog product
resource "aws_servicecatalog_product" "ec2_product" {
  name        = "HelloWorld"
  owner       = "Prod Team"
  description = "This product launches an EC2 instance displaying a Hello World page"
  type        = "CLOUD_FORMATION_TEMPLATE"

  provisioning_artifact_parameters {
    name         = "v1"
    description  = "Initial version"
    type         = "CLOUD_FORMATION_TEMPLATE"
    template_url = "https://${aws_s3_bucket.my-bucket.bucket}.s3.amazonaws.com/${aws_s3_object.my-object.key}"
  }

  tags = {
    Environment = "Dev"
  }
}

# Associate the product with the portfolio
resource "aws_servicecatalog_product_portfolio_association" "association" {
  portfolio_id = aws_servicecatalog_portfolio.portfolio.id
  product_id   = aws_servicecatalog_product.ec2_product.id
}

# Define a launch constraint
resource "aws_servicecatalog_constraint" "test_launch_constraint" {
  portfolio_id = aws_servicecatalog_portfolio.portfolio.id
  product_id   = aws_servicecatalog_product.ec2_product.id
  type         = "LAUNCH"
  parameters   = jsonencode({
    RoleArn = aws_iam_role.test_role.arn
  })
}

# IAM role for end user launching product
resource "aws_iam_role" "sc_end_user_role" {
  name = "enduser-role-servicecatalog"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_policy" "end_user_policy" {
  name = "enduser-policy-servicecatalog"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "servicecatalog:*",
          "cloudformation:GetTemplateSummary",
          "ec2:Describe*"
        ],
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "end_user_attach" {
  role       = aws_iam_role.test_role.name
  policy_arn = aws_iam_policy.end_user_policy.arn
}

# Data source to get account ID
data "aws_caller_identity" "current" {}