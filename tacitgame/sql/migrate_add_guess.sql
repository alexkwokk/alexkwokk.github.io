-- 一次性 SQL：给 tacit_answers 表加 guess JSONB 列，用来存「我的挑战记录」。
-- 旧库没有这个列，所以「挑战对方」Tab 的猜测记录目前只存在本地。
-- 跑完这条 SQL 后，新存入的 guessing 也会同步到云端，「清空云端我的挑战记录」按钮才有用。

alter table tacit_answers
  add column if not exists guess jsonb default '{}'::jsonb;

-- 兼容老 row：用空对象填默认，避免后续 sync 逻辑读到 null
update tacit_answers
  set guess = '{}'::jsonb
  where guess is null;
