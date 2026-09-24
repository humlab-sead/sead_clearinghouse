# SEAD Clearinghouse - PHP to Python/FastAPI Migration Plan

**Document Version:** 1.0  
**Date:** February 20, 2026  
**Status:** Planning Phase  
**Repository:** humlab-sead/sead_clearinghouse  
**Branch:** dev  

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current Architecture Analysis](#current-architecture-analysis)
3. [Proposed Python/FastAPI Architecture](#proposed-python-fastapi-architecture)
4. [Detailed Migration Phases](#detailed-migration-phases)
5. [Code Examples & Patterns](#code-examples--patterns)
6. [Migration Complexity Assessment](#migration-complexity-assessment)
7. [Timeline & Resource Estimation](#timeline--resource-estimation)
8. [Risk Mitigation](#risk-mitigation)
9. [Benefits Analysis](#benefits-analysis)
10. [Next Steps](#next-steps)

---

## Executive Summary

This document outlines a comprehensive plan to migrate the SEAD Clearinghouse API from PHP/Slim Framework to Python/FastAPI. The migration aims to improve performance, maintainability, and developer experience while maintaining backward compatibility with the existing PostgreSQL database schema.

### Current Stack
- **Framework:** PHP 7+ with Slim Framework 3.10
- **Database:** PostgreSQL with PDO
- **Architecture:** Service-Repository-Command pattern
- **Authentication:** PHP sessions
- **Dependencies:** PHPMailer, Monolog, NuSOAP

### Target Stack
- **Framework:** Python 3.11+ with FastAPI
- **ORM:** SQLAlchemy 2.0 (async)
- **Authentication:** JWT tokens
- **Validation:** Pydantic v2
- **Database Driver:** asyncpg
- **Migration Tool:** Alembic

### Key Metrics
- **Total Endpoints:** 30+
- **Service Classes:** 20+
- **Repository Classes:** 15+
- **Estimated Timeline:** 16-24 weeks
- **Team Size:** 2-3 developers + 1 QA

---

## Current Architecture Analysis

### Directory Structure

```
src/api/
├── Application/
│   ├── BootstrapService.php
│   ├── ClearingHouseCommand.php      # Command pattern base
│   ├── Main.php                      # Main controller
│   ├── Router.php                    # Slim routes
│   ├── Session.php                   # PHP session management
│   ├── config.php                    # Configuration (deprecated)
│   └── Services/
│       ├── LoginService.php
│       ├── SubmissionResultService.php
│       └── UploadService.php
├── InfraStructure/
│   ├── ConfigService.php             # Config from DB settings
│   ├── ConnectionFactory.php         # DB connection factory
│   ├── DatabaseConnection.php        # PDO wrapper
│   ├── DatabaseCallService.php       # Stored procedure calls
│   ├── ErrorHandler.php
│   ├── Log.php
│   └── MailService.php
├── Services/
│   ├── AcceptOrRejectService.php
│   ├── ActivityService.php           # Activity logging
│   ├── DataSetService.php
│   ├── EncryptPasswordService.php
│   ├── Locator.php                   # Service locator
│   ├── MailService.php
│   ├── ProcessService.php            # XML processing
│   ├── ReportService.php
│   ├── SecurityService.php           # RBAC
│   ├── SessionService.php
│   ├── SubmissionService.php
│   ├── UserService.php
│   └── Specification/                # Business rules
│       ├── CanAcceptSubmissionSpecification.php
│       ├── CanClaimSubmission.php
│       └── ... (12+ files)
├── Repository/
│   ├── RepositoryBase.php            # Base repository
│   ├── RepositoryRegistry.php        # Repository registry
│   ├── ActivityRepository.php
│   ├── DataSetRepository.php
│   ├── SubmissionRepository.php
│   ├── UserRepository.php
│   └── ... (15+ repositories)
├── Model/
│   ├── EntityBase.php
│   ├── Submission.php
│   ├── SubmissionFactory.php
│   └── User.php
├── autoload.php                      # Composer autoloader
├── index.php                         # Entry point (API)
└── process.php                       # Entry point (batch processing)
```

### Architecture Patterns

#### 1. Service Locator Pattern
```php
// Services/Locator.php
class Locator {
    protected $service_store = array();
    
    public function getService($class_name) {
        if (!array_key_exists($class_name, $this->service_store)) {
            $this->service_store[$class_name] = new $class_name();
        }
        return $this->service_store[$class_name];
    }
    
    public function getSubmissionService() {
        return $this->locate("\Services\SubmissionService");
    }
}
```

#### 2. Repository Pattern
```php
// Repository/RepositoryBase.php
class RepositoryBase {
    protected $con;              // PDO connection
    protected $table_name;
    protected $key_column_names;
    
    public function findById() { ... }
    public function save(&$entity, $affected_columns = NULL) { ... }
    public function deleteById() { ... }
    public function findAll() { ... }
}
```

#### 3. Command Pattern
```php
// Application/ClearingHouseCommand.php
class ClearingHouseCommand extends ServiceBase {
    public function execute($entity_id, $payload = null) {
        $activity = $this->registerStart($entity_id);
        try {
            $result = $this->executeCommand($entity_id, $payload);
            $this->registerStop($activity);
        } catch (Exception $ex) {
            $this->registerStop($activity, Activity_State_Error, $ex->getMessage());
            throw $ex;
        }
        return $result;
    }
}
```

#### 4. Specification Pattern
```php
// Services/Specification/CanClaimSubmission.php
class CanClaimSubmission implements Specification {
    public function IsSatisfiesBy($submission) {
        // Business logic validation
        return $submission['submission_state_id'] == State_Pending;
    }
}
```

### Current API Endpoints

#### Authentication
- `GET /login` - User login
- `GET /logout` - User logout

#### Users
- `GET /users` - List all users
- `GET /users/{user_id}` - Get user by ID
- `POST /users` - Create user
- `PUT /users` - Update user
- `DELETE /users/{user_id}` - Delete user

#### Submissions
- `GET /submissions` - List all submissions
- `GET /submissions_report` - Get submissions report
- `GET /submissions/{submission_id}` - Get submission details
- `GET /submissions/{submission_id}/sites` - Get submission sites
- `GET /submissions/{submission_id}/rejects` - Get rejection reasons
- `POST /submissions/{submission_id}/rejects` - Add rejection reason
- `PUT /submissions/{submission_id}/rejects/{reject_id}` - Update rejection
- `DELETE /submissions/{submission_id}/rejects/{reject_id}` - Delete rejection
- `GET /submissions/{submission_id}/process` - Process submission
- `GET /submissions/process_queue` - Process submission queue

#### Submission Actions
- `GET /submission/{submission_id}/claim` - Claim submission
- `GET /submission/{submission_id}/unclaim` - Unclaim submission
- `GET /submission/{submission_id}/transfer` - Transfer submission
- `GET /submission/{submission_id}/reject` - Reject submission
- `GET /submission/{submission_id}/accept` - Accept submission

#### Submission Data
- `GET /submission/{submission_id}/metadata` - Get metadata
- `GET /submission/{submission_id}/site/{site_id}` - Get site model
- `GET /submission/{submission_id}/site/{site_id}/sample_group/{sample_group_id}` - Get sample group
- `GET /submission/{submission_id}/site/{site_id}/sample_group/{sample_group_id}/sample/{sample_id}` - Get sample
- `GET /submission/{submission_id}/site/{site_id}/sample_group/{sample_group_id}/dataset/{dataset_id}` - Get dataset

#### Reports
- `GET /reports/toc` - Get reports table of contents
- `GET /reports/execute/{report_id}/{submission_id}` - Execute report
- `GET /submission/{submission_id}/tables` - Get submission tables
- `GET /submission/{submission_id}/table/{table_id}` - Get table content

#### System
- `GET /bootstrap` - Bootstrap data
- `GET /helloworld` - Health check
- `GET /nag` - Send reminder emails

### Database Configuration

**Environment Variables:**
```bash
CH_DATABASE=clearinghouse_db
CH_HOST=localhost
CH_PORT=5432
CH_USER=clearinghouse_user
CH_PASSWORD=***
```

**Fallback:** `/etc/.pgpass.env` file

### Key Database Tables

```
clearing_house.tbl_clearinghouse_users
clearing_house.tbl_clearinghouse_submissions
clearing_house.tbl_clearinghouse_submission_states
clearing_house.tbl_clearinghouse_submission_tables
clearing_house.tbl_clearinghouse_submission_rejects
clearing_house.tbl_clearinghouse_sessions
clearing_house.tbl_clearinghouse_activity
clearing_house.tbl_clearinghouse_settings
clearing_house.tbl_sites
clearing_house.tbl_sample_groups
clearing_house.tbl_datasets
```

### Key Stored Procedures

```sql
clearing_house.fn_explode_submission_xml_to_rdb(submission_id)
-- Converts uploaded XML into relational tables
```

---

## Proposed Python/FastAPI Architecture

### Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Web Framework | FastAPI | 0.110+ | Async REST API |
| ORM | SQLAlchemy | 2.0+ | Database ORM |
| Validation | Pydantic | 2.6+ | Data validation |
| DB Driver | asyncpg | 0.29+ | Async PostgreSQL |
| Auth | python-jose | 3.3+ | JWT handling |
| Password | passlib | 1.7+ | Password hashing |
| Email | aiosmtplib | 3.0+ | Async email |
| Cache | aiocache | 0.12+ | Redis caching |
| Migrations | Alembic | 1.13+ | DB migrations |
| Testing | pytest | 8.0+ | Testing framework |
| HTTP Client | httpx | 0.27+ | Async HTTP client |
| Task Queue | Celery | 5.3+ | Background jobs (optional) |
| Scheduler | APScheduler | 3.10+ | Scheduled tasks (optional) |

### Project Structure

```
fastapi-clearinghouse/
├── app/
│   ├── __init__.py
│   ├── main.py                      # FastAPI application
│   ├── config.py                    # Settings (Pydantic)
│   ├── database.py                  # DB session & engine
│   ├── dependencies.py              # DI container
│   │
│   ├── core/                        # Core utilities
│   │   ├── __init__.py
│   │   ├── security.py              # JWT, password hashing, RBAC
│   │   ├── logging.py               # Structured logging
│   │   ├── exceptions.py            # Custom exceptions
│   │   └── cache.py                 # Cache utilities
│   │
│   ├── models/                      # SQLAlchemy ORM models
│   │   ├── __init__.py
│   │   ├── base.py                  # Base model
│   │   ├── user.py                  # User model
│   │   ├── submission.py            # Submission model
│   │   ├── site.py                  # Site model
│   │   ├── sample.py                # Sample model
│   │   ├── dataset.py               # Dataset model
│   │   ├── session.py               # Session model (legacy)
│   │   └── activity.py              # Activity log model
│   │
│   ├── schemas/                     # Pydantic schemas
│   │   ├── __init__.py
│   │   ├── user.py                  # UserCreate, UserUpdate, UserResponse
│   │   ├── submission.py            # Submission schemas
│   │   ├── auth.py                  # Token, Login schemas
│   │   └── ...
│   │
│   ├── repositories/                # Data access layer
│   │   ├── __init__.py
│   │   ├── base.py                  # Generic repository
│   │   ├── user.py                  # UserRepository
│   │   ├── submission.py            # SubmissionRepository
│   │   ├── site.py
│   │   ├── sample.py
│   │   ├── dataset.py
│   │   └── activity.py
│   │
│   ├── services/                    # Business logic layer
│   │   ├── __init__.py
│   │   ├── base.py                  # Base service
│   │   ├── auth.py                  # Authentication service
│   │   ├── user.py                  # User service
│   │   ├── submission.py            # Submission service
│   │   ├── processor.py             # XML processing service
│   │   ├── email.py                 # Email service
│   │   ├── report.py                # Report generation
│   │   └── activity.py              # Activity logging
│   │
│   ├── api/                         # API routes
│   │   ├── __init__.py
│   │   ├── deps.py                  # Shared dependencies
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── auth.py              # Auth endpoints
│   │       ├── users.py             # User CRUD
│   │       ├── submissions.py       # Submission endpoints
│   │       ├── sites.py             # Site endpoints
│   │       ├── samples.py           # Sample endpoints
│   │       ├── datasets.py          # Dataset endpoints
│   │       └── reports.py           # Report endpoints
│   │
│   ├── background/                  # Background tasks
│   │   ├── __init__.py
│   │   ├── celery_app.py           # Celery configuration
│   │   ├── processor.py            # Submission processing
│   │   └── scheduler.py            # Scheduled tasks
│   │
│   └── utils/                       # Utility functions
│       ├── __init__.py
│       ├── xml_parser.py           # XML processing
│       └── validators.py           # Custom validators
│
├── tests/                           # Test suite
│   ├── __init__.py
│   ├── conftest.py                 # Pytest fixtures
│   ├── test_auth.py
│   ├── test_users.py
│   ├── test_submissions.py
│   └── ...
│
├── alembic/                         # Database migrations
│   ├── versions/
│   ├── env.py
│   └── script.py.mako
│
├── docs/                            # Documentation
│   ├── api.md                      # API documentation
│   ├── deployment.md               # Deployment guide
│   └── development.md              # Development setup
│
├── .env.example                     # Environment template
├── .gitignore
├── docker-compose.yml              # Docker setup
├── Dockerfile                      # Application container
├── pyproject.toml                  # Poetry dependencies
├── poetry.lock
└── README.md
```

---

## Detailed Migration Phases

### Phase 1: Foundation & Infrastructure (4-6 weeks)

**Objective:** Set up the basic project structure, configuration, and database connectivity.

#### Tasks:

1. **Project Bootstrap (Week 1)**
   - Initialize Python project with Poetry
   - Set up directory structure
   - Configure development tools (black, mypy, ruff)
   - Set up pre-commit hooks
   - Create Docker development environment

2. **Configuration Management (Week 1)**
   - Implement settings using Pydantic
   - Environment variable handling
   - Database configuration
   - Logging configuration

3. **Database Setup (Week 2)**
   - Configure SQLAlchemy async engine
   - Create base models
   - Set up Alembic for migrations
   - Connection pooling
   - Health check endpoints

4. **Error Handling & Logging (Week 1)**
   - Custom exception classes
   - Global exception handlers
   - Structured logging setup
   - Error tracking integration

5. **Development Tools (Week 1-2)**
   - Docker Compose for local dev
   - pytest configuration
   - API documentation setup
   - CI/CD pipeline basics

#### Deliverables:
- ✅ Working FastAPI application skeleton
- ✅ Database connection established
- ✅ Basic health check endpoint
- ✅ Development environment ready
- ✅ Documentation structure

---

### Phase 2: Authentication & Authorization (2-3 weeks)

**Objective:** Implement JWT-based authentication to replace PHP sessions and role-based access control.

#### Tasks:

1. **JWT Authentication (Week 1)**
   - JWT token generation and validation
   - OAuth2 password flow
   - Token refresh mechanism
   - Password hashing with bcrypt

2. **User Model & Repository (Week 1)**
   - SQLAlchemy User model
   - Pydantic user schemas
   - User repository with CRUD operations
   - Password validation rules

3. **Role-Based Access Control (Week 2)**
   - Permission system (matches SecurityService.php)
   - Role definitions (Administrator, Normal, Reader)
   - Permission decorators
   - User context in requests

4. **Auth Endpoints (Week 2)**
   - POST /api/v1/auth/login
   - POST /api/v1/auth/logout
   - GET /api/v1/auth/me (current user)
   - POST /api/v1/auth/refresh

5. **Session Migration Strategy**
   - Parallel support for PHP sessions (temporary)
   - JWT token in cookies or headers
   - Session to JWT bridge (if needed)

#### Deliverables:
- ✅ JWT authentication working
- ✅ User CRUD operations
- ✅ Permission system implemented
- ✅ Auth endpoints tested
- ✅ Frontend can authenticate

---

### Phase 3: Core Models & Schemas (3-4 weeks)

**Objective:** Create SQLAlchemy models and Pydantic schemas for all major database tables.

#### Models to Implement:

1. **Week 1: User & Session**
   - `models/user.py` - User model
   - `models/session.py` - Session model (if kept)
   - `models/activity.py` - Activity log model

2. **Week 2: Submission**
   - `models/submission.py` - Main submission model
   - `models/submission_state.py` - Submission states
   - `models/submission_reject.py` - Rejection reasons
   - `models/submission_table.py` - Table metadata

3. **Week 3: Site & Sample**
   - `models/site.py` - Site model
   - `models/sample_group.py` - Sample group model
   - `models/sample.py` - Sample model

4. **Week 4: Dataset & Reports**
   - `models/dataset.py` - Dataset model
   - `models/report.py` - Report definitions
   - `models/setting.py` - System settings

#### Pydantic Schemas Pattern:

```python
# For each model, create:
# - Base schema (shared fields)
# - Create schema (for POST)
# - Update schema (for PUT/PATCH)
# - Response schema (for GET)
# - InDB schema (internal use)
```

#### Deliverables:
- ✅ All SQLAlchemy models created
- ✅ All Pydantic schemas defined
- ✅ Model relationships configured
- ✅ Database migrations created
- ✅ Model tests written

---

### Phase 4: Repository Layer (3-4 weeks)

**Objective:** Implement data access layer with repositories for all models.

#### Generic Repository Pattern:

```python
class BaseRepository(Generic[ModelType]):
    async def get_by_id(db: AsyncSession, id: int) -> Optional[ModelType]
    async def get_all(db: AsyncSession, skip: int = 0, limit: int = 100) -> List[ModelType]
    async def create(db: AsyncSession, obj_in: dict) -> ModelType
    async def update(db: AsyncSession, db_obj: ModelType, obj_in: dict) -> ModelType
    async def delete(db: AsyncSession, id: int) -> bool
```

#### Repositories to Implement:

1. **Week 1**
   - `UserRepository` - 15+ methods
   - `SessionRepository` - 8+ methods
   - `ActivityRepository` - 10+ methods

2. **Week 2**
   - `SubmissionRepository` - 20+ methods
   - `SubmissionRejectRepository` - 8+ methods
   - `AcceptedQueueRepository` - 5+ methods

3. **Week 3**
   - `SiteRepository` - 10+ methods
   - `SampleGroupRepository` - 10+ methods
   - `SampleRepository` - 10+ methods

4. **Week 4**
   - `DataSetRepository` - 10+ methods
   - `ReportRepository` - 12+ methods
   - `SettingRepository` - 8+ methods
   - `SignalRepository` - 6+ methods

#### Special Considerations:

- **Complex Queries:** Some repositories have complex SQL
- **Stored Procedures:** Call PostgreSQL functions where needed
- **Caching:** Implement cache decorators
- **Transactions:** Proper transaction handling

#### Deliverables:
- ✅ All repositories implemented
- ✅ Repository tests with fixtures
- ✅ Query optimization done
- ✅ Stored procedure calls working

---

### Phase 5: Service Layer (4-5 weeks)

**Objective:** Implement business logic layer mirroring PHP services.

#### Services to Implement:

1. **Week 1: Core Services**
   - `AuthService` - Authentication logic
   - `UserService` - User management
   - `ActivityService` - Activity logging
   - `SecurityService` - Permission checks

2. **Week 2: Submission Services**
   - `SubmissionService` - Main submission logic
   - `ProcessService` - XML processing
   - `DecodeService` - Content decoding
   - `AcceptOrRejectService` - Accept/reject workflow

3. **Week 3: Data Services**
   - `SiteService` - Site operations
   - `SampleGroupService` - Sample group operations
   - `SampleService` - Sample operations
   - `DataSetService` - Dataset operations

4. **Week 4: Supporting Services**
   - `EmailService` - Email notifications
   - `ReportService` - Report generation
   - `TransferService` - Submission transfer
   - `ReminderService` - Reminder emails

5. **Week 5: Specialized Services**
   - `XMLProcessorService` - XML to RDB conversion
   - `SignalService` - Event signaling
   - `MailTemplateService` - Email templates

#### Business Rules (Specifications):

Rather than separate Specification classes, implement as methods:

```python
class SubmissionService:
    def can_claim(self, submission: Submission, user: User) -> tuple[bool, str]:
        """Check if user can claim submission"""
        if submission.claim_user_id:
            return False, "Already claimed"
        if submission.submission_state_id != State.PENDING:
            return False, "Not in claimable state"
        return True, ""
```

#### Deliverables:
- ✅ All services implemented
- ✅ Business rules enforced
- ✅ Service tests with mocks
- ✅ Documentation updated

---

### Phase 6: API Routes (4-5 weeks)

**Objective:** Implement all REST API endpoints.

#### Endpoint Groups:

1. **Week 1: Authentication & Users**
   - `api/v1/auth.py` - 4 endpoints
   - `api/v1/users.py` - 5 endpoints

2. **Week 2: Submissions (Core)**
   - `api/v1/submissions.py` - 10 endpoints
   - Submission CRUD
   - Submission sites
   - Submission rejects

3. **Week 3: Submission Actions**
   - Claim/Unclaim
   - Accept/Reject
   - Transfer
   - Process

4. **Week 4: Data Endpoints**
   - `api/v1/sites.py` - 3 endpoints
   - `api/v1/samples.py` - 4 endpoints
   - `api/v1/datasets.py` - 3 endpoints

5. **Week 5: Reports & System**
   - `api/v1/reports.py` - 5 endpoints
   - System bootstrap endpoint
   - Health checks

#### API Standards:

- RESTful design
- Consistent error responses
- Pagination where appropriate
- OpenAPI documentation
- Request validation
- Response models

#### Testing:

- Integration tests for each endpoint
- Authentication tests
- Permission tests
- Error case tests

#### Deliverables:
- ✅ All 30+ endpoints implemented
- ✅ OpenAPI docs generated
- ✅ Integration tests passing
- ✅ Postman collection created

---

### Phase 7: Background Tasks & Processing (2-3 weeks)

**Objective:** Implement batch processing and scheduled tasks.

#### Options Evaluated:

**Option A: FastAPI BackgroundTasks** (Simple, built-in)
- Good for: Quick async tasks
- Limitations: No retry, no monitoring
- Use case: Simple notifications

**Option B: Celery** (Production-grade)
- Good for: Complex workflows, retries
- Requirements: Redis/RabbitMQ broker
- Use case: Submission processing

**Option C: APScheduler** (Cron-like)
- Good for: Scheduled tasks
- Use case: Reminder emails, cleanup

**Recommended:** Combine B + C

#### Tasks to Implement:

1. **Week 1: Celery Setup**
   - Configure Celery worker
   - Redis broker setup
   - Task monitoring (Flower)
   - Error handling

2. **Week 2: Processing Tasks**
   - `process_submission_queue` - Main batch processor
   - `process_single_submission` - Individual processing
   - `decode_xml_content` - XML decoding
   - `explode_xml_to_rdb` - RDB conversion

3. **Week 3: Scheduled Tasks**
   - `send_reminder_emails` - Daily reminders
   - `cleanup_old_sessions` - Session cleanup
   - `generate_reports` - Scheduled reports

#### CLI Commands:

```bash
# Start Celery worker
celery -A app.background.celery_app worker --loglevel=info

# Start scheduler
python -m app.background.scheduler

# Process queue manually
python -m app.background.processor
```

#### Deliverables:
- ✅ Celery configured and working
- ✅ Background tasks implemented
- ✅ Scheduler running
- ✅ Monitoring dashboard

---

### Phase 8: Email & External Services (1-2 weeks)

**Objective:** Implement email notifications and external service integrations.

#### Email Service Implementation:

1. **Week 1: Email Infrastructure**
   - SMTP configuration
   - HTML email templates (Jinja2)
   - Async sending with aiosmtplib
   - Email queuing

2. **Week 2: Email Types**
   - Welcome emails
   - Submission notifications
   - Reminder emails
   - Error notifications
   - Password reset (if needed)

#### Template System:

```python
# Use Jinja2 for templates
templates/
├── email/
│   ├── base.html
│   ├── submission_claimed.html
│   ├── submission_accepted.html
│   ├── submission_rejected.html
│   └── reminder.html
```

#### Deliverables:
- ✅ Email service working
- ✅ All email templates created
- ✅ Email tests with mock SMTP
- ✅ Email logs/tracking

---

### Phase 9: Caching (1-2 weeks)

**Objective:** Implement caching for performance optimization.

#### Caching Strategy:

1. **Redis Setup**
   - Redis server configuration
   - aiocache integration
   - Cache key naming convention

2. **What to Cache:**
   - Bootstrap data (1 hour TTL)
   - User permissions (session lifetime)
   - Submission metadata (5 minutes)
   - Report results (configurable)
   - Settings (1 hour)

3. **Cache Patterns:**
   ```python
   # Cache-aside pattern
   async def get_submission(submission_id: int):
       cache_key = f"submission:{submission_id}"
       cached = await cache.get(cache_key)
       if cached:
           return cached
       
       submission = await repo.get_by_id(db, submission_id)
       await cache.set(cache_key, submission, ttl=300)
       return submission
   ```

4. **Cache Invalidation:**
   - On submission update
   - On user permission change
   - On settings change

#### Deliverables:
- ✅ Redis configured
- ✅ Cache decorators created
- ✅ Key APIs cached
- ✅ Cache tests written

---

### Phase 10: Testing (Ongoing, 3-4 weeks)

**Objective:** Comprehensive test coverage for all components.

#### Test Categories:

1. **Unit Tests** (Target: 80% coverage)
   - Models
   - Repositories
   - Services
   - Utilities

2. **Integration Tests**
   - API endpoints
   - Database operations
   - Authentication flow

3. **End-to-End Tests**
   - Complete user workflows
   - Submission processing pipeline
   - Report generation

#### Test Infrastructure:

```python
# conftest.py
@pytest.fixture
async def test_db():
    """Create test database"""
    
@pytest.fixture
async def client():
    """Test API client"""
    
@pytest.fixture
async def auth_token():
    """Authenticated user token"""
    
@pytest.fixture
async def test_submission():
    """Sample submission for testing"""
```

#### Testing Tools:

- pytest - Test runner
- pytest-asyncio - Async test support
- pytest-cov - Coverage reporting
- httpx - Async HTTP client
- faker - Test data generation
- factory_boy - Model factories

#### Deliverables:
- ✅ 80%+ code coverage
- ✅ All endpoints tested
- ✅ CI/CD running tests
- ✅ Test documentation

---

## Code Examples & Patterns

### 1. Configuration (`app/config.py`)

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache

class Settings(BaseSettings):
    # Application
    app_name: str = "SEAD Clearinghouse API"
    app_version: str = "2.0.0"
    debug: bool = False
    
    # Database
    database_url: str
    db_pool_size: int = 10
    db_max_overflow: int = 20
    db_echo: bool = False
    
    # Authentication
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    
    # Email
    smtp_server: str = "localhost"
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from: str = "noreply@sead.org"
    smtp_from_name: str = "SEAD Clearing House"
    
    # Redis
    redis_url: str = "redis://localhost:6379/0"
    cache_ttl: int = 3600
    
    # CORS
    cors_origins: list[str] = ["http://localhost:3000"]
    
    # Logging
    log_level: str = "INFO"
    log_file: str = "/tmp/clearinghouse.log"
    
    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
        extra="ignore"
    )

@lru_cache()
def get_settings() -> Settings:
    return Settings()
```

### 2. Database Setup (`app/database.py`)

```python
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    create_async_engine,
    async_sessionmaker,
)
from sqlalchemy.orm import declarative_base
from typing import AsyncGenerator
from app.config import get_settings

settings = get_settings()

# Create async engine
engine: AsyncEngine = create_async_engine(
    settings.database_url,
    echo=settings.db_echo,
    pool_size=settings.db_pool_size,
    max_overflow=settings.db_max_overflow,
    pool_pre_ping=True,
    pool_recycle=3600,
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)

# Base class for models
Base = declarative_base()

# Dependency for FastAPI routes
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
```

### 3. User Model (`app/models/user.py`)

```python
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class User(Base):
    __tablename__ = "tbl_clearinghouse_users"
    __table_args__ = {"schema": "clearing_house"}
    
    user_id = Column(Integer, primary_key=True, index=True)
    user_name = Column(String(40), unique=True, nullable=False, index=True)
    first_name = Column(String(40))
    last_name = Column(String(60))
    email = Column(String(191), unique=True, nullable=False, index=True)
    password = Column(String(255), nullable=False)
    role_id = Column(Integer, nullable=False, default=0)
    is_active = Column(Boolean, default=True)
    is_data_provider = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    submitted_submissions = relationship(
        "Submission",
        foreign_keys="Submission.upload_user_id",
        back_populates="uploader"
    )
    claimed_submissions = relationship(
        "Submission",
        foreign_keys="Submission.claim_user_id",
        back_populates="claimer"
    )
    
    def __repr__(self):
        return f"<User(id={self.user_id}, username={self.user_name})>"
```

### 4. User Schemas (`app/schemas/user.py`)

```python
from pydantic import BaseModel, EmailStr, Field, ConfigDict
from typing import Optional
from datetime import datetime

class UserBase(BaseModel):
    user_name: str = Field(..., min_length=3, max_length=40)
    email: EmailStr
    first_name: Optional[str] = Field(None, max_length=40)
    last_name: Optional[str] = Field(None, max_length=60)
    role_id: int = Field(default=0, ge=0, le=3)
    is_active: bool = True
    is_data_provider: bool = False

class UserCreate(UserBase):
    password: str = Field(..., min_length=8)

class UserUpdate(BaseModel):
    user_name: Optional[str] = Field(None, min_length=3, max_length=40)
    email: Optional[EmailStr] = None
    first_name: Optional[str] = Field(None, max_length=40)
    last_name: Optional[str] = Field(None, max_length=60)
    password: Optional[str] = Field(None, min_length=8)
    role_id: Optional[int] = Field(None, ge=0, le=3)
    is_active: Optional[bool] = None
    is_data_provider: Optional[bool] = None

class UserResponse(UserBase):
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    model_config = ConfigDict(from_attributes=True)

class UserInDB(UserResponse):
    password: str
```

### 5. Security & Auth (`app/core/security.py`)

```python
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.models.user import User
from app.repositories.user import UserRepository

settings = get_settings()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

class UserRole:
    UNDEFINED = 0
    READER = 1
    NORMAL = 2
    ADMINISTRATOR = 3

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.access_token_expire_minutes)
    
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user_repo = UserRepository()
    user = await user_repo.get_by_id(db, int(user_id))
    
    if user is None:
        raise credentials_exception
    
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    
    return user

class Permission:
    """User permissions based on role"""
    
    def __init__(self, user: User):
        self.user = user
        self.is_admin = user.role_id == UserRole.ADMINISTRATOR
        self.is_normal = user.role_id == UserRole.NORMAL
        self.is_readonly = user.role_id == UserRole.READER
        self.is_undefined = user.role_id == UserRole.UNDEFINED
    
    @property
    def can_view_submissions(self) -> bool:
        return not self.is_undefined
    
    @property
    def can_edit_submissions(self) -> bool:
        return self.is_normal or self.is_admin
    
    @property
    def can_accept_submissions(self) -> bool:
        return self.is_normal or self.is_admin
    
    @property
    def can_reject_submissions(self) -> bool:
        return self.is_normal or self.is_admin
    
    @property
    def can_claim_submissions(self) -> bool:
        return self.is_normal or self.is_admin
    
    @property
    def can_unclaim_submissions(self) -> bool:
        return self.is_normal or self.is_admin
    
    @property
    def can_transfer_submissions(self) -> bool:
        return self.is_admin
    
    @property
    def can_edit_users(self) -> bool:
        return self.is_admin
    
    def to_dict(self) -> dict:
        return {
            "user_is_administrator": self.is_admin,
            "user_is_normal": self.is_normal,
            "user_is_readonly": self.is_readonly,
            "user_is_data_provider": self.user.is_data_provider,
            "has_view_submission_privilage": self.can_view_submissions,
            "has_edit_submission_privilage": self.can_edit_submissions,
            "has_accept_submission_privilage": self.can_accept_submissions,
            "has_reject_submission_privilage": self.can_reject_submissions,
            "has_claim_submission_privilage": self.can_claim_submissions,
            "has_unclaim_submission_privilage": self.can_unclaim_submissions,
            "has_transfer_submission_privilage": self.can_transfer_submissions,
            "has_edit_user_privilage": self.can_edit_users,
        }

def require_permission(check_func):
    """Decorator to require specific permission"""
    def decorator(func):
        async def wrapper(*args, current_user: User = Depends(get_current_user), **kwargs):
            perms = Permission(current_user)
            if not check_func(perms):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Insufficient permissions"
                )
            return await func(*args, current_user=current_user, **kwargs)
        return wrapper
    return decorator
```

### 6. Base Repository (`app/repositories/base.py`)

```python
from typing import Generic, TypeVar, Type, Optional, List, Any
from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import Base

ModelType = TypeVar("ModelType", bound=Base)

class BaseRepository(Generic[ModelType]):
    def __init__(self, model: Type[ModelType]):
        self.model = model
    
    async def get_by_id(self, db: AsyncSession, id: Any) -> Optional[ModelType]:
        result = await db.execute(
            select(self.model).where(self.model.id == id)
        )
        return result.scalar_one_or_none()
    
    async def get_all(
        self,
        db: AsyncSession,
        skip: int = 0,
        limit: int = 100
    ) -> List[ModelType]:
        result = await db.execute(
            select(self.model).offset(skip).limit(limit)
        )
        return list(result.scalars().all())
    
    async def create(self, db: AsyncSession, obj_in: dict) -> ModelType:
        db_obj = self.model(**obj_in)
        db.add(db_obj)
        await db.flush()
        await db.refresh(db_obj)
        return db_obj
    
    async def update(
        self,
        db: AsyncSession,
        db_obj: ModelType,
        obj_in: dict
    ) -> ModelType:
        for field, value in obj_in.items():
            if hasattr(db_obj, field):
                setattr(db_obj, field, value)
        await db.flush()
        await db.refresh(db_obj)
        return db_obj
    
    async def delete(self, db: AsyncSession, id: Any) -> bool:
        obj = await self.get_by_id(db, id)
        if obj:
            await db.delete(obj)
            await db.flush()
            return True
        return False
    
    async def find_by(
        self,
        db: AsyncSession,
        filters: dict,
        skip: int = 0,
        limit: int = 100
    ) -> List[ModelType]:
        query = select(self.model)
        for field, value in filters.items():
            if hasattr(self.model, field):
                query = query.where(getattr(self.model, field) == value)
        query = query.offset(skip).limit(limit)
        result = await db.execute(query)
        return list(result.scalars().all())
```

### 7. Submission Repository (`app/repositories/submission.py`)

```python
from typing import List, Optional
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.submission import Submission
from app.repositories.base import BaseRepository

class SubmissionRepository(BaseRepository[Submission]):
    def __init__(self):
        super().__init__(Submission)
    
    async def get_by_id(self, db: AsyncSession, submission_id: int) -> Optional[Submission]:
        result = await db.execute(
            select(self.model).where(self.model.submission_id == submission_id)
        )
        return result.scalar_one_or_none()
    
    async def get_with_relations(
        self,
        db: AsyncSession,
        submission_id: int
    ) -> Optional[Submission]:
        result = await db.execute(
            select(self.model)
            .options(
                selectinload(self.model.data_provider),
                selectinload(self.model.uploader),
                selectinload(self.model.claimer),
                selectinload(self.model.sites)
            )
            .where(self.model.submission_id == submission_id)
        )
        return result.scalar_one_or_none()
    
    async def get_all_new(self, db: AsyncSession) -> List[Submission]:
        """Get submissions in NEW state (state_id = 1)"""
        result = await db.execute(
            select(self.model).where(self.model.submission_state_id == 1)
        )
        return list(result.scalars().all())
    
    async def get_all_pending(self, db: AsyncSession) -> List[Submission]:
        """Get submissions in PENDING state (state_id = 2)"""
        result = await db.execute(
            select(self.model).where(self.model.submission_state_id == 2)
        )
        return list(result.scalars().all())
    
    async def find_by_state(
        self,
        db: AsyncSession,
        state_id: int,
        skip: int = 0,
        limit: int = 100
    ) -> List[Submission]:
        result = await db.execute(
            select(self.model)
            .where(self.model.submission_state_id == state_id)
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())
    
    async def explode_xml_to_rdb(
        self,
        db: AsyncSession,
        submission_id: int
    ) -> None:
        """Call stored procedure to explode XML to relational tables"""
        await db.execute(
            "SELECT clearing_house.fn_explode_submission_xml_to_rdb(:submission_id)",
            {"submission_id": submission_id}
        )
```

### 8. Submission Service (`app/services/submission.py`)

```python
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from app.models.submission import Submission
from app.models.user import User
from app.repositories.submission import SubmissionRepository
from app.schemas.submission import SubmissionCreate, SubmissionUpdate

class SubmissionService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = SubmissionRepository()
    
    async def get_all_submissions(
        self,
        skip: int = 0,
        limit: int = 100
    ) -> List[Submission]:
        return await self.repo.get_all(self.db, skip, limit)
    
    async def get_submission(self, submission_id: int) -> Submission:
        submission = await self.repo.get_with_relations(self.db, submission_id)
        if not submission:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Submission {submission_id} not found"
            )
        return submission
    
    async def claim_submission(
        self,
        submission_id: int,
        user: User
    ) -> Submission:
        submission = await self.get_submission(submission_id)
        
        # Business rules
        if submission.claim_user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Submission already claimed"
            )
        
        if submission.submission_state_id != 2:  # PENDING
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Submission not in claimable state"
            )
        
        # Claim it
        submission.claim_user_id = user.user_id
        await self.db.flush()
        await self.db.refresh(submission)
        
        return submission
    
    async def unclaim_submission(
        self,
        submission_id: int,
        user: User
    ) -> Submission:
        submission = await self.get_submission(submission_id)
        
        if not submission.claim_user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Submission not claimed"
            )
        
        # Only owner or admin can unclaim
        if submission.claim_user_id != user.user_id and user.role_id != 3:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot unclaim submission claimed by another user"
            )
        
        submission.claim_user_id = None
        await self.db.flush()
        await self.db.refresh(submission)
        
        return submission
    
    async def process_submission(self, submission_id: int) -> dict:
        """Process submission: decode XML and explode to RDB"""
        submission = await self.get_submission(submission_id)
        
        # Check if can process
        if submission.submission_state_id != 1:  # NEW
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only NEW submissions can be processed"
            )
        
        # Decode XML if needed
        if submission.upload_content and not submission.xml:
            from app.utils.xml_parser import decode_xml
            submission.xml = decode_xml(submission.upload_content)
            await self.db.flush()
        
        # Explode XML to RDB
        if submission.xml:
            await self.repo.explode_xml_to_rdb(self.db, submission_id)
        
        # Update state to PENDING
        submission.submission_state_id = 2
        await self.db.flush()
        await self.db.refresh(submission)
        
        return {
            "status": "success",
            "submission_id": submission_id,
            "message": "Submission processed successfully"
        }
