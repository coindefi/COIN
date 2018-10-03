require('babel-register');
require('babel-polyfill');
module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8544,
      network_id: "*" // Match any network id
    }
  }
};
