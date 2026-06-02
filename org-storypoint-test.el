;;; org-storypoint-test.el --- Tests for org-storypoint -*- lexical-binding: t; -*-

(require 'ert)
(require 'org-storypoint)

;;; --- 3点見積もり ---

(ert-deftest org-storypoint-test/safety-0のとき-pert期待値が返る ()
  "安全係数0でPERT加重平均が正しく計算される。"
  (let ((result (org-storypoint--estimate 1 3 8 0)))
    (should (= result 3.5))))

(ert-deftest org-storypoint-test/safety-1のとき-sigmaが加算される ()
  "安全係数1でExpected+1σが返る。"
  (should (< (abs (- (org-storypoint--estimate 1 3 8 1) 4.6667)) 0.001)))

(ert-deftest org-storypoint-test/safety-2のとき-sigma2倍が加算される ()
  "安全係数2でExpected+2σが返る。"
  (should (< (abs (- (org-storypoint--estimate 1 3 8 2) 5.8333)) 0.001)))

(ert-deftest org-storypoint-test/整数ポイントのとき-小数点なしで表示される ()
  "整数値は .0 なしでフォーマットされる。"
  (should (equal (org-storypoint--format 5) "5"))
  (should (equal (org-storypoint--format 5.0) "5")))

(ert-deftest org-storypoint-test/小数ポイントのとき-小数点1桁で表示される ()
  "小数値は1桁でフォーマットされる。"
  (should (equal (org-storypoint--format 3.5) "3.5"))
  (should (equal (org-storypoint--format 4.6667) "4.7")))

(ert-deftest org-storypoint-test/見積もり実行のとき-7つのプロパティが設定される ()
  "org-storypoint-setで7つのSTORYPOINTプロパティがエントリに設定される。"
  (with-temp-buffer
    (org-mode)
    (insert "* Test task\n")
    (goto-char (point-min))
    (org-back-to-heading t)
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
    (should (equal (org-entry-get nil "STORYPOINT_EXPECTED") "5.8"))
    (should (equal (org-entry-get nil "STORYPOINT_SIGMA") "1.8"))
    (should (equal (org-entry-get nil "STORYPOINT_SAFETY") "Normal (0σ)"))
    (should (equal (org-entry-get nil "STORYPOINT") "5.8"))))

(ert-deftest org-storypoint-test/completing-readのとき-metadataで順序が保持される ()
  "補完候補にdisplay-sort-function=identityのmetadataが付与される。"
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

;;; --- Effort一括変換 ---

(ert-deftest org-storypoint-test/SP掛ける基準時間のとき-effort文字列が返る ()
  "ストーリーポイント×基準分数でH:MM形式のEffortが返る。"
  (should (equal (org-storypoint--effort-from-point 3 5) "0:15"))
  (should (equal (org-storypoint--effort-from-point 8 10) "1:20"))
  (should (equal (org-storypoint--effort-from-point 1 1) "0:01")))

(ert-deftest org-storypoint-test/フラットな子タスクのとき-各子と親にeffortが設定される ()
  "直下の子タスクにEffortが設定され、親に合計が設定される。"
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
    (cl-letf (((symbol-function 'org-storypoint--completing-read-in-order)
               (lambda (_prompt _collection) "0:05")))
      (org-storypoint-assign-efforts))
    (goto-char (point-min))
    (search-forward "Task A")
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "Effort") "0:15"))
    (goto-char (point-min))
    (search-forward "Task B")
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "Effort") "0:25"))
    (goto-char (point-min))
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "Effort") "0:40"))
    (should (equal (org-entry-get nil "STORYPOINT") "8"))))

(ert-deftest org-storypoint-test/SP未設定の子のとき-effortなしでスキップされる ()
  "STORYPOINT未設定の子タスクにはEffortが付かず、合計にも含まれない。"
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
    (goto-char (point-min))
    (search-forward "Task B")
    (org-back-to-heading t)
    (should (null (org-entry-get nil "Effort")))
    (goto-char (point-min))
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "STORYPOINT") "8"))
    (should (equal (org-entry-get nil "Effort") "1:20"))))

(ert-deftest org-storypoint-test/子見出しなしのとき-user-errorになる ()
  "子見出しがない場合にuser-errorが発生する。"
  (with-temp-buffer
    (org-mode)
    (insert "* Empty project\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (cl-letf (((symbol-function 'org-storypoint--completing-read-in-order)
               (lambda (_prompt _collection) "0:05")))
      (should-error (org-storypoint-assign-efforts) :type 'user-error))))

;;; --- ツリー集約 ---

(ert-deftest org-storypoint-test/ネストしたツリーのとき-リーフから再帰的にeffortが計算される ()
  "リーフのSPからEffortが計算され、中間タスクに子の合計が設定される。"
  (with-temp-buffer
    (org-mode)
    (insert "* Project\n"
            "** Task 1\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 3\n"
            ":END:\n"
            "** Task 2\n"
            "*** Sub 2-1\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 2\n"
            ":END:\n"
            "*** Sub 2-2\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 5\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (cl-letf (((symbol-function 'org-storypoint--completing-read-in-order)
               (lambda (_prompt _collection) "0:10")))
      (org-storypoint-assign-efforts))
    (goto-char (point-min))
    (search-forward "Task 1")
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "Effort") "0:30"))
    (goto-char (point-min))
    (search-forward "Sub 2-1")
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "Effort") "0:20"))
    (goto-char (point-min))
    (search-forward "Sub 2-2")
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "Effort") "0:50"))
    (goto-char (point-min))
    (search-forward "Task 2")
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "Effort") "1:10"))
    (goto-char (point-min))
    (org-back-to-heading t)
    (should (equal (org-entry-get nil "STORYPOINT") "10"))
    (should (equal (org-entry-get nil "Effort") "1:40"))))

