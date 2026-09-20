# 构建后改写 manifest 的 use_dynamic_url

`@crxjs/vite-plugin` 生成的 `manifest.json` 会把 `web_accessible_resources[].use_dynamic_url` 置为 `true`，在较新版 Chrome 下触发 CSP 错误，导致开发模式下扩展无法工作；该依赖长期未更新，上游未修复。对策是构建后由仓库根目录的 `fix.cjs` 把它改写为 `false`（build 脚本为 `tsc && vite build && node fix.cjs`）。代价是开发模式仍需手动改 `dist/manifest.json` 并重载扩展。
