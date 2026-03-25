def test_create_project(client, auth_headers):
    r = client.post("/projects", json={
        "title": "Harambee ya Wanjiku",
        "target_amount": 50000,
        "visibility": "public",
    }, headers=auth_headers)
    assert r.status_code == 201
    data = r.json()
    assert data["title"] == "Harambee ya Wanjiku"
    assert data["raised_amount"] == 0.0
    assert data["percentage_funded"] == 0.0
    assert data["deficit"] == 50000.0
    assert data["is_funded"] is False


def test_list_projects_public(client, auth_headers, sample_project):
    r = client.get("/projects", headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["total"] >= 1


def test_get_project(client, auth_headers, sample_project):
    r = client.get(f"/projects/{sample_project['id']}", headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["id"] == sample_project["id"]


def test_update_project(client, auth_headers, sample_project):
    r = client.put(f"/projects/{sample_project['id']}",
        json={"title": "Updated Harambee"},
        headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["title"] == "Updated Harambee"


def test_delete_project(client, auth_headers, sample_project):
    r = client.delete(f"/projects/{sample_project['id']}", headers=auth_headers)
    assert r.status_code == 204
    r2 = client.get(f"/projects/{sample_project['id']}", headers=auth_headers)
    assert r2.status_code == 404


def test_create_project_unauthenticated(client):
    r = client.post("/projects", json={"title": "No auth", "target_amount": 1000})
    assert r.status_code == 401


def test_search_projects(client, auth_headers, sample_project):
    r = client.get("/projects?search=Harambee", headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["total"] >= 1


def test_create_team(client, auth_headers, sample_project):
    r = client.post(f"/projects/{sample_project['id']}/teams",
        json={"name": "Team Nairobi", "description": "Watu wa Nairobi"},
        headers=auth_headers)
    assert r.status_code == 201
    assert r.json()["name"] == "Team Nairobi"


def test_list_teams(client, auth_headers, sample_project):
    client.post(f"/projects/{sample_project['id']}/teams",
        json={"name": "Team Nairobi"}, headers=auth_headers)
    r = client.get(f"/projects/{sample_project['id']}/teams", headers=auth_headers)
    assert r.status_code == 200
    assert len(r.json()) >= 1


def test_get_contributors_empty(client, auth_headers, sample_project):
    r = client.get(f"/projects/{sample_project['id']}/contributors", headers=auth_headers)
    assert r.status_code == 200
    assert r.json() == []


def test_project_amount_validation(client, auth_headers):
    r = client.post("/projects", json={
        "title": "Tiny project",
        "target_amount": 50,
    }, headers=auth_headers)
    assert r.status_code == 422
