# クリアファイル

10枚綴じのクリアファイルアプリ。書類の写真やPDFを表と裏に入れて、付箋も貼れます。
ホーム画面に追加するとアプリとして使え、オフラインでも動きます。書類はスマホの中にだけ保存されます。

## 目標達成マネージャー
- `target/` … スタッフ用アプリ（https://chaitentou6464.github.io/clearfile-app/target/）
- `manager/` … 店長・管理者用アプリ（https://chaitentou6464.github.io/clearfile-app/manager/）。`manager/index.html` は `target/index.html` のコピーで、違うのは `<title>` と apple-touch-icon だけ。パスに `/manager/` が入ると「メンバー」タブが出る。target を直したら manager と shared にもコピーすること（違うのは `<title>` と apple-touch-icon だけ）。
- `shared/` … お店の共用端末用アプリ（https://chaitentou6464.github.io/clearfile-app/shared/）。これも `target/index.html` のコピー。パスに `/shared/` が入ると、名前を選ぶ画面・メンバーごとのデータ（localStorage の `shared_v1`）・店長の暗証番号つきメンバー欄になる。
- `team.html` … クリアファイルの本棚から開く「スタッフ実績」。manager と同じ保存場所（localStorage の `team_v1`）を使う。

- `cloud/` … サーバー版（Supabase）。https://chaitentou6464.github.io/clearfile-app/cloud/ 。これも `target/index.html` のコピーで、パスに `/cloud/` が入るとログイン・自動保存・店長のメンバー欄（役割が店長の人だけ）になる。サーバー側の設定は `cloud/setup.sql`（`cloud/setup.html` からコピーできる）。Supabase の Authentication で「Confirm email」をオフにしておくこと。

## 本格導入版（サーバー：Supabase）
- `staff/` スタッフ用（自分の実績を入力）
- `store/` 店長用（スタッフ別グラフ・店舗内ランキング・店舗合計）
- `hq/` 本部用（店舗合計・店舗ランキング・スタッフ別・全体ランキング・店舗追加）
- どれも `target/index.html` のコピー（title と apple-touch-icon だけ違う）。パスで動きが変わる。

## 目標達成マネージャー改（takami）
- `takami/` … https://chaitentou6464.github.io/clearfile-app/takami/
- フェニックスの評価基準とソフトバンクの評価基準を1つのアプリで管理する版。`target/index.html` をもとに作った別アプリ（target/manager などにはコピーしない）。
- 入力タブ：日付を ‹ › で切り替えて、上に「ソフトバンク成果」（`S.sb.items`、記録は月の `sbLogs`）、下に「フェニックス実績」（元の今日の成果＝`logs`）を入力。項目は右上の⚙で設定。
- 目標/実績タブ（足切りタブもここにまとめた）：上に足切りのまとめ、下に項目ごとのカード。左上のボタンでソフトバンク／フェニックスを切り替え。見え方は元の成果タブのカード。ソフトバンク側は `withSB()` で sbLogs・`sbT`（月ごとの目標）をフェニックスと同じ形に置きかえて計算。
- データは端末の中だけ（localStorage の `takami_v1`）。元の目標達成マネージャー（`target_v1`）とは別保存。

## 施策キャンペーン確認
- `campaign/` … https://chaitentou6464.github.io/clearfile-app/campaign/
- 施策を登録して、手続き（MNP・機種変更など）や機種名・「一括1円」などで検索するアプリ。言い換え（機変＝機種変更、のりかえ＝MNP、アイフォン＝iPhone など）にも対応。
- データは端末の中だけ（localStorage の `campaign_v1`、写真は IndexedDB の `campaign_photos`）。メニューからファイルで送る・読み込むができる。

## ブラックジャック戦略
- `blackjack/` … https://chaitentou6464.github.io/clearfile-app/blackjack/
- テーブル：本物のテーブル風の画面で1ゲームずつ進める。カードを配られた順に押すと「あなた→ディーラー→あなた」と自動で入力先が切り替わり、おすすめの動き・勝率・ディーラーの結果（勝ち/負け）が出る。ヒット/スタンド/ダブル/スプリットのボタンで流れを進める。スプリットは最大4手まで（手ごとにおすすめ・勝率・勝ち負け、合計の倍率を表示。Aのスプリットは1枚ずつで自動で次の手へ。「1枚戻す」でスプリットも戻せる）。
- 人数：テーブルは最大5人（自分含む）。人数を選ぶと、ほかの人の席が出て、配る順番（あなた→ほかの人→ディーラー→あなた→ほかの人）で入力先が自動で切り替わる。席をタップするとその人に入力。
- 残りカード：デッキ数×52枚から、入れたカードを1枚単位で引いて残りを計算（ランクごとの枚数と次に出る確率、Hi-Loのカウント）。勝率もこの残りカードから計算。捨て札のまとめ入力・シャッフル（最初に戻す）もここ。
- 戦略表（設定のルールで自動で変わる）・練習（正解率・よく間違える手）。
- データは端末の中だけ（localStorage の `blackjack_v1`：opt / shoe / game / drill）。
