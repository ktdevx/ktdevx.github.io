---
title: Build a WordPress Server on Debian
date: 2025-08-26T19:21:31+09:00
draft: false
params:
  toc: true
---

## Install the Packages

Install the packages required to build a WordPress server. First update the package list, then install the required packages.

```bash
sudo apt update
sudo apt install -y wordpress curl apache2 mariadb-server
```

**Installed packages:**
- `wordpress`: WordPress application and files, including PHP files and templates
- `curl`: Tool for downloading files from the web and sending API requests
- `apache2`: Web server software that runs WordPress PHP files and displays them in a browser
- `mariadb-server`: Database server that stores WordPress posts, user information, and other data

The `-y` flag automatically answers yes to confirmation prompts during installation. An internet connection and some time are required.

## Secure the MariaDB Installation

Immediately after installation, MariaDB has relatively loose security settings. Run `mysql_secure_installation` to improve security. This script configures the root password, removes anonymous users, disables remote root access, and removes the test database.

```bash
sudo mysql_secure_installation
```

The following prompts may be displayed. Recommended answers are shown below.

```
NOTE: RUNNING ALL PARTS OF THIS SCRIPT IS RECOMMENDED FOR ALL MariaDB
      SERVERS IN PRODUCTION USE!  PLEASE READ EACH STEP CAREFULLY!

In order to log into MariaDB to secure it, we'll need the current
password for the root user. If you've just installed MariaDB, and
haven't set the root password yet, you should just press enter here.

Enter current password for root (enter for none): <press Enter>
```

Immediately after installing MariaDB, no root password is set. Press `Enter` to continue.

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

Enable unix_socket authentication by entering `y`.

```
You already have your root account protected, so you can safely answer 'n'.

Change the root password? [Y/n] y
New password: <enter password>
Re-enter new password: <re-enter password>
Password updated successfully!
Reloading privilege tables..
 ... Success!
```

Enter `y` and set a secure password that you can remember. You will need this password later to connect to MariaDB.

```
By default, a MariaDB installation has an anonymous user, allowing anyone
to log into MariaDB without having to have a user account created for
them.  This is intended only for testing, and to make the installation
go a bit smoother.  You should remove them before moving into a
production environment.

Remove anonymous users? [Y/n] y
 ... Success!
```

Anonymous users are a security risk. Enter `y` to remove them.

```
Normally, root should only be allowed to connect from 'localhost'.  This
ensures that someone cannot guess at the root password from the network.

Disallow root login remotely? [Y/n] y
 ... Success!
```

Enter `y` to prohibit remote root access and improve security.

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

The test database is unnecessary. Enter `y` to remove it.

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

## Create the WordPress Database and User

Create the database and database user used by WordPress.

```bash
sudo mysql -u root -p
```

Enter the MariaDB root password. The MariaDB command prompt (`MariaDB [(none)]>`) is displayed.

```sql
CREATE DATABASE wordpress;
CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'your_password_here';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

Replace `your_password_here` with the actual password. This password must later be set as `DB_PASSWORD` in the WordPress configuration file, so keep a record of it.

## Configure the Apache VirtualHost

Create the WordPress virtual host configuration file for Apache.

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

Save and exit vi by entering `:wq`.

## Edit the WordPress Configuration File

Enter the database information WordPress uses in its configuration file.

```bash
sudo vi /etc/wordpress/config-default.php
```

In vi, press `i` to enter insert mode, edit the settings below, press `Esc`, then enter `:wq` and press `Enter` to save and exit. Use `:q!` to exit without saving.

```php
// ** MySQL settings ** //
/** WordPress database name */
define('DB_NAME', 'wordpress');

/** MySQL database username */
define('DB_USER', 'wordpress');

/** MySQL database password */
define('DB_PASSWORD', 'your_password_here');  // Replace with the password set during MariaDB secure configuration

/** MySQL hostname */
define('DB_HOST', 'localhost');

/** Database table prefix */
$table_prefix = 'wp_';
```

`DB_NAME` is the WordPress database name, `DB_USER` is the database username, `DB_PASSWORD` is the password you configured, and `DB_HOST` is `localhost` when MariaDB runs on the same server. The default `$table_prefix` of `wp_` is normally suitable.

## Enable the Apache Configuration

Enable the WordPress virtual host, disable the default site, and reload Apache.

```
sudo a2dissite 000-default
sudo a2ensite wp
sudo systemctl reload apache2
```

## Check in a Browser and Install WordPress

You can now access the WordPress installation screen from a browser.

For a local test environment, access the following URL. Replace `myblog.example.com` with the `ServerName` from the VirtualHost configuration.

```
http://myblog.example.com
```

If DNS is not configured, edit the host file on the host OS and map the domain name to the server IP address.

- **Windows**: `C:\Windows\System32\drivers\etc\hosts`
- **Linux/Mac**: `/etc/hosts`

Add the following line, replacing the IP address with the Debian server's address.

```
192.168.1.100  myblog.example.com
```

On the WordPress installation screen, select a language, confirm the database information loaded from `/etc/wordpress/config-default.php`, enter the blog title and administrator information, and select Install WordPress.

When installation is complete, log in to the WordPress administration screen with the administrator username and password you configured.

The basic WordPress server setup on Debian is complete.

## Troubleshooting

If you cannot connect to the WordPress installation screen, check the following.

### Check that Apache Is Running

```bash
sudo systemctl status apache2
```

If the output contains `Active: active (running)`, Apache is running normally. Start it with the following command if necessary.

```bash
sudo systemctl start apache2
```

### Check the Apache Error Log

```bash
sudo tail -f /var/log/apache2/error.log
```

This displays the Apache error log in real time. Press `Ctrl + C` to exit.

### Check that MariaDB Is Running

```bash
sudo systemctl status mariadb
```

If the output contains `Active: active (running)`, MariaDB is running normally. Start it if necessary.

```bash
sudo systemctl start mariadb
```

### Check the WordPress Configuration File

```bash
sudo cat /etc/wordpress/config-default.php | grep -E 'DB_NAME|DB_USER|DB_PASSWORD|DB_HOST'
```

Confirm that `DB_PASSWORD` is not still `your_password_here` and that the actual password is configured.

### Check the Host File on Windows

Run the following in PowerShell to check the host file.

```powershell
Get-Content "C:\Windows\System32\drivers\etc\hosts" | Select-String "myblog.example.com"
```

Confirm that the domain name and IP address are mapped correctly.
