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
version that keeps the core retrospective workflow while adding
authorization, anonymity, team management, action items, and
retrospective lifecycle handling.

The application is implemented in **Ruby 3.2** and **Rails 7.1**, with
MySQL, Hotwire, and Tailwind CSS.

---

## Why Retroreflect?

Traditional retrospective meetings can become repetitive and difficult
to follow up on.

Retroreflect provides a structured workflow where:

- Team members privately submit retrospective feedback.
- Feedback remains anonymous after it is revealed.
- Facilitators reveal and discuss all feedback during the meeting.
- Action items are created during discussion and must belong to that
  retrospective.
- Action items continue after the retrospective is closed.
- Teams keep historical retrospectives for later reference.

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

System Admin status does not automatically grant team membership,
Facilitator privileges, or access to retrospective feedback.

At least one System Admin must always remain. The last System Admin
cannot leave the role, be revoked, or be discarded.

The first System Admin is created with an explicit bootstrap task, not
by registration or deployment:

    bin/rails retroreflect:create_system_admin

### Facilitator

A facilitator is a team-level role responsible for running
retrospectives and managing that team.

Facilitators can:

- Manage team membership on their own team.
- Add confirmed users to their team.
- Assign Facilitator/Member roles on their own team.
- Create retrospectives.
- Invite team members to retrospectives.
- Monitor participant submission status.
- Reveal feedback.
- Facilitate discussion.
- Create action items during discussion.
- Update action items they facilitate, including after the retrospective
  closes or the team is archived.
- Close a discussing retrospective.
- Cancel a draft or collecting retrospective.
- Archive their own team when archive conditions are met.

An active team must keep at least one current Facilitator. Multiple
facilitators can belong to the same team.

Facilitators cannot create teams or access System Administration unless
they are also granted System Admin independently.

### Participant / Member

Participants can:

- Join retrospectives they are invited to.
- Enter feedback privately.
- Add multiple points to each category.
- Edit their own drafts while collection is open and they have not
  submitted.
- Remove their own draft points.
- Save their draft.
- Submit their feedback.
- See and update action items they own.

Participants cannot:

- Create teams.
- Create retrospectives.
- Reveal feedback.
- View another participant's drafts.
- Manage team membership.
- Archive teams.
- Manage the retrospective as a facilitator.
- Cancel an action item they own.

The facilitator is **not a participant by default**. The facilitator
runs the retrospective and does not contribute anonymous feedback as
part of the team submission.

---

# Retrospective Workflow

## 1. Create a Team

A System Admin creates a team and assigns a confirmed user as the
initial Facilitator.

The System Admin does not become a team member automatically. The
initial Facilitator then adds confirmed users as members.

Team creation is enforced by backend authorization as well as the UI.

Active team names must be unique. An archived team's name may be reused.

---

## 2. Create a Retrospective

The facilitator creates a retrospective for a team.

Sprint identity is assigned automatically and is **team-scoped**:

- Each team starts at Sprint 1.
- The next number is the team's next unused sprint, including cancelled
  and closed retrospectives.
- The calendar year is display context only. Numbers do not reset in
  January.
- Different teams can have the same sprint number at the same time.
- The same facilitator managing two teams does not share one sequence.

The generated identity looks like:

```text
Sprint 1 (2026)
Sprint 1 Retrospective - 2026
```

Facilitators do not type a sprint number or title. Client-supplied
values are ignored.

A team can have only one running retrospective at a time (`draft`,
`collecting`, or `discussing`). A new retrospective cannot be created
until that one is **closed** or **cancelled**.

The participant roster can be edited while the retrospective is in
draft. The roster freezes when collection starts.

---

## 3. Invite Participants

The facilitator selects members from the team and starts collection,
which sends invitations. At least one participant must be on the roster
before collection can start.

Participants must have registered, confirmed accounts.

Invitations are for team members on the roster. A forwarded invitation
link does not grant participation to someone who is not on that
retrospective.

---

## 4. Collect Feedback

Participants access the retrospective through their authenticated
account.

During collection:

- Participants can see only their own drafts.
- Participants can add multiple points.
- Participants can edit their own drafts until they submit.
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
only so that participant can edit their own work.

When feedback is revealed:

