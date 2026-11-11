"""Tests of the roadmap tooling (make test-tools): the file, the sync and the fetch."""

import datetime as dt
import io
import json
import sys
import tempfile
import unittest
import urllib.error
import urllib.parse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fetch_roadmap
import sync_roadmap
from roadmap_lib import ROADMAP_FILE, GitHub, RoadmapError, find_marker, load, strip_marker

SMALL = """
[label]
name = "roadmap"
color = "1D3F8F"
description = "On the roadmap"

[[milestones]]
id = "first"
title = "First"
title_ur = "پہلا"
due = "2027-02-28"
description = "The first step."
description_ur = "پہلا قدم"

[[milestones.issues]]
id = "one"
title = "Issue one"
title_ur = "پہلا کام"
body = "Do one thing."

[[milestones.issues]]
id = "two"
title = "Issue two"
title_ur = "دوسرا کام"
body = "Do another."
"""


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class FakeGitHub:
    """Labels, milestones and issues in memory, behind the REST paths the tools use."""

    def __init__(self):
        self.labels: dict[str, dict] = {}
        self.milestones: list[dict] = []
        self.issues: list[dict] = []
        self.writes: list[tuple[str, str]] = []

    def __call__(self, request):
        url = urllib.parse.urlparse(request.full_url)
        path = url.path.removeprefix("/repos/owner/repo")
        query = dict(urllib.parse.parse_qsl(url.query))
        body = json.loads(request.data) if request.data else None
        method = request.get_method()
        if method != "GET":
            self.writes.append((method, path))
        result = self.route(method, path, query, body)
        if result is None and method == "GET":
            raise urllib.error.HTTPError(request.full_url, 404, "Not Found", {}, None)
        return FakeResponse(json.dumps(result).encode())

    def route(self, method, path, query, body):
        page = int(query.get("page", "1"))
        if path.startswith("/labels/"):
            name = path.split("/")[-1]
            if method == "PATCH":
                self.labels[name].update(body)
            return self.labels.get(name)
        if path == "/labels":
            self.labels[body["name"]] = dict(body)
            return body
        if path == "/milestones":
            if method == "POST":
                milestone = {
                    **body,
                    "number": len(self.milestones) + 1,
                    "state": "open",
                    "html_url": f"https://github.com/m/{len(self.milestones) + 1}",
                }
                self.milestones.append(milestone)
                return milestone
            return self.milestones if page == 1 else []
        if path.startswith("/milestones/"):
            number = int(path.split("/")[-1])
            milestone = next(m for m in self.milestones if m["number"] == number)
            milestone.update(body)
            return milestone
        if path == "/issues":
            if method == "POST":
                number = len(self.issues) + 1
                milestone = next(m for m in self.milestones if m["number"] == body["milestone"])
                issue = {
                    **body,
                    "number": number,
                    "state": "open",
                    "milestone": milestone,
                    "html_url": f"https://github.com/i/{number}",
                }
                self.issues.append(issue)
                return issue
            if page != 1:
                return []
            if "labels" not in query:
                return self.issues
            # GitHub's label filter. Issues created here keep their labels as names; GitHub's
            # (and the tests' own) carry objects with a name.
            return [i for i in self.issues if query["labels"] in label_names(i)]
        raise AssertionError(f"unexpected {method} {path}")


def label_names(issue):
    return [x if isinstance(x, str) else x["name"] for x in issue.get("labels", [])]


def small_roadmap(text=SMALL):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "roadmap.toml"
        path.write_text(text, encoding="utf-8")
        return load(path)


class RoadmapFileTest(unittest.TestCase):
    def test_the_repository_roadmap_is_valid(self):
        roadmap = load(ROADMAP_FILE)
        self.assertGreaterEqual(len(roadmap.milestones), 3)
        self.assertEqual(len(roadmap.issue_ids()), len(set(roadmap.issue_ids())))

    def test_urdu_must_be_in_urdu_script(self):
        with self.assertRaisesRegex(RoadmapError, "Urdu script"):
            small_roadmap(SMALL.replace('title_ur = "پہلا کام"', 'title_ur = "Pehla kaam"'))

    def test_ids_are_unique_and_dates_are_real_dates(self):
        with self.assertRaisesRegex(RoadmapError, "unique"):
            small_roadmap(SMALL.replace('id = "two"', 'id = "one"'))
        with self.assertRaisesRegex(RoadmapError, "YYYY-MM-DD"):
            small_roadmap(SMALL.replace("2027-02-28", "February"))

    def test_markers(self):
        self.assertEqual(find_marker("Text\n\n<!-- roadmap: one -->"), "one")
        self.assertIsNone(find_marker(None))
        self.assertEqual(strip_marker("Text\n\n<!-- roadmap: one -->"), "Text")


