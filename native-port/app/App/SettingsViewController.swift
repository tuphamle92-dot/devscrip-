import UIKit

/// Graphics and control options. Before launch every change applies on Play;
/// during play only resolution and controls apply live, the rest on restart.
final class SettingsViewController: UITableViewController {
    private let settings = GameSettings.shared
    private let engineRunning: Bool
    private let bootPreset: GraphicsPreset
    /// The mode the running engine started in (nil before Play).
    private let runningMode: GameMode?
    var resolutionChanged: (() -> Void)?
    var controlsChanged: (() -> Void)?
    var editLayout: (() -> Void)?
    var targetingChanged: (() -> Void)?
    var gameModeChanged: (() -> Void)?
    var openCheat: (() -> Void)?
    var openMods: (() -> Void)?
    var openSaves: (() -> Void)?

    private enum Section: Int, CaseIterable { case cheat, mode, graphics, controls, gyro, files, device }
    private let preloader = AssetPreloader.shared
    /// Rows shown in the Game files section, rebuilt from the preloader's phase.
    private enum FileRow { case status, start, pause, resume, cancel, remove }
    private var fileRows: [FileRow] = []
    private var fileStateKey = ""
    private var fileMessage: String?

    init(engineRunning: Bool, runningMode: GameMode? = nil) {
        self.engineRunning = engineRunning
        self.runningMode = engineRunning ? runningMode : nil
        self.bootPreset = GameSettings.shared.graphicsPreset
        super.init(style: .insetGrouped)
        title = L10n.text("Cài đặt Mugoat")
        modalPresentationStyle = .formSheet
        overrideUserInterfaceStyle = .dark
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.rightBarButtonItem?.tintColor = Theme.accent
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundView = Theme.dimmedBackdrop(image: "SettingsBackground")
        tableView.separatorColor = UIColor(white: 1, alpha: 0.1)
        fileRows = makeFileRows()
        NotificationCenter.default.addObserver(self, selector: #selector(preloadChanged), name: .assetPreloadChanged, object: nil)
        preloader.refresh()
        let arguments = ProcessInfo.processInfo.arguments
        if let i = arguments.firstIndex(of: "--settings-section"), i + 1 < arguments.count,
           let section = ["files": Section.files, "graphics": Section.graphics, "resolution": Section.graphics][arguments[i + 1]] {
            let row = arguments[i + 1] == "resolution" ? settings.tier.allowed.count : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.tableView.scrollToRow(at: IndexPath(row: row, section: section.rawValue), at: .middle, animated: false)
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    // The app's look: rows as glass on the darkened art, headers in the display font.
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = Theme.rowBackground
        let selected = UIView()
        selected.backgroundColor = Theme.rowSelected
        cell.selectedBackgroundView = selected
    }
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        var content = header.defaultContentConfiguration()
        content.text = self.tableView(tableView, titleForHeaderInSection: section)
        content.textProperties.font = Theme.display(15, .bold)
        content.textProperties.color = Theme.text
        content.textProperties.transform = .uppercase
        header.contentConfiguration = content
    }
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let label = (view as? UITableViewHeaderFooterView)?.textLabel
        label?.textColor = Theme.tertiaryText
        if let text = label?.text { label?.text = L10n.text(text) }
    }

