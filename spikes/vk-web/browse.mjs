// Пошаговый браузер для агента: открыть URL, выполнить действия, вернуть aria-снимок страницы (текстом, без скриншотов).
//   node browse.mjs <url|-> '[{"click":"Создать"},{"fill":["Название","X"]},{"select":["Платформа","Web"]},{"wait":3000}]'
// url "-" = остаться на последней странице (сохраняется в profile/../last-url).
import { chromium } from 'playwright';
import { readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';

const PROFILE = process.env.VK_PROFILE_DIR ?? `${process.env.HOME}/.local/share/vk-web-spike/profile`;
const LAST = `${PROFILE}/../last-url`;
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36';

// Секреты (ключи VK) никогда не печатаем: вырезаем из любого вывода.
const TOKEN_RE = /vk1\.a\.[\w-]{20,}|\b[0-9a-f]{85}\b/g;
const redact = (s) => s.replace(TOKEN_RE, '<REDACTED>');

const [urlArg, actionsArg = '[]'] = process.argv.slice(2);
const url = urlArg === '-' ? readFileSync(LAST, 'utf8').trim() : urlArg;

const ctx = await chromium.launchPersistentContext(PROFILE, {
  headless: true, userAgent: UA, locale: 'ru-RU', viewport: { width: 1280, height: 900 },
});
const page = ctx.pages()[0] ?? await ctx.newPage();
try {
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);
  for (const a of JSON.parse(actionsArg)) {
    if (a.click) await page.getByText(a.click, { exact: false }).first().click();
    if (a.clickRole) await page.getByRole(a.clickRole[0], { name: a.clickRole[1], exact: true }).last().click();
    if (a.fill) await page.getByLabel(a.fill[0]).or(page.getByPlaceholder(a.fill[0])).first().fill(a.fill[1]);
    if (a.select) await page.getByLabel(a.select[0]).selectOption({ label: a.select[1] });
    if (a.waitCode && a.ifText && !(await page.locator('body').innerText()).includes(a.ifText)) {
      console.log(`waitCode skipped: no "${a.ifText}" on page`);
    } else if (a.waitCode) {                // ждём код (SMS/MAX) от человека в файле, печатаем в фокус
      for (let i = 0; i < 100 && !existsSync(a.waitCode); i++) await page.waitForTimeout(3000);
      const code = readFileSync(a.waitCode, 'utf8').replace(/\D/g, '');
      rmSync(a.waitCode);
      await page.keyboard.type(code, { delay: 150 });
    }
    if (a.press) await page.keyboard.press(a.press);
    if (a.saveToken) {                      // найденный на странице ключ → файл (600), в вывод только длина
      const inputs = await page.locator('input, textarea').evaluateAll((els) => els.map((e) => e.value).join(' '));
      const found = (inputs + ' ' + await page.locator('body').innerText()).match(TOKEN_RE);
      if (found) writeFileSync(a.saveToken, found[0], { mode: 0o600 });
      console.log(found ? `token saved → ${a.saveToken} (len ${found[0].length})` : 'token NOT found on page');
    }
    if (a.check) await page.getByRole("checkbox", { name: a.check }).or(page.getByRole("switch", { name: a.check })).or(page.getByLabel(a.check)).first().check({ force: true });
    await page.waitForTimeout(a.wait ?? 1500);
  }
  writeFileSync(LAST, page.url());
  console.log(`URL: ${page.url()}\nTITLE: ${await page.title()}\n`);
  console.log(redact(await page.locator('body').ariaSnapshot()).slice(0, 12000));
  if (process.env.TEXT) console.log('\n--- innerText:\n' + redact(await page.locator('body').innerText()).slice(0, 6000));
} catch (e) {
  console.log(`URL: ${page.url()}\nERROR: ${e.message.split('\n')[0]}`);
  console.log(redact(await page.locator('body').ariaSnapshot().catch(() => '')).slice(0, 6000));
} finally {
  await ctx.close();
}
