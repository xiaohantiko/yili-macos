const { app, BrowserWindow, Menu, net, protocol, session, shell } = require('electron');
const { mkdtempSync } = require('node:fs');
const { tmpdir } = require('node:os');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const origin = 'yili://almanac';
const home = `${origin}/index.html`;
const smoke = process.argv.includes('--smoke-test');
const assets = new Map([
    ['/index.html', 'renderer/index.html'],
    ['/styles.css', 'renderer/styles.css'],
    ['/app.mjs', 'renderer/app.mjs'],
    ['/bagua.mjs', 'renderer/bagua.mjs'],
    ['/core/bazi.mjs', 'core/bazi.mjs'],
    ['/core/interpretation.mjs', 'core/interpretation.mjs'],
    ['/core/solar-terms.mjs', 'core/solar-terms.mjs'],
]);
const contentTypes = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
};
const references = new Set([
    'https://www.hko.gov.hk/tc/gts/time/stemsandbranches.htm',
    'https://www.hko.gov.hk/tc/gts/time/24solarterms.htm',
    'https://ssd.jpl.nasa.gov/doc/de440_de441.html',
    'https://zh.wikisource.org/wiki/%E5%91%A8%E6%98%93%E6%AD%A3%E7%BE%A9/09.05',
    'https://www.chinese-classics.org/read/shushu/mingli/yuan-hai-zi-ping/001',
]);

app.setName('YiLi');
app.setAppUserModelId('com.yili.almanac');
app.enableSandbox();
protocol.registerSchemesAsPrivileged([
    { scheme: 'yili', privileges: { standard: true, secure: true, corsEnabled: true } },
]);

if (smoke) {
    app.setPath('userData', mkdtempSync(path.join(tmpdir(), 'yili-smoke-')));
}

let mainWindow;

async function createWindow() {
    mainWindow = new BrowserWindow({
        title: '易历',
        width: 1180,
        height: 830,
        minWidth: 820,
        minHeight: 570,
        show: false,
        backgroundColor: '#131613',
        autoHideMenuBar: true,
        webPreferences: {
            contextIsolation: true,
            sandbox: true,
            nodeIntegration: false,
            spellcheck: false,
        },
    });
    const window = mainWindow;
    if (smoke) window.webContents.on('console-message', (details) => console.error(details.message));
    window.on('closed', () => { mainWindow = null; });
    window.webContents.on('will-navigate', (event) => event.preventDefault());
    window.webContents.setWindowOpenHandler(({ url }) => {
        if (references.has(url)) void shell.openExternal(url);
        return { action: 'deny' };
    });
    if (!smoke) window.once('ready-to-show', () => window.show());
    await window.loadURL(home);
    return window;
}

if (!smoke && !app.requestSingleInstanceLock()) {
    app.quit();
} else {
    app.on('second-instance', () => {
        if (!mainWindow) return;
        if (mainWindow.isMinimized()) mainWindow.restore();
        mainWindow.focus();
    });
    app.on('window-all-closed', () => app.quit());
    app.whenReady().then(async () => {
        protocol.handle('yili', async (request) => {
            const url = new URL(request.url);
            const file = url.host === 'almanac' && request.method === 'GET' && assets.get(url.pathname);
            if (!file) return new Response(null, { status: 404 });
            const response = await net.fetch(pathToFileURL(path.join(__dirname, file)).href);
            return new Response(response.body, {
                status: response.status,
                headers: {
                    'Content-Type': contentTypes[path.extname(file)],
                    'Content-Security-Policy': "default-src 'none'; script-src 'self'; style-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
                },
            });
        });
        session.defaultSession.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
        session.defaultSession.setPermissionCheckHandler(() => false);
        Menu.setApplicationMenu(Menu.buildFromTemplate([
            { label: '编辑', submenu: [
                { role: 'undo', label: '撤销' }, { role: 'redo', label: '重做' },
                { type: 'separator' },
                { role: 'cut', label: '剪切' }, { role: 'copy', label: '复制' },
                { role: 'paste', label: '粘贴' }, { role: 'selectAll', label: '全选' },
            ] },
        ]));
        const window = await createWindow();
        if (smoke) {
            await require('./smoke.cjs')(window.webContents, home);
            app.exit(0);
        }
    }).catch((error) => {
        console.error(error);
        app.exit(1);
    });
}