    private var isOnline: Bool {
        MugoatOnlineEnabled() || OnlineSettings.enabled
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .cheat: return isOnline ? 1 : 2
        case .mode: return GameMode.allCases.count
        case .graphics: return settings.tier.allowed.count + 3
        case .controls: return 11
        case .gyro: return (settings.gyroAim == .off ? 1 : 3) + (settings.tiltSteer == .off ? 1 : 2)
        case .files: return fileRows.count
        case .device: return 5
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let cheatHeader = isOnline ? L10n.text("Quản lý Mod") : L10n.text("Menu Cheat & Mod")
        return [cheatHeader, L10n.text("Chế độ chơi"), L10n.text("Đồ họa & FPS"), L10n.text("Điều khiển"), L10n.text("Cảm biến"), L10n.text("Dữ liệu game"), L10n.text("Thiết bị & hỗ trợ")][section]
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .cheat:
            if isOnline {
                return L10n.text("Mục Cheat bị ẩn khi chơi Online để đảm bảo công bằng. Bạn có thể mở Quản lý Mod để cài đặt tệp mod.")
            }
            return L10n.text("Menu Cheat cho phép kích hoạt ngay các tính năng gian lận, spawn phương tiện và can thiệp game. Bạn cũng có thể mở Quản lý Mod để cài đặt tệp mod vào game.")
        case .mode:
            var text = L10n.text("Story mode saves stay on this phone between launches. Sandbox keeps its own separate files.")
            if let runningMode {
                text = L10n.text("Changes apply the next time you start the game. ") + text
                if settings.gameMode != runningMode { text += " Close and reopen the app to play \(settings.gameMode.title)." }
            }
            return text
        case .graphics:
            var text = L10n.text("Resolution changes apply right away. ")
            text += engineRunning ? L10n.text("Preset and frame rate changes apply the next time you start the game.") : L10n.text("Presets apply when you press Play.")
            if settings.graphicsPreset != bootPreset && engineRunning { text += " Restart needed for \(settings.graphicsPreset.title)." }
            if settings.tier.risky(settings.graphicsPreset) { text += " Presets above the recommended one can run out of memory or overheat on this phone; if a launch fails, the game falls back automatically." }
            return text
        case .controls:
            return L10n.text("Controls act as a game controller, so the game's own aim assist and analog steering work. Assisted aim locks onto targets like on a console.")
        case .gyro:
            return L10n.text("Move the phone to fine-tune your aim; turning your body turns the camera. Tilt steering turns the phone like a steering wheel: Assist adds fine control on top of the touch steering, Tilt to steer replaces it. The straight-ahead angle is however you hold the phone when you get in.")
        case .files: return filesFooter()
        case .device: return "Mugoat · iOSVN · \(Theme.appVersion). Chia sẻ log kèm phiên bản này khi báo lỗi."
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .default
        var content = cell.defaultContentConfiguration()
        content.secondaryTextProperties.color = .secondaryLabel
        let presets = settings.tier.allowed
        switch Section(rawValue: indexPath.section)! {
        case .cheat:
            if isOnline {
                content.text = L10n.text("Quản lý Mod riêng biệt")
                content.secondaryText = L10n.text("Xem danh sách tệp mod, giải nén zip và quản lý thư mục Mugoat/mods")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            } else if indexPath.row == 0 {
                content.text = L10n.text("Menu Cheat (Trainer)")
                content.secondaryText = L10n.text("Kích hoạt bất tử, full vũ khí, gọi xe cộ, máy bay, đổi thời tiết...")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            } else {
                content.text = L10n.text("Quản lý Mod riêng biệt")
                content.secondaryText = L10n.text("Xem danh sách tệp mod, giải nén zip và quản lý thư mục Mugoat/mods")
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            }
        case .mode:
            let mode = GameMode.allCases[indexPath.row]
            content.text = mode.title + (mode == runningMode ? L10n.text(" (playing now)") : "")
            content.secondaryText = mode.detail
            cell.accessoryType = settings.gameModeChoice == mode ? .checkmark : .none
        case .graphics:
            if indexPath.row < presets.count {
                let preset = presets[indexPath.row]
                content.text = preset.title + (preset == settings.tier.recommended ? L10n.text(" (recommended)") : "")
                content.secondaryText = "Detail level, default \(preset.height)p · " + preset.detail + (settings.tier.risky(preset) ? L10n.text("\n⚠︎ Heavier than this phone's recommended setting: may run out of memory or overheat.") : "")
                if settings.tier.risky(preset) { content.secondaryTextProperties.color = .systemOrange }
                cell.accessoryType = preset == settings.graphicsPreset ? .checkmark : .none
            } else {
                let row = indexPath.row - presets.count
                cell.selectionStyle = .none
                if row == 0 {
                    content.text = L10n.text("Resolution")
                    content.secondaryText = currentSizeText() + L10n.text(" · changes right away")
                    let button = UIButton(type: .system)
                    button.setTitle(resolutionTitle(settings.renderHeight) + " ▾", for: .normal)
                    button.showsMenuAsPrimaryAction = true
                    button.accessibilityLabel = L10n.text("Resolution")
                    let choices = [0] + GraphicsConfiguration.resolutionChoices
                    button.menu = UIMenu(children: choices.map { height in
                        UIAction(title: resolutionTitle(height), state: height == settings.renderHeight ? .on : .off) { [weak self] _ in
                            guard let self else { return }
                            self.settings.renderHeight = height
                            self.resolutionChanged?()
                            self.reloadFooters()
                        }
                    })
                    button.sizeToFit()
                    cell.accessoryView = button
                } else if row == 1 {
                    content.text = L10n.text("Fill the screen")
                    content.secondaryText = L10n.text("Render at the screen's shape instead of stretching 16:9")
                    cell.accessoryView = toggle(settings.matchScreenShape, label: L10n.text("Fill the screen")) { [weak self] in
                        self?.settings.matchScreenShape = $0; self?.resolutionChanged?(); self?.tableView.reloadData()
                    }
                } else {
                    content.text = L10n.text("Frame rate")
                    content.secondaryText = L10n.text("Higher uses more power and heat; 30 FPS is steadiest. Unlocked goes up to 120 on ProMotion iPhones.")
                    let button = UIButton(type: .system)
                    button.setTitle(GameSettings.frameRateTitle(settings.frameRateCap) + " ▾", for: .normal)
                    button.showsMenuAsPrimaryAction = true
                    button.accessibilityLabel = L10n.text("Frame rate")
                    button.menu = UIMenu(children: [30, 60, 0].map { cap in
                        UIAction(title: GameSettings.frameRateTitle(cap), state: cap == settings.frameRateCap ? .on : .off) { [weak self] _ in
                            self?.settings.frameRateCap = cap; self?.reloadFooters(); self?.tableView.reloadData()
                        }
                    })
                    button.sizeToFit()
                    cell.accessoryView = button
                }
            }
        case .controls:
            cell.selectionStyle = .none
            switch indexPath.row {
            case 0:
                cell.accessoryView = slider(settings.lookSensitivity, 0.5, 10.0, label: L10n.text("Look speed")) { [weak self] in self?.settings.lookSensitivity = $0 }
                content.text = L10n.text("Camera stick speed")
            case 5:
                cell.accessoryView = slider(settings.aimSensitivity, 0.5, 10.0, label: "Aim look speed") { [weak self] in self?.settings.aimSensitivity = $0 }
                content.text = L10n.text("Aim stick speed")
            case 7:
                content.text = L10n.text("Edit controls layout")
                content.secondaryText = ControlsLayout.isCustomized ? "Customized" : "Move, resize or hide buttons"
                content.textProperties.color = .systemBlue
            case 1:
                cell.accessoryView = slider(settings.controlScale, 0.7, 1.5, label: "Button size") { [weak self] in self?.settings.controlScale = $0; self?.controlsChanged?() }
                content.text = "Button size"
            case 2:
                cell.accessoryView = slider(settings.controlOpacity, 0.2, 1, label: L10n.text("Button opacity")) { [weak self] in self?.settings.controlOpacity = $0; self?.controlsChanged?() }
                content.text = L10n.text("Button opacity")
            case 3:
                content.text = "Targeting"
                let button = UIButton(configuration: .gray())
                button.configuration?.title = GameSettings.targetingTitles[settings.targetingMode]
                button.menu = UIMenu(children: GameSettings.targetingTitles.enumerated().map { index, title in
                    UIAction(title: title, state: index == settings.targetingMode ? .on : .off) { [weak self] _ in
                        self?.settings.targetingMode = index
                        self?.targetingChanged?()
                        UIView.performWithoutAnimation { self?.tableView.reloadSections([Section.controls.rawValue], with: .none) }
                    }
                })
                button.showsMenuAsPrimaryAction = true
                button.sizeToFit()
                cell.accessoryView = button
            case 6:
                content.text = L10n.text("Hide when a controller is connected")
                content.secondaryText = L10n.text("Touch controls come back as soon as the controller disconnects")
                cell.accessoryView = toggle(settings.hideTouchWithController, label: L10n.text("Hide touch controls with a controller")) { [weak self] in self?.settings.hideTouchWithController = $0 }
            case 8:
                content.text = L10n.text("Keyboard and mouse")
                content.secondaryText = L10n.text("Play with the PC controls (WASD, mouse look). With both connected, touch controls hide")
                cell.accessoryView = toggle(settings.keyboardMouse, label: L10n.text("Keyboard and mouse")) { [weak self] in
                    self?.settings.keyboardMouse = $0
                    if !$0 { KeyboardMouse.shared.releaseAll() }
                }
            case 10:
                content.text = L10n.text("Đảo ngược trục dọc (Invert Y)")
                content.secondaryText = L10n.text("Kéo lên để nhìn xuống, kéo xuống để nhìn lên")
                cell.accessoryView = toggle(settings.invertLookY, label: L10n.text("Đảo ngược trục dọc")) { [weak self] in self?.settings.invertLookY = $0 }
            default:
                content.text = L10n.text("Fire also aims")
                content.secondaryText = L10n.text("Fire locks on first, like the classic mobile GTA games")
                cell.accessoryView = toggle(settings.fireAlsoAims, label: L10n.text("Fire also aims")) { [weak self] in self?.settings.fireAlsoAims = $0 }
            }
        case .gyro:
            let aimRows = settings.gyroAim == .off ? 1 : 3
            if indexPath.row == aimRows {
                content.text = L10n.text("Tilt steering")
                let button = UIButton(configuration: .gray())
                button.configuration?.title = settings.tiltSteer.title
                button.menu = UIMenu(children: TiltSteerMode.allCases.map { mode in
                    UIAction(title: mode.title, state: mode == settings.tiltSteer ? .on : .off) { [weak self] _ in
                        self?.settings.tiltSteer = mode; UIView.performWithoutAnimation { self?.tableView.reloadSections([Section.gyro.rawValue], with: .none) }
                    }
                })
                button.showsMenuAsPrimaryAction = true
                button.sizeToFit()
                cell.accessoryView = button
                cell.selectionStyle = .none
            } else if indexPath.row == aimRows + 1 {
                content.text = "Full lock at \(Int(settings.tiltFullLock))°"
                cell.accessoryView = slider(settings.tiltFullLock, 10, 45, label: L10n.text("Tilt for full steering")) { [weak self] in self?.settings.tiltFullLock = $0.rounded() }
                cell.selectionStyle = .none
            } else if indexPath.row == 0 {
                content.text = L10n.text("Gyro")
                content.secondaryText = settings.gyroAim.title
                let menu = UIMenu(children: GyroAimMode.allCases.map { mode in
                    UIAction(title: mode.title, state: mode == settings.gyroAim ? .on : .off) { [weak self] _ in
                        self?.settings.gyroAim = mode; UIView.performWithoutAnimation { self?.tableView.reloadSections([Section.gyro.rawValue], with: .none) }
                    }
                })
                let button = UIButton(configuration: .gray())
                button.configuration?.title = settings.gyroAim.title
                button.menu = menu
                button.showsMenuAsPrimaryAction = true
                button.sizeToFit()
                cell.accessoryView = button
                cell.selectionStyle = .none
            } else if indexPath.row == 1 {
                content.text = String(format: "Sensitivity %.1f×", settings.gyroSensitivity)
                let slider = UISlider()
                slider.minimumValue = 0.2; slider.maximumValue = 3
                slider.value = Float(settings.gyroSensitivity)
                slider.frame.size.width = 150
                slider.accessibilityLabel = "Gyro sensitivity"
                slider.addAction(UIAction { [weak self, weak slider] _ in
                    guard let self, let slider else { return }
                    self.settings.gyroSensitivity = (Double(slider.value) * 10).rounded() / 10
                    var updated = cell.defaultContentConfiguration()
                    updated.text = String(format: "Sensitivity %.1f×", self.settings.gyroSensitivity)
                    cell.contentConfiguration = updated
                }, for: .valueChanged)
                cell.accessoryView = slider
                cell.selectionStyle = .none
            } else {
                content.text = L10n.text("Invert vertical")
                cell.accessoryView = toggle(settings.gyroInvertY, label: "Invert vertical gyro") { [weak self] in self?.settings.gyroInvertY = $0 }
                cell.selectionStyle = .none
            }
        case .files:
            configureFileCell(cell, &content, fileRows[indexPath.row])
        case .device:
            if indexPath.row == 4 {
                content.text = "Tiếng Việt / English"
                content.secondaryText = L10n.language == "en" ? "English" : "Tiếng Việt"
                cell.accessoryType = .disclosureIndicator
            } else if indexPath.row == 3 {
                content.text = L10n.text("Save game & sao lưu")
                content.secondaryText = L10n.text("Xem tệp lưu, xuất bản sao hoặc khôi phục")
                cell.accessoryType = .disclosureIndicator
            } else if indexPath.row == 0 {
                content.text = settings.tier.summary
                content.textProperties.font = .preferredFont(forTextStyle: .footnote)
                content.textProperties.color = .secondaryLabel
                cell.selectionStyle = .none
            } else if indexPath.row == 1 {
                content.text = L10n.text("Chia sẻ nhật ký hỗ trợ")
                content.secondaryText = L10n.text("One tap. Helps fix crashes and loading problems")
                content.textProperties.color = .systemBlue
            } else {
                content.text = L10n.text("Share log")
                content.secondaryText = L10n.text("Save or send this run's log and the previous one yourself")
                content.textProperties.color = .systemBlue
            }
        }
        content.text = content.text.map(L10n.text)
        content.secondaryText = content.secondaryText.map(L10n.text)
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == Section.cheat.rawValue {
            if isOnline {
                if let openMods { openMods() } else { showModManager() }
            } else if indexPath.row == 0 {
                openCheat?()
            } else {
                if let openMods { openMods() } else { showModManager() }
            }
            return
        }
        if indexPath.section == Section.device.rawValue, indexPath.row == 4 {
            LocalizedUI.chooseLanguage(from: self) { [weak self] in
                self?.title = L10n.text("Cài đặt Mugoat")
                self?.tableView.reloadData()
            }
            return
        }
        if indexPath.section == Section.device.rawValue, indexPath.row == 3 { openSaves?(); return }
        if indexPath.section == Section.device.rawValue, indexPath.row == 1 { shareLogs(from: tableView.cellForRow(at: indexPath)); return }
        if indexPath.section == Section.device.rawValue, indexPath.row == 2 { shareLogs(from: tableView.cellForRow(at: indexPath)); return }
        if indexPath.section == Section.controls.rawValue, indexPath.row == 7 { editLayout?(); return }
        if indexPath.section == Section.mode.rawValue {
            guard indexPath.row < GameMode.allCases.count else { return }
            settings.gameMode = GameMode.allCases[indexPath.row]
            gameModeChanged?()
            UIView.performWithoutAnimation { tableView.reloadSections([Section.mode.rawValue], with: .none) }
            return
        }
        if indexPath.section == Section.files.rawValue { selectFileRow(fileRows[indexPath.row]); return }
        let presets = settings.tier.allowed
        guard indexPath.section == Section.graphics.rawValue, indexPath.row < presets.count else { return }
        settings.graphicsPreset = presets[indexPath.row]
        resolutionChanged?()
        UIView.performWithoutAnimation { tableView.reloadSections([Section.graphics.rawValue], with: .none) }
    }

