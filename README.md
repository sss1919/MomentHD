# 高清朋友圈(独立精简版)

参照越狱插件 `wchook`(悬浮按钮分屏)逆向得出的"高清朋友圈"功能点,**只保留这一项**独立重写的 Theos 插件。

## 功能

朋友圈发布图片/视频时不被微信压缩,保留原图原画:

- hook `adjustSizeToStandardForMoments` — 跳过图片"标准化尺寸"压缩
- hook `shouldCompressLongImage` — 长图不压缩
- hook `setSkipVideoCompress:` — 视频跳过压缩
- hook `isVideoShouldExportWithoutCompressByAsset:scene:` — 视频导出不压缩

## 编译

推送代码后 GitHub Actions 自动在云端 macOS 编译,约 3-5 分钟。

编译完成后:仓库页面 → Actions → 点最近的运行 → Artifacts 下载 `hd-moments-deb`。

## 安装

把 deb 传到设备,用 Sileo / Zebra 安装,注销后重启微信即生效。

## 开关

默认开启。关闭: `defaults write com.tencent.xin com.ylr.hdmoments.enabled -bool NO`
