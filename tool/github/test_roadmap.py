"""Tests of the roadmap tooling (make test-tools): the file, the sync and the fetch."""

import datetime as dt
import io
import json
import re
import sys
import tempfile
import unittest
import urllib.error
import urllib.parse
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import fetch_roadmap
import sync_roadmap
from roadmap_lib import (
    ROADMAP_FILE,
    GitHub,
    RoadmapError,
    find_marker,
    load,
    opened_by_project,
    strip_marker,
)

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

SECOND = """
[[milestones]]
id = "second"
title = "Second"
title_ur = "دوسرا"
due = "2027-06-30"
description = "The second step."
description_ur = "دوسرا قدم"

[[milestones.issues]]
id = "three"
title = "Issue three"
title_ur = "تیسرا کام"
body = "Do a third thing."
"""

# How GitHub lists an issue's author: the sync's bot, and someone outside the project.
SYNC_BOT = {"user": {"login": "github-actions[bot]", "type": "Bot"}, "author_association": "NONE"}
OUTSIDER = {"user": {"login": "someone", "type": "User"}, "author_association": "NONE"}


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
        path = re.sub(r"^/repos/[^/]+/[^/]+", "", url.path)
        query = dict(urllib.parse.parse_qsl(url.query))
        body = json.loads(request.data) if request.data else None
        method = request.get_method()
        if method != "GET":
            self.writes.append((method, path))
        if path.startswith("/milestones") and method != "GET" and self.title_taken(path, body):
            # GitHub refuses a milestone title another milestone has, whatever its case.
            raise urllib.error.HTTPError(request.full_url, 422, "Validation Failed", {}, None)
        result = self.route(method, path, query, body)
        if result is None and method == "GET":
            raise urllib.error.HTTPError(request.full_url, 404, "Not Found", {}, None)
        return FakeResponse(json.dumps(result).encode())

    def title_taken(self, path, body):
        number = int(path.split("/")[-1]) if path.startswith("/milestones/") else None
        title = str(body.get("title", "")).casefold()
        return any(
            m["number"] != number and str(m["title"]).casefold() == title for m in self.milestones
        )

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
                    **SYNC_BOT,
                    "number": number,
                    "state": "open",
                    "state_reason": None,
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
        # The right shape, but no such day: 2027 is not a leap year.
        with self.assertRaisesRegex(RoadmapError, "not a real date"):
            small_roadmap(SMALL.replace("2027-02-28", "2027-02-29"))
        with self.assertRaisesRegex(RoadmapError, "not a real date"):
            small_roadmap(SMALL.replace("2027-02-28", "2027-06-31"))
        self.assertEqual(
            small_roadmap(SMALL.replace("2027-02-28", "2028-02-29")).milestones[0].due, "2028-02-29"
        )

    def test_milestone_titles_are_unique_whatever_their_case(self):
        self.assertEqual(len(small_roadmap(SMALL + SECOND).milestones), 2)
        with self.assertRaisesRegex(RoadmapError, "'first' already has the title 'FIRST'"):
            small_roadmap(SMALL + SECOND.replace('title = "Second"', 'title = "FIRST"'))
        # Issues are matched by id alone, and GitHub allows two with one title.
        self.assertEqual(len(small_roadmap(SMALL.replace("Issue two", "Issue one")).issue_ids()), 2)

    def test_markers(self):
        self.assertEqual(find_marker("Text\n\n<!-- roadmap: one -->"), "one")
        self.assertIsNone(find_marker(None))
        self.assertEqual(strip_marker("Text\n\n<!-- roadmap: one -->"), "Text")

    def test_only_the_project_opens_the_roadmap_s_issues(self):
        body = "Text\n\n<!-- roadmap: one -->"
        for association in ("OWNER", "MEMBER", "COLLABORATOR"):
            self.assertTrue(opened_by_project({"author_association": association, "body": ""}))
        self.assertTrue(opened_by_project({**SYNC_BOT, "body": body}))
        # A bot's issue without a roadmap id was not opened by the sync.
        self.assertFalse(opened_by_project({**SYNC_BOT, "body": "Text"}))
        # Anyone can copy the hidden id into an issue of their own; the author still decides.
        self.assertFalse(opened_by_project({**OUTSIDER, "body": body}))
        self.assertFalse(opened_by_project({"author_association": "CONTRIBUTOR", "body": body}))
        self.assertFalse(opened_by_project({"body": body}))


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

    def test_an_outsider_s_issue_with_a_roadmap_id_does_not_stand_in_for_it(self):
        self.fake.issues.append(
            {**OUTSIDER, "number": 1, "title": "Mine", "body": "<!-- roadmap: one -->"}
        )
        self.run_sync()
        ours = [i for i in self.fake.issues if i.get("user", {}).get("type") == "Bot"]
        self.assertEqual([find_marker(i["body"]) for i in ours], ["one", "two"])

    def test_a_milestone_s_old_title_goes_to_a_new_one_without_taking_its_issues(self):
        # "first" was "Beta"; it is renamed, and a new milestone "second" takes the title.
        label, first = SMALL.split("[[milestones]]", 1)
        before = label + "[[milestones]]" + first.replace('title = "First"', 'title = "Beta"')
        renamed = "\n[[milestones]]" + first.replace('title = "First"', 'title = "Beta one"')
        second = SECOND.replace('title = "Second"', 'title = "Beta"')
        # The new milestone listed after the renamed one, and before it.
        for after in (label + renamed + second, label + second + renamed):
            with self.subTest(new_one_first=after.index('"second"') < after.index('"first"')):
                self.fake = FakeGitHub()
                self.github = GitHub("owner/repo", "token", opener=self.fake)
                self.roadmap = small_roadmap(before)
                self.run_sync()
                self.roadmap = small_roadmap(after)
                for _ in range(3):
                    self.run_sync()
                titles = {find_marker(m["description"]): m["title"] for m in self.fake.milestones}
                self.assertEqual(titles, {"first": "Beta one", "second": "Beta"})
                stages = {
                    find_marker(i["body"]): find_marker(i["milestone"]["description"])
                    for i in self.fake.issues
                }
                self.assertEqual(stages, {"one": "first", "two": "first", "three": "second"})
                self.fake.writes.clear()
                self.run_sync()
                self.assertEqual(self.fake.writes, [])

    def test_a_milestone_found_by_title_is_taken_over_once(self):
        # A milestone made by hand before the roadmap existed is adopted by its title.
        self.fake.milestones.append(
            {"number": 1, "title": "First", "description": "", "state": "open", "due_on": None}
        )
        self.run_sync()
        self.assertEqual(len(self.fake.milestones), 1)
        self.assertEqual(find_marker(self.fake.milestones[0]["description"]), "first")


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
        self.fake.issues[0].update(state="closed", state_reason="completed")
        self.fake.issues[1]["title"] = "Issue two, renamed"
        stranger = {
            "number": 3,
            "title": "Added on GitHub",
            "body": "",
            "labels": [{"name": "roadmap"}],
            "state": "open",
            "milestone": self.fake.milestones[0],
            "html_url": "https://github.com/i/3",
            "user": {"login": "maintainer", "type": "User"},
            "author_association": "MEMBER",
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
                "user": {"login": "maintainer", "type": "User"},
                "author_association": "COLLABORATOR",
            }
        )
        data = fetch_roadmap.from_github(self.roadmap, self.github, dt.date(2026, 11, 11))
        self.assertEqual([i["number"] for i in data["milestones"][0]["issues"]], [1])
        unscheduled = data["unscheduled"]
        self.assertEqual([i["number"] for i in unscheduled], [2, 3])
        self.assertEqual(unscheduled[0]["id"], "two")
        self.assertEqual(unscheduled[0]["titleUr"], "دوسرا کام")
        self.assertIsNone(unscheduled[1]["titleUr"])

    def test_an_issue_someone_outside_the_project_opened_stays_off_the_site(self):
        sync_roadmap.sync(
            self.roadmap, GitHub("owner/repo", "t", opener=self.fake), log=lambda _: None
        )
        for number, body in ((3, "Please add this."), (4, "<!-- roadmap: one -->")):
            self.fake.issues.append(
                {
                    **OUTSIDER,
                    "number": number,
                    "title": "A title its author can change at any time",
                    "body": body,
                    "labels": [{"name": "roadmap"}],
                    "state": "open",
                    "milestone": self.fake.milestones[0] if number == 3 else None,
                    "html_url": f"https://github.com/i/{number}",
                }
            )
        data = fetch_roadmap.from_github(self.roadmap, self.github, dt.date(2026, 11, 11))
        self.assertEqual([i["number"] for i in data["milestones"][0]["issues"]], [1, 2])
        self.assertEqual(data["unscheduled"], [])

    def test_an_issue_closed_undone_is_neither_listed_nor_counted(self):
        sync_roadmap.sync(
            self.roadmap, GitHub("owner/repo", "t", opener=self.fake), log=lambda _: None
        )
        milestone = self.fake.milestones[0]
        self.fake.issues[0].update(state="closed", state_reason="not_planned")
        self.fake.issues[1].update(state="closed", state_reason="duplicate")
        for number, reason in ((3, "completed"), (4, None), (5, "reopened")):
            self.fake.issues.append(
                {
                    "number": number,
                    "title": f"Issue {number}",
                    "body": "",
                    "labels": [{"name": "roadmap"}],
                    "state": "open" if reason == "reopened" else "closed",
                    "state_reason": reason,
                    "milestone": milestone,
                    "html_url": f"https://github.com/i/{number}",
                    "author_association": "OWNER",
                }
            )
        data = fetch_roadmap.from_github(self.roadmap, self.github, dt.date(2026, 11, 11))
        issues = data["milestones"][0]["issues"]
        # Completed, closed before GitHub kept reasons (shown as completed), and reopened.
        self.assertEqual(
            [(i["number"], i["state"]) for i in issues],
            [(3, "closed"), (4, "closed"), (5, "open")],
        )

    def test_the_file_s_copy_names_the_project_s_repository_wherever_it_is_made(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "roadmap.toml"
            source.write_text(SMALL, encoding="utf-8")
            output = Path(directory) / "roadmap.json"
            arguments = ["--file", str(source), "--output", str(output)]
            # As in a Codespace on a fork, which sets GITHUB_REPOSITORY to the fork.
            with mock.patch.dict("os.environ", {"GITHUB_REPOSITORY": "contributor/fork"}):
                self.assertEqual(fetch_roadmap.main(["--from-file", *arguments]), 0)
                repository = json.loads(output.read_text(encoding="utf-8"))["repository"]
                self.assertEqual(repository, f"https://github.com/{fetch_roadmap.REPOSITORY}")
                fetch_roadmap.main(["--from-file", "--repository", "owner/repo", *arguments])
                repository = json.loads(output.read_text(encoding="utf-8"))["repository"]
                self.assertEqual(repository, "https://github.com/owner/repo")
                # Live data, and the file's copy in its place, are the workflow's repository's.
                original = fetch_roadmap.GitHub
                read: list[str] = []
                fetch_roadmap.GitHub = lambda repository, token: (
                    read.append(repository) or GitHub(repository, token, opener=FakeGitHub())
                )
                try:
                    fetch_roadmap.main(["--from-github", *arguments])
                finally:
                    fetch_roadmap.GitHub = original
                self.assertEqual(read, ["contributor/fork"])
                repository = json.loads(output.read_text(encoding="utf-8"))["repository"]
                self.assertEqual(repository, "https://github.com/contributor/fork")

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
