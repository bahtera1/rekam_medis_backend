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

    struct Pasien {
        string nama;
        uint umur;
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

    struct UpdateInfo {
        address dokter; // alamat dokter yang update
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
    event PasienTerdaftar(address indexed pasien, string nama, address adminRS);
    event PasienPindahRS(address indexed pasien, address adminRS);
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
        address dokter,
        uint timestamp
    );
    event DokterInfoDiperbarui(
        address indexed dokter,
        string nama,
        string spesialisasi,
        string nomorLisensi,
        address indexed adminRS
    );

    constructor() {
        superAdmin = 0xB0dC0Bf642d339517438017Fc185Bb0f758A01D2;
    }

    // Modifier
    modifier hanyaSuperAdmin() {
        require(msg.sender == superAdmin, "Hanya super admin.");
        _;
    }

    modifier hanyaAdminRS() {
        require(dataAdmin[msg.sender].aktif, "Hanya admin RS aktif.");
        _;
    }

    modifier hanyaDokterAktif() {
        require(
            isDokter[msg.sender] && dataDokter[msg.sender].aktif,
            "Hanya dokter aktif."
        );
        _;
    }

    modifier hanyaDokterAktifUntukPasien(address _pasien) {
        require(
            isDokter[msg.sender] && dataDokter[msg.sender].aktif,
            "Hanya dokter aktif."
        );
        require(
            dataDokter[msg.sender].adminRS ==
                dataPasien[_pasien].rumahSakitPenanggungJawab,
            "Dokter & pasien beda RS"
        );
        bool assigned = false;
        address[] storage list = dataDokter[msg.sender].assignedPasien;
        for (uint i = 0; i < list.length; i++) {
            if (list[i] == _pasien) {
                assigned = true;
                break;
            }
        }
        require(assigned, "Dokter tidak diassign ke pasien ini.");
        _;
    }

    modifier hanyaPasien(address _pasien) {
        require(msg.sender == _pasien, "Hanya pasien.");
        _;
    }

    // Fungsi SuperAdmin mendaftarkan Admin RS baru
    function registerAdminRS(
        address _admin,
        string calldata _namaRS
    ) external hanyaSuperAdmin {
        require(
            bytes(dataAdmin[_admin].namaRumahSakit).length == 0,
            "Admin RS sudah terdaftar."
        );
        dataAdmin[_admin] = AdminRS({namaRumahSakit: _namaRS, aktif: true});
        daftarAdmin.push(_admin);
        emit AdminRSTerdaftar(_admin, _namaRS);
    }
    function getAllAdminRSAddresses() external view returns (address[] memory) {
        return daftarAdmin;
    }
    // SuperAdmin ubah status admin RS (aktif/nonaktif)
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

    // Ambil total admin RS
    function totalAdmin() external view returns (uint) {
        return daftarAdmin.length;
    }

    // Ambil admin RS by index
    function getAdminByIndex(uint idx) external view returns (address) {
        require(idx < daftarAdmin.length, "Index admin RS invalid.");
        return daftarAdmin[idx];
    }

    // Admin RS ubah status dokter
    function setStatusDokter(
        address _dokter,
        bool _aktif
    ) external hanyaAdminRS {
        require(isDokter[_dokter], "Dokter belum terdaftar.");
        require(
            dataDokter[_dokter].adminRS == msg.sender,
            "Dokter bukan milik RS anda."
        );
        dataDokter[_dokter].aktif = _aktif;
        emit DokterStatusDiubah(_dokter, _aktif);
    }

    // Ambil total dokter terdaftar (semua RS)
    function totalDokter() external view returns (uint) {
        return daftarDokter.length;
    }

    address[] public daftarDokter;

    // Admin RS mendaftarkan dokter baru dan simpan daftar
    function registerDokter(
        address _dokter,
        string calldata _nama,
        string calldata _spesialisasi,
        string calldata _nomorLisensi
    ) external hanyaAdminRS {
        require(!isDokter[_dokter], "Sudah dokter.");
        require(!isPasien[_dokter], "Alamat milik pasien.");
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

    // Ambil dokter by index
    function getDokterByIndex(uint idx) external view returns (address) {
        require(idx < daftarDokter.length, "Index invalid.");
        return daftarDokter[idx];
    }
    // Fungsi untuk Admin RS memperbarui informasi dokter
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

        // Pastikan nilai baru tidak kosong jika itu adalah kebijakan
        // Misalnya, jika nama tidak boleh kosong:
        // require(bytes(_namaBaru).length > 0, "Nama baru tidak boleh kosong.");

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
    // Ambil detail dokter
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

    // Admin RS mendaftarkan pasien baru
    function registerPasien(
        address _pasien,
        string calldata _nama,
        address _adminRS
    ) external hanyaAdminRS {
        require(!isPasien[_pasien], "Pasien sudah terdaftar.");
        require(!isDokter[_pasien], "Alamat milik dokter.");
        require(dataAdmin[_adminRS].aktif, "Admin RS tidak aktif.");
        isPasien[_pasien] = true;
        dataPasien[_pasien] = Pasien({
            nama: _nama,
            umur: 0,
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

    // Pasien bisa register sendiri (mandiri)
    function selfRegisterPasien(
        string calldata _nama,
        uint _umur,
        string calldata _golonganDarah,
        string calldata _tanggalLahir,
        string calldata _gender,
        string calldata _alamat,
        string calldata _noTelepon,
        string calldata _email,
        address _adminRS
    ) external {
        require(!isPasien[msg.sender], "Anda sudah pasien.");
        require(!isDokter[msg.sender], "Alamat milik dokter.");
        require(dataAdmin[_adminRS].aktif, "Admin RS tidak aktif.");
        isPasien[msg.sender] = true;
        dataPasien[msg.sender] = Pasien({
            nama: _nama,
            umur: _umur,
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

    // Ambil daftar pasien
    address[] public daftarPasien;

    function getDaftarPasien() external view returns (address[] memory) {
        return daftarPasien;
    }

    // Ambil detail pasien
    function getPasienData(
        address _pasien
    )
        external
        view
        returns (
            string memory nama,
            uint umur,
            string memory golonganDarah,
            string memory tanggalLahir,
            string memory gender,
            string memory alamat,
            string memory noTelepon,
            string memory email,
            address rumahSakitPenanggungJawab
        )
    {
        if (!isPasien[_pasien]) {
            return ("", 0, "", "", "", "", "", "", address(0));
        }
        Pasien storage p = dataPasien[_pasien];
        return (
            p.nama,
            p.umur,
            p.golonganDarah,
            p.tanggalLahir,
            p.gender,
            p.alamat,
            p.noTelepon,
            p.email,
            p.rumahSakitPenanggungJawab
        );
    }

    // Admin RS assign pasien ke dokter
    function assignPasienToDokter(
        address _dokter,
        address _pasien
    ) external hanyaAdminRS {
        require(isDokter[_dokter], "Dokter belum terdaftar.");
        require(isPasien[_pasien], "Pasien belum terdaftar.");
        require(
            dataDokter[_dokter].adminRS == msg.sender,
            "Dokter bukan milik RS anda."
        );
        require(
            dataPasien[_pasien].rumahSakitPenanggungJawab == msg.sender,
            "Pasien bukan milik RS anda."
        );

        address[] storage list = dataDokter[_dokter].assignedPasien;
        for (uint i = 0; i < list.length; i++) {
            require(list[i] != _pasien, "Pasien sudah diassign.");
        }
        list.push(_pasien);
        emit PasienDiassignKeDokter(_dokter, _pasien);
    }

    // Tambah rekam medis (oleh pasien sendiri atau dokter aktif RS pasien)
    function tambahRekamMedis(
        address _pasien,
        string calldata _diagnosa,
        string calldata _foto,
        string calldata _catatan
    ) external {
        bool isValidActor = false;
        if (msg.sender == _pasien) {
            isValidActor = true;
        } else if (isDokter[msg.sender]) {
            if (
                dataDokter[msg.sender].adminRS ==
                dataPasien[_pasien].rumahSakitPenanggungJawab
            ) {
                if (isAssigned(msg.sender, _pasien)) {
                    isValidActor = true;
                }
            }
        }
        require(isValidActor, "Tidak berhak.");
        require(isPasien[_pasien], "Pasien tidak terdaftar.");

        rekamMedisCount++;
        rekamMedis[rekamMedisCount] = RekamMedisData({
            id: rekamMedisCount,
            pasien: _pasien,
            diagnosa: _diagnosa,
            foto: _foto,
            catatan: _catatan,
            valid: true
        });
        rekamMedisByPasien[_pasien].push(rekamMedisCount);
        emit RekamMedisDitambahkan(rekamMedisCount, _pasien, _diagnosa, true);
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

    function updateRekamMedis(
        uint _id,
        string calldata _diagnosa,
        string calldata _foto,
        string calldata _catatan
    ) external hanyaDokterAktifUntukPasien(rekamMedis[_id].pasien) {
        RekamMedisData storage r = rekamMedis[_id];
        rekamMedisVersions[_id].push(r);

        r.diagnosa = _diagnosa;
        r.foto = _foto;
        r.catatan = _catatan;

        // Simpan info update
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

    // Ambil rekam medis by pasien
    function getRekamMedisIdsByPasien(
        address _pasien
    ) external view returns (uint[] memory) {
        return rekamMedisByPasien[_pasien];
    }

    // Ambil detail rekam medis
    function getRekamMedis(
        uint _id
    )
        external
        view
        returns (
            address pasien,
            string memory diagnosa,
            string memory foto,
            string memory catatan,
            bool valid
        )
    {
        RekamMedisData storage r = rekamMedis[_id];
        return (r.pasien, r.diagnosa, r.foto, r.catatan, r.valid);
    }

    // Ambil versi rekam medis
    function getRekamMedisVersions(
        uint _id
    ) external view returns (RekamMedisData[] memory) {
        return rekamMedisVersions[_id];
    }
    function getRekamMedisUpdateHistory(
        uint _id
    ) external view returns (address[] memory, uint256[] memory) {
        uint len = rekamMedisUpdateHistory[_id].length;
        address[] memory dokters = new address[](len);
        uint256[] memory times = new uint256[](len);
        for (uint i = 0; i < len; i++) {
            dokters[i] = rekamMedisUpdateHistory[_id][i].dokter;
            times[i] = rekamMedisUpdateHistory[_id][i].timestamp;
        }
        return (dokters, times);
    }

    // Nonaktifkan rekam medis (admin RS saja)
    function nonaktifkanRekamMedis(uint _id) external hanyaAdminRS {
        rekamMedis[_id].valid = false;
    }

    // Ganti superAdmin
    function setSuperAdmin(address _newAdmin) external hanyaSuperAdmin {
        superAdmin = _newAdmin;
    }

    // Ambil role user
    function getUserRole(address _user) public view returns (string memory) {
        if (_user == superAdmin) return "SuperAdmin";
        if (dataAdmin[_user].aktif) return "AdminRS";
        if (isDokter[_user]) return "Dokter";
        if (isPasien[_user]) return "Pasien";
        return "Unknown";
    }
}
