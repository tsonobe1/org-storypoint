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

(provide 'org-storypoint)
;;; org-storypoint.el ends here
