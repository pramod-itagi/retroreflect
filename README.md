# Retroreflect

> A retrospective dashboard that helps teams reflect on their work, have
> honest conversations, and turn discussion into actionable
> follow-through.

## Overview

Retroreflect is a retrospective management application designed around a
simple workflow:

**Collect → Reveal → Discuss → Act → Close**

The goal is to make sprint retrospectives easy to run while preserving
the anonymity of individual feedback.

The original Retroreflect application was built during an internship as
a Ruby on Rails application. This project is a rebuilt and expanded
version, keeping the core retrospective workflow while improving
authorization, anonymity, team management, action items, lifecycle
handling, and future analytics/AI capabilities.

---

## Why Retroreflect?

Traditional retrospective meetings can become repetitive and difficult
to follow up on.

Retroreflect provides a structured workflow where:

- Team members can privately submit retrospective feedback.
- Feedback remains anonymous after it is revealed.
- Facilitators can reveal and discuss all feedback during the meeting.
- Action items can be created directly from the discussion.
- Action items continue to exist after the retrospective is closed.
- Teams can keep historical retrospectives for future reference.
- Future AI capabilities can help identify recurring themes and
  patterns across retrospectives.

---

## Core Retrospective Format

Each retrospective contains four feedback categories:

1.  **What went well**
2.  **What didn't go well**
3.  **What to continue**
4.  **What to improve**

Participants can add multiple points to each category.

The retrospective board uses a **2×2 layout**:

```text
┌─────────────────────────┬─────────────────────────┐
│ What went well          │ What didn't go well     │
├─────────────────────────┼─────────────────────────┤
│ What to continue        │ What to improve         │
└─────────────────────────┴─────────────────────────┘
```

---

## User Roles

Retroreflect has three distinct role concepts.

### System Admin

System Admin is an application-level role.

System Admins can:

- Access System Administration.
- Create teams and assign an initial Facilitator.
- View and archive teams.
- Manage System Admin access.

System Admin status does not automatically grant team membership, Facilitator
privileges, or access to retrospective feedback.

The first System Admin is created with an explicit bootstrap task, not by
registration or deployment:

    bin/rails retroreflect:create_system_admin

### Facilitator

A facilitator is a team-level role responsible for running retrospectives and
managing that team.

Facilitators can:

- Manage team membership on their own team.
- Add confirmed users to their team.
- Assign Facilitator/Member roles on their own team.
- Create retrospectives.
- Invite team members to retrospectives.
- Monitor participant submission status.
- Reveal feedback.
- Facilitate discussion.
- Create action items during the retrospective.
- Manage action items.
- Mark action items completed after confirmation.
- Close retrospectives.
- Archive their own team.

Multiple facilitators can belong to the same team. Facilitators cannot create
teams or access System Administration unless they are also granted System Admin
independently.

### Participant / Member

Participants can:

- Join retrospectives they are invited to.
- Enter feedback privately.
- Add multiple points to each category.
- Edit their own drafts while collection is open.
- Remove their own draft points.
- Save their draft.
- Submit their feedback.

Participants cannot:

- Create teams.
- Create retrospectives.
- Reveal feedback.
- View another participant's feedback.
- Manage team membership.
- Archive teams.
- Manage the retrospective as a facilitator.

The facilitator is **not a participant by default**. The facilitator
acts as the person running the retrospective and does not contribute
anonymous feedback as part of the team submission.

---

# Retrospective Workflow

## 1. Create a Team

A System Admin creates a team and assigns a confirmed user as the initial
Facilitator.

The System Admin does not become a team member automatically. The initial
Facilitator then adds confirmed users as members.

Team creation is enforced by backend authorization as well as the UI.

Active team names must be unique. An archived team's name may be reused.

---

## 2. Create a Retrospective

The facilitator creates a retrospective for a team.

A retrospective includes information such as:

- Title
- Sprint number
- Team
- Participant roster

A team can have only one active/running retrospective at a time.

A new retrospective cannot be created until the existing active
retrospective has been closed.

The participant roster becomes frozen once collection starts.

---

## 3. Invite Participants

The facilitator selects members from the team and sends invitations.

Participants are required to have registered accounts.

Invitations are intended for team members only.

Participants should not be able to participate simply because an
invitation link was forwarded to another person.

---

## 4. Collect Feedback

Participants access the retrospective through their authenticated
account.

During collection:

- Participants can see only their own drafts.
- Participants can add multiple points.
- Participants can edit their own drafts.
- Participants can remove their own drafts.
- Participants can save their work as a draft.
- Participants can submit when finished.

Participants cannot see what other participants have written.

The facilitator can see whether participants have submitted, but cannot
see which participant wrote a particular feedback point.

---

## 5. Anonymous Feedback Model

Anonymity is a core design decision in Retroreflect.

The system intentionally does **not** retain an author mapping for
published feedback.

During collection, draft feedback is associated with the participant
only for the purpose of allowing that participant to edit their own
work.

When feedback is revealed:

1.  Published feedback records are created using only the category and
    body.
