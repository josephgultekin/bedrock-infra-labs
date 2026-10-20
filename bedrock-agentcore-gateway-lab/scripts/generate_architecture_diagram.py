"""
Renders a comparison diagram of this lab family's two inbound-auth
scenarios for the top-level README, using official AWS Architecture Icons
via the `diagrams` package.

AgentCore has no dedicated icon in this library yet (too new - GA 2025),
so the general Bedrock icon stands in for "AgentCore Gateway", relabeled.
Keycloak isn't an AWS service, so it's shown as a generic Docker container
icon (how it's actually deployed here: a container on App Runner) rather
than a fabricated "AWS icon" for third-party software.

Usage:
    /path/to/.diagrams-venv/bin/python generate_architecture_diagram.py
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, Lambda
from diagrams.aws.ml import Bedrock
from diagrams.aws.security import Cognito
from diagrams.onprem.container import Docker

graph_attr = {
    "fontsize": "22",
    "bgcolor": "white",
    "pad": "0.4",
    "splines": "spline",
}

with Diagram(
    "AgentCore Gateway Auth Lab - Scenario Comparison",
    filename="architecture",
    outformat="png",
    graph_attr=graph_attr,
    direction="LR",
    show=False,
):
    with Cluster("Scenario 1: Cognito (\"quick create\")"):
        cognito = Cognito("Cognito User Pool\n(provisioned by Terraform)")
        gateway_1 = Bedrock("AgentCore Gateway\n(CUSTOM_JWT, MCP)")
        lambda_1 = Lambda("ping tool\n(private subnet)")
        nat_1 = EC2("NAT instance\n(t4g.nano)")

        cognito >> Edge(label="discovery_url") >> gateway_1
        gateway_1 >> Edge(label="gateway_iam_role") >> lambda_1
        nat_1 >> Edge(label="0.0.0.0/0", style="dashed") >> lambda_1

    with Cluster("Scenario 2: Keycloak (\"existing IdP\")"):
        keycloak = Docker("Keycloak\n(App Runner, self-hosted)")
        gateway_2 = Bedrock("AgentCore Gateway\n(CUSTOM_JWT, MCP)")
        lambda_2 = Lambda("ping tool\n(private subnet)")
        nat_2 = EC2("NAT instance\n(t4g.nano)")

        keycloak >> Edge(label="discovery_url") >> gateway_2
        gateway_2 >> Edge(label="gateway_iam_role") >> lambda_2
        nat_2 >> Edge(label="0.0.0.0/0", style="dashed") >> lambda_2
