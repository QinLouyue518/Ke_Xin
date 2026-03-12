# 刻心 (Carved in Heart)
**雕刻时光 · 铭记本心**

「刻心」不仅是一款日记 App，它是一个基于 AI 的数字化人格镜像。它尝试将流逝的碎片化情感，转化为可感知的成长纹理。

[![Platform](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![AI](https://img.shields.io/badge/AI-DeepSeek--R1-blue?logo=openai)](https://www.deepseek.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

##  核心特性
###  记忆星图 (Memory Galaxy)
告别枯燥的列表。你的每一篇日记都是一颗恒星，根据情绪引力自动聚集成星云。通过「岁月重塑」功能，逐个点亮记忆，在浩瀚的精神宇宙中漫游。

###  素心鉴 (5D Persona)
AI 通过深度阅读你的过往，构建动态的五维人格画像：
- 人格特质：挖掘你的性格底色。
- 核心价值观：看清你内心真正的坚持。
- 思维模式：识破那些你自己都未曾察觉的潜意识倾向。
- 近期状态：总结近期的能量起伏。
- 沟通偏好：让 AI 学会以你最舒适的方式与你对话。

###  清言客 (Global AI Companion)
一个拥有长期记忆的 AI 伴侣。它知道你是谁，知道你的人生阶段（从高一到大学），并支持 DeepSeek-R1 推理模式。你可以实时查看 AI 的「思考过程」，看它如何剥茧抽丝般理解你的内心。

###  浮生册 (Life Chapters)
将琐碎的日记串联成连贯的篇章。AI 会结合你的个人背景，将碎片化的记录重构成文学性的回忆录，为你的人生书写编年史。

###  时光切片 (Energy Stats)
可视化你的情绪心电图。通过能量波动曲线，客观审视生活的起伏，捕捉那些高光与低谷背后的循环规律。

##  技术架构
- **Frontend**: Flutter (Material 3 Design / Animate / Hero)
- **Intelligence**: DeepSeek V3 / R1 (via REST API)
- **Context Logic**:
  - RAG (Retrieval-Augmented Generation)：基于日记碎片与个人画像的上下文注入。
  - CoT (Chain of Thought)：支持推理模型思考过程的结构化展示。
- **Storage**: 本地 SharedPreferences + 本地文件存储（隐私优先，数据不出本地）。
- **Export**: 支持全量导出为 Markdown 格式，将数据主权归还用户。

##  快速开始
### 1. 安装
在 Releases 页面下载最新的 APK 安装包（Android）或 ZIP 压缩包（Windows）。

### 2. 配置 AI 大脑
为了保护开发者余额并实现个性化自由，「刻心」需要用户配置自己的 API Key：
1. 前往 [DeepSeek 官方](https://www.deepseek.com) 或 [硅基流动](https://platform.siliconflow.cn) 申请 API Key。
2. 在 App「设置」->「AI 模型配置」中填入 Key 与对应的 Endpoint。
3. 推荐使用 `deepseek-reasoner (R1)` 以获得最佳的思维链展示效果。

##  开发者自述
这个项目的灵感诞生于 2025 年 2 月 11 日，我高三下学期最艰难的一段时光。当时我在草稿本上写下：“这或许是我所能做的，最有价值的一件事。”

现在，作为一名华中科技大学计算机系的大一学生，我利用 AI 的力量将这个乌托邦投射进了现实。我希望「刻心」能成为一面镜子，帮每一个在现代丛林里迷失的人，找回那个最真实、最深沉的自我。

##  隐私声明
「刻心」极其重视隐私。除你选择的 AI 服务商外，任何数据均不会上传至任何服务器。你的日记、画像和 API Key 仅保存在你的设备本地。

##  贡献与反馈
- 欢迎提交 Issue 或 Pull Request。
- 如果你也对「数字化第二大脑」感兴趣，欢迎联系我。
- 如果这个项目对你有启发，请给它一个 ⭐️ Star，这对我这个新人开发者意义重大！

---
Created with ❤️ by qinlouyue518