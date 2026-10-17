import UIKit
import Darwin

enum OnlineSettings {
    private static let legacy: [String: Any] = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let data = try? Data(contentsOf: documents.appendingPathComponent("config.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }()
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "MugoatOnlineEnabled") as? Bool ?? legacy["multiplayer"] as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "MugoatOnlineEnabled") }
    }
    static var server: String {
        get { UserDefaults.standard.string(forKey: "MugoatOnlineServer") ?? legacy["server"] as? String ?? "18.143.103.253" }
        set { UserDefaults.standard.set(newValue, forKey: "MugoatOnlineServer") }
    }
    static var name: String {
        get { UserDefaults.standard.string(forKey: "MugoatOnlineName") ?? legacy["player_name"] as? String ?? "Player" }
        set { UserDefaults.standard.set(newValue, forKey: "MugoatOnlineName") }
    }
    static var room: String {
        get { UserDefaults.standard.string(forKey: "MugoatOnlineRoom") ?? legacy["room"] as? String ?? "story" }
        set { UserDefaults.standard.set(newValue, forKey: "MugoatOnlineRoom") }
    }
    static let roles = ["Dân thường", "Cảnh sát", "Bác sĩ", "Băng đảng", "Tài xế"]
    static var role: String {
        get { UserDefaults.standard.string(forKey: "MugoatOnlineRole") ?? "Dân thường" }
        set { UserDefaults.standard.set(newValue, forKey: "MugoatOnlineRole") }
    }
    static var pvp: Bool {
        get { UserDefaults.standard.object(forKey: "MugoatOnlinePVP") as? Bool ?? legacy["pvp"] as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "MugoatOnlinePVP") }
    }
    static func configure(mode: GameMode) -> Bool {
        setenv("MUGUET_PVP", pvp ? "1" : "0", 1)
        let currentRole = role
        let displayName = (currentRole != "Dân thường" && !name.hasPrefix("[")) ? "[\(currentRole)] \(name)" : name
        return (enabled ? server : "").withCString { server in
            displayName.withCString { name in room.withCString { room in
                MugoatOnlineConfigure(server, name, room, Int32(mode.rawValue))
            } }
        }
    }
    static var status: String {
        var bytes = [CChar](repeating: 0, count: 512)
        bytes.withUnsafeMutableBufferPointer { _ = MugoatOnlineStatus($0.baseAddress, $0.count) }
        return L10n.text(String(cString: bytes))
    }
}

final class OnlineSettingsViewController: UIViewController {
    private let running: Bool
    private let enabled = UISwitch()
    private let rolePicker = UISegmentedControl(items: OnlineSettings.roles)
    private let pvp = UISwitch()
    private let server = UITextField()
    private let name = UITextField()
    private let room = UITextField()
    private let status = UILabel()
    private var statusTimer: Timer?
    var changed: (() -> Void)?
    init(running: Bool) { self.running = running; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("Máy chủ online")
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
        enabled.isOn = OnlineSettings.enabled; enabled.isEnabled = !running
        let label = UILabel(); label.text = L10n.text("Chơi online"); label.textColor = Theme.text
        let toggle = UIStackView(arrangedSubviews: [label, enabled]); toggle.alignment = .center
        let roleLabel = UILabel(); roleLabel.text = L10n.text("Vai trò nhân vật (Role)"); roleLabel.textColor = Theme.text
        roleLabel.font = Theme.body(14)
        rolePicker.selectedSegmentIndex = OnlineSettings.roles.firstIndex(of: OnlineSettings.role) ?? 0
        rolePicker.isEnabled = !running
        rolePicker.overrideUserInterfaceStyle = .dark
        pvp.isOn = OnlineSettings.pvp; pvp.isEnabled = !running
        let pvpLabel = UILabel(); pvpLabel.text = L10n.text("PvP: bắn người chơi khác"); pvpLabel.textColor = Theme.text
        let pvpRow = UIStackView(arrangedSubviews: [pvpLabel, pvp]); pvpRow.alignment = .center
        server.text = OnlineSettings.server; server.placeholder = "IP / hostname:47520"; server.keyboardType = .URL
        name.text = OnlineSettings.name; name.placeholder = L10n.text("Tên người chơi")
        room.text = OnlineSettings.room; room.placeholder = L10n.text("Phòng chơi")
        for field in [server, name, room] {
            field.borderStyle = .roundedRect; field.autocapitalizationType = .none
            field.autocorrectionType = .no; field.isEnabled = !running
            field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        let explanation = UILabel()
        explanation.text = L10n.text(running ? "Đóng rồi mở lại app để đổi máy chủ." : "Dùng cùng IP, phòng và chế độ chơi với bạn bè. Máy chủ Muguet dùng UDP 47520. Kết nối bắt đầu khi vào game.")
        explanation.font = Theme.body(13); explanation.textColor = Theme.secondaryText; explanation.numberOfLines = 0
        status.text = running ? OnlineSettings.status : ""; status.textColor = Theme.accent; status.numberOfLines = 0
        let save = Theme.primaryButton(L10n.text("Lưu"), symbol: "checkmark")
        save.isEnabled = !running
        save.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside)
        let column = UIStackView(arrangedSubviews: [toggle, roleLabel, rolePicker, server, name, room, pvpRow, explanation, status, save]); column.axis = .vertical; column.spacing = 16
        let scroll = UIScrollView(); scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(scroll)
        column.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(column)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20), column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24), column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.text("Đóng"), style: .done, target: self, action: #selector(close))
    }
    @objc private func close() { dismiss(animated: true) }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if running { statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.status.text = OnlineSettings.status } }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated); statusTimer?.invalidate(); statusTimer = nil
    }
    private func save() {
        let host = (server.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let player = (name.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let channel = (room.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !enabled.isOn || (!host.isEmpty && host.utf8.count <= 253 && !host.contains("/") && !host.contains(where: { $0.isWhitespace }) && player.utf8.count <= 48 && channel.utf8.count <= 64) else {
            let alert = UIAlertController(title: L10n.text("Máy chủ không hợp lệ"), message: L10n.text("Nhập IP hoặc hostname, ví dụ 192.168.1.10:47520."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true); return
        }
        OnlineSettings.server = host; OnlineSettings.name = player; OnlineSettings.room = channel; OnlineSettings.enabled = enabled.isOn
        OnlineSettings.pvp = pvp.isOn
        let roleIdx = rolePicker.selectedSegmentIndex
        if OnlineSettings.roles.indices.contains(roleIdx) {
            OnlineSettings.role = OnlineSettings.roles[roleIdx]
        }
        changed?(); dismiss(animated: true)
    }
}
