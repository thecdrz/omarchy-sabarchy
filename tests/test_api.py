import json
import subprocess
import tempfile
import threading
import unittest
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


HELPER = Path(__file__).parents[1] / "bin" / "sabnzbd-pipeline-api"
MAX_API_RESPONSE_BYTES = 1024 * 1024


class ApiHandler(BaseHTTPRequestHandler):
    action_status = True
    last_query = {}
    queries = []
    queue = {"slots": [], "noofslots": 0, "noofslots_total": 0}
    processing_history = {"slots": [], "noofslots": 0}
    recent_history = {"slots": [], "noofslots": 0}
    raw_body = None
    send_content_length = True
    content_length_override = None
    redirect_location = None

    def do_GET(self):
        if ApiHandler.redirect_location is not None:
            self.send_response(302)
            self.send_header("Location", ApiHandler.redirect_location)
            self.end_headers()
            return
        parsed = urllib.parse.urlparse(self.path)
        ApiHandler.last_query = urllib.parse.parse_qs(parsed.query)
        ApiHandler.queries.append((parsed.path, ApiHandler.last_query))
        mode = ApiHandler.last_query.get("mode", [""])[0]
        statuses = ApiHandler.last_query.get("status", [""])[0]
        if mode == "queue" and "name" not in ApiHandler.last_query:
            payload = {"queue": ApiHandler.queue}
        elif mode == "history" and statuses == "Completed,Failed":
            payload = {"history": ApiHandler.recent_history}
        elif mode == "history" and statuses:
            payload = {"history": ApiHandler.processing_history}
        else:
            payload = {"status": ApiHandler.action_status}
        body = ApiHandler.raw_body if ApiHandler.raw_body is not None else json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        if ApiHandler.send_content_length:
            content_length = ApiHandler.content_length_override
            self.send_header("Content-Length", str(len(body) if content_length is None else content_length))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, *_args):
        pass


