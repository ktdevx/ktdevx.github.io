---
title: DebianにWordpressサーバーを構築する
date: 2025-08-26T19:21:31+09:00
draft: false
params:
  toc: true
---

## パッケージのインストール

WordPress サーバーを構築するために必要なパッケージをインストールします。まず、パッケージリストを最新に更新してから、必要なパッケージをインストールします。

```bash
sudo apt update
sudo apt install -y wordpress curl apache2 mariadb-server
```

**インストールするパッケージの説明：**
- `wordpress`: WordPress のアプリケーションおよびファイル（PHP ファイル、テンプレートなど）
- `curl`: ウェブからファイルをダウンロードしたり、API リクエストを送信するためのツール
- `apache2`: ウェブサーバーソフトウェア。WordPress の PHP ファイルを実行してブラウザに表示します
- `mariadb-server`: データベースサーバー。WordPress の記事、ユーザー情報などのデータを保存します

`-y` フラグは、インストール中の確認プロンプトに自動的に「yes」と答えます。インストールにはインターネット接続と若干の時間がかかります。

## MariaDB のセキュア設定

MariaDB をインストール直後は、セキュリティ設定が緩い状態です。`mysql_secure_installation` スクリプトを実行して、セキュリティを強化します。このスクリプトは以下の項目をセキュアに設定します：

- **root ユーザーのパスワード設定**: 初期状態では root パスワードが空の場合があります
- **匿名ユーザーの削除**: 誰でもデータベースにアクセスできる匿名ユーザーを削除
- **リモートアクセスの制限**: root ユーザーがネットワーク経由でアクセスするのを禁止
- **テストデータベースの削除**: テスト用の「test」という名前のデータベースを削除

以下のコマンドでセキュア設定を開始します：

```bash
sudo mysql_secure_installation
```

実行すると以下のようなプロンプトが表示されます。各段階での推奨される回答を説明します：

```
NOTE: RUNNING ALL PARTS OF THIS SCRIPT IS RECOMMENDED FOR ALL MariaDB
      SERVERS IN PRODUCTION USE!  PLEASE READ EACH STEP CAREFULLY!

In order to log into MariaDB to secure it, we'll need the current
password for the root user. If you've just installed MariaDB, and
haven't set the root password yet, you should just press enter here.

Enter current password for root (enter for none): <Enterキー押下>
```

**説明：** MariaDB インストール直後は root パスワードが設定されていません。`Enter` キーを押して進みます。

```
OK, successfully used password, moving on...

Setting the root password or using the unix_socket ensures that nobody
can log into the MariaDB root user without the proper authorisation.

You already have your root account protected, so you can safely answer 'n'.

Switch to unix_socket authentication [Y/n] y
Enabled successfully!
Reloading privilege tables..
 ... Success!
```

**説明：** unix_socket 認証を有効にすることで、OS ユーザー認証を利用したセキュアなアクセス制御が可能になります。`y` と入力して有効化します。

```
You already have your root account protected, so you can safely answer 'n'.

Change the root password? [Y/n] y
New password: <パスワードを入力>
Re-enter new password: <パスワードを再入力>
Password updated successfully!
Reloading privilege tables..
 ... Success!
```

**説明：** `y` と入力して root ユーザーのパスワードを設定します。**安全で覚えやすいパスワードを設定してください** —このパスワードは後ほど MariaDB に接続する際に必要になります。

```
By default, a MariaDB installation has an anonymous user, allowing anyone
to log into MariaDB without having to have a user account created for
them.  This is intended only for testing, and to make the installation
go a bit smoother.  You should remove them before moving into a
production environment.

Remove anonymous users? [Y/n] y
 ... Success!
```

**説明：** 匿名ユーザーはセキュリティリスクです。本番環境では削除する必要があります。`y` と入力して削除します。

```
Normally, root should only be allowed to connect from 'localhost'.  This
ensures that someone cannot guess at the root password from the network.

Disallow root login remotely? [Y/n] y
 ... Success!
```

**説明：** root ユーザーがネットワーク経由（リモート）でアクセスするのを禁止することで、セキュリティが向上します。`y` と入力して禁止します。

```
By default, MariaDB comes with a database named 'test' that anyone can
access.  This is also intended only for testing, and should be removed
before moving into a production environment.

Remove test database and access to it? [Y/n] y
 - Dropping test database...
 ... Success!
 - Removing privileges on test database...
 ... Success!
```

