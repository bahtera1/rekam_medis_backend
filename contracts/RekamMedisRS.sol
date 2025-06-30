// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RekamMedisRS {
    address public superAdmin;

    struct AdminRS {
        string namaRumahSakit;
        bool aktif;
        string alamatRumahSakit;
        string kota;
        string IDRS; // ID unik Rumah Sakit
    }
    mapping(address => AdminRS) public dataAdmin;
    mapping(string => bool) public isIDRSUsed; // Untuk memastikan IDRS unik
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

    struct RekamMedisData {
        uint id;
        address pasien;
        string diagnosa;
        string foto;
        string catatan;
        bool valid;
        address pembuat;
        uint256 timestampPembuatan;
        string tipeRekamMedis;
    }
    mapping(uint => RekamMedisData) public rekamMedis;
    mapping(address => uint[]) public rekamMedisByPasien;
    uint public rekamMedisCount;

    // Events (dimodifikasi/ditambah)
    event AdminRSTerdaftar(
        address indexed admin,
        string namaRumahSakit,
        string alamatRumahSakit,
        string kota,
        string IDRS // Tambah IDRS ke event
    );
    event AdminRSStatusDiubah(address indexed admin, bool aktif);

    // Event baru untuk update detail Admin RS
    event AdminRSInfoDiperbarui(
        address indexed admin,
        string namaRumahSakit,
        string alamatRumahSakit,
        string kota,
        string IDRS // Tambah IDRS ke event update
    );

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

    // --- Admin RS Functions ---

    // Fungsi registerAdminRS: Tambah Admin RS baru
    function registerAdminRS(
        address _admin,
        string calldata _namaRS,
        string calldata _alamatRS,
        string calldata _kotaRS,
        string calldata _IDRS // Parameter: IDRS
    ) external hanyaSuperAdmin {
        require(
            bytes(dataAdmin[_admin].namaRumahSakit).length == 0,
            "Admin RS sudah terdaftar dengan alamat ini."
        );
        require(bytes(_namaRS).length > 0, "Nama Rumah Sakit tidak boleh kosong.");
        require(bytes(_IDRS).length > 0, "IDRS tidak boleh kosong.");
        require(!isIDRSUsed[_IDRS], "IDRS sudah digunakan oleh Admin RS lain.");

        dataAdmin[_admin] = AdminRS({
            namaRumahSakit: _namaRS,
            aktif: true,
            alamatRumahSakit: _alamatRS,
            kota: _kotaRS,
            IDRS: _IDRS
        });
        daftarAdmin.push(_admin);
        isIDRSUsed[_IDRS] = true;

        emit AdminRSTerdaftar(_admin, _namaRS, _alamatRS, _kotaRS, _IDRS);
    }

    // Fungsi updateAdminRSDetails: Update detail informasi Admin RS (oleh Super Admin)
    function updateAdminRSDetails(
        address _admin,
        string calldata _namaBaru,
        string calldata _alamatBaru,
        string calldata _kotaBaru,
        string calldata _IDRSBaru // Parameter: IDRS baru
    ) external hanyaSuperAdmin {
        require(bytes(dataAdmin[_admin].namaRumahSakit).length != 0, "Admin RS tidak ditemukan.");
        require(bytes(_namaBaru).length > 0, "Nama Rumah Sakit baru tidak boleh kosong.");
        require(bytes(_IDRSBaru).length > 0, "IDRS baru tidak boleh kosong.");
        
        // Cek jika IDRS berubah
        if (keccak256(abi.encodePacked(dataAdmin[_admin].IDRS)) != keccak256(abi.encodePacked(_IDRSBaru))) {
            require(!isIDRSUsed[_IDRSBaru], "IDRS baru sudah digunakan oleh Admin RS lain.");
            if (bytes(dataAdmin[_admin].IDRS).length > 0) {
                 isIDRSUsed[dataAdmin[_admin].IDRS] = false; 
            }
            isIDRSUsed[_IDRSBaru] = true;
        }


        AdminRS storage adminToUpdate = dataAdmin[_admin];
        adminToUpdate.namaRumahSakit = _namaBaru;
        adminToUpdate.alamatRumahSakit = _alamatBaru;
        adminToUpdate.kota = _kotaBaru;
        adminToUpdate.IDRS = _IDRSBaru;

        emit AdminRSInfoDiperbarui(_admin, _namaBaru, _alamatBaru, _kotaBaru, _IDRSBaru);
    }


    // Fungsi setStatusAdminRS: Mengubah status aktif/non-aktif Admin RS (oleh Super Admin)
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

    function getAllAdminRSAddresses() external view returns (address[] memory) {
        return daftarAdmin;
    }

    function totalAdmin() external view returns (uint) {
        return daftarAdmin.length;
    }

    function getAdminByIndex(uint idx) external view returns (address) {
        require(idx < daftarAdmin.length, "Indeks admin RS tidak valid.");
        return daftarAdmin[idx];
    }

    // Fungsi getAdminRS: Mengambil semua detail Admin RS
    function getAdminRS(
        address _admin
    )
        external
        view
        returns (
            string memory namaRumahSakit,
            bool aktif,
            string memory alamatRumahSakit,
            string memory kota,
            string memory IDRS
        )
    {
        require(bytes(dataAdmin[_admin].namaRumahSakit).length > 0, "Admin RS tidak ditemukan.");
        AdminRS storage adminData = dataAdmin[_admin];
        return (
            adminData.namaRumahSakit,
            adminData.aktif,
            adminData.alamatRumahSakit,
            adminData.kota,
            adminData.IDRS
        );
    }

    // --- Dokter Functions ---
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
        address[] storage listPasienDitugaskan = dataDokter[
            _dokter
        ].assignedPasien;
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
        address[] storage listPasienDitugaskan = dataDokter[
            _dokter
        ].assignedPasien;
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
    function tambahRekamMedis(
        address _pasien,
        string calldata _diagnosa,
        string calldata _foto,
        string calldata _catatan,
        string calldata _tipeRekamMedis
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

    // --- Super Admin Functions ---
    function setSuperAdmin(address _newAdmin) external hanyaSuperAdmin {
        require(
            _newAdmin != address(0),
            "Alamat super admin baru tidak valid."
        );
        superAdmin = _newAdmin;
    }

    // MODIFIKASI: Fungsi getUserRole untuk AdminRS dan Dokter non-aktif
    function getUserRole(address _user) public view returns (string memory) {
        if (_user == superAdmin) return "SuperAdmin";
        
        // Cek apakah user adalah AdminRS TERDAFTAR terlebih dahulu
        if (bytes(dataAdmin[_user].namaRumahSakit).length > 0) {
            if (dataAdmin[_user].aktif) {
                return "AdminRS"; // Admin RS Aktif
            } else {
                return "InactiveAdminRS"; // Admin RS Terdaftar tapi Non-aktif
            }
        }
        
        // Cek apakah user adalah Dokter TERDAFTAR
        if (isDokter[_user]) { 
            if (dataDokter[_user].aktif) {
                return "Dokter"; // Dokter Aktif
            } else {
                return "InactiveDokter"; // Dokter Terdaftar tapi Non-aktif
            }
        }
        
        // Kemudian cek role Pasien (Pasien dianggap selalu 'aktif' untuk validitas loginnya)
        if (isPasien[_user]) return "Pasien";
        
        return "Unknown"; // Role tidak dikenal
    }
}