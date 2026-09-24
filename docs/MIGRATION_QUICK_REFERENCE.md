# SEAD Clearinghouse Migration - Quick Reference

**Last Updated:** February 20, 2026  
**Full Plan:** See [MIGRATION_PLAN_PHP_TO_FASTAPI.md](./MIGRATION_PLAN_PHP_TO_FASTAPI.md)

---

## Quick Stats

- **Current:** PHP 7+ with Slim Framework 3.10
- **Target:** Python 3.11+ with FastAPI
- **Endpoints:** 30+
- **Services:** 20+
- **Repositories:** 15+
- **Timeline:** 16-24 weeks
- **Team:** 2-3 developers + 1 QA

---

## Migration Phases Overview

| # | Phase | Duration | Priority |
|---|-------|----------|----------|
| 1 | Foundation & Infrastructure | 4-6 weeks | Critical |
| 2 | Authentication & Authorization | 2-3 weeks | Critical |
| 3 | Core Models & Schemas | 3-4 weeks | Critical |
| 4 | Repository Layer | 3-4 weeks | Critical |
| 5 | Service Layer | 4-5 weeks | Critical |
| 6 | API Routes | 4-5 weeks | Critical |
| 7 | Background Tasks & Processing | 2-3 weeks | High |
| 8 | Email & External Services | 1-2 weeks | Medium |
| 9 | Caching | 1-2 weeks | Medium |
| 10 | Testing | 3-4 weeks | Critical |

---

## Tech Stack Comparison

| Component | PHP | Python/FastAPI |
|-----------|-----|----------------|
| Framework | Slim 3.10 | FastAPI 0.110+ |
| Database | PDO | SQLAlchemy 2.0 + asyncpg |
| Auth | PHP Sessions | JWT (python-jose) |
| Validation | Manual | Pydantic v2 |
| Testing | PHPUnit | pytest |
| Email | PHPMailer | aiosmtplib |
| Cache | File-based | Redis (aiocache) |
| Background Jobs | Cron + process.php | Celery + APScheduler |

---

## Directory Structure Mapping

```
PHP (src/api/)                    Python (app/)
├── Application/                  ├── core/
│   ├── Main.php                  │   ├── security.py
│   ├── Router.php                │   ├── logging.py
│   ├── Session.php               │   └── exceptions.py
│   └── Commands/                 ├── api/v1/
├── InfraStructure/               │   ├── auth.py
│   ├── DatabaseConnection.php    │   ├── users.py
│   └── ConfigService.php         │   └── submissions.py
├── Services/                     ├── services/
│   ├── UserService.php           │   ├── user.py
│   └── SubmissionService.php     │   └── submission.py
├── Repository/                   ├── repositories/
│   ├── RepositoryBase.php        │   ├── base.py
│   └── UserRepository.php        │   └── user.py
└── Model/                        ├── models/
    └── User.php                  │   └── user.py
                                  ├── schemas/
                                  │   └── user.py
                                  ├── database.py
                                  ├── config.py
                                  └── main.py
```

---

## Key Endpoints to Migrate

### Authentication (2)
- `GET /login` → `POST /api/v1/auth/login`
- `GET /logout` → `POST /api/v1/auth/logout`

### Users (5)
- `GET /users` → `GET /api/v1/users`
- `GET /users/{id}` → `GET /api/v1/users/{id}`
- `POST /users` → `POST /api/v1/users`
- `PUT /users` → `PUT /api/v1/users/{id}`
- `DELETE /users/{id}` → `DELETE /api/v1/users/{id}`

### Submissions (10+)
- `GET /submissions` → `GET /api/v1/submissions`
- `GET /submissions/{id}` → `GET /api/v1/submissions/{id}`
- `GET /submission/{id}/claim` → `POST /api/v1/submissions/{id}/claim`
- `GET /submission/{id}/unclaim` → `POST /api/v1/submissions/{id}/unclaim`
- `GET /submission/{id}/accept` → `POST /api/v1/submissions/{id}/accept`
- `GET /submission/{id}/reject` → `POST /api/v1/submissions/{id}/reject`
- ... (see full plan for complete list)

---

## Core Patterns to Implement

### 1. Configuration
```python
# app/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    secret_key: str
    # ... other settings
    
    class Config:
        env_file = ".env"
```

### 2. Database Session
```python
# app/database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession

engine = create_async_engine(settings.database_url)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession)

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
```

### 3. Authentication
```python
# app/core/security.py
from jose import jwt
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"])

def create_access_token(data: dict):
    return jwt.encode(data, settings.secret_key, algorithm="HS256")

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    # Validate token and return user
```

### 4. Repository Pattern
```python
# app/repositories/base.py
class BaseRepository(Generic[ModelType]):
    async def get_by_id(self, db: AsyncSession, id: int):
        result = await db.execute(select(self.model).where(self.model.id == id))
        return result.scalar_one_or_none()
```

### 5. Service Pattern
```python
# app/services/submission.py
class SubmissionService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = SubmissionRepository()
    
    async def claim_submission(self, submission_id: int, user: User):
        # Business logic here
```

### 6. API Routes
```python
# app/api/v1/submissions.py
@router.post("/{submission_id}/claim")
async def claim_submission(
    submission_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    service = SubmissionService(db)
    return await service.claim_submission(submission_id, current_user)
```

---

## Critical Files to Understand

### PHP Side
1. `src/api/Application/Router.php` - All route definitions
2. `src/api/Application/Main.php` - Main controller logic
3. `src/api/Application/ClearingHouseCommand.php` - Command pattern
4. `src/api/Services/Locator.php` - Service locator
5. `src/api/Repository/RepositoryBase.php` - Repository pattern
6. `src/api/InfraStructure/DatabaseConnection.php` - Database layer
7. `src/api/InfraStructure/ConfigService.php` - Configuration
8. `src/api/Application/Session.php` - Session management