2.  Feedback is shuffled.
3.  Draft feedback is deleted.
4.  No participant/user identifier is retained on the published
    feedback.
5.  No separate authorship mapping is retained.

Therefore, published feedback cannot be mapped back to its author
through the application.

This is intentionally stronger than simply hiding an author field in the
UI.

### What is retained

The system may retain participation information such as:

- Who was invited.
- Whether a participant submitted.
- Submission time.

This allows a facilitator to know who has or has not submitted without
knowing who wrote an individual card.

---

# Reveal and Discussion

## Locked-Box Model

Retroreflect uses a **locked-box** model.

Feedback is collected privately and is not revealed incrementally.

The facilitator reveals the collected feedback only when the
retrospective is ready for discussion.

The reveal action should not be available when there have been no
submissions.

The UI should clearly communicate that the reveal action becomes
available only after at least one participant submission.

For example:

> At least one participant must submit feedback before the points can be
> revealed.

Once feedback has been revealed:

- Published feedback is anonymous.
- Participant authorship is no longer available in the application.
- The facilitator can discuss the feedback with the team.

---

# Editing and Freezing

Once the retrospective moves into the discussion stage, feedback
collection is frozen.

Participants cannot continue editing or adding feedback after discussion
has started.

This protects the integrity of the meeting and ensures that the
facilitator is discussing a stable set of anonymous feedback.

The participant also cannot edit submitted feedback.

---

# Action Items

Action items are created during the retrospective discussion.

This is intentional.

A facilitator discusses a feedback point with the team and, when the
team agrees that an action is needed, creates an action item.

An action item can contain:

- Title
- Description
- Owner
- Due date
- Status
- Retrospective association

### Action Item Lifecycle

Action items continue independently after their retrospective is closed.

They are not deleted when a retrospective is closed.

Typical statuses include:

- Open
- In Progress
- Ready for Review
- Completed
- Cancelled

Only the facilitator can mark an action item as completed, after
discussing the item with the team and getting confirmation.

### Progress Updates

Action items should support a lightweight progress update when status
changes.

The intention is not to create a full comment/discussion system.

Instead, an update can provide context such as:

> Deployment script is being tested. Waiting for CI pipeline changes.

For normal status changes, the update can be optional.

For important terminal transitions:

- **Completed** → completion note should be required.
- **Cancelled** → cancellation reason should be required.

This provides context for why an action item was completed or cancelled.

---

# Action Item Visibility

Retroreflect separates action-item creation from action-item management.

### Retrospective Meeting Board

Used to **create** action items during discussion.

### Home

Shows **action items needing attention** across the user's workspace.

This provides a quick overview of items that are overdue, due soon, or
otherwise require attention.

### Actions

Provides the complete action-item management and history experience.

### Team Page

The Team page does not provide an action-item creation form.

It is focused on:

- Team members.
- Current retrospective.
- Team lifecycle.

This avoids duplicating action-item creation and management across
multiple screens.

---

# Team Management

A team represents a group of users participating in retrospectives.

The application currently follows a:

> **Single company with many teams**

model rather than a multi-organization SaaS model.

### Team Membership

Facilitators can:

- Add confirmed users.
- Assign roles.
- Remove team members.

Removing a team member is a destructive membership operation and should
require confirmation.

The backend must enforce all membership rules; hiding an action in the
UI is not sufficient authorization.

---

# Team Archiving

Teams should be archived rather than hard-deleted.

Archiving a team:

- Removes all current members from the team.
- Prevents new retrospectives from being created for the team.
- Retains historical retrospectives.
- Retains historical action items.
- Preserves historical data for reference and future analysis.

The archive operation should display a clear warning before
confirmation.

Example:

> Archiving removes all current members from this team and prevents new
> retrospectives. Historical retrospectives and action items are
> retained.

The exact restore behavior for archived teams is a future product
decision.

---

# Retrospective History

Historical retrospectives should be kept separate from the
active/current workflow.

The application should prioritize the current retrospective and current
work rather than filling the main team screen with historical
retrospectives.

The navigation includes a dedicated **Retrospectives** area for
historical retrospectives.

A team page can provide a link such as:

> View retrospective history

but should not display a large list of all historical retrospectives.

This keeps the current team workflow focused.

---

# Application Navigation

The application is intended to have the following major areas:

### Home

A workspace overview showing:

- Current work / active retrospectives.
- Teams requiring attention.
- Action items needing attention.
- A small amount of contextual/product information.

The Home page should not become a full historical data browser.

### Teams

Team management and team membership.

### Retrospectives

Historical and current retrospective browsing.

### Actions

Action-item management and history.

### Meeting Board

The working area for running an active retrospective.

---

# Product Experience

The authenticated Home page should answer:

> **What needs my attention right now?**

The Team page should answer:

> **What's happening with this team?**

The Retrospectives page should answer:

> **What happened in previous retrospectives?**

The Actions page should answer:

> **What action items exist and what is their current status?**

The Meeting Board should answer:

> **How do we run this retrospective?**

A separate public/landing experience can answer:

> **What is Retroreflect and why should a team use it?**

The future visual design can use the existing Retroreflect design
direction as inspiration without changing the underlying product
responsibilities.

---

# Retrospective States

The application uses a lifecycle where a retrospective moves through
controlled states.

A simplified workflow is:

```text
Draft
  │
  ▼
Collecting
  │
  ▼
Discussing
  │
  ▼
Closed
```

A retrospective may also be cancelled according to the final lifecycle
rules.

Important lifecycle principles:

- Only one active retrospective can exist for a team at a time.
- The participant roster freezes when collection begins.
- Feedback becomes immutable once discussion begins.
- Published feedback is anonymous.
- Closed retrospectives are historical records.

---

# Privacy and Security Principles

Privacy is an important part of Retroreflect's design.

The application must not treat UI hiding as anonymity.

Do not:

- Hide participant IDs in serializers.
- Keep an authorship mapping and simply hide it from the UI.
- Add hidden "show author" functionality.
- Log participant identity alongside published feedback in a way that
  reconstructs authorship.
- Expose another participant's drafts.

Published feedback must not contain a user or participation reference.

Backend authorization must protect all facilitator-only operations.

---

# Future AI Capabilities

AI is intentionally a future phase, not a requirement for the core
retrospective workflow.

The long-term goal is to use anonymous historical feedback to provide
useful insights across retrospectives.

Potential capabilities include:

### Recurring Themes

Identify themes that appear repeatedly across multiple retrospectives.

Example:

```text
Sprint 20
"Deployment was painful."

Sprint 21
"Deployment took too long."

Sprint 22
"Deployment process still causes delays."
```

AI could identify:

> **Recurring theme: Deployment process**

### Trend Analysis

Identify whether a recurring problem is:

- Improving.
- Getting worse.
- Staying unchanged.

### Cross-Retrospective Insights

AI could summarize patterns across several closed retrospectives rather
than analyzing only one meeting.

### Suggested Actions

AI could potentially suggest action items based on recurring themes.

Any AI capability should preserve the application's anonymity model.

AI should work with published anonymous feedback and should not receive
participant identity information.

---

# Future UI Direction

The application will eventually receive a broader UI/UX redesign.

The intended visual direction is inspired by the Retroreflect design
concept:

- Warm/off-white background.
- Dark green typography.
- Coral accent color.
- Editorial-style display typography.
- Clean cards.
- Generous whitespace.
- Rounded controls.
- Clear hierarchy.
- Calm, focused visual language.

The visual redesign should be applied after the core functional
workflows and edge cases are stable.

The UI should improve the product experience without changing the
established domain model or privacy guarantees.

---

# Current Product Principles

Retroreflect is built around a few core principles:

### 1. Anonymous means anonymous

Do not retain an author-to-published-feedback mapping.

### 2. Discussion should be focused

Feedback is collected first and revealed together.

### 3. The roster is stable

Once collection begins, the participant roster is frozen.

### 4. Action items come from discussion

Action items are created during the retrospective meeting, not from
unrelated team-management screens.

### 5. Action items survive the retrospective

Closing a retrospective does not close or delete its action items.

### 6. Historical information should not overwhelm current work

Current retrospectives and outstanding actions should be easy to find.
Historical information belongs in dedicated areas.

### 7. Authorization is enforced on the backend

UI visibility is not a security boundary.

### 8. Keep the core workflow simple

Retroreflect should make running a retrospective easier rather than
introducing unnecessary complexity.

---

# Project Status

The application is currently being developed incrementally.

The current focus is:

1.  Complete and verify core retrospective workflows.
2.  Resolve edge cases and authorization rules.
3.  Finalize team archiving and lifecycle behavior.
4.  Finalize action-item behavior.
5.  Verify automated tests.
6.  Apply the broader UI/UX redesign.
7.  Explore AI-powered retrospective insights.

Technical implementation details will continue to evolve as the product
decisions are finalized.

---

# Planned Areas

## Core

- Authentication
- Team management
- Team membership
- Retrospective creation
- Participant invitations
- Anonymous feedback collection
- Locked-box reveal
- Discussion workflow
- Retrospective closure

## Action Management

- Action item creation during discussion
- Ownership
- Due dates
- Status management
- Progress updates
- Completion/cancellation reasons
- Action item history

## History

- Previous retrospectives
- Historical anonymous feedback
- Retrospective/action relationships

## Team Lifecycle

- Team archiving
- Membership removal
- Active retrospective restrictions

## Future

- Improved notifications
- Audit/history capabilities
- Richer action-item tracking
- Cross-retrospective analytics
- AI-generated insights
- Recurring theme detection
- Trend analysis
- Suggested actions

---

# Development Philosophy

Retroreflect is being developed incrementally.

Before adding large features, the project prioritizes:

- Clear product behavior.
- Explicit state transitions.
- Strong authorization.
- Privacy by design.
- Simple workflows.
- Automated tests.
- Small, reviewable changes.

The UI will be refined after the underlying product behavior is stable.

---

## License

License information will be added when the project license is finalized.
