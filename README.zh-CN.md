# FretNote

[English](README.md) · **简体中文**

[![构建](https://github.com/lele94218/FretNote/actions/workflows/build.yml/badge.svg)](https://github.com/lele94218/FretNote/actions/workflows/build.yml)
[![版本](https://img.shields.io/github/v/release/lele94218/FretNote)](https://github.com/lele94218/FretNote/releases/latest)
[![MIT](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE)

在 Mac 上熟悉吉他指板、练习识谱，跟着 Guitar Pro 乐谱演奏。原生 macOS 应用，音频仅在本机处理。

**[下载](https://github.com/lele94218/FretNote/releases/latest)** · [反馈问题](https://github.com/lele94218/FretNote/issues)

## 动态预览

![指板跟谱、音级标记、推弦与揉弦动态演示](docs/demo/fretboard-player.gif)

使用原创练习谱和应用指板组件生成。GIF 可在页面直接播放，无声音。[下载带 MIDI 声音的视频](https://github.com/lele94218/FretNote/releases/download/v0.4.0/FretNote-v0.4.0-demo.mp4) · [试用演示乐谱](docs/demo/fretnote-demo.gp)

## 核心功能

- **指板与识谱练习**：通过声卡或麦克风弹出指定音、短旋律，获得音高反馈并保存学习记录。
- **和弦与琶音**：先看指型学习，再练习三和弦和七和弦三音骨架。琶音按顺序判定；和弦多音识别目前为试用功能。
- **Guitar Pro 跟谱**：导入 GP3/4/5、GPX、GP 文件，在 21 品实琴指板上跟随演奏，支持小节循环与最低 25% 的减速不变调播放。
- **多轨播放**：吉他、Bass、鼓独立静音，小节方格导航与同步节拍器。
- **演奏动画**：推弦、回落、揉弦及推弦叠加揉弦。可开启当前把位的完整音阶音级标记，默认显示音名。
- **Mac 使用体验**：中英文、深浅模式、可调字号；文件列表保存在本机，下次打开自动恢复。

<details>
<summary>更多界面预览</summary>

![和弦学习](docs/screenshots/chord-learning-light.jpg)

![五线谱找音](docs/screenshots/sight-reading-light.jpg)

</details>

## 安装

在 [Releases](https://github.com/lele94218/FretNote/releases/latest) 下载 **macOS arm64 ZIP**，解压后将 `FretNote.app` 放入“应用程序”。

- 需要 Apple Silicon（M 系列）Mac、macOS 13 或更新版本。
- 发布包采用临时签名，未经 Apple 公证。如首次打开被拦截，请确认下载来源后按 [Apple 的说明](https://support.apple.com/102445) 操作，或从源码构建。
- 暂无 Intel 发布包，Intel 构建尚未验证。

## 快速开始

**练习找音：**连接吉他，在设置中选择声卡及输入通道，开始监听，再选择练习。建议使用干净音色，并静音未使用的琴弦。

**跟谱播放：**进入「指板跟谱」，导入 Guitar Pro 文件，点击下方音轨方格选择吉他轨，再点击播放。开启「音级标记」可查看当前把位的音阶标签。

音高检测只能验证声音，不能确认实际弦品。音阶名称是自动推测结果。导入曲目的指板显示限标准调弦、无变调夹、最高 21 品的六弦吉他，跟谱播放暂不进行演奏判分。文件与学习记录均保存在本机。

## 开发

需要 macOS、Xcode Command Line Tools，以及 Swift 5.9 或更新版本。

```sh
git clone https://github.com/lele94218/FretNote.git
cd FretNote
swift test
bash scripts/build-app.sh
open ~/Applications/FretNote.app
```

解析器和音色库已随项目提供，只有重建 Guitar Pro 适配器时才需要 Node.js。更多说明：[解析与音频](tools/guitar-pro/README.md)、[和弦检测验证](docs/chord-detection-validation.md)、[演示导出](docs/demo/README.md)。

欢迎提交 Issue 和 PR。反馈音频问题时，请附 macOS 版本、声卡型号、输入设置与复现步骤；提交代码前运行 `swift test`。

## 许可证

项目采用 [MIT](LICENSE)。随附组件保留各自许可证：[alphaTab · MPL-2.0](Sources/FretNoteApp/Resources/alphaTab-LICENSE.txt)、[TinySoundFont · MIT](Sources/FretNoteApp/Resources/TinySoundFont-LICENSE.txt)、[Sonivox · Apache-2.0](Sources/FretNoteApp/Resources/Sonivox-LICENSE.txt)、[Inter · OFL](Sources/FretNoteApp/Resources/Inter-LICENSE.txt)、[Bravura · OFL](Sources/FretNoteApp/Resources/Bravura-LICENSE.txt)。公开发布包使用开源字体，不包含本机提供的商业字体。
