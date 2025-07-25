/**
 * Use this file to configure your truffle project.
 */

// require('dotenv').config(); // Tidak perlu ini jika hanya pakai network 'development'
// const HDWalletProvider = require('@truffle/hdwallet-provider'); // Tidak perlu ini jika hanya pakai network 'development'

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7546,
      network_id: "*", // Match any network ID (default untuk Ganache adalah 5777, tapi "*" lebih fleksibel)
    },
    // Konfigurasi untuk jaringan publik (seperti Sepolia) DIKOMENTARI PENUH
    // karena fokus sekarang ke Ganache lokal dan menghindari kerumitan.
  },

  mocha: {
    // timeout: 100000
  },

  // Konfigurasi compilers
  compilers: {
    solc: {
      // Truffle akan mencoba mengunduh versi ini jika belum ada
      version: "0.8.19", // <-- TETAPKAN KE 0.8.20 (ini yang terakhir kali berhasil kompilasi sampai error stack too deep)
      settings: {
        optimizer: {
          enabled: true,  // Mengaktifkan optimizer
          runs: 200,      // Jumlah optimasi yang dilakukan
        },
        viaIR: true,
      },
    },
  },
};