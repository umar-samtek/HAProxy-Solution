##############################################################
# Data sources to get VPC, subnets and security group details
##############################################################
data "aws_vpc" "default" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet_ids" "all" {
  filter {
    name   = "tag:Name"
    values = var.subnet_names
  }
  vpc_id = data.aws_vpc.default.id
}


data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["743302140042"] # Amazon

  filter {
    name = "name"

    values = [
      "amzn2-gi-*"
    ]
  }
}

data "aws_route_table" "rt1" {
  filter {
    name   = "tag:Name"
    values = [var.route_table1]
  }
  vpc_id = data.aws_vpc.default.id
}

data "aws_route_table" "rt2" {
  filter {
    name   = "tag:Name"
    values = [var.route_table2]
  }
  vpc_id = data.aws_vpc.default.id
}
