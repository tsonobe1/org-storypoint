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

(provide 'org-storypoint)
;;; org-storypoint.el ends here
