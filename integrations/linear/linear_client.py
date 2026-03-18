from __future__ import annotations

import os
from typing import Any

import requests

from integrations.cache import cache_get_value, cache_set


class LinearAPIError(RuntimeError):
    pass


class LinearClient:
    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        timeout: float | None = None,
    ) -> None:
        self.api_key = (api_key or os.getenv("LINEAR_API_KEY", "")).strip()
        self.base_url = (base_url or os.getenv("LINEAR_API_URL", "https://api.linear.app/graphql")).strip()
        self.timeout = float(timeout or os.getenv("LINEAR_API_TIMEOUT", "20"))
        if not self.api_key:
            raise LinearAPIError("LINEAR_API_KEY missing")

    def _graphql(self, query: str, variables: dict[str, Any] | None = None) -> dict[str, Any]:
        response = requests.post(
            self.base_url,
            headers={
                "Authorization": self.api_key,
                "Content-Type": "application/json",
            },
            json={"query": query, "variables": variables or {}},
            timeout=self.timeout,
        )
        response.raise_for_status()
        payload = response.json()
        errors = payload.get("errors") or []
        if errors:
            message = "; ".join(str(err.get("message", "Linear GraphQL error")) for err in errors)
            raise LinearAPIError(message)
        data = payload.get("data")
        if not isinstance(data, dict):
            raise LinearAPIError("invalid Linear response")
        return data

    def health(self) -> dict[str, Any]:
        return self._graphql(
            """
            query LinearViewerHealth {
              viewer {
                id
                name
                email
                active
              }
            }
            """
        )

    def list_teams(self, ttl: int = 300) -> list[dict[str, Any]]:
        cache_key = "linear:teams"
        cached = cache_get_value(cache_key)
        if isinstance(cached, list) and cached:
            return cached
        data = self._graphql(
            """
            query LinearTeams {
              teams(first: 50) {
                nodes {
                  id
                  key
                  name
                }
              }
            }
            """
        )
        teams = data.get("teams", {}).get("nodes", [])
        if isinstance(teams, list):
            cache_set(cache_key, teams, ttl)
            return teams
        return []

    def resolve_team_id(
        self,
        team_id: str | None = None,
        team_key: str | None = None,
        team_name: str | None = None,
    ) -> str:
        if team_id:
            return team_id
        env_team_id = os.getenv("LINEAR_TEAM_ID", "").strip()
        if env_team_id:
            return env_team_id

        lookup_key = (team_key or os.getenv("LINEAR_TEAM_KEY", "")).strip().lower()
        lookup_name = (team_name or os.getenv("LINEAR_TEAM_NAME", "")).strip().lower()
        teams = self.list_teams()
        if lookup_key:
            for team in teams:
                if str(team.get("key", "")).strip().lower() == lookup_key:
                    return str(team["id"])
        if lookup_name:
            for team in teams:
                if str(team.get("name", "")).strip().lower() == lookup_name:
                    return str(team["id"])
        if len(teams) == 1:
            return str(teams[0]["id"])
        raise LinearAPIError("Linear team could not be resolved; set LINEAR_TEAM_ID or LINEAR_TEAM_KEY")

    def create_issue(
        self,
        title: str,
        description: str,
        *,
        team_id: str | None = None,
        team_key: str | None = None,
        team_name: str | None = None,
        priority: int | None = None,
        state_id: str | None = None,
        label_ids: list[str] | None = None,
        project_id: str | None = None,
    ) -> dict[str, Any]:
        resolved_team_id = self.resolve_team_id(team_id=team_id, team_key=team_key, team_name=team_name)
        issue_input: dict[str, Any] = {
            "teamId": resolved_team_id,
            "title": title,
            "description": description,
        }
        if priority is not None:
            issue_input["priority"] = int(priority)
        if state_id:
            issue_input["stateId"] = state_id
        if label_ids:
            issue_input["labelIds"] = label_ids
        if project_id:
            issue_input["projectId"] = project_id

        data = self._graphql(
            """
            mutation LinearIssueCreate($input: IssueCreateInput!) {
              issueCreate(input: $input) {
                success
                issue {
                  id
                  identifier
                  title
                  url
                  priority
                  state {
                    id
                    name
                  }
                  team {
                    id
                    key
                    name
                  }
                }
              }
            }
            """,
            {"input": issue_input},
        )
        result = data.get("issueCreate") or {}
        if not result.get("success"):
            raise LinearAPIError("Linear issueCreate failed")
        issue = result.get("issue")
        if not isinstance(issue, dict):
            raise LinearAPIError("Linear issueCreate returned no issue")
        return issue
