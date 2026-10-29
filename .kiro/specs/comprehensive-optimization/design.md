# 设计文档

## 信息架构
主导航为“今日 / 用药计划 / 添加处方”。今日展示下一次提醒、今日记录和复查；计划页包含待确认草稿与已保存计划。统一浅蓝背景、白色卡片、深色正文、蓝色主操作，保持小狗陪伴元素。

## 数据与通知
Plan 增加 remindersPaused，缺省 false；Patient 增加 doseCompletions 时间映射，缺省空。ReminderEvent 的通知 key 保持原格式，新增基于原始时间的 occurrenceKey 作为记录身份。PatientStore 提供带回滚的持久化操作。完成记录只过滤后续系统及前台提醒，今日列表仍显示记录。

通知服务暴露权限与排期数量；登录与用户主动检查可以申请权限，生命周期刷新仅查询并重排。每次重排同步设备时区。沿用最近 60 条通知上限和同原始时间错开 10 分钟的既有规则。

## 文件职责
- lib/models.dart、storage.dart、notifications.dart：兼容存储、记录与提醒可靠性。
- lib/design_system.dart、dog_avatar.dart：统一视觉与共享组件。
- lib/forms.dart：登录与用药录入、键盘和无障碍交互。
- lib/main.dart：今日、计划管理、照片草稿、提醒页及状态联动。
- test/：存储回滚、稳定剂次身份、时区更新、主流程和大字号回归验证。
- tool/generate_app_icons.dart：复用 DogPainter 生成平台所需的不透明 RGB 图标，图形资源不依赖下载。

## 约束
保留现有 iOS 工程改动；不新增联网业务依赖、不改变医嘱、不删除历史记录、不自动推送或发布 GitHub 变更。用户已选择并授权综合优化方向，具体实现按以上边界推进。
