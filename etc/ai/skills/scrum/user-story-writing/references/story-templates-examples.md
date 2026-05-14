# User Story Templates and Examples

This document provides templates and real-world examples of well-written user stories across
different domains and contexts.

## Standard User Story Template

### Basic Template

````text
As a [type of user],
I want [some goal]
so that [some reason/benefit].

Acceptance Criteria:
- [Specific, testable criterion 1]
- [Specific, testable criterion 2]
- [Specific, testable criterion 3]
```text

### Enhanced Template with Given-When-Then

```text
As a [type of user],
I want [some goal]
so that [some reason/benefit].

Acceptance Criteria:
Given [some context/precondition],
When [some action is taken],
Then [some outcome is expected].

Additional Criteria:
- [Other specific requirements]
- [Edge cases or error conditions]
- [Performance or quality requirements]
```text

## E-commerce Examples

### User Registration Story

```text
As a new customer,
I want to create an account on the website
so that I can save my preferences and track my orders.

Acceptance Criteria:
- User can enter email, password, first name, and last name
- Email address must be validated for proper format
- Password must be at least 8 characters with one number and one special character
- User receives a confirmation email after successful registration
- User is automatically logged in after successful registration
- Error messages are displayed for invalid inputs
- User cannot register with an email that already exists in the system

Definition of Done:
- Unit tests written and passing
- Integration tests cover the registration flow
- Email service integration is tested
- Security review completed for password handling
- Responsive design works on mobile and desktop
```text

### Shopping Cart Story

```text
As a customer,
I want to add items to my shopping cart
so that I can purchase multiple items in a single transaction.

Acceptance Criteria:
Given I am viewing a product page,
When I click the "Add to Cart" button,
Then the item should be added to my cart
And the cart icon should show the updated item count
And I should see a confirmation message.

Additional Criteria:
- User can specify quantity before adding to cart
- Out-of-stock items cannot be added to cart
- Cart persists across browser sessions for logged-in users
- Cart shows item name, price, quantity, and subtotal
- User can access cart from any page via cart icon
- Maximum of 99 items per product can be added to cart
```text

### Order Tracking Story

```text
As a customer,
I want to track the status of my order
so that I know when to expect delivery.

Acceptance Criteria:
- Customer can enter order number to view status
- Status shows current stage: Processing, Shipped, Out for Delivery, Delivered
- Tracking information includes estimated delivery date
- Customer receives email notifications for status changes
- Order history shows all previous orders for logged-in customers
- Tracking page shows order details: items, quantities, shipping address
- Invalid order numbers show appropriate error message
```text

## SaaS Application Examples

### User Dashboard Story

```text
As a project manager,
I want to see a dashboard of my team's current projects
so that I can quickly assess progress and identify issues.

Acceptance Criteria:
- Dashboard displays all projects assigned to the user's team
- Each project shows: name, status, progress percentage, due date
- Projects are sorted by due date (earliest first)
- Overdue projects are highlighted in red
- User can click on a project to view detailed information
- Dashboard refreshes automatically every 5 minutes
- Loading state is shown while data is being fetched
- Empty state is shown when user has no projects

Performance Criteria:
- Dashboard loads within 2 seconds
- Supports up to 100 projects without performance degradation
```text

### Team Collaboration Story

```text
As a team member,
I want to comment on project tasks
so that I can communicate with my teammates about work progress.

Acceptance Criteria:
Given I am viewing a task detail page,
When I enter text in the comment field and click "Post Comment",
Then my comment should appear in the comment thread
And other team members should be notified of the new comment
And the comment should show my name and timestamp.

Additional Criteria:
- Comments support basic formatting (bold, italic, links)
- Users can edit their own comments within 5 minutes of posting
- Users can delete their own comments
- Comments are sorted chronologically (oldest first)
- Email notifications are sent to task assignee and watchers
- Comment field has a 1000 character limit
- Users can @mention other team members in comments
```text

### Reporting Story

```text
As a business analyst,
I want to generate custom reports on project metrics
so that I can provide insights to stakeholders.

Acceptance Criteria:
- User can select from predefined report types: Progress, Time Tracking, Budget
- User can filter reports by date range, project, team, or team member
- Reports can be exported as PDF or CSV
- Charts and graphs are included for visual representation
- Report generation completes within 30 seconds for standard datasets
- User can save report configurations for future use
- Reports include data source and generation timestamp
- Empty results show appropriate message with suggestions
```text

## Mobile Application Examples

### Social Media Story

```text
As a social media user,
I want to share photos with my followers
so that I can keep them updated on my activities.

Acceptance Criteria:
- User can select photos from device gallery or take new photos
- User can add captions up to 280 characters
- User can tag other users in photos
- User can add location information to posts
- Photos are automatically resized for optimal loading
- User can preview post before sharing
- Post appears in user's timeline and followers' feeds immediately
- User receives confirmation when post is successfully shared

Technical Criteria:
- Photos are compressed to under 2MB
- Offline posts are queued and sent when connection is restored
- Image upload progress is shown to user
- Failed uploads can be retried
```text

### Navigation Story

```text
As a mobile app user,
I want to navigate between screens easily
so that I can access different features quickly.

