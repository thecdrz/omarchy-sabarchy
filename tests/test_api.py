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
    status = True
    last_query = {}

    def do_GET(self):
        ApiHandler.last_query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        body = json.dumps({"status": ApiHandler.status}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


class HelperTests(unittest.TestCase):
    def setUp(self):
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

    def test_retry_sends_documented_parameters(self):
        ApiHandler.status = True
        result = self.run_retry()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(ApiHandler.last_query["mode"], ["retry"])
        self.assertEqual(ApiHandler.last_query["value"], ["SABnzbd_nzo_test"])
        self.assertEqual(ApiHandler.last_query["apikey"], ["test-key"])

    def test_retry_failure_returns_nonzero(self):
        ApiHandler.status = False
        result = self.run_retry()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)["ok"])

    def test_clear_completed_archives_only_completed_history(self):
        ApiHandler.status = True
        result = self.run_clear_completed()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(ApiHandler.last_query["mode"], ["history"])
        self.assertEqual(ApiHandler.last_query["name"], ["delete"])
        self.assertEqual(ApiHandler.last_query["value"], ["completed"])
        self.assertNotIn("del_files", ApiHandler.last_query)
        self.assertNotIn("archive", ApiHandler.last_query)

    def test_clear_completed_rejection_returns_nonzero(self):
        ApiHandler.status = False
        result = self.run_clear_completed()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)["ok"])

    def test_pause_single_job_uses_queue_operation(self):
        ApiHandler.status = True
        result = self.run_job_action("job_pause")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(ApiHandler.last_query["mode"], ["queue"])
        self.assertEqual(ApiHandler.last_query["name"], ["pause"])
        self.assertEqual(ApiHandler.last_query["value"], ["SABnzbd_nzo_test"])

    def test_resume_single_job_uses_queue_operation(self):
        ApiHandler.status = True
        result = self.run_job_action("job_resume")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(ApiHandler.last_query["mode"], ["queue"])
        self.assertEqual(ApiHandler.last_query["name"], ["resume"])

    def test_single_job_action_rejection_returns_nonzero(self):
        ApiHandler.status = False
        result = self.run_job_action("job_pause")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(json.loads(result.stdout)["ok"])


if __name__ == "__main__":
    unittest.main()