```

### 9. Auth Endpoints (`app/api/v1/auth.py`)

```python
from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.security import (
    create_access_token,
    verify_password,
    get_current_user,
    Permission,
)
from app.config import get_settings
from app.schemas.auth import Token, LoginRequest
from app.schemas.user import UserResponse
from app.repositories.user import UserRepository
from app.models.user import User

settings = get_settings()
router = APIRouter(prefix="/auth", tags=["authentication"])

@router.post("/login", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    """Authenticate user and return JWT token"""
    user_repo = UserRepository()
    
    # Find user by username
    user = await user_repo.get_by_username(db, form_data.username)
    
    if not user or not verify_password(form_data.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": str(user.user_id)},
        expires_delta=access_token_expires
    )
    
    # Get permissions
    permissions = Permission(user).to_dict()
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user,
        "permissions": permissions
    }

@router.post("/logout")
async def logout(current_user: User = Depends(get_current_user)):
    """Logout (client should discard token)"""
    return {
        "status": "success",
        "message": "Logged out successfully"
    }

@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current authenticated user info"""
    return current_user
```

### 10. Submission Endpoints (`app/api/v1/submissions.py`)

```python
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.core.security import get_current_user, require_permission, Permission
from app.models.user import User
from app.schemas.submission import (
    SubmissionResponse,
    SubmissionCreate,
    SubmissionUpdate
)
from app.services.submission import SubmissionService

router = APIRouter(prefix="/submissions", tags=["submissions"])

@router.get("/", response_model=List[SubmissionResponse])
async def get_submissions(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all submissions"""
    # Check permission
    perms = Permission(current_user)
    if not perms.can_view_submissions:
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    
    service = SubmissionService(db)
    submissions = await service.get_all_submissions(skip, limit)
    return submissions

