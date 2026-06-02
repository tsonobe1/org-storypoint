;;; org-storypoint.el --- Three-point storypoint estimation for org-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2025 tsonobe1
;; Author: tsonobe1
;; URL: https://github.com/tsonobe1/org-storypoint
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (org "9.6"))
;; Keywords: org, estimation, agile

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Storypoint-based three-point estimation (PERT) for Emacs org-mode.
;; Assign storypoints to tasks, convert them to Effort, and track progress.

;;; Code:

(require 'org)
(require 'calendar)

(defgroup org-storypoint nil
  "Storypoint estimation for org-mode."
  :group 'org
  :prefix "org-storypoint-")

(defcustom org-storypoint-scale '(1 2 3 5 8 13 21 34 55 89)
  "Fibonacci-like scale for storypoint selection."
  :type '(repeat number)
  :group 'org-storypoint)

(defcustom org-storypoint-safety-options
  '(("Normal (0σ)" . 0)
    ("Safe (1σ)" . 1)
    ("Very safe (2σ)" . 2))
  "Safety margin options for three-point estimates."
  :type '(alist :key-type string :value-type number)
  :group 'org-storypoint)

(defcustom org-storypoint-time-options
  '("0:01" "0:03" "0:05" "0:10" "0:15" "0:30" "0:45" "1:00")
  "Candidate base effort times for storypoint expansion."
  :type '(repeat string)
  :group 'org-storypoint)

(defun org-storypoint--format (point)
  "Format POINT without trailing .0 when it is an integer."
  (if (= point (floor point))
      (number-to-string (floor point))
    (format "%.1f" point)))

(defun org-storypoint--expected (optimistic most-likely pessimistic)
  "Return PERT expected value from OPTIMISTIC, MOST-LIKELY, PESSIMISTIC."
  (/ (+ optimistic (* 4 most-likely) pessimistic) 6.0))

(defun org-storypoint--sigma (optimistic pessimistic)
  "Return PERT standard deviation from OPTIMISTIC and PESSIMISTIC."
  (/ (- pessimistic optimistic) 6.0))

(defun org-storypoint--estimate (optimistic most-likely pessimistic safety-factor)
  "Return PERT estimate from OPTIMISTIC, MOST-LIKELY, PESSIMISTIC and SAFETY-FACTOR."
  (+ (org-storypoint--expected optimistic most-likely pessimistic)
     (* safety-factor (org-storypoint--sigma optimistic pessimistic))))

(defun org-storypoint--completing-read-in-order (prompt collection)
  "Read from COLLECTION with PROMPT, preserving collection order."
  (completing-read
   prompt
   (lambda (string pred action)
     (if (eq action 'metadata)
         `(metadata (display-sort-function . ,#'identity))
       (complete-with-action action collection string pred)))
   nil t))

(defun org-storypoint--read (prompt &optional min-point)
  "Read a storypoint value with PROMPT from the configured scale.
When MIN-POINT is non-nil, offer only candidates >= MIN-POINT."
  (string-to-number
   (org-storypoint--completing-read-in-order
    prompt
    (mapcar #'number-to-string
            (seq-filter (lambda (p)
                          (or (null min-point) (>= p min-point)))
                        org-storypoint-scale)))))

(defun org-storypoint-set ()
  "Prompt for three-point storypoint estimates and set org properties."
  (interactive)
  (let* ((optimistic (org-storypoint--read "Storypoint optimistic (O): "))
         (most-likely (org-storypoint--read "Storypoint most likely (M): " optimistic))
         (pessimistic (org-storypoint--read "Storypoint pessimistic (P): " most-likely)))
    (let* ((safety-label
            (org-storypoint--completing-read-in-order
             "Safety: "
             (mapcar #'car org-storypoint-safety-options)))
           (safety-factor (cdr (assoc safety-label org-storypoint-safety-options)))
           (expected (org-storypoint--expected optimistic most-likely pessimistic))
           (sigma (org-storypoint--sigma optimistic pessimistic))
           (selected (org-storypoint--estimate optimistic most-likely pessimistic safety-factor)))
      (org-set-property "STORYPOINT_OPTIMISTIC" (org-storypoint--format optimistic))
      (org-set-property "STORYPOINT_MOST_LIKELY" (org-storypoint--format most-likely))
      (org-set-property "STORYPOINT_PESSIMISTIC" (org-storypoint--format pessimistic))
      (org-set-property "STORYPOINT_EXPECTED" (org-storypoint--format expected))
      (org-set-property "STORYPOINT_SIGMA" (org-storypoint--format sigma))
      (org-set-property "STORYPOINT_SAFETY" safety-label)
      (org-set-property "STORYPOINT" (org-storypoint--format selected)))))

(defun org-storypoint--get (entry-point)
  "Get STORYPOINT as number at ENTRY-POINT, or nil if not set."
  (save-excursion
    (goto-char entry-point)
    (let ((val (org-entry-get nil "STORYPOINT")))
      (when (and val (string-match-p "^[0-9]+\\(?:\\.[0-9]+\\)?$" val))
        (string-to-number val)))))

(defun org-storypoint--parse-time-to-minutes (time-str)
  "Parse TIME-STR like \"0:05\" to minutes."
  (let* ((parts (split-string time-str ":"))
         (h (string-to-number (car parts)))
         (m (string-to-number (cadr parts))))
    (+ (* h 60) m)))

(defun org-storypoint--minutes-to-effort (minutes)
  "Format MINUTES as effort string \"H:MM\"."
  (format "%d:%02d" (/ minutes 60) (% minutes 60)))

(defun org-storypoint--effort-from-point (storypoint base-minutes)
  "Return effort string like \"0:15\" for STORYPOINT and BASE-MINUTES."
  (org-storypoint--minutes-to-effort (round (* base-minutes storypoint))))

(defun org-storypoint--direct-children (parent-pos)
  "Return list of markers for direct children of PARENT-POS."
  (let ((children '())
        (parent-level (save-excursion
                        (goto-char parent-pos)
                        (org-current-level))))
    (save-excursion
      (goto-char parent-pos)
      (let ((subtree-end (save-excursion (org-end-of-subtree t) (point))))
        (while (re-search-forward org-heading-regexp subtree-end t)
          (save-excursion
            (org-back-to-heading t)
            (unless (= (point) parent-pos)
              (when (= (org-current-level) (1+ parent-level))
                (push (point-marker) children)))))))
    (nreverse children)))

(defun org-storypoint--collect-tree (marker base-minutes)
  "Recursively compute SP and effort-minutes for subtree at MARKER.
Return (sp . effort-minutes).  Set Effort property on each entry.
For leaf tasks, Effort = SP * base-minutes.
For intermediate tasks, Effort = sum of children's efforts."
  (let ((children (org-storypoint--direct-children (marker-position marker))))
    (if (null children)
        ;; Leaf task
        (let ((sp (org-storypoint--get (marker-position marker))))
          (if sp
              (let* ((effort (org-storypoint--effort-from-point sp base-minutes))
                     (effort-min (org-storypoint--parse-time-to-minutes effort)))
                (save-excursion
                  (goto-char marker)
                  (org-set-property "Effort" effort))
                (cons sp effort-min))
            (message "Warning: '%s' has no STORYPOINT (skipped)"
                     (save-excursion (goto-char marker)
                                     (org-get-heading t t t t)))
            (cons 0 0)))
      ;; Intermediate task — recurse into children
      (let ((total-sp 0)
            (total-effort-min 0))
        (dolist (child children)
          (let ((result (org-storypoint--collect-tree child base-minutes)))
            (setq total-sp (+ total-sp (car result)))
            (setq total-effort-min (+ total-effort-min (cdr result)))))
        (when (> total-sp 0)
          (save-excursion
            (goto-char marker)
            (let ((own-sp (org-storypoint--get (marker-position marker))))
              (when (and own-sp (/= own-sp total-sp))
                (message "Note: '%s' has STORYPOINT %s but children sum to %s. Using children sum."
                         (org-get-heading t t t t)
                         (org-storypoint--format own-sp)
                         (org-storypoint--format total-sp))))
            (org-set-property "Effort"
                              (org-storypoint--minutes-to-effort total-effort-min))))
        (cons total-sp total-effort-min)))))

(defun org-storypoint-assign-efforts ()
  "Assign Effort to child tasks based on their STORYPOINT values."
  (interactive)
  (org-back-to-heading t)
  (let* ((parent-pos (point))
         (base-choice (org-storypoint--completing-read-in-order
                       "Time for 1 Storypoint: "
                       org-storypoint-time-options))
         (base-minutes (org-storypoint--parse-time-to-minutes base-choice))
         (parent-marker (point-marker))
         (children (org-storypoint--direct-children parent-pos)))
    (unless children
      (user-error "No child headings found"))
    (let ((total-sp 0)
          (total-effort-min 0))
      (dolist (child children)
        (let ((result (org-storypoint--collect-tree child base-minutes)))
          (setq total-sp (+ total-sp (car result)))
          (setq total-effort-min (+ total-effort-min (cdr result)))))
      (when (= total-sp 0)
        (user-error "No child tasks with STORYPOINT found"))
      (save-excursion
        (goto-char parent-marker)
        (org-set-property "Effort"
                          (org-storypoint--minutes-to-effort total-effort-min))
        (org-set-property "STORYPOINT" (org-storypoint--format total-sp))))))

(defun org-storypoint--done-sp-in-tree ()
  "Return total STORYPOINT of DONE entries in current subtree."
  (let ((total 0))
    (org-map-entries
     (lambda ()
       (let ((sp (org-storypoint--get (point))))
         (when sp (setq total (+ total sp)))))
     "TODO=\"DONE\"" 'tree)
    total))

(defun org-storypoint--today-absolute ()
  "Return today as an absolute date."
  (pcase-let ((`(,_sec ,_min ,_hour ,day ,month ,year . ,_)
               (decode-time (current-time))))
    (calendar-absolute-from-gregorian (list month day year))))

(defun org-storypoint--timestamp-to-absolute (timestamp)
  "Return absolute date for org TIMESTAMP string, or nil."
  (when timestamp
    (let* ((parts (org-parse-time-string timestamp))
           (day (nth 3 parts))
           (month (nth 4 parts))
           (year (nth 5 parts)))
      (when (and day month year)
        (calendar-absolute-from-gregorian (list month day year))))))

(defun org-storypoint--weekend-p (absolute-date)
  "Return non-nil when ABSOLUTE-DATE is Saturday or Sunday."
  (memq (calendar-day-of-week (calendar-gregorian-from-absolute absolute-date))
        '(0 6)))

(defun org-storypoint--count-days (start end include-weekend)
  "Count days from START to END inclusive.
When INCLUDE-WEEKEND is nil, skip Saturdays and Sundays."
  (let ((count 0))
    (when (<= start end)
      (dotimes (offset (1+ (- end start)))
        (let ((day (+ start offset)))
          (when (or include-weekend
                    (not (org-storypoint--weekend-p day)))
            (setq count (1+ count))))))
    count))

(defun org-storypoint--status-label (gap)
  "Return progress status label for GAP storypoints."
  (cond
   ((< gap -0.05) "behind")
   ((> gap 0.05) "ahead")
   (t "on track")))

(defun org-storypoint--plan-summary (total-sp done-sp)
  "Return ideal progress summary string, or nil if no schedule."
  (let* ((start (org-storypoint--timestamp-to-absolute
                 (org-entry-get nil "SCHEDULED")))
         (deadline (org-storypoint--timestamp-to-absolute
                    (org-entry-get nil "DEADLINE")))
         (weekend (or (org-entry-get nil "STORYPOINT_WEEKEND") "include"))
         (include-weekend (not (string= weekend "exclude"))))
    (when (and start deadline (> total-sp 0))
      (let* ((today (org-storypoint--today-absolute))
             (total-days (org-storypoint--count-days start deadline include-weekend))
             (elapsed-end (min deadline today))
             (elapsed-days (if (< today start) 0
                             (org-storypoint--count-days start elapsed-end include-weekend))))
        (when (> total-days 0)
          (let* ((sp-per-day (/ total-sp (float total-days)))
                 (ideal-sp (min total-sp (* sp-per-day elapsed-days)))
                 (gap (- done-sp ideal-sp)))
            (format "%s %+.1fSP | pace %.1fSP/day"
                    (org-storypoint--status-label gap)
                    gap
                    sp-per-day)))))))

(defun org-storypoint-set-weekend ()
  "Set STORYPOINT_WEEKEND property on current entry."
  (interactive)
  (let ((choice (org-storypoint--completing-read-in-order
                 "Weekend days: "
                 '("include" "exclude"))))
    (org-set-property "STORYPOINT_WEEKEND" choice)))

(defun org-storypoint-progress ()
  "Show storypoint progress for the current subtree.
Return the result string."
  (interactive)
  (org-back-to-heading t)
  (let* ((total-sp (or (org-storypoint--get (point)) 0)))
    (when (= total-sp 0)
      (user-error "No STORYPOINT set on this entry"))
    (let* ((done-sp (org-storypoint--done-sp-in-tree))
         (sp-pct (if (> total-sp 0)
                     (* 100.0 (/ done-sp (float total-sp)))
                   0.0))
         (plan (org-storypoint--plan-summary total-sp done-sp))
         (sp-part (format "done %s/%s SP (%.1f%%)"
                          (org-storypoint--format done-sp)
                          (org-storypoint--format total-sp)
                          sp-pct))
         (result (if plan
                     (format "%s | %s" plan sp-part)
                   sp-part)))
      (message "%s" result)
      (kill-new result)
      result)))

(provide 'org-storypoint)
;;; org-storypoint.el ends here
