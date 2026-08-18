# 默契挑战

两人专用的默契度测试游戏。两人各自在「设置答案」Tab 答一批题，然后切换到「挑战对方」Tab 互相猜对方的答案，看看有多少道能猜中。

## 项目结构

```
tacitgame/
├── index.html      # 入口页面（结构 + 静态骨架 + 同步标签栏/Tab）
├── styles.css      # 全部样式
├── game.js         # 游戏逻辑（题库、Supabase 同步、三个 Tab 渲染）
├── supabase.js     # Supabase JS SDK（UMD）
└── README.md       # 本文件
```

- `index.html` 只负责结构和静态骨架（避免 JS 加载失败时一片空白），并在末尾同步加载 SDK 和游戏脚本。
- `styles.css` 把原来内嵌在 `<style>` 里的样式完整抽出，未做任何修改。
- `game.js` 是原来 `<script>` 里的全部逻辑，**完全原样搬迁**，仅做了模块化拆分。

## 如何打开

- 本地双击 `tacitgame/index.html`（`file://` 协议也能跑，题库是内嵌的，不依赖任何外部资源）。
- 或部署到任意静态站点，浏览器访问 `tacitgame/index.html`。

> 首页入口已更新为 `tacitgame/index.html`，从根目录的 `index.html` 点击「默契挑战」即可进入。

## 游戏流程

1. 选择身份：`ggh`（A 玩家）或 `hsq`（B 玩家），选定后写入 `localStorage`，下次自动进入主区。
2. **设置答案**：每次从全部 500 道题中随机抽 30 道未答过的题（Fisher-Yates 洗牌），可自由翻面修改已答的题。答完最后一题后，「下一题」按钮会变成「完成」，点击「完成」会一次性上传到云端并开下一批题。
3. **挑战对方**：从对方已答的题中随机抽 ≤30 道未猜过的题（不重复），即时判分显示「猜对/不对」并展示对方真实答案。
4. **默契结果**：汇总所有已挑战的题，计算最终默契度（0-100%）并给出评语。

## 云同步

- 数据存储在 Supabase 表 `tacit_answers`（`room_code = 'tacit_default'`，仅一对玩家使用）。
- 上传：`upsert({ room_code, role, answers }, { onConflict: 'room_code,role' })`
- 实时订阅：`postgres_changes` filter `room_code=eq.tacit_default`，对方答案变化时自动刷新本地缓存和 UI。
- **双向同步**：`syncNow()` 会先 fetch 云端，**把「自己这一方」的云端答案合入本地**（local 已有 key 优先保留），再把合并后的我方答案回传云端。这样手机设了 100 题，电脑打开会自动看到同样的 100 题；任何一端的「设置答案」最终都会在两端汇总。
- **猜测同步**：挑战模式下，每答一道题都会自动 `uploadGuess(role, guess)` 把「我的猜测」写入云端（`guess` 列）。换设备时，`syncNow()` 也会做一次双向合并，把云端的猜测拉回本地。
- 同步触发时机：选择身份后、答题提交后、答题判分时、切到「挑战对方 / 结果」Tab、手动点 `↻ 刷新`、收到对方变化的 realtime 推送。
- 状态条：左下角小灯显示「连接中…/已就绪 ✓/上传失败」等状态；右上角的 `🔍 诊断` 按钮可一键打印 supabase 客户端与远端状态。

### 表结构

```sql
create table tacit_answers (
  room_code text not null,
  role      text not null,
  answers   jsonb default '{}'::jsonb,
  guess     jsonb default '{}'::jsonb,
  primary key (room_code, role)
);
```

> 老库若没有 `guess` 列，先在 Supabase SQL Editor 执行一次：
>
> ```sql
> alter table tacit_answers
>   add column if not exists guess jsonb default '{}'::jsonb;
> ```
>
> 跑完这句之后，「挑战对方」Tab 的猜测记录才会被同步到云端。

## 本地存储 key

| Key | 说明 |
| --- | --- |
| `tacit_role` | 当前选定的角色（`a` / `b`） |
| `tacit_<role>_answers` | 我已经设置的真实答案（`{ qid: 'A'\|'B'\|'C'\|'D' }`） |
| `tacit_<role>_guess` | 我的猜测（结构同上） |
| `tacit_partner` | 缓存的对方答案（同步成功后写入） |
| `tacit_setup_session` | 「设置答案」当前 batch 的题号列表与指针 |
| `tacit_challenge_session` | 「挑战对方」当前 batch 的题号列表与指针 |

> 云端列 `tacit_answers.guess` 与本地 `tacit_<role>_guess` 一一对应；切设备时通过 `syncNow()` 自动合并。

## 维护说明

- 修改题库：编辑 `game.js` 中的 `EMBEDDED_QUESTIONS` 常量（一行一道，`题号. 题目\|选项A\|选项B\|选项C\|选项D`）。
- 调每轮题数：修改 `QUESTIONS_PER_SETUP` 和 `QUESTIONS_PER_CHALLENGE`。
- 改 Supabase 配置：修改 `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `ROOM_CODE`。
- 改样式：编辑 `styles.css`。
