# ---------- NAT instance security group ----------

resource "aws_security_group" "nat_instance" {
  name        = "${var.project_name}-nat-instance"
  description = "NAT instance: accepts forwarded traffic from private subnets in this VPC, egresses anywhere"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "All traffic from inside this VPC, to be forwarded/NATed out"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-nat-instance"
  }
}

# ---------- Private compute security group ----------
#
# Used by the ping Lambda tool. Nothing inbound ever initiates to it from
# within the VPC, so there's no ingress rule at all - only egress, for
# calling AWS service endpoints (via the NAT instance) and the AgentCore
# Gateway (via the VPC endpoint below).

resource "aws_security_group" "private_compute" {
  name        = "${var.project_name}-private-compute"
  description = "Lambda tools in this scenario's private subnets"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "Outbound internet/AWS API access via the NAT instance"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-private-compute"
  }
}

# ---------- Bastion security group ----------
#
# The test bastion (bastion.tf). No ingress at all - SSM Session Manager
# is outbound-initiated from the instance, no inbound port needed.

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion"
  description = "Test bastion: pip installs via NAT, calls the Gateway via the VPC endpoint"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "Outbound to NAT (pip installs) and to the VPC endpoint (443)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

# ---------- VPC endpoint security group ----------
#
# The Gateway PrivateLink interface endpoint's ENIs. Only the bastion is
# allowed to reach it - least privilege, since the bastion is the only
# intended caller in this lab.

resource "aws_security_group" "vpc_endpoint" {
  name        = "${var.project_name}-vpc-endpoint"
  description = "AgentCore Gateway interface VPC endpoint: HTTPS from the bastion only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "HTTPS from the bastion"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Unrestricted egress for the endpoint ENIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vpc-endpoint"
  }
}
