# org-storypoint

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

## Workflow

### 1. Estimate tasks

Place the cursor on a task heading and run `org-storypoint-set`. You will be prompted for:

1. **Optimistic (O)** — best-case storypoints
2. **Most Likely (M)** — most probable storypoints
3. **Pessimistic (P)** — worst-case storypoints
4. **Safety factor** — Normal (0σ), Safe (1σ), or Very safe (2σ)

The command computes the PERT estimate and sets these properties:

```org
* Task
:PROPERTIES:
:STORYPOINT_OPTIMISTIC: 2
:STORYPOINT_MOST_LIKELY: 5
:STORYPOINT_PESSIMISTIC: 13
:STORYPOINT_EXPECTED: 5.8
:STORYPOINT_SIGMA: 1.8
:STORYPOINT_SAFETY: Normal (0σ)
:STORYPOINT: 5.8
:END:
```

### 2. Convert to Effort

Place the cursor on the parent heading and run `org-storypoint-assign-efforts`. Select a base duration (e.g., `0:10` = 10 minutes per storypoint).

- **Leaf tasks** get `Effort = STORYPOINT × base duration`
- **Intermediate tasks** get the sum of their children's Effort
- Tasks without STORYPOINT are warned and skipped
- If an intermediate task's own STORYPOINT disagrees with its children's sum, a warning is shown

### 3. Track progress

Set SCHEDULED and DEADLINE on the parent heading, then run `org-storypoint-progress`:

```
behind -2.0SP | pace 1.0SP/day | done 3/10 SP (30.0%)
```

Use `org-storypoint-set-weekend` to exclude weekends from the day count.

### 4. Review on completion

With `org-storypoint-mode` enabled, completing a task (TODO → DONE) checks if the clocked time differs significantly from the estimated Effort. If so, you are prompted to record a reason in the `EFFORT_DIFF_REASON` property.

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
