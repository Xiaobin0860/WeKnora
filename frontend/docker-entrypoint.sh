#!/bin/sh

# 处理 BASE_PATH: 默认 /，可设为 /wiki/ 等
BASE_PATH=${BASE_PATH:-/}
case "$BASE_PATH" in
  /)   FALLBACK_INDEX="/index.html" ;;
  */)  FALLBACK_INDEX="${BASE_PATH}index.html" ;;
  *)   FALLBACK_INDEX="${BASE_PATH}/index.html" ;;
esac
# 确保 ${BASE_PATH} 末尾有 / (除了 root / 的情况)
case "$BASE_PATH" in
  */) ;;
  *)   [ "$BASE_PATH" != "/" ] && BASE_PATH="${BASE_PATH}/" ;;
esac

# 生成运行时配置文件，注入环境变量到前端
cat > /usr/share/nginx/html/config.js << EOF
window.__RUNTIME_CONFIG__ = {
  MAX_FILE_SIZE_MB: ${MAX_FILE_SIZE_MB:-50},
  BASE_PATH: "${BASE_PATH}"
};
EOF

# 处理 nginx 配置
export MAX_FILE_SIZE=${MAX_FILE_SIZE_MB}M
export APP_HOST=${APP_HOST:-app}
export APP_PORT=${APP_PORT:-8080}
export APP_SCHEME=${APP_SCHEME:-http}
envsubst '${MAX_FILE_SIZE} ${APP_HOST} ${APP_PORT} ${APP_SCHEME}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

# 替换 nginx 配置中的 base path 占位符
sed -i "s|__BASE_PATH__|${BASE_PATH}|g" /etc/nginx/conf.d/default.conf
sed -i "s|__FALLBACK_INDEX__|${FALLBACK_INDEX}|g" /etc/nginx/conf.d/default.conf

# 启动 nginx
exec nginx -g 'daemon off;'
