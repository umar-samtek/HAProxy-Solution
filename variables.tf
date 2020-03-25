variable "s3_bucket" {
  default     = "idr-haproxy-9ew9"
  description = "Name of the S3 bucket we are creating the proxy for" # FIXME: We need to handle more than one bucket
}

variable "iam_instance_profile" {
  default     = "s3-access-haproxy" # FIXME: We should be creating this instance profile
  description = "Name of the instance profile assigned to the EC2 instances"
}

variable "name" {
  default     = "idr-haproxy"
  description = "General name for all resources in AWS created with this module"
}

variable "key_name" {
  default     = "key-cms-idr-cloud"
  description = "Name of the EC2 Key to assign to the Instances" #TODO: Also accept pubkey
}

variable "instance_type" {
  default     = "t2.micro"
  description = "Type of EC2 instances to launch with the ASG"
}

variable "root_block_size" {
  default     = "50"
  description = "Size of the root volume in GB"
}

variable "ebs_block_size" {
  default     = "50"
  description = "Size of the data volume in GB"
}

variable "min_size" {
  default     = 1
  description = "Min number of instances in the ASG"
}

variable "max_size" {
  default     = 2
  description = "Max number of instances in the ASG"
}

variable "desired_capacity" {
  default     = 1
  description = "Desired number of instances in the ASG"
}

variable "environment" {
  default     = "dev"
  description = "Name of the environment, used in tags" # TODO: Allow more flexibility with tags
}

variable "vpc_name" {
  description = "Name of the VPC the ha proxy set up will be created in"
  default     = "idr-cloud-dev"
}

variable "subnet_names" {
  description = "Names of private subnets to launch HA proxy resources and NLB in"
  type        = list
  default     = ["idr-cloud-dev-data-a", "idr-cloud-dev-data-b"]
}

#FIXME: This assumes two subnets, we need to make this a list, so we can handle more or less than 2
variable "route_table1" {
  description = "Name of the route table associated with the first subnet"
  default     = "idr-cloud-dev-data-a"
}

variable "route_table2" {
  description = "Name of the route table associated with the second subnet"
  default     = "idr-cloud-dev-data-b"
}

variable "iam_policy" {
  description = "IAM policy to be associated via HA Proxy Instance Profiles"
  default     = <<EOF
{
"Version": "2012-10-17",
"Statement": [
    {
        "Effect": "Allow",
        "Action": "s3:*",
        "Resource": "*"
    }
]
}
EOF
}
