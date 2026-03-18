from __future__ import annotations

from flask import Blueprint, jsonify, request

from ai.signals.push_signal_to_linear import push_signal_to_linear
from integrations.linear.linear_client import LinearAPIError, LinearClient

bp = Blueprint("qai_linear", __name__)


def _client() -> LinearClient:
    return LinearClient()


def _json_error(message: str, status_code: int = 400):
    return jsonify(ok=False, error=message), status_code


@bp.errorhandler(ValueError)
def handle_value_error(exc: ValueError):
    return _json_error(str(exc), 400)


@bp.errorhandler(LinearAPIError)
def handle_linear_error(exc: LinearAPIError):
    return _json_error(str(exc), 502)


@bp.get("/linear/health")
def linear_health():
    data = _client().health()
    viewer = data.get("viewer", {})
    return jsonify(ok=True, viewer=viewer)


@bp.get("/linear/teams")
def linear_teams():
    teams = _client().list_teams()
    return jsonify(ok=True, count=len(teams), teams=teams)


@bp.post("/linear/issues")
def linear_issue_create():
    body = request.get_json(silent=True) or {}
    title = str(body.get("title") or "").strip()
    description = str(body.get("description") or "").strip()
    team_id = str(body.get("team_id") or "").strip() or None
    team_key = str(body.get("team_key") or "").strip() or None
    team_name = str(body.get("team_name") or "").strip() or None
    state_id = str(body.get("state_id") or "").strip() or None
    project_id = str(body.get("project_id") or "").strip() or None
    label_ids = body.get("label_ids") if isinstance(body.get("label_ids"), list) else None
    priority = body.get("priority")

    if not title:
        raise ValueError("title required")
    if not description:
        raise ValueError("description required")

    issue = _client().create_issue(
        title=title,
        description=description,
        team_id=team_id,
        team_key=team_key,
        team_name=team_name,
        state_id=state_id,
        project_id=project_id,
        label_ids=label_ids,
        priority=priority,
    )
    return jsonify(ok=True, issue=issue)


@bp.post("/linear/issues/from-signal")
def linear_issue_from_signal():
    body = request.get_json(silent=True) or {}
    result = push_signal_to_linear(
        signal_path=body.get("signal_path"),
        team_id=body.get("team_id"),
        team_key=body.get("team_key"),
        team_name=body.get("team_name"),
        priority=body.get("priority"),
    )
    return jsonify(result)


def register_qai_linear(app) -> None:
    app.register_blueprint(bp)
