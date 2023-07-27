# Configure the AWS provider with the desired region
provider "aws" {
  region = "us-east-1"
}

# Define a variable for the domain name with a default value
variable "domain_name_simple" {
  type    = string
  default = "new-domain.tk"
}

# Create an S3 bucket to store the static website files
resource "aws_s3_bucket" "website_bucket" {
  bucket = "rohit-bucket-devops-tf"
}

# Configure AWS S3 bucket access permissions
resource "aws_s3_account_public_access_block" "website_bucket" {
  block_public_acls         = true
  block_public_policy       = true
  ignore_public_acls        = true
  restrict_public_buckets   = true
}

# Upload the index.html file to the S3 bucket
resource "aws_s3_object" "website_bucket" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  source       = "html/index.html"
  content_type = "text/html"
}

# Create an AWS CloudFront distribution for the static website
resource "aws_cloudfront_distribution" "cdn_static_site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "my cloudfront in front of the s3 bucket"

  # Configure the origin for the CloudFront distribution
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id                = "my-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  # Define aliases (CNAMEs) for the CloudFront distribution
  aliases = ["new-domain.tk"]

  # Configure default cache behavior for the distribution
  default_cache_behavior {
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "my-s3-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # Configure restrictions for the CloudFront distribution
  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  # Configure SSL certificate for the distribution
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# Create an SSL certificate using AWS ACM (Amazon Certificate Manager)
resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain_name_simple
  validation_method         = "DNS"
  subject_alternative_names = [var.domain_name_simple]

  lifecycle {
    create_before_destroy = true
  }
}

# Fetch the Route53 hosted zone information for the specified domain name
data "aws_route53_zone" "zone" {
  provider     = aws
  name         = var.domain_name_simple
  private_zone = false
}

# Create Route53 records to validate the SSL certificate
resource "aws_route53_record" "cert_validation" {
  provider = aws
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone.zone_id
  ttl             = 60
}

# Validate the SSL certificate
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Create an A record for the apex domain that points to the AWS CloudFront distribution
resource "aws_route53_record" "apex" {
  zone_id = data.aws_route53_zone.zone.id
  name    = var.domain_name_simple
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site.domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site.hosted_zone_id
    evaluate_target_health = false
  }
}

# Create an AWS CloudFront origin access control for signing requests
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "cloudfront OAC"
  description                       = "description of OAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Output the CloudFront distribution URL
output "cloudfront_url" {
  value = aws_cloudfront_distribution.cdn_static_site.domain_name
}

# Generate IAM policy document to allow CloudFront to access the S3 bucket
data "aws_iam_policy_document" "website_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website_bucket.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.cdn_static_site.arn]
    }
  }
}

# Attach the IAM policy to the S3 bucket
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  policy = data.aws_iam_policy_document.website_bucket.json
}
