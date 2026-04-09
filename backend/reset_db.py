"""
reset_db.py — drops all tables and recreates them fresh.

Run from inside the backend container:
    docker compose exec api python reset_db.py
"""

from app.database import Base, engine
from app.models.models import (
    User, Chama, ChamaMember, Project,
    Contribution, RefreshToken,
    Budget, BudgetCategory, BudgetExpense,
)

print("⚠️  Dropping all tables...")
Base.metadata.drop_all(bind=engine)
print("✅ All tables dropped.")

print("🔨 Creating tables...")
Base.metadata.create_all(bind=engine)
print("✅ All tables created.")

print("""
Tables created:
  - users
  - refresh_tokens
  - chamas
  - chama_members
  - projects
  - contributions
  - budgets
  - budget_categories
  - budget_expenses

Done. Register a fresh user to get started.
""")