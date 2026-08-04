def test_create_project(client, auth_headers, sample_chama):
    r = client.post(f"/chamas/{sample_chama['id']}/projects", json={
        "title": "Harambee ya Wanjiku",
        "target_amount": 50000,
        "payment_type": "paybill",
        "payment_number": "174379",
    }, headers=auth_headers)
    assert r.status_code == 201
    data = r.json()
    assert data["title"] == "Harambee ya Wanjiku"
    assert data["raised_amount"] == 0.0
    assert data["percentage_funded"] == 0.0
    assert data["deficit"] == 50000.0
    assert data["is_funded"] is False


def test_list_my_projects(client, auth_headers, sample_project):
    r = client.get("/projects/mine", headers=auth_headers)
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


def test_create_project_unauthenticated(client, sample_chama):
    r = client.post(f"/chamas/{sample_chama['id']}/projects", json={
        "title": "No auth",
        "target_amount": 1000,
        "payment_type": "paybill",
        "payment_number": "174379",
    })
    # FastAPI's HTTPBearer defaults to auto_error=True, which raises 403
    # ("Not authenticated") for a missing header — 401 only comes from
    # get_auth_context once a header is present but invalid. Same
    # pre-existing behavior test_auth.py::test_me_unauthenticated already
    # exercises; not something API-01 changes.
    assert r.status_code == 403


def test_search_my_projects(client, auth_headers, sample_project):
    r = client.get("/projects/mine?search=Harambee", headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["total"] >= 1

    r2 = client.get("/projects/mine?search=NoSuchProjectTitle", headers=auth_headers)
    assert r2.status_code == 200
    assert r2.json()["total"] == 0


def test_get_contributors_empty(client, auth_headers, sample_project):
    r = client.get(f"/projects/{sample_project['id']}/contributors", headers=auth_headers)
    assert r.status_code == 200
    assert r.json() == []


def test_project_amount_validation(client, auth_headers, sample_chama):
    r = client.post(f"/chamas/{sample_chama['id']}/projects", json={
        "title": "Tiny project",
        "target_amount": 50,
        "payment_type": "paybill",
        "payment_number": "174379",
    }, headers=auth_headers)
    assert r.status_code == 422
