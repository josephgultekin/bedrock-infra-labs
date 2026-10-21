"""
Renders scenario 3's concrete architecture (AWS_IAM Gateway, locked to one
VPC-endpoint-scoped IAM role) for its own README, using official AWS
Architecture Icons.

AgentCore has no dedicated icon in this library yet (too new - GA 2025),
so the general Bedrock icon stands in for "AgentCore Gateway", relabeled.

Usage:
    /path/to/.diagrams-venv/bin/python generate_architecture_diagram.py
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, Lambda
from diagrams.aws.ml import Bedrock
from diagrams.aws.network import Privatelink, VPC
from diagrams.aws.security import IAM

graph_attr = {
    "fontsize": "22",
    "bgcolor": "white",
    "pad": "0.4",
    "splines": "spline",
}

with Diagram(
    "Gateway Auth Lab - Scenario 3: Private AWS_IAM Gateway",
    filename="architecture",
    outformat="png",
    graph_attr=graph_attr,
    direction="LR",
    show=False,
):
    with Cluster("VPC 10.45.0.0/16"):
        with Cluster("Public subnet"):
            nat = EC2("NAT instance\n(t4g.nano)\nbootstrap egress only")

        with Cluster("Private subnet"):
            bastion = EC2("Test bastion\n(t4g.micro, SSM-only)")
            role = IAM("bastion role\naws:SourceVpce condition")
            endpoint = Privatelink("Interface VPC Endpoint\ncom.amazonaws.*.bedrock-agentcore.gateway\nrestrictive policy")
            ping = Lambda("ping tool")

    gateway = Bedrock("AgentCore Gateway\n(AWS_IAM, MCP)")

    role >> bastion
    bastion >> Edge(label="SigV4, only valid\nvia the endpoint", style="bold") >> endpoint
    endpoint >> gateway
    gateway >> Edge(label="gateway_iam_role") >> ping
    nat >> Edge(label="pip install, via NAT", style="dashed") >> bastion
