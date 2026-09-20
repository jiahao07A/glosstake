#!/usr/bin/env bash
#
# 发布辅助脚本：递增版本号 → 构建 → 打包 dist.zip → 提交 → 打 tag → 推送
#
# 用法：
#   ./push.sh [--dry-run] [MAJOR|MINOR|PATCH]
#
#   --dry-run  完整走完流程，但不修改 package.json，也不产生 commit / tag / push
#   MAJOR|MINOR|PATCH  指定递增哪一段；省略则交互式选择
#
set -euo pipefail

DRY_RUN=false
PART=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    MAJOR|MINOR|PATCH) PART="$arg" ;;
    *) echo "未知参数: $arg" >&2; exit 2 ;;
  esac
done

if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] 不修改 package.json，不产生 commit / tag / push"
fi

# 读取当前版本（用 node 解析 JSON，避免 grep/cut 的脆弱匹配）
current_version=$(node -p "require('./package.json').version")
echo "Current version: $current_version"

# 选择要递增的版本段
if [ -z "$PART" ]; then
  if [ ! -t 0 ]; then
    echo "错误：未指定版本段，且 stdin 不是终端，无法交互选择。" >&2
    echo "请显式传入：./push.sh [--dry-run] MAJOR|MINOR|PATCH" >&2
    exit 2
  fi
  echo "Which part of the version do you want to upgrade?"
  select part in "MAJOR" "MINOR" "PATCH"; do
    case "$part" in
      MAJOR|MINOR|PATCH) PART="$part"; break ;;
      *) echo "Invalid option" ;;
    esac
  done
fi

# 计算新版本号
new_version=$(node -e '
const [cur, part] = process.argv.slice(1)
const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(cur)
if (!m) { console.error("无法解析当前版本号: " + cur); process.exit(1) }
let [major, minor, patch] = m.slice(1).map(Number)
if (part === "MAJOR") { major += 1; minor = 0; patch = 0 }
else if (part === "MINOR") { minor += 1; patch = 0 }
else { patch += 1 }
console.log(major + "." + minor + "." + patch)
' "$current_version" "$PART")

# 就地改写 package.json 的 version 字段（不依赖 sed，规避 BSD/GNU 方言差异）
bump_version() {
  node -e '
const fs = require("fs")
const [file, from, to] = process.argv.slice(1)
const raw = fs.readFileSync(file, "utf8")
const needle = "\"version\": \"" + from + "\""
const next = raw.replace(needle, "\"version\": \"" + to + "\"")
if (next === raw) {
  console.error("package.json 中未找到 " + needle + "，版本号未更新")
  process.exit(1)
}
JSON.parse(next) // 写回前先校验 JSON 合法
fs.writeFileSync(file, next)
' "$1" "$current_version" "$new_version"
}

# 版本号必须先于构建写入：manifest.config.ts 从 package.json 读 version 注入 manifest.json。
# 因此一旦后续步骤失败，需要回滚 package.json，避免留下"版本号已改但未发布"的半成品。
#
# 回滚谓词不能只看"是否成功"——发布流程的 git 副作用是分阶段落地的，需分三种情况处理：
#   1) commit 之前失败：无任何 git 副作用，直接还原 package.json，重试安全。
#   2) commit 之后、push 之前失败：commit 已落地。若只还原 package.json，会造成
#      HEAD 与工作区版本号矛盾，且重试时 `git commit` 因无改动而失败
#      （nothing added to commit → exit 1），无法续跑。故撤销该 commit 后再还原工作区。
#   3) push 之后失败（如 tag 冲突）：commit 已推送，不能本地撤销（会与远端分叉）。
#      此时保持 HEAD 与工作区一致，并打印手工续跑指引。
WORK_BACKUP=""
DRY_TMP=""
COMMITTED=false
PUSHED=false
on_exit() {
  code=$?
  if [ "$code" -ne 0 ] && [ -n "$WORK_BACKUP" ] && [ -f "$WORK_BACKUP" ]; then
    if [ "$COMMITTED" != true ]; then
      # 情况 1：无 git 副作用，直接还原工作区
      cp "$WORK_BACKUP" package.json
      echo "流程中止（退出码 $code），package.json 已回滚为 $current_version" >&2
    elif [ "$PUSHED" != true ]; then
      # 情况 2：commit 已产生但未推送。撤销提交（--mixed 同时复位索引，避免留下已暂存的改动），
      # 再还原工作区，使 HEAD / 索引 / 工作区三者回到发布前的状态，重试可续跑。
      if git reset --mixed HEAD~1 >/dev/null 2>&1; then
        cp "$WORK_BACKUP" package.json
        echo "流程中止（退出码 $code）。发布提交已产生但未推送，已用 git reset --mixed HEAD~1 撤销" >&2
        echo "package.json 已回滚为 $current_version，可直接重试" >&2
      else
        echo "流程中止（退出码 $code）。自动撤销发布提交失败，请手工恢复：" >&2
        echo "  git reset --mixed HEAD~1   # 撤销发布提交" >&2
        echo "  git checkout -- package.json   # 或从备份还原" >&2
      fi
    else
      # 情况 3：commit 已推送，不回滚，避免 HEAD 与远端分叉。
      # 工作区 package.json 与 HEAD 本就一致（提交后未再改动），故无需处理。
      echo "流程中止（退出码 $code）。发布提交 $new_version 已推送，工作区与 HEAD 一致，未做回滚。" >&2
      echo "请手工完成剩余步骤（若已执行则跳过）：" >&2
      echo "  git tag $new_version && git push origin $new_version" >&2
      echo "若 tag 已存在导致失败：git tag -d $new_version 后重试，或直接 git push origin $new_version" >&2
    fi
  fi
  if [ -n "$WORK_BACKUP" ]; then rm -f "$WORK_BACKUP"; fi
  if [ -n "$DRY_TMP" ]; then rm -f "$DRY_TMP"; fi
  exit $code
}
trap on_exit EXIT

if [ "$DRY_RUN" = true ]; then
  # 在临时副本上真实演练版本改写，确认逻辑可用，但不触碰工作区
  DRY_TMP=$(mktemp)
  cp package.json "$DRY_TMP"
  bump_version "$DRY_TMP"
  echo "[dry-run] 版本号改写演练通过：$current_version -> $new_version"
else
  WORK_BACKUP=$(mktemp)
  cp package.json "$WORK_BACKUP"
  bump_version package.json
  echo "Version updated to: $new_version"
fi

# 构建（set -e 保证失败立即中止，不会带着坏构建继续提交/打 tag）
echo "==> 构建"
pnpm run build
echo "==> 构建成功"

# 打包 dist -> dist.zip（不依赖系统 zip 命令）
echo "==> 打包 dist.zip"
rm -f dist.zip
node -e '
const fs = require("fs"), path = require("path"), zlib = require("zlib")

const CRC_TABLE = (() => {
  const table = new Int32Array(256)
  for (let n = 0; n < 256; n++) {
    let c = n
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    table[n] = c
  }
  return table
})()
const crc32 = (buf) => {
  let c = -1
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8)
  return (c ^ -1) >>> 0
}

const walk = (dir, prefix) => {
  const out = []
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name)
    const rel = prefix ? prefix + "/" + name : name
    if (fs.statSync(full).isDirectory()) out.push(...walk(full, rel))
    else out.push({ full, rel })
  }
  return out
}

const root = process.argv[1]
if (!fs.existsSync(root)) { console.error("找不到目录: " + root); process.exit(1) }
const files = walk(root, "")
if (files.length === 0) { console.error("目录为空: " + root); process.exit(1) }

const local = [], central = []
let offset = 0
for (const f of files) {
  const raw = fs.readFileSync(f.full)
  const data = zlib.deflateRawSync(raw)
  const name = Buffer.from(f.rel, "utf8")
  const crc = crc32(raw)
  const m = fs.statSync(f.full).mtime
  const time = ((m.getHours() << 11) | (m.getMinutes() << 5) | Math.floor(m.getSeconds() / 2)) & 0xffff
  const date = (((m.getFullYear() - 1980) << 9) | ((m.getMonth() + 1) << 5) | m.getDate()) & 0xffff

  const lh = Buffer.alloc(30)
  lh.writeUInt32LE(0x04034b50, 0)
  lh.writeUInt16LE(20, 4)
  lh.writeUInt16LE(0x0800, 6) // UTF-8 文件名
  lh.writeUInt16LE(8, 8)      // deflate
  lh.writeUInt16LE(time, 10)
  lh.writeUInt16LE(date, 12)
  lh.writeUInt32LE(crc, 14)
  lh.writeUInt32LE(data.length, 18)
  lh.writeUInt32LE(raw.length, 22)
  lh.writeUInt16LE(name.length, 26)
  lh.writeUInt16LE(0, 28)
  local.push(lh, name, data)

  const ch = Buffer.alloc(46)
  ch.writeUInt32LE(0x02014b50, 0)
  ch.writeUInt16LE(20, 4)
  ch.writeUInt16LE(20, 6)
  ch.writeUInt16LE(0x0800, 8)
  ch.writeUInt16LE(8, 10)
  ch.writeUInt16LE(time, 12)
  ch.writeUInt16LE(date, 14)
  ch.writeUInt32LE(crc, 16)
  ch.writeUInt32LE(data.length, 20)
  ch.writeUInt32LE(raw.length, 24)
  ch.writeUInt16LE(name.length, 28)
  ch.writeUInt16LE(0, 30)
  ch.writeUInt16LE(0, 32)
  ch.writeUInt16LE(0, 34)
  ch.writeUInt16LE(0, 36)
  ch.writeUInt32LE(0, 38)
  ch.writeUInt32LE(offset, 42)
  central.push(ch, name)

  offset += lh.length + name.length + data.length
}

const cd = Buffer.concat(central)
const eocd = Buffer.alloc(22)
eocd.writeUInt32LE(0x06054b50, 0)
eocd.writeUInt16LE(0, 4)
eocd.writeUInt16LE(0, 6)
eocd.writeUInt16LE(files.length, 8)
eocd.writeUInt16LE(files.length, 10)
eocd.writeUInt32LE(cd.length, 12)
eocd.writeUInt32LE(offset, 16)
eocd.writeUInt16LE(0, 20)

fs.writeFileSync("dist.zip", Buffer.concat([...local, cd, eocd]))
console.log("已写入 dist.zip，共 " + files.length + " 个文件")
' dist

# git：仅显式路径，避免把意外文件卷入发布提交
if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] 跳过 git add / commit / push / tag"
  echo "[dry-run] 完成，工作区未被修改"
  exit 0
fi

git add package.json
git commit -m "chore: release $new_version"
COMMITTED=true
git push
PUSHED=true

# tag
git tag "$new_version"
git push origin "$new_version"

echo "发布完成: $new_version"
