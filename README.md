# nijie.sh
[shell script] nijie.info download script



# ログイン(プロンプトを使用したログイン)
```
./nijie.sh login
```

# オプション
 - `--limit` (integer): 探索ページ数を制限
 - `--output` (string): 出力ファイル名を指定
 - `--tag` (string): タグでフィルタ
 - `--json` ダウンロードせずjson出力
 - `--atry` (integer): 指定数連続してダウンロード済みなら再帰を中止
# ファイル名のテンプレート
 - `[title]` タイトル
 - `[illust_id]` イラストID
 - `[index]` イラストインデックス
 - `[ext]` 拡張子
 - `[author_id]` 投稿者ID
 - `[author]` 投稿者名
 
# コマンド例
#### イラストをダウンロード
```
./nijie.sh https://nijie.info/view.php?id=xxxxxxx
```
#### イラストをダウンロード(ファイル名指定)
```
./nijie.sh -o "[illust_id]_[index].[ext]" https://nijie.info/view.php?id=xxxxxxx
```
#### メンバーからイラストをダウンロード
```
./nijie.sh https://nijie.info/members_illust.php?id=xxxxxx
```

#### メンバーからイラストをダウンロード (オリジナルタグを含む)
```
./nijie.sh --tag 'オリジナル' https://nijie.info/members_illust.php?id=xxxxxx
```
#### メンバーからイラストをダウンロード (オリジナルタグを含むまない)
```
./nijie.sh --tag '!"オリジナル"' https://nijie.info/members_illust.php?id=xxxxxx
```

#### メンバーからイラストをダウンロード(ページを指定)
```
./nijie.sh https://nijie.info/members_illust.php?p=1&id=xxxxxx
```

#### お気に入りからイラストをダウンロード
```
./nijie.sh favorite
```

#### お気に入りからイラストIDをjqを使用しエクスポート
```
./nijie.sh --json favorite | jq .[].illust_id
```
