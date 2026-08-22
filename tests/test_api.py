import json
import subprocess
import tempfile
import threading
import unittest
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


HELPER = Path(__file__).parents[1] / "bin" / "sabnzbd-pipeline-api"


class ApiHandler(BaseHTTPRequestHandler):
    action_status = True
    last_query = {}
    queries = []
    queue = {"slots": [], "noofslots": 0, "noofslots_total": 0}
    processing_history = {"slots": [], "noofslots": 0}
    recent_history = {"slots": [], "noofslots": 0}

    def do_GET(self):
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
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

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


if __name__ == "__main__":
    unittest.main()
