;;; org-storypoint-test.el --- Tests for org-storypoint -*- lexical-binding: t; -*-

(require 'ert)
(require 'org-storypoint)

;;; RED 1: PERT calculation
(ert-deftest org-storypoint-test-pert-estimate ()
  "PERT formula: (O + 4M + P) / 6 with safety factor applied."
  (let ((result (org-storypoint--estimate 1 3 8 0)))
    ;; Expected = (1 + 12 + 8) / 6 = 3.5
    ;; Sigma = (8 - 1) / 6 ≈ 1.1667
    ;; Safety 0 → 3.5 + 0 * 1.1667 = 3.5
    (should (= result 3.5))))

;;; RED 2: Safety factor applies sigma multiplier
(ert-deftest org-storypoint-test-pert-with-safety-factor ()
  "Safety factor multiplies sigma and adds to expected value."
  ;; O=1, M=3, P=8 → Expected=3.5, Sigma≈1.1667
  ;; Safety 1 → 3.5 + 1 * 1.1667 ≈ 4.6667
  ;; Safety 2 → 3.5 + 2 * 1.1667 ≈ 5.8333
  (should (< (abs (- (org-storypoint--estimate 1 3 8 1) 4.6667)) 0.001))
  (should (< (abs (- (org-storypoint--estimate 1 3 8 2) 5.8333)) 0.001)))

;;; RED 3: Format storypoint values
(ert-deftest org-storypoint-test-format ()
  "Integer points have no decimal, fractional points show one decimal."
  (should (equal (org-storypoint--format 5) "5"))
  (should (equal (org-storypoint--format 5.0) "5"))
  (should (equal (org-storypoint--format 3.5) "3.5"))
  (should (equal (org-storypoint--format 4.6667) "4.7")))

;;; RED 4: org-storypoint-set writes 7 properties to org entry
(ert-deftest org-storypoint-test-set-writes-properties ()
  "org-storypoint-set sets all 7 STORYPOINT properties on the current entry."
  (with-temp-buffer
    (org-mode)
    (insert "* Test task\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    ;; Simulate: O=2, M=5, P=13, Safety="Normal (0σ)"
    (cl-letf (((symbol-function 'org-storypoint--read)
               (let ((calls '(2 5 13)))
                 (lambda (_prompt &optional _min)
                   (pop calls))))
              ((symbol-function 'org-storypoint--completing-read-in-order)
               (lambda (_prompt _collection)
                 "Normal (0σ)")))
      (org-storypoint-set))
    (should (equal (org-entry-get nil "STORYPOINT_OPTIMISTIC") "2"))
    (should (equal (org-entry-get nil "STORYPOINT_MOST_LIKELY") "5"))
    (should (equal (org-entry-get nil "STORYPOINT_PESSIMISTIC") "13"))
    ;; Expected = (2 + 20 + 13) / 6 = 5.833...
    (should (equal (org-entry-get nil "STORYPOINT_EXPECTED") "5.8"))
    ;; Sigma = (13 - 2) / 6 = 1.833...
    (should (equal (org-entry-get nil "STORYPOINT_SIGMA") "1.8"))
    (should (equal (org-entry-get nil "STORYPOINT_SAFETY") "Normal (0σ)"))
    ;; Safety 0 → STORYPOINT = Expected = 5.8
    (should (equal (org-entry-get nil "STORYPOINT") "5.8"))))

;;; RED 6: completing-read-in-order preserves candidate order via metadata
(ert-deftest org-storypoint-test-completing-read-metadata ()
  "The collection function returns metadata with display-sort-function = identity."
  (let* ((candidates '("1" "2" "3" "5" "8"))
         collection-fn metadata sort-fn)
    (cl-letf (((symbol-function 'completing-read)
               (lambda (_prompt collection &rest _args)
                 (setq collection-fn collection)
                 "1")))
      (org-storypoint--completing-read-in-order "Test: " candidates))
    (setq metadata (funcall collection-fn "" nil 'metadata))
    (should (eq (car metadata) 'metadata))
    (setq sort-fn (cdr (assq 'display-sort-function (cdr metadata))))
    (should (eq sort-fn #'identity))))

;;; --- Issue #2: Effort assignment ---

;;; RED 7: Convert storypoint × base minutes to Effort string
(ert-deftest org-storypoint-test-effort-from-point ()
  "SP multiplied by base minutes produces H:MM effort string."
  (should (equal (org-storypoint--effort-from-point 3 5) "0:15"))
  (should (equal (org-storypoint--effort-from-point 8 10) "1:20"))
  (should (equal (org-storypoint--effort-from-point 1 1) "0:01")))

;;; RED 8: assign-efforts sets Effort on children and totals on parent
(ert-deftest org-storypoint-test-assign-efforts-flat ()
  "Assign Effort to children based on STORYPOINT, set totals on parent."
  (with-temp-buffer
    (org-mode)
    (insert "* Project\n"
            "** Task A\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 3\n"
            ":END:\n"
            "** Task B\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 5\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    ;; Select "0:05" as base time (5 minutes per SP)
    (cl-letf (((symbol-function 'org-storypoint--completing-read-in-order)
               (lambda (_prompt _collection) "0:05")))
      (org-storypoint-assign-efforts))
    ;; Task A: 3 SP × 5 min = 0:15
    (goto-char (point-min))
    (search-forward "Task A")
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "Effort") "0:15"))
    ;; Task B: 5 SP × 5 min = 0:25
    (goto-char (point-min))
    (search-forward "Task B")
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "Effort") "0:25"))
    ;; Parent: total Effort = 0:40, total SP = 8
    (goto-char (point-min))
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "Effort") "0:40"))
    (should (equal (org-entry-get nil "STORYPOINT") "8"))))

;;; RED 9: Children without STORYPOINT are skipped
(ert-deftest org-storypoint-test-assign-efforts-skips-unestimated ()
  "Children without STORYPOINT get no Effort; only estimated tasks count in totals."
  (with-temp-buffer
    (org-mode)
    (insert "* Project\n"
            "** Task A\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 3\n"
            ":END:\n"
            "** Task B\n"
            "** Task C\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 5\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (cl-letf (((symbol-function 'org-storypoint--completing-read-in-order)
               (lambda (_prompt _collection) "0:10")))
      (org-storypoint-assign-efforts))
    ;; Task B has no STORYPOINT → no Effort
    (goto-char (point-min))
    (search-forward "Task B")
    (org-back-to-heading t)
    (should (null (org-entry-get nil "Effort")))
    ;; Parent totals only from estimated tasks: SP=8, Effort=1:20
    (goto-char (point-min))
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "STORYPOINT") "8"))
    (should (equal (org-entry-get nil "Effort") "1:20"))))

;;; RED 10: assign-efforts with no children signals error
(ert-deftest org-storypoint-test-assign-efforts-no-children ()
  "Signals user-error when no child tasks have STORYPOINT."
  (with-temp-buffer
    (org-mode)
    (insert "* Empty project\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (cl-letf (((symbol-function 'org-storypoint--completing-read-in-order)
               (lambda (_prompt _collection) "0:05")))
      (should-error (org-storypoint-assign-efforts) :type 'user-error))))

;;; org-storypoint-test.el ends here
