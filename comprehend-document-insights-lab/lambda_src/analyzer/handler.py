import json
import os
import urllib.parse

import boto3

comprehend = boto3.client("comprehend")
s3 = boto3.client("s3")

INSIGHTS_PREFIX = os.environ["INSIGHTS_PREFIX"]
DEFAULT_LANGUAGE_CODE = os.environ["DEFAULT_LANGUAGE_CODE"]

# Comprehend's real-time Detect* calls cap input size per API (a few KB for
# sentiment/entities/key-phrases). Demo documents here are short paragraphs,
# but real, larger documents should go through the async batch-job path
# (see scripts/run_pii_redaction_job.py) instead of being chunked here.
MAX_TEXT_BYTES = 4500


def _truncate(text: str) -> str:
    return text.encode("utf-8")[:MAX_TEXT_BYTES].decode("utf-8", errors="ignore")


def _detect_language_code(text: str) -> str:
    result = comprehend.detect_dominant_language(Text=text)
    languages = result.get("Languages", [])
    if not languages:
        return DEFAULT_LANGUAGE_CODE
    top = max(languages, key=lambda lang: lang["Score"])
    return top["LanguageCode"]


def _call_with_language_fallback(fn, text: str, language_code: str):
    try:
        return fn(Text=text, LanguageCode=language_code), language_code
    except comprehend.exceptions.UnsupportedLanguageException:
        return fn(Text=text, LanguageCode=DEFAULT_LANGUAGE_CODE), DEFAULT_LANGUAGE_CODE


def _analyze(text: str) -> dict:
    detected_language = _detect_language_code(text)

    sentiment, sentiment_lang = _call_with_language_fallback(
        comprehend.detect_sentiment, text, detected_language
    )
    key_phrases, _ = _call_with_language_fallback(
        comprehend.detect_key_phrases, text, sentiment_lang
    )
    entities, _ = _call_with_language_fallback(
        comprehend.detect_entities, text, sentiment_lang
    )
    pii, _ = _call_with_language_fallback(
        comprehend.detect_pii_entities, text, sentiment_lang
    )

    pii_entities = pii.get("Entities", [])

    return {
        "detected_language_code": detected_language,
        "language_code_used": sentiment_lang,
        "sentiment": sentiment["Sentiment"],
        "sentiment_score": sentiment["SentimentScore"],
        "key_phrases": [kp["Text"] for kp in key_phrases.get("KeyPhraseList", [])],
        "entities": [
            {"type": e["Type"], "text": e["Text"], "score": e["Score"]}
            for e in entities.get("Entities", [])
        ],
        # PII findings record type, confidence, and offsets only - never the
        # raw matched text - so the insights file itself never becomes a new
        # place sensitive values leak into.
        "pii_detected": len(pii_entities) > 0,
        "pii_entity_types": [
            {
                "type": e["Type"],
                "score": e["Score"],
                "begin_offset": e["BeginOffset"],
                "end_offset": e["EndOffset"],
            }
            for e in pii_entities
        ],
    }


def handler(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        obj = s3.get_object(Bucket=bucket, Key=key)
        text = _truncate(obj["Body"].read().decode("utf-8", errors="ignore"))

        insights = _analyze(text)
        insights["source_key"] = key

        filename = key.rsplit("/", 1)[-1]
        insights_key = f"{INSIGHTS_PREFIX}{filename}.json"

        s3.put_object(
            Bucket=bucket,
            Key=insights_key,
            Body=json.dumps(insights, default=str).encode("utf-8"),
            ContentType="application/json",
        )

    return {"statusCode": 200}
