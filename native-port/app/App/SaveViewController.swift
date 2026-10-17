import UIKit
import UniformTypeIdentifiers

final class SaveViewController: UITableViewController, UIDocumentPickerDelegate {
    private let engineRunning: Bool
    private let store: SaveStore
    private var files: [SaveStore.File] = []
    private var importingFolder = false
    private var working = false {
        didSet { navigationItem.rightBarButtonItem?.isEnabled = !working }
    }

    init(engineRunning: Bool) {
        self.engineRunning = engineRunning
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        store = SaveStore(root: URL(fileURLWithPath: EnginePaths.filesRoot().path), backups: documents.appendingPathComponent("SaveBackups"))
        super.init(style: .insetGrouped)
        title = L10n.text("Save game")
        overrideUserInterfaceStyle = .dark
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        tableView.backgroundView = Theme.dimmedBackdrop(image: "SettingsBackground")
        refreshControl = UIRefreshControl()
        refreshControl?.addAction(UIAction { [weak self] _ in self?.reloadFiles() }, for: .valueChanged)
        reloadFiles()
    }
    private func reloadFiles() {
        do { files = try store.files(); tableView.reloadData() }
        catch { message(L10n.text("Không đọc được save"), error.localizedDescription) }
        refreshControl?.endRefreshing()
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 4 : max(1, files.count) }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { section == 0 ? L10n.text("Sao lưu & khôi phục") : L10n.text("Tệp đang có") + " · \(files.count)" }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else { return nil }
        return L10n.text("Lưu tiến trình bằng điện thoại hoặc điểm lưu trong GTA V. Sau đó sao lưu tại đây. Bản sao nằm trong Tệp › Mugoat › SaveBackups. Khôi phục khi chưa vào game; save hiện có được sao lưu trước khi thay thế.")
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = Theme.rowBackground
        cell.textLabel?.textColor = Theme.text
        cell.detailTextLabel?.textColor = Theme.secondaryText
        cell.detailTextLabel?.numberOfLines = 2
        if indexPath.section == 0 {
            let titles = [L10n.text("Sao lưu tất cả save"), L10n.text("Nhập bản sao lưu"), L10n.text("Làm mới danh sách"), L10n.text("Nhập thư mục save")]
            let symbols = ["square.and.arrow.up", "square.and.arrow.down", "arrow.clockwise", "folder.badge.plus"]
            cell.textLabel?.text = titles[indexPath.row]
            cell.imageView?.image = UIImage(systemName: symbols[indexPath.row]); cell.imageView?.tintColor = Theme.accent
            cell.detailTextLabel?.text = indexPath.row == 0 ? L10n.text("Tạo bản sao và chọn nơi lưu hoặc chia sẻ") : indexPath.row == 1 ? (engineRunning ? L10n.text("Mở lại app, nhập trước khi bấm Vào game") : L10n.text("Chọn tệp .mugoatsave đã xuất")) : L10n.text("Xem tệp mới nhất sau khi game lưu")
            cell.accessoryType = .disclosureIndicator
            if indexPath.row == 3 { cell.detailTextLabel?.text = L10n.text("Chọn thư mục chứa userdata và sandbox, ví dụ Muguet/saves") }
            if [1, 3].contains(indexPath.row) && engineRunning { cell.textLabel?.textColor = Theme.tertiaryText }
        } else if files.isEmpty {
            cell.textLabel?.text = L10n.text("Chưa có tệp save")
            cell.detailTextLabel?.text = L10n.text("Chơi Cốt truyện và lưu trong game, rồi quay lại đây.")
            cell.selectionStyle = .none
        } else {
            let file = files[indexPath.row]
            cell.textLabel?.text = file.url.lastPathComponent
            let date = DateFormatter.localizedString(from: file.modified, dateStyle: .short, timeStyle: .short)
            let size = ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file)
            cell.detailTextLabel?.text = "\(file.path)\n\(size) · \(date)"
            cell.imageView?.image = UIImage(systemName: "doc.fill"); cell.imageView?.tintColor = Theme.accent
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !working else { return }
        if indexPath.section == 1 {
            guard !files.isEmpty else { return }
            let file = files[indexPath.row]
            do {
                guard file.size <= SaveStore.totalLimit else { throw SaveStore.Failure.tooLarge }
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let copy = directory.appendingPathComponent(file.url.lastPathComponent)
                let bytes = try Data(contentsOf: file.url)
                guard bytes.count <= SaveStore.totalLimit, bytes == (try Data(contentsOf: file.url)) else { throw SaveStore.Failure.changed }
                try bytes.write(to: copy, options: .atomic)
                share(copy, from: tableView.cellForRow(at: indexPath))
            } catch { message(L10n.text("Không xuất được tệp"), error.localizedDescription) }
            return
        }
        switch indexPath.row {
        case 0:
            working = true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let result = Result { try self.store.export() }
                DispatchQueue.main.async {
                    self.working = false
                    switch result {
                    case .success(let url): self.share(url, from: self.tableView.cellForRow(at: indexPath))
                    case .failure(let error): self.message(L10n.text("Không sao lưu được"), error.localizedDescription)
                    }
                }
            }
        case 1, 3:
            guard !engineRunning else { message(L10n.text("Khôi phục trước khi vào game"), L10n.text("Mở lại app và vào Save game trước khi bấm Vào game.")); return }
            importingFolder = indexPath.row == 3
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: importingFolder ? [.folder] : [.data], asCopy: !importingFolder)
            picker.delegate = self
            present(picker, animated: true)
        default: reloadFiles()
        }
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard !engineRunning, let source = urls.first else { return }
        let isFolder = importingFolder
        let alert = UIAlertController(title: L10n.text("Khôi phục save?"), message: L10n.text("Save trùng đường dẫn sẽ được thay thế. App tạo bản sao lưu save hiện có trước khi khôi phục."), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.text("Hủy"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.text("Khôi phục"), style: .default) { [weak self] _ in
            guard let self else { return }
            self.working = true
            DispatchQueue.global(qos: .userInitiated).async {
                let scoped = source.startAccessingSecurityScopedResource()
                defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                let result = Result {
                    if isFolder {
                        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                        defer { try? FileManager.default.removeItem(at: temporary) }
                        let imported = SaveStore(root: source, backups: temporary)
                        let package = try imported.export()
                        try self.store.restore(from: package)
                    } else {
                        try self.store.restore(from: source)
                    }
                }
                DispatchQueue.main.async {
                    self.working = false
                    switch result {
                    case .success: self.reloadFiles(); self.message(L10n.text("Đã khôi phục tệp save"), L10n.text("Chọn Cốt truyện và vào game để nạp tiến trình."))
                    case .failure(let error): self.message(L10n.text("Không khôi phục được"), error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }
    private func share(_ url: URL, from source: UIView?) {
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = source ?? view
        sheet.popoverPresentationController?.sourceRect = (source ?? view).bounds
        present(sheet, animated: true)
    }
    private func message(_ title: String, _ text: String) {
        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.text("Đóng"), style: .cancel))
        present(alert, animated: true)
    }
}