Acceptance Criteria:
- Bottom navigation bar is visible on all main screens
- Navigation icons are clearly labeled and intuitive
- Current screen is highlighted in navigation
- Tapping navigation items switches screens immediately
- Back button returns to previous screen
- Navigation state is preserved when app is backgrounded
- Navigation works consistently across iOS and Android
- Accessibility labels are provided for screen readers
```text

## Financial Services Examples

### Account Balance Story

```text
As a bank customer,
I want to view my account balance
so that I can monitor my finances.

Acceptance Criteria:
- User can view current balance after secure login
- Balance is displayed in user's preferred currency format
- Available balance and pending transactions are shown separately
- Balance information is updated in real-time
- User can view balance history for the past 12 months
- Sensitive information is masked when app is backgrounded
- Balance loads within 3 seconds of authentication
- Error handling for network connectivity issues

Security Criteria:
- Session expires after 15 minutes of inactivity
- Balance information is encrypted in transit and at rest
- Failed authentication attempts are logged and monitored
```text

### Money Transfer Story

```text
As a banking customer,
I want to transfer money to another account
so that I can pay bills and send money to family.

Acceptance Criteria:
Given I have sufficient funds in my account,
When I enter recipient details and transfer amount,
Then the money should be transferred successfully
And both accounts should reflect the updated balances
And I should receive a confirmation with transaction ID.

Additional Criteria:
- User must authenticate with PIN or biometric before transfer
- Transfer limits are enforced (daily/monthly maximums)
- Recipient account details are validated before processing
- User can save frequent recipients for future transfers
- Transfer fees are clearly displayed before confirmation
- Transaction history includes all transfer details
- Failed transfers show specific error messages
- International transfers include exchange rate information
```text

## Healthcare Examples

### Appointment Scheduling Story

```text
As a patient,
I want to schedule medical appointments online
so that I can book appointments at my convenience.

Acceptance Criteria:
- Patient can view available appointment slots for next 30 days
- Patient can select preferred doctor or accept any available doctor
- Patient can choose appointment type (consultation, follow-up, etc.)
- System prevents double-booking of time slots
- Patient receives confirmation email with appointment details
- Patient can cancel or reschedule appointments up to 24 hours in advance
- System sends reminder notifications 24 hours before appointment
- Emergency appointments are handled separately from regular booking

Compliance Criteria:
- Patient data is handled according to HIPAA requirements
- Appointment information is encrypted and access-logged
- Only authorized personnel can view patient appointment details
```text

### Medical Records Story

```text
As a healthcare provider,
I want to access patient medical records during appointments
so that I can provide informed care based on medical history.

Acceptance Criteria:
- Provider can search for patients by name, ID, or phone number
- Medical records display chronologically with most recent first
- Records include: diagnoses, medications, allergies, test results
- Provider can add new notes and observations to patient record
- All record access is logged with timestamp and provider ID
- Records are read-only for providers not directly involved in care
- System alerts provider to critical allergies or conditions
- Records can be filtered by date range or record type

Security and Compliance:
- Multi-factor authentication required for record access
- Automatic logout after 10 minutes of inactivity
- All access attempts are audited and logged
- Patient consent is verified before sharing records
```text

## Educational Technology Examples

### Online Learning Story

```text
As a student,
I want to watch video lectures online
so that I can learn at my own pace and review material as needed.

Acceptance Criteria:
- Student can access video lectures after course enrollment
- Videos support play, pause, rewind, and fast-forward controls
- Student can adjust playback speed (0.5x, 1x, 1.5x, 2x)
- Video progress is saved and resumed across sessions
- Student can take notes synchronized with video timestamps
- Videos include closed captions for accessibility
- Video quality adjusts automatically based on connection speed
- Student can download videos for offline viewing (if permitted)

Technical Criteria:
- Videos load and start playing within 5 seconds
- Streaming works on desktop, tablet, and mobile devices
- Video player works across major browsers
- Bandwidth usage is optimized for mobile users
```text

### Assignment Submission Story

```text
As a student,
I want to submit assignments online
so that I can turn in my work electronically and track submission status.

Acceptance Criteria:
Given an assignment is available for submission,
When I upload my completed work before the deadline,
Then the system should accept my submission
And I should receive a confirmation with submission timestamp
And my instructor should be notified of the new submission.

Additional Criteria:
- Student can upload multiple file types (PDF, DOC, images)
- File size limit is clearly displayed (maximum 25MB per file)
- Student can replace submissions before the deadline
- Late submissions are marked and may incur penalties
- Student can view submission history and status
- Plagiarism detection runs automatically on text submissions
- System prevents submissions after hard deadline
- Instructor can provide feedback directly on submitted files
```text

## Technical Implementation Examples

### System Integration Story

```text
As a [technical role],
I want [system behavior change]
so that [business outcome is achieved instead of current problematic behavior].

