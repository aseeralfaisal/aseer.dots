#!/usr/bin/env python3

"""Small Wofi front end for concise Gemini answers."""

from __future__ import annotations

import json
import os
import re
import socket
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


API_URL = "https://generativelanguage.googleapis.com/v1beta/interactions"
MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.7-flash")
API_KEY_FILE = Path(
    os.environ.get(
        "GEMINI_API_KEY_FILE",
        Path.home() / ".config" / "wofi" / "gemini-api-key",
    )
)
ANSWER_WORD_LIMIT = 100
ANSWER_TOKEN_LIMIT = 192
REQUEST_TIMEOUT_SECONDS = 30
ENTRY_SEPARATOR = "\x1e"


class GeminiError(RuntimeError):
    """An error that is safe to present to the user."""


def run_wofi(
    *,
    prompt: str,
    input_text: str = "",
    password: bool = False,
    answer_view: bool = False,
) -> subprocess.CompletedProcess[str]:
    command = [
        "/usr/bin/wofi",
        "--dmenu",
        "--cache-file=/dev/null",
        f"--prompt={prompt}",
        "--width=500",
    ]
    if password:
        command.extend(("--password=•", "--height=160", "--lines=1"))
    elif answer_view:
        command.extend(
            (
                "--hide-search",
                "--height=600",
                "--lines=1",
                "--define=line_wrap=word",
                f"--define=dmenu-separator={ENTRY_SEPARATOR}",
            )
        )
    else:
        command.extend(("--height=180", "--lines=2"))

    return subprocess.run(
        command,
        input=input_text,
        text=True,
        capture_output=True,
        check=False,
    )


def notify(message: str, *, title: str = "Gemini") -> None:
    subprocess.run(
        (
            "/usr/bin/notify-send",
            "--app-name=Wofi Gemini",
            "--expire-time=7000",
            title,
            message,
        ),
        check=False,
    )


def lookup_api_key() -> str | None:
    try:
        key = API_KEY_FILE.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        return None
    except OSError as error:
        raise GeminiError(f"Could not read {API_KEY_FILE}: {error.strerror}") from None
    return key or None


def prompt_for_and_store_api_key() -> str | None:
    result = run_wofi(prompt="Gemini API key", password=True)
    if result.returncode != 0:
        return None

    key = result.stdout.strip()
    if not key:
        return None

    try:
        API_KEY_FILE.parent.mkdir(parents=True, exist_ok=True)
        descriptor = os.open(
            API_KEY_FILE,
            os.O_WRONLY | os.O_CREAT | os.O_TRUNC,
            0o600,
        )
        with os.fdopen(descriptor, "w", encoding="utf-8") as key_file:
            key_file.write(key + "\n")
        API_KEY_FILE.chmod(0o600)
    except OSError as error:
        raise GeminiError(f"Could not save {API_KEY_FILE}: {error.strerror}") from None
    return key


def get_api_key() -> str | None:
    return lookup_api_key() or prompt_for_and_store_api_key()


def prompt_for_question() -> str | None:
    result = run_wofi(prompt="Ask Gemini")
    if result.returncode != 0:
        return None
    question = result.stdout.strip()
    return question or None


def build_payload(question: str) -> dict[str, Any]:
    return {
        "model": MODEL,
        "input": question,
        "system_instruction": (
            "Answer directly in plain text using at most 100 words. "
            "Use short paragraphs when helpful. Do not use Markdown tables."
        ),
        "store": False,
        "generation_config": {
            "max_output_tokens": ANSWER_TOKEN_LIMIT,
            "thinking_level": "low",
        },
    }


