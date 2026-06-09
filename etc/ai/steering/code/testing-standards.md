---
paths:
  - '**/*.py'
  - '**/tests/**'
  - '**/test_*'
  - '**/conftest.py'
---

# Testing Standards

## Framework

- pytest for all Python testing — no unittest.TestCase subclasses
- factory-boy for test data generation (SQLAlchemy integration via `SQLAlchemyModelFactory`)
- `unittest.mock` for patching — prefer `patch` and `Mock` over third-party mock libraries

## Standard Plugins

Include these in every Python project's dev dependencies:

- `pytest-randomly` — randomizes test order to catch hidden order dependencies (zero config)
- `pytest-timeout` — kills hanging tests; set a global default of 10 seconds in `pyproject.toml` and
  override on individual slow tests with `@pytest.mark.timeout(60)`

## Project Structure

- Mirror the source tree: `app/services/cache.py` → `tests/services/test_cache.py`
- One `conftest.py` per test directory level:
  - Root `tests/conftest.py` — app fixture, DB setup, shared auth mocks
  - Domain `tests/<domain>/conftest.py` — domain-specific fixtures and factories
- Factories live alongside the tests that use them: `tests/factories.py` or
  `tests/<domain>/factories.py`

## Fixtures

- Use `@pytest.fixture` for setup; avoid setup/teardown methods
- Use `yield` for teardown, not `addfinalizer` (cleaner, easier to read)
- Prefer parameter injection over `@pytest.mark.usefixtures` unless the fixture has no return value
  (e.g., `db` for side-effect-only DB session management)
- Scope fixtures appropriately:
  - `function` (default) — test isolation, most fixtures
  - `session` — expensive one-time setup (DB process, app creation)
  - `class` — rarely; only when tests share state intentionally
- Don't specify `scope='function'` explicitly — it's the default and ruff PT003 removes it
- Name fixtures after what they provide, not what they do: `one_screening` not
  `create_screening_fixture`

## Parametrize

- Use `@pytest.mark.parametrize` when the same logic is tested with varying inputs

- Prefer separate test methods when different inputs exercise fundamentally different code paths

- Always use `ids=` for readable test names when parametrize values aren't self-explanatory:

  ```python
  @pytest.mark.parametrize('status', ['draft', 'complete', 'declined'], ids=str)
  ```

- Use tuple unpacking for multiple parameters:

  ```python
  @pytest.mark.parametrize(('input_val', 'expected'), [(1, 'one'), (2, 'two')])
  ```

## Factories (factory-boy)

- Define a `BaseFactory` with shared session binding:

  ```python
  class BaseFactory(SQLAlchemyModelFactory):
      class Meta:
          abstract = True
          sqlalchemy_session = db.session
  ```

- Prefer `build()` over `create()` when the test doesn't need persistence — faster, no DB writes

- Use `create()` only for integration tests that exercise DB queries

- Use `factory.Faker` for realistic data, `FuzzyChoice` for enums

- Use `factory.Sequence` for unique ordered values

- Use `factory.LazyAttribute` for computed fields that depend on other attributes

- Keep factories minimal — only set fields that the model requires or the test exercises

- Use `SubFactory` when the FK lives on your model; use `RelatedFactory` + trait when the FK is on
  the related model

- Put nullable fields in traits rather than setting them as defaults — forces tests to be explicit
  about optional state

## Mocking Strategy

- Mock at service boundaries: external APIs, Redis, message queues, auth services
- Use real Postgres for database tests (`pytest-postgresql` or similar)
- Prefer `patch` as context manager or decorator over `patch.object` when targeting module-level
  imports
- When mocking multiple related services, group patches in a fixture rather than stacking decorators
- Never mock the unit under test — only its dependencies

## Assertions

- Use plain `assert` statements — pytest rewrites them for informative failure messages
- Use `pytest.raises` for expected exceptions; include `match=` when the exception message matters
  (ruff PT011 encourages this)
- One logical assertion per test — multiple `assert` lines are fine if they verify one behavior
- Avoid `assert True`, `assert bool(x)` patterns — assert the actual expected value

## Test Organization

- Group related tests in classes: `TestCacheService`, `TestTemplateVisibility`
- Class names use `Test` prefix + the component being tested
- No `__init__` methods on test classes
- Method names: `test_[unit]_[scenario]_[expected_result]`
  - Example: `test_get_or_fetch_cache_miss_calls_fetch_function`

## What to Test

- Every new feature gets tests before or alongside implementation
- Bug fixes include a regression test that fails without the fix
- Test behavior, not implementation — assert outputs and side effects, not internal state
- Cover error paths: invalid input, network failures, empty results, edge cases
- Integration tests for DB queries and multi-component flows
- Unit tests for business logic, transformations, and validation

## What Not to Do

- Don't test framework behavior (Flask routing works, SQLAlchemy saves objects)
- Don't create test interdependencies — each test must pass in isolation
- Don't over-mock: if mocking requires replicating internal logic, test at a higher level
- Don't use `time.sleep` in tests — mock time or use deterministic waits
- Don't assert on log output unless logging IS the behavior being tested

## Coverage

- Minimum 80% line coverage for critical paths (services, business logic)
- Use `# pragma: no cover` sparingly and only for genuinely untestable code (e.g., `if __name__`)
- Coverage gaps in error handlers and edge cases are higher priority than covering boilerplate

## Ruff Enforcement

The `PT` rule family (flake8-pytest-style) is enabled in ruff and enforces:

- Correct `@pytest.fixture` usage and scope
- Proper `pytest.raises` patterns (include `match=`, no broad catches)
- No unnecessary `pytest.mark.usefixtures` on fixtures themselves
- Parametrize names as tuples, not CSV strings (PT006)
- Use `return_value=` instead of patching with lambda (PT008)
- No composite assertions inside `pytest.raises` blocks (PT018)
