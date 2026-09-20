# Gloss

Gloss 是一个 B 站（bilibili）视频字幕列表浏览器扩展，旨在提供更高效和可控的视频信息获取方式。

它会在视频页面显示完整的字幕列表，让你能够快速浏览字幕内容，并通过点击跳转到视频中的对应位置。同时，你也可以方便地下载字幕文件。

除此之外，Gloss 还提供字幕总结与翻译功能，帮助快速掌握视频要点，并支持面向知识学习类视频的深度理解与整理。

## 功能特点

- 🎬 显示视频的字幕列表
- 🔗 点击字幕跳转视频对应位置
- 📥 多种格式复制与下载字幕
- 📝 多种方式总结字幕
- 🌍 翻译字幕
- 🌑 深色主题

## 下载扩展

Gloss 暂未上架应用商店。目前可通过自行构建的方式安装：

1. 本地构建：

   ```bash
   pnpm install
   pnpm run dev     # 开发调试
   # 或
   pnpm run build   # 打生产包
   ```

2. 打开浏览器的扩展管理页面，开启「开发者模式」。
3. 点击「加载已解压的扩展程序」，选择构建产物 `dist` 目录。

## 使用说明

安装扩展后，在哔哩哔哩网站观看视频时，视频右侧会显示字幕列表面板。

### 使用本地Ollama模型
如果你使用本地Ollama模型，需要配置环境变量：`OLLAMA_ORIGINS=chrome-extension://*,moz-extension://*,safari-web-extension://*`，否则访问会出现403错误。

然后在插件配置里，apiKey随便填一个，服务器地址填`http://localhost:11434`，模型选自定义，然后填入自定义模型名如`llama2`。

但是测试发现llama2 7b模型比较弱，无法返回需要的json格式，因此总结很可能会无法解析响应而报错(但提问功能不需要解析响应格式，因此没问题)。

## 开发指南
node版本：18.15.0
包管理器：pnpm

- 本地调试：`pnpm run dev`，然后浏览器扩展管理页面，开启开发者模式，再加载已解压的扩展程序，选择`dist`目录。
- 打生产包：`pnpm run build`，然后浏览器扩展管理页面，开启开发者模式，再加载已解压的扩展程序，选择`dist`目录。

注：`./push.sh` 是本地发布辅助脚本（递增版本号、构建、打包、提交并推送），可按需修改或直接忽略。

注意事项：`push.sh` 中的 `sed -i '' "..." package.json` 使用的是 macOS 的 BSD `sed` 语法。在 Windows（Git Bash / MSYS2）下需要改为 `sed -i "..." package.json`，否则会报错或产生非预期的文件。

提示：最新版浏览器安全方面有更新，开发调试可能有问题，会报csp错误！
暂时的解决办法是`pnpm run dev`运行起来后，手动将`dist/manifest.json`文件里的web_accessible_resources里的use_dynamic_url都修改为false，然后浏览器扩展管理页面点击重载一下，就能正常（是@crxjs/vite-plugin依赖的问题，这个依赖很长时间没更新了，这个bug也没修复，暂时没发现更好的解决办法）。
构建后正常（关键是fix.cjs里将use_dynamic_url设置为false的这个操作）。

## 许可证

该项目采用 **MIT 许可证**，详情请参阅许可证文件。

本项目基于 IndieKKY 的 bilibili-subtitle（MIT 许可）衍生，原始版权声明保留在 `LICENSE` 文件中。
