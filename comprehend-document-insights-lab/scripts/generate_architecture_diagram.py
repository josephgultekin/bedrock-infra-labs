"""Renders the lab's two Comprehend pipelines (README architecture section) as
a PNG using official AWS Architecture Icons via the `diagrams` package.

Usage:
    pip install diagrams  (and `brew install graphviz` / apt equivalent)
    python3 generate_architecture_diagram.py
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.ml import Comprehend
from diagrams.aws.compute import Lambda
from diagrams.aws.storage import S3
from diagrams.aws.security import IAM

graph_attr = {
    "fontsize": "22",
    "bgcolor": "white",
    "pad": "0.4",
    "splines": "spline",
}

with Diagram(
    "Comprehend Document Insights Lab",
    filename="architecture",
    outformat="png",
    graph_attr=graph_attr,
    direction="LR",
    show=False,
):
    with Cluster("Real-time path (S3-triggered)"):
        incoming = S3("incoming/")
        analyzer = Lambda("analyzer")
        comprehend_rt = Comprehend("Detect*\n(Language, Sentiment,\nKeyPhrases, Entities,\nPiiEntities)")
        insights = S3("insights/\n<file>.json")

        incoming >> Edge(label="S3 event") >> analyzer
        analyzer >> Edge(label="caller IAM perms") >> comprehend_rt
        analyzer >> insights

    with Cluster("Batch path (async redaction)"):
        batch_input = S3("batch-input/")
        redaction_role = IAM("DataAccessRoleArn\n(Comprehend service role)")
        comprehend_batch = Comprehend("StartPiiEntitiesDetectionJob\nMode=ONLY_REDACTION")
        batch_output = S3("batch-output/\nredacted copies")

        batch_input >> Edge(label="run_pii_redaction_job.py") >> comprehend_batch
        redaction_role >> Edge(label="assumed by Comprehend", style="dashed") >> comprehend_batch
        comprehend_batch >> batch_output
