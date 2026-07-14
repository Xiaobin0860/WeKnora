# WeKnora 部署记录

## 环境信息

| 项目 | 详情 |
|---|---|
| 部署时间 | 2026-07-13 |
| 部署方式 | Docker Compose（生产模式） |
| Docker 版本 | 26.1.3 |
| Docker Compose 版本 | v2.26.1 |
| Go 版本 | 未安装（使用预构建镜像） |
| Node.js 版本 | v24.14.0 |

## 前提条件

- Docker 已安装并运行
- Docker Compose 可用（`docker-compose` 或 `docker compose`）
- 网络可访问 Docker Hub（拉取镜像）

## 部署步骤

### 1. 创建环境变量文件

```bash
cp .env.example .env
```

`.env.example` 已包含适用于本地部署的默认值（PostgreSQL 凭证、Redis 密码、存储类型等），可直接使用。

### 2. 拉取 Docker 镜像

```bash
docker-compose pull
```

拉取的镜像及大小：

| 镜像 | 大小 |
|---|---|
| `wechatopenai/weknora-app:latest` | 1.66 GB |
| `wechatopenai/weknora-ui:latest` | 86 MB |
| `wechatopenai/weknora-docreader:latest` | 3.92 GB |
| `paradedb/paradedb:v0.22.2-pg17` | 1.82 GB |
| `redis:7.0-alpine` | 33 MB |

### 3. 端口冲突处理

默认前端端口 `80` 已被占用，修改 `.env`：

```
FRONTEND_PORT=8081
```

### 4. 启动服务

```bash
docker-compose up -d
```

### 5. 验证服务状态

```bash
docker-compose ps
```

预期输出（5 个服务均为 healthy / running）：

| 容器名 | 镜像 | 端口映射 | 状态 |
|---|---|---|---|
| WeKnora-postgres | paradedb/paradedb:v0.22.2-pg17 | 5432（内部） | healthy |
| WeKnora-redis | redis:7.0-alpine | 6379（内部） | running |
| WeKnora-docreader | wechatopenai/weknora-docreader | 50051（内部） | healthy |
| WeKnora-app | wechatopenai/weknora-app | 8080:8080 | healthy |
| WeKnora-frontend | wechatopenai/weknora-ui | 8081:80 | running |

### 6. 验证端点

```bash
# API 健康检查
curl http://localhost:8080/health
# 返回: {"status":"ok"}

# 前端页面
curl -o /dev/null -s -w "%{http_code}" http://localhost:8081
# 返回: 200
```

## 访问地址

| 服务 | 地址 |
|---|---|
| 前端界面 | http://localhost:8081 |
| API 接口 | http://localhost:8080 |
| Swagger 文档 | http://localhost:8080/swagger/index.html |

## 常用管理命令

```bash
# 查看日志
docker-compose logs -f app

# 重启单个服务
docker-compose restart app

# 停止所有服务
docker-compose down

# 重新启动
docker-compose up -d
```

## 核心服务依赖关系

```
frontend → app → postgres (healthy)
               → redis
               → docreader (healthy)
```

`app` 容器会等待 `postgres` 和 `docreader` 通过健康检查后才启动；`frontend` 等待 `app` 就绪。

## 注意事项

1. **端口冲突**：如 80 端口被占用，修改 `.env` 中的 `FRONTEND_PORT` 后执行 `docker-compose up -d` 即可重新创建前端容器。
2. **首次启动**：`app` 容器的 `start_period` 为 60 秒，数据库迁移和初始化可能需要一些时间，请耐心等待健康检查通过。
3. **数据持久化**：PostgreSQL、文件存储等数据保存在 Docker 命名卷中，`docker-compose down` 不会删除卷数据。如需彻底清理，使用 `docker-compose down -v`。
4. **Langfuse 可选栈**：可通过 `docker-compose --profile langfuse up -d` 启用可观测性服务。

---

## 离线部署（无网络环境）

适用于目标机器无法访问 Docker Hub 或其他网络受限的场景。

### 前提条件

| 要求 | 说明 |
|---|---|
| Docker | 目标机器已安装 Docker（≥ 24.0）并正常运行 |
| Docker Compose | 可使用 `docker-compose` 或 `docker compose` |
| 镜像文件 | 已将 5 个 `weknora-*.tar.gz` 文件拷贝到目标机器 |
| 项目文件 | 已将 `docker-compose.yml`、`.env`、`config/config.yaml`、`skills/` 拷贝到目标机器 |
| LLM 模型 | 目标机器需有可用的 LLM 和 Embedding 模型（本地 Ollama 或局域网模型服务） |

### 需要拷贝的文件清单

