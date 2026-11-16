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

## 施策キャンペーン確認
- `campaign/` … https://chaitentou6464.github.io/clearfile-app/campaign/
- 施策を登録して、手続き（MNP・機種変更など）や機種名・「一括1円」などで検索するアプリ。言い換え（機変＝機種変更、のりかえ＝MNP、アイフォン＝iPhone など）にも対応。
- データは端末の中だけ（localStorage の `campaign_v1`、写真は IndexedDB の `campaign_photos`）。メニューからファイルで送る・読み込むができる。

## ブラックジャック戦略
- `blackjack/` … https://chaitentou6464.github.io/clearfile-app/blackjack/
- 判定（ディーラーの1枚と手札を押すと最善の動き）・戦略表（設定のルールに合わせて自動で変わる）・練習（正解率・よく間違える手）・カウント（Hi-Lo、トゥルーカウントで判定を切り替え）。
- 判定画面の下に自動カウンター：判定で押したカード（ディーラー・自分）を自動でHi-Loカウント。他の人のカードも追加できる。「次のゲーム」ではカウントは残り、「シャッフル」で0に戻る。
- 判定画面に「勝率」表示：カウント（+1/0/−1の枚数）から残りカードの割合を推定し、スタンド・ヒット・ダブル・スプリット・サレンダーの勝ち/引分/負けの確率と100円あたりの期待値を計算。
- 手札が空（次のゲーム）のときは「次のゲームの勝率」：カウントから次の1ゲーム全体の勝ち/引分/負けと、×1・×2掛けの100円あたり期待値を表示。
- データは端末の中だけ（localStorage の `blackjack_v1`）。
