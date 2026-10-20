"""
Renders scenario 1's concrete architecture (Cognito-backed CUSTOM_JWT
Gateway) for its own README, using official AWS Architecture Icons.

AgentCore has no dedicated icon in this library yet (too new - GA 2025),
so the general Bedrock icon stands in for "AgentCore Gateway", relabeled.

Usage:
    /path/to/.diagrams-venv/bin/python generate_architecture_diagram.py
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, Lambda
from diagrams.aws.ml import Bedrock
from diagrams.aws.network import VPC
from diagrams.aws.security import Cognito, IAM

graph_attr = {
    "fontsize": "22",
    "bgcolor": "white",
    "pad": "0.4",
    "splines": "spline",
}

with Diagram(
    "Gateway Auth Lab - Scenario 1: Cognito",
    filename="architecture",
    outformat="png",
    graph_attr=graph_attr,
    direction="LR",
    show=False,
):
    cognito = Cognito("User Pool + Domain\n+ Resource Server\n+ App Client\n(client_credentials)")

    with Cluster("AgentCore"):
        gateway_role = IAM("gateway_exec role")
        gateway = Bedrock("Gateway\n(CUSTOM_JWT, MCP)")

    with Cluster(f"VPC 10.43.0.0/16"):
        with Cluster("Public subnet"):
            nat = EC2("NAT instance\n(t4g.nano)")
        with Cluster("Private subnet"):
            ping = Lambda("ping tool")

    cognito >> Edge(label="discovery_url,\nallowed_clients") >> gateway
    gateway_role >> gateway
    gateway >> Edge(label="gateway_iam_role") >> ping
    nat >> Edge(label="0.0.0.0/0 egress", style="dashed") >> ping
