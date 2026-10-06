// Spike: доступ к личным сообщениям VK через веб-клиент (Playwright, persistent profile).
// Не продакшен. Цель — ответить: держится ли сессия, читаются ли диалоги, работает ли send, не морозят ли.
//
//   node spike.mjs login            — открыть vk.com, скриншотить экран входа (QR) пока не залогинимся
//   node spike.mjs probe            — непрочитанные диалоги + по 3 последних сообщения
//   node spike.mjs send <peer> <text> — отправить сообщение (peer = свой id → «Избранное»)
import { chromium } from 'playwright';
import { mkdirSync, rmSync, existsSync, readFileSync } from 'node:fs';

// Профиль = живая сессия VK, по сути пароль. Вне репозитория.
const PROFILE = process.env.VK_PROFILE_DIR ?? `${process.env.HOME}/.local/share/vk-web-spike/profile`;
const SHOTS = process.env.VK_SHOTS_DIR ?? `/srv/screenshots/${process.env.CLAUDE_CODE_SESSION_ID ?? 'vk-spike'}`;
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36';

const log = (...a) => console.error(new Date().toISOString(), ...a);

async function open() {
  mkdirSync(PROFILE, { recursive: true });
  const ctx = await chromium.launchPersistentContext(PROFILE, {
    headless: true, userAgent: UA, locale: 'ru-RU', viewport: { width: 1280, height: 900 },
  });
  const page = ctx.pages()[0] ?? await ctx.newPage();
  // Фолбэк, если window.vkApi нет: ловим access_token из запросов самого веб-клиента к api.vk.com
  page.capturedToken = null;
  page.on('request', (r) => {
    if (!r.url().includes('api.vk.com/method/')) return;
    const m = (r.postData() ?? r.url()).match(/access_token=([^&]+)/);
    if (m) page.capturedToken = decodeURIComponent(m[1]);
  });
  return { ctx, page };
}

const myId = (page) => page.evaluate(() => window.vk?.id ?? 0);

async function login() {
  const { ctx, page } = await open();
  mkdirSync(SHOTS, { recursive: true });
  log('VK: goto vk.com');
  await page.goto('https://vk.com/', { waitUntil: 'domcontentloaded' });
  for (let i = 0; i < 120; i++) {          // ~10 минут
    if (await myId(page).catch(() => 0)) break;
    // Код подтверждения нового устройства: кладём в <SHOTS>/code.txt — печатаем в сфокусированное поле
    const codeFile = `${SHOTS}/code.txt`;
    if (existsSync(codeFile)) {
      const code = readFileSync(codeFile, 'utf8').replace(/\D/g, '');
      rmSync(codeFile);
      log(`typing confirmation code (${code.length} digits)`);
      await page.keyboard.type(code, { delay: 150 });
    }
    await page.screenshot({ path: `${SHOTS}/vk-login.png` });
    if (i === 0) log(`screenshot: https://cashflow-game.ru/screenshots/${SHOTS.split('/').pop()}/vk-login.png`);
    await page.waitForTimeout(5000);
  }
  const id = await myId(page).catch(() => 0);
  log(id ? `logged in, id=${id}` : 'not logged in (timeout)');
  rmSync(`${SHOTS}/vk-login.png`, { force: true });   // QR = ключ входа, публично не держим
  await ctx.close();
}

async function api(page, method, params) {
  log(`VK API: ${method}`);
  const viaVkApi = await page.evaluate(async ([m, p]) => {
    if (!window.vkApi?.api) return { missing: true };
    try { return { ok: await window.vkApi.api(m, p) }; } catch (e) { return { err: String(e?.message ?? JSON.stringify(e)) }; }
  }, [method, params]);
  if (!viaVkApi.missing) {
    if (viaVkApi.err) throw new Error(`${method} (vkApi): ${viaVkApi.err}`);
    return viaVkApi.ok;
  }
  if (!page.capturedToken) throw new Error('нет ни window.vkApi, ни перехваченного токена');
  const body = new URLSearchParams({ ...params, access_token: page.capturedToken, v: '5.199' });
  const res = await page.evaluate(async ([m, b]) =>
    (await fetch(`https://api.vk.com/method/${m}`, { method: 'POST', body: new URLSearchParams(b) })).json(), [method, body.toString()]);
  if (res.error) throw new Error(`${method}: ${res.error.error_code} ${res.error.error_msg}`);
  return res.response;
}

async function withIm(fn) {
  const { ctx, page } = await open();
  await page.goto('https://vk.com/im', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(4000);         // дать клиенту инициализироваться / сделать свои запросы
  if (!(await myId(page))) { await ctx.close(); throw new Error('не залогинен — сначала login'); }
  log(`id=${await myId(page)} vkApi=${await page.evaluate(() => typeof window.vkApi?.api)} token=${page.capturedToken ? 'captured' : 'none'}`);
  try { await fn(page); } finally { await ctx.close(); }
}

const short = (s) => (s ?? '').replace(/\s+/g, ' ').slice(0, 60);

async function probe(page) {
  const conv = await api(page, 'messages.getConversations', { filter: 'unread', count: 20, extended: 1 });
  const names = new Map([
    ...(conv.profiles ?? []).map((p) => [p.id, `${p.first_name} ${p.last_name}`]),
    ...(conv.groups ?? []).map((g) => [-g.id, g.name]),
  ]);
  console.log(`unread conversations: ${conv.count}`);
  for (const { conversation: c } of conv.items.slice(0, 5)) {
    const title = c.chat_settings?.title ?? names.get(c.peer.id) ?? c.peer.id;
    console.log(`- ${title} [${c.peer.type} ${c.peer.id}] unread=${c.unread_count ?? 0}`);
    const h = await api(page, 'messages.getHistory', { peer_id: c.peer.id, count: 3 });
    for (const m of h.items) console.log(`    ${m.out ? '→' : '←'} ${short(m.text) || '[вложение]'}`);
  }
}

async function send(page, peer, text) {
  const r = await api(page, 'messages.send', { peer_id: peer, message: text, random_id: Date.now() % 2 ** 31 });
  console.log('sent, message_id =', JSON.stringify(r));
}

const [cmd, ...args] = process.argv.slice(2);
if (cmd === 'login') await login();
else if (cmd === 'probe') await withIm(probe);
else if (cmd === 'send') await withIm((p) => send(p, args[0], args.slice(1).join(' ')));
else if (cmd === 'api') await withIm(async (p) => console.log(JSON.stringify(await api(p, args[0], JSON.parse(args[1] ?? '{}')))));
else { console.error('usage: node spike.mjs login | probe | send <peer_id> <text>'); process.exit(2); }
