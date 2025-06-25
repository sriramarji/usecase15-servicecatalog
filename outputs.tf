# output "cloudformation_template_url" {
#   value = "https://${aws_s3_bucket.my-bucket.bucket}.s3.amazonaws.com/${aws_s3_object.my-object.key}"
# }

output "product_name" {
  description = "Service Catalog product name"
  value       = aws_servicecatalog_product.web_app_product.name
}

output "portfolio_name" {
  description = "Service Catalog portfolio name"
  value       = aws_servicecatalog_portfolio.web_app_product.name
}