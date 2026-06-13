# JSON Release Reflection Procedure

- 対象: `ryokyaku_swipe`
- 対象ファイル: `assets/quiz_data.json`
- 目的: 既存公開問題を変更せず、各カテゴリを100問化した管理台帳を安全にJSONへ反映する

## 保護対象
- `part1`: `P1-001` から `P1-050`
- `part2`: `P2-001` から `P2-050`
- `part3`: `P3-001` から `P3-050`
- `part4`: `P4-001` から `P4-050`
- `part5`: `P5-001` から `P5-050`

上記50問は既存公開問題として扱い、原則として問題文・正誤・解説を変更しない。

## 反映元
- `docs/part1_question_bank_template.csv`
- `docs/part2_question_bank_template.csv`
- `docs/part3_question_bank_template.csv`
- `docs/part4_question_bank_template.csv`
- `docs/part5_question_bank_template.csv`

反映対象は以下を満たす行のみとする。
- `status = approved`
- `app_ready = yes`

## 反映ルール
1. 各カテゴリとも、既存公開50問は現行JSONの先頭50問をそのまま保持する。
2. 各カテゴリの51問目以降は、対応するCSVの `P*-051` 以降から順番に反映する。
3. JSONへ書き込む項目は以下に限定する。
- `question`
- `isCorrect`
- `explanation`
- `imagePath`
4. `imagePath` は既存項目がなければ `null` を許容する。
5. CSV上の中分類、難易度、レビュー状態はJSONへ直接は書かず、台帳側で管理する。

## 反映前チェック
- 各CSVが `100問` あること
- 各CSVが `approved: 100`、`app_ready: yes 100` であること
- 各カテゴリの正誤比が `正60 / 誤40` であること
- 既存公開50問がCSV先頭50問と対応していること

## 反映後チェック
- `assets/quiz_data.json` の `part1` から `part5` がすべて100問になっていること
- 各カテゴリの `true/false` 比率が `60/40` であること
- 各カテゴリの先頭50問が反映前と一致していること
- 51問目以降がCSVと一致していること

## 障害時の戻し方
1. 反映前に `assets/quiz_data.json` のバックアップを取得する
2. 問題が見つかった場合はバックアップを復元する
3. 原因をCSV側か反映スクリプト側か切り分けてから再反映する

## 注意点
- 既存公開50問の文面補正は、この反映作業では行わない
- 比率調整は新規50問側のみで行う
- アプリ確認前に追加で問題を書き換えない
