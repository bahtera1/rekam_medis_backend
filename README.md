# Implementasi Sistem Rekam Medis Elektronik Menggunakan Teknologi Blockchain (SOLIDITY CODE)

**Disusun oleh:**
* **Naufal Assani Saputra** (NIM: 20210140058)

**Dosen Pembimbing:**
* **Ir. Eko Prasetyo, M.Eng., Ph.D.** (NIDN: 0522046701)  
* **Prayitno, S.ST., M.T., Ph.D.** (NIDN: 0010048506)

# 📄 Smart Contract: Rekam Medis Berbasis Blockchain

Repositori ini berisi smart contract untuk sistem **Rekam Medis Elektronik (RME)** berbasis blockchain, dikembangkan menggunakan **Solidity** dan dikelola melalui framework **Truffle**. Kontrak ini bertujuan meningkatkan transparansi, keamanan, dan integritas data rekam medis melalui desentralisasi.



## 🛠 Tools yang Digunakan

- [Truffle](https://trufflesuite.com/)
- [Ganache](https://trufflesuite.com/ganache/)
- [Solidity](https://docs.soliditylang.org/)



## ⚙️ Instalasi
```bash
git clone https://github.com/bahtera1/rekam_medis_solidity.git
cd rekam_medis_solidity
npm install
```

## 🔨 Compile Kontrak
```bash
truffle compile
```

## 🚀 Deploy ke Jaringan Lokal (Ganache)
Pastikan Ganache sudah aktif (GUI/CLI).

Jalankan perintah berikut untuk migrasi:
```bash
truffle migrate --network development
```

## 🧪 Testing (Opsional)
Jika sudah ada script test di folder /test, jalankan:
```bash
truffle test
```
Setelah kontrak berhasil di-deploy, ambil alamat kontraknya dari output dan tambahkan ke file .env di folder frontend dan salin file ABI ke frontend.