1.  Only drafts from **submitted** participations are published.
2.  Published records store only the category and body.
3.  Feedback is shuffled within each category.
4.  Drafts are deleted.
5.  No participant/user identifier is retained on published feedback.
6.  No separate authorship mapping is retained.

Unsubmitted drafts are not published.

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

The facilitator reveals collected feedback only when the retrospective
is ready for discussion.

Reveal is not available when there have been no submissions.

The UI communicates that reveal becomes available only after at least
one participant submission.

For example:

> At least one participant must submit feedback before the points can be
> revealed.

Once feedback has been revealed:

- Published feedback is anonymous.
- Participant authorship is no longer available in the application.
- The facilitator can discuss the feedback with the team.
- Collection is frozen. Later submissions cannot change collecting data.

---

# Editing and Freezing

Once the retrospective moves into the discussion stage, feedback
collection is frozen.

Participants cannot continue editing or adding feedback after discussion
has started.

This protects the integrity of the meeting and ensures that the
facilitator is discussing a stable set of anonymous feedback.

A participant also cannot edit feedback after they have submitted it.

---

# Action Items

Action items are created during retrospective discussion.

This is intentional.

A facilitator discusses a feedback point with the team and, when the
team agrees that an action is needed, creates an action item.

Every new action item must belong to a retrospective. Team-level
creation without a retrospective is rejected. New action items cannot be
created after that retrospective is closed or cancelled, or after the
team is archived.

Creation always starts the item as **Open**. Status is not chosen on
create and is not advanced automatically.

An action item can contain:

- Title
- Description
- Owner (a current team member)
- Due date
- Status
- Retrospective association
- Status history comments

### Action Item Lifecycle

Working statuses:

- Open
- In Progress
- Ready for Review

Terminal statuses:

- Completed
- Cancelled

Items do not have to move through every working status. A facilitator or
owner can, for example, complete an item from Open. Some working-status
moves can also go backward. **Cancelled** is a facilitator-only
terminal state, not a step owners can choose.

Existing action items remain after their retrospective is closed. They
are not deleted and are not made read-only merely because the
retrospective ended.

Status changes only when an authorized user explicitly selects a new
status. Every real status change requires a short comment.

- Owners can move their unresolved items among allowed statuses,
  including **Completed**.
- Owners cannot cancel an item.
- Facilitators can complete or cancel, including after retrospective
  close or team archive, subject to the same transition rules.
- Completed and cancelled items cannot change status again.

---

# Action Item Visibility

Retroreflect separates action-item creation from action-item management.

### Retrospective Meeting Board

Used to **create** action items during discussion.

### Home

Shows **action items needing attention**: unresolved items owned by the
current user, limited to a short list ordered by due date.

Each card has an **Open** control to that item in the owner's inbox.
**View all** goes to the owner inbox.

### Action items (navbar)

The navbar **Action items** link is the current user's **owner inbox**
at `/participant/action_items`.

It shows that user's own items, including completed history. It is not a
team-wide list.

### Team Page

**Current action items** shows unresolved items for that team, regardless
of owner.

**View all action items** opens the team's action-item history, not the
owner inbox.

The Team page does not provide an action-item creation form.

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

Removing a team member requires confirmation.

An active team must keep at least one Facilitator. The last facilitator
cannot be removed or demoted.

The backend enforces all membership rules; hiding an action in the UI is
not sufficient authorization.

---

# Team Archiving

Teams are archived rather than hard-deleted.

A team cannot be archived while it has:

- A collecting or discussing retrospective.
- Unresolved action items.

A leftover draft retrospective is cancelled as part of archive.

Archiving a team:

- Removes all current members from the team.
- Prevents new retrospectives and new action items.
- Retains historical retrospectives.
- Retains historical action items.
- Leaves existing action items workable under their normal owner and
  facilitator rules.

The archive operation displays a clear warning before confirmation.

Example:

> Archiving removes all current members from this team and prevents new
> retrospectives. Historical retrospectives and action items are
> retained.

Restoring an archived team is not implemented.

---

# Retrospective History

Historical retrospectives are kept separate from the current team
workflow.

The application prioritizes the current retrospective and current work
rather than filling the main team screen with history.

The navigation includes a dedicated **Retrospectives** area for current
and previous retrospectives.

A team page can provide:

> View retrospective history

without listing every past retrospective on the team page itself.

---

# Application Navigation

