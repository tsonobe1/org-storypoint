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

(defun org-storypoint--effort-from-point (storypoint base-minutes)
  "Return effort string like \"0:15\" for STORYPOINT and BASE-MINUTES."
  (let ((total (round (* base-minutes storypoint))))
    (format "%d:%02d" (/ total 60) (% total 60))))

(defun org-storypoint-assign-efforts ()
  "Assign Effort to child tasks based on their STORYPOINT values."
  (interactive)
  (org-back-to-heading t)
  (let* ((parent-pos (point))
         (subtree-end (save-excursion (org-end-of-subtree t) (point)))
         (base-choice (org-storypoint--completing-read-in-order
                       "Time for 1 Storypoint: "
                       org-storypoint-time-options))
         (base-minutes (org-storypoint--parse-time-to-minutes base-choice))
         (entries '())
         (total-sp 0)
         (total-effort-minutes 0))
    (save-excursion
      (goto-char parent-pos)
      (while (re-search-forward org-heading-regexp subtree-end t)
        (let ((pos (save-excursion (org-back-to-heading t) (point))))
          (unless (= pos parent-pos)
            (let ((sp (org-storypoint--get pos)))
              (when sp
                (push (cons pos sp) entries)))))))
    (unless entries
      (user-error "No child tasks with STORYPOINT found"))
    (dolist (entry entries)
      (let* ((pos (car entry))
             (sp (cdr entry))
             (effort (org-storypoint--effort-from-point sp base-minutes))
             (effort-min (org-storypoint--parse-time-to-minutes effort)))
        (save-excursion
          (goto-char pos)
          (org-set-property "Effort" effort))
        (setq total-sp (+ total-sp sp))
        (setq total-effort-minutes (+ total-effort-minutes effort-min))))
    (save-excursion
      (goto-char parent-pos)
      (let ((total (format "%d:%02d" (/ total-effort-minutes 60)
                           (% total-effort-minutes 60))))
        (org-set-property "Effort" total)
        (org-set-property "STORYPOINT" (org-storypoint--format total-sp))))))

(provide 'org-storypoint)
;;; org-storypoint.el ends here
