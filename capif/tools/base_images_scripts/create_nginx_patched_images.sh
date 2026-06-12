#!/bin/bash

set -euo pipefail

NGINX_VERSION=1.27.1
PLATFORMS=("linux/arm64"
"linux/amd64")
PATCH_REPO="https://labs.etsi.org/rep/ocf/tools/nginx-sslkeylog.git"
REGISTRY="labs.etsi.org:5050/ocf/capif"

MANIFEST_AMEND=""
for platform in "${PLATFORMS[@]}";do
  image_name="nginx-ocf-patched:$NGINX_VERSION"
  echo "$image_name pulled for platform $platform"

  container_id=$(docker run -d --platform=$platform --name build-nginx debian:bullseye sleep infinity)

  docker exec $container_id bash -c "
    set -e

    echo 'Installing build dependencies...'
    apt-get update && apt-get install -y \
      build-essential \
      libpcre3-dev \
      libssl-dev \
      zlib1g-dev \
      curl \
      patch \
      ca-certificates \
      openssl \
      git \
      jq \
      gettext

    echo 'Creating nginx user...'
    useradd -r -d /etc/nginx -s /sbin/nologin nginx

    echo 'Downloading NGINX $NGINX_VERSION...'
    curl -LO https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
    tar -xzf nginx-${NGINX_VERSION}.tar.gz
    cd nginx-${NGINX_VERSION}

    echo 'Cloning and applying patch...'
    git clone ${PATCH_REPO} ../nginx-sslkeylog
    patch -p1 < ../nginx-sslkeylog/nginx-patches/${NGINX_VERSION}.patch

    echo 'Configuring NGINX...'
    ./configure \
      --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --modules-path=/usr/lib/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log \
      --pid-path=/var/run/nginx.pid \
      --lock-path=/var/run/nginx.lock \
      --http-client-body-temp-path=/var/cache/nginx/client_temp \
      --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
      --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
      --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
      --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
      --user=nginx \
      --group=nginx \
      --with-compat \
      --with-file-aio \
      --with-threads \
      --with-http_addition_module \
      --with-http_auth_request_module \
      --with-http_dav_module \
      --with-http_flv_module \
      --with-http_gunzip_module \
      --with-http_gzip_static_module \
      --with-http_mp4_module \
      --with-http_random_index_module \
      --with-http_realip_module \
      --with-http_secure_link_module \
      --with-http_slice_module \
      --with-http_ssl_module \
      --with-http_stub_status_module \
      --with-http_sub_module \
      --with-http_v2_module \
      --with-http_v3_module \
      --with-mail \
      --with-mail_ssl_module \
      --with-stream \
      --with-stream_realip_module \
      --with-stream_ssl_module \
      --with-stream_ssl_preread_module \
      --with-cc-opt='-g -O2 -ffile-prefix-map=/data/builder/debuild/nginx-${NGINX_VERSION}/debian/debuild-base/nginx-${NGINX_VERSION}=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
      --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
      --add-module=../nginx-sslkeylog

    echo 'Building NGINX...'
    make -j\$(nproc) && make install

    echo 'Creating required temporary directories...'
    mkdir -p /var/cache/nginx/{client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp}

    echo '✅ NGINX build completed.'
  "

  tag=$(echo $platform | awk -F'/' '{print $NF}')

  docker commit $container_id $image_name
  docker tag $image_name $REGISTRY/$image_name-$tag
  echo "$REGISTRY/$image_name-$tag tagged"
  docker push $REGISTRY/$image_name-$tag
  echo "$REGISTRY/$image_name-$tag pushed"
  MANIFEST_AMEND="$MANIFEST_AMEND --amend $REGISTRY/$image_name-$tag"
  docker stop $container_id
  docker rm $container_id

done

docker manifest create $REGISTRY/$image_name $MANIFEST_AMEND
echo "$REGISTRY/$image_name Manifest created with amend $MANIFEST_AMEND"
docker manifest push $REGISTRY/$image_name
echo "$REGISTRY/$image_name Manifest pushed"

echo "🎉 All builds completed successfully."
