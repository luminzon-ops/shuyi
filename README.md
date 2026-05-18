# 数一游园 (Shuyi Playland)

面向小学 1-6 年级的离线数学学习应用，采用 Godot 4.6 引擎开发，以闯关、任务、成长、奖励为核心包装，让数学练习更有趣。

## 功能特性

- **四层内容结构**：年级 → 模块 → 知识点 → 关卡
- **多种练习模式**：专项练习、随机练习、模拟测试、错题重练
- **游戏化系统**：每日/每周任务、等级成长、签到奖励、成就勋章
- **多题型支持**：选择题、判断题、填空题、口算题、连线题、拖拽排序、图形题、应用题、多步题
- **本地存档**：SQLite 持久化 + JSON 备份，支持导入导出
- **数学小游戏**：内置轻量数学小游戏模块
- **护眼提醒**：可配置的使用时长提醒

## 技术栈

| 组件 | 技术 |
|------|------|
| 客户端 | Godot 4.6 (GDScript) |
| 后台管理 | Node.js + Express |
| 数据交换 | JSON |
| 本地存储 | SQLite + JSON/ZIP 备份 |
| 目标平台 | Android (竖屏) |

## 项目结构

```
shuyi/
├── shuyi_playland/          # Godot 客户端项目
│   ├── scenes/              # 场景文件 (首页/练习/成长/签到/结算/小游戏/设置/错题本/成就)
│   ├── scripts/             # GDScript 脚本 (UI/核心/题型)
│   ├── autoload/            # 自动加载单例 (状态/内容/备份/数据库)
│   ├── assets/              # 游戏资源 (音频/背景/角色/UI/特效)
│   ├── data/content/        # JSON 内容数据 (题目/关卡/规则)
│   └── project.godot        # 项目配置
├── shuyi_admin/             # 本地 Web 后台
│   ├── server.js            # Express 服务 (端口 3131)
│   ├── public/              # 管理界面
│   └── storage/             # 内容与运行时数据
└── .gitignore
```

## 快速开始

### 1. 获取游戏资源

为尊重原作者版权，本仓库**不含第三方素材**。首次运行前需要将素材放入 `shuyi_playland/assets/`。

需要的素材包（请自行下载并遵守各素材包的许可协议）：

| 素材包 | 安装到 |
|--------|--------|
| [Pixel UI pack 3](https://ninjikin.itch.io/pixel-ui-pack-3) | `assets/ui/` |
| [Kyrise's 16x16 RPG Icon Pack](https://kyrise.itch.io/kyrises-free-16x16-rpg-icon-pack) | `assets/ui/icons/` |
| [Ninja Adventure - Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) | `assets/characters/`, `assets/effects/`, `assets/Audio/` |
| [Free Pixel Effects Pack](https://codemanu.itch.io/pixel-effects-pack) | `assets/effects/reward/` |
| [FreePixelFood](https://henrysoftware.itch.io/pixel-food) | `assets/mini_games/pickups/food/` |
| [0x72 DungeonTilesetII](https://0x72.itch.io/dungeontileset-ii) | `assets/mini_games/dungeon/`, `assets/Backgrounds/` |
| [FREE MUSIC PACK](https://pixel-boy.itch.io/ninja-adventure-asset-pack) | `assets/Audio/Musics/` |

> 详细映射参见 `shuyi_playland/assets/source_packs_manifest/asset_intake_manifest.md`

### 2. 客户端

1. 使用 [Godot 4.6](https://godotengine.org/) 打开 `shuyi_playland/project.godot`
2. 在编辑器中运行 (F5) 即可启动桌面预览

### 后台管理

```bash
cd shuyi_admin
npm install
node server.js
```

访问 `http://localhost:3131` 进入管理界面。

**API 端点：**
- `GET /api/dashboard` — 数据概览
- `GET /api/content/:file` — 读取内容文件
- `PUT /api/content/:file` — 更新内容文件
- `POST /api/export/client-content` — 导出内容至客户端

### Android 导出

```bash
# 1. 在 Godot 编辑器中导出 APK (Project → Export → Android)
# 2. 签名 APK
pwsh shuyi_playland/scripts/tools/sign_android_debug_apk.ps1
# 3. 安装到设备
adb install shuyi_playland/builds/shuyi-playland-debug-signed.apk
```

> 导出前请确保 `project.godot` 中 `renderer/rendering_method.mobile` 设置为 `gl_compatibility`。

## 版本

当前版本：**v0.9.0-product**

## 许可证

项目代码仅供学习和参考使用。游戏资源（assets）版权归原作者所有。