class SyncTest(unittest.TestCase):
    def setUp(self):
        self.fake = FakeGitHub()
        self.github = GitHub("owner/repo", "token", opener=self.fake)
        self.roadmap = small_roadmap()

    def run_sync(self, **kwargs):
        return sync_roadmap.sync(self.roadmap, self.github, log=lambda _: None, **kwargs)

    def test_creates_the_label_milestones_and_issues(self):
        counts = self.run_sync()
        self.assertEqual(counts, {"created": 4, "updated": 0, "unchanged": 0})
        self.assertEqual(self.fake.milestones[0]["due_on"], "2027-02-28T12:00:00Z")
        self.assertIn("<!-- roadmap: first -->", self.fake.milestones[0]["description"])
        self.assertEqual([i["labels"] for i in self.fake.issues], [["roadmap"], ["roadmap"]])
        self.assertTrue(self.fake.issues[1]["body"].endswith("<!-- roadmap: two -->"))

    def test_a_second_run_changes_nothing(self):
        self.run_sync()
        self.fake.writes.clear()
        counts = self.run_sync()
        self.assertEqual(counts["created"] + counts["updated"], 0)
        self.assertEqual(self.fake.writes, [])

    def test_a_changed_due_date_updates_the_milestone_but_never_an_issue(self):
        self.run_sync()
        self.fake.issues[0]["title"] = "Renamed on GitHub"
        self.roadmap = small_roadmap(SMALL.replace("2027-02-28", "2027-03-31"))
        self.fake.writes.clear()
        self.run_sync()
        self.assertEqual(self.fake.writes, [("PATCH", "/milestones/1")])
        self.assertEqual(self.fake.issues[0]["title"], "Renamed on GitHub")

    def test_a_dry_run_writes_nothing(self):
        counts = self.run_sync(dry_run=True)
        self.assertEqual(counts["created"], 4)
        self.assertEqual(self.fake.writes, [])

    def test_an_issue_whose_label_was_removed_is_not_created_again(self):
        self.run_sync()
        self.fake.issues[0]["labels"] = []
        self.fake.writes.clear()
        counts = self.run_sync()
        self.assertEqual(counts["created"], 0)
        self.assertEqual(self.fake.writes, [])
        self.assertEqual(len(self.fake.issues), 2)

    def test_pull_requests_with_the_label_are_not_mistaken_for_issues(self):
        self.fake.labels["roadmap"] = {
            "name": "roadmap",
            "color": "1d3f8f",
            "description": "On the roadmap",
        }
        self.fake.issues.append({"number": 9, "pull_request": {}, "body": "<!-- roadmap: one -->"})
        self.run_sync()
        self.assertEqual(sum(1 for i in self.fake.issues if "pull_request" not in i), 2)


class FetchTest(unittest.TestCase):
    def setUp(self):
        self.fake = FakeGitHub()
        self.github = GitHub("owner/repo", None, opener=self.fake)
        self.roadmap = small_roadmap()

    def test_from_file_lists_the_plan_with_every_issue_open(self):
        data = fetch_roadmap.from_file(self.roadmap, "owner/repo")
        self.assertEqual(data["source"], "file")
        self.assertEqual([i["state"] for i in data["milestones"][0]["issues"]], ["open", "open"])
        self.assertEqual(data["milestones"][0]["issues"][1]["titleUr"], "دوسرا کام")
        self.assertEqual(data["unscheduled"], [])

    def test_from_github_shows_live_state_and_keeps_urdu_only_for_unchanged_titles(self):
        sync_roadmap.sync(
            self.roadmap, GitHub("owner/repo", "t", opener=self.fake), log=lambda _: None
        )
        self.fake.issues[0]["state"] = "closed"
        self.fake.issues[1]["title"] = "Issue two, renamed"
        stranger = {
            "number": 3,
            "title": "Added on GitHub",
            "body": "",
            "labels": [{"name": "roadmap"}],
            "state": "open",
            "milestone": self.fake.milestones[0],
            "html_url": "https://github.com/i/3",
        }
        self.fake.issues.append(stranger)
        self.fake.milestones.append(
            {
                "number": 2,
                "title": "Not on the roadmap",
                "description": "",
                "state": "open",
                "due_on": None,
            }
        )
        data = fetch_roadmap.from_github(self.roadmap, self.github, dt.date(2026, 11, 11))
        self.assertEqual(data["source"], "github")
        self.assertEqual(data["updated"], "2026-11-11")
        self.assertEqual(len(data["milestones"]), 1)
        milestone = data["milestones"][0]
        self.assertEqual(milestone["due"], "2027-02-28")
        self.assertEqual(milestone["description"], "The first step.")
        self.assertEqual(milestone["titleUr"], "پہلا")
        self.assertEqual(milestone["descriptionUr"], "پہلا قدم")
        issues = milestone["issues"]
        self.assertEqual([i["number"] for i in issues], [1, 2, 3])
        self.assertEqual(issues[0]["state"], "closed")
        self.assertEqual(issues[0]["titleUr"], "پہلا کام")
        self.assertIsNone(issues[1]["titleUr"])
        self.assertIsNone(issues[2]["id"])

    def test_a_changed_description_drops_its_urdu_until_the_file_catches_up(self):
        sync_roadmap.sync(
            self.roadmap, GitHub("owner/repo", "t", opener=self.fake), log=lambda _: None
        )
        self.fake.milestones[0]["description"] = "A newer plan.\n\n<!-- roadmap: first -->"
        data = fetch_roadmap.from_github(self.roadmap, self.github, dt.date(2026, 11, 11))
        milestone = data["milestones"][0]
        self.assertEqual(milestone["description"], "A newer plan.")
        self.assertIsNone(milestone["descriptionUr"])
        self.assertEqual(milestone["titleUr"], "پہلا")

    def test_a_labelled_issue_in_no_milestone_is_listed_as_unscheduled(self):
        sync_roadmap.sync(
            self.roadmap, GitHub("owner/repo", "t", opener=self.fake), log=lambda _: None
        )
        self.fake.issues[1]["milestone"] = None
        self.fake.issues.append(
            {
                "number": 3,
                "title": "Suggested on GitHub",
                "body": "",
                "labels": [{"name": "roadmap"}],
                "state": "open",
                "milestone": None,
                "html_url": "https://github.com/i/3",
            }
        )
        data = fetch_roadmap.from_github(self.roadmap, self.github, dt.date(2026, 11, 11))
        self.assertEqual([i["number"] for i in data["milestones"][0]["issues"]], [1])
        unscheduled = data["unscheduled"]
        self.assertEqual([i["number"] for i in unscheduled], [2, 3])
        self.assertEqual(unscheduled[0]["id"], "two")
        self.assertEqual(unscheduled[0]["titleUr"], "دوسرا کام")
        self.assertIsNone(unscheduled[1]["titleUr"])

    def test_main_falls_back_to_the_file_when_github_has_no_roadmap(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "roadmap.toml"
            source.write_text(SMALL, encoding="utf-8")
            output = Path(directory) / "roadmap.json"
            original = fetch_roadmap.GitHub
            fetch_roadmap.GitHub = lambda repository, token: GitHub(
                repository, token, opener=FakeGitHub()
            )
            try:
                code = fetch_roadmap.main(
                    [
                        "--from-github",
                        "--repository",
                        "owner/repo",
                        "--file",
                        str(source),
                        "--output",
                        str(output),
                    ]
                )
            finally:
                fetch_roadmap.GitHub = original
            self.assertEqual(code, 0)
            self.assertEqual(json.loads(output.read_text(encoding="utf-8"))["source"], "file")

    def test_the_committed_copy_is_current(self):
        expected = fetch_roadmap.from_file(load(ROADMAP_FILE), fetch_roadmap.REPOSITORY)
        committed = json.loads(fetch_roadmap.OUTPUT.read_text(encoding="utf-8"))
        self.assertEqual(committed, expected, "run `make roadmap`")


if __name__ == "__main__":
    unittest.main()
