# 数一游园 本地 Web 后台

## 启动

```powershell
npm install
npm start
```

启动后访问：

- http://localhost:3131

## 当前能力

- 题库 JSON 内容编辑
- 年级 / 模块 / 知识点 / 关卡 / 规则文件管理
- 数据总览统计
- 高频知识点覆盖统计
- 导出内容到 Godot 客户端 `shuyi_playland/data/content/`

## 与客户端协作

1. 在本地后台修改 JSON
2. 点击“导出到客户端”
3. 客户端重启或调用内容重载逻辑后读取最新内容

## 目录

- `public/` 后台前端页面
- `storage/content/` 后台维护的内容包
- `storage/runtime/analytics.json` 统计分析结果
- `server.js` 本地 API 服务
