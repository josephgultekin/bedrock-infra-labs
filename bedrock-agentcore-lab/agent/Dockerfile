FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Port/entrypoint contract assumed from the bedrock-agentcore SDK's
# BedrockAgentCoreApp default - double-check against its docs (see app.py's
# NOTE) before relying on this.
EXPOSE 8080
CMD ["python", "app.py"]
