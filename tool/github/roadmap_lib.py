"""The roadmap file (.github/roadmap.toml) and a small GitHub REST client.

Shared by sync_roadmap.py, which writes the roadmap's milestones and issues to
GitHub, and fetch_roadmap.py, which reads them back for the website.
"""

from __future__ import annotations

import datetime as dt
import json
import re
import tomllib
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
ROADMAP_FILE = ROOT / ".github" / "roadmap.toml"
API = "https://api.github.com"
ID = re.compile(r"^[a-z][a-z0-9-]{1,63}$")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MARKER = re.compile(r"<!-- roadmap: ([a-z][a-z0-9-]{1,63}) -->")
# How GitHub describes an issue's author who belongs to the project: the repository's owner, a
# member of the organisation that owns it, or a collaborator on it.
PROJECT_AUTHORS = frozenset({"OWNER", "MEMBER", "COLLABORATOR"})


def marker(item_id: str) -> str:
    """The hidden comment that ties a GitHub milestone or issue to its roadmap id."""
    return f"<!-- roadmap: {item_id} -->"


def find_marker(text: str | None) -> str | None:
    match = MARKER.search(text or "")
    return match.group(1) if match else None


def strip_marker(text: str | None) -> str:
    return MARKER.sub("", text or "").strip()


def opened_by_project(issue: dict[str, Any]) -> bool:
    """Whether an issue was opened by the project, so that no one outside it can retitle it.

    Anyone can open an issue, and its author can change its title at any time, even after a
    maintainer has labelled it or put it in a milestone. So the roadmap takes an issue as its own
    only when the project opened it: its author is the project's owner, a member or a
    collaborator, or it was opened by the sync, as a bot with a roadmap id in its body. A bot is a
    GitHub App, which can open issues only in a repository it is installed in. The id alone proves
    nothing, since anyone can type the hidden comment into an issue they open.
    """
    if issue.get("author_association") in PROJECT_AUTHORS:
        return True
    author = issue.get("user") or {}
    return author.get("type") == "Bot" and find_marker(issue.get("body")) is not None


@dataclass(frozen=True)
class Issue:
    id: str
    title: str
    title_ur: str
    body: str


@dataclass(frozen=True)
class Milestone:
    id: str
    title: str
    title_ur: str
    due: str
    description: str
    description_ur: str
    issues: tuple[Issue, ...] = field(default_factory=tuple)


@dataclass(frozen=True)
class Label:
    name: str
    color: str
    description: str


@dataclass(frozen=True)
class Roadmap:
    label: Label
    milestones: tuple[Milestone, ...]

    def issue_ids(self) -> list[str]:
        return [issue.id for m in self.milestones for issue in m.issues]


class RoadmapError(ValueError):
    """The roadmap file is not valid."""


def _text(table: dict[str, Any], key: str, where: str) -> str:
    value = table.get(key)
    if not isinstance(value, str) or not value.strip():
        raise RoadmapError(f"{where}: '{key}' must be a non-empty string")
    return value.strip()


def _no_latin(value: str, where: str) -> str:
    if re.search(r"[A-Za-z]", value):
        raise RoadmapError(f"{where}: Urdu text must be in Urdu script only: {value!r}")
    return value


def _date(value: str, where: str) -> str:
    if not DATE.fullmatch(value):
        raise RoadmapError(f"{where}: due must be YYYY-MM-DD, not {value!r}")
    try:
        dt.date.fromisoformat(value)
    except ValueError:
        raise RoadmapError(f"{where}: due {value!r} is not a real date") from None
    return value


