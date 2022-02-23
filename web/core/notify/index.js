var {
    execSync
} = require('child_process');

function panelSendNotify(title, content) {
    execSync(`task notify "${title}" "${content}"`);
}

module.exports = {
    panelSendNotify
}