**説明：** テストデータベースは不要なので削除します。`y` と入力してください。

```
Reloading privilege tables will ensure that all changes made so far
will take effect immediately.

Reload privilege tables now? [Y/n] y
 ... Success!

Cleaning up...

All done!  If you've completed all of the above steps, your MariaDB
installation should now be secure.

Thanks for using MariaDB!
```

## WordPress データベースとユーザーの作成

WordPress が接続するためのデータベースとデータベースユーザーを作成します。

```bash
sudo mysql -u root -p
```

MariaDB root ユーザーのパスワードを入力してください。パスワード入力後、MariaDB のコマンドプロンプト（`MariaDB [(none)]>` ）が表示されます。

以下のコマンドを実行して、WordPress 用のデータベースとユーザーを作成します：

```sql
CREATE DATABASE wordpress;
CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'your_password_here';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

**コマンドの説明：**
- `CREATE DATABASE wordpress;`: WordPress 用のデータベース「wordpress」を作成
- `CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'password';`: WordPress 用のユーザー「wordpress」を作成（パスワードは `your_password_here` を実際のパスワードに置き換えてください）
- `GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';`: wordpress ユーザーに wordpress データベースの全権限を付与
- `FLUSH PRIVILEGES;`: 設定を反映させる
- `EXIT;`: MariaDB を終了

**注意：** このパスワードは後ほど WordPress 設定ファイルの `DB_PASSWORD` に設定するので、忘れずにメモしておいてください。

## Apache VirtualHost 設定

Apache 用の WordPress 用仮想ホスト設定ファイルを作成します。

```
sudo vi /etc/apache2/sites-available/wp.conf
```

```
<VirtualHost *:80>
        ServerName myblog.example.com
        ServerAdmin webmaster@example.com
        DocumentRoot /usr/share/wordpress
        Alias /wp-content /var/lib/wordpress/wp-content
        <Directory /usr/share/wordpress>
            Options FollowSymLinks
            AllowOverride Limit Options FileInfo
            DirectoryIndex index.php
            Require all granted
        </Directory>
        <Directory /var/lib/wordpress/wp-content>
            Options FollowSymLinks
            Require all granted
        </Directory>
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
```

### ファイルの保存

ファイルを編集したら、vi エディタで `:wq` と入力して保存し終了します。

## WordPress 設定ファイルの編集

WordPress が接続するデータベース情報を設定ファイルに記述します。

```bash
sudo vi /etc/wordpress/config-default.php
```

### vi エディタの操作方法

vi エディタでファイルが開いたら、以下の手順で編集します。初心者向けの詳細説明です：

1. **ファイルを開く**: 上記コマンドでファイルが開きます。画面最下部に `:` が表示されていない状態です
2. **編集モードに入る**: `i` キーを押すと、画面下部に `-- INSERT --` と表示されます。これで文字入力が可能になります
3. **内容を編集する**: 設定項目を編集します（下記参照）
4. **編集モードを終了する**: `Esc` キーを押すと編集モードが終了します（`-- INSERT --` の表示が消えます）
5. **ファイルを保存して終了する**: `:wq` と入力して `Enter` キーを押します。`:` は自動的に表示されます
6. **もし編集を取り消す場合**: `:q!` と入力して `Enter` キーを押すと、編集を保存せずに終了します

### 設定ファイルの編集内容

ファイルを開いたら、以下の設定項目を確認・編集してください。初心者向けに主要な設定項目を説明します：

```php
// ** MySQL 設定 ** //
/** WordPress のためのデータベース名 */
define('DB_NAME', 'wordpress');

/** MySQL データベースのユーザー名 */
define('DB_USER', 'wordpress');

/** MySQL データベースのパスワード */
define('DB_PASSWORD', 'your_password_here');  // ここを MariaDB セキュア設定で決めたパスワードに変更

/** MySQL のホストサーバー */
define('DB_HOST', 'localhost');

/** データベースのテーブル接頭辞 */
$table_prefix = 'wp_';
```

**設定項目の説明：**
- `DB_NAME`: WordPress が使用するデータベース名（デフォルト：wordpress）
- `DB_USER`: WordPress がデータベースにアクセスするためのユーザー名（デフォルト：wordpress）
- `DB_PASSWORD`: そのユーザーのパスワード（セキュア設定で決めたパスワードを入力）
- `DB_HOST`: MariaDB サーバーのホスト名（同じサーバー上ならば localhost で OK）
- `$table_prefix`: WordPress のテーブルの接頭辞（通常は `wp_` のままで問題ありません）

