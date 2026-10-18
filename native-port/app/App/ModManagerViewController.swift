import UIKit
import UniformTypeIdentifiers

/// Dedicated Mod Manager screen: manage installed mods, import mod archives/files of any type
/// (.zip, .rpf, .ytd, .yft, .meta, .asi...), show the real type of every file, and spawn installed
/// add-on/DLC vehicles and iconic GTA V vehicles directly into the game.
final class ModManagerViewController: UITableViewController, UIDocumentPickerDelegate {
    private let engineRunning: Bool
    private let fileManager = FileManager.default
    private var modFiles: [ModFile] = []
    private var dlcCatalog: ModRuntime.Catalog = ModRuntime.Catalog()
    /// model -> vehicle type label ("Ô tô", "Mô tô"...) and model -> DLC pack name, for installed packs.
    private var vehicleKinds: [String: String] = [:]
    private var packOfModel: [String: String] = [:]

    typealias ModFile = ModFiles.Entry

    private let defaultVehicles: [(name: String, model: String, icon: String)] = [
        ("Karin Sultan (4 cửa)", "sultan", "car.fill"),
        ("Trực thăng Buzzard Attack", "buzzard", "airplane"),
        ("Mô tô bay Oppressor Mk II", "oppressor2", "bolt.car.fill"),
        ("Siêu xe Truffade Adder", "adder", "car.side.fill"),
        ("Mô tô Pegassi Bati 801", "bati", "bicycle")
    ]

    /// The dedicated mods directory: Files › On My iPhone › Mugoat › mods
    static var modsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("mods")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    init(engineRunning: Bool) {
        self.engineRunning = engineRunning
        super.init(style: .insetGrouped)
        title = L10n.text("Quản lý Mod")
        overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        tableView.backgroundView = Theme.dimmedBackdrop(image: "SettingsBackground")
        refreshControl = UIRefreshControl()
        refreshControl?.addAction(UIAction { [weak self] _ in self?.scanMods() }, for: .valueChanged)
        _ = Self.modsDirectory
        scanMods()
    }

