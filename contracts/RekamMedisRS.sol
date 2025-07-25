// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract RekamMedisRS {
    struct AdminRS {
        string namaRumahSakit;
        bool aktif;
        string alamatRumahSakit;
        string kota;
        string NIBRS;
    }
    mapping(address => AdminRS) public dataAdmin;
    mapping(string => bool) public isNIBRSUsed;
    address[] public daftarAdmin;

    struct Dokter {
        string nama;
        string spesialisasi;
        string nomorLisensi;
        bool aktif;
        address[] assignedPasien;
        address adminRS;
    }
    mapping(address => Dokter) public dataDokter;
    mapping(address => bool) public isDokter;
    address[] public daftarDokter;

    struct Pasien {
        string nama;
        string ID;
        string NIK;
        string golonganDarah;
        string tanggalLahir;
        string gender;
        string alamat;
        string noTelepon;
        string email;
        address rumahSakitPenanggungJawab;
    }
    mapping(address => Pasien) public dataPasien;
    mapping(address => bool) public isPasien;
    mapping(string => bool) public isPatientIDUsed;
    mapping(string => bool) public isPatientNIKUsed;
    address[] public daftarPasien;

    struct RekamMedisData {
        uint id;
        address pasien;
        string diagnosa;
        string foto;
        string catatan;
        address pembuat;
        uint256 timestampPembuatan;
        string tipeRekamMedis;
    }
    mapping(uint => RekamMedisData) public rekamMedis;
    mapping(address => uint[]) public rekamMedisByPasien;
    uint public rekamMedisCount;

    event AdminRSTerdaftar(
        address indexed admin,
        string namaRumahSakit,
        string alamatRumahSakit,
        string kota,
        string NIBRS
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
    event PasienTerdaftar(
        address indexed pasien,
        string nama,
        string IDPasien,
        string NIKPasien,
        address adminRS
    );
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
        uint timestamp
    );

    event PasienDataDiperbarui(
        address indexed pasien,
        string nama,
        string NIK,
        string golonganDarah,
        string tanggalLahir,
        string gender,
        string alamat,
        string noTelepon,
        string email
    );

    constructor() {
        // Tambahkan Admin RS pertama
        address admin1 = 0xDf953fA75aEB06ee7D182f52b58521a9524E077B;
        string memory namaRS1 = "RS Siloam Malang";
        string memory alamatRS1 = "Jl. Raya Langsep No. 2, Malang";
        string memory kotaRS1 = "Malang";
        string memory NIBRS1 = "NIBRS-SM001";

        dataAdmin[admin1] = AdminRS({
            namaRumahSakit: namaRS1,
            aktif: true,
            alamatRumahSakit: alamatRS1,
            kota: kotaRS1,
            NIBRS: NIBRS1
        });
        daftarAdmin.push(admin1);
        isNIBRSUsed[NIBRS1] = true;
        emit AdminRSTerdaftar(admin1, namaRS1, alamatRS1, kotaRS1, NIBRS1);

        // Tambahkan Admin RS kedua
        address admin2 = 0x65846ad493b8aE8A5991704fd5d4c89cF1Ec4eA2;
        string memory namaRS2 = "RS Siloam Yogya";
        string memory alamatRS2 = "Jl. Laksda Adisucipto No. 32, Yogyakarta";
        string memory kotaRS2 = "Yogyakarta";
        string memory NIBRS2 = "NIBRS-SY001";

        dataAdmin[admin2] = AdminRS({
            namaRumahSakit: namaRS2,
            aktif: true,
            alamatRumahSakit: alamatRS2,
            kota: kotaRS2,
            NIBRS: NIBRS2
        });
        daftarAdmin.push(admin2);
        isNIBRSUsed[NIBRS2] = true;
        emit AdminRSTerdaftar(admin2, namaRS2, alamatRS2, kotaRS2, NIBRS2);
    }

    modifier hanyaAdminRS() {
        require(
            bytes(dataAdmin[msg.sender].namaRumahSakit).length > 0 &&
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
        require(isPasien[_pasien], "Pasien tidak terdaftar.");
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
            string memory NIBRS
        )
    {
        require(
            bytes(dataAdmin[_admin].namaRumahSakit).length > 0,
            "Admin RS tidak ditemukan."
        );
        AdminRS storage adminData = dataAdmin[_admin];
        return (
            adminData.namaRumahSakit,
            adminData.aktif,
            adminData.alamatRumahSakit,
            adminData.kota,
            adminData.NIBRS
        );
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

    function getAssignedPatients(
        address _dokter
    ) external view returns (address[] memory) {
        require(isDokter[_dokter], "Dokter tidak ditemukan.");
        return dataDokter[_dokter].assignedPasien;
    }

    function selfRegisterPasien(
        string calldata _nama,
        string calldata _IDPasien,
        string calldata _NIKPasien,
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
        require(bytes(_IDPasien).length > 0, "ID Pasien tidak boleh kosong.");
        require(!isPatientIDUsed[_IDPasien], "ID Pasien sudah digunakan.");
        require(bytes(_NIKPasien).length > 0, "NIK Pasien tidak boleh kosong.");
        require(!isPatientNIKUsed[_NIKPasien], "NIK Pasien sudah digunakan.");
        require(
            dataAdmin[_adminRS].aktif,
            "Rumah Sakit yang dipilih tidak aktif atau tidak valid."
        );

        isPasien[msg.sender] = true;
        dataPasien[msg.sender] = Pasien({
            nama: _nama,
            ID: _IDPasien,
            NIK: _NIKPasien,
            golonganDarah: _golonganDarah,
            tanggalLahir: _tanggalLahir,
            gender: _gender,
            alamat: _alamat,
            noTelepon: _noTelepon,
            email: _email,
            rumahSakitPenanggungJawab: _adminRS
        });
        daftarPasien.push(msg.sender);
        isPatientIDUsed[_IDPasien] = true;
        isPatientNIKUsed[_NIKPasien] = true;
        emit PasienTerdaftar(
            msg.sender,
            _nama,
            _IDPasien,
            _NIKPasien,
            _adminRS
        );
    }

    function updatePasienData(
        string calldata _nama,
        string calldata _NIK,
        string calldata _golonganDarah,
        string calldata _tanggalLahir,
        string calldata _gender,
        string calldata _alamat,
        string calldata _noTelepon,
        string calldata _email
    ) external hanyaPasien(msg.sender) {
        require(isPasien[msg.sender], "Pasien tidak ditemukan.");

        // Validasi NIK baru jika ada perubahan
        if (
            keccak256(abi.encodePacked(dataPasien[msg.sender].NIK)) !=
            keccak256(abi.encodePacked(_NIK))
        ) {
            require(bytes(_NIK).length > 0, "NIK Pasien tidak boleh kosong.");
            require(
                !isPatientNIKUsed[_NIK],
                "NIK baru sudah digunakan oleh pasien lain."
            );
            // Nonaktifkan NIK lama (jika ada) dan aktifkan NIK baru
            if (bytes(dataPasien[msg.sender].NIK).length > 0) {
                isPatientNIKUsed[dataPasien[msg.sender].NIK] = false;
            }
            isPatientNIKUsed[_NIK] = true;
        }

        Pasien storage pasienToUpdate = dataPasien[msg.sender];
        pasienToUpdate.nama = _nama;
        pasienToUpdate.NIK = _NIK;
        pasienToUpdate.golonganDarah = _golonganDarah;
        pasienToUpdate.tanggalLahir = _tanggalLahir;
        pasienToUpdate.gender = _gender;
        pasienToUpdate.alamat = _alamat;
        pasienToUpdate.noTelepon = _noTelepon;
        pasienToUpdate.email = _email;

        emit PasienDataDiperbarui(
            msg.sender,
            _nama,
            _NIK,
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
        require(isPasien[msg.sender], "Pasien tidak ditemukan.");
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

    function totalPasien() public view returns (uint) {
        return daftarPasien.length;
    }

    function getPasienData(
        address _pasien
    )
        external
        view
        returns (
            string memory nama,
            string memory ID,
            string memory NIK,
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
            p.ID,
            p.NIK,
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
            (dataPasien[_pasien].rumahSakitPenanggungJawab == msg.sender ||
                dataPasien[_pasien].rumahSakitPenanggungJawab == address(0)),
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

    function tambahRekamMedis(
        address _pasien,
        string calldata _diagnosa,
        string calldata _foto,
        string calldata _catatan,
        string calldata _tipeRekamMedis
    ) external {
        // Hanya dokter aktif yang ditugaskan ke pasien yang dapat menambah rekam medis
        require(
            isDokter[msg.sender] && dataDokter[msg.sender].aktif,
            "Hanya dokter aktif yang dapat menambah rekam medis."
        );
        require(isPasien[_pasien], "Pasien tidak terdaftar.");
        require(
            dataDokter[msg.sender].adminRS ==
                dataPasien[_pasien].rumahSakitPenanggungJawab,
            "Dokter dan pasien tidak berada di rumah sakit yang sama."
        );
        require(
            isAssigned(msg.sender, _pasien),
            "Dokter ini tidak ditugaskan untuk menangani pasien tersebut."
        );

        rekamMedisCount++;
        uint newId = rekamMedisCount;
        rekamMedis[newId] = RekamMedisData({
            id: newId,
            pasien: _pasien,
            diagnosa: _diagnosa,
            foto: _foto,
            catatan: _catatan,
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
            r.pembuat,
            r.timestampPembuatan,
            r.tipeRekamMedis
        );
    }

    function getRekamMedisByPasienUntukAdminRS(
        address _pasien
    ) external view hanyaAdminRS returns (RekamMedisData[] memory) {
        // 1. Verifikasi Berewenang
        // Memastikan AdminRS yang memanggil fungsi ini adalah RS penanggung jawab pasien.
        require(
            dataPasien[_pasien].rumahSakitPenanggungJawab == msg.sender,
            "Anda tidak berhak melihat rekam medis pasien ini."
        );

        // 2. Ambil ID Rekam Medis
        // Mengambil semua ID rekam medis yang dimiliki oleh pasien.
        uint[] storage recordIds = rekamMedisByPasien[_pasien];

        // 3. Siapkan Array untuk Hasil
        // Membuat array di memori untuk menampung data rekam medis lengkap.
        RekamMedisData[] memory records = new RekamMedisData[](
            recordIds.length
        );

        for (uint i = 0; i < recordIds.length; i++) {
            records[i] = rekamMedis[recordIds[i]];
        }

        return records;
    }

    function getUserRole(address _user) public view returns (string memory) {
        if (bytes(dataAdmin[_user].namaRumahSakit).length > 0) {
            if (dataAdmin[_user].aktif) {
                return "AdminRS";
            } else {
                return "InactiveAdminRS";
            }
        }

        if (isDokter[_user]) {
            if (dataDokter[_user].aktif) {
                return "Dokter";
            } else {
                return "InactiveDokter";
            }
        }

        if (isPasien[_user]) return "Pasien";

        return "Unknown";
    }

    function getPasienByAdminRS()
        external
        view
        hanyaAdminRS
        returns (address[] memory)
    {
        address[] memory pasienDiRS;
        uint count = 0;
        for (uint i = 0; i < daftarPasien.length; i++) {
            if (
                dataPasien[daftarPasien[i]].rumahSakitPenanggungJawab ==
                msg.sender
            ) {
                count++;
            }
        }

        pasienDiRS = new address[](count);
        uint currentIndex = 0;
        for (uint i = 0; i < daftarPasien.length; i++) {
            if (
                dataPasien[daftarPasien[i]].rumahSakitPenanggungJawab ==
                msg.sender
            ) {
                pasienDiRS[currentIndex] = daftarPasien[i];
                currentIndex++;
            }
        }
        return pasienDiRS;
    }
}
