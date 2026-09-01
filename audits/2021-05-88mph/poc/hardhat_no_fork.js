// Disable mainnet forking for deterministic local reproduction.
const config = require("./hardhat.config.js");

config.networks.hardhat = {};
config.telemetry = { enabled: false };
config.mocha = { timeout: 60000, grep: process.env.TEST_GREP || undefined };

module.exports = config;
