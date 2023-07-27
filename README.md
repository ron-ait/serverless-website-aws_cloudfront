# Terraform AWS Static Website Deployment

This Terraform configuration deploys a static website on AWS, serving it through an S3 bucket and distributing it globally using AWS CloudFront. The static website is secured with HTTPS using an SSL certificate from Amazon Certificate Manager (ACM). DNS records are managed in AWS Route53 for the website's domain.

## Prerequisites

To use this Terraform configuration, you need the following:

1. Terraform installed on your machine.
2. AWS CLI configured with appropriate credentials and permissions.

## Configuration

Before running the Terraform script, modify the following variables in `main.tf` to suit your requirements:

- `domain_name_simple`: Set your domain name for the static website (e.g., "example.com").

## Usage

1. Initialize Terraform in the project directory:

   ```bash
   terraform init
   
   #View the plan to understand the changes that will be applied:
   terraform plan

   #Apply the changes to create the AWS resources:
   terraform apply

After successful execution, the CloudFront distribution URL will be shown in the output.

Once deployed, upload your static website files to the S3 bucket. For example, upload your _index.html_ to the bucket.


## Clean Up
To clean up and delete the AWS resources created by this Terraform configuration:

Run the following command to destroy the resources:

  `terraform destroy`

  
## Note
1. Make sure to add the actual static website files, like index.html, to the html directory before running Terraform.
2. Ensure your domain name is properly registered in Route53 or managed by AWS Route53.
3. The ACM certificate validation may take some time to complete before CloudFront becomes fully operational.
4. Be cautious when running terraform destroy as it will remove all resources created by this configuration.

## Resources
For more information on Terraform and AWS, refer to their official documentation:

<u>Terraform Documentation</u>
<u>AWS Documentation</u>