class HelperTests(unittest.TestCase):
    def setUp(self):
        ApiHandler.action_status = True
        ApiHandler.last_query = {}
        ApiHandler.queries = []
        ApiHandler.queue = {"slots": [], "noofslots": 0, "noofslots_total": 0}
        ApiHandler.processing_history = {"slots": [], "noofslots": 0}
        ApiHandler.recent_history = {"slots": [], "noofslots": 0}
        ApiHandler.raw_body = None
        ApiHandler.send_content_length = True
        ApiHandler.content_length_override = None
        ApiHandler.redirect_location = None
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), ApiHandler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.tempdir = tempfile.TemporaryDirectory()
        self.config = Path(self.tempdir.name) / "sabnzbd.ini"
        self.config.write_text(
            "__version__ = 19\n[misc]\n"
            f"port = {self.server.server_port}\napi_key = test-key\nenable_https = 0\n",
            encoding="utf-8",
        )

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.tempdir.cleanup()

    def run_retry(self):
        return subprocess.run(
            [str(HELPER), "retry", "--id", "SABnzbd_nzo_test", "--config", str(self.config)],
            check=False,
            capture_output=True,
            text=True,
        )

    def run_clear_completed(self):
        return subprocess.run(
            [str(HELPER), "clear_completed", "--config", str(self.config)],
            check=False,
            capture_output=True,
            text=True,
        )

    def run_job_action(self, action):
        return subprocess.run(
            [str(HELPER), action, "--id", "SABnzbd_nzo_test", "--config", str(self.config)],
            check=False,
            capture_output=True,
            text=True,
        )

    def run_snapshot(self, *args):
        return subprocess.run(
            [str(HELPER), "snapshot", "--config", str(self.config), *args],
            check=False,
            capture_output=True,
            text=True,
        )

    def test_retry_sends_documented_parameters(self):
        result = self.run_retry()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(ApiHandler.last_query["mode"], ["retry"])
        self.assertEqual(ApiHandler.last_query["value"], ["SABnzbd_nzo_test"])
        self.assertEqual(ApiHandler.last_query["apikey"], ["test-key"])

    def test_retry_failure_returns_nonzero(self):
        ApiHandler.action_status = False
        result = self.run_retry()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)["ok"])

    def test_action_requires_literal_boolean_success(self):
        ApiHandler.action_status = "true"

        result = self.run_retry()

        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)["ok"])

    def test_clear_completed_archives_only_completed_history(self):
        result = self.run_clear_completed()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(ApiHandler.last_query["mode"], ["history"])
        self.assertEqual(ApiHandler.last_query["name"], ["delete"])
        self.assertEqual(ApiHandler.last_query["value"], ["completed"])
        self.assertNotIn("del_files", ApiHandler.last_query)
        self.assertNotIn("archive", ApiHandler.last_query)

    def test_clear_completed_rejection_returns_nonzero(self):
        ApiHandler.action_status = False
        result = self.run_clear_completed()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)["ok"])

    def test_pause_single_job_uses_queue_operation(self):
        result = self.run_job_action("job_pause")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(ApiHandler.last_query["mode"], ["queue"])
        self.assertEqual(ApiHandler.last_query["name"], ["pause"])
        self.assertEqual(ApiHandler.last_query["value"], ["SABnzbd_nzo_test"])

    def test_resume_single_job_uses_queue_operation(self):
        result = self.run_job_action("job_resume")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(ApiHandler.last_query["mode"], ["queue"])
        self.assertEqual(ApiHandler.last_query["name"], ["resume"])

    def test_single_job_action_rejection_returns_nonzero(self):
        ApiHandler.action_status = False
        result = self.run_job_action("job_pause")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)["ok"])

    def test_snapshot_separates_processing_from_recent_history(self):
        ApiHandler.queue = {
            "status": "Downloading",
            "paused": False,
            "speed": "1.5 M",
            "noofslots": 1,
            "noofslots_total": 4,
            "slots": [{"nzo_id": "queue-1", "filename": "Queued job", "status": "Downloading"}],
        }
        ApiHandler.processing_history = {
            "noofslots": 2,
            "slots": [
                {"nzo_id": "verify-1", "name": "Verify job", "status": "Verifying"},
                {"nzo_id": "unpack-1", "name": "Unpack job", "status": "Extracting"},
            ],
        }
        ApiHandler.recent_history = {
            "noofslots": 12,
            "slots": [
                {"nzo_id": "done-1", "name": "Done job", "status": "Completed"},
                {"nzo_id": "failed-1", "name": "Failed job", "status": "Failed"},
            ],
        }

        result = self.run_snapshot("--queue-limit", "20", "--history-limit", "20")

        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["counts"]["active_total"], 6)
        self.assertEqual(payload["counts"]["history_total"], 12)
        self.assertEqual([item["id"] for item in payload["stages"]["verify"]], ["verify-1"])
        self.assertEqual([item["id"] for item in payload["stages"]["unpack"]], ["unpack-1"])
        self.assertEqual([item["id"] for item in payload["stages"]["recent"]], ["done-1", "failed-1"])
        history_queries = [query for _path, query in ApiHandler.queries if query.get("mode") == ["history"]]
        self.assertEqual(len(history_queries), 2)
        self.assertEqual(history_queries[1]["status"], ["Completed,Failed"])

    def test_snapshot_honors_url_base(self):
        self.config.write_text(
            "__version__ = 19\n[misc]\n"
            f"port = {self.server.server_port}\napi_key = test-key\nenable_https = 0\nurl_base = /sabnzbd/\n",
            encoding="utf-8",
        )

        result = self.run_snapshot()

        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["web_url"], f"http://127.0.0.1:{self.server.server_port}/sabnzbd")
        self.assertTrue(ApiHandler.queries)
        self.assertTrue(all(path == "/sabnzbd/api" for path, _query in ApiHandler.queries))

    def test_snapshot_preserves_markup_like_metadata_for_plain_text_rendering(self):
        markup = '<img src="probe.png">'
        ApiHandler.queue = {
            "status": "Downloading",
            "slots": [
                {
                    "nzo_id": "queue-markup",
                    "name": markup,
                    "status": "Downloading",
                    "cat": markup,
                    "labels": [markup],
                }
            ],
        }
        ApiHandler.recent_history = {
            "slots": [
                {
                    "nzo_id": "history-markup",
                    "name": markup,
                    "status": "Failed",
                    "cat": markup,
                    "fail_message": markup,
                    "labels": [markup],
                }
            ]
        }

        result = self.run_snapshot()

        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        active = payload["stages"]["download"][0]
        failed = payload["stages"]["recent"][0]
        for item in (active, failed):
            self.assertEqual(item["name"], markup)
            self.assertEqual(item["category"], markup)
            self.assertEqual(item["labels"], [markup])
        self.assertEqual(failed["failure"], markup)

    def test_snapshot_rejects_oversized_api_body_without_content_length(self):
        ApiHandler.raw_body = b" " * (MAX_API_RESPONSE_BYTES + 1)
        ApiHandler.send_content_length = False

        result = self.run_snapshot()

        self.assertEqual(result.returncode, 5)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["state"], "api-error")
        self.assertIn("1 MiB", payload["message"])
        self.assertLess(len(result.stdout), 1024)

    def test_snapshot_rejects_announced_oversized_api_body(self):
        ApiHandler.raw_body = b"{}"
        ApiHandler.content_length_override = MAX_API_RESPONSE_BYTES + 1

        result = self.run_snapshot()

        self.assertEqual(result.returncode, 5)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["state"], "api-error")
        self.assertIn("1 MiB", payload["message"])

    def test_snapshot_rejects_incomplete_announced_api_body(self):
        ApiHandler.raw_body = b"{}"
        ApiHandler.content_length_override = 100

        result = self.run_snapshot()

        self.assertEqual(result.returncode, 5)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["state"], "api-error")
        self.assertIn("incomplete", payload["message"])

    def test_snapshot_rejects_non_object_and_non_finite_json(self):
        for raw_body in (b"[]", b'{"queue":{"kbpersec":NaN}}'):
            with self.subTest(raw_body=raw_body):
                ApiHandler.raw_body = raw_body
                result = self.run_snapshot()
                self.assertEqual(result.returncode, 5)
                self.assertEqual(json.loads(result.stdout)["state"], "api-error")

    def test_api_redirect_is_not_followed(self):
        ApiHandler.redirect_location = "http://127.0.0.1:1/not-followed"

        result = self.run_snapshot()

        self.assertEqual(result.returncode, 5)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["state"], "api-error")
        self.assertIn("HTTP 302", payload["message"])

    def test_snapshot_enforces_server_array_limits(self):
        ApiHandler.queue = {
            "slots": [
                {"nzo_id": f"queue-{index}", "name": f"Queue {index}", "status": "Downloading"}
                for index in range(25)
            ]
        }
        ApiHandler.processing_history = {
            "slots": [
                {"nzo_id": f"processing-{index}", "name": f"Processing {index}", "status": "Verifying"}
                for index in range(1005)
            ]
        }
        ApiHandler.recent_history = {
            "slots": [
                {"nzo_id": f"recent-{index}", "name": f"Recent {index}", "status": "Completed"}
                for index in range(25)
            ]
        }

        result = self.run_snapshot("--queue-limit", "20", "--history-limit", "20")

        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        self.assertEqual(len(payload["stages"]["download"]), 20)
        self.assertEqual(len(payload["stages"]["verify"]), 1000)
        self.assertEqual(len(payload["stages"]["recent"]), 20)

    def test_snapshot_bounds_server_strings_and_labels(self):
        oversized = "x" * 4096
        excessive_labels = [oversized] * 32
        ApiHandler.queue = {
            "speed": oversized,
            "slots": [
                {
                    "nzo_id": oversized,
                    "name": oversized,
                    "status": "Downloading",
                    "cat": oversized,
                    "labels": excessive_labels,
                }
            ],
        }
        ApiHandler.recent_history = {
            "slots": [
                {
                    "nzo_id": "failed",
                    "name": "Failed",
                    "status": "Failed",
                    "fail_message": oversized,
                }
            ]
        }

        result = self.run_snapshot()

        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        active = payload["stages"]["download"][0]
        failed = payload["stages"]["recent"][0]
        self.assertEqual(len(active["id"]), 256)
        self.assertEqual(len(active["name"]), 512)
        self.assertEqual(len(active["category"]), 128)
        self.assertEqual(len(active["labels"]), 16)
        self.assertTrue(all(len(label) == 128 for label in active["labels"]))
        self.assertEqual(len(failed["failure"]), 2048)
        self.assertLessEqual(len(payload["queue"]["speed"]), 130)

    def test_snapshot_refuses_output_that_would_overfill_shell_collector(self):
        name = "n" * 512
        category = "c" * 128
        ApiHandler.queue = {
            "slots": [
                {"nzo_id": f"queue-{index}", "name": name, "cat": category, "status": "Downloading"}
                for index in range(1000)
            ]
        }
        ApiHandler.processing_history = {
            "slots": [
                {"nzo_id": f"processing-{index}", "name": name, "cat": category, "status": "Verifying"}
                for index in range(1000)
            ]
        }

        result = self.run_snapshot("--queue-limit", "1000")

        self.assertEqual(result.returncode, 5)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["state"], "api-error")
        self.assertIn("output limit", payload["message"])
        self.assertLess(len(result.stdout), 1024)

    def test_oversized_config_is_rejected_with_bounded_output(self):
        self.config.write_bytes(b"x" * (1024 * 1024 + 1))

        result = self.run_snapshot()

        self.assertEqual(result.returncode, 4)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["state"], "configuration-error")
        self.assertLess(len(result.stdout), 1024)

    def test_global_pause_and_resume_use_documented_modes(self):
        for action in ("pause", "resume"):
            with self.subTest(action=action):
                result = subprocess.run(
                    [str(HELPER), action, "--config", str(self.config)],
                    check=False,
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode, 0)
                self.assertEqual(ApiHandler.last_query["mode"], [action])

    def test_missing_job_id_returns_configuration_error(self):
        result = subprocess.run(
            [str(HELPER), "retry", "--config", str(self.config)],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 4)
        self.assertEqual(json.loads(result.stdout)["state"], "configuration-error")

    def test_disk_threshold_controls_low_warning(self):
        ApiHandler.queue = {"diskspace1": "12.6", "diskspace2": "12.6"}
        cases = [
            ([], True),
            (["--disk-threshold", "20"], True),
            (["--disk-threshold", "10"], False),
            (["--disk-threshold", "0"], False),
            (["--disk-threshold", "500"], True),
        ]
        for extra_args, expected_low in cases:
            with self.subTest(extra_args=extra_args):
                result = self.run_snapshot(*extra_args)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(json.loads(result.stdout)["disk"]["low"], expected_low)

    def test_disk_threshold_is_clamped_to_safe_bounds(self):
        for raw_threshold in ("nan", "-5", "999999999"):
            with self.subTest(raw_threshold=raw_threshold):
                result = self.run_snapshot("--disk-threshold", raw_threshold)
                self.assertEqual(result.returncode, 0)
                payload = json.loads(result.stdout)
                self.assertEqual(payload["disk"]["free_gb"], -1)
                self.assertFalse(payload["disk"]["low"])

    def test_history_storage_paths_are_sanitized(self):
        oversized = "/" + "s" * 4096
        ApiHandler.recent_history = {
            "slots": [
                {"nzo_id": "stored", "name": "Stored", "status": "Completed", "storage": "/data/complete/Stored"},
                {"nzo_id": "remote", "name": "Remote", "status": "Completed", "storage": "file:///etc/passwd"},
                {"nzo_id": "control", "name": "Control", "status": "Completed", "storage": "/data/complete/bad\npath"},
                {"nzo_id": "oversized", "name": "Oversized", "status": "Completed", "storage": oversized},
                {"nzo_id": "missing", "name": "Missing", "status": "Completed"},
            ]
        }
        ApiHandler.queue = {"slots": [{"nzo_id": "queue-1", "name": "Queue", "status": "Downloading"}]}

        result = self.run_snapshot()

        self.assertEqual(result.returncode, 0)
        recent = {item["id"]: item for item in json.loads(result.stdout)["stages"]["recent"]}
        self.assertEqual(recent["stored"]["storage"], "/data/complete/Stored")
        self.assertEqual(recent["remote"]["storage"], "")
        self.assertEqual(recent["control"]["storage"], "")
        self.assertEqual(len(recent["oversized"]["storage"]), 512)
        self.assertEqual(recent["missing"]["storage"], "")
        self.assertEqual(json.loads(result.stdout)["stages"]["download"][0]["storage"], "")

    def test_demo_snapshot_respects_disk_threshold(self):
        for extra_args, expected_low in [(["--disk-threshold", "20"], True), (["--disk-threshold", "5"], False)]:
            with self.subTest(extra_args=extra_args):
                result = self.run_snapshot("--demo", "failed", *extra_args)
                self.assertEqual(result.returncode, 0)
                payload = json.loads(result.stdout)
                self.assertEqual(payload["disk"]["low"], expected_low)

    def test_demo_completed_history_carries_storage_paths(self):
        result = self.run_snapshot("--demo", "downloading")

        self.assertEqual(result.returncode, 0)
        recent = json.loads(result.stdout)["stages"]["recent"]
        self.assertTrue(recent)
        self.assertTrue(all(item["storage"].startswith("/") for item in recent if not item["failed"]))


if __name__ == "__main__":
    unittest.main()