(ert-deftest org-storypoint-test/SP未設定リーフのとき-タスク名付き警告が出る ()
  "STORYPOINT未設定のリーフタスクはタスク名付きで警告される。"
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
    (let ((warning-messages '()))
      (cl-letf (((symbol-function 'org-storypoint--completing-read-in-order)
                 (lambda (_prompt _collection) "0:10"))
                ((symbol-function 'message)
                 (lambda (fmt &rest args)
                   (push (apply #'format fmt args) warning-messages))))
        (org-storypoint-assign-efforts))
      (should (cl-some (lambda (msg) (string-match-p "Task B" msg))
                       warning-messages)))))

(ert-deftest org-storypoint-test/中間タスクのSPが子の合計と不一致のとき-警告が出てプロパティは保持される ()
  "中間タスクのSTORYPOINTと子の合計が異なる場合、警告が出るがプロパティは上書きされない。"
  (with-temp-buffer
    (org-mode)
    (insert "* Project\n"
            "** Task 2\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 8\n"
            ":END:\n"
            "*** Sub 2-1\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 5\n"
            ":END:\n"
            "*** Sub 2-2\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 5\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (let ((warning-messages '()))
      (cl-letf (((symbol-function 'org-storypoint--completing-read-in-order)
                 (lambda (_prompt _collection) "0:10"))
                ((symbol-function 'message)
                 (lambda (fmt &rest args)
                   (push (apply #'format fmt args) warning-messages))))
        (org-storypoint-assign-efforts))
      (should (cl-some (lambda (msg)
                         (and (string-match-p "Task 2" msg)
                              (string-match-p "8" msg)
                              (string-match-p "10" msg)))
                       warning-messages))
      (goto-char (point-min))
      (search-forward "Task 2")
      (org-back-to-heading t)
      (should (equal (org-entry-get nil "STORYPOINT") "8")))))

;;; --- 進捗計算 ---

(ert-deftest org-storypoint-test/スケジュールなしのとき-完了率のみ表示される ()
  "SCHEDULED/DEADLINEなしでSP完了率が表示される。"
  (with-temp-buffer
    (org-mode)
    (insert "* Project\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 10\n"
            ":END:\n"
            "** DONE Task A\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 3\n"
            ":END:\n"
            "** TODO Task B\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 7\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (let ((result (org-storypoint-progress)))
      (should (string-match-p "done 3/10 SP" result))
      (should (string-match-p "30\\.0%" result)))))

(ert-deftest org-storypoint-test/スケジュールありで遅れのとき-behind表示とペースが出る ()
  "SCHEDULED/DEADLINEがあり理想線より遅れている場合、behindとpaceが表示される。"
  (with-temp-buffer
    (org-mode)
    (insert "* Project\n"
            "SCHEDULED: <2026-06-01> DEADLINE: <2026-06-10>\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 10\n"
            ":END:\n"
            "** DONE Task A\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 3\n"
            ":END:\n"
            "** TODO Task B\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 7\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (cl-letf (((symbol-function 'org-storypoint--today-absolute)
               (lambda () (calendar-absolute-from-gregorian '(6 5 2026)))))
      (let ((result (org-storypoint-progress)))
        (should (string-match-p "behind" result))
        (should (string-match-p "-2\\.0SP" result))
        (should (string-match-p "pace" result))))))

(ert-deftest org-storypoint-test/土日除外のとき-平日のみで日数計算される ()
  "STORYPOINT_WEEKEND=excludeで土日がスキップされ正しいペースが計算される。"
  (with-temp-buffer
    (org-mode)
    (insert "* Project\n"
            "SCHEDULED: <2026-06-01> DEADLINE: <2026-06-12>\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 10\n"
            ":STORYPOINT_WEEKEND: exclude\n"
            ":END:\n"
            "** DONE Task A\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 5\n"
            ":END:\n"
            "** TODO Task B\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 5\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (cl-letf (((symbol-function 'org-storypoint--today-absolute)
               (lambda () (calendar-absolute-from-gregorian '(6 5 2026)))))
      (let ((result (org-storypoint-progress)))
        (should (string-match-p "on track" result))))))

(ert-deftest org-storypoint-test/進捗表示のとき-結果がkill-ringにコピーされる ()
  "進捗結果文字列がkill-ringに追加される。"
  (with-temp-buffer
    (org-mode)
    (insert "* Project\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 8\n"
            ":END:\n"
            "** DONE Task A\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 3\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (let ((result (org-storypoint-progress)))
      (should (equal (current-kill 0) result)))))

(ert-deftest org-storypoint-test/SP未設定エントリのとき-進捗計算でuser-errorになる ()
  "STORYPOINTが設定されていないエントリでuser-errorが発生する。"
  (with-temp-buffer
    (org-mode)
    (insert "* Project without SP\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (should-error (org-storypoint-progress) :type 'user-error)))

(ert-deftest org-storypoint-test/全タスクDONEのとき-100パーセント表示される ()
  "全子タスクがDONEのとき完了率100%が表示される。"
  (with-temp-buffer
    (org-mode)
    (insert "* Project\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 5\n"
            ":END:\n"
            "** DONE Task A\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 3\n"
            ":END:\n"
            "** DONE Task B\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 2\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (let ((result (org-storypoint-progress)))
      (should (string-match-p "done 5/5 SP" result))
      (should (string-match-p "100\\.0%" result)))))

(ert-deftest org-storypoint-test/プロジェクト開始前のとき-elapsed-0で計算される ()
  "SCHEDULEDが未来日のとき、経過日数0で理想SPも0になる。"
  (with-temp-buffer
    (org-mode)
    (insert "* Project\n"
            "SCHEDULED: <2026-07-01> DEADLINE: <2026-07-10>\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 10\n"
            ":END:\n"
            "** TODO Task A\n"
            ":PROPERTIES:\n"
            ":STORYPOINT: 10\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (cl-letf (((symbol-function 'org-storypoint--today-absolute)
               (lambda () (calendar-absolute-from-gregorian '(6 15 2026)))))
      (let ((result (org-storypoint-progress)))
        (should (string-match-p "on track" result))))))

;;; --- Effort差異チェック + minor-mode ---

(ert-deftest org-storypoint-test/モードOFFのとき-DONE遷移で差異チェックが発火しない ()
  "org-storypoint-mode無効時はDONE遷移で理由入力を求められない。"
  (with-temp-buffer
    (org-mode)
    (org-storypoint-mode -1)
    (insert "* TODO Task\n"
            ":PROPERTIES:\n"
            ":Effort: 0:10\n"
            ":END:\n"
            ":LOGBOOK:\n"
            "CLOCK: [2026-06-01 Mon 09:00]--[2026-06-01 Mon 09:30] =>  0:30\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (let ((read-string-called nil))
      (cl-letf (((symbol-function 'read-string)
                 (lambda (&rest _) (setq read-string-called t) "test")))
        (org-todo "DONE"))
      (should-not read-string-called))))

(ert-deftest org-storypoint-test/モードONで差異閾値超のとき-理由が記録される ()
  "org-storypoint-mode有効時にEffortとCLOCKの差が閾値超で理由がプロパティに記録される。"
  (with-temp-buffer
    (org-mode)
    (org-storypoint-mode 1)
    (insert "* TODO Task\n"
            ":PROPERTIES:\n"
            ":Effort: 0:10\n"
            ":END:\n"
            ":LOGBOOK:\n"
            "CLOCK: [2026-06-01 Mon 09:00]--[2026-06-01 Mon 09:30] =>  0:30\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (cl-letf (((symbol-function 'read-string)
               (lambda (&rest _) "took longer than expected")))
      (org-todo "DONE"))
    (should (equal (org-entry-get nil "EFFORT_DIFF_REASON")
                   "took longer than expected"))
    (org-storypoint-mode -1)))

(ert-deftest org-storypoint-test/モードONでeffort閾値超のとき-分割推奨メッセージが出る ()
  "org-storypoint-mode有効時にEffort設定が閾値以上でブレイクダウン警告が表示される。"
  (with-temp-buffer
    (org-mode)
    (org-storypoint-mode 1)
    (insert "* Task\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (let ((warning-messages '()))
      (cl-letf (((symbol-function 'message)
                 (lambda (fmt &rest args)
                   (push (apply #'format fmt args) warning-messages))))
        (org-set-effort nil "0:45"))
      (should (cl-some (lambda (msg) (string-match-p "breaking.*down\\|break.*down" msg))
                       warning-messages)))
    (org-storypoint-mode -1)))

(ert-deftest org-storypoint-test/モードON後OFFのとき-差異チェックが発火しなくなる ()
  "org-storypoint-modeをON→OFFにした後、DONE遷移で差異チェックが発火しない。"
  (with-temp-buffer
    (org-mode)
    (org-storypoint-mode 1)
    (org-storypoint-mode -1)
    (insert "* TODO Task\n"
            ":PROPERTIES:\n"
            ":Effort: 0:10\n"
            ":END:\n"
            ":LOGBOOK:\n"
            "CLOCK: [2026-06-01 Mon 09:00]--[2026-06-01 Mon 09:30] =>  0:30\n"
            ":END:\n")
    (goto-char (point-min))
    (org-back-to-heading t)
    (let ((read-string-called nil))
      (cl-letf (((symbol-function 'read-string)
                 (lambda (&rest _) (setq read-string-called t) "test")))
        (org-todo "DONE"))
      (should-not read-string-called))))

;;; org-storypoint-test.el ends here
