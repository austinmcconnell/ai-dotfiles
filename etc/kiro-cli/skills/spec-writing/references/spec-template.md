# Feature Name

**Status:** Draft
**Created:** YYYY-MM-DD
**Owner:** @username

## Overview

[1-2 paragraphs: What is this feature and why does it matter? Give enough context that anyone can understand the goal without reading further.]

## Requirements

User-facing behavior as testable checkboxes:

- [ ] User can [perform specific action]
- [ ] System [responds with specific behavior] when [condition]
- [ ] Feature [handles specific edge case]

**Edge cases:** [Scenario → outcome]. [Another scenario → outcome]. [Third scenario → outcome].

## Architecture

### Components

- **Component Name** - Role and responsibility
- **Another Component** - Role and responsibility

### Data Contracts

**API Endpoint:**

```http
GET /api/resource
Response: { "data": {...}, "meta": {...} }
```

**Database Schema:**
```sql
CREATE TABLE resource (
  id UUID PRIMARY KEY,
  name VARCHAR(255),
  created_at TIMESTAMP
);
```

### Key Decisions

**Decision:** [What you decided]
**Why:** [Rationale for the decision]
**Trade-off:** [What you're giving up or accepting]

**Decision:** [Another decision]
**Why:** [Rationale]
**Trade-off:** [Consequences]

## Implementation Plan

Tasks ordered by dependency (each completable in single PR):

- [ ] [First task that unblocks others]
- [ ] [Second task that depends on first]
- [ ] [Third task]
- [ ] [Write tests]
- [ ] [Add monitoring/logging]

## Verification

| Requirement | Test Method | Pass Criteria |
| ----------- | ----------------------- | --------------------------- |
| [Requirement 1] | [Unit/Integration/E2E test] | [Specific pass condition] |
| [Requirement 2] | [Performance test] | [Metric threshold] |
| [Requirement 3] | [Manual test] | [Observable outcome] |

## Open Questions

- [ ] [Question that needs answering before implementation]
- [ ] [Another unresolved decision]

---

## Example: Real-Time Metrics Dashboard

**Status:** In Progress
**Created:** 2026-03-04
**Owner:** @austin

### Overview

Add a real-time dashboard showing system metrics (CPU, memory, disk) with automatic threshold highlighting. This replaces manual SSH checks and provides visibility for the entire team. Metrics update every 5 seconds with sub-2-second page load times.

### Requirements

- [ ] User can view dashboard with real-time CPU, memory, and disk metrics
- [ ] System highlights metrics exceeding 80% threshold in red
- [ ] Dashboard loads in under 2 seconds
- [ ] Metrics update automatically every 5 seconds
- [ ] User can manually refresh metrics

**Edge cases:** No data available → show empty state with "Collecting metrics..." message. API timeout → show cached data with staleness indicator. User has no permissions → redirect to access request page.

### Architecture

#### Components

- **Dashboard Controller** - Handles HTTP requests, returns metrics JSON
- **Metrics Service** - Fetches system data via OS calls
- **Cache Layer** - Redis with 5-minute TTL for performance

#### Data Contracts

**API Response:**
```json
{
  "metrics": {
    "cpu": 45.2,
    "memory": 62.8,
    "disk": 78.1
  },
  "timestamp": "2026-03-04T10:00:00Z",
  "cached": false
}
```

**Database:** None required (real-time data only)

#### Key Decisions

**Decision:** Use Redis cache with 5-minute TTL
**Why:** Reduces load on metrics service, acceptable staleness for monitoring use case
**Trade-off:** Users may see slightly outdated data during high-change periods

**Decision:** Client-side polling instead of WebSockets
**Why:** Simpler implementation, adequate for 5-second refresh rate
**Trade-off:** Slightly higher network overhead, but negligible for this use case

### Implementation Plan

- [ ] Create `/api/metrics` endpoint in backend
- [ ] Implement metrics service with system calls (CPU, memory, disk)
- [ ] Add Redis caching layer with 5-minute TTL
- [ ] Build dashboard React component with auto-refresh
- [ ] Add threshold highlighting logic (>80% = red)
- [ ] Implement error handling and empty states
- [ ] Write integration tests for API endpoint
- [ ] Write unit tests for threshold logic
- [ ] Add performance monitoring (response time tracking)

### Verification

| Requirement | Test Method | Pass Criteria |
| ---------------------- | ----------------- | --------------------------------------- |
| Dashboard loads < 2s | Performance test | p95 latency < 2000ms |
| Threshold highlighting | Unit test | Red color applied when value > 80% |
| Cache behavior | Integration test | Cache hit rate > 90% |
| Auto-refresh | E2E test | Metrics update within 6 seconds |
| Error handling | Integration test | Graceful degradation on API failure |

### Open Questions

- [ ] Should we support custom threshold values per user? (Default: No, keep simple)
- [ ] Do we need historical data or just current snapshot? (Decision: Current only for v1)