    // MARK: Game files

    private func makeFileRows() -> [FileRow] {
        let phase = preloader.phase
        let hasFiles = preloader.cachedBytes > 0
        switch phase {
        case .unavailable: return [.status]
        case .idle: return hasFiles ? [.start, .remove] : [.start]
        case .downloading: return [.status, .pause, .cancel]
        case .paused: return [.status, .resume, .cancel] + (hasFiles ? [.remove] : [])
        case .complete: return [.status, .remove]
        }
    }

    @objc private func preloadChanged() {
        let rows = makeFileRows()
        let section = Section.files.rawValue
        // Footer text depends on these; a footer only resizes on a reload.
        let key = "\(rows)|\(preloader.phase)|\(preloader.removing)|\(preloader.lastError ?? "")|\(fileMessage ?? "")|\(preloader.measured)|\(preloader.cachedBytes > 0)"
        if rows != fileRows || key != fileStateKey {
            fileRows = rows
            fileStateKey = key
            UIView.performWithoutAnimation { tableView.reloadSections([section], with: .none) }
            return
        }
        // Same rows: refresh the visible text in place (no flicker).
        for (row, kind) in rows.enumerated() {
            guard let cell = tableView.cellForRow(at: IndexPath(row: row, section: section)) else { continue }
            var content = cell.defaultContentConfiguration()
            content.secondaryTextProperties.color = .secondaryLabel
            configureFileCell(cell, &content, kind)
            cell.contentConfiguration = content
        }
    }