The authenticated application has these major areas:

### Home

A workspace overview showing:

- Current / running retrospectives.
- The user's teams.
- Action items needing attention.

### Teams

Teams the user currently belongs to. A System Admin also sees every
active team here and opens teams they do not belong to from System
Administration.

### Retrospectives

Current, draft, and previous retrospectives the user can access.

### Action items

The current user's owner inbox.

### System administration

Visible only to System Admins.

### Meeting Board

The working area for a revealed retrospective.

---

# Product Experience

The authenticated Home page should answer:

> **What needs my attention right now?**

The Team page should answer:

> **What's happening with this team?**

The Retrospectives page should answer:

> **What happened in previous retrospectives?**

The Action items inbox should answer:

> **What action items are assigned to me?**

The team action-item history should answer:

> **What action items exist for this team?**

The Meeting Board should answer:

> **How do we run this retrospective?**

Sign-in, registration, and password reset introduce Retroreflect and
route people into the workspace. The authenticated Home page also
includes product-facing copy above the current work.

---

# Retrospective States

A retrospective moves through controlled states:

```text
Draft → Collecting → Discussing → Closed
```

A draft or collecting retrospective may instead be **cancelled**:

```text
Draft
  │
  ├──► Cancelled
  ▼
Collecting
  │
  ├──► Cancelled
  ▼
Discussing
  │
  ▼
Closed
```

A discussing retrospective cannot be cancelled; it must be closed. A
cancelled retrospective stays in history and keeps its sprint number.
The next retrospective for that team uses the next sprint number.

Important lifecycle principles:

- Only one running retrospective can exist for a team at a time.
- The participant roster freezes when collection begins.
- Feedback becomes immutable once discussion begins.
- Published feedback is anonymous.
- Closed and cancelled retrospectives are historical records.
- Sprint numbers are never reused for that team.

---

# Accounts and Sessions

People register with email and password and must confirm their email
before joining teams, running or joining retrospectives, or managing
action items. Unconfirmed accounts can sign in, but those workspace
actions stay blocked until confirmation.

Password reset is available from the sign-in page. Changing a password
invalidates previously issued sessions. The session created by a
successful reset remains usable.

Sign-in and password-reset requests are rate limited on the server.

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

# Visual Design

The current workspace uses the Retroreflect visual language:

- Warm cream / off-white background.
- Dark green / near-black typography.
- Coral accent color.
- Fraunces for major headings and Work Sans for UI.
- Clean cards, dotted or dashed borders, and generous whitespace.
- Rounded controls and visible focus states.

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
Archiving a team also retains existing items and leaves them workable.

### 6. Historical information should not overwhelm current work

Current retrospectives and outstanding actions should be easy to find.
Historical information belongs in dedicated areas.

### 7. Authorization is enforced on the backend

UI visibility is not a security boundary.

### 8. Keep the core workflow simple

Retroreflect should make running a retrospective easier rather than
introducing unnecessary complexity.

---

# Current Capabilities

These workflows are implemented:

- Registration, email confirmation, sign-in, sign-out, and password
  reset.
- System Administration for teams and System Admins.
- Team membership, last-facilitator protection, and team archiving.
- Team-scoped sprint numbering and generated retrospective titles.
- Draft, collecting, discussing, closed, and cancelled retrospectives.
- Participant invitations and roster freeze.
- Anonymous locked-box reveal.
- Action item creation during discussion.
- Owner inbox and team-scoped action-item history.
- Action item status history with required comments.

---

# Future Areas

Possible later work, not required for the current workflow:

- Restoring archived teams.
- Richer notifications.
- Cross-retrospective analytics.
- AI-generated insights from anonymous published feedback.
- Recurring theme detection and suggested actions.

Any future insight feature should use published anonymous feedback only
and must not receive participant identity.

---

# Development

Requirements:

- Ruby 3.2.2
- Rails 7.1
- MySQL

Setup:

    bin/setup

Create the first System Admin:

    bin/rails retroreflect:create_system_admin

Run the test suite:

    bundle exec rspec

Before adding large features, the project prioritizes:

- Clear product behavior.
- Explicit state transitions.
- Strong authorization.
- Privacy by design.
- Simple workflows.
- Automated tests.
- Small, reviewable changes.

---

## License

Retroreflect is available under the [MIT License](LICENSE).
