// Пошаговый браузер для агента: открыть URL, выполнить действия, вернуть aria-снимок страницы (текстом, без скриншотов).
//   node browse.mjs <url|-> '[{"click":"Создать"},{"fill":["Название","X"]},{"select":["Платформа","Web"]},{"wait":3000}]'
// url "-" = остаться на последней странице (сохраняется в profile/../last-url).
import { chromium } from 'playwright';
import { readFileSync, writeFileSync, existsSync, rmSync } from 'node:fs';

const PROFILE = process.env.VK_PROFILE_DIR ?? `${process.env.HOME}/.local/share/vk-web-spike/profile`;
const LAST = `${PROFILE}/../last-url`;
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36';

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
    if (a.clickRole) await page.getByRole(a.clickRole[0], { name: a.clickRole[1] }).first().click();
    if (a.fill) await page.getByLabel(a.fill[0]).or(page.getByPlaceholder(a.fill[0])).first().fill(a.fill[1]);
    if (a.select) await page.getByLabel(a.select[0]).selectOption({ label: a.select[1] });
    if (a.waitCode) {                       // ждём код (SMS/MAX) от человека в файле, печатаем в фокус
      for (let i = 0; i < 100 && !existsSync(a.waitCode); i++) await page.waitForTimeout(3000);
      const code = readFileSync(a.waitCode, 'utf8').replace(/\D/g, '');
      rmSync(a.waitCode);
      await page.keyboard.type(code, { delay: 150 });
    }
    if (a.check)await page.getByRole("switch", { name: a.check }).or(page.getByLabel(a.check)).first().check({ force: true });
    await page.waitForTimeout(a.wait ?? 1500);
  }
  writeFileSync(LAST, page.url());
  console.log(`URL: ${page.url()}\nTITLE: ${await page.title()}\n`);
  console.log((await page.locator('body').ariaSnapshot()).slice(0, 12000));
  if (process.env.TEXT) console.log('\n--- innerText:\n' + (await page.locator('body').innerText()).slice(0, 6000));
} catch (e) {
  console.log(`URL: ${page.url()}\nERROR: ${e.message.split('\n')[0]}`);
  console.log((await page.locator('body').ariaSnapshot().catch(() => '')).slice(0, 6000));
} finally {
  await ctx.close();
}
