module.exports = {
    apps: [
        {
            name: 'web_server',
            script: './server.js',
            watch: true,
            // Delay between restart
            watch_delay: 2000,
            ignore_watch: ['node_modules', 'public','sessions'],
            log_date_format: 'YYYY-MM-DD HH:mm:ss',
            watch_options: {
                followSymlinks: false,
            },
        },
    ],
};