    private func progressText() -> String {
        let percent = Int((preloader.fraction * 100).rounded(.down))
        var text = "\(percent)% · \(AssetPreloader.format(preloader.cachedBytes)) of \(AssetPreloader.format(preloader.totalBytes))"
        if preloader.phase == .downloading {
            if let rate = preloader.bytesPerSecond { text += " · \(AssetPreloader.format(UInt64(rate)))/s" }
            if let seconds = preloader.secondsRemaining { text += " · " + AssetPreloader.formatDuration(seconds) }
        }
        return text
    }

    private func configureFileCell(_ cell: UITableViewCell, _ content: inout UIListContentConfiguration, _ row: FileRow) {
        let total = preloader.measured ? AssetPreloader.format(preloader.totalBytes) : L10n.text("Checking size")
        switch row {
        case .status:
            cell.selectionStyle = .none
            switch preloader.phase {
            case .unavailable(let reason):
                content.text = L10n.text("Download all game files")
                content.secondaryText = reason
                content.textProperties.color = .secondaryLabel
            case .complete:
                content.text = "All files on device"
                content.secondaryText = "\(total) · plays without streaming"
                content.image = UIImage(systemName: "checkmark.circle.fill")
                content.imageProperties.tintColor = Theme.ok
            case .downloading:
                content.text = "Downloading game files"
                content.secondaryText = progressText()
                cell.accessoryView = progressView()
            default:
                content.text = preloader.lastError == nil ? "Download paused" : "Download stopped"
                content.secondaryText = progressText()
                cell.accessoryView = progressView()
            }
        case .start:
            content.text = L10n.text("Download all game files")
            content.textProperties.color = .tintColor
            if preloader.cachedBytes > 0 && preloader.measured {
                content.secondaryText = "\(total) · \(AssetPreloader.format(preloader.cachedBytes)) already on this iPhone"
            } else {
                content.secondaryText = total
            }
            content.image = UIImage(systemName: "arrow.down.circle")
        case .pause:
            content.text = L10n.text("Pause")
            content.textProperties.color = .tintColor
            content.image = UIImage(systemName: "pause.circle")
        case .resume:
            content.text = "Resume download"
            content.textProperties.color = .tintColor
            content.image = UIImage(systemName: "arrow.down.circle")
        case .cancel:
            content.text = "Cancel download"
            content.secondaryText = "Keeps what is already downloaded"
            content.textProperties.color = .systemRed
            content.image = UIImage(systemName: "xmark.circle")
            content.imageProperties.tintColor = .systemRed
        case .remove:
            content.text = preloader.removing ? "Removing files…" : "Remove downloaded files"
            content.secondaryText = engineRunning ? "Available after restarting the app" : "Frees \(AssetPreloader.format(preloader.cachedBytes))"
            content.textProperties.color = engineRunning ? .secondaryLabel : .systemRed
            content.image = UIImage(systemName: "trash")
            content.imageProperties.tintColor = engineRunning ? .secondaryLabel : .systemRed
            cell.selectionStyle = engineRunning ? .none : .default
        }
    }

