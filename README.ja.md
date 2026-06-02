# org-storypoint

[English](README.md)

Emacs org-mode 向けの3点見積もり（PERT式）パッケージ。タスクにストーリーポイントを割り当て、Effort に変換し、バーンダウンラインに対する進捗を追跡します。

## 特徴

- **3点見積もり** — フィボナッチスケールで楽観値/最頻値/悲観値を入力し、安全係数を選択（PERT式で算出）
- **Effort 一括変換** — 基準時間を選んでストーリーポイントを org の Effort プロパティに変換。再帰的なツリー集約に対応
- **進捗追跡** — SCHEDULED/DEADLINE から理想バーンダウンラインを算出し、完了済み SP と比較。土日除外オプションあり
- **Effort 差異チェック** — タスク完了時に見積もり Effort と実績 CLOCK を比較し、大きな乖離があれば理由を記録
- **外部依存なし** — org-mode（Emacs 同梱）のみ必要

## インストール

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

### 手動

リポジトリをクローンし、`load-path` に追加:

```elisp
(add-to-list 'load-path "/path/to/org-storypoint")
(require 'org-storypoint)
```

## セットアップ

### 推奨キーバインド

```elisp
(use-package org-storypoint
  :hook (org-mode . org-storypoint-mode)
  :bind (:map org-mode-map
         ("C-c s s" . org-storypoint-set)
         ("C-c s e" . org-storypoint-assign-efforts)
         ("C-c s p" . org-storypoint-progress)
         ("C-c s w" . org-storypoint-set-weekend)))
```

`org-storypoint-mode` を有効にすると自動チェック（DONE 時の Effort 差異確認、ブレイクダウン警告）が動作します。コマンド自体はモード無効でも使えます。

## 使用例: スプリント計画

Webアプリ開発の2週間スプリントを例に、全ワークフローを紹介します。

### 1. スプリントをタスクに分解する

```org
* Sprint 2026-W23  :sprint:
SCHEDULED: <2026-06-01 Mon> DEADLINE: <2026-06-12 Fri>
** ユーザー認証
*** ログインフォーム
**** TODO フォームレイアウトとスタイリング
**** TODO メール/パスワードバリデーション
**** TODO エラーメッセージ表示
**** TODO 「ログイン状態を保持」チェックボックス
*** OAuth連携
**** TODO Google OAuth: アプリ登録と認証情報取得
**** TODO Google OAuth: コールバックハンドラ
**** TODO GitHub OAuth: アプリ登録と認証情報取得
**** TODO GitHub OAuth: コールバックハンドラ
**** TODO OAuthユーザー作成フローの統一
*** セッション管理
**** TODO JWTトークン生成
**** TODO リフレッシュトークンローテーション
**** TODO ログアウトとトークン失効
** 検索機能改善
*** バックエンド
**** TODO posts.bodyカラムにGINインデックス追加
**** TODO ts_rankスコアリング実装
**** TODO 検索結果APIのページネーション
*** フロントエンド
**** TODO デバウンス付き検索バー
**** TODO カテゴリフィルタドロップダウン
**** TODO 日付範囲ピッカー
**** TODO 検索結果なし画面
**** TODO ローディングスケルトン
** パフォーマンス
*** プロファイリング
**** TODO リクエストタイミングミドルウェア設置
**** TODO 遅いエンドポイントTop5の特定
*** 最適化
**** TODO ホットクエリのRedisキャッシュ追加
**** TODO 一覧ページの画像遅延読み込み
**** TODO APIレスポンスのgzip圧縮有効化
```

### 2. リーフタスクを見積もる

各リーフタスク（例: `ログインフォームUI`）にカーソルを置き `org-storypoint-set` を実行。
楽観値 (O)、最頻値 (M)、悲観値 (P)、安全係数を入力します。

見積もり後のタスク:

