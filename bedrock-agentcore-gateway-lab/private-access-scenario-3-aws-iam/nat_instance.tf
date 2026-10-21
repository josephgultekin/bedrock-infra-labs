# A NAT instance, not a NAT Gateway - see README for why. Amazon Linux 2023
# (arm64, matching t4g.nano's Graviton CPU) with a small user_data script
# that turns on IP forwarding and masquerades outbound traffic. Managed via
# SSM Session Manager only - no key pair, no open SSH port.

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_iam_role" "nat_instance" {
  name = "${var.project_name}-nat-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nat_instance_ssm" {
  role       = aws_iam_role.nat_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat_instance" {
  name = "${var.project_name}-nat-instance"
  role = aws_iam_role.nat_instance.name
}

resource "aws_instance" "nat" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = var.nat_instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.nat_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.nat_instance.name

  # Required for a NAT instance: it must be allowed to forward traffic that
  # isn't addressed to itself.
  source_dest_check = false

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-nat.conf
    sysctl -p /etc/sysctl.d/99-nat.conf

    cat <<'SCRIPT' > /usr/local/sbin/enable-nat.sh
    #!/bin/bash
    set -euxo pipefail
    IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
    iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
    SCRIPT
    chmod +x /usr/local/sbin/enable-nat.sh

    cat <<'UNIT' > /etc/systemd/system/nat-masquerade.service
    [Unit]
    Description=Enable NAT masquerade for private subnet egress
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/usr/local/sbin/enable-nat.sh

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable --now nat-masquerade.service
  EOF

  tags = {
    Name = "${var.project_name}-nat-instance"
  }
}

resource "aws_eip" "nat" {
  domain   = "vpc"
  instance = aws_instance.nat.id

  tags = {
    Name = "${var.project_name}-nat-instance"
  }
}
