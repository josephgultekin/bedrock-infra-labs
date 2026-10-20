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
# Shared by the Lambda tools and the AgentCore Runtime's VPC attachment.
# Nothing inbound ever initiates to either of these from within the VPC, so
# there's no ingress rule at all - only egress, for calling AWS service
# endpoints (via the NAT instance) and, for the Runtime, the AgentCore
# Gateway.

resource "aws_security_group" "private_compute" {
  name        = "${var.project_name}-private-compute"
  description = "Lambda tools and the AgentCore Runtime VPC attachment"
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
