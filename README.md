# auto-brotli

auto-brotli is a set-and-forget shell script that generates **pre-compressed Brotli (`.br`) files**
for static WordPress cache files.

It exists to solve one specific problem:

> **Brotli compression is expensive and should not be done on the fly.**

Instead of compressing responses at request time, auto-brotli pre-compresses
static cache files so your webserver can serve them instantly with zero CPU overhead.

---

## Why does this exist?

Modern caching plugins (WP Rocket, WP Fastest Cache, etc.) already generate static
HTML, CSS, JS, XML files on disk.

On-the-fly Brotli compression:
- is CPU intensive
- does not scale well under load
- increases TTFB during traffic spikes

Pre-compressed Brotli files:
- cost CPU **once**
- are served instantly
- scale perfectly

auto-brotli bridges that gap by continuously keeping `.br` files in sync with your cache.

---

## What auto-brotli is (and is not)

auto-brotli **is**:
- a simple shell script
- incremental and idempotent
- designed to run via cron

auto-brotli is **not**:
- a daemon
- a file watcher
- a WordPress plugin
- a replacement for your cache plugin

It only pre-compresses files.  
Your webserver is responsible for serving them.

---

## Features

- **Maximum compression**  
  Uses Brotli quality level 11 for best compression ratio.

- **Incremental operation**  
  Only new or modified files are processed.

- **Self-healing timestamps**  
  `.br` files mirror ownership and modification times of their source files.

- **Low system impact**  
  Designed to run with `nice` and `ionice` via cron.

- **Cache-cleaner friendly**  
  Preserves file metadata so cache garbage collectors behave as expected.

---

## Requirements

- Linux system
- `brotli` CLI tool installed  
  - Debian / Ubuntu: `apt install brotli`  
  - RHEL / CentOS: `yum install brotli`

---

## Installation

```shell
sudo wget -O /usr/local/bin/auto-brotli.sh https://raw.githubusercontent.com/realrellek/auto-brotli/main/auto-brotli.sh
sudo chmod +x /usr/local/bin/auto-brotli.sh
````

Edit the configuration at the top of the script:

* `WEB_ROOT`
  Base directory containing your sites
  (e.g. `/var/www` or `/var/customers/webs`)

* `CACHE_PATH_PATTERN`
  Default: `*/wp-content/cache/*`

---

## Usage

### Initial run

Compress all existing cache files once:

```shell
sudo /usr/local/bin/auto-brotli.sh --first-run
```

For large caches, use `screen` or `tmux`.

---

### Cron setup

Recommended cron job (every 10 minutes, lowest priority):

```cron
*/10 * * * * /usr/bin/flock -n /tmp/auto-brotli.lock \
  /usr/bin/nice -n 19 \
  /usr/bin/ionice -c 3 \
  /usr/local/bin/auto-brotli.sh
```

This ensures:

* no parallel runs
* minimal CPU usage
* minimal disk IO impact

---

## Webserver configuration

### Nginx (recommended)

Requires `ngx_brotli`:

```nginx
brotli_static on;
```

That’s it.

---

### Apache (possible, but manual)

Apache has no simple equivalent to `brotli_static on`.
You must explicitly rewrite requests to `.br` files and fix headers.

Example configuration:

```apache
<IfModule mod_headers.c>
    RewriteCond %{HTTP:Accept-Encoding} br
    RewriteCond %{REQUEST_FILENAME}\.br -s
    RewriteRule ^(.*)$ $1\.br [L,QSA]

    <FilesMatch "\.br$">
        Header set Content-Encoding br
        Header append Vary Accept-Encoding
    </FilesMatch>

    <FilesMatch "\.css\.br$">
        ForceType text/css
    </FilesMatch>
    <FilesMatch "\.js\.br$">
        ForceType application/javascript
    </FilesMatch>
    <FilesMatch "\.html\.br$">
        ForceType text/html
    </FilesMatch>
</IfModule>
```

---

## Important notes for WP Rocket and other cache plugins

The webserver examples above are **generic**.

Caching plugins like WP Rocket use complex rewrite rules to bypass PHP.
You may need to adapt those rules to also check for `.br` files.

Refer to your caching plugin’s documentation when integrating Brotli static files.

---

## Known limitations

* Primarily tested with **WP Rocket**
* Works with other disk-based cache plugins
* Edge case: if a cache file is deleted but its `.br` file remains,
  a stale response may be served until the cache is regenerated

With WP Rocket’s directory-based cache structure, this is usually not an issue.

## Known WP Rocket issue: homepage Brotli files

When using **WP Rocket**, clearing the homepage cache may **not remove existing
Brotli (`.br`) files** if the homepage cache is **not stored in a separate directory**.

As a result, a stale `.br` file (for example `index.html.br`) may remain in place
and continue to be served by the webserver, even though the HTML cache was cleared.

This is not specific to auto-brotli — it is a side effect of how WP Rocket handles
homepage cache cleanup.

---

### Hotfix for WP Rocket homepage cleanup

You can fix this by hooking into WP Rocket’s cleanup action and explicitly removing
homepage `.br` files.

Add the following code to your theme’s `functions.php`, a plugin, or a mu-plugin:

```php
add_action( 'after_rocket_clean_home', 'rellek_wpr_remove_home_br', 10, 2 );

function rellek_wpr_remove_home_br( $root, $lang ) {
	if ( ! function_exists( 'rocket_direct_filesystem' ) ) {
		return;
	}

	$files = glob( $root . '/*.br', GLOB_NOSORT );

	if ( ! $files ) {
		return;
	}

	foreach ( $files as $file ) {
		if ( preg_match( '#/index(?:-.+\.|\.)html(?:_gzip)?\.br$#', $file ) ) {
			rocket_direct_filesystem()->delete( $file );
		}
	}
}
```

This ensures that stale homepage Brotli files are removed whenever the homepage
cache is cleared.

---

## Advanced usage

auto-brotli can also be used to pre-compress **non-WordPress files**.

By adjusting:

* `WEB_ROOT`
* `CACHE_PATH_PATTERN`

you can brotli-compress any static directory tree.
Multiple copies of the script can be used for different targets.

---

## License

MIT
