const { contextBridge, ipcRenderer } = require('electron');

async function invoke(channel, value) {
    const response = await ipcRenderer.invoke(channel, value);
    if (!response.ok) throw new Error(response.error);
    return response.value;
}

contextBridge.exposeInMainWorld('yiliGPT', Object.freeze({
    status: () => invoke('gpt:status'),
    setKey: (key) => invoke('gpt:set-key', key),
    clearKey: () => invoke('gpt:clear-key'),
    generate: (request) => invoke('gpt:generate', request),
    cancel: (requestId) => invoke('gpt:cancel', requestId),
}));
