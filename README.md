# S3 Proxy Solution via CMSNet using VPCEndpoint

### Introduction

This repository contains a simple terraform implementation of the solution described [here](https://confluence.cms.gov/pages/viewpage.action?spaceKey=GDITAQ&title=S3+Proxy+Solution+via+CMSNet)

### Usage

Modify the variables in the `variables.tf` file per your environment and then run the following on
the command line:

`terraform plan` # Review printed plan
`terraform apply` # To create/update the infrastructure

#### Providers

| Name | Version |
|------|---------|
| aws | n/a |

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| desired\_capacity | Desired number of instances in the ASG | `number` | `1` | no |
| ebs\_block\_size | Size of the data volume in GB | `string` | `"50"` | no |
| environment | Name of the environment, used in tags | `string` | `"dev"` | no |
| iam\_instance\_profile | Name of the instance profile assigned to the EC2 instances | `string` | `"s3-access-haproxy"` | no |
| iam\_policy | IAM policy to be associated via HA Proxy Instance Profiles | `string` | `"{\n    \"Version\": \"2012-10-17\",\n    \"Statement\": [\n        {\n            \"Effect\": \"Allow\",\n            \"Action\": \"s3:*\",\n            \"Resource\": \"*\"\n        }\n    ]\n}\n"` | no |
| instance\_type | Type of EC2 instances to launch with the ASG | `string` | `"t2.micro"` | no |
| key\_name | Name of the EC2 Key to assign to the Instances | `string` | `"key-cms-idr-cloud"` | no |
| max\_size | Max number of instances in the ASG | `number` | `2` | no |
| min\_size | Min number of instances in the ASG | `number` | `1` | no |
| name | General name for all resources in AWS created with this module | `string` | `"idr-haproxy"` | no |
| root\_block\_size | Size of the root volume in GB | `string` | `"50"` | no |
| route\_table1 | Name of the route table associated with the first subnet | `string` | `"idr-cloud-dev-data-a"` | no |
| route\_table2 | Name of the route table associated with the second subnet | `string` | `"idr-cloud-dev-data-b"` | no |
| s3\_bucket | Name of the S3 bucket we are creating the proxy for | `string` | `"idr-haproxy-9ew9"` | no |
| subnet\_names | Names of private subnets to launch HA proxy resources and NLB in | `list` | <pre>[<br>  "idr-cloud-dev-data-a",<br>  "idr-cloud-dev-data-b"<br>]</pre> | no |
| vpc\_name | Name of the VPC the ha proxy set up will be created in | `string` | `"idr-cloud-dev"` | no |

## Outputs

No output.
