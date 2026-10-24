# VidHub iOS（个人使用版）

原生 SwiftUI iPhone App，最低 iOS 16，零第三方依赖。
数据来自你自己添加的**采集接口**（苹果CMS V10 / TVBox 配置），App 内不内置任何影视资源。

## 1.0.0 已实现

- 首页：源切换、头图推荐、最近更新、高分推荐、各分类横滑轨、继续观看、下拉刷新
- 分类：分类胶囊 + 三列海报墙 + 分页无限加载
- 搜索：在全部已启用接口里并发搜索，同名结果合并并标注来源数
- 详情：海报、评分、年份/地区、导演/主演、可展开简介、线路切换、剧集网格
- 播放：AVPlayer 原生 HLS/mp4 直连；手势调进度、亮度、音量；倍速；线路/选集切换；播完自动下一集；画中画；后台音频与锁屏信息；进度记忆
- 我的：接口增删启停、TVBox 配置一键导入、收藏、观看历史、显示与播放设置

## 未实现（明确不是「一模一样」）

- SMB / WebDAV / DLNA / Emby / Jellyfin / 网盘直连片源：只做采集接口
- 杜比视界、杜比全景声、DTS 直通：依赖系统 AVPlayer 能力，不做转码
- ASS/SSA 特效字幕在线渲染：AVPlayer 不支持，需要自研字幕渲染器
- 离线缓存、iCloud 跨设备同步、Trakt、Apple TV 版、DLNA 投屏

## 构建

Windows 本地没有 Xcode，走 GitHub macOS 云端编译：

```
node tools/cloud-build.mjs start     # 新建仓库、上传源码、触发构建
node tools/cloud-build.mjs status    # 查构建进度
node tools/cloud-build.mjs download  # 下载未签名 IPA
```

或手动：仓库里 `.github/workflows/build-ios.yml` → Actions → Run workflow → 下载 Artifact。

## 安装

未签名 IPA 不能直接装。用 iLoader / Sideloadly 等工具，以你自己的 Apple ID 签名后安装（免费签名 7 天需续签）。Apple ID 密码与验证码由你在工具里输入，不进工程。
