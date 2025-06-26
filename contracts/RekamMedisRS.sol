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

    // Struct untuk menyimpan info update/pembuatan
    struct UpdateInfo {
        address aktor; // Alamat aktor yang melakukan update/pembuatan (bisa dokter atau pasien)
        uint256 timestamp; // Waktu update/pembuatan (block.timestamp)
    }

    // struct RekamMedisData dengan tambahan pembuat dan waktu pembuatan awal
    struct RekamMedisData {
        uint id;
        address pasien;
        string diagnosa;
        string foto;
        string catatan;
        bool valid;
        address pembuatAwal; // BARU: Alamat pembuat rekam medis pertama kali
        uint256 timestampAwal; // BARU: Timestamp pembuatan rekam medis pertama kali
    }

    // REVISI Kecil di Smart Contract (Opsional tapi bisa membuat Frontend lebih mudah)
    // Tidak mengubah RekamMedisData struct atau fungsi tambah/update utama
    // Tujuan: Membuat fungsi view yang mengembalikan histori lengkap per Rekam Medis ID

    // Tambahkan struct untuk riwayat RM yang lebih komprehensif
    struct FullRMHistoryEntry {
        uint id_rm;
        uint versiKe;
        string diagnosa;
        string foto;
        string catatan;
        bool valid;
        address aktor; // Pembuat/pengupdate
        uint256 timestamp; // Waktu perubahan
        string jenisPerubahan; // "Creation" atau "Update"
    }

    function getFullRekamMedisHistory(
        uint _id
    ) external view returns (FullRMHistoryEntry[] memory) {
        require(
            rekamMedis[_id].pasien != address(0),
            "Rekam medis tidak ditemukan."
        );

        RekamMedisData storage currentRM = rekamMedis[_id];
        RekamMedisData[] storage historicalVersions = rekamMedisVersions[_id];
        UpdateInfo[] storage updateEvents = rekamMedisUpdateHistory[_id]; // ini hanya update events

        // Hitung total entri: 1 (creation) + jumlah historical versions
        uint totalEntries = 1 + historicalVersions.length;
        FullRMHistoryEntry[] memory history = new FullRMHistoryEntry[](
            totalEntries
        );

        uint counter = 0;

        // Tambahkan entri pembuatan awal
        history[counter] = FullRMHistoryEntry({
            id_rm: currentRM.id,
            versiKe: 0, // Akan diisi di frontend setelah sort
            diagnosa: currentRM.diagnosa,
            foto: currentRM.foto,
            catatan: currentRM.catatan,
            valid: currentRM.valid,
            aktor: currentRM.pembuatAwal,
            timestamp: currentRM.timestampAwal,
            jenisPerubahan: "Creation"
        });
        counter++;

        // Tambahkan entri untuk setiap versi historis
        // Setiap `historicalVersions[i]` adalah snapshot *sebelum* `updateEvents[i]` terjadi.
        // Jadi, kita ingin menampilkan `historicalVersions[i]` sebagai versi yang *diubah* oleh `updateEvents[i]`.
        for (uint i = 0; i < historicalVersions.length; i++) {
            // Asumsi updateEvents[i] cocok dengan historicalVersions[i] yang di-snapshot sebelumnya
            UpdateInfo memory currentUpdateInfo = updateEvents[i]; // Info aktor/timestamp dari event update

            history[counter] = FullRMHistoryEntry({
                id_rm: historicalVersions[i].id,
                versiKe: 0, // Akan diisi di frontend
                diagnosa: historicalVersions[i].diagnosa,
                foto: historicalVersions[i].foto,
                catatan: historicalVersions[i].catatan,
                valid: historicalVersions[i].valid,
                aktor: currentUpdateInfo.aktor,
                timestamp: currentUpdateInfo.timestamp,
                jenisPerubahan: "Update"
            });
            counter++;
        }

        // Perhatikan: Data 'currentRM' (versi paling baru) tidak secara eksplisit di return di sini sebagai versi terakhir
        // karena historicalVersions hanya menyimpan versi LAMA.
        // Jika Anda ingin versi TERBARU (currentRM) juga muncul di sini dengan info update terakhirnya,
        // maka perlu penyesuaian di `updateRekamMedis` untuk menyimpan CURRENT state ke history,
        // atau di frontend menangani currentRM secara terpisah seperti sebelumnya.
        // Untuk kesederhanaan, kita akan teruskan data terbaru (currentRM) dari getRekamMedis di frontend.

        return history;
    }
    mapping(uint => RekamMedisData) public rekamMedis;
    mapping(address => uint[]) public rekamMedisByPasien;
    uint public rekamMedisCount;

    // History versi rekam medis (snapshot data RM sebelum update)
    mapping(uint => RekamMedisData[]) public rekamMedisVersions; // Akan menyimpan snapshot lengkap, termasuk pembuatAwal/timestampAwal

    // History update rekam medis (siapa dan kapan dilakukan update, TIDAK termasuk pembuatan awal)
    mapping(uint => UpdateInfo[]) public rekamMedisUpdateHistory;

    // Events
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
    event PasienDiunassignDariDokter(address dokter, address pasien); // Pastikan ini juga ada
    event RekamMedisDitambahkan(
        uint id,
        address pasien,
        string diagnosa,
        address pembuat, // Tambahkan pembuat dan waktu pembuatan ke event ini
        uint timestamp,
        bool valid
    );
    event RekamMedisDiperbarui(
        uint id,
        string diagnosa,
        string catatan,
        address updater, // Aktor yang memperbarui
        uint timestamp
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
        superAdmin = 0xB0dC0Bf642d339517438017Fc185Bb0f758A01D2; // Ganti dengan alamat super admin Anda
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

    // Fungsi untuk mendapatkan nama RS dari alamat AdminRS
    function getNamaRumahSakitByAdmin(
        address _adminRS
    ) external view returns (string memory) {
        require(
            dataAdmin[_adminRS].aktif,
            "Admin RS tidak ditemukan atau tidak aktif."
        );
        return dataAdmin[_adminRS].namaRumahSakit;
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
            adminRS: msg.sender // Admin RS yang mendaftarkan
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
            address adminRS // Alamat Admin RS dokter
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
        address _adminRS // Alamat Admin RS yang mendaftarkan
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
            rumahSakitPenanggungJawab: _adminRS, // Set RS penanggung jawab saat pendaftaran
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

        // AdminRS hanya bisa mengassign pasien yang rumahSakitPenanggungJawab-nya adalah dirinya sendiri
        // atau pasien yang belum memiliki RS penanggung jawab (address(0))
        require(
            dataPasien[_pasien].rumahSakitPenanggungJawab == msg.sender ||
                dataPasien[_pasien].rumahSakitPenanggungJawab == address(0),
            "Pasien ini tidak terdaftar di rumah sakit Anda atau sudah di-assign ke RS lain."
        );

        // Jika pasien self-register dan belum punya RS penanggung jawab, set RS penanggung jawabnya ke RS Admin ini
        if (dataPasien[_pasien].rumahSakitPenanggungJawab == address(0)) {
            dataPasien[_pasien].rumahSakitPenanggungJawab = msg.sender;
            // No explicit event for this, as PasienTerdaftar covers initial RS assignment.
            // If you need to log this specific change when admin assigns, you can emit PasienPindahRS here
            // emit PasienPindahRS(_pasien, address(0), msg.sender);
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
    function tambahRekamMedis(
        address _pasien,
        string calldata _diagnosa,
        string calldata _foto,
        string calldata _catatan
    ) external {
        bool isValidActor = false;
        if (msg.sender == _pasien && isPasien[_pasien]) {
            isValidActor = true; // Pasien bisa menambah RM sendiri
        } else if (isDokter[msg.sender] && dataDokter[msg.sender].aktif) {
            if (
                dataPasien[_pasien].exists &&
                dataDokter[msg.sender].adminRS ==
                dataPasien[_pasien].rumahSakitPenanggungJawab &&
                isAssigned(msg.sender, _pasien)
            ) {
                isValidActor = true; // Dokter yang ditugaskan bisa menambah RM
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
            pembuatAwal: msg.sender, // BARU
            timestampAwal: block.timestamp // BARU
        });
        rekamMedisByPasien[_pasien].push(newId);

        // rekamMedisUpdateHistory TIDAK digunakan untuk pembuatan awal
        emit RekamMedisDitambahkan(
            newId,
            _pasien,
            _diagnosa,
            msg.sender,
            block.timestamp,
            true
        ); // Update Event
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
        );
        require(r.valid, "Rekam medis ini sudah tidak valid/dinonaktifkan.");

        // Simpan versi lama sebelum update ke rekamMedisVersions
        rekamMedisVersions[_id].push(
            RekamMedisData({
                id: r.id,
                pasien: r.pasien,
                diagnosa: r.diagnosa,
                foto: r.foto,
                catatan: r.catatan,
                valid: r.valid,
                pembuatAwal: r.pembuatAwal, // Sertakan data pembuat/waktu awal
                timestampAwal: r.timestampAwal
            })
        );

        // Update data rekam medis utama
        r.diagnosa = _diagnosa;
        r.foto = _foto;
        r.catatan = _catatan;

        // Simpan info update (siapa dan kapan) ke rekamMedisUpdateHistory
        rekamMedisUpdateHistory[_id].push(
            UpdateInfo({aktor: msg.sender, timestamp: block.timestamp}) // Gunakan 'aktor' field
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
            bool valid,
            address pembuatAwal, // BARU
            uint256 timestampAwal // BARU
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
            r.pembuatAwal,
            r.timestampAwal
        );
    }

    function getRekamMedisVersions(
        uint _id
    ) external view returns (RekamMedisData[] memory) {
        return rekamMedisVersions[_id];
    }

    function getRekamMedisUpdateHistory(
        uint _id
    )
        external
        view
        returns (address[] memory actors, uint256[] memory timestamps)
    {
        uint len = rekamMedisUpdateHistory[_id].length;
        actors = new address[](len);
        timestamps = new uint256[](len);
        for (uint i = 0; i < len; i++) {
            actors[i] = rekamMedisUpdateHistory[_id][i].aktor; // Gunakan .aktor
            timestamps[i] = rekamMedisUpdateHistory[_id][i].timestamp;
        }
        return (actors, timestamps);
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
        // Pertimbangkan untuk emit event di sini jika diperlukan log nonaktifkan
    }

    // --- Super Admin Functions ---
    function setSuperAdmin(address _newAdmin) external hanyaSuperAdmin {
        require(
            _newAdmin != address(0),
            "Alamat super admin baru tidak valid."
        );
        superAdmin = _newAdmin;
    }

    // --- Utility Functions ---
    function getUserRole(address _user) public view returns (string memory) {
        if (_user == superAdmin) return "SuperAdmin";
        if (dataAdmin[_user].aktif) return "AdminRS";
        if (isDokter[_user]) return "Dokter";
        if (isPasien[_user]) return "Pasien";
        return "Unknown";
    }
}