### Database
1. `src/sql/02_clearinghouse_model.sql` - Main schema
2. `src/sql/04_entity_model.sql` - Entity definitions
3. Stored procedure: `clearing_house.fn_explode_submission_xml_to_rdb()`

---

## Dependencies to Install

```toml
[tool.poetry.dependencies]
python = "^3.11"
fastapi = "^0.110.0"
uvicorn = {extras = ["standard"], version = "^0.27.0"}
sqlalchemy = "^2.0.25"
asyncpg = "^0.29.0"
pydantic = {extras = ["email"], version = "^2.6.0"}
pydantic-settings = "^2.1.0"
python-jose = {extras = ["cryptography"], version = "^3.3.0"}
passlib = {extras = ["bcrypt"], version = "^1.7.4"}
python-multipart = "^0.0.9"
aiosmtplib = "^3.0.1"
aiocache = "^0.12.2"
alembic = "^1.13.0"
redis = "^5.0.1"
celery = "^5.3.4"
apscheduler = "^3.10.4"

[tool.poetry.group.dev.dependencies]
pytest = "^8.0.0"
pytest-asyncio = "^0.23.0"
pytest-cov = "^4.1.0"
httpx = "^0.27.0"
black = "^24.1.0"
ruff = "^0.2.0"
mypy = "^1.8.0"
```

---

## Environment Setup

### 1. Create Project
```bash
# Create project directory
mkdir fastapi-clearinghouse
cd fastapi-clearinghouse

# Initialize Poetry
poetry init
poetry add fastapi uvicorn sqlalchemy asyncpg pydantic ...

# Create structure
mkdir -p app/{core,models,schemas,repositories,services,api/v1,background,utils}
touch app/__init__.py app/main.py app/config.py app/database.py
```

### 2. Environment Variables
```bash
# .env
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/clearinghouse
SECRET_KEY=your-secret-key-here
ACCESS_TOKEN_EXPIRE_MINUTES=60
SMTP_SERVER=mail.acc.umu.se
SMTP_PORT=587
REDIS_URL=redis://localhost:6379/0
DEBUG=true
```

### 3. Docker Setup
```yaml
# docker-compose.yml
version: '3.8'
services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
    depends_on:
      - db
      - redis
  
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: clearinghouse
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
  
  redis:
    image: redis:7-alpine
```

### 4. Run Development Server
```bash
# Install dependencies
poetry install

# Run migrations
poetry run alembic upgrade head

# Start server
poetry run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Access API docs
# http://localhost:8000/api/docs
```

---

## Testing Commands

```bash
# Run all tests
poetry run pytest

# Run with coverage
poetry run pytest --cov=app --cov-report=html

# Run specific test file
poetry run pytest tests/test_auth.py

# Run specific test
poetry run pytest tests/test_auth.py::test_login

# Run with verbose output
poetry run pytest -v -s
```

---

## Deployment Checklist

### Pre-deployment
- [ ] All tests passing
- [ ] Code coverage > 80%
- [ ] Security audit completed
- [ ] Performance testing done
- [ ] Documentation updated
- [ ] Environment variables configured
- [ ] Database migrations ready
- [ ] Backup strategy in place

### Deployment
- [ ] Deploy to staging
- [ ] Smoke tests on staging
- [ ] Performance tests on staging
- [ ] Deploy to production (parallel with PHP)
- [ ] Monitor error rates
- [ ] Monitor performance metrics
- [ ] Gradual traffic migration

### Post-deployment
- [ ] Monitor logs for 24-48 hours
- [ ] Verify all endpoints working
- [ ] Check database performance
- [ ] Validate email sending
- [ ] Reviews user feedback
- [ ] Plan PHP deprecation

---

## Common Issues & Solutions

### Issue: Async SQLAlchemy Sessions
**Problem:** Forgetting to use `await` with database operations  
**Solution:** Always use `await` with async functions, use `AsyncSession`

### Issue: Pydantic Validation Errors
**Problem:** Data doesn't match schema  
**Solution:** Use `model_validate()` for ORM objects, check field types

### Issue: JWT Token Expiration
**Problem:** Users getting logged out unexpectedly  
**Solution:** Implement token refresh endpoint, adjust expiration time

### Issue: Database Connection Pool Exhaustion
**Problem:** "Too many connections" error  
**Solution:** Configure pool size, use connection pooling properly

### Issue: Stored Procedure Calls
**Problem:** How to call PostgreSQL functions  
**Solution:** Use raw SQL with `db.execute("SELECT function_name(:param)", {"param": value})`

---

## Key Contacts & Resources

### Documentation
- FastAPI: https://fastapi.tiangolo.com/
- SQLAlchemy: https://docs.sqlalchemy.org/
- Pydantic: https://docs.pydantic.dev/
- Alembic: https://alembic.sqlalchemy.org/

### Project Resources
- Full Migration Plan: `./MIGRATION_PLAN_PHP_TO_FASTAPI.md`
- Current PHP API: `src/api/`
- Database Schema: `src/sql/`
- Tests: `Tests/`

---

## Next Steps

1. **Review full migration plan** in `MIGRATION_PLAN_PHP_TO_FASTAPI.md`
2. **Get stakeholder approval** for timeline and resources
3. **Set up POC environment** and test 3-5 core endpoints
4. **Assemble team** and assign roles
5. **Begin Phase 1** (Foundation & Infrastructure)

---

**Good Luck with the Migration! 🚀**
