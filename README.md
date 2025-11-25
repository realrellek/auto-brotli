# **Auto-Brotli Static Compressor**

**A set-and-forget shell script to generate pre-compressed Brotli (`.br`) files for WordPress caches.**

This script monitors your `wp-content/cache` directory and automatically generates maximum-compression Brotli files (Level 11) for your static assets (HTML, CSS, JS, XML).

This allows Nginx (`brotli_static on;`) and Apache to serve pre-compressed files with zero CPU overhead, drastically reducing Time-To-First-Byte (TTFB) compared to on-the-fly compression.

## **Features**

* 🚀 **Max Compression:** Uses Brotli Quality 11 (smaller than Gzip and on-the-fly Brotli).  
* 🔄 **Incremental:** Only processes new or modified files.  
* 🛡️ **Self-Healing:** Syncs timestamps with source files. If the cache is updated, the `.br` file is updated.  
* 📉 **Low Resource:** Designed to run via Cron with lowest CPU/IO priority (`nice`/`ionice`).  
* 🧹 **Cleaner Compatible:** Preserves file ownership and modification times, so cache cleaners (like WP Rocket's garbage collector) work as expected.

## **Requirements**

* Linux Server (Debian/Ubuntu/CentOS etc.)  
* `brotli` command line tool installed:  
  * Debian/Ubuntu: `apt install brotli`
  * RHEL/CentOS: `yum install brotli`

## **Installation**

1. **Download the script:**
```
sudo wget -O /usr/local/bin/auto-brotli.sh https://raw.githubusercontent.com/realrellek/auto-brotli/main/auto-brotli.sh
sudo chmod +x /usr/local/bin/auto-brotli.sh
```

2. Configuration:  
   Edit the file `nano /usr/local/bin/auto-brotli.sh` and check the variables at the top:  
   * `WEB_ROOT`: The base directory where your websites live (e.g., `/var/www` or `/var/customers/webs`).  
   * `CACHE_PATH_PATTERN`: Default is `*/wp-content/cache/*`.

## **Usage**

### **1. Initial Scan**

Run the script once manually to compress all existing cache files. This might take a while depending on your cache size.

```
# Run in screen or tmux if you have a huge cache  
sudo /usr/local/bin/auto-brotli.sh --first-run
```

### **2. Setup Cronjob**

Add the following line to your root crontab (`sudo crontab -e`). This runs the script every 10 minutes with low priority to ensure it never impacts site performance.
```
*/10 * * * * /usr/bin/flock -n /tmp/auto-brotli.lock /usr/bin/nice -n 19 /usr/bin/ionice -c 3 /usr/local/bin/auto-brotli.sh
```
* `flock`: Ensures only one instance runs at a time.  
* `nice -n 19`: Uses lowest CPU priority.  
* `ionice -c 3`: Uses lowest I/O priority.

## **Webserver Configuration**

To actually serve these files, you need to configure your webserver.

---

⚠️ **IMPORTANT NOTE FOR WP ROCKET & CACHING PLUGINS**
The configurations below are generic examples. They may not be enough to make it work with WP Rocket or similar caching tools out of the box!

WP Rocket, for example, uses its own complex RewriteRules in `.htaccess` (Apache) or configuration (Nginx) to bypass PHP. You may need to manually adjust those rules to check for `.br` files in addition to `.html_gzip` files. Please refer to your specific caching tool's documentation on how to serve pre-compressed custom files.

---

### **Nginx**

Requires the `ngx_brotli` module. Add this to your server or location block:
```
brotli_static on;
```
### **Apache**

Apache doesn't have a simple switch, but you can use `mod_rewrite` to check for the existence of `.br` files. Add this to your `.htaccess` or vhost config:
```
<IfModule mod_headers.c>
    # Check if browser accepts br and file exists
    RewriteCond %{HTTP:Accept-Encoding} br
    RewriteCond %{REQUEST_FILENAME}\.br -s
    RewriteRule ^(.*)$ $1\.br [L,QSA]

    # Force correct content-type and encoding headers
    <FilesMatch "\.br$">
        Header set Content-Encoding br
        Header append Vary Accept-Encoding
    </FilesMatch>
    
    # Fix MIME types (Apache might see .br as application/x-brotli otherwise)
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

## **Known Limitations**

* **Plugin Compatibility:** Tested primarily with **WP Rocket**. Also works with WP Fastest Cache and others that store static files on disk.  
* **Stale Cache Edge Case:** If a caching plugin deletes *only* the source file (e.g., `index.html`) but leaves the `.br` file (rare, as most delete the folder), the webserver might serve the stale `.br` file until the cache is regenerated. With WP Rocket, this is not an issue as it clears directory-based structures.

## **Different uses**

It shall be known that auto-brotli can be "abused" to brotli-fy other files too. All you would have to do is change the `WEB_ROOT` and adjust `CACHE_PATH_PATTERN`. You can use `*` as the `CACHE_PATH_PATTERN` if you have no preferences or restrictions on where to look inside `WEB_ROOT`. You can create a second copy of the script if you want both functions.

## **License**

MIT
