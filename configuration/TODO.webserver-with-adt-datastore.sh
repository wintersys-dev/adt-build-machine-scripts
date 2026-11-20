THIS IS THE ONE TO TRY


Not quite—only the ones enabled in default.env (plus ALWAYS items) will be installed, and there are three quick cloud-init details to keep in mind.

1. What Gets Installed on Boot

When cloud-init calls ${HOME}/installation/InstallSoftware.sh, it reads software.manifest from top to bottom and installs:
• Every item marked ALWAYS (prereqs, sendemail, ssmtp).
• Every item whose ENABLE_* flag is set to 1 in ${HOME}/config/profiles/default.env (or whichever profile you pass via --profile).
• Anything set to 0 (such as ENABLE_MARIADB=0 or ENABLE_NGINX_SOURCE=0) is skipped.

2. Three Cloud-Init Details to Verify First

Before calling InstallSoftware.sh from cloud-init, make sure these three prerequisites are satisfied in your cloud-init boot sequence:
1. /home/homedir.dat must already exist: InstallSoftware.sh starts with HOME="$(cat /home/homedir.dat)". Make sure your cloud-init script writes /home/homedir.dat (and clones the webserver repository into ${HOME}) before calling InstallSoftware.sh.
2. S3 credentials must be in place before Stage 1 runs: For MountDatastore.sh, GetFromDatastore.sh, and PutToDatastore.sh to use the S3 pull-through cache, your datastore credentials file (e.g., ${HOME}/.s3cfg or AWS/R2 environment variables) must be written by cloud-init prior to running InstallSoftware.sh.
3. Webserver application configuration still runs after installation: InstallSoftware.sh handles installing and smoke-testing the binaries (nginx, lighttpd, apache2, php, etc.). If your existing toolkit runs post-install site configuration scripts afterward (like ConfigureNginxForApplication.sh), keep that call right after InstallSoftware.sh in your cloud-init script.

Example Cloud-Init Invocation

sh
# 1. Ensure permissions are executable
chmod +x "${HOME}/installation/InstallSoftware.sh" "${HOME}/installation/recipes/"*.sh

# 2. Run the manifest installer (or pass --profile web / --profile proxy)
"${HOME}/installation/InstallSoftware.sh" >> /var/log/adt-install.log 2>&1


this is the simpler version (try this first) - this contains a prompt for generating recipes which can be added to a new chat and the recipe for a particular
softwware installation can be generated
-----------------------------------------------------------------------

Here is the complete, unified solution with the single copy-paste prompt template built directly into ${HOME}/installation/recipes/README.md, split into modular, copy-pasteable sections so nothing overflows.

1. Filesystem Layout

text
${HOME}/
├── config/
│   └── software.conf               <── Single file: settings + module lists + ON/OFF toggles
└── installation/
    ├── InstallSoftware.sh          <── Production-hardened POSIX engine + SHA-256 S3 cache
    └── recipes/
        ├── README.md               <── Includes ready-to-paste AI prompt template + spec
        ├── s5cmd.sh
        ├── rclone.sh
        ├── s3fs.sh
        ├── postgres.sh
        ├── php.sh
        ├── wpcli.sh
        ├── composer.sh
        ├── clamav.sh
        ├── lego.sh
        ├── nginx_source.sh
        ├── lighttpd_repo.sh
        ├── lighttpd_source.sh
        └── apache_source.sh
Use code with caution.

2. The Single Config File (${HOME}/config/software.conf)

text
#@ POSTGRES_VERSION="17"
#@ PHP_VERSION="8.4"
#@ PHP_MODULES="mysql pgsql curl xml mbstring zip gd intl bcmath"
#@ NGINX_VERSION="1.26.2"
#@ NGINX_ARGS="--with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_gzip_static_module"
#@ LIGHTTPD_VERSION="1.4.76"
#@ LIGHTTPD_MODULES="mod_openssl mod_accesslog mod_deflate mod_setenv mod_access mod_expire mod_redirect mod_rewrite mod_proxy mod_fastcgi"
#@ APACHE_VERSION="2.4.62"
#@ APACHE_MODULES="rewrite ssl headers proxy proxy_fcgi"

# STATE | NAME            | TYPE   | TARGET                                               | POST_CMD
# -----------------------------------------------------------------------------------------------------------------
ON      | prereqs         | apt    | curl wget jq unzip ca-certificates gnupg lsb-release |
ON      | s5cmd           | recipe | s5cmd.sh                                             |
OFF     | s3cmd           | apt    | s3cmd                                                | [ -f "${HOME}/.s3cfg" ] && cp "${HOME}/.s3cfg" /root/
OFF     | rclone          | recipe | rclone.sh                                            |
OFF     | s3fs_repo       | apt    | libfuse3-dev s3fs                                    |
ON      | s3fs_source     | recipe | s3fs.sh                                              |
ON      | ufw             | apt    | ufw                                                  | /usr/sbin/ufw disable
ON      | sendemail       | apt    | sendemail                                            |
ON      | ssmtp           | apt    | ssmtp mailutils                                      |
OFF     | fail2ban        | apt    | fail2ban                                             |
OFF     | clamav          | recipe | clamav.sh                                            |
OFF     | lego            | recipe | lego.sh                                              |
OFF     | w3m             | apt    | w3m                                                  |
OFF     | lynx            | apt    | lynx                                                 |
OFF     | elinks          | apt    | elinks                                               |
OFF     | mariadb         | apt    | mariadb-server mariadb-client                        | systemctl enable mariadb
OFF     | mariadb_client  | apt    | mariadb-client                                       |
ON      | postgres        | recipe | postgres.sh                                          |
ON      | php             | recipe | php.sh                                               |
ON      | wpcli           | recipe | wpcli.sh                                             |
OFF     | composer        | recipe | composer.sh                                          |
ON      | nginx_repo      | apt    | nginx                                                |
OFF     | nginx_source    | recipe | nginx_source.sh                                      |
OFF     | lighttpd_repo   | recipe | lighttpd_repo.sh                                     |
OFF     | lighttpd_source | recipe | lighttpd_source.sh                                   |
OFF     | apache_repo     | apt    | apache2 apache2-utils                                |
OFF     | apache_source   | recipe | apache_source.sh                                     |
Use code with caution.

3. InstallSoftware.sh — Block 1: Setup, S3 Cache & run_apt

sh
#!/bin/sh
set -eu

HOME="$(cat /home/homedir.dat)"
export HOME

CONF="${1:-${HOME}/config/software.conf}"
RECIPES="${HOME}/installation/recipes"
DONE_DIR="${HOME}/runtime/installedsoftware"
CACHE_BUCKET="software-cache"

[ -f "${CONF}" ] || { printf 'Error: Config not found: %s\n' "${CONF}" >&2; exit 1; }
mkdir -p "${DONE_DIR}"

WORK_DIR="$(mktemp -d /tmp/adt_install.XXXXXX)"
trap 'rm -rf "${WORK_DIR}"' EXIT INT TERM

. /etc/os-release
ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
CACHE_PREFIX="${CACHE_BUCKET}/${ID}-${VERSION_ID}-${ARCH}"

# Safely load any '#@ KEY="VAL"' settings from top of software.conf
eval "$(grep '^#@' "${CONF}" | sed 's/^#@//' || true)"

mount_cache() {
    [ -x /usr/bin/s5cmd ] || [ -x /usr/bin/s3cmd ] || [ -x /usr/bin/rclone ] || [ -x /usr/bin/s3fs ] || return 1
    "${HOME}/providerscripts/datastore/MountDatastore.sh" "${CACHE_BUCKET}" >/dev/null 2>&1 || true
}

cache_get() {
    key="$1"; dest="$2"; sha="${dest}.sha256"
    mount_cache || return 1
    rm -f "${dest}" "${sha}"

    "${HOME}/providerscripts/datastore/GetFromDatastore.sh" "${CACHE_PREFIX}/${key}" "${dest}" >/dev/null 2>&1 || return 1
    "${HOME}/providerscripts/datastore/GetFromDatastore.sh" "${CACHE_PREFIX}/${key}.sha256" "${sha}" >/dev/null 2>&1 || return 1

    if [ -s "${dest}" ] && [ -s "${sha}" ]; then
        expected="$(awk '{print $1}' "${sha}")"
        actual="$(sha256sum "${dest}" | awk '{print $1}')"
        if [ -n "${expected}" ] && [ "${expected}" = "${actual}" ]; then
            rm -f "${sha}"
            printf '[CACHE HIT] %s\n' "${key}"
            return 0
        fi
        printf '[CACHE CORRUPT] %s failed SHA-256 check\n' "${key}"
    fi
    rm -f "${dest}" "${sha}"
    return 1
}

cache_put() {
    src="$1"; key="$2"; sha="${src}.sha256"
    [ -s "${src}" ] && mount_cache || return 0
    sha256sum "${src}" | awk '{print $1}' > "${sha}"
    if "${HOME}/providerscripts/datastore/PutToDatastore.sh" "${src}" "${CACHE_PREFIX}/${key}" >/dev/null 2>&1 && \
       "${HOME}/providerscripts/datastore/PutToDatastore.sh" "${sha}" "${CACHE_PREFIX}/${key}.sha256" >/dev/null 2>&1; then
        printf '[CACHE PUSH] %s\n' "${key}"
    fi
    rm -f "${sha}"
}

run_apt() {
    deb_dir="${WORK_DIR}/$1_debs"; tar_file="${WORK_DIR}/$1.tar.gz"
    mkdir -p "${deb_dir}/partial"
    export DEBIAN_FRONTEND=noninteractive

    if cache_get "$1.tar.gz" "${tar_file}"; then
        tar -xzf "${tar_file}" -C "${deb_dir}"
        apt-get -o DPkg::Lock::Timeout=-1 -o "Dir::Cache::Archives=${deb_dir}" -qq -y install --no-download $2 || \
        apt-get -o DPkg::Lock::Timeout=-1 -o "Dir::Cache::Archives=${deb_dir}" -qq -y install $2
        return 0
    fi

    apt-get -o DPkg::Lock::Timeout=-1 -qq -y update
    apt-get -o DPkg::Lock::Timeout=-1 -o "Dir::Cache::Archives=${deb_dir}" -qq -y install --download-only --reinstall $2
    apt-get -o DPkg::Lock::Timeout=-1 -o "Dir::Cache::Archives=${deb_dir}" -qq -y install $2

    if ls "${deb_dir}"/*.deb >/dev/null 2>&1; then
        tar -czf "${tar_file}" -C "${deb_dir}" .
        cache_put "${tar_file}" "$1.tar.gz"
    fi
}
Use code with caution.

4. InstallSoftware.sh — Block 2: Main Orchestration Loop (Append to InstallSoftware.sh)

sh
grep -vE '^[[:space:]]*#|^[[:space:]]*$' "${CONF}" | while IFS='|' read -r r_state r_name r_type r_target r_post
do
    state="$(echo "$r_state" | xargs)"
    name="$(echo "$r_name" | xargs)"
    type="$(echo "$r_type" | xargs)"
    target="$(echo "$r_target" | xargs)"
    post="$(echo "$r_post" | xargs)"

    [ "${state}" = "ON" ] || continue
    [ -f "${DONE_DIR}/${name}.done" ] && continue

    printf 'Installing %s...\n' "${name}"
    for attempt in 1 2 3; do
        rc=0
        case "${type}" in
            apt)    run_apt "${name}" "${target}" || rc=$? ;;
            recipe) ( set -e; . "${RECIPES}/${target}" ) || rc=$? ;;
            *)      printf 'Error: Unknown type %s\n' "${type}" >&2; exit 1 ;;
        esac

        if [ "${rc}" -eq 0 ]; then
            [ -n "${post}" ] && sh -c "${post}"
            touch "${DONE_DIR}/${name}.done"
            break
        fi
        printf 'Retry %s/3 for %s...\n' "${attempt}" "${name}"
        sleep 2
    done

    if [ ! -f "${DONE_DIR}/${name}.done" ]; then
        "${HOME}/services/email/SendEmail.sh" "INSTALL ERROR: ${name}" "Failed to install ${name}" "ERROR" || true
        exit 1
    fi
done
Use code with caution.

5. Webserver Recipes (nginx_source.sh, lighttpd_repo.sh, lighttpd_source.sh, apache_source.sh)

sh
# recipes/nginx_source.sh
#!/bin/sh
run_apt "nginx_build_deps" "build-essential libpcre2-dev zlib1g-dev libssl-dev"
mkdir -p /var/log/nginx /var/cache/nginx /etc/nginx/conf.d

ng_ver="${NGINX_VERSION:-1.26.2}"
ng_args="${NGINX_ARGS:---with-http_ssl_module --with-http_v2_module}"
cfg_hash="$(printf '%s|%s' "${ng_ver}" "${ng_args}" | sha256sum | awk '{print substr($1,1,8)}')"
artifact="nginx-${ng_ver}-${cfg_hash}.tar.gz"

if cache_get "${artifact}" "${WORK_DIR}/${artifact}"; then
    tar -xzf "${WORK_DIR}/${artifact}" -C /
else
    mkdir -p "${WORK_DIR}/nginx_src"
    curl -fsSL "https://nginx.org{ng_ver}.tar.gz" | tar -xz -C "${WORK_DIR}/nginx_src" --strip-components=1
    cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
    (
        cd "${WORK_DIR}/nginx_src"
        ./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx \
            --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log \
            --pid-path=/run/nginx.pid --lock-path=/run/lock/nginx.lock ${ng_args}
        make -j"${cpus}"
        make install
    )
    tar -czf "${WORK_DIR}/${artifact}" /usr/sbin/nginx /etc/nginx
    cache_put "${WORK_DIR}/${artifact}" "${artifact}"
fi

if [ ! -f /etc/systemd/system/nginx.service ] && [ ! -f /lib/systemd/system/nginx.service ]; then
    cat <<'EOF' > /etc/systemd/system/nginx.service
[Unit]
Description=NGINX HTTP and Reverse Proxy Server
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
fi

systemctl enable nginx 2>/dev/null || true
touch /etc/nginx/BUILT_FROM_SOURCE
/usr/sbin/nginx -t >/dev/null
Use code with caution.
sh
# recipes/lighttpd_repo.sh
#!/bin/sh
lt_pkgs="lighttpd"
for mod in ${LIGHTTPD_MODULES:-}; do
    case "${mod}" in
        mod_openssl) lt_pkgs="${lt_pkgs} lighttpd-mod-openssl" ;;
        mod_deflate) lt_pkgs="${lt_pkgs} lighttpd-mod-deflate" ;;
    esac
done

run_apt "lighttpd_repo" "${lt_pkgs}"

mkdir -p /etc/lighttpd
if [ -n "${LIGHTTPD_MODULES:-}" ]; then
    printf 'server.modules = (\n' > /etc/lighttpd/modules.conf
    first=1
    for mod in ${LIGHTTPD_MODULES}; do
        [ "${first}" -eq 0 ] && printf ',\n' >> /etc/lighttpd/modules.conf
        printf '    "%s"' "${mod}" >> /etc/lighttpd/modules.conf
        first=0
    done
    printf '\n)\n' >> /etc/lighttpd/modules.conf
fi

systemctl enable lighttpd 2>/dev/null || true
touch /etc/lighttpd/BUILT_FROM_REPO
/usr/sbin/lighttpd -v >/dev/null
Use code with caution.
sh
# recipes/lighttpd_source.sh
#!/bin/sh
run_apt "lighttpd_build_deps" "build-essential pkg-config libpcre2-dev zlib1g-dev libssl-dev"
mkdir -p /etc/lighttpd /var/log/lighttpd

lt_ver="${LIGHTTPD_VERSION:-1.4.76}"
lt_major="$(printf '%s' "${lt_ver}" | awk -F'.' '{print $1"."$2}')"
artifact="lighttpd-${lt_ver}.tar.gz"

if cache_get "${artifact}" "${WORK_DIR}/${artifact}"; then
    tar -xzf "${WORK_DIR}/${artifact}" -C /
else
    mkdir -p "${WORK_DIR}/lighttpd_src"
    curl -fsSL "https://lighttpd.net{lt_major}.x/lighttpd-${lt_ver}.tar.xz" | \
        tar -xJ -C "${WORK_DIR}/lighttpd_src" --strip-components=1
    cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
    (
        cd "${WORK_DIR}/lighttpd_src"
        ./configure --prefix=/usr --libdir=/usr/lib/lighttpd --sysconfdir=/etc/lighttpd --with-openssl --with-pcre2 --with-zlib
        make -j"${cpus}"
        make install
    )
    tar -czf "${WORK_DIR}/${artifact}" /usr/sbin/lighttpd /usr/lib/lighttpd
    cache_put "${WORK_DIR}/${artifact}" "${artifact}"
fi

if [ -n "${LIGHTTPD_MODULES:-}" ]; then
    printf 'server.modules = (\n' > /etc/lighttpd/modules.conf
    first=1
    for mod in ${LIGHTTPD_MODULES}; do
        [ "${first}" -eq 0 ] && printf ',\n' >> /etc/lighttpd/modules.conf
        printf '    "%s"' "${mod}" >> /etc/lighttpd/modules.conf
        first=0
    done
    printf '\n)\n' >> /etc/lighttpd/modules.conf
fi

if [ ! -f /etc/systemd/system/lighttpd.service ] && [ ! -f /lib/systemd/system/lighttpd.service ]; then
    cat <<'EOF' > /etc/systemd/system/lighttpd.service
[Unit]
Description=Lighttpd Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=/usr/sbin/lighttpd -tt -f /etc/lighttpd/lighttpd.conf
ExecStart=/usr/sbin/lighttpd -D -f /etc/lighttpd/lighttpd.conf
ExecReload=/bin/kill -USR1 $MAINPID

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
fi

systemctl enable lighttpd 2>/dev/null || true
touch /etc/lighttpd/BUILT_FROM_SOURCE
/usr/sbin/lighttpd -v >/dev/null
Use code with caution.
sh
# recipes/apache_source.sh
#!/bin/sh
run_apt "apache_build_deps" "build-essential libapr1-dev libaprutil1-dev libpcre2-dev libssl-dev zlib1g-dev libnghttp2-dev"
mkdir -p /var/log/apache2 /var/run/apache2 /etc/apache2

ap_ver="${APACHE_VERSION:-2.4.62}"
ap_mods="${APACHE_MODULES:-rewrite ssl headers proxy proxy_fcgi}"
cfg_hash="$(printf '%s|%s' "${ap_ver}" "${ap_mods}" | sha256sum | awk '{print substr($1,1,8)}')"
artifact="apache-${ap_ver}-${cfg_hash}.tar.gz"

if cache_get "${artifact}" "${WORK_DIR}/${artifact}"; then
    tar -xzf "${WORK_DIR}/${artifact}" -C /
else
    mkdir -p "${WORK_DIR}/apache_src"
    curl -fsSL "https://apache.org{ap_ver}.tar.gz" | \
        tar -xz -C "${WORK_DIR}/apache_src" --strip-components=1
    cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"

    mod_flags="--enable-so --enable-http2"
    for mod in ${ap_mods}; do
        mod_flags="${mod_flags} --enable-${mod}"
    done

    (
        cd "${WORK_DIR}/apache_src"
        ./configure --prefix=/usr/local/apache2 --sbindir=/usr/sbin --sysconfdir=/etc/apache2 ${mod_flags}
        make -j"${cpus}"
        make install
    )
    tar -czf "${WORK_DIR}/${artifact}" /usr/sbin/apache2 /usr/sbin/httpd /usr/local/apache2 /etc/apache2 2>/dev/null || \
        tar -czf "${WORK_DIR}/${artifact}" /usr/local/apache2 /etc/apache2
    cache_put "${WORK_DIR}/${artifact}" "${artifact}"
fi

[ ! -e /usr/sbin/apache2 ] && [ -x /usr/sbin/httpd ] && ln -s /usr/sbin/httpd /usr/sbin/apache2

if [ ! -f /etc/systemd/system/apache2.service ] && [ ! -f /lib/systemd/system/apache2.service ]; then
    cat <<'EOF' > /etc/systemd/system/apache2.service
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
Environment=APACHE_RUN_USER=www-data
Environment=APACHE_RUN_GROUP=www-data
Environment=APACHE_PID_FILE=/var/run/apache2/apache2.pid
Environment=APACHE_RUN_DIR=/var/run/apache2
Environment=APACHE_LOCK_DIR=/var/lock/apache2
Environment=APACHE_LOG_DIR=/var/log/apache2
ExecStart=/usr/sbin/apachectl start
ExecStop=/usr/sbin/apachectl graceful-stop
ExecReload=/usr/sbin/apachectl graceful
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
fi

systemctl enable apache2 2>/dev/null || true
touch /etc/apache2/BUILT_FROM_SOURCE
/usr/sbin/apache2 -v >/dev/null
Use code with caution.

6. Remaining Recipes (s5cmd.sh, rclone.sh, s3fs.sh, postgres.sh, php.sh, wpcli.sh, composer.sh, clamav.sh, lego.sh)

sh
# recipes/s5cmd.sh
#!/bin/sh
url="$(wget -q -O - https://github.com | \
    jq -r ".assets[] | select(.name | endswith(\"linux_${ARCH}.deb\")).browser_download_url" | head -n 1)"
[ -n "${url}" ]
wget -q -O "${WORK_DIR}/s5cmd.deb" "${url}"
dpkg -i "${WORK_DIR}/s5cmd.deb"
/usr/bin/s5cmd version >/dev/null
Use code with caution.
sh
# recipes/rclone.sh
#!/bin/sh
if ! cache_get "rclone.bin" "/usr/bin/rclone"; then
    wget -q -O "${WORK_DIR}/rclone.zip" "https://rclone.org{ARCH}.zip"
    unzip -q "${WORK_DIR}/rclone.zip" -d "${WORK_DIR}/rclone"
    cp "${WORK_DIR}"/rclone/*/rclone /usr/bin/rclone
    chmod +x /usr/bin/rclone
    cache_put "/usr/bin/rclone" "rclone.bin"
fi
chmod +x /usr/bin/rclone
/usr/bin/rclone version >/dev/null
Use code with caution.
sh
# recipes/s3fs.sh
#!/bin/sh
if cache_get "s3fs.bin" "/usr/bin/s3fs"; then
    run_apt "s3fs_runtime" "libfuse3-dev"
    chmod +x /usr/bin/s3fs
else
    run_apt "s3fs_build" "build-essential git libfuse-dev libcurl4-openssl-dev libxml2-dev automake libtool pkg-config libssl-dev libfuse3-dev"
    cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
    (
        git clone --depth 1 https://github.com "${WORK_DIR}/s3fs-fuse"
        cd "${WORK_DIR}/s3fs-fuse"
        ./autogen.sh && ./configure --prefix=/usr --with-openssl && make -j"${cpus}" && make install
    )
    cache_put "/usr/bin/s3fs" "s3fs.bin"
fi
/usr/bin/s3fs --version >/dev/null
Use code with caution.
sh
# recipes/postgres.sh
#!/bin/sh
if [ ! -f /etc/apt/sources.list.d/pgdg.list ] && [ ! -f /etc/apt/sources.list.d/pgdg.sources ]; then
    run_apt "pg_common" "postgresql-common"
    yes | /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
fi
pg_ver="${POSTGRES_VERSION:-17}"
run_apt "postgres-${pg_ver}" "postgresql-${pg_ver} postgresql-client-${pg_ver}"
systemctl enable postgresql
/usr/bin/psql --version >/dev/null
Use code with caution.
sh
# recipes/php.sh
#!/bin/sh
php_ver="${PHP_VERSION:-8.4}"
use_native=0

if [ "${ID}" = "ubuntu" ]; then
    if { [ "${VERSION_ID}" = "24.04" ] && [ "${php_ver}" = "8.3" ]; } || \
       { [ "${VERSION_ID}" = "26.04" ] && [ "${php_ver}" = "8.5" ]; }; then
        use_native=1
    fi
elif [ "${ID}" = "debian" ]; then
    if [ "${VERSION_ID}" = "13" ] && [ "${php_ver}" = "8.4" ]; then
        use_native=1
    fi
fi

if [ "${use_native}" -eq 0 ]; then
    if [ "${ID}" = "ubuntu" ]; then
        if ! grep -rq "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
            run_apt "php_ppa_deps" "software-properties-common ca-certificates"
            add-apt-repository -y ppa:ondrej/php
        fi
    elif [ "${ID}" = "debian" ]; then
        if [ ! -f /etc/apt/sources.list.d/php.sources ] && [ ! -f /etc/apt/sources.list.d/php.list ]; then
            curl -fsSLo /usr/share/keyrings/deb.sury.org-php.gpg https://sury.org
            codename="$(lsb_release -sc)"
            printf 'Types: deb\nURIs: https://sury.org\nSuites: %s\nComponents: main\nArchitectures: %s\nSigned-By: /usr/share/keyrings/deb.sury.org-php.gpg\n' \
                "${codename}" "${ARCH}" > /etc/apt/sources.list.d/php.sources
        fi
    else
        printf 'Error: Unsupported OS for PHP recipe: %s\n' "${ID}" >&2
        exit 1
    fi
fi

if [ "${use_native}" -eq 1 ]; then
    pkg_list="php php-cli php-fpm"
    for mod in ${PHP_MODULES:-}; do pkg_list="${pkg_list} php-${mod}"; done
    cache_key="php-native-${ID}${VERSION_ID}"
else
    pkg_list="php${php_ver} php${php_ver}-cli php${php_ver}-fpm"
    for mod in ${PHP_MODULES:-}; do pkg_list="${pkg_list} php${php_ver}-${mod}"; done
    cache_key="php-${php_ver}"
fi

mod_hash="$(printf '%s' "${pkg_list}" | sha256sum | awk '{print substr($1,1,8)}')"
run_apt "${cache_key}-${mod_hash}" "${pkg_list}"

if [ "${use_native}" -eq 0 ] && [ -x "/usr/bin/php${php_ver}" ]; then
    update-alternatives --set php "/usr/bin/php${php_ver}"
    systemctl enable "php${php_ver}-fpm"
else
    systemctl enable php-fpm 2>/dev/null || systemctl enable "php${php_ver}-fpm" 2>/dev/null || true
fi
/usr/bin/php -v >/dev/null
Use code with caution.
sh
# recipes/wpcli.sh
#!/bin/sh
if ! cache_get "wp-cli.phar" "/usr/local/bin/wp"; then
    curl -fsSL -o "${WORK_DIR}/wp-cli.phar" https://githubusercontent.com
    curl -fsSL -o "${WORK_DIR}/wp-cli.phar.asc" https://githubusercontent.com.asc
    curl -fsSL https://githubusercontent.com | gpg --import
    gpg --verify "${WORK_DIR}/wp-cli.phar.asc" "${WORK_DIR}/wp-cli.phar"
    cp "${WORK_DIR}/wp-cli.phar" /usr/local/bin/wp
    chmod +x /usr/local/bin/wp
    cache_put "/usr/local/bin/wp" "wp-cli.phar"
fi
chmod +x /usr/local/bin/wp
/usr/local/bin/wp --info >/dev/null
Use code with caution.
sh
# recipes/composer.sh
#!/bin/sh
[ -x /usr/bin/php ] || { printf 'Error: PHP is required before installing Composer\n' >&2; exit 1; }
if ! cache_get "composer.phar" "/usr/local/bin/composer"; then
    expected_sig="$(curl -fsSL https://github.io)"
    curl -fsSL -o "${WORK_DIR}/composer-setup.php" https://getcomposer.org
    actual_sig="$(sha384sum "${WORK_DIR}/composer-setup.php" | awk '{print $1}')"
    [ -n "${expected_sig}" ] && [ "${expected_sig}" = "${actual_sig}" ]
    /usr/bin/php "${WORK_DIR}/composer-setup.php" --install-dir="${WORK_DIR}" --filename=composer
    cp "${WORK_DIR}/composer" /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    cache_put "/usr/local/bin/composer" "composer.phar"
fi
chmod +x /usr/local/bin/composer
/usr/local/bin/composer --version --no-interaction >/dev/null
Use code with caution.
sh
# recipes/clamav.sh
#!/bin/sh
run_apt "clamav" "clamav clamav-daemon"
systemctl stop clamav-freshclam 2>/dev/null || true
freshclam || true
systemctl enable clamav-freshclam clamav-daemon 2>/dev/null || true
systemctl start clamav-freshclam clamav-daemon 2>/dev/null || true
/usr/bin/clamscan --version >/dev/null
Use code with caution.
sh
# recipes/lego.sh
#!/bin/sh
if ! cache_get "lego.bin" "/usr/local/bin/lego"; then
    url="$(wget -q -O - https://github.com | \
        jq -r ".assets[] | select(.name | endswith(\"linux_${ARCH}.tar.gz\")).browser_download_url" | head -n 1)"
    [ -n "${url}" ]
    wget -q -O "${WORK_DIR}/lego.tar.gz" "${url}"
    tar -xzf "${WORK_DIR}/lego.tar.gz" -C "${WORK_DIR}" lego
    cp "${WORK_DIR}/lego" /usr/local/bin/lego
    chmod +x /usr/local/bin/lego
    cache_put "/usr/local/bin/lego" "lego.bin"
fi
chmod +x /usr/local/bin/lego
/usr/local/bin/lego --version >/dev/null
Use code with caution.

7. Single Copy-Paste AI Prompt Template (${HOME}/installation/recipes/README.md)

Save this file in your repository. Whenever you start a new chat, copy everything inside the block below, replace <SOFTWARE_NAME> at the bottom, and paste it.
markdown
# Single Copy-Paste Prompt for Generating New Recipes

Copy and paste the block below into any new AI chat session when you want a new recipe created:

---

```text
Write a self-contained POSIX `/bin/sh` recipe for my `InstallSoftware.sh` engine, along with its `software.conf` row and any `#@ KEY="VAL"` variables.

### System Rules & Context
1. **Strict POSIX `/bin/sh`:** Recipes are sourced inside `( set -e; . recipe.sh )` on Ubuntu or Debian. Do NOT use Bashisms (`[[`, arrays, `local`, `source`).
2. **Self-Contained:** Download or compile upstream sources directly inside `${WORK_DIR}`. If compiling a daemon from source, create its `/etc/systemd/system/<name>.service` unit if one doesn't exist and run `systemctl daemon-reload`.
3. **Available Context Variables:**
   - `${HOME}`: Toolkit root directory (exported)
   - `${WORK_DIR}`: Auto-cleaned temporary build directory
   - `${ID}`: OS identifier from `/etc/os-release` (`ubuntu` or `debian`)
   - `${VERSION_ID}`: OS release version (`24.04`, `26.04`, `13`, etc.)
   - `${ARCH}`: Normalized CPU architecture (`amd64` or `arm64`)
   - Any `#@ KEY="VAL"` variables defined at the top of `software.conf`
4. **Available Helper Functions:**
   - `run_apt "<cache_key>" "<pkg1 pkg2>"` — Installs APT packages with SHA-256 verified S3 `.deb` caching.
   - `cache_get "<s3_filename>" "<local_dest>"` — Pulls & SHA-256 verifies an artifact from S3 (`0` on hit, `1` on miss).
   - `cache_put "<local_src>" "<s3_filename>"` — Uploads an artifact + `.sha256` sidecar to S3.
5. **Conventions:**
   - Always check `cache_get` before downloading or compiling; call `cache_put` afterward.
   - Wrap `cd` calls in `( ... )` subshells.
   - End every recipe with a smoke-test verification command (`--version`, `-v`, `-t`) so `InstallSoftware.sh` only marks it `.done` when verified.

### Reference Example (`recipes/wpcli.sh`)
#!/bin/sh
if ! cache_get "wp-cli.phar" "/usr/local/bin/wp"; then
    curl -fsSL -o "\${WORK_DIR}/wp-cli.phar" https://githubusercontent.com
    curl -fsSL -o "\${WORK_DIR}/wp-cli.phar.asc" https://githubusercontent.com.asc
    curl -fsSL https://githubusercontent.com | gpg --import
    gpg --verify "\({WORK_DIR}/wp-cli.phar.asc" "\){WORK_DIR}/wp-cli.phar"
    cp "\${WORK_DIR}/wp-cli.phar" /usr/local/bin/wp
    chmod +x /usr/local/bin/wp
    cache_put "/usr/local/bin/wp" "wp-cli.phar"
fi
chmod +x /usr/local/bin/wp
/usr/local/bin/wp --info >/dev/null

### Task
Generate a new recipe for: <SOFTWARE_NAME_AND_REQUIREMENTS>
```
Use code with caution.

8. Final Permissions & Syntax Validation Command

Run this once after creating the files to apply executable permissions and validate POSIX syntax across every script:
sh
HOME="$(cat /home/homedir.dat)"
chmod +x "${HOME}/installation/InstallSoftware.sh" "${HOME}/installation/recipes/"*.sh
for f in "${HOME}/installation/InstallSoftware.sh" "${HOME}/installation/recipes/"*.sh; do
    sh -n "$f" && printf '[OK] %s\n' "$f"
done
Use code with caution.
If you'd like, I can:
• Convert any remaining legacy scripts from your repository using that prompt template right now
• Help you test InstallSoftware.sh on a fresh instance and verify the S3 cache bucket contents








-------------------------------------------------
this is the more complex version, if needed
-------------------------------------------------









# 3. Run your webserver application/reverse-proxy configuration scripts
Use code with caution.
If you'd like, I can:
Show how to wire post-install webserver configuration (ConfigureNginxForApplication.sh / ConfigureNginxForReverseProxy.sh) directly into the webserver recipesHelp you test the manifest with --dry-run or --status before your next cloud-init boot


Here is the complete, unified ADT InstallSoftware.sh solution (Debian & Ubuntu, self-contained profile.env, ADT Datastore S3 pull-through cache, and all recipes), organized into clean, copy-pasteable sections.

1. Filesystem Layout

text
${HOME}/
├── config/
│   ├── software.manifest           <── Master 4-column software list
│   └── profiles/
│       └── default.env             <── Self-contained feature flags, versions & modules
└── installation/
    ├── InstallSoftware.sh          <── Self-contained POSIX engine + ADT Datastore cache
    └── recipes/
        ├── README.md               <── Recipe authoring contract
        ├── s5cmd.sh
        ├── s3cmd.sh
        ├── rclone.sh
        ├── s3fs.sh
        ├── ufw.sh
        ├── postgres.sh
        ├── php.sh
        ├── wpcli.sh
        ├── composer.sh
        ├── clamav.sh
        ├── lego.sh
        ├── nginx_source.sh
        ├── lighttpd_source.sh
        └── apache_source.sh
Use code with caution.

2. Master Server Profile (${HOME}/config/profiles/default.env)

sh
# Datastore & Storage Clients
ENABLE_S5CMD=1
ENABLE_S3CMD=0
ENABLE_RCLONE=0
ENABLE_S3FS_REPO=0
ENABLE_S3FS_SOURCE=1

# Core System, Security & Mail Utilities
ENABLE_UFW=1
ENABLE_FAIL2BAN=0
ENABLE_CLAMAV=0
ENABLE_LEGO=0
ENABLE_TEXTBROWSER_W3M=0
ENABLE_TEXTBROWSER_LYNX=0
ENABLE_TEXTBROWSER_ELINKS=0

# Databases
ENABLE_MARIADB=0
ENABLE_MARIADB_CLIENT=0
ENABLE_POSTGRES=1
POSTGRES_VERSION="17"

# PHP & Application Tools
ENABLE_PHP=1
PHP_VERSION="8.4"
PHP_MODULES="mysql pgsql curl xml mbstring zip gd intl bcmath"
ENABLE_WPCLI=1
ENABLE_COMPOSER=0

# Webservers & Reverse Proxies
ENABLE_NGINX_REPO=1
ENABLE_NGINX_SOURCE=0
ENABLE_LIGHTTPD_REPO=0
ENABLE_LIGHTTPD_SOURCE=0
ENABLE_APACHE_REPO=0
ENABLE_APACHE_SOURCE=0
APACHE_MODULES="rewrite ssl headers proxy proxy_fcgi"
Use code with caution.

3. Master Manifest (${HOME}/config/software.manifest)

text
# NAME            | ENABLE_FLAG               | TYPE   | TARGET
# ---------------------------------------------------------------------------
prereqs           | ALWAYS                    | apt    | curl wget jq unzip ca-certificates gnupg lsb-release
s5cmd             | ENABLE_S5CMD              | recipe | s5cmd.sh
s3cmd             | ENABLE_S3CMD              | recipe | s3cmd.sh
rclone            | ENABLE_RCLONE             | recipe | rclone.sh
s3fs_repo         | ENABLE_S3FS_REPO          | apt    | libfuse3-dev s3fs
s3fs_source       | ENABLE_S3FS_SOURCE        | recipe | s3fs.sh
ufw               | ENABLE_UFW                | recipe | ufw.sh
sendemail         | ALWAYS                    | apt    | sendemail
ssmtp             | ALWAYS                    | apt    | ssmtp mailutils
fail2ban          | ENABLE_FAIL2BAN           | apt    | fail2ban
clamav            | ENABLE_CLAMAV             | recipe | clamav.sh
lego              | ENABLE_LEGO               | recipe | lego.sh
w3m               | ENABLE_TEXTBROWSER_W3M    | apt    | w3m
lynx              | ENABLE_TEXTBROWSER_LYNX   | apt    | lynx
elinks            | ENABLE_TEXTBROWSER_ELINKS | apt    | elinks
mariadb           | ENABLE_MARIADB            | apt    | mariadb-server mariadb-client
mariadb_client    | ENABLE_MARIADB_CLIENT     | apt    | mariadb-client
postgres          | ENABLE_POSTGRES           | recipe | postgres.sh
php               | ENABLE_PHP                | recipe | php.sh
wpcli             | ENABLE_WPCLI              | recipe | wpcli.sh
composer          | ENABLE_COMPOSER           | recipe | composer.sh
nginx_repo        | ENABLE_NGINX_REPO         | apt    | nginx
nginx_source      | ENABLE_NGINX_SOURCE       | recipe | nginx_source.sh
lighttpd_repo     | ENABLE_LIGHTTPD_REPO      | apt    | lighttpd
lighttpd_source   | ENABLE_LIGHTTPD_SOURCE    | recipe | lighttpd_source.sh
apache_repo       | ENABLE_APACHE_REPO        | apt    | apache2 apache2-utils
apache_source     | ENABLE_APACHE_SOURCE      | recipe | apache_source.sh
Use code with caution.

4. InstallSoftware.sh — Block 1: CLI Parsing, Profile & OS Detection

sh
#!/bin/sh
set -eu

HOME="$(cat /home/homedir.dat)"
MANIFEST="${HOME}/config/software.manifest"
PROFILE="${HOME}/config/profiles/default.env"
RECIPES="${HOME}/installation/recipes"
STATE_DIR="${HOME}/runtime/installedsoftware"
LOCK_DIR="/var/lock/adt_pkgbox.lock"
CACHE_BUCKET="software-cache"

DRY_RUN=0
STATUS_MODE=0
ONLY_TARGET=""
RESET_TARGET=""

while [ $# -gt 0 ]; do
    case "$1" in
        --profile|-p)
            PROFILE="${2:-}"
            [ -n "${PROFILE}" ] || { printf 'Error: --profile requires a file path\n' >&2; exit 1; }
            shift 2
            ;;
        --profile=*)  PROFILE="${1#--profile=}"; shift ;;
        --dry-run|-n) DRY_RUN=1; shift ;;
        --status|-s)  STATUS_MODE=1; shift ;;
        --only)
            ONLY_TARGET="${2:-}"
            [ -n "${ONLY_TARGET}" ] || { printf 'Error: --only requires a target name\n' >&2; exit 1; }
            shift 2
            ;;
        --only=*)     ONLY_TARGET="${1#--only=}"; shift ;;
        --reset)
            RESET_TARGET="${2:-}"
            [ -n "${RESET_TARGET}" ] || { printf 'Error: --reset requires a target name or "all"\n' >&2; exit 1; }
            shift 2
            ;;
        --reset=*)    RESET_TARGET="${1#--reset=}"; shift ;;
        *)
            printf 'Usage: %s [--profile <file>] [--status] [--dry-run] [--only <name>] [--reset <name|all>]\n' "$0" >&2
            exit 1
            ;;
    esac
done

if [ ! -f "${PROFILE}" ] && [ -f "${HOME}/config/profiles/${PROFILE}.env" ]; then
    PROFILE="${HOME}/config/profiles/${PROFILE}.env"
fi

[ -f "${PROFILE}" ] || { printf 'Error: Profile not found: %s\n' "${PROFILE}" >&2; exit 1; }
mkdir -p "${STATE_DIR}" /var/lock

if [ -n "${RESET_TARGET}" ]; then
    if [ "${RESET_TARGET}" = "all" ]; then
        rm -f "${STATE_DIR}"/*.hash
        printf 'Cleared all state hashes in %s\n' "${STATE_DIR}"
    else
        rm -f "${STATE_DIR}/${RESET_TARGET}.hash"
        printf 'Cleared state hash for %s\n' "${RESET_TARGET}"
    fi
    [ -z "${ONLY_TARGET}" ] && exit 0
fi

if [ "${DRY_RUN}" -eq 0 ] && [ "${STATUS_MODE}" -eq 0 ]; then
    if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
        printf 'Error: Another InstallSoftware instance is running (%s exists).\n' "${LOCK_DIR}" >&2
        exit 1
    fi
fi

WORK_DIR="$(mktemp -d /tmp/adt_pkgbox.XXXXXX)"
trap 'rm -rf "${WORK_DIR}" "${LOCK_DIR}"' EXIT INT TERM

. "${PROFILE}"
PROFILE_CONTENT="$(cat "${PROFILE}")"

. /etc/os-release
RAW_ARCH="$(uname -m)"
case "${RAW_ARCH}" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *)       ARCH="${RAW_ARCH}" ;;
esac

CACHE_PREFIX="${CACHE_BUCKET}/${ID}-${VERSION_ID}-${ARCH}"
DATASTORE_MOUNTED=0

log() { printf '[%s] [%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$2"; }
Use code with caution.

5. InstallSoftware.sh — Block 2: ADT Datastore Cache & APT Engine (Append)

sh
datastore_ready() {
    [ -x /usr/bin/s5cmd ] || [ -x /usr/bin/s3cmd ] || [ -x /usr/bin/rclone ] || [ -x /usr/bin/s3fs ]
}

ensure_datastore_mounted() {
    if [ "${DATASTORE_MOUNTED}" -eq 0 ] && datastore_ready; then
        "${HOME}/providerscripts/datastore/MountDatastore.sh" "${CACHE_BUCKET}" >/dev/null 2>&1 || true
        DATASTORE_MOUNTED=1
    fi
}

cache_get() {
    key="$1"; dest="$2"
    datastore_ready || return 1
    ensure_datastore_mounted
    rm -f "${dest}" "${dest}.sha256"

    "${HOME}/providerscripts/datastore/GetFromDatastore.sh" "${CACHE_PREFIX}/${key}" "${dest}" >/dev/null 2>&1 || return 1
    "${HOME}/providerscripts/datastore/GetFromDatastore.sh" "${CACHE_PREFIX}/${key}.sha256" "${dest}.sha256" >/dev/null 2>&1 || return 1

    [ -s "${dest}" ] && [ -s "${dest}.sha256" ] || { rm -f "${dest}" "${dest}.sha256"; return 1; }

    expected="$(awk '{print $1}' "${dest}.sha256")"
    actual="$(sha256sum "${dest}" | awk '{print $1}')"
    if [ -n "${expected}" ] && [ "${expected}" = "${actual}" ]; then
        rm -f "${dest}.sha256"
        log "CACHE" "HIT: ${key}"
        return 0
    fi

    log "WARN" "CACHE" "CORRUPT: ${key} failed SHA-256 check"
    rm -f "${dest}" "${dest}.sha256"
    return 1
}

cache_put() {
    src="$1"; key="$2"
    datastore_ready || return 0
    [ -s "${src}" ] || return 0
    ensure_datastore_mounted

    sha256sum "${src}" | awk '{print $1}' > "${src}.sha256"
    if "${HOME}/providerscripts/datastore/PutToDatastore.sh" "${src}" "${CACHE_PREFIX}/${key}" >/dev/null 2>&1 && \
       "${HOME}/providerscripts/datastore/PutToDatastore.sh" "${src}.sha256" "${CACHE_PREFIX}/${key}.sha256" >/dev/null 2>&1; then
        log "CACHE" "PUSH: ${key}"
    fi
    rm -f "${src}.sha256"
}

run_apt() {
    name="$1"; pkgs="$2"
    deb_dir="${WORK_DIR}/${name}_debs"
    tar_path="${WORK_DIR}/${name}.tar.gz"
    mkdir -p "${deb_dir}/partial"
    export DEBIAN_FRONTEND=noninteractive

    if cache_get "${name}.tar.gz" "${tar_path}"; then
        tar -xzf "${tar_path}" -C "${deb_dir}"
        apt-get -o DPkg::Lock::Timeout=-1 -o "Dir::Cache::Archives=${deb_dir}" -qq -y install --no-download ${pkgs} || \
        apt-get -o DPkg::Lock::Timeout=-1 -o "Dir::Cache::Archives=${deb_dir}" -qq -y install ${pkgs}
        return 0
    fi

    apt-get -o DPkg::Lock::Timeout=-1 -qq -y update
    apt-get -o DPkg::Lock::Timeout=-1 -o "Dir::Cache::Archives=${deb_dir}" -qq -y install --download-only --reinstall ${pkgs}
    apt-get -o DPkg::Lock::Timeout=-1 -o "Dir::Cache::Archives=${deb_dir}" -qq -y install ${pkgs}

    if ls "${deb_dir}"/*.deb >/dev/null 2>&1; then
        tar -czf "${tar_path}" -C "${deb_dir}" .
        cache_put "${tar_path}" "${name}.tar.gz"
    fi
}
Use code with caution.

6. InstallSoftware.sh — Block 3: Main Orchestration Loop (Append)

sh
if [ "${STATUS_MODE}" -eq 1 ]; then
    printf 'Profile: %s (OS: %s %s)\n\n' "${PROFILE}" "${ID}" "${VERSION_ID}"
    printf '%-16s | %-10s | %-15s | %-8s | %s\n' "TARGET" "ENABLED" "STATE" "TYPE" "DEFINITION"
    printf '%-16s-+-%-10s-+-%-15s-+-%-8s-+-%s\n' "----------------" "----------" "---------------" "--------" "--------------------"
fi

grep -vE '^[[:space:]]*#|^[[:space:]]*$' "${MANIFEST}" | while IFS='|' read -r r_name r_flag r_type r_target
do
    name="$(echo "$r_name" | xargs)"
    flag="$(echo "$r_flag" | xargs)"
    type="$(echo "$r_type" | xargs)"
    target="$(echo "$r_target" | xargs)"

    [ -n "${ONLY_TARGET}" ] && [ "${name}" != "${ONLY_TARGET}" ] && continue

    enabled="yes"
    if [ "${flag}" != "ALWAYS" ]; then
        case "${flag}" in *[!A-Z0-9_]*) log "ERROR" "Invalid flag name: ${flag}"; exit 1 ;; esac
        flag_val="$(eval "printf '%s' \"\${${flag}:-0}\"")"
        [ "${flag_val}" = "1" ] || enabled="no"
    fi

    recipe_body=""
    [ "${type}" = "recipe" ] && [ -f "${RECIPES}/${target}" ] && recipe_body="$(cat "${RECIPES}/${target}")"
    desired_hash="$(printf '%s|%s|%s\n%s\n%s' "${name}" "${type}" "${target}" "${PROFILE_CONTENT}" "${recipe_body}" | sha256sum | awk '{print $1}')"
    current_hash="$(cat "${STATE_DIR}/${name}.hash" 2>/dev/null || true)"

    if [ "${STATUS_MODE}" -eq 1 ]; then
        if [ "${enabled}" = "no" ]; then
            state="DISABLED"
        elif [ "${desired_hash}" = "${current_hash}" ]; then
            state="UP_TO_DATE"
        elif [ -n "${current_hash}" ]; then
            state="DRIFTED"
        else
            state="PENDING"
        fi
        printf '%-16s | %-10s | %-15s | %-8s | %s\n' "${name}" "${enabled}" "${state}" "${type}" "${target}"
        continue
    fi

    if [ -z "${ONLY_TARGET}" ]; then
        [ "${enabled}" = "yes" ] || continue
        [ "${desired_hash}" = "${current_hash}" ] && continue
    fi

    if [ "${DRY_RUN}" -eq 1 ]; then
        status="NEW"
        [ -n "${current_hash}" ] && status="DRIFT_UPDATE"
        printf '[DRY-RUN] [%-12s] %-15s | Type: %-6s | Target: %s\n' "${status}" "${name}" "${type}" "${target}"
        continue
    fi

    log "INFO" "Installing ${name} (os=${ID}-${VERSION_ID}, profile=$(basename "${PROFILE}"))..."
    installed=0
    for attempt in 1 2 3; do
        rc=0
        case "${type}" in
            "apt")
                run_apt "${name}" "${target}" || rc=$?
                ;;
            "recipe")
                ( set -e; . "${RECIPES}/${target}" ) || rc=$?
                ;;
            *)
                log "ERROR" "Unknown type: ${type}"; exit 1
                ;;
        esac

        if [ "${rc}" -eq 0 ]; then
            printf '%s\n' "${desired_hash}" > "${STATE_DIR}/${name}.hash"
            installed=1
            break
        fi
        log "WARN" "Retry ${attempt}/3 for ${name} (rc=${rc})..."
        sleep 2
    done

    if [ "${installed}" -ne 1 ]; then
        log "ERROR" "Failed to install ${name}"
        "${HOME}/services/email/SendEmail.sh" "INSTALLATION ERROR ${name}" "I believe that ${name} hasn't installed correctly, please investigate" "ERROR" || true
        exit 1
    fi
    log "OK" "${name} verified and installed."
done
Use code with caution.

7. Recipes Part A: Storage & Security (s5cmd.sh, s3cmd.sh, rclone.sh, s3fs.sh, ufw.sh, clamav.sh, lego.sh)

sh
# recipes/s5cmd.sh
#!/bin/sh
url="$(wget -q -O - https://github.com | \
    jq -r ".assets[] | select(.name | endswith(\"linux_${ARCH}.deb\")).browser_download_url" | head -n 1)"
[ -n "${url}" ]
wget -q -O "${WORK_DIR}/s5cmd.deb" "${url}"
dpkg -i "${WORK_DIR}/s5cmd.deb"
/usr/bin/s5cmd version >/dev/null
Use code with caution.
sh
# recipes/s3cmd.sh
#!/bin/sh
run_apt "s3cmd" "s3cmd"
[ -f "${HOME}/.s3cfg" ] && cp "${HOME}/.s3cfg" /root/
/usr/bin/s3cmd --version >/dev/null
Use code with caution.
sh
# recipes/rclone.sh
#!/bin/sh
if ! cache_get "rclone.bin" "/usr/bin/rclone"; then
    wget -q -O "${WORK_DIR}/rclone.zip" "https://rclone.org{ARCH}.zip"
    unzip -q "${WORK_DIR}/rclone.zip" -d "${WORK_DIR}/rclone"
    cp "${WORK_DIR}"/rclone/*/rclone /usr/bin/rclone
    chmod +x /usr/bin/rclone
    cache_put "/usr/bin/rclone" "rclone.bin"
fi
chmod +x /usr/bin/rclone
/usr/bin/rclone version >/dev/null
Use code with caution.
sh
# recipes/s3fs.sh
#!/bin/sh
if cache_get "s3fs.bin" "/usr/bin/s3fs"; then
    run_apt "s3fs_runtime" "libfuse3-dev"
    chmod +x /usr/bin/s3fs
else
    run_apt "s3fs_build" "build-essential git libfuse-dev libcurl4-openssl-dev libxml2-dev automake libtool pkg-config libssl-dev libfuse3-dev"
    (
        cd "${WORK_DIR}"
        "${HOME}/services/git/CloneRepository.sh" "github" "" "s3fs-fuse" "s3fs-fuse"
        cd "${WORK_DIR}/s3fs-fuse"
        ./autogen.sh && ./configure --prefix=/usr --with-openssl && make && make install
    )
    cache_put "/usr/bin/s3fs" "s3fs.bin"
fi
/usr/bin/s3fs --version >/dev/null
Use code with caution.
sh
# recipes/ufw.sh
#!/bin/sh
run_apt "ufw" "ufw"
/usr/sbin/ufw disable
/usr/sbin/ufw status >/dev/null
Use code with caution.
sh
# recipes/clamav.sh
#!/bin/sh
run_apt "clamav" "clamav clamav-daemon"
systemctl stop clamav-freshclam 2>/dev/null || true
freshclam || true
systemctl enable clamav-freshclam clamav-daemon 2>/dev/null || true
systemctl start clamav-freshclam clamav-daemon 2>/dev/null || true
/usr/bin/clamscan --version >/dev/null
Use code with caution.
sh
# recipes/lego.sh
#!/bin/sh
if ! cache_get "lego.bin" "/usr/local/bin/lego"; then
    url="$(wget -q -O - https://github.com | \
        jq -r ".assets[] | select(.name | endswith(\"linux_${ARCH}.tar.gz\")).browser_download_url" | head -n 1)"
    [ -n "${url}" ]
    wget -q -O "${WORK_DIR}/lego.tar.gz" "${url}"
    tar -xzf "${WORK_DIR}/lego.tar.gz" -C "${WORK_DIR}" lego
    cp "${WORK_DIR}/lego" /usr/local/bin/lego
    chmod +x /usr/local/bin/lego
    cache_put "/usr/local/bin/lego" "lego.bin"
fi
chmod +x /usr/local/bin/lego
/usr/local/bin/lego --version >/dev/null
Use code with caution.

8. Recipes Part B: Databases, PHP & Webservers (postgres.sh, php.sh, wpcli.sh, composer.sh, nginx_source.sh, lighttpd_source.sh, apache_source.sh)

sh
# recipes/postgres.sh
#!/bin/sh
if [ ! -f /etc/apt/sources.list.d/pgdg.list ] && [ ! -f /etc/apt/sources.list.d/pgdg.sources ]; then
    run_apt "pg_common" "postgresql-common"
    yes | /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
fi
pg_ver="${POSTGRES_VERSION:-17}"
run_apt "postgres-${pg_ver}" "postgresql-${pg_ver} postgresql-client-${pg_ver}"
systemctl enable postgresql
/usr/bin/psql --version >/dev/null
Use code with caution.
sh
# recipes/php.sh
#!/bin/sh
php_ver="${PHP_VERSION:-8.4}"
use_native=0

if [ "${ID}" = "ubuntu" ]; then
    if { [ "${VERSION_ID}" = "24.04" ] && [ "${php_ver}" = "8.3" ]; } || \
       { [ "${VERSION_ID}" = "26.04" ] && [ "${php_ver}" = "8.5" ]; }; then
        use_native=1
    fi
elif [ "${ID}" = "debian" ]; then
    if [ "${VERSION_ID}" = "13" ] && [ "${php_ver}" = "8.4" ]; then
        use_native=1
    fi
fi

if [ "${use_native}" -eq 0 ]; then
    if [ "${ID}" = "ubuntu" ]; then
        if ! grep -rq "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
            run_apt "php_ppa_deps" "software-properties-common ca-certificates"
            add-apt-repository -y ppa:ondrej/php
        fi
    elif [ "${ID}" = "debian" ]; then
        if [ ! -f /etc/apt/sources.list.d/php.sources ] && [ ! -f /etc/apt/sources.list.d/php.list ]; then
            curl -fsSLo /usr/share/keyrings/deb.sury.org-php.gpg https://sury.org
            codename="$(lsb_release -sc)"
            printf 'Types: deb\nURIs: https://sury.org\nSuites: %s\nComponents: main\nArchitectures: %s\nSigned-By: /usr/share/keyrings/deb.sury.org-php.gpg\n' \
                "${codename}" "${ARCH}" > /etc/apt/sources.list.d/php.sources
        fi
    else
        printf 'Error: Unsupported OS for PHP recipe: %s\n' "${ID}" >&2
        exit 1
    fi
fi

if [ "${use_native}" -eq 1 ]; then
    pkg_list="php php-cli php-fpm"
    for mod in ${PHP_MODULES:-}; do pkg_list="${pkg_list} php-${mod}"; done
    cache_key="php-native-${ID}${VERSION_ID}"
else
    pkg_list="php${php_ver} php${php_ver}-cli php${php_ver}-fpm"
    for mod in ${PHP_MODULES:-}; do pkg_list="${pkg_list} php${php_ver}-${mod}"; done
    cache_key="php-${php_ver}"
fi

mod_hash="$(printf '%s' "${pkg_list}" | sha256sum | awk '{print substr($1,1,8)}')"
run_apt "${cache_key}-${mod_hash}" "${pkg_list}"

if [ "${use_native}" -eq 0 ] && [ -x "/usr/bin/php${php_ver}" ]; then
    update-alternatives --set php "/usr/bin/php${php_ver}"
    systemctl enable "php${php_ver}-fpm"
else
    systemctl enable php-fpm 2>/dev/null || systemctl enable "php${php_ver}-fpm" 2>/dev/null || true
fi
/usr/bin/php -v >/dev/null
Use code with caution.
sh
# recipes/wpcli.sh
#!/bin/sh
if ! cache_get "wp-cli.phar" "/usr/local/bin/wp"; then
    curl -fsSL -o "${WORK_DIR}/wp-cli.phar" https://githubusercontent.com
    curl -fsSL -o "${WORK_DIR}/wp-cli.phar.asc" https://githubusercontent.com.asc
    curl -fsSL https://githubusercontent.com | gpg --import
    gpg --verify "${WORK_DIR}/wp-cli.phar.asc" "${WORK_DIR}/wp-cli.phar"
    cp "${WORK_DIR}/wp-cli.phar" /usr/local/bin/wp
    chmod +x /usr/local/bin/wp
    cache_put "/usr/local/bin/wp" "wp-cli.phar"
fi
chmod +x /usr/local/bin/wp
/usr/local/bin/wp --info >/dev/null
Use code with caution.
sh
# recipes/composer.sh
#!/bin/sh
if ! cache_get "composer.phar" "/usr/local/bin/composer"; then
    expected_sig="$(curl -fsSL https://github.io)"
    curl -fsSL -o "${WORK_DIR}/composer-setup.php" https://getcomposer.org
    actual_sig="$(sha384sum "${WORK_DIR}/composer-setup.php" | awk '{print $1}')"
    [ -n "${expected_sig}" ] && [ "${expected_sig}" = "${actual_sig}" ]
    /usr/bin/php "${WORK_DIR}/composer-setup.php" --install-dir="${WORK_DIR}" --filename=composer
    cp "${WORK_DIR}/composer" /usr/local/bin/composer
    chmod +x /usr/local/bin/composer
    cache_put "/usr/local/bin/composer" "composer.phar"
fi
chmod +x /usr/local/bin/composer
/usr/local/bin/composer --version --no-interaction >/dev/null
Use code with caution.
sh
# recipes/nginx_source.sh
#!/bin/sh
run_apt "nginx_build_deps" "build-essential libpcre2-dev zlib1g-dev libssl-dev"
mkdir -p /var/log/nginx /var/cache/nginx
if cache_get "nginx-compiled.tar.gz" "${WORK_DIR}/nginx.tar.gz"; then
    tar -xzf "${WORK_DIR}/nginx.tar.gz" -C /
else
    "${HOME}/installation/nginx/BuildNginxFromSource.sh"
    tar -czf "${WORK_DIR}/nginx.tar.gz" /usr/sbin/nginx /etc/nginx /usr/lib/nginx 2>/dev/null || \
        tar -czf "${WORK_DIR}/nginx.tar.gz" /usr/sbin/nginx /etc/nginx
    cache_put "${WORK_DIR}/nginx.tar.gz" "nginx-compiled.tar.gz"
fi
touch /etc/nginx/BUILT_FROM_SOURCE
/usr/sbin/nginx -t >/dev/null
Use code with caution.
sh
# recipes/lighttpd_source.sh
#!/bin/sh
run_apt "lighttpd_build_deps" "build-essential autoconf automake libtool pkg-config libpcre2-dev zlib1g-dev libssl-dev"
if cache_get "lighttpd-compiled.tar.gz" "${WORK_DIR}/lighttpd.tar.gz"; then
    tar -xzf "${WORK_DIR}/lighttpd.tar.gz" -C /
else
    "${HOME}/installation/lighttpd/BuildLighttpdFromSource.sh"
    tar -czf "${WORK_DIR}/lighttpd.tar.gz" /usr/sbin/lighttpd /usr/lib/lighttpd /etc/lighttpd
    cache_put "${WORK_DIR}/lighttpd.tar.gz" "lighttpd-compiled.tar.gz"
fi
mkdir -p /etc/lighttpd /var/log/lighttpd
touch /etc/lighttpd/BUILT_FROM_SOURCE
/usr/sbin/lighttpd -v >/dev/null
Use code with caution.
sh
# recipes/apache_source.sh
#!/bin/sh
run_apt "apache_build_deps" "build-essential libapr1-dev libaprutil1-dev libpcre2-dev libssl-dev zlib1g-dev libnghttp2-dev"
mkdir -p /var/log/apache2 /var/run/apache2
if cache_get "apache-compiled.tar.gz" "${WORK_DIR}/apache.tar.gz"; then
    tar -xzf "${WORK_DIR}/apache.tar.gz" -C /
else
    "${HOME}/installation/apache/BuildApacheFromSource.sh"
    archive_paths="/usr/sbin/apache2 /etc/apache2"
    [ -d /usr/lib/apache2 ] && archive_paths="${archive_paths} /usr/lib/apache2"
    [ -d /usr/local/apache2 ] && archive_paths="${archive_paths} /usr/local/apache2"
    tar -czf "${WORK_DIR}/apache.tar.gz" ${archive_paths}
    cache_put "${WORK_DIR}/apache.tar.gz" "apache-compiled.tar.gz"
fi
if [ -x /usr/sbin/a2enmod ]; then
    for mod in ${APACHE_MODULES:-}; do
        /usr/sbin/a2enmod "${mod}" || true
    done
fi
mkdir -p /etc/apache2
touch /etc/apache2/BUILT_FROM_SOURCE
/usr/sbin/apache2 -v >/dev/null
Use code with caution.

9. Recipe Contract (${HOME}/installation/recipes/README.md)

markdown
# ADT Recipe Authoring Spec

When generating a new recipe in `${HOME}/installation/recipes/<name>.sh`, follow these rules:

1. **Strict POSIX `/bin/sh`:** Sourced inside `( set -e; . recipe.sh )`. Do not use Bashisms (`[[`, arrays, `local`).
2. **Available Context Variables:**
   - `${HOME}`: Toolkit root directory
   - `${WORK_DIR}`: Auto-cleaned temporary build directory
   - `${ID}`: OS identifier from `/etc/os-release` (`ubuntu` or `debian`)
   - `${VERSION_ID}`: OS release version (`24.04`, `26.04`, `13`, etc.)
   - `${ARCH}`: Normalized CPU architecture (`amd64` or `arm64`)
   - All variables defined in the active `profile.env`
3. **Available Helper Functions:**
   - `run_apt "<cache_key>" "<pkg1 pkg2>"` — Installs APT packages with S3 `.deb` bundle caching.
   - `cache_get "<s3_filename>" "<local_dest>"` — Pulls & SHA-256 verifies artifact from S3 (`0` on hit, `1` on miss).
   - `cache_put "<local_src>" "<s3_filename>"` — Uploads artifact + `.sha256` sidecar to S3.
4. **Conventions:**
   - Always check `cache_get` before downloading or compiling; call `cache_put` after building.
   - Wrap `cd` calls in `( ... )` subshells.
   - End every recipe with a smoke-test verification command (`--version`, `-v`, `-t`).
   - Also output the matching `ENABLE_*` variable for `default.env` and row for `software.manifest`.
Use code with caution.
Would you like to:
• Run a syntax & permission check (chmod +x + sh -n) across InstallSoftware.sh and all recipes
• Upload any remaining legacy scripts from your repository to convert them into recipes