```org
**** TODO フォームレイアウトとスタイリング
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

全リーフタスクを見積もった状態:

```org
* Sprint 2026-W23  :sprint:
SCHEDULED: <2026-06-01 Mon> DEADLINE: <2026-06-12 Fri>
** ユーザー認証
*** ログインフォーム
**** TODO フォームレイアウトとスタイリング    :STORYPOINT: 2:
**** TODO メール/パスワードバリデーション    :STORYPOINT: 1:
**** TODO エラーメッセージ表示               :STORYPOINT: 1:
**** TODO 「ログイン状態を保持」             :STORYPOINT: 1:
*** OAuth連携
**** TODO Google OAuth: アプリ登録           :STORYPOINT: 1:
**** TODO Google OAuth: コールバック         :STORYPOINT: 3:
**** TODO GitHub OAuth: アプリ登録           :STORYPOINT: 1:
**** TODO GitHub OAuth: コールバック         :STORYPOINT: 2:
**** TODO OAuthユーザー作成フロー統一        :STORYPOINT: 3:
*** セッション管理
**** TODO JWTトークン生成                    :STORYPOINT: 2:
**** TODO リフレッシュトークンローテーション :STORYPOINT: 3:
**** TODO ログアウトとトークン失効           :STORYPOINT: 2:
** 検索機能改善
*** バックエンド
**** TODO GINインデックス追加                :STORYPOINT: 2:
**** TODO ts_rankスコアリング実装            :STORYPOINT: 5:
**** TODO 検索結果APIページネーション        :STORYPOINT: 2:
*** フロントエンド
**** TODO デバウンス付き検索バー             :STORYPOINT: 2:
**** TODO カテゴリフィルタドロップダウン      :STORYPOINT: 3:
**** TODO 日付範囲ピッカー                   :STORYPOINT: 5:
**** TODO 検索結果なし画面                   :STORYPOINT: 1:
**** TODO ローディングスケルトン             :STORYPOINT: 1:
** パフォーマンス
*** プロファイリング
**** TODO リクエストタイミングミドルウェア    :STORYPOINT: 2:
**** TODO 遅いエンドポイントTop5特定         :STORYPOINT: 3:
*** 最適化
**** TODO Redisキャッシュ追加                :STORYPOINT: 5:
**** TODO 画像遅延読み込み                   :STORYPOINT: 2:
**** TODO gzip圧縮有効化                     :STORYPOINT: 1:
```

### 3. Effort に変換する

`Sprint 2026-W23` にカーソルを置き `org-storypoint-assign-efforts` を実行。
基準時間を選択します（例: `0:15` = 1SP あたり15分）。

結果:

- 各 **リーフタスク** に `Effort = STORYPOINT × 15分` が設定される（例: `フォームレイアウトとスタイリング` (2 SP) → `0:30`）
- 各 **中間タスク**（例: `ログインフォーム`、`ユーザー認証`）に子の Effort 合計が設定される
- **スプリント見出し** に全体の合計が設定される: `STORYPOINT: 56`, `Effort: 14:00`

### 4. 毎日の進捗確認

スプリント数日目に `org-storypoint-progress` をスプリント見出しで実行:

```
behind -5.2SP | pace 5.6SP/day | done 12/56 SP (21.4%)
```

これは以下を意味します:
- 理想バーンダウンラインから **5.2 SP 遅れている**
- 期日に間に合うには平均 **5.6 SP/日** のペースが必要
- 現在 **56 SP 中 12 SP** を完了

チームが土日休みなら `org-storypoint-set-weekend` で土日を日数計算から除外できます。

### 5. 完了時の見積もり精度振り返り

`org-storypoint-mode` を有効にした状態でタスクを DONE にすると（例: `OAuth連携（Google）`）、見積もり Effort と実績 CLOCK の差をチェック:

```
Effort: 75min, Clocked: 120min, Diff: +45min. Why?
```

理由を入力すると（例: "APIドキュメントが古く、実装を逆引きする必要があった"）`EFFORT_DIFF_REASON` プロパティに記録されます。これにより見積もり精度の改善記録が蓄積されます。

## ワークフローまとめ

| ステップ | コマンド | 動作 |
|---|---|---|
| 見積もり | `org-storypoint-set` | O/M/P 入力 → PERT 計算 → STORYPOINT プロパティ設定 |
| 変換 | `org-storypoint-assign-efforts` | STORYPOINT × 基準時間 → Effort に変換（ツリー集約あり） |
| 進捗確認 | `org-storypoint-progress` | 完了 SP vs 理想バーンダウン → ステータスをミニバッファに表示 |
| 振り返り | `org-storypoint-mode` | DONE 時: Effort vs CLOCK 差異チェック → 理由を記録 |

## カスタマイズ

| 変数 | デフォルト | 説明 |
|---|---|---|
| `org-storypoint-scale` | `(1 2 3 5 8 13 21 34 55 89)` | 見積もりに使うフィボナッチスケール |
| `org-storypoint-safety-options` | Normal/Safe/Very safe | 安全係数のラベルとσ倍率 |
| `org-storypoint-time-options` | `("0:01" ... "1:00")` | 基準時間の候補 |
| `org-storypoint-effort-diff-threshold` | `10` | Effort 差異で理由を聞く閾値（分） |
| `org-storypoint-effort-diff-property` | `"EFFORT_DIFF_REASON"` | 差異理由を記録するプロパティ名 |
| `org-storypoint-effort-breakdown-threshold` | `30` | タスク分割を推奨する Effort 閾値（分） |

## コマンド一覧

| コマンド | 説明 |
|---|---|
| `org-storypoint-set` | 3点見積もり → STORYPOINT プロパティ設定 |
| `org-storypoint-assign-efforts` | サブツリーの SP を Effort に一括変換 |
| `org-storypoint-progress` | 理想バーンダウンに対する進捗表示 |
| `org-storypoint-set-weekend` | 進捗計算の土日含む/除外を設定 |
| `org-storypoint-mode` | 自動チェック機能のトグル |

## ライセンス

GPL-3.0-or-later。[LICENSE](LICENSE) を参照。