Background
[Brief context about current system behavior and why it's problematic]

Current Issue
• [Specific problem 1 with current implementation]
• [Specific problem 2 with current implementation]
• [Impact/consequence of current problems]

Acceptance Criteria

Core Functionality
• [ ] [Primary system behavior change]
• [ ] [Secondary system behavior change]

Technical Implementation
• [ ] [Specific technical task 1]
• [ ] [Specific technical task 2]
````

### Example: Data Processing Improvement

```text
As a healthcare data integration specialist,
I want FHIR bundle processing to use the organization referenced in the observations (primary care provider)
so that screenings are correctly attributed to the appropriate healthcare provider instead of the first organization found.

Background
Analysis of real-world SHIN-NY bundles reveals that the current provider lookup logic treats all organizations equally and returns the first match found. However, the observations in these bundles reference a specific performing organization that should be used as the primary care provider.

Current Issue
• Provider lookup processes organizations sequentially and returns the first match found
• Ignores the fact that observations reference a specific performing organization
• Can result in screenings being attributed to technology platforms or payers instead of the actual care provider

Acceptance Criteria

Core Functionality
• [ ] Observation-Referenced Organization: System identifies which organization is referenced in the Observation resources as the performing organization
• [ ] Primary Provider Selection: Use the organization referenced in observations as the primary care provider for screening attribution

Technical Implementation
• [ ] Organization Reference Extraction: Extract performer references from Observation resources
• [ ] Provider Matching: Match the observation-performing organization against the provider database
```

## Common Story Patterns

### CRUD Operations

#### Create Story

````text
As a [user type],
I want to create a new [entity]
so that I can [benefit/reason].

Acceptance Criteria:
- User can enter all required information for the [entity]
- Form validation prevents submission of invalid data
- User receives confirmation when [entity] is successfully created
- New [entity] appears in the user's [entity] list
- Required fields are clearly marked
- User can cancel creation and return to previous screen
```text

#### Read/View Story

```text
As a [user type],
I want to view [entity] details
so that I can [benefit/reason].

Acceptance Criteria:
- User can access [entity] details from [entity] list
- All relevant [entity] information is displayed clearly
- User can navigate back to [entity] list
- Loading state is shown while [entity] details are being fetched
- Error message is shown if [entity] cannot be loaded
- [Entity] details are formatted for readability
```text

#### Update Story

```text
As a [user type],
I want to edit [entity] information
so that I can [benefit/reason].

Acceptance Criteria:
- User can modify editable fields of the [entity]
- Changes are validated before saving
- User receives confirmation when changes are saved successfully
- Updated information is immediately reflected in the interface
- User can cancel changes and revert to original values
- Concurrent editing conflicts are handled appropriately
```text

#### Delete Story

```text
As a [user type],
I want to delete [entity]
so that I can [benefit/reason].

Acceptance Criteria:
- User can initiate deletion from [entity] detail or list view
- System requests confirmation before permanent deletion
- Deleted [entity] is removed from all relevant lists and views
- User receives confirmation of successful deletion
- Related data is handled appropriately (cascade or prevent deletion)
- Soft delete option preserves data for recovery if needed
```text

### Error Handling Patterns

#### Network Error Story

```text
As a user,
I want to be informed when network errors occur
so that I understand why actions are failing and what I can do.

Acceptance Criteria:
- Clear error messages explain what went wrong
- User is provided with suggested actions (retry, check connection)
- Offline functionality is available where possible
- Failed actions can be retried when connection is restored
- Error messages are user-friendly, not technical
- Critical errors are logged for support team investigation
```text

#### Validation Error Story

```text
As a user,
I want to receive clear feedback about form validation errors
so that I can correct my input and complete the task.

Acceptance Criteria:
- Validation errors are shown immediately after field loses focus
- Error messages are specific and actionable
- Invalid fields are visually highlighted
- Form submission is prevented until all errors are resolved
- Error messages disappear when issues are corrected
- Multiple errors are prioritized and displayed clearly
```text

## Story Quality Checklist

When writing or reviewing stories, ensure they meet these criteria:

### Structure and Format

- [ ] Follows standard "As a... I want... so that..." format
- [ ] Identifies specific user type/persona
- [ ] States clear goal or desired functionality
- [ ] Explains the value or benefit to the user
- [ ] Includes specific, testable acceptance criteria

### INVEST Criteria

- [ ] **Independent**: Can be developed without dependencies on other stories
- [ ] **Negotiable**: Leaves room for discussion and implementation decisions
- [ ] **Valuable**: Delivers clear value to users or business
- [ ] **Estimable**: Team can estimate the effort required
- [ ] **Small**: Can be completed within one Sprint
- [ ] **Testable**: Has clear criteria for determining completion

### Content Quality

- [ ] Uses plain language that stakeholders can understand
- [ ] Focuses on user needs rather than technical implementation
- [ ] Includes both positive and negative test scenarios
- [ ] Addresses edge cases and error conditions
- [ ] Specifies any performance or quality requirements
- [ ] Considers accessibility and usability requirements

### Completeness

- [ ] All necessary information is provided
- [ ] Assumptions are documented
- [ ] Dependencies are identified
- [ ] Definition of Done criteria are clear
- [ ] Business value is quantified where possible
````