    private func scanMods() {
        modFiles = ModFiles.scan(Self.modsDirectory)
        dlcCatalog = ModRuntime.catalog(Self.modsDirectory)
        var kinds: [String: String] = [:]
        var packs: [String: String] = [:]
        for pack in dlcCatalog.packs {
            for model in pack.vehicleModels {
                kinds[model] = pack.vehicleKinds[model] ?? "Xe (chưa rõ loại)"
                packs[model] = pack.name
            }
        }
        vehicleKinds = kinds
        packOfModel = packs
        tableView.reloadData()
        refreshControl?.endRefreshing()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3 // Quản lý & Cài đặt
        case 1: return max(1, modFiles.count) // Tệp mod đã cài
        case 2: return 1 + dlcCatalog.vehicleModels.count + defaultVehicles.count // Gọi xe (Custom + Add-ons + Mặc định)
        default: return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return L10n.text("Cài đặt & Tệp Mod")
        case 1: return L10n.text("Danh sách Mod đã cài") + " · \(modFiles.count)"
        case 2: return L10n.text("Gọi phương tiện & Xe Mod (DLC Spawner)")
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return L10n.text("Nhập gói DLC add-on (dlc.rpf, hoặc .zip/.rar chứa dlc.rpf, tối đa 100 MB mỗi gói) bằng Nhập Mod. Không chép tay file rpf vào thư mục mods. Sau khi nhập hoặc đổi mod, thoát hẳn app và mở lại. Bấm ⓘ ở tệp mod để xem báo cáo.")
                + "\n" + "Mọi loại tệp mod khác (.ytd, .yft, .meta, rpf mã hóa…) cũng được nhận và lưu kèm loại thật của tệp; engine chỉ nạp gói dlc.rpf hợp lệ."
        case 1:
            guard !dlcCatalog.problems.isEmpty else { return nil }
            return "⚠︎ " + dlcCatalog.problems.joined(separator: "\n⚠︎ ")
        case 2:
            return L10n.text("Bấm vào phương tiện để triệu hồi ngay trước mặt nhân vật. Có thể nhập tên model bất kỳ từ bản mod hoặc GTA V gốc.")
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = Theme.rowBackground
        cell.textLabel?.textColor = Theme.text
        cell.detailTextLabel?.textColor = Theme.secondaryText
        cell.detailTextLabel?.numberOfLines = 3

        switch indexPath.section {
        case 0:
            let titles = [
                L10n.text("Nhập Mod từ tệp (.zip, .rpf, .meta)"),
                L10n.text("Vị trí thư mục Mod"),
                L10n.text("Làm mới danh sách Mod")
            ]
            let subs = [
                L10n.text("Chọn tệp từ Tệp hoặc iCloud để tự động cài vào Mugoat"),
                "Files › On My iPhone › Mugoat › mods",
                L10n.text("Quét lại thư mục sau khi chép file qua máy tính hoặc app Tệp")
            ]
            let icons = ["square.and.arrow.down.fill", "folder.fill.badge.gearshape", "arrow.clockwise"]
            cell.textLabel?.text = titles[indexPath.row]
            cell.detailTextLabel?.text = subs[indexPath.row]
            cell.imageView?.image = UIImage(systemName: icons[indexPath.row])
            cell.imageView?.tintColor = Theme.accent
            cell.accessoryType = indexPath.row == 0 ? .disclosureIndicator : .none

        case 1:
            if modFiles.isEmpty {
                cell.textLabel?.text = L10n.text("Chưa có tệp Mod nào")
                cell.detailTextLabel?.text = L10n.text("Bấm 'Nhập Mod từ tệp' ở trên hoặc chép file vào thư mục Mugoat/mods.")
                cell.imageView?.image = UIImage(systemName: "tray")
                cell.imageView?.tintColor = Theme.secondaryText
                cell.selectionStyle = .none
            } else {
                let mod = modFiles[indexPath.row]
                cell.textLabel?.text = mod.name
                let sizeStr = ByteCountFormatter.string(fromByteCount: mod.size, countStyle: .file)
                let dateStr = DateFormatter.localizedString(from: mod.modified, dateStyle: .short, timeStyle: .short)
                var detail = "\(sizeStr) · \(dateStr) · \(mod.isEnabled ? L10n.text("Đang bật") : L10n.text("Đã tắt"))"
                if mod.isEnabled, let pack = installedPack(for: mod) {
                    detail += "\nGói DLC dlc_\(pack.name) · \(pack.vehicleModels.count) xe"
                    let kinds = Set(pack.vehicleKinds.values)
                    if !kinds.isEmpty { detail += " (" + kinds.sorted().joined(separator: ", ") + ")" }
                    if !pack.pedModels.isEmpty { detail += " · \(pack.pedModels.count) nhân vật" }
                    if !pack.warnings.isEmpty { detail += " · ⚠︎" }
                } else {
                    detail += "\n" + mod.info.title
                    if !mod.info.detail.isEmpty { detail += " · " + mod.info.detail }
                }
                cell.detailTextLabel?.text = detail
                cell.imageView?.image = UIImage(systemName: mod.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                cell.imageView?.tintColor = mod.isEnabled ? Theme.accent : .systemGray
                cell.accessoryType = .detailButton
            }

        case 2:
            if indexPath.row == 0 {
                cell.textLabel?.text = L10n.text("Gọi xe theo tên Model (Custom Spawn…)")
                cell.detailTextLabel?.text = L10n.text("Nhập tên model bất kỳ (ví dụ: mbslk, sultan, buzzard…)")
                cell.imageView?.image = UIImage(systemName: "magnifyingglass.circle.fill")
                cell.imageView?.tintColor = Theme.accent
                cell.accessoryType = .disclosureIndicator
            } else if indexPath.row <= dlcCatalog.vehicleModels.count {
                let model = dlcCatalog.vehicleModels[indexPath.row - 1]
                let kind = vehicleKinds[model] ?? "Xe (chưa rõ loại)"
                let pack = packOfModel[model].map { "dlc_" + $0 } ?? "DLC"
                cell.textLabel?.text = "Xe Mod: \(model.uppercased())"
                cell.detailTextLabel?.text = "\(kind) · \(pack) · " + L10n.text("Bấm để triệu hồi")
                cell.imageView?.image = UIImage(systemName: Self.icon(forKind: kind))
                cell.imageView?.tintColor = .systemYellow
                cell.accessoryType = .disclosureIndicator
            } else {
                let index = indexPath.row - 1 - dlcCatalog.vehicleModels.count
                if index < defaultVehicles.count {
                    let v = defaultVehicles[index]
                    cell.textLabel?.text = v.name
                    cell.detailTextLabel?.text = "Model: \(v.model) · " + L10n.text("Bấm để triệu hồi")
                    cell.imageView?.image = UIImage(systemName: v.icon)
                    cell.imageView?.tintColor = Theme.accent
                    cell.accessoryType = .disclosureIndicator
                }
            }

        default: break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0:
            if indexPath.row == 0 { pickModFile() }
            else if indexPath.row == 1 { showFolderInfo() }
            else if indexPath.row == 2 { scanMods() }

        case 1:
            guard !modFiles.isEmpty, indexPath.row < modFiles.count else { return }
            toggleMod(at: indexPath.row)

        case 2:
            if indexPath.row == 0 {
                promptCustomVehicleSpawn()
            } else if indexPath.row <= dlcCatalog.vehicleModels.count {
                let model = dlcCatalog.vehicleModels[indexPath.row - 1]
                spawnVehicle(named: model)
            } else {
                let index = indexPath.row - 1 - dlcCatalog.vehicleModels.count
                if index < defaultVehicles.count {
                    spawnVehicle(named: defaultVehicles[index].model)
                }
            }

        default: break
        }
    }

    // MARK: - Mod File Actions

    private func pickModFile() {
        // Any file type is accepted (.ytd, .yft, .meta, .rpf, archives...); notes and pictures are skipped on import.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let destDir = Self.modsDirectory
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        navigationItem.titleView = spinner
        view.isUserInteractionEnabled = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var report = ModRuntime.ImportReport()
            for url in urls {
                let name = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                    report.problems.append("\(name): không đọc được (không phải tệp thường).")
                    continue
                }
                if ModFiles.archiveExtensions.contains(ext) {
                    report.merge(ModRuntime.installArchive(url, into: destDir))
                } else {
                    report.merge(ModRuntime.importFile(url, into: destDir))
                }
            }
            let finished = report
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.navigationItem.titleView = nil
                self.view.isUserInteractionEnabled = true
                self.scanMods()
                self.showImportResult(finished)
            }
        }
    }

    private func showImportResult(_ report: ModRuntime.ImportReport) {
        var lines: [String] = []
        for pack in report.installed {
            var summary = "✅ \(pack.name): \(pack.vehicleModels.count) xe"
            if !pack.pedModels.isEmpty { summary += ", \(pack.pedModels.count) nhân vật" }
            lines.append(summary)
            var shown: [String] = []
            for model in pack.vehicleModels.prefix(8) {
                if let kind = pack.vehicleKinds[model] { shown.append("\(model) (\(kind))") } else { shown.append(model) }
            }
            if !shown.isEmpty { lines.append("   " + shown.joined(separator: ", ") + (pack.vehicleModels.count > 8 ? "…" : "")) }
            if !pack.pedModels.isEmpty { lines.append("   Nhân vật: " + pack.pedModels.prefix(8).joined(separator: ", ")) }
            for warning in pack.warnings { lines.append("   ⚠︎ " + warning) }
        }
        for item in report.stored.prefix(12) { lines.append("📥 " + item) }
        if report.stored.count > 12 { lines.append("📥 … và \(report.stored.count - 12) tệp khác") }
        if report.looseFiles > 0 {
            lines.append("ℹ︎ \(report.looseFiles) tệp đã được nhận và lưu, loại của từng tệp hiện trong Danh sách Mod đã cài. Engine chỉ nạp mod đóng gói thành gói dlc.rpf hợp lệ; tệp rời (.ytd/.yft/.meta…) cần được gộp vào dlc.rpf mới lên game.")
        }
        for problem in report.problems { lines.append("❌ " + problem) }
        if !report.installed.isEmpty {
            lines.append("")
            lines.append(engineRunning
                ? "Game đang chạy: hãy thoát hẳn app rồi mở lại để engine nạp mod mới."
                : "Mod sẽ được nạp khi bạn bấm Play.")
        }
        guard !lines.isEmpty else { return }
        let received = !report.installed.isEmpty || !report.stored.isEmpty
        showAlert(received ? "Kết quả nhập Mod" : "Không nhập được mod", lines.joined(separator: "\n"))
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard indexPath.section == 1, indexPath.row < modFiles.count else { return }
        let mod = modFiles[indexPath.row]
        showAlert(mod.name, describe(mod))
    }

    private func installedPack(for mod: ModFile) -> ModPack? {
        let path = mod.url.standardizedFileURL.path
        return dlcCatalog.packs.first { $0.url.standardizedFileURL.path == path }
    }

    private func describe(_ mod: ModFile) -> String {
        var lines: [String] = []
        if !mod.isEnabled {
            lines.append("Mod đang tắt.")
        } else if let pack = installedPack(for: mod) {
            return pack.report
        }
        lines.append("Loại: " + mod.info.title)
        if !mod.info.detail.isEmpty { lines.append(mod.info.detail) }
        let prefix = mod.name + ": "
        if mod.isEnabled, let problem = dlcCatalog.problems.first(where: { $0.hasPrefix(prefix) }) {
            lines.append("Chưa nạp vào game: " + String(problem.dropFirst(prefix.count)))
        } else if mod.isEnabled {
            lines.append("Đã lưu trong thư mục mods. Engine bản này chỉ nạp mod đóng gói thành gói DLC (dlc.rpf) hợp lệ; tệp rời như .ytd/.yft/.meta chưa tự lên game được.")
        }
        return lines.joined(separator: "\n")
    }

    /// SF Symbol for a vehicle type label produced by ModFiles.vehicleKindLabel.
    private static func icon(forKind kind: String) -> String {
        switch kind {
        case "Mô tô", "Xe đạp", "Xe quad": return "bicycle"
        case "Trực thăng", "Máy bay", "Trực thăng gyro", "Khí cầu": return "airplane"
        case "Tàu thuyền", "Tàu ngầm": return "ferry.fill"
        default: return "car.fill"
        }
    }

    private func noteRestartIfNeeded() {
        guard engineRunning else { return }
        showAlert("Cần mở lại game", "Thay đổi mod chỉ có hiệu lực sau khi thoát hẳn app và mở lại.")
    }

    private func toggleMod(at index: Int) {
        let mod = modFiles[index]
        let sheet = UIAlertController(title: mod.name, message: L10n.text("Chọn thao tác cho bản mod này:"), preferredStyle: .actionSheet)
        let toggleTitle = mod.isEnabled ? L10n.text("Tắt Mod này (.disabled)") : L10n.text("Bật lại Mod này")
        sheet.addAction(UIAlertAction(title: toggleTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            let newURL: URL
            if mod.isEnabled {
                newURL = mod.url.appendingPathExtension("disabled")
            } else {
                newURL = mod.url.deletingPathExtension()
            }
            try? self.fileManager.moveItem(at: mod.url, to: newURL)
            self.scanMods()
            self.noteRestartIfNeeded()
        })
        sheet.addAction(UIAlertAction(title: L10n.text("Xóa vĩnh viễn"), style: .destructive) { [weak self] _ in
            guard let self else { return }
            try? self.fileManager.removeItem(at: mod.url)
            self.scanMods()
            self.noteRestartIfNeeded()
        })
        sheet.addAction(UIAlertAction(title: L10n.text("Đóng"), style: .cancel))
        if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 1)) {
            sheet.popoverPresentationController?.sourceView = cell
        }
        present(sheet, animated: true)
    }

    private func showFolderInfo() {
        let path = Self.modsDirectory.path
        let alert = UIAlertController(
            title: L10n.text("Thư mục Mod Mugoat"),
            message: "\(L10n.text("Đường dẫn trên iPhone:"))\n\(path)\n\n\(L10n.text("Mở app 'Tệp' › 'Trên iPhone' › 'Mugoat' › 'mods' để quản lý hoặc chép đè tệp mod."))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.text("Sao chép đường dẫn"), style: .default) { _ in
            UIPasteboard.general.string = path
        })
        alert.addAction(UIAlertAction(title: L10n.text("Đã hiểu"), style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Vehicle Spawner

    private func spawnVehicle(named model: String) {
        guard engineRunning else {
            showAlert(L10n.text("Chưa vào game"), L10n.text("Vui lòng khởi động và vào game trước khi gọi phương tiện."))
            return
        }
        let cleanModel = ModRuntime.resolveModel(model, mods: Self.modsDirectory)
        guard !cleanModel.isEmpty else { return }
        if ModRuntime.needsRestart(for: cleanModel, mods: Self.modsDirectory) {
            showAlert("Cần mở lại game", "Mod '\(cleanModel)' được cài sau khi game khởi động nên engine chưa nạp. Hãy thoát hẳn app rồi mở lại và vào game.")
            return
        }
        let started = cleanModel.withCString { PGSpawnVehicle($0) }
        if started {
            let shown = cleanModel
            navigationItem.prompt = "Đang nạp xe '\(shown)'…"
            ModSpawn.watch { [weak self] ok in
                guard let self = self else { return }
                self.navigationItem.prompt = nil
                if ok == true {
                    self.showAlert(L10n.text("Đã gọi xe"), "Đã tạo xe '\(shown)' trước mặt nhân vật.")
                } else if ok == false {
                    let similar = ModRuntime.similarModels(to: shown, mods: Self.modsDirectory).filter { $0 != shown }
                    let tip = similar.isEmpty ? "" : "\nCó thể bạn muốn gọi: " + similar.joined(separator: ", ")
                    self.showAlert("Không gọi được xe", "Engine không tạo được '\(shown)'.\n" + ModSpawn.failureHint + tip)
                } else {
                    self.showAlert("Xe vẫn đang tải", "'\(shown)' nạp lâu bất thường. Nếu xe không xuất hiện, \(ModSpawn.failureHint)")
                }
            }
        } else {
            showAlert(L10n.text("Hệ thống bận"), L10n.text("Đang trong quá trình triệu hồi phương tiện khác. Vui lòng thử lại sau giây lát."))
        }
    }

    private func promptCustomVehicleSpawn() {
        let alert = UIAlertController(
            title: L10n.text("Gọi xe theo tên Model"),
            message: L10n.text("Nhập tên model xe từ bản mod (ví dụ: mbslk) hoặc GTA V gốc (ví dụ: sultan, adder, buzzard):"),
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "mbslk, sultan, buzzard..."
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: L10n.text("Gọi xe ngay"), style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text else { return }
            self?.spawnVehicle(named: text)
        })
        alert.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
        present(alert, animated: true)
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.text("Đã hiểu"), style: .default))
        present(alert, animated: true)
    }
}
