plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Enforce version constraints
rule "terraform_required_version" {
  enabled = true
}

# Enforce consistent variable types
rule "terraform_typed_variables" {
  enabled = true
}

# Configure AWS provider version constraints
rule "terraform_required_providers" {
  enabled = true
}