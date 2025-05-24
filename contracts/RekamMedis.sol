// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract RekamMedis {
    address public admin;

    struct Dokter {
        string nama;
        string spesialisasi;
        string nomorLisensi;
        bool aktif;
        address[] assignedPasien;
    }

    struct Pasien {
        string nama;
        uint umur;
        string golonganDarah;
        string tanggalLahir;
        string gender;
        string alamat;
        string noTelepon;
        string email;
        bool exists;
    }

    struct RekamMedisData {
        uint id;
        address pasien;
        string diagnosa;
        string foto;
        string catatan;
        bool valid;
    }

    mapping(address => Dokter) public dataDokter;
    mapping(address => bool) public isDokter;

    mapping(address => Pasien) public dataPasien;
    mapping(address => bool) public isPasien;

    mapping(uint => RekamMedisData) public rekamMedis;
    mapping(address => uint[]) public rekamMedisByPasien;

    address[] public daftarDokter;
    address[] public daftarPasien;
    uint public rekamMedisCount;

    // history versions
    mapping(uint => RekamMedisData[]) public rekamMedisVersions;

    // Events
    event AdminDitetapkan(address newAdmin);
    event DokterTerdaftar(
        address dokter,
        string nama,
        string spesialisasi,
        string nomorLisensi
    );
    event DokterStatusDiubah(address dokter, bool aktif);
    event PasienTerdaftar(address pasien, string nama);
    event PasienDiassignKeDokter(address dokter, address pasien);
    event RekamMedisDitambahkan(
        uint id,
        address pasien,
        string diagnosa,
        bool valid
    );
    event RekamMedisDiperbarui(uint id, string diagnosa, string catatan);

    constructor() {
        admin = msg.sender;
    }

    modifier hanyaAdmin() {
        require(msg.sender == admin, "Hanya admin.");
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

    // Ambil role user
    function getUserRole(address _user) public view returns (string memory) {
        if (_user == admin) return "Admin";
        if (isDokter[_user]) return "Dokter";
        if (isPasien[_user]) return "Pasien";
        return "Unknown";
    }

    // --- Dokter management ---
    function registerDokter(
        address _dokter,
        string calldata _nama,
        string calldata _spesialisasi,
        string calldata _nomorLisensi
    ) external hanyaAdmin {
        require(!isDokter[_dokter], "Sudah dokter.");
        require(!isPasien[_dokter], "Alamat milik pasien.");
        isDokter[_dokter] = true;
        dataDokter[_dokter] = Dokter({
            nama: _nama,
            spesialisasi: _spesialisasi,
            nomorLisensi: _nomorLisensi,
            aktif: true,
            assignedPasien: new address[](0)
        });
        daftarDokter.push(_dokter);
        emit DokterTerdaftar(_dokter, _nama, _spesialisasi, _nomorLisensi);
    }

    function totalDokter() external view returns (uint) {
        return daftarDokter.length;
    }

    function getDokterByIndex(uint idx) external view returns (address) {
        require(idx < daftarDokter.length, "Index invalid.");
        return daftarDokter[idx];
    }

    function setStatusDokter(address _dokter, bool _aktif) external hanyaAdmin {
        require(isDokter[_dokter], "Dokter belum terdaftar.");
        dataDokter[_dokter].aktif = _aktif;
        emit DokterStatusDiubah(_dokter, _aktif);
    }

    function updateDataDokter(
        address _dokter,
        string calldata _nama,
        string calldata _spesialisasi,
        string calldata _nomorLisensi
    ) external hanyaAdmin {
        require(isDokter[_dokter], "Dokter belum terdaftar.");
        dataDokter[_dokter].nama = _nama;
        dataDokter[_dokter].spesialisasi = _spesialisasi;
        dataDokter[_dokter].nomorLisensi = _nomorLisensi;
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
            address[] memory pasienList
        )
    {
        Dokter storage d = dataDokter[_dokter];
        return (
            d.nama,
            d.spesialisasi,
            d.nomorLisensi,
            d.aktif,
            d.assignedPasien
        );
    }

    // --- Pasien management ---
    function registerPasien(
        address _pasien,
        string calldata _nama
    ) external hanyaAdmin {
        require(!isPasien[_pasien], "Pasien sudah terdaftar.");
        require(!isDokter[_pasien], "Alamat milik dokter.");
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
            exists: true
        });
        daftarPasien.push(_pasien);
        emit PasienTerdaftar(_pasien, _nama);
    }

    function selfRegisterPasien(
        string calldata _nama,
        uint _umur,
        string calldata _golonganDarah,
        string calldata _tanggalLahir,
        string calldata _gender,
        string calldata _alamat,
        string calldata _noTelepon,
        string calldata _email
    ) external {
        require(!isPasien[msg.sender], "Anda sudah pasien.");
        require(!isDokter[msg.sender], "Alamat milik dokter.");
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
            exists: true
        });
        daftarPasien.push(msg.sender);
        emit PasienTerdaftar(msg.sender, _nama);
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
            uint umur,
            string memory golonganDarah,
            string memory tanggalLahir,
            string memory gender,
            string memory alamat,
            string memory noTelepon,
            string memory email
        )
    {
        if (!isPasien[_pasien]) {
            // Kembalikan nilai kosong jika pasien belum terdaftar
            return ("", 0, "", "", "", "", "", "");
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
            p.email
        );
    }

    // --- Assignment ---
    function assignPasienToDokter(
        address _dokter,
        address _pasien
    ) external hanyaAdmin {
        require(isDokter[_dokter], "Dokter belum terdaftar.");
        require(isPasien[_pasien], "Pasien belum terdaftar.");
        address[] storage list = dataDokter[_dokter].assignedPasien;
        for (uint i = 0; i < list.length; i++) {
            require(list[i] != _pasien, "Sudah diassign.");
        }
        list.push(_pasien);
        emit PasienDiassignKeDokter(_dokter, _pasien);
    }

    function getAssignedPasienByDokter(
        address _dokter
    ) external view returns (address[] memory) {
        require(isDokter[_dokter], "Dokter belum terdaftar.");
        return dataDokter[_dokter].assignedPasien;
    }

    // --- Rekam Medis ---
    // Update fungsi tambahRekamMedis agar bisa dipanggil oleh pasien sendiri atau dokter aktif yg diassign ke pasien tersebut
    function tambahRekamMedis(
        address _pasien,
        string calldata _diagnosa,
        string calldata _foto,
        string calldata _catatan
    ) external {
        require(
            (msg.sender == _pasien) ||
                (isDokter[msg.sender] &&
                    dataDokter[msg.sender].aktif &&
                    isPasien[_pasien] &&
                    isAssigned(msg.sender, _pasien)),
            "Hanya pasien sendiri atau dokter aktif yang diassign ke pasien."
        );
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

    // Fungsi helper untuk cek apakah dokter diassign ke pasien
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
        emit RekamMedisDiperbarui(_id, _diagnosa, _catatan);
    }

    function getRekamMedisIdsByPasien(
        address _pasien
    ) external view returns (uint[] memory) {
        return rekamMedisByPasien[_pasien];
    }

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

    function getRekamMedisVersions(
        uint _id
    ) external view returns (RekamMedisData[] memory) {
        return rekamMedisVersions[_id];
    }

    function nonaktifkanRekamMedis(uint _id) external hanyaAdmin {
        rekamMedis[_id].valid = false;
    }

    function setAdmin(address _newAdmin) external hanyaAdmin {
        admin = _newAdmin;
        emit AdminDitetapkan(_newAdmin);
    }
}
