# acr-mirror

把 Terminal-Bench 2.1 的 89 个题目镜像从 Docker Hub 复制到阿里云容器镜像服务（ACR），再从 ACR 拉到本机给 Truss 用。

- `images.txt`：89 个镜像地址，取自 Terminal-Bench 2.1 各题 `task.toml` 的 `docker_image`（2026-10-23）。
- 仓库根目录的 `.github/workflows/mirror-to-acr.yml`（GitHub 只认根目录下的工作流）：GitHub Actions 里用 skopeo 在两个仓库之间直接复制，保留摘要（digest），所以 ACR 里的就是 Docker Hub 上那一份。已在 ACR 里的跳过，重跑只补缺的。
- `pull-from-acr.sh`：在 Mac 上从 ACR 拉取，并改回 `task.toml` 里的原名 `alexgshaw/<题名>:<标签>`。Harbor 起预构建镜像用 `docker compose up`、不带 `--pull`，本地有就直接用。

## 步骤

1. **ACR 控制台**（个人版实例）
   - 命名空间：建一个（个人版最多 3 个），打开"自动创建仓库"。否则 89 个仓库要手工建，个人版也没有 OpenAPI。"默认仓库类型"选私有或公开都可以；个人版公开仓库限额 300，私有仓库限额计费说明里没写，以控制台为准。
   - 访问凭证：设"固定密码"；记下页面上 `docker login` 那行里的用户名和仓库地址（如 `registry.cn-hangzhou.aliyuncs.com`）。
   - 说明：控制台里"代码源"绑定 GitHub 是给 ACR 自己的构建服务用的，这个工作流用不到。工作流靠下面第 3 步的凭证登录 ACR。
2. **GitHub**：本仓库就是。注意它是公开仓库：Actions 的运行日志和产物 `report.tsv` 别人也能看到，里面有 ACR 地址和命名空间（看不到密码）。ACR 那边的仓库建议设为私有。
3. **仓库设置** → Settings → Secrets and variables → Actions：
   - Variables：`ACR_REGISTRY`（仓库地址）、`ACR_NAMESPACE`（命名空间）。
   - Secrets：`ACR_USERNAME`、`ACR_PASSWORD`（固定密码）。
   - 可选：Variable `DOCKERHUB_USERNAME` 与 Secret `DOCKERHUB_TOKEN`（Docker Hub 的访问令牌）。匿名拉取有频率限制，89 个最好登录。
4. **运行**：Actions → `mirror-tb21-to-acr` → Run workflow。可以先在 `only` 里填 `fix-git` 试一个，再留空跑全部。
   - 单个任务最多 6 小时，到时会停；直接再点一次，只补缺的。
   - 跑完在运行页下载 `mirror-report`（`report.tsv`：源地址、ACR 地址、摘要、结果）。
5. **Mac**：
   ```bash
   docker login --username=<ACR 用户名> registry.cn-hangzhou.aliyuncs.com
   cd acr-mirror
   # 先拉一个试试；REPORT 可省，给了就逐个核对摘要
   REPORT=~/Downloads/report.tsv ACR_REGISTRY=registry.cn-hangzhou.aliyuncs.com ACR_NAMESPACE=<命名空间> ./pull-from-acr.sh images.txt regex-log
   ```
   - 拉全部之前先把 colima 的数据盘扩大：89 个落盘约 50 GB（共享层去重后压缩 16.7 GB，落盘约 3 倍），虚拟机现在只剩 35 GB。改 `~/.colima/default/colima.yaml` 的 `disk: 60` 为 `150`，`colima stop && colima start`（只能扩不能缩）。
   - P2 只要约 10 个开发题（约 6 GB 落盘），现有空间够；那时用第二个参数按题名逐个拉。

## 核对

- 拉完 `docker images | grep alexgshaw` 应能看到对应的原名。
- 给了 `REPORT` 时，脚本会对每个镜像核对：本地拉到的摘要必须等于工作流记录的摘要，否则停下。