def extract_answer(response: dict[str, Any]) -> str:
    text_parts: list[str] = []
    for step in response.get("steps", []):
        if not isinstance(step, dict) or step.get("type") != "model_output":
            continue
        for content in step.get("content", []):
            if isinstance(content, dict) and content.get("type") == "text":
                text = content.get("text")
                if isinstance(text, str) and text.strip():
                    text_parts.append(text.strip())

    answer = "\n\n".join(text_parts).strip()
    if not answer:
        status = response.get("status")
        if status == "failed":
            raise GeminiError("Gemini could not complete that request.")
        raise GeminiError("Gemini returned no text answer.")
    return answer


def limit_words(text: str, limit: int = ANSWER_WORD_LIMIT) -> str:
    words = list(re.finditer(r"\S+", text))
    if len(words) <= limit:
        return text.strip()
    return text[: words[limit - 1].end()].rstrip(".,;:!?") + "…"


def call_gemini(question: str, api_key: str) -> str:
    request = urllib.request.Request(
        API_URL,
        data=json.dumps(build_payload(question)).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-goog-api-key": api_key,
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(
            request, timeout=REQUEST_TIMEOUT_SECONDS
        ) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        try:
            error_payload = json.loads(error.read().decode("utf-8"))
            error_items = error_payload if isinstance(error_payload, list) else [error_payload]
            api_message = " ".join(
                str(item.get("error", item).get("message", ""))
                for item in error_items
                if isinstance(item, dict)
                and isinstance(item.get("error", item), dict)
            )
        except (json.JSONDecodeError, UnicodeDecodeError):
            api_message = ""

        if error.code in (400, 401, 403) and "API key not valid" in api_message:
            raise GeminiError(
                f"The API key is invalid. Replace the contents of {API_KEY_FILE}."
            ) from None
        if error.code == 429:
            raise GeminiError("Gemini's rate limit was reached. Try again shortly.") from None
        if 500 <= error.code < 600:
            raise GeminiError("Gemini is temporarily unavailable.") from None
        raise GeminiError(f"Gemini rejected the request (HTTP {error.code}).") from None
    except (urllib.error.URLError, TimeoutError, socket.timeout):
        raise GeminiError("Could not reach Gemini within 30 seconds.") from None
    except (json.JSONDecodeError, UnicodeDecodeError):
        raise GeminiError("Gemini returned an unreadable response.") from None

    if not isinstance(payload, dict):
        raise GeminiError("Gemini returned an unreadable response.")
    return limit_words(extract_answer(payload))


def show_answer(answer: str) -> bool:
    # The record separator keeps embedded newlines inside one dmenu entry.
    result = run_wofi(
        prompt="Gemini answer",
        input_text=answer + ENTRY_SEPARATOR,
        answer_view=True,
    )
    if result.returncode != 0:
        return False

    copied = subprocess.run(
        ("/usr/bin/wl-copy",),
        input=answer,
        text=True,
        capture_output=True,
        check=False,
    )
    if copied.returncode != 0:
        raise GeminiError("The answer was shown but could not be copied.")
    notify("Answer copied to the clipboard.")
    return True


def main() -> int:
    try:
        api_key = get_api_key()
        if api_key is None:
            return 0

        question = prompt_for_question()
        if question is None:
            return 0

        answer = call_gemini(question, api_key)
        show_answer(answer)
        return 0
    except GeminiError as error:
        notify(str(error), title="Gemini error")
        return 1
    except Exception:
        notify("An unexpected error occurred.", title="Gemini error")
        return 1


def stdio_main() -> int:
    """Read one question from stdin and return only the answer on stdout."""
    try:
        question = sys.stdin.read().strip()
        if not question:
            raise GeminiError("Type a question before asking Gemini.")

        api_key = get_api_key()
        if api_key is None:
            raise GeminiError("Gemini API key setup was cancelled.")

        print(call_gemini(question, api_key), flush=True)
        return 0
    except GeminiError as error:
        print(str(error), file=sys.stderr, flush=True)
        return 1
    except Exception:
        print("An unexpected Gemini error occurred.", file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    if "--stdio" in sys.argv[1:]:
        raise SystemExit(stdio_main())
    raise SystemExit(main())
