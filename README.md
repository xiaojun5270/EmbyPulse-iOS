# EmbyPulse iOS

一个基于 [zeyu8023/emby-pulse](https://github.com/zeyu8023/emby-pulse) 文档和实际后端接口实现的 SwiftUI iOS 客户端。

## 已实现能力

- EmbyPulse 面板登录
  - 使用面板地址 + Emby 管理员账号密码
  - 通过服务端 Session Cookie 保持登录状态
  - 登录页可切换进入独立的求片广场模式
- 仪表盘
  - 总播放次数、活跃用户、累计时长、媒体总量
  - 播放趋势图
  - 实时播放会话
  - 最近入库与最近活动
- 数据分析中心
  - 内容排行
  - 历史记录分页浏览
  - 用户画像与趣味勋章
  - 质量盘点与忽略列表
  - 报表预览 / Bot 推送
  - 全局媒体库搜索
- 追剧日历
  - 调用 `/api/calendar/weekly`
  - 支持查看上周 / 本周 / 下周
  - 支持修改缓存 TTL
  - 已入库剧集可跳转 Emby Web
- 用户管理
  - 查看用户列表、管理员标记、禁用状态、到期时间、最近登录
  - 快速启用 / 禁用账号
  - 新建用户
  - 邀请码生成与查看
  - 用户详情编辑（到期、密码、权限、转码、家长分级）
  - 批量启用 / 禁用 / 续期 / 删除
- 管理中心
  - 求片审批与反馈工单
    - 支持批量处理
  - 任务中心
  - 客户端管理与黑名单阻断
  - Telegram / 企业微信 Bot 配置
  - 系统设置
    - 读取 / 保存 Emby、TMDB、Webhook、MoviePilot 等配置
    - 测试 TMDB 连通性
    - 测试 MoviePilot 连通性
- 求片广场（用户侧）
  - Emby 用户登录
  - 热门推荐与高分榜
  - TMDB 搜索
  - 电影 / 剧集求片提交
  - 我的求片与报错记录
  - 个人画像与勋章

## 工程结构

```text
EmbyPulse/
  App/
  Core/
  Features/
    Analytics/
    Admin/
    Auth/
    Dashboard/
    Calendar/
    Users/
    Settings/
  Shared/
project.yml
```

## 使用方式

### 1. 生成 Xcode 工程

本仓库使用 **XcodeGen** 生成工程文件。

```bash
brew install xcodegen
xcodegen generate
open EmbyPulse.xcodeproj
```

### 2. 运行要求

- Xcode 15+
- iOS 16+
- 已部署 EmbyPulse 面板
- 若要使用追剧日历，请先在面板中配置 `TMDB API Key`

### 3. 登录说明

根据 EmbyPulse 文档，默认直接使用 **Emby 管理员账号** 登录面板。

面板默认部署端口通常为：

```text
http://你的服务器IP:10307
```

## 对接的主要后端接口

- `POST /api/login`
- `POST /api/requests/auth`
- `GET /api/requests/check`
- `POST /api/requests/logout`
- `GET /api/requests/trending`
- `GET /api/requests/search`
- `GET /api/requests/tv/{tmdb_id}`
- `GET /api/requests/check/{media_type}/{tmdb_id}`
- `POST /api/requests/submit`
- `GET /api/requests/my`
- `POST /api/requests/feedback/submit`
- `GET /api/requests/feedback/my`
- `GET /api/stats/dashboard`
- `GET /api/stats/trend`
- `GET /api/stats/top_movies`
- `GET /api/stats/user_details`
- `GET /api/stats/badges`
- `GET /api/stats/poster_data`
- `GET /api/stats/top_users_list`
- `GET /api/stats/monthly_stats`
- `GET /api/stats/live`
- `GET /api/stats/recent`
- `GET /api/stats/latest`
- `GET /api/history/list`
- `GET /api/library/search`
- `GET /api/calendar/weekly`
- `POST /api/calendar/config`
- `GET /api/insight/quality`
- `GET /api/insight/ignores`
- `POST /api/insight/ignore`
- `POST /api/insight/unignore_batch`
- `GET /api/report/preview`
- `POST /api/report/push`
- `GET /api/manage/users`
- `POST /api/manage/user/new`
- `POST /api/manage/user/update`
- `DELETE /api/manage/user/{id}`
- `GET /api/manage/invites`
- `POST /api/manage/invite/gen`
- `GET /api/manage/requests`
- `POST /api/manage/requests/batch`
- `GET /api/manage/feedback`
- `POST /api/manage/feedback/action`
- `GET /api/tasks`
- `POST /api/tasks/{id}/start`
- `POST /api/tasks/{id}/stop`
- `POST /api/tasks/translate`
- `GET /api/clients/data`
- `GET /api/clients/blacklist`
- `POST /api/clients/blacklist`
- `DELETE /api/clients/blacklist/{app_name}`
- `POST /api/clients/execute_block`
- `GET /api/bot/settings`
- `POST /api/bot/settings`
- `POST /api/bot/test`
- `POST /api/bot/test_wecom`
- `GET /api/settings`
- `POST /api/settings`
- `POST /api/settings/test_tmdb`
- `POST /api/settings/test_mp`

## CI

仓库内已更新 GitHub Actions：

- 自动安装 XcodeGen
- 生成 `EmbyPulse.xcodeproj`
- 执行 iOS Release 构建
- 打包 IPA 制品

## 当前导航结构

- 仪表盘
- 求片广场（独立入口）
- 数据分析
  - 内容排行
  - 历史记录
  - 用户画像
  - 质量盘点
  - 映迹工坊
  - 全局搜索
- 追剧日历
- 用户管理
- 管理中心
  - 求片中心
  - 任务中心
  - 客户端管理
  - 机器人助手
  - 系统设置
