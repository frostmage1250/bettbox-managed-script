# Bettbox 托管脚本（自定义版）

自动跟进 [appshubcc/Bettbox](https://github.com/appshubcc/Bettbox) 的内置托管脚本
[`assets/scripts/managed.js`](https://github.com/appshubcc/Bettbox/blob/main/assets/scripts/managed.js)，
并在每次上游更新后自动套用自定义修改。

## 订阅地址

```
https://raw.githubusercontent.com/frostmage1250/bettbox-managed-script/main/managed.js
```

## 工作方式

GitHub Actions 每 3 小时运行一次 [`scripts/sync.sh`](scripts/sync.sh)，也可以在 Actions 页面手动运行：

1. 抓取上游最新的 `managed.js`，与 `upstream/managed.js`（上次同步的原版）比较，没有变化就结束。
2. 有变化时做三方合并：把"上次的原版 → 自定义版"之间的差异套到最新原版上。
3. 自定义版的 `@version` 跟随最新上游版本号。
4. 通过 `node --check` 语法检查后提交。

## 修改自定义内容

直接编辑仓库里的 `managed.js` 并提交即可，以后的同步会自动保留这些修改。
不要改 `upstream/managed.js`，它是合并基准。

## 合并冲突

如果上游改动了你自定义过的同一处代码，同步会失败并保留旧版本，GitHub 会发邮件通知。
在 Actions 运行记录的摘要里能看到冲突位置。处理方法：

1. 手动把自定义修改应用到最新的上游脚本上，保存为 `managed.js`。
2. 把最新的上游原版保存为 `upstream/managed.js`。
3. 一起提交。

## 许可

上游项目以 GPL-3.0 发布，本仓库的修改版同样遵循 [GPL-3.0](LICENSE)。
