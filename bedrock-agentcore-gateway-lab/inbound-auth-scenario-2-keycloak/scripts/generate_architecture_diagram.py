"""
Renders scenario 2's concrete architecture (self-hosted Keycloak, CUSTOM_JWT
Gateway) for its own README, using official AWS Architecture Icons.

AgentCore has no dedicated icon in this library yet (too new - GA 2025),
so the general Bedrock icon stands in for "AgentCore Gateway", relabeled.
Keycloak isn't an AWS service, so it's shown as a generic Docker container
icon (how it's actually deployed: a container on App Runner) rather than a
fabricated "AWS icon" for third-party software.

Usage:
    /path/to/.diagrams-venv/bin/python generate_architecture_diagram.py
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, AppRunner, ECR, Lambda
from diagrams.aws.ml import Bedrock
from diagrams.aws.network import VPC
from diagrams.aws.security import IAM
from diagrams.onprem.container import Docker

graph_attr = {
    "fontsize": "22",
    "bgcolor": "white",
    "pad": "0.4",
    "splines": "spline",
}

with Diagram(
    "Gateway Auth Lab - Scenario 2: Keycloak",
    filename="architecture",
    outformat="png",
    graph_attr=graph_attr,
    direction="LR",
    show=False,
):
    with Cluster("Keycloak hosting (outside the VPC - public HTTPS, like Cognito)"):
        ecr = ECR("ECR\n(mirrored image)")
        apprunner = AppRunner("App Runner\n(start-dev, ephemeral H2)")
        keycloak = Docker("Keycloak\n(realm + client)")

        ecr >> Edge(label="manual pull/tag/push") >> apprunner
        apprunner >> keycloak

    with Cluster("AgentCore"):
        gateway_role = IAM("gateway_exec role")
        gateway = Bedrock("Gateway\n(CUSTOM_JWT, MCP)")

    with Cluster("VPC 10.44.0.0/16"):
        with Cluster("Public subnet"):
            nat = EC2("NAT instance\n(t4g.nano)")
        with Cluster("Private subnet"):
            ping = Lambda("ping tool")

    keycloak >> Edge(label="discovery_url,\nallowed_clients") >> gateway
    gateway_role >> gateway
    gateway >> Edge(label="gateway_iam_role") >> ping
    nat >> Edge(label="0.0.0.0/0 egress", style="dashed") >> ping
