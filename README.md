# org-storypoint

[Japanese (日本語)](README.ja.md)

Three-point storypoint estimation (PERT) for Emacs org-mode. Assign storypoints to tasks, convert them to Effort, and track progress against a burn-down line.

## Features

- **Three-point estimation** — Input Optimistic / Most Likely / Pessimistic values using a Fibonacci scale, with configurable safety factor (PERT formula)
- **Effort assignment** — Convert storypoints to org Effort properties based on a chosen base duration, with recursive tree aggregation
- **Progress tracking** — Compare completed storypoints against an ideal burn-down line derived from SCHEDULED/DEADLINE, with optional weekend exclusion
- **Effort diff check** — On task completion, compare estimated Effort vs actual clocked time and record the reason for significant deviations
- **No external dependencies** — Only requires org-mode (ships with Emacs)

## Installation

### straight.el

```elisp
(straight-use-package
 '(org-storypoint :type git :host github :repo "tsonobe1/org-storypoint"))
```

### elpaca

```elisp
(use-package org-storypoint
  :elpaca (:host github :repo "tsonobe1/org-storypoint"))
```

### Manual

Clone this repository and add the directory to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/org-storypoint")
(require 'org-storypoint)
```

## Setup

### Recommended keybindings

```elisp
(use-package org-storypoint
  :hook (org-mode . org-storypoint-mode)
  :bind (:map org-mode-map
         ("C-c s s" . org-storypoint-set)
         ("C-c s e" . org-storypoint-assign-efforts)
         ("C-c s p" . org-storypoint-progress)
         ("C-c s w" . org-storypoint-set-weekend)))
```

`org-storypoint-mode` enables automatic checks (effort diff on DONE, breakdown warnings). Interactive commands work with or without the mode.

## Example: Sprint planning

Here is a full walkthrough using a 2-week sprint for a web application.

### 1. Break down the sprint into tasks

```org
* Sprint 2026-W23  :sprint:
SCHEDULED: <2026-06-01 Mon> DEADLINE: <2026-06-12 Fri>
** User authentication
*** Login form
**** TODO Form layout and styling
**** TODO Email/password validation
**** TODO Error message display
**** TODO "Remember me" checkbox
*** OAuth integration
**** TODO Google OAuth: register app and get credentials
**** TODO Google OAuth: callback handler
**** TODO GitHub OAuth: register app and get credentials
**** TODO GitHub OAuth: callback handler
**** TODO Unify OAuth user creation flow
*** Session management
**** TODO JWT token generation
**** TODO Refresh token rotation
**** TODO Logout and token revocation
** Search improvements
*** Backend
**** TODO Add GIN index to posts.body column
**** TODO Implement ts_rank scoring
**** TODO Pagination for search results API
*** Frontend
**** TODO Search bar with debounced input
**** TODO Category filter dropdown
**** TODO Date range picker
**** TODO Empty state / no results page
**** TODO Loading skeleton
** Performance
*** Profiling
**** TODO Set up request timing middleware
**** TODO Identify top 5 slow endpoints
*** Optimization
**** TODO Add Redis caching for hot queries
**** TODO Lazy-load images on listing pages
**** TODO Enable gzip compression for API responses
```

### 2. Estimate each leaf task

Place the cursor on each leaf task (e.g., `Login form UI`) and run `org-storypoint-set`.
You will be prompted for Optimistic (O), Most Likely (M), Pessimistic (P), and a safety factor.

After estimating, the task looks like:

```org
**** TODO Form layout and styling
:PROPERTIES:
:STORYPOINT_OPTIMISTIC: 1
:STORYPOINT_MOST_LIKELY: 2
:STORYPOINT_PESSIMISTIC: 5
:STORYPOINT_EXPECTED: 2.3
:STORYPOINT_SIGMA: 0.7
:STORYPOINT_SAFETY: Normal (0σ)
:STORYPOINT: 2.3
:END:
```

After estimating all leaf tasks, the tree might look like:

```org
* Sprint 2026-W23  :sprint:
SCHEDULED: <2026-06-01 Mon> DEADLINE: <2026-06-12 Fri>
** User authentication
*** Login form
**** TODO Form layout and styling             :STORYPOINT: 2:
**** TODO Email/password validation           :STORYPOINT: 1:
**** TODO Error message display               :STORYPOINT: 1:
**** TODO "Remember me" checkbox              :STORYPOINT: 1:
*** OAuth integration
**** TODO Google OAuth: register app          :STORYPOINT: 1:
**** TODO Google OAuth: callback handler      :STORYPOINT: 3:
**** TODO GitHub OAuth: register app          :STORYPOINT: 1:
**** TODO GitHub OAuth: callback handler      :STORYPOINT: 2:
**** TODO Unify OAuth user creation flow      :STORYPOINT: 3:
*** Session management
**** TODO JWT token generation                :STORYPOINT: 2:
**** TODO Refresh token rotation              :STORYPOINT: 3:
**** TODO Logout and token revocation         :STORYPOINT: 2:
** Search improvements
*** Backend
**** TODO Add GIN index to posts.body         :STORYPOINT: 2:
**** TODO Implement ts_rank scoring           :STORYPOINT: 5:
**** TODO Pagination for search results API   :STORYPOINT: 2:
*** Frontend
**** TODO Search bar with debounced input     :STORYPOINT: 2:
**** TODO Category filter dropdown            :STORYPOINT: 3:
**** TODO Date range picker                   :STORYPOINT: 5:
**** TODO Empty state / no results page       :STORYPOINT: 1:
**** TODO Loading skeleton                    :STORYPOINT: 1:
** Performance
*** Profiling
**** TODO Set up request timing middleware    :STORYPOINT: 2:
**** TODO Identify top 5 slow endpoints       :STORYPOINT: 3:
*** Optimization
**** TODO Add Redis caching for hot queries   :STORYPOINT: 5:
**** TODO Lazy-load images on listing pages   :STORYPOINT: 2:
**** TODO Enable gzip compression             :STORYPOINT: 1:
```

### 3. Convert to Effort

Place the cursor on `Sprint 2026-W23` and run `org-storypoint-assign-efforts`.
Select a base duration (e.g., `0:15` = 15 minutes per storypoint).

The result:

- Each **leaf task** gets `Effort = STORYPOINT × 15 min` (e.g., `Form layout and styling` (2 SP) → `0:30`)
- Each **intermediate task** (e.g., `Login form`, `User authentication`) gets the sum of its children's Effort
- The **sprint heading** gets the total: `STORYPOINT: 56`, `Effort: 14:00`

### 4. Track progress daily

A few days into the sprint, run `org-storypoint-progress` on the sprint heading:

```
behind -5.2SP | pace 5.6SP/day | done 12/56 SP (21.4%)
```

This tells you:
- You're **5.2 SP behind** the ideal burn-down line
- You need to average **5.6 SP/day** to finish on time
- You've completed **12 out of 56 SP** so far

Use `org-storypoint-set-weekend` to exclude weekends if the team doesn't work Sat/Sun.

### 5. Review estimation accuracy on completion

With `org-storypoint-mode` enabled, when you mark a task DONE (e.g., `OAuth integration (Google)`), the package compares the estimated Effort against the actual clocked time:

```
Effort: 75min, Clocked: 120min, Diff: +45min. Why?
```

Type your reason (e.g., "API docs were outdated, had to reverse-engineer the flow") and it is saved to the `EFFORT_DIFF_REASON` property. This builds a record of estimation accuracy over time.

## Workflow summary

| Step | Command | What happens |
|---|---|---|
| Estimate | `org-storypoint-set` | Input O/M/P → PERT calculation → set STORYPOINT properties |
| Convert | `org-storypoint-assign-efforts` | STORYPOINT × base time → Effort on each task, with tree aggregation |
| Track | `org-storypoint-progress` | Compare done SP vs ideal burn-down → show status in minibuffer |
| Review | `org-storypoint-mode` | On DONE: check Effort vs CLOCK diff → record reason if significant |

## Customization

| Variable | Default | Description |
|---|---|---|
| `org-storypoint-scale` | `(1 2 3 5 8 13 21 34 55 89)` | Fibonacci-like scale for estimation |
| `org-storypoint-safety-options` | Normal/Safe/Very safe | Safety factor labels and σ multipliers |
| `org-storypoint-time-options` | `("0:01" ... "1:00")` | Base duration candidates |
| `org-storypoint-effort-diff-threshold` | `10` | Minutes of diff that triggers a reason prompt |
| `org-storypoint-effort-diff-property` | `"EFFORT_DIFF_REASON"` | Property name for recording reasons |
| `org-storypoint-effort-breakdown-threshold` | `30` | Minutes above which a breakdown is suggested |

## Commands

| Command | Description |
|---|---|
| `org-storypoint-set` | Three-point estimate → set STORYPOINT properties |
| `org-storypoint-assign-efforts` | Convert storypoints to Effort in subtree |
| `org-storypoint-progress` | Show progress vs ideal burn-down line |
| `org-storypoint-set-weekend` | Set weekend include/exclude for progress |
| `org-storypoint-mode` | Toggle automatic effort checks |

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