設定を編集後、`:wq` で保存します。

## Apache 設定の有効化

WordPress の仮想ホスト設定を有効化し、デフォルトサイトを無効化します。

```
sudo a2dissite 000-default
sudo a2ensite wp
sudo systemctl reload apache2
```

コマンドの説明：
- `sudo a2dissite 000-default`: Apache のデフォルトサイト設定を無効化します
- `sudo a2ensite wp`: `wp.conf` という新しい仮想ホスト設定を有効化します
- `sudo systemctl reload apache2`: Apache サーバーを再起動して、新しい設定を反映させます

## ブラウザでの確認と WordPress インストール

ここまでで、ブラウザから WordPress インストール画面にアクセスできるようになりました。

**ローカルテスト環境の場合：**

ホスト OS のブラウザを開いて、以下の URL にアクセスします（`myblog.example.com` は VirtualHost 設定の ServerName に置き換えてください）：

```
http://myblog.example.com
```

**DNS 設定がない場合：**

テスト用には、ホスト OS のホストファイルを編集して、ドメイン名をサーバーの IP アドレスにマップしてください：

- **Windows**: `C:\Windows\System32\drivers\etc\hosts`
- **Linux/Mac**: `/etc/hosts`

以下の行を追加します（Debian サーバーの IP アドレスに置き換えてください）：

```
192.168.1.100  myblog.example.com
```

### WordPress インストール画面での設定

ブラウザでアクセスすると、WordPress のインストール画面が表示されます。以下の手順でセットアップしてください：

1. **言語選択**: 日本語を選択します
2. **データベース情報の確認**: WordPress が `/etc/wordpress/config-default.php` から DB 接続情報を自動的に読み込みます
3. **WordPress タイトルと管理者情報の入力**:
   - ブログのタイトルを入力
   - 管理者ユーザー名を入力（任意）
   - 管理者パスワードを設定（強力なパスワードを推奨）
   - 管理者メールアドレスを入力
4. **インストール実行**: 「WordPress をインストール」ボタンをクリック

### インストール完了確認

インストールが完了すると、WordPress の管理画面ログイン画面が表示されます。先ほど設定した管理者ユーザー名とパスワードでログインしてください。

以上で、Debian サーバー上に WordPress サーバーの基本的なセットアップが完了しました。お疲れ様でした！

## トラブルシューティング

もし WordPress のインストール画面に接続できない場合は、以下を確認してください。

### Apache が起動していることを確認

```bash
sudo systemctl status apache2
```

このコマンドで Apache のステータスを確認します。以下のような出力が表示されます：

```
● apache2.service - The Apache HTTP Server
     Loaded: loaded (/lib/systemd/system/apache2.service; enabled; vendor preset: enabled)
     Active: active (running) since ...
```

`Active: active (running)` と表示されていれば、Apache は正常に起動しています。

もし起動していない場合は、以下で起動してください：

```bash
sudo systemctl start apache2
```

### Apache のエラーログを確認

```bash
sudo tail -f /var/log/apache2/error.log
```

このコマンドで Apache のエラーログをリアルタイムで確認できます。ブラウザでアクセスしてエラーが発生した場合、ここに詳細が表示されます。

終了するには `Ctrl + C` キーを押してください。

### MariaDB が起動していることを確認

```bash
sudo systemctl status mariadb
```

このコマンドで MariaDB のステータスを確認します。`Active: active (running)` と表示されていれば正常です。

もし起動していない場合は以下で起動してください：

```bash
sudo systemctl start mariadb
```

### WordPress の設定ファイルを確認

WordPress 設定ファイルが正しく編集されているか確認します：

```bash
sudo cat /etc/wordpress/config-default.php | grep -E 'DB_NAME|DB_USER|DB_PASSWORD|DB_HOST'
```

このコマンドで設定ファイルの重要な部分を表示します。`DB_PASSWORD` が `your_password_here` のままになっていないか、実際のパスワードが設定されているか確認してください。

### ホストファイルの設定を確認（Windows の場合）

ホストファイルが正しく設定されているか確認します。PowerShell で以下を実行：

```powershell
Get-Content "C:\Windows\System32\drivers\etc\hosts" | Select-String "myblog.example.com"
```

ドメイン名と IP アドレスが正しくマッピングされていることを確認してください。