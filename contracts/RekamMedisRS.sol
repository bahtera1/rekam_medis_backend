// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RekamMedisRS {
    address public superAdmin;

    struct AdminRS {
        string namaRumahSakit;
        bool aktif;
    }
    mapping(address => AdminRS) public dataAdmin;
    address[] public daftarAdmin;

    struct Dokter {
        string nama;
        string spesialisasi;
        string nomorLisensi;
        bool aktif;
        address[] assignedPasien;
        address adminRS; // Rumah sakit tempat dokter bertugas
    }
    mapping(address => Dokter) public dataDokter;
    mapping(address => bool) public isDokter;
    address[] public daftarDokter; // Ditambahkan untuk melacak semua dokter

    struct Pasien {
        string nama;
        string golonganDarah;
        string tanggalLahir;
        string gender;
        string alamat;
        string noTelepon;
        string email;
        address rumahSakitPenanggungJawab;
        bool exists;
    }
    mapping(address => Pasien) public dataPasien;
    mapping(address => bool) public isPasien;
    address[] public daftarPasien; // Ditambahkan untuk melacak semua pasien

    struct UpdateInfo {
        address dokter; // alamat aktor yang melakukan update/pembuatan (bisa dokter atau pasien)
        uint256 timestamp; // waktu update (block.timestamp)
    }

    struct RekamMedisData {
        uint id;
        address pasien;
        string diagnosa;
        string foto;
        string catatan;
        bool valid;
    }
    mapping(uint => RekamMedisData) public rekamMedis;
    mapping(address => uint[]) public rekamMedisByPasien;
    uint public rekamMedisCount;

    // History versi rekam medis
    mapping(uint => RekamMedisData[]) public rekamMedisVersions;
    mapping(uint => UpdateInfo[]) public rekamMedisUpdateHistory;

    // Events
    event AdminRSTerdaftar(address indexed admin, string namaRumahSakit);
    event AdminRSStatusDiubah(address indexed admin, bool aktif);
    event DokterTerdaftar(address indexed dokter, string nama, address adminRS);
    event DokterStatusDiubah(address indexed dokter, bool aktif);
    event DokterInfoDiperbarui(
        // Event untuk update info dokter
        address indexed dokter,
        string nama,
        string spesialisasi,
        string nomorLisensi,
        address indexed adminRS
    );
    event PasienTerdaftar(address indexed pasien, string nama, address adminRS);
    event PasienPindahRS(address indexed pasien, address adminRS); // Belum ada fungsinya
    event PasienDiassignKeDokter(address dokter, address pasien);
    event RekamMedisDitambahkan(
        uint id,
        address pasien,
        string diagnosa,
        bool valid
    );
    event RekamMedisDiperbarui(
        uint id,
        string diagnosa,
        string catatan,
        address dokter, // Aktor yang memperbarui
        uint timestamp
    );

    event PasienDiunassignDariDokter(address dokter, address pasien);

    constructor() {
        superAdmin = 0xB0dC0Bf642d339517438017Fc185Bb0f758A01D2; // Sesuai kode Anda
    }

    // Modifier
    modifier hanyaSuperAdmin() {
        require(
            msg.sender == superAdmin,
            "Hanya super admin yang dapat menjalankan fungsi ini."
        );
        _;
    }

    modifier hanyaAdminRS() {
        require(
            dataAdmin[msg.sender].aktif,
            "Hanya admin RS yang aktif yang dapat menjalankan fungsi ini."
        );
        _;
    }

    modifier hanyaDokterAktif() {
        require(
            isDokter[msg.sender] && dataDokter[msg.sender].aktif,
            "Hanya dokter yang aktif yang dapat menjalankan fungsi ini."
        );
        _;
    }

    modifier hanyaDokterAktifUntukPasien(address _pasien) {
        require(
            isDokter[msg.sender] && dataDokter[msg.sender].aktif,
            "Hanya dokter aktif."
        );
        require(dataPasien[_pasien].exists, "Pasien tidak terdaftar."); // Pastikan pasien ada
        require(
            dataDokter[msg.sender].adminRS ==
                dataPasien[_pasien].rumahSakitPenanggungJawab,
            "Dokter dan pasien tidak berada di rumah sakit yang sama."
        );
        bool assigned = false;
        address[] storage listPasienDitugaskan = dataDokter[msg.sender]
            .assignedPasien;
        for (uint i = 0; i < listPasienDitugaskan.length; i++) {
            if (listPasienDitugaskan[i] == _pasien) {
                assigned = true;
                break;
            }
        }
        require(
            assigned,
            "Dokter ini tidak ditugaskan untuk menangani pasien tersebut."
        );
        _;
    }

    modifier hanyaPasien(address _pasien) {
        // Modifier untuk pasien tertentu
        require(
            msg.sender == _pasien,
            "Hanya pasien yang bersangkutan yang dapat menjalankan fungsi ini."
        );
        _;
    }

    function registerAdminRS(
        address _admin,
        string calldata _namaRS
    ) external hanyaSuperAdmin {
        require(
            bytes(dataAdmin[_admin].namaRumahSakit).length == 0,
            "Admin RS sudah terdaftar dengan alamat ini."
        );
        dataAdmin[_admin] = AdminRS({namaRumahSakit: _namaRS, aktif: true});
        daftarAdmin.push(_admin);
        emit AdminRSTerdaftar(_admin, _namaRS);
    }

    function getAllAdminRSAddresses() external view returns (address[] memory) {
        return daftarAdmin;
    }

    function setStatusAdminRS(
        address _admin,
        bool _aktif
    ) external hanyaSuperAdmin {
        require(
            bytes(dataAdmin[_admin].namaRumahSakit).length != 0,
            "Admin RS tidak ditemukan."
        );
        dataAdmin[_admin].aktif = _aktif;
        emit AdminRSStatusDiubah(_admin, _aktif);
    }

    function totalAdmin() external view returns (uint) {
        return daftarAdmin.length;
    }

    function getAdminByIndex(uint idx) external view returns (address) {
        require(idx < daftarAdmin.length, "Indeks admin RS tidak valid.");
        return daftarAdmin[idx];
    }

    function registerDokter(
        address _dokter,
        string calldata _nama,
        string calldata _spesialisasi,
        string calldata _nomorLisensi
    ) external hanyaAdminRS {
        require(
            !isDokter[_dokter],
            "Alamat ini sudah terdaftar sebagai dokter."
        );
        require(
            !isPasien[_dokter],
            "Alamat ini terdaftar sebagai pasien, tidak bisa menjadi dokter."
        );
        isDokter[_dokter] = true;
        dataDokter[_dokter] = Dokter({
            nama: _nama,
            spesialisasi: _spesialisasi,
            nomorLisensi: _nomorLisensi,
            aktif: true,
            assignedPasien: new address[](0),
            adminRS: msg.sender
        });
        daftarDokter.push(_dokter);
        emit DokterTerdaftar(_dokter, _nama, msg.sender);
    }

    function updateDokterInfo(
        address _dokter,
        string calldata _namaBaru,
        string calldata _spesialisasiBaru,
        string calldata _nomorLisensiBaru
    ) external hanyaAdminRS {
        require(isDokter[_dokter], "Dokter tidak terdaftar di sistem.");
        require(
            dataDokter[_dokter].adminRS == msg.sender,
            "Anda bukan admin RS yang berhak untuk dokter ini."
        );

        Dokter storage dokterToUpdate = dataDokter[_dokter];
        dokterToUpdate.nama = _namaBaru;
        dokterToUpdate.spesialisasi = _spesialisasiBaru;
        dokterToUpdate.nomorLisensi = _nomorLisensiBaru;

        emit DokterInfoDiperbarui(
            _dokter,
            _namaBaru,
            _spesialisasiBaru,
            _nomorLisensiBaru,
            msg.sender
        );
    }

    function setStatusDokter(
        address _dokter,
        bool _aktif
    ) external hanyaAdminRS {
        require(isDokter[_dokter], "Dokter tidak terdaftar.");
        require(
            dataDokter[_dokter].adminRS == msg.sender,
            "Dokter ini tidak terdaftar di rumah sakit Anda."
        );
        dataDokter[_dokter].aktif = _aktif;
        emit DokterStatusDiubah(_dokter, _aktif);
    }

    function totalDokter() external view returns (uint) {
        return daftarDokter.length;
    }

    function getDokterByIndex(uint idx) external view returns (address) {
        require(idx < daftarDokter.length, "Indeks dokter tidak valid.");
        return daftarDokter[idx];
    }

    function getDokter(
        address _dokter
    )
        external
        view
        returns (
            string memory nama,
            string memory spesialisasi,
            string memory nomorLisensi,
            bool aktif,
            address[] memory pasienList,
            address adminRS
        )
    {
        require(isDokter[_dokter], "Dokter tidak ditemukan.");
        Dokter storage d = dataDokter[_dokter];
        return (
            d.nama,
            d.spesialisasi,
            d.nomorLisensi,
            d.aktif,
            d.assignedPasien,
            d.adminRS
        );
    }

    function registerPasien(
        address _pasien,
        string calldata _nama,
        address _adminRS // Alamat Admin RS yang mendaftarkan
    ) external hanyaAdminRS {
        // Hanya admin RS yang aktif yang bisa mendaftarkan
        require(
            !isPasien[_pasien],
            "Pasien sudah terdaftar dengan alamat ini."
        );
        require(
            !isDokter[_pasien],
            "Alamat ini terdaftar sebagai dokter, tidak bisa menjadi pasien."
        );
        require(
            dataAdmin[_adminRS].aktif,
            "Admin RS yang dirujuk tidak aktif."
        ); // Pastikan admin RS penanggung jawab aktif
        require(
            msg.sender == _adminRS,
            "Hanya admin RS penanggung jawab yang bisa mendaftarkan pasien ini."
        );

        isPasien[_pasien] = true;
        dataPasien[_pasien] = Pasien({
            nama: _nama,
            golonganDarah: "",
            tanggalLahir: "",
            gender: "",
            alamat: "",
            noTelepon: "",
            email: "",
            rumahSakitPenanggungJawab: _adminRS,
            exists: true
        });
        daftarPasien.push(_pasien);
        emit PasienTerdaftar(_pasien, _nama, _adminRS);
    }

    function selfRegisterPasien(
        string calldata _nama,
        string calldata _golonganDarah,
        string calldata _tanggalLahir,
        string calldata _gender,
        string calldata _alamat,
        string calldata _noTelepon,
        string calldata _email,
        address _adminRS // Admin RS yang dipilih pasien sebagai penanggung jawab awal
    ) external {
        require(!isPasien[msg.sender], "Anda sudah terdaftar sebagai pasien.");
        require(!isDokter[msg.sender], "Alamat ini terdaftar sebagai dokter.");
        require(
            dataAdmin[_adminRS].aktif,
            "Rumah Sakit yang dipilih tidak aktif atau tidak valid."
        );

        isPasien[msg.sender] = true;
        dataPasien[msg.sender] = Pasien({
            nama: _nama,
            golonganDarah: _golonganDarah,
            tanggalLahir: _tanggalLahir,
            gender: _gender,
            alamat: _alamat,
            noTelepon: _noTelepon,
            email: _email,
            rumahSakitPenanggungJawab: _adminRS,
            exists: true
        });
        daftarPasien.push(msg.sender);
        emit PasienTerdaftar(msg.sender, _nama, _adminRS);
    }

    function getDaftarPasien() external view returns (address[] memory) {
        return daftarPasien;
    }

    function getPasienData(
        address _pasien
    )
        external
        view
        returns (
            string memory nama,
            string memory golonganDarah,
            string memory tanggalLahir,
            string memory gender,
            string memory alamat,
            string memory noTelepon,
            string memory email,
            address rumahSakitPenanggungJawab
        )
    {
        require(isPasien[_pasien], "Pasien tidak ditemukan.");
        Pasien storage p = dataPasien[_pasien];
        return (
            p.nama,
            p.golonganDarah,
            p.tanggalLahir,
            p.gender,
            p.alamat,
            p.noTelepon,
            p.email,
            p.rumahSakitPenanggungJawab
        );
    }

    function assignPasienToDokter(
        address _dokter,
        address _pasien
    ) external hanyaAdminRS {
        require(isDokter[_dokter], "Dokter tidak terdaftar.");
        require(
            dataDokter[_dokter].adminRS == msg.sender,
            "Dokter ini tidak terdaftar di rumah sakit Anda."
        );
        require(isPasien[_pasien], "Pasien tidak terdaftar.");
        require(
            dataPasien[_pasien].rumahSakitPenanggungJawab == msg.sender,
            "Pasien ini tidak terdaftar di rumah sakit Anda."
        );

        address[] storage listPasienDitugaskan = dataDokter[_dokter]
            .assignedPasien;
        for (uint i = 0; i < listPasienDitugaskan.length; i++) {
            require(
                listPasienDitugaskan[i] != _pasien,
                "Pasien ini sudah ditugaskan ke dokter tersebut."
            );
        }
        listPasienDitugaskan.push(_pasien);
        emit PasienDiassignKeDokter(_dokter, _pasien);
    }

    function unassignPasienFromDokter(
        address _dokter,
        address _pasien
    ) external hanyaAdminRS {
        require(isDokter[_dokter], "Dokter tidak terdaftar.");
        require(
            dataDokter[_dokter].adminRS == msg.sender,
            "Dokter ini tidak terdaftar di rumah sakit Anda."
        );
        require(isPasien[_pasien], "Pasien tidak terdaftar.");
        require(
            dataPasien[_pasien].rumahSakitPenanggungJawab == msg.sender,
            "Pasien ini tidak terdaftar di rumah sakit Anda."
        );

        bool found = false;
        address[] storage listPasienDitugaskan = dataDokter[_dokter]
            .assignedPasien;
        for (uint i = 0; i < listPasienDitugaskan.length; i++) {
            if (listPasienDitugaskan[i] == _pasien) {
                // Geser elemen terakhir ke posisi saat ini dan kurangi panjang array
                listPasienDitugaskan[i] = listPasienDitugaskan[
                    listPasienDitugaskan.length - 1
                ];
                listPasienDitugaskan.pop();
                found = true;
                break;
            }
        }
        require(found, "Pasien tidak ditugaskan ke dokter ini.");
        emit PasienDiunassignDariDokter(_dokter, _pasien); // Tambahkan event ini juga di atas
    }

    function isAssigned(
        address _dokter,
        address _pasien
    ) internal view returns (bool) {
        address[] storage list = dataDokter[_dokter].assignedPasien;
        for (uint i = 0; i < list.length; i++) {
            if (list[i] == _pasien) {
                return true;
            }
        }
        return false;
    }

    // --- MODIFIKASI DI SINI ---
    function tambahRekamMedis(
        address _pasien,
        string calldata _diagnosa,
        string calldata _foto,
        string calldata _catatan
    ) external {
        bool isValidActor = false;
        if (msg.sender == _pasien && isPasien[_pasien]) {
            isValidActor = true;
        } else if (isDokter[msg.sender] && dataDokter[msg.sender].aktif) {
            if (
                dataPasien[_pasien].exists &&
                dataDokter[msg.sender].adminRS ==
                dataPasien[_pasien].rumahSakitPenanggungJawab &&
                isAssigned(msg.sender, _pasien)
            ) {
                isValidActor = true;
            }
        }
        require(
            isValidActor,
            "Aktor tidak berhak menambah rekam medis untuk pasien ini."
        );
        require(dataPasien[_pasien].exists, "Pasien tidak terdaftar."); // Pastikan pasien exist sebelum tambah RM

        rekamMedisCount++;
        uint newId = rekamMedisCount; // Gunakan variabel agar konsisten
        rekamMedis[newId] = RekamMedisData({
            id: newId,
            pasien: _pasien,
            diagnosa: _diagnosa,
            foto: _foto,
            catatan: _catatan,
            valid: true
        });
        rekamMedisByPasien[_pasien].push(newId);

        // --- BARIS TAMBAHAN UNTUK MENCATAT RIWAYAT PEMBUATAN AWAL ---
        rekamMedisUpdateHistory[newId].push(
            UpdateInfo({
                dokter: msg.sender, // Menyimpan alamat msg.sender (pembuat)
                timestamp: block.timestamp
            })
        );
        // -----------------------------------------------------------

        emit RekamMedisDitambahkan(newId, _pasien, _diagnosa, true);
    }

    function updateRekamMedis(
        uint _id,
        string calldata _diagnosa,
        string calldata _foto,
        string calldata _catatan
    ) external hanyaDokterAktifUntukPasien(rekamMedis[_id].pasien) {
        RekamMedisData storage r = rekamMedis[_id];
        require(
            r.pasien != address(0),
            "Rekam medis tidak ditemukan atau ID tidak valid."
        ); // Pastikan RM ada
        require(r.valid, "Rekam medis ini sudah tidak valid/dinonaktifkan.");

        // Simpan versi lama sebelum update
        rekamMedisVersions[_id].push(
            RekamMedisData({
                id: r.id,
                pasien: r.pasien,
                diagnosa: r.diagnosa,
                foto: r.foto,
                catatan: r.catatan,
                valid: r.valid // Simpan status validitas sebelumnya juga
            })
        );

        // Update data rekam medis utama
        r.diagnosa = _diagnosa;
        r.foto = _foto;
        r.catatan = _catatan;
        // r.valid tetap true karena ini adalah update aktif, kecuali ada logika lain

        // Simpan info update (siapa dan kapan)
        rekamMedisUpdateHistory[_id].push(
            UpdateInfo({dokter: msg.sender, timestamp: block.timestamp})
        );

        emit RekamMedisDiperbarui(
            _id,
            _diagnosa,
            _catatan,
            msg.sender,
            block.timestamp
        );
    }

    function getRekamMedisIdsByPasien(
        address _pasien
    ) external view returns (uint[] memory) {
        require(isPasien[_pasien], "Pasien tidak ditemukan.");
        return rekamMedisByPasien[_pasien];
    }

    function getRekamMedis(
        uint _id
    )
        external
        view
        returns (
            uint id,
            address pasien,
            string memory diagnosa,
            string memory foto,
            string memory catatan,
            bool valid
        )
    {
        require(
            rekamMedis[_id].pasien != address(0),
            "Rekam medis tidak ditemukan."
        );
        RekamMedisData storage r = rekamMedis[_id];
        return (r.id, r.pasien, r.diagnosa, r.foto, r.catatan, r.valid);
    }

    function getRekamMedisVersions(
        uint _id
    ) external view returns (RekamMedisData[] memory) {
        // Tidak perlu require di sini karena jika _id tidak ada, akan return array kosong
        return rekamMedisVersions[_id];
    }

    function getRekamMedisUpdateHistory(
        uint _id
    )
        external
        view
        returns (address[] memory actors, uint256[] memory timestamps)
    {
        // Tidak perlu require di sini, akan return array kosong jika tidak ada histori
        uint len = rekamMedisUpdateHistory[_id].length;
        actors = new address[](len); // 'actors' karena bisa dokter atau pasien
        timestamps = new uint256[](len);
        for (uint i = 0; i < len; i++) {
            actors[i] = rekamMedisUpdateHistory[_id][i].dokter; // Tetap .dokter sesuai struct
            timestamps[i] = rekamMedisUpdateHistory[_id][i].timestamp;
        }
        return (actors, timestamps);
    }

    function nonaktifkanRekamMedis(uint _id) external hanyaAdminRS {
        require(
            rekamMedis[_id].pasien != address(0),
            "Rekam medis tidak ditemukan."
        );
        // Pastikan adminRS yang menonaktifkan adalah admin dari RS tempat pasien terdaftar
        require(
            dataPasien[rekamMedis[_id].pasien].rumahSakitPenanggungJawab ==
                msg.sender,
            "Admin RS tidak berhak atas pasien ini."
        );
        rekamMedis[_id].valid = false;
        // Pertimbangkan untuk emit event di sini
    }

    function setSuperAdmin(address _newAdmin) external hanyaSuperAdmin {
        require(
            _newAdmin != address(0),
            "Alamat super admin baru tidak valid."
        );
        superAdmin = _newAdmin;
    }

    function getUserRole(address _user) public view returns (string memory) {
        if (_user == superAdmin) return "SuperAdmin";
        if (dataAdmin[_user].aktif) return "AdminRS"; // Cek status aktif juga
        if (isDokter[_user]) return "Dokter";
        if (isPasien[_user]) return "Pasien";
        return "Unknown";
    }
}
