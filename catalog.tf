/*resource "random_id" "rand" {
  byte_length = 4
}

resource "aws_s3_bucket" "my-bucket" {
  bucket        = "ser-catalog-usecase-${random_id.rand.hex}"
  force_destroy = true
}

# resource "aws_s3_bucket_public_access_block" "test" {
#   bucket                  = aws_s3_bucket.my-bucket.id
#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

resource "aws_s3_object" "my-object" {
  bucket        = aws_s3_bucket.my-bucket.id
  key           = "my-ec2-template.yml"
  source        = "${path.module}/my-ec2-template.yml"
  etag          = filemd5("${path.module}/my-ec2-template.yml")
  content_type  = "text/yaml"
}

# IAM role for Service Catalog to launch EC2
# resource "aws_iam_role" "test_role" {
#   name = "sc-ec2-launch-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "servicecatalog.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

resource "aws_iam_role" "launch_constraint_role" {
  name = "sc-ec2-launch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "servicecatalog.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_full_access" {
  role       = aws_iam_role.launch_constraint_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# resource "aws_iam_role_policy_attachment" "ec2_full_access" {
#   role       = aws_iam_role.test_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
# }

# resource "aws_iam_role_policy_attachment" "cloudformation_full_access" {
#   role       = aws_iam_role.test_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
# }

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
    "RoleArn" = aws_iam_role.test_role.arn
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
  role       = aws_iam_role.sc_end_user_role.name
  policy_arn = aws_iam_policy.end_user_policy.arn
}

# Data source to get account ID
data "aws_caller_identity" "current" {}*/


# Create a unique S3 bucket for templates

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "template_bucket" {
  bucket = "svc-catalog-templates-${random_id.bucket_suffix.hex}"
}

## 1. Create Service Catalog Portfolio
resource "aws_servicecatalog_portfolio" "web_app_portfolio" {
  name          = "WebApplicationPortfolio"
  description   = "Portfolio for web application products"
  provider_name = "IT Department"
}

## 2. Create IAM Role for Launch Constraints with proper permissions
resource "aws_iam_role" "launch_constraint_role" {
  name = "SCWebAppLaunchRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "servicecatalog.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy_attachment" "launch_constraint_policy" {
  role       = aws_iam_role.launch_constraint_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Add additional permissions needed by Service Catalog
resource "aws_iam_role_policy" "service_catalog_policy" {
  name = "ServiceCatalogAdditionalPermissions"
  role = aws_iam_role.launch_constraint_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        Effect   = "Allow",
        Resource = "${aws_s3_bucket.template_bucket.arn}/*"
      },
      {
        Action = [
          "cloudformation:*",
          "servicecatalog:*"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

## 3. Create CloudFormation Template for Web App
data "template_file" "web_app_template" {
  template = file("${path.module}/myec2-template.yml")
}

resource "aws_s3_object" "web_app_template" {
  bucket  = aws_s3_bucket.template_bucket.bucket
  key     = "templates/ec2_instance.yaml"
  content = data.template_file.web_app_template.rendered
}

## 4. Create Service Catalog Product
resource "aws_servicecatalog_product" "web_app_product" {
  name             = "WebApplicationProduct"
  owner            = "IT Department"
  type             = "CLOUD_FORMATION_TEMPLATE"
  description      = "Web Application with EC2 and ALB"

  provisioning_artifact_parameters {
    description          = "Initial version"
    name                 = "v1.0"
    template_url         = "https://${aws_s3_bucket.template_bucket.bucket_regional_domain_name}/${aws_s3_object.web_app_template.key}"
    type                 = "CLOUD_FORMATION_TEMPLATE"
  }

  tags = {
    "Category" = "WebApplications"
  }
}

## 5. Associate Product with Portfolio
resource "aws_servicecatalog_product_portfolio_association" "web_app_association" {
  portfolio_id = aws_servicecatalog_portfolio.web_app_portfolio.id
  product_id   = aws_servicecatalog_product.web_app_product.id
}

## 6. Add Launch Constraint
resource "aws_servicecatalog_constraint" "web_app_launch_constraint" {
  description  = "Launch constraint for web application"
  portfolio_id = aws_servicecatalog_portfolio.web_app_portfolio.id
  product_id   = aws_servicecatalog_product.web_app_product.id
  type         = "LAUNCH"

  parameters = jsonencode({
    "RoleArn" : aws_iam_role.launch_constraint_role.arn
  })

  depends_on = [
    aws_iam_role_policy.service_catalog_policy,
    aws_iam_role_policy_attachment.launch_constraint_policy
  ]
}

## 7. Grant Access to Users/Groups
resource "aws_servicecatalog_principal_portfolio_association" "developer_access" {
  portfolio_id  = aws_servicecatalog_portfolio.web_app_portfolio.id
  principal_arn = "arn:aws:iam::211125784755:user/kumari"
}