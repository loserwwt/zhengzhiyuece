# 文件下载中心

这是一个可以直接打开的静态下载网站，也可以部署到 GitHub Pages。

## 使用方法

1. 把要分享的文件放进 `downloads` 文件夹。
2. 可选：在 `file-descriptions.json` 里给文件添加说明。
3. 双击 `update-downloads.bat`，或在 PowerShell 里运行 `.\update-downloads.ps1`。
4. 推荐双击 `start-local-site.bat` 打开本地网站；也可以直接打开 `index.html` 查看页面。

## 文件说明格式

`file-descriptions.json` 使用文件名或相对路径作为键：

```json
{
  "资料.pdf": "这是一份资料说明。",
  "tools/工具.zip": "工具压缩包说明。"
}
```

## 部署到 GitHub Pages

把这个文件夹里的内容提交到 GitHub 仓库，然后在仓库的 Settings -> Pages 里选择分支发布即可。

每次新增、删除或替换 `downloads` 里的文件后，重新运行一次 `update-downloads.bat`。

## 关于 txt、pdf 等文件

请让访问者点击页面里的“下载”按钮。这个按钮会尽量强制浏览器下载文件。

如果你是在电脑本地测试，不要直接双击 `index.html` 测试下载；请双击 `start-local-site.bat`，它会用 `http://127.0.0.1:8765/` 打开网站，并且会对 `downloads` 文件夹里的文件加上下载响应头。直接打开 `downloads/文件名.txt` 这样的文件地址时，浏览器仍可能把文本、PDF 或图片当作可预览内容打开。
