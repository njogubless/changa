"""
reset_db.py — drops all tables and recreates them fresh.
Run from inside the backend container:

    docker exec -it changa-api-1 python reset_db.py

Or from your project root:

    docker compose exec api python reset_db.py
"""

from app.database import Base, engine
from app.models.models import (
    User, Chama, ChamaMember, Project,
    Contribution, RefreshToken,
)

print(" Dropping all tables...")
Base.metadata.drop_all(bind=engine)
print("All tables dropped.")

print(" Creating tables...")
Base.metadata.create_all(bind=engine)
print("All tables created.")

print("""
Tables created:
  - users
  - chamas
  - chama_members
  - projects
  - contributions
  - refresh_tokens

Done. Register a fresh user and create a Chama to get started.
""")