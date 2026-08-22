from contextlib import redirect_stderr, redirect_stdout
import io
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from wofi import gemini


class GeminiPayloadTests(unittest.TestCase):
    def test_payload_is_stateless_and_short(self):
        payload = gemini.build_payload("What is Wayland?")

        self.assertEqual(payload["model"], gemini.MODEL)
        self.assertEqual(payload["input"], "What is Wayland?")
        self.assertIs(payload["store"], False)
        self.assertEqual(
            payload["generation_config"]["max_output_tokens"],
            gemini.ANSWER_TOKEN_LIMIT,
        )
        self.assertNotIn("previous_interaction_id", payload)

    def test_extracts_all_text_from_model_output_steps(self):
        response = {
            "status": "completed",
            "steps": [
                {"type": "user_input", "content": [{"type": "text", "text": "Q"}]},
                {
                    "type": "model_output",
                    "content": [
                        {"type": "text", "text": "First paragraph."},
                        {"type": "text", "text": "Second paragraph."},
                    ],
                },
            ],
        }

        self.assertEqual(
            gemini.extract_answer(response),
            "First paragraph.\n\nSecond paragraph.",
        )

    def test_empty_response_raises_safe_error(self):
        with self.assertRaisesRegex(gemini.GeminiError, "no text answer"):
            gemini.extract_answer({"status": "completed", "steps": []})

    def test_answer_is_capped_at_one_hundred_words(self):
        answer = " ".join(f"word{index}" for index in range(120))

        limited = gemini.limit_words(answer)

        self.assertEqual(len(limited.split()), 100)
        self.assertTrue(limited.endswith("…"))


class GeminiApiKeyFileTests(unittest.TestCase):
    def test_missing_or_empty_key_file_returns_none(self):
        with tempfile.TemporaryDirectory() as directory:
            key_path = Path(directory) / "gemini-api-key"
            with mock.patch.object(gemini, "API_KEY_FILE", key_path):
                self.assertIsNone(gemini.lookup_api_key())
                key_path.write_text("\n", encoding="utf-8")
                self.assertIsNone(gemini.lookup_api_key())

    @mock.patch("wofi.gemini.run_wofi")
    def test_prompt_stores_key_in_private_file(self, run_wofi):
        run_wofi.return_value = mock.Mock(returncode=0, stdout="new-key\n")
        with tempfile.TemporaryDirectory() as directory:
            key_path = Path(directory) / "nested" / "gemini-api-key"
            with mock.patch.object(gemini, "API_KEY_FILE", key_path):
                self.assertEqual(gemini.prompt_for_and_store_api_key(), "new-key")
                self.assertEqual(key_path.read_text(encoding="utf-8"), "new-key\n")
                self.assertEqual(os.stat(key_path).st_mode & 0o777, 0o600)


class GeminiAnswerViewTests(unittest.TestCase):
    @mock.patch("wofi.gemini.notify")
    @mock.patch("wofi.gemini.subprocess.run")
    @mock.patch("wofi.gemini.run_wofi")
    def test_enter_copies_exact_answer(self, run_wofi, run_process, notify):
        run_wofi.return_value = mock.Mock(returncode=0)
        run_process.return_value = mock.Mock(returncode=0)

        self.assertTrue(gemini.show_answer("line one\nline two"))

        run_process.assert_called_once_with(
            ("/usr/bin/wl-copy",),
            input="line one\nline two",
            text=True,
            capture_output=True,
            check=False,
        )
        notify.assert_called_once()

    @mock.patch("wofi.gemini.subprocess.run")
    @mock.patch("wofi.gemini.run_wofi")
    def test_escape_does_not_copy(self, run_wofi, run_process):
        run_wofi.return_value = mock.Mock(returncode=1)

        self.assertFalse(gemini.show_answer("answer"))
        run_process.assert_not_called()


class GeminiStdioTests(unittest.TestCase):
    @mock.patch("wofi.gemini.call_gemini", return_value="A concise answer.")
    @mock.patch("wofi.gemini.get_api_key", return_value="secret")
    def test_stdio_uses_stdin_and_prints_only_answer(self, get_key, call_gemini):
        output = io.StringIO()
        with mock.patch("sys.stdin", io.StringIO("current search text\n")):
            with redirect_stdout(output):
                status = gemini.stdio_main()

        self.assertEqual(status, 0)
        self.assertEqual(output.getvalue(), "A concise answer.\n")
        get_key.assert_called_once_with()
        call_gemini.assert_called_once_with("current search text", "secret")

    @mock.patch("wofi.gemini.get_api_key")
    def test_stdio_rejects_empty_search_without_key_lookup(self, get_key):
        errors = io.StringIO()
        with mock.patch("sys.stdin", io.StringIO("   \n")):
            with redirect_stderr(errors):
                status = gemini.stdio_main()

        self.assertEqual(status, 1)
        self.assertIn("Type a question", errors.getvalue())
        get_key.assert_not_called()


if __name__ == "__main__":
    unittest.main()
