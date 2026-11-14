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