@router.get("/{submission_id}", response_model=SubmissionResponse)
async def get_submission(
    submission_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get a specific submission by ID"""
    service = SubmissionService(db)
    return await service.get_submission(submission_id)

@router.post("/{submission_id}/claim", response_model=SubmissionResponse)
async def claim_submission(
    submission_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Claim a submission"""
    perms = Permission(current_user)
    if not perms.can_claim_submissions:
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    
    service = SubmissionService(db)
    return await service.claim_submission(submission_id, current_user)

@router.post("/{submission_id}/unclaim", response_model=SubmissionResponse)
async def unclaim_submission(
    submission_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Unclaim a submission"""
    perms = Permission(current_user)
    if not perms.can_unclaim_submissions:
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    
    service = SubmissionService(db)
    return await service.unclaim_submission(submission_id, current_user)

@router.post("/{submission_id}/process")
async def process_submission(
    submission_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Process a submission (decode XML, explode to RDB)"""
    perms = Permission(current_user)
    if not perms.can_edit_submissions:
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    
    service = SubmissionService(db)
    return await service.process_submission(submission_id)
```

### 11. Main Application (`app/main.py`)

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from app.config import get_settings
from app.database import engine
from app.api.v1 import auth, users, submissions, sites, samples, datasets, reports

settings = get_settings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("Starting up...")
    yield
    # Shutdown
    print("Shutting down...")
    await engine.dispose()

# Create FastAPI application
app = FastAPI(
    title="SEAD Clearinghouse API",
    description="Python/FastAPI migration of SEAD Clearinghouse",
    version="2.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
    lifespan=lifespan
)

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Include routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(submissions.router, prefix="/api/v1")
app.include_router(sites.router, prefix="/api/v1")
app.include_router(samples.router, prefix="/api/v1")
app.include_router(datasets.router, prefix="/api/v1")
app.include_router(reports.router, prefix="/api/v1")

# Root endpoints
@app.get("/")
async def root():
    return {
        "message": "SEAD Clearinghouse API",
        "version": "2.0.0",
        "docs": "/api/docs"
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.get("/api/v1/bootstrap")
async def bootstrap():
    """Bootstrap data for frontend initialization"""
    # TODO: Implement bootstrap data logic
    return {
        "settings": {},
        "lookup_tables": {},
        "user_roles": {}
    }
```

---

## Migration Complexity Assessment

### High Complexity Items (Total: ~15 days)

| Item | Complexity | Estimated Time | Notes |
|------|-----------|----------------|-------|
| XML Processing to RDB | Very High | 5 days | Complex stored procedure logic |
| Command Pattern with Activity Logging | High | 3 days | Every action needs logging |
| Specification Pattern Migration | Medium-High | 2 days | 12+ business rule classes |
| Report Generation System | High | 3 days | Dynamic SQL, multiple formats |
| Session to JWT Migration | Medium-High | 2 days | Frontend integration needed |

### Medium Complexity Items (Total: ~12 days)

| Item | Complexity | Estimated Time | Notes |
|------|-----------|----------------|-------|
| Repository Layer (15+ repos) | Medium | 4 days | Pattern is consistent |
| Service Layer (20+ services) | Medium | 5 days | Business logic migration |
| Email Service Integration | Medium | 2 days | Templates, async sending |
| File Upload Processing | Medium | 1 day | XML validation |

### Low Complexity Items (Total: ~8 days)

| Item | Complexity | Estimated Time | Notes |
|------|-----------|----------------|-------|
| User CRUD Operations | Low | 2 days | Straightforward endpoints |
| Site/Sample CRUD | Low | 2 days | Similar to User CRUD |
| Bootstrap Data API | Low | 1 day | Simple data aggregation |
| Health Check & System Endpoints | Low | 1 day | Basic endpoints |
| Caching Implementation | Low | 2 days | Standard Redis pattern |

### Database Considerations

- **Keep Existing Schema:** No changes to PostgreSQL schema
- **Stored Procedures:** Call from Python, don't rewrite unless necessary
- **Migrations:** Use Alembic to version control any new tables/indexes
- **Connection Pooling:** Essential for performance

---

## Timeline & Resource Estimation

### Total Timeline: 16-24 weeks

### Detailed Phase Breakdown

| Phase | Duration | Team | Priority | Dependencies |
|-------|----------|------|----------|--------------|
| **1. Foundation** | 4-6 weeks | 1-2 devs | Critical | None |
| **2. Auth & Authorization** | 2-3 weeks | 1 dev | Critical | Phase 1 |
| **3. Core Models** | 3-4 weeks | 1-2 devs | Critical | Phase 1 |
| **4. Repository Layer** | 3-4 weeks | 1-2 devs | Critical | Phase 3 |
| **5. Service Layer** | 4-5 weeks | 2 devs | Critical | Phase 4 |
| **6. API Routes** | 4-5 weeks | 2 devs | Critical | Phase 5 |
| **7. Background Tasks** | 2-3 weeks | 1 dev | High | Phase 6 |
| **8. Email & External** | 1-2 weeks | 1 dev | Medium | Phase 5 |
| **9. Caching** | 1-2 weeks | 1 dev | Medium | Phase 6 |
| **10. Testing** | 3-4 weeks | 1 dev | Critical | Ongoing |
| **Documentation** | 2 weeks | 1 dev | High | Phase 6+ |
| **Buffer/Polish** | 2-3 weeks | Team | High | All phases |

### Team Composition

**Recommended:** 2-3 developers + 1 QA

**Roles:**
- **Lead Developer:** Architecture, complex components
- **Backend Developer:** Services, repositories, APIs
- **DevOps/Full-stack:** Docker, CI/CD, deployment
- **QA Engineer:** Testing, test automation

### Milestone Schedule

**Month 1-2:** Foundation + Auth + Models  
**Month 3-4:** Repositories + Services  
**Month 4-5:** API Routes + Background Tasks  
**Month 5-6:** Testing + Polish + Documentation  

---

## Risk Mitigation

### Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Performance regression** | High | Medium | Load testing, profiling, caching strategy |
| **Database schema changes during migration** | High | Medium | Use Alembic, version control, coordination |
| **Business logic bugs** | High | Low | Comprehensive testing, parallel deployment |
| **Stored procedure incompatibility** | Medium | Low | Document all procedures, test thoroughly |
| **Session management issues** | Medium | Medium | Hybrid approach, gradual migration |

### Project Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Scope creep** | High | Medium | Strict scope control, change management |
| **Resource availability** | High | Medium | Cross-training, documentation |
| **Timeline delays** | Medium | High | Buffer time, agile approach |
| **Frontend integration issues** | Medium | Medium | Early coordination, API contracts |

### Mitigation Strategies

1. **Parallel Deployment**
   - Run PHP and Python APIs side-by-side
   - Gradual traffic migration
   - Fallback to PHP if issues arise

2. **Comprehensive Testing**
   - Unit tests for all components
   - Integration tests for all endpoints
   - E2E tests for critical workflows
   - Performance/load testing

3. **Documentation**
   - API documentation (OpenAPI)
   - Architecture diagrams
   - Deployment guides
   - Runbooks for operations

4. **Monitoring & Alerting**
   - Application metrics
   - Error tracking (Sentry)
   - Performance monitoring
   - Database query monitoring

5. **Rollback Plan**
   - Keep PHP API running
   - Database migrations reversible
   - Feature flags for gradual rollout

---

## Benefits Analysis

### Performance Improvements

| Metric | PHP (Current) | Python/FastAPI | Improvement |
|--------|---------------|----------------|-------------|
| **Concurrent Requests** | ~100 | ~1000+ | 10x |
| **Response Time (p50)** | ~50ms | ~20ms | 2.5x |
| **Memory Usage** | High | Medium | -30% |
| **JSON Serialization** | Slow | Fast (Pydantic) | 5x |

### Developer Experience

**Current (PHP):**
- ❌ No type hints
- ❌ Limited IDE support
- ❌ Manual API documentation
- ❌ Complex dependency management

**New (Python/FastAPI):**
- ✅ Full type hints
- ✅ Excellent IDE support (autocomplete, refactoring)
- ✅ Automatic API documentation (OpenAPI)
- ✅ Modern dependency management (Poetry)

### Maintainability

**Code Quality:**
- Clearer separation of concerns
- Better testability
- Consistent patterns
- Type safety

**Testing:**
- pytest ecosystem
- Async test support
- Better mocking tools
- Faster test execution

**DevOps:**
- Better Docker support
- Easier deployments
- Better monitoring options
- Modern tooling

### Security

| Aspect | Improvement |
|--------|-------------|
| **Authentication** | JWT tokens (stateless, scalable) |
| **Password Hashing** | Modern bcrypt implementation |
| **Input Validation** | Pydantic automatic validation |
| **SQL Injection** | SQLAlchemy ORM protection |
| **Dependency Updates** | Easier with Poetry |

### Long-term Benefits

1. **Easier Hiring:** Python/FastAPI is modern and popular
2. **Community:** Large, active community for support
3. **Ecosystem:** Rich ecosystem of libraries
4. **Future-proof:** Modern, actively maintained stack
5. **Cloud-native:** Better suited for cloud deployments

---

## Next Steps

### Immediate Actions (Next 2 Weeks)

1. **Stakeholder Approval**
   - Present migration plan
   - Get budget approval
   - Confirm timeline

2. **Proof of Concept**
   - Implement 3-5 core endpoints
   - Test performance
   - Validate patterns
   - Demo to stakeholders

3. **Team Assembly**
   - Hire/assign developers
   - Set up development environment
   - Training on FastAPI/SQLAlchemy

4. **Infrastructure Preparation**
   - Set up development servers
   - Configure Docker environment
   - Set up CI/CD pipeline
   - Database access for dev team

### Week 1-2: POC Sprint

**Goal:** Validate approach with working proof of concept

**Scope:**
- Health check endpoint
- User authentication (login/logout)
- Get submissions endpoint
- Get submission by ID endpoint
- Database connection working

**Deliverable:** Working demo with 4-5 endpoints

### Week 3-4: Planning & Setup

**Tasks:**
- Finalize project structure
- Set up all repositories/services scaffolding
- Create comprehensive test plan
- Map all 30+ endpoints to owners
- Set up project management (Jira/GitHub Projects)

### Week 5+: Begin Phase 1

Start with Foundation & Infrastructure phase as outlined above.

---

## Appendix

### A. PHP to Python Mapping

| PHP Concept | Python/FastAPI Equivalent |
|-------------|---------------------------|
| Composer | Poetry |
| PSR-4 Autoloading | Python imports |
| Slim Framework | FastAPI |
| PHP Sessions | JWT tokens |
| PDO | SQLAlchemy + asyncpg |
| Monolog | Python logging |
| PHPMailer | aiosmtplib |
| PHPUnit | pytest |

### B. Database Tables Reference

See existing schema in `transport_system/` and `src/sql/` directories.

Key tables:
- `clearing_house.tbl_clearinghouse_*` - Main application tables
- Schema is production and should not be modified during migration

### C. Stored Procedures to Document

- `fn_explode_submission_xml_to_rdb()`
- Any other procedures called from `DatabaseCallService.php`

### D. Environment Variables Required

```bash
# Database
DATABASE_URL=postgresql+asyncpg://user:pass@host:port/db

# Auth
SECRET_KEY=random_secure_key_here
ACCESS_TOKEN_EXPIRE_MINUTES=60

# Email
SMTP_SERVER=mail.acc.umu.se
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM=noreply@sead.org

# Redis
REDIS_URL=redis://localhost:6379/0

# App
DEBUG=false
LOG_LEVEL=INFO
CORS_ORIGINS=["http://localhost:3000"]
```

### E. Testing Strategy

**Test Coverage Goals:**
- Unit tests: 80%+ coverage
- Integration tests: All endpoints
- E2E tests: Critical workflows

**Test Types:**
1. **Unit Tests:** Models, repositories, services, utilities
2. **Integration Tests:** API endpoints, database operations
3. **E2E Tests:** Complete workflows (upload → process → accept)
4. **Performance Tests:** Load testing, stress testing
5. **Security Tests:** Auth, permissions, injection attacks

### F. Deployment Options

**Option 1: Parallel Deployment**
- PHP API: `/api/*`
- Python API: `/api/v2/*`
- Gradually migrate endpoints

**Option 2: Feature Flags**
- Both APIs running
- Toggle between them per endpoint
- A/B testing

**Option 3: Complete Cutover**
- Deploy Python API
- Keep PHP as backup
- Switch DNS/routing

**Recommended:** Option 1 (Parallel Deployment)

---

## Document Control

**Version History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-20 | Migration Team | Initial comprehensive plan |

**Review Schedule:**
- Weekly during POC phase
- Bi-weekly during active development
- Monthly for long-term planning

**Approvals Required:**
- Technical Lead
- Project Manager
- Stakeholders

---

**End of Document**
