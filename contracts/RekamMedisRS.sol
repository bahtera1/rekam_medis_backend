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
        address adminRS; // Rumah sakit tempat dokter bertugas (alamat AdminRS)
    }
    mapping(address => Dokter) public dataDokter;
    mapping(address => bool) public isDokter;
    address[] public daftarDokter;

    struct Pasien {
        string nama;
        string golonganDarah;
        string tanggalLahir;
        string gender;
        string alamat;
        string noTelepon;
        string email;
        address rumahSakitPenanggungJawab; // Alamat AdminRS penanggung jawab
        bool exists;
    }
    mapping(address => Pasien) public dataPasien;
    mapping(address => bool) public isPasien;
    address[] public daftarPasien;

    // Struct RekamMedisData yang disederhanakan
    struct RekamMedisData {
        uint id;
        address pasien;
        string diagnosa;
        string foto;
        string catatan;
        bool valid; // Tetap dipertahankan untuk menandai RM tidak berlaku
        address pembuat; // Pembuat RM ini
        uint256 timestampPembuatan; // Waktu pembuatan RM ini
        string tipeRekamMedis; // Jenis rekam medis (Pemeriksaan, Lab, Resep, dll.)
    }
    mapping(uint => RekamMedisData) public rekamMedis;
    mapping(address => uint[]) public rekamMedisByPasien; // Daftar ID RM untuk pasien
    uint public rekamMedisCount;

    // mapping rekamMedisVersions, rekamMedisUpdateHistory, struct UpdateInfo,
    // dan struct FullRMHistoryEntry DIHAPUS karena tidak ada lagi versi atau history update per ID RM yang kompleks.

    // Events (dimodifikasi)
    event AdminRSTerdaftar(address indexed admin, string namaRumahSakit);
    event AdminRSStatusDiubah(address indexed admin, bool aktif);
    event DokterTerdaftar(address indexed dokter, string nama, address adminRS);
    event DokterStatusDiubah(address indexed dokter, bool aktif);
    event DokterInfoDiperbarui(
        address indexed dokter,
        string nama,
        string spesialisasi,
        string nomorLisensi,
        address indexed adminRS
    );
    event PasienTerdaftar(address indexed pasien, string nama, address adminRS);
    event PasienPindahRS(
        address indexed pasien,
        address oldAdminRS,
        address newAdminRS
    );
    event PasienDiassignKeDokter(address dokter, address pasien);
    event PasienDiunassignDariDokter(address dokter, address pasien);

    // Event RekamMedisDitambahkan dimodifikasi
    event RekamMedisDitambahkan(
        uint id,
        address pasien,
        string diagnosa,
        string foto,
        string catatan,
        string tipeRekamMedis,
        address pembuat,
        uint timestamp,
        bool valid
    );
    // Event RekamMedisDiperbarui DIHAPUS (karena tidak ada update)

    event PasienDataDiperbarui(
        address indexed pasien,
        string nama,
        string golonganDarah,
        string tanggalLahir,
        string gender,
        string alamat,
        string noTelepon,
        string email
    );

    constructor() {
        superAdmin = 0xB0dC0Bf642d339517438017Fc185Bb0f758A01D2; // << GANTI DENGAN ALAMAT SUPER ADMIN ANDA >>
    }

    // Modifier (Tidak ada perubahan di sini)
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

    // Modifier hanyaDokterAktifUntukPasien ini masih digunakan oleh 'tambahRekamMedis'
    modifier hanyaDokterAktifUntukPasien(address _pasien) {
        require(
            isDokter[msg.sender] && dataDokter[msg.sender].aktif,
            "Hanya dokter aktif."
        );
        require(dataPasien[_pasien].exists, "Pasien tidak terdaftar.");
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
        require(
            msg.sender == _pasien,
            "Hanya pasien yang bersangkutan yang dapat menjalankan fungsi ini."
        );
        _;
    }

    // --- Admin RS Functions (Tidak ada perubahan signifikan) ---
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

    function getNamaRumahSakitByAdmin(
        address _adminRS
    ) external view returns (string memory) {
        require(
            bytes(dataAdmin[_adminRS].namaRumahSakit).length > 0,
            "Admin RS tidak ditemukan."
        );
        return dataAdmin[_adminRS].namaRumahSakit;
    }

    // --- Dokter Functions (Tidak ada perubahan signifikan) ---
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

    function getAssignedPatients(
        address _dokter
    ) external view returns (address[] memory) {
        require(isDokter[_dokter], "Dokter tidak ditemukan.");
        return dataDokter[_dokter].assignedPasien;
    }

    // --- Pasien Functions ---
    function registerPasien(
        address _pasien,
        string calldata _nama,
        address _adminRS
    ) external hanyaAdminRS {
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
        );
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
        address _adminRS
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

    function updatePasienData(
        string calldata _nama,
        string calldata _golonganDarah,
        string calldata _tanggalLahir,
        string calldata _gender,
        string calldata _alamat,
        string calldata _noTelepon,
        string calldata _email
    ) external hanyaPasien(msg.sender) {
        require(
            dataPasien[msg.sender].exists,
            "Data pasien Anda tidak ditemukan."
        );

        Pasien storage pasienToUpdate = dataPasien[msg.sender];
        pasienToUpdate.nama = _nama;
        pasienToUpdate.golonganDarah = _golonganDarah;
        pasienToUpdate.tanggalLahir = _tanggalLahir;
        pasienToUpdate.gender = _gender;
        pasienToUpdate.alamat = _alamat;
        pasienToUpdate.noTelepon = _noTelepon;
        pasienToUpdate.email = _email;

        emit PasienDataDiperbarui(
            msg.sender,
            _nama,
            _golonganDarah,
            _tanggalLahir,
            _gender,
            _alamat,
            _noTelepon,
            _email
        );
    }

    function updatePasienRumahSakit(
        address _newAdminRS
    ) external hanyaPasien(msg.sender) {
        require(
            dataPasien[msg.sender].exists,
            "Data pasien Anda tidak ditemukan."
        );
        require(
            dataAdmin[_newAdminRS].aktif,
            "Rumah Sakit baru tidak aktif atau tidak valid."
        );
        require(
            dataPasien[msg.sender].rumahSakitPenanggungJawab != _newAdminRS,
            "Anda sudah terdaftar di rumah sakit ini."
        );

        address oldAdminRS = dataPasien[msg.sender].rumahSakitPenanggungJawab;
        dataPasien[msg.sender].rumahSakitPenanggungJawab = _newAdminRS;

        emit PasienPindahRS(msg.sender, oldAdminRS, _newAdminRS);
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
            dataPasien[_pasien].rumahSakitPenanggungJawab == msg.sender ||
                dataPasien[_pasien].rumahSakitPenanggungJawab == address(0),
            "Pasien ini tidak terdaftar di rumah sakit Anda atau sudah di-assign ke RS lain."
        );

        if (dataPasien[_pasien].rumahSakitPenanggungJawab == address(0)) {
            dataPasien[_pasien].rumahSakitPenanggungJawab = msg.sender;
        }

        bool alreadyAssigned = false;
        address[] storage listPasienDitugaskan = dataDokter[_dokter]
            .assignedPasien;
        for (uint i = 0; i < listPasienDitugaskan.length; i++) {
            if (listPasienDitugaskan[i] == _pasien) {
                alreadyAssigned = true;
                break;
            }
        }
        require(
            !alreadyAssigned,
            "Pasien ini sudah ditugaskan ke dokter tersebut."
        );

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
                listPasienDitugaskan[i] = listPasienDitugaskan[
                    listPasienDitugaskan.length - 1
                ];
                listPasienDitugaskan.pop();
                found = true;
                break;
            }
        }
        require(found, "Pasien tidak ditugaskan ke dokter ini.");
        emit PasienDiunassignDariDokter(_dokter, _pasien);
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

    // --- Rekam Medis Functions ---
    // Fungsi tambahRekamMedis dimodifikasi untuk menerima tipeRekamMedis
    // dan sekarang selalu membuat Rekam Medis baru, bukan update versi.
    function tambahRekamMedis(
        address _pasien,
        string calldata _diagnosa,
        string calldata _foto,
        string calldata _catatan,
        string calldata _tipeRekamMedis // BARU
    ) external {
        bool isValidActor = false;
        if (msg.sender == _pasien && isPasien[msg.sender]) {
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
        require(dataPasien[_pasien].exists, "Pasien tidak terdaftar.");

        rekamMedisCount++;
        uint newId = rekamMedisCount;
        rekamMedis[newId] = RekamMedisData({
            id: newId,
            pasien: _pasien,
            diagnosa: _diagnosa,
            foto: _foto,
            catatan: _catatan,
            valid: true,
            pembuat: msg.sender,
            timestampPembuatan: block.timestamp,
            tipeRekamMedis: _tipeRekamMedis
        });
        rekamMedisByPasien[_pasien].push(newId);

        emit RekamMedisDitambahkan(
            newId,
            _pasien,
            _diagnosa,
            _foto,
            _catatan,
            _tipeRekamMedis,
            msg.sender,
            block.timestamp,
            true
        );
    }

    // Fungsi updateRekamMedis DIHAPUS (karena setiap perubahan adalah RM baru)
    // Fungsi getRekamMedisVersions DIHAPUS
    // Fungsi getRekamMedisUpdateHistory DIHAPUS
    // Fungsi getFullRekamMedisHistory DIHAPUS (semua ini diganti oleh model 'RM baru')

    function getRekamMedisIdsByPasien(
        address _pasien
    ) external view returns (uint[] memory) {
        require(isPasien[_pasien], "Pasien tidak ditemukan.");
        return rekamMedisByPasien[_pasien];
    }

    // Fungsi getRekamMedis disesuaikan dengan struct RekamMedisData yang baru
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
            bool valid,
            address pembuat,
            uint256 timestampPembuatan,
            string memory tipeRekamMedis
        )
    {
        require(
            rekamMedis[_id].pasien != address(0),
            "Rekam medis tidak ditemukan."
        );
        RekamMedisData storage r = rekamMedis[_id];
        return (
            r.id,
            r.pasien,
            r.diagnosa,
            r.foto,
            r.catatan,
            r.valid,
            r.pembuat,
            r.timestampPembuatan,
            r.tipeRekamMedis
        );
    }

    // Fungsi nonaktifkanRekamMedis tetap sama, ia akan menonaktifkan RM spesifik
    function nonaktifkanRekamMedis(uint _id) external hanyaAdminRS {
        require(
            rekamMedis[_id].pasien != address(0),
            "Rekam medis tidak ditemukan."
        );
        require(
            dataPasien[rekamMedis[_id].pasien].rumahSakitPenanggungJawab ==
                msg.sender,
            "Admin RS tidak berhak atas pasien ini."
        );
        rekamMedis[_id].valid = false;
    }

    // --- Super Admin Functions (Tidak ada perubahan) ---
    function setSuperAdmin(address _newAdmin) external hanyaSuperAdmin {
        require(
            _newAdmin != address(0),
            "Alamat super admin baru tidak valid."
        );
        superAdmin = _newAdmin;
    }

    // --- Utility Functions (Tidak ada perubahan) ---
    function getUserRole(address _user) public view returns (string memory) {
        if (_user == superAdmin) return "SuperAdmin";
        if (dataAdmin[_user].aktif) return "AdminRS";
        if (isDokter[_user]) return "Dokter";
        if (isPasien[_user]) return "Pasien";
        return "Unknown";
    }
}