```
weknora/
├── weknora-app.tar.gz           # 应用镜像 (527 MB)
├── weknora-ui.tar.gz            # 前端镜像 (35 MB)
├── weknora-docreader.tar.gz     # 文档解析镜像 (1.5 GB)
├── weknora-postgres.tar.gz      # 数据库镜像 (476 MB)
├── weknora-redis.tar.gz         # Redis 镜像 (13 MB)
├── docker-compose.yml           # 编排文件
├── .env                         # 环境变量（可从 .env.example 复制）
├── config/
│   └── config.yaml              # 应用配置文件
└── skills/
    └── preloaded/               # Skills 目录（空目录即可）
```

### 第一步：加载 Docker 镜像

将 5 个 `tar.gz` 文件和项目目录拷贝到目标机器后，执行：

```bash
cd /path/to/weknora

# 逐个加载镜像
gunzip -c weknora-redis.tar.gz      | docker load
gunzip -c weknora-postgres.tar.gz   | docker load
gunzip -c weknora-docreader.tar.gz  | docker load
gunzip -c weknora-app.tar.gz        | docker load
gunzip -c weknora-ui.tar.gz         | docker load

# 或一条命令全部加载
for f in weknora-*.tar.gz; do gunzip -c "$f" | docker load; done
```

验证镜像已加载：

```bash
docker images | grep weknora
```

预期看到 5 个镜像。

### 第二步：配置环境变量

```bash
# 首次部署
cp .env.example .env

# 或使用已有的 .env
```

**以下参数必须根据目标机器实际情况修改：**

```ini
# 前端端口（确保不与其他服务冲突）
FRONTEND_PORT=8081

# 应用端口
APP_PORT=8080

# 文档解析端口
DOCREADER_PORT=50051

# 数据库密码（首次部署保持默认即可，生产请修改）
DB_PASSWORD=postgres123!@#

# Redis 密码（首次部署保持默认即可，生产请修改）
REDIS_PASSWORD=redis123!@#

# Ollama 地址（如果使用本地 Ollama）
OLLAMA_BASE_URL=http://host.docker.internal:11434
```

**如果需要使用 /wiki/ base path（反向代理场景），添加：**

```ini
BASE_PATH=/wiki/
```

### 第三步：创建必要目录

```bash
mkdir -p skills/preloaded
```

### 第四步：启动服务

```bash
# 默认根路径 (/)
docker-compose up -d

# 或使用 /wiki/ base path
BASE_PATH=/wiki/ docker-compose up -d
```

首次启动会自动执行数据库迁移，app 容器约 60-90 秒完成初始化。

### 第五步：验证部署

```bash
# 查看服务状态（5 个服务均为 healthy / running）
docker-compose ps

# 验证 API
curl http://localhost:8080/health
# 返回: {"status":"ok"}

# 验证前端
curl -o /dev/null -s -w "%{http_code}" http://localhost:8081
# 返回: 200

# 如果使用 /wiki/ base path
curl -o /dev/null -s -w "%{http_code}" http://localhost:8081/wiki/
# 返回: 200
```

### 第六步：配置外网 Nginx 反向代理（可选）

如果通过外网 nginx 代理访问（例如 `https://example.com/wiki/`），在外网 nginx 配置中添加：

```nginx
# /data/service/conf/nginx/conf.d/wiki.conf
server {
    listen       80;
    server_name  your-domain.com;

    # 必须使用 ^~ 前缀，确保 /wiki/ 下的 JS/CSS 文件也被代理
    location ^~ /wiki/ {
        proxy_pass http://127.0.0.1:8081/wiki/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**关键点**：location 必须使用 `^~` 修饰符，否则 nginx 的正则 location（如 `~.*\.(css|js)$`）会优先匹配，导致静态资源 404。

重载 nginx：

```bash
sudo nginx -s reload
```

### 数据备份与迁移

所有持久化数据存储在 Docker 命名卷中：

| 卷名 | 内容 | 备份命令 |
|---|---|---|
| `weknora_postgres-data` | 所有结构化数据 | `docker run --rm -v weknora_postgres-data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz -C /data .` |
| `weknora_data-files` | 上传的原始文件 | 同上，卷名替换为 `weknora_data-files` |

还原到新机器：

```bash
docker run --rm -v weknora_postgres-data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres-backup.tar.gz -C /data
```

### 常见问题

**Q: 启动后 app 容器一直 unhealthy？**

```bash
# 查看 app 日志
docker-compose logs app --tail=50

# 常见原因：
# 1. postgres 未就绪 → 等待 1-2 分钟
# 2. config.yaml 缺失 → 确保 config/config.yaml 存在
# 3. .env 中数据库密码不匹配 → 检查 DB_PASSWORD
```

**Q: 修改 .env 后需要重建容器吗？**

大部分配置只需要 `docker-compose up -d` 重新创建容器即可，不需要删除镜像。只有 `MAX_FILE_SIZE_MB` 等少数构建期变量才需要重建。

**Q: 如何彻底清理重新部署？**

```bash
docker-compose down -v   # 删除容器和卷（数据会丢失！）
rm -rf .env              # 删除旧配置
# 然后从第二步开始重新部署
```
