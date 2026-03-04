# Architecture Decision Record (ADR) Format

Use this format when documenting architectural decisions within specs.

## Structure

```markdown
**Decision:** [What you decided - one sentence]
**Why:** [Rationale - why this is the right choice]
**Trade-off:** [What you're accepting or giving up]
```

## Guidelines

**Decision:**
- One clear sentence
- State what was chosen
- Be specific, not vague

**Why:**
- Explain the reasoning
- Reference constraints or requirements
- Mention alternatives considered (briefly)

**Trade-off:**
- What are you accepting?
- What are you giving up?
- What could go wrong?

## Examples

### Good ADRs

**Decision:** Use Redis cache with 5-minute TTL
**Why:** Reduces load on metrics service by 90%, acceptable staleness for monitoring use case
**Trade-off:** Users may see slightly outdated data during high-change periods

**Decision:** Client-side polling instead of WebSockets
**Why:** Simpler implementation, adequate for 5-second refresh rate, easier to debug
**Trade-off:** Slightly higher network overhead (~10KB/min per client), but negligible for expected user count

**Decision:** PostgreSQL for transactional data, ClickHouse for analytics
**Why:** PostgreSQL handles ACID requirements for user data, ClickHouse provides 100x faster analytics queries
**Trade-off:** Operational complexity of managing two databases, data sync required

**Decision:** Monorepo with shared packages
**Why:** Easier code sharing, atomic cross-package changes, single CI pipeline
**Trade-off:** Larger repository size, longer clone times, requires tooling (Nx/Turborepo)

### Bad ADRs (Too Vague)

❌ **Decision:** Use caching
**Why:** Better performance
**Trade-off:** Complexity

Better version:
✅ **Decision:** Use Redis cache with 5-minute TTL for API responses
**Why:** Reduces database load by 85%, p95 latency drops from 800ms to 120ms
**Trade-off:** Stale data possible for up to 5 minutes, cache invalidation adds complexity

---

❌ **Decision:** Use microservices
**Why:** Scalability
**Trade-off:** More services

Better version:
✅ **Decision:** Split monolith into 3 services: API, Worker, Analytics
**Why:** API and Worker have different scaling needs (API: CPU-bound, Worker: I/O-bound), Analytics requires different tech stack (ClickHouse)
**Trade-off:** Distributed system complexity, network latency between services, harder local development

## When to Write ADRs

Write ADRs for:
- Technology choices (database, framework, language)
- Architecture patterns (monolith vs microservices, REST vs GraphQL)
- Data modeling decisions (schema design, normalization)
- Performance trade-offs (caching strategy, indexing)
- Security decisions (authentication method, encryption)

Don't write ADRs for:
- Obvious choices (use standard library)
- Temporary decisions (quick fix)
- Implementation details (variable names)
- Reversible choices (can change easily)

## ADR in Context

ADRs live in the "Architecture" section of specs:

```markdown
## Architecture

### Components
[List of components]

### Data Contracts
[API schemas, database schemas]

### Key Decisions

**Decision:** [First decision]
**Why:** [Rationale]
**Trade-off:** [Consequences]

**Decision:** [Second decision]
**Why:** [Rationale]
**Trade-off:** [Consequences]
```

## Updating ADRs

When decisions change:
1. Don't delete the old ADR
2. Add a new ADR explaining the change
3. Reference the old ADR

Example:
```markdown
**Decision:** Migrate from REST to GraphQL for dashboard API
**Why:** Dashboard makes 12 REST calls per page load, GraphQL reduces to 1-2 calls, 60% faster load time
**Trade-off:** Added complexity (GraphQL resolver layer), schema coordination required
**Supersedes:** Previous decision to use REST (see ADR-001)
```

## Full Example in Spec

<!-- markdownlint-disable MD040 -->

```markdown
## Architecture

### Components

- **API Gateway** - Routes requests, handles authentication
- **User Service** - Manages user data and permissions
- **Analytics Service** - Processes and queries event data

### Data Contracts

**User API:**

```json
{
  "id": "uuid",
  "email": "string",
  "role": "admin|user"
}
```

### Key Decisions

**Decision:** Use JWT tokens with 1-hour expiration
**Why:** Stateless authentication, no database lookup per request, standard format
**Trade-off:** Cannot revoke tokens before expiration, must implement refresh token flow

**Decision:** PostgreSQL for user data, ClickHouse for analytics
**Why:** PostgreSQL handles ACID requirements, ClickHouse provides 100x faster analytics queries (30s → 300ms)
**Trade-off:** Two databases to manage, data sync pipeline required, increased operational complexity

**Decision:** Event-driven architecture with Kafka
**Why:** Decouples services, allows replay on failure, handles 10K events/sec with room to scale
**Trade-off:** Added latency (~200ms), operational complexity of Kafka cluster, eventual consistency
```

<!-- markdownlint-enable MD040 -->
