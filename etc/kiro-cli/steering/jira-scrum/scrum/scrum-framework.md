# SCRUM Framework Knowledge

## Core SCRUM Principles

### The Three Pillars of Scrum

1. **Transparency**: All aspects of the process must be visible to those responsible for the outcome
2. **Inspection**: Scrum artifacts and progress must be inspected frequently to detect variances
3. **Adaptation**: If inspection reveals unacceptable deviations, adjustments must be made quickly

### The Five Scrum Values

1. **Commitment**: Team members commit to achieving the team's goals
2. **Courage**: Team members have courage to do the right thing and work on tough problems
3. **Focus**: Everyone focuses on the work of the Sprint and the goals of the Scrum Team
4. **Openness**: Team members are open about their work and the challenges they face
5. **Respect**: Team members respect each other to be capable, independent people

## Scrum Roles

### Product Owner

- **Responsibilities**:
  - Manages the Product Backlog
  - Defines and prioritizes user stories
  - Ensures the team understands items in the Product Backlog
  - Makes decisions about scope and acceptance criteria
  - Represents stakeholders and users
- **Key Activities**:
  - Writing and refining user stories
  - Prioritizing backlog items based on business value
  - Accepting or rejecting completed work
  - Participating in Sprint Planning, Review, and Retrospective

### Scrum Master

- **Responsibilities**:
  - Facilitates Scrum events
  - Coaches the team on Scrum practices
  - Removes impediments
  - Protects the team from external distractions
  - Ensures Scrum is understood and enacted
- **Key Activities**:
  - Facilitating Sprint ceremonies
  - Helping resolve conflicts and impediments
  - Coaching team members on agile practices
  - Ensuring adherence to Scrum principles

### Development Team

- **Responsibilities**:
  - Delivers potentially shippable product increments
  - Self-organizes to accomplish Sprint goals
  - Estimates user stories
  - Participates in all Scrum ceremonies
- **Characteristics**:
  - Cross-functional (has all skills needed to create the product)
  - Self-organizing (decides how to do the work)
  - Typically 3-9 members

## Scrum Artifacts

### Product Backlog

- **Definition**: Ordered list of features, functions, requirements, enhancements, and fixes
- **Characteristics**:
  - Owned and managed by the Product Owner
  - Dynamic and constantly evolving
  - Items are prioritized by business value
  - Higher priority items are more detailed and refined

### Sprint Backlog

- **Definition**: Set of Product Backlog items selected for the Sprint plus a plan for delivering
  them
- **Characteristics**:
  - Created during Sprint Planning
  - Owned by the Development Team
  - Can be modified during the Sprint as more is learned
  - Includes tasks needed to complete the selected user stories

### Product Increment

- **Definition**: Sum of all Product Backlog items completed during a Sprint plus all previous
  Sprints
- **Characteristics**:
  - Must be potentially shippable
  - Must meet the Definition of Done
  - Cumulative - includes all previous increments

## Definition of Done (DoD)

### Purpose

- Shared understanding of what it means for work to be complete
- Ensures transparency and quality
- Helps the team know when a user story is truly finished

### Common DoD Criteria

- Code is written and reviewed
- Unit tests are written and passing
- Integration tests are passing
- Documentation is updated
- Code is deployed to staging environment
- Product Owner has accepted the work
- No known defects remain

### DoD Evolution

- Should be refined over time as the team matures
- Can become more stringent as processes improve
- Should be agreed upon by the entire Scrum Team

## Sprint Ceremonies

### Sprint Planning

- **Purpose**: Plan the work to be performed in the Sprint
- **Duration**: Maximum 8 hours for a one-month Sprint (proportionally less for shorter Sprints)
- **Participants**: Entire Scrum Team
- **Outcomes**:
  - Sprint Goal is defined
  - Sprint Backlog is created
  - Team commits to Sprint deliverables

### Daily Scrum

- **Purpose**: Synchronize activities and create a plan for the next 24 hours
- **Duration**: 15 minutes maximum
- **Participants**: Development Team (others may observe)
- **Format**: Each team member answers:
  - What did I do yesterday that helped the team meet the Sprint Goal?
  - What will I do today to help the team meet the Sprint Goal?
  - Do I see any impediments that prevent me or the team from meeting the Sprint Goal?

### Sprint Review

- **Purpose**: Inspect the Increment and adapt the Product Backlog if needed
- **Duration**: Maximum 4 hours for a one-month Sprint
- **Participants**: Scrum Team and stakeholders
- **Activities**:
  - Demonstrate completed work
  - Discuss what went well and what problems were encountered
  - Review timeline, budget, and potential capabilities for next Sprint

### Sprint Retrospective

- **Purpose**: Inspect how the last Sprint went and create a plan for improvements
- **Duration**: Maximum 3 hours for a one-month Sprint
- **Participants**: Scrum Team only
- **Outcomes**:
  - Identification of what went well
  - Identification of what could be improved
  - Action items for the next Sprint

## Backlog Refinement

### Purpose

- Ongoing activity to add detail, estimates, and order to Product Backlog items
- Ensures the backlog remains relevant and well-understood

### Activities

- Breaking down large user stories (epics) into smaller stories
- Adding acceptance criteria to user stories
- Estimating user stories
- Prioritizing backlog items
- Removing obsolete items

### Best Practices

- Spend no more than 10% of Development Team capacity on refinement
- Involve the entire Scrum Team
- Focus on upcoming Sprint items first
- Ensure stories meet INVEST criteria before Sprint Planning

## Estimation Techniques

### Story Points

- Relative sizing technique
- Based on complexity, effort, and uncertainty
- Common scales: Fibonacci (1, 2, 3, 5, 8, 13, 21), T-shirt sizes (XS, S, M, L, XL)

### Planning Poker

- Team-based estimation technique
- Each team member estimates independently
- Discuss differences and re-estimate until consensus

### Velocity

- Measure of how much work a team can complete in a Sprint
- Used for Sprint Planning and release planning
- Should be tracked over multiple Sprints for accuracy

## Common Anti-Patterns to Avoid

### Sprint Planning Anti-Patterns

- Planning in too much detail upfront
- Not involving the entire team
- Overcommitting to work
- Not defining a clear Sprint Goal

### Daily Scrum Anti-Patterns

- Turning it into a status meeting for the Scrum Master
- Problem-solving during the meeting
- Not focusing on the Sprint Goal
- Skipping the meeting when team members are absent

### Sprint Review Anti-Patterns

- Only showing completed work
- Not involving stakeholders
- Making it a one-way presentation
- Not adapting the Product Backlog based on feedback

### Sprint Retrospective Anti-Patterns

- Not creating actionable improvement items
- Focusing only on problems without solutions
- Not following up on previous retrospective actions
- Allowing blame and finger-pointing
