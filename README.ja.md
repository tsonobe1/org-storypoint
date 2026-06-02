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

## ワークフロー

### 1. タスクを見積もる

タスクの見出しにカーソルを置き `org-storypoint-set` を実行。以下を順に入力します:

1. **楽観値 (O)** — 最善ケースのストーリーポイント
2. **最頻値 (M)** — 最も可能性が高いストーリーポイント
3. **悲観値 (P)** — 最悪ケースのストーリーポイント
4. **安全係数** — Normal (0σ)、Safe (1σ)、Very safe (2σ)

PERT 式で算出し、以下のプロパティが設定されます:

```org
* タスク
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

### 2. Effort に変換する

親見出しにカーソルを置き `org-storypoint-assign-efforts` を実行。基準時間（例: `0:10` = 1SP あたり10分）を選択します。

- **リーフタスク** — `Effort = STORYPOINT × 基準時間` が設定される
- **中間タスク** — 子タスクの Effort 合計が設定される
- STORYPOINT 未設定のタスクは警告が出てスキップされる
- 中間タスクの STORYPOINT と子の合計が不一致の場合、警告が出る（プロパティは上書きしない）

### 3. 進捗を確認する

親見出しに SCHEDULED と DEADLINE を設定し、`org-storypoint-progress` を実行:

```
behind -2.0SP | pace 1.0SP/day | done 3/10 SP (30.0%)
```

`org-storypoint-set-weekend` で土日を日数計算から除外できます。

### 4. 完了時に振り返る

`org-storypoint-mode` を有効にした状態でタスクを完了（TODO → DONE）すると、実績 CLOCK と見積もり Effort の差が閾値を超えた場合に理由の入力を求め、`EFFORT_DIFF_REASON` プロパティに記録します。

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