    private func progressView() -> UIProgressView {
        let bar = UIProgressView(progressViewStyle: .default)
        bar.frame.size.width = 110
        bar.progress = Float(preloader.fraction)
        bar.accessibilityLabel = "Download progress"
        return bar
    }

    private func filesFooter() -> String {
        var text = ""
        if let message = fileMessage ?? preloader.lastError { text = message + "\n\n" }
        switch preloader.phase {
        case .unavailable: return text
        case .complete:
            text += "The game reads everything from this iPhone. Removing the files frees the space; the game then streams again."
        default:
            text += "Saves the whole game on this iPhone (\(preloader.measured ? AssetPreloader.format(preloader.totalBytes) : "about 21 GB")) so it no longer streams from the server. Tailscale must be connected while it downloads. Keep the app open: in the background the download pauses after a short while and continues when you come back. You can play while it downloads."
            if preloader.cachedBytes > 0 && preloader.phase != .downloading {
                text += " Removing files also clears the startup set; the next Play prepares it again."
            }
        }
        return text
    }

    private func selectFileRow(_ row: FileRow) {
        fileMessage = nil
        switch row {
        case .status: return
        case .start, .resume:
            let start = { [weak self] in
                guard let self else { return }
                if let message = self.preloader.start() { self.showAlert("Can't download", message) }
            }
            if row == .start {
                let alert = UIAlertController(title: L10n.text("Download all game files?"),
                    message: "This saves \(AssetPreloader.format(preloader.missingBytes)) more on this iPhone (\(AssetPreloader.format(preloader.availableBytes())) free). Wi-Fi and Tailscale recommended.",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L10n.text("Cancel"), style: .cancel))
                alert.addAction(UIAlertAction(title: L10n.text("Download"), style: .default) { _ in start() })
                present(alert, animated: true)
            } else { start() }
        case .pause: preloader.pause()
        case .cancel: preloader.cancel()
        case .remove:
            guard !engineRunning else { return }
            let alert = UIAlertController(title: L10n.text("Remove downloaded files?"),
                message: "Frees \(AssetPreloader.format(preloader.cachedBytes)). The game will stream from the server again.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.text("Cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: L10n.text("Remove"), style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.preloader.removeDownloads { message in
                    if let message { self.showAlert(L10n.text("Can't remove files"), message) }
                }
            })
            present(alert, animated: true)
        }
        preloadChanged()
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: L10n.text(title), message: L10n.text(message), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func currentSizeText() -> String {
        let screen = view.window?.windowScene?.screen.bounds.size ?? UIScreen.main.bounds.size
        let (w, h) = GraphicsConfiguration.size(for: engineRunning ? bootPreset : settings.graphicsPreset, renderHeight: settings.renderHeight,
                                                screen: screen, matchScreenShape: settings.matchScreenShape)
        return "Renders at \(w)×\(h)"
    }
    /// Uploads the logs after the player confirms, with an optional note (its own screen, so the
    /// keyboard never covers Send in landscape).
    private func sendLog() {
        let screen = SendLogViewController()
        screen.finished = { [weak self] title, message in self?.showAlert(title, message) }
        let nav = UINavigationController(rootViewController: screen)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
    private func shareLogs(from cell: UITableViewCell?) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logs = ["native-port.log", "native-port-previous.log"].map { documents.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !logs.isEmpty else { showAlert(L10n.text("No log yet"), L10n.text("Start the game once, then try again.")); return }
        let sheet = UIActivityViewController(activityItems: logs, applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = cell ?? view
        present(sheet, animated: true)
    }
    private func showModManager() {
        let vc = ModManagerViewController(engineRunning: engineRunning)
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            Theme.styleNavigation(nav)
            nav.modalPresentationStyle = .formSheet
            present(nav, animated: true)
        }
    }
    private func resolutionTitle(_ height: Int) -> String {
        if height == 0 {
            let screen = view.window?.windowScene?.screen.bounds.size ?? UIScreen.main.bounds.size
            let (_, h) = GraphicsConfiguration.size(for: engineRunning ? bootPreset : settings.graphicsPreset, renderHeight: 0, screen: screen, matchScreenShape: settings.matchScreenShape)
            return "Auto (\(h)p)"
        }
        if height == 2160 {
            return height == GraphicsConfiguration.nativeHeight ? "4K Native (2160p)" : "4K (2160p)"
        }
        return height == GraphicsConfiguration.nativeHeight ? "Native (\(height)p)" : "\(height)p"
    }
    private func reloadFooters() {
        UIView.performWithoutAnimation { tableView.reloadSections([Section.graphics.rawValue], with: .none) }
    }
    private func slider(_ value: Double, _ low: Float, _ high: Float, label: String, changed: @escaping (Double) -> Void) -> UISlider {
        let control = UISlider()
        control.minimumValue = low; control.maximumValue = high
        control.value = Float(value)
        control.frame.size.width = 160
        control.accessibilityLabel = label
        control.addAction(UIAction { [weak control] _ in changed(Double(control?.value ?? 0)) }, for: .valueChanged)
        return control
    }
    private func toggle(_ on: Bool, label: String, changed: @escaping (Bool) -> Void) -> UISwitch {
        let control = UISwitch()
        control.isOn = on
        control.accessibilityLabel = label
        control.addAction(UIAction { [weak control] _ in changed(control?.isOn ?? false) }, for: .valueChanged)
        return control
    }
}