def load(path: Path = ROADMAP_FILE) -> Roadmap:
    """Reads and checks the roadmap file.

    Ids are unique, due dates are real dates, milestone titles are unique (GitHub refuses a second
    milestone with a title already taken, ignoring case) and Urdu is in Urdu script.
    """
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    label_table = data.get("label")
    if not isinstance(label_table, dict):
        raise RoadmapError("[label] is missing")
    color = _text(label_table, "color", "label")
    if not re.fullmatch(r"[0-9A-Fa-f]{6}", color):
        raise RoadmapError(f"label: color must be six hex digits, not {color!r}")
    label = Label(
        _text(label_table, "name", "label"), color, _text(label_table, "description", "label")
    )
    seen: set[str] = set()
    titles: dict[str, str] = {}
    milestones: list[Milestone] = []
    for index, table in enumerate(data.get("milestones") or []):
        where = f"milestones[{index}]"
        milestone_id = _text(table, "id", where)
        if not ID.fullmatch(milestone_id) or milestone_id in seen:
            raise RoadmapError(f"{where}: id {milestone_id!r} is not a unique lower-case id")
        seen.add(milestone_id)
        title = _text(table, "title", where)
        if (other := titles.get(title.casefold())) is not None:
            raise RoadmapError(f"{where}: milestone {other!r} already has the title {title!r}")
        titles[title.casefold()] = milestone_id
        due = _date(_text(table, "due", where), where)
        issues: list[Issue] = []
        for issue_index, issue in enumerate(table.get("issues") or []):
            issue_where = f"{where}.issues[{issue_index}]"
            issue_id = _text(issue, "id", issue_where)
            if not ID.fullmatch(issue_id) or issue_id in seen:
                raise RoadmapError(f"{issue_where}: id {issue_id!r} is not a unique lower-case id")
            seen.add(issue_id)
            issues.append(
                Issue(
                    id=issue_id,
                    title=_text(issue, "title", issue_where),
                    title_ur=_no_latin(_text(issue, "title_ur", issue_where), issue_where),
                    body=_text(issue, "body", issue_where),
                )
            )
        milestones.append(
            Milestone(
                id=milestone_id,
                title=title,
                title_ur=_no_latin(_text(table, "title_ur", where), where),
                due=due,
                description=_text(table, "description", where),
                description_ur=_no_latin(_text(table, "description_ur", where), where),
                issues=tuple(issues),
            )
        )
    if not milestones:
        raise RoadmapError("the roadmap has no milestones")
    return Roadmap(label, tuple(milestones))


Opener = Callable[[urllib.request.Request], Any]


def _open(request: urllib.request.Request) -> Any:
    # Only ever the https:// GitHub API address built below.
    return urllib.request.urlopen(request, timeout=30)  # noqa: S310


class GitHub:
    """The few GitHub REST calls the roadmap needs, with pagination."""

    def __init__(
        self,
        repository: str,
        token: str | None = None,
        api: str = API,
        opener: Opener | None = None,
    ) -> None:
        if not re.fullmatch(r"[\w.-]+/[\w.-]+", repository):
            raise ValueError(f"not an owner/name repository: {repository!r}")
        self.repository = repository
        self.token = token
        self.api = api.rstrip("/")
        self.opener = opener or _open

    def request(
        self,
        method: str,
        path: str,
        body: dict[str, Any] | None = None,
        params: dict[str, str] | None = None,
    ) -> Any:
        url = f"{self.api}/repos/{self.repository}{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request(url, data=data, method=method)  # noqa: S310 - https only
        request.add_header("Accept", "application/vnd.github+json")
        request.add_header("X-GitHub-Api-Version", "2022-11-28")
        request.add_header("User-Agent", "maalik-e-makaan-roadmap")
        if data is not None:
            request.add_header("Content-Type", "application/json")
        if self.token:
            request.add_header("Authorization", f"Bearer {self.token}")
        with self.opener(request) as response:
            raw = response.read()
        return json.loads(raw) if raw else None

    def paginate(self, path: str, params: dict[str, str] | None = None) -> list[Any]:
        items: list[Any] = []
        for page in range(1, 51):
            batch = self.request(
                "GET", path, params={**(params or {}), "per_page": "100", "page": str(page)}
            )
            if not isinstance(batch, list):
                raise ValueError(f"GitHub returned {type(batch).__name__} for {path}, not a list")
            items.extend(batch)
            if len(batch) < 100:
                return items
        raise ValueError(f"{path}: more than 5,000 items")

    def get_or_none(self, path: str) -> Any:
        try:
            return self.request("GET", path)
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            raise
