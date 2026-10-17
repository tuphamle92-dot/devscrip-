import SwiftUI
import UIKit

struct CheatItem: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let desc: String
    let category: String
}

let CHEAT_LIST: [CheatItem] = [
    // MARK: - Nhân vật (12)
    CheatItem(code: "UNFREEZE", name: "Gỡ kẹt cảnh / Thoát Cutscene", desc: "Buộc thoát cutscene, mở khóa điều khiển và gỡ treo màn hình", category: "Nhân vật"),
    CheatItem(code: "PAINKILLER", name: "Bất tử 5 phút", desc: "Không nhận sát thương trong 5 phút", category: "Nhân vật"),
    CheatItem(code: "TURTLE", name: "Đầy Máu & Giáp", desc: "Hồi phục 100% máu, giáp và sửa xe", category: "Nhân vật"),
    CheatItem(code: "TOOLUP", name: "Tất cả Vũ khí", desc: "Nhận full tất cả vũ khí và đạn", category: "Nhân vật"),
    CheatItem(code: "LAWYERUP", name: "Xóa sao cảnh sát", desc: "Giảm mức độ truy nã về 0", category: "Nhân vật"),
    CheatItem(code: "FUGITIVE", name: "Tăng 1 sao cảnh sát", desc: "Tăng thêm 1 cấp độ truy nã", category: "Nhân vật"),
    CheatItem(code: "POWERUP", name: "Đầy kỹ năng", desc: "Nạp đầy thanh kỹ năng nhân vật", category: "Nhân vật"),
    CheatItem(code: "CATCHME", name: "Chạy siêu nhanh", desc: "Tăng tốc độ di chuyển tối đa", category: "Nhân vật"),
    CheatItem(code: "GOTGILLS", name: "Bơi siêu nhanh", desc: "Tăng tốc độ bơi dưới nước", category: "Nhân vật"),
    CheatItem(code: "HOPTOIT", name: "Siêu nhảy", desc: "Nhảy cao gấp 10 lần bình thường", category: "Nhân vật"),
    CheatItem(code: "SKYDIVE", name: "Trang bị Dù nhảy", desc: "Nhận dù để nhảy từ trên cao", category: "Nhân vật"),
    CheatItem(code: "LIQUOR", name: "Chế độ say rượu", desc: "Đi đứng lảo đảo hiệu ứng say xỉn", category: "Nhân vật"),

    // MARK: - Phương tiện (13)
    CheatItem(code: "BUZZOFF", name: "Trực thăng Buzzard", desc: "Trực thăng chiến đấu có súng & tên lửa", category: "Phương tiện"),
    CheatItem(code: "COMET", name: "Xe thể thao Comet", desc: "Xe Porsche 2 cửa siêu tốc", category: "Phương tiện"),
    CheatItem(code: "RAPIDGT", name: "Xe đua Rapid GT", desc: "Xe thể thao cao cấp", category: "Phương tiện"),
    CheatItem(code: "ROCKET", name: "Mô tô đua PCJ-600", desc: "Xe máy phân khối lớn tốc độ cao", category: "Phương tiện"),
    CheatItem(code: "OFFROAD", name: "Xe cào cào Sanchez", desc: "Mô tô địa hình vượt đồi núi", category: "Phương tiện"),
    CheatItem(code: "BANDIT", name: "Xe đạp BMX", desc: "Xe đạp biểu diễn nhào lộn", category: "Phương tiện"),
    CheatItem(code: "BARNSTORM", name: "Máy bay Stunt Plane", desc: "Máy bay nhào lộn cánh quạt", category: "Phương tiện"),
    CheatItem(code: "VINEWOOD", name: "Xe Limousine", desc: "Xe sang trọng kéo dài", category: "Phương tiện"),
    CheatItem(code: "TRASHED", name: "Xe rác Trashmaster", desc: "Xe chở rác bọc thép húc xe khác", category: "Phương tiện"),
    CheatItem(code: "DEATHCAR", name: "Xe bọc thép Duke O'Death", desc: "Xe cơ bắp chống đạn chống nổ cực mạnh", category: "Phương tiện"),
    CheatItem(code: "BUBBLES", name: "Tàu ngầm Kraken", desc: "Tàu lặn khám phá đáy đại dương", category: "Phương tiện"),
    CheatItem(code: "FLYSPRAY", name: "Máy bay Duster", desc: "Máy bay cánh quạt cổ điển", category: "Phương tiện"),
    CheatItem(code: "EXTINCT", name: "Thủy phi cơ Dodo", desc: "Máy bay hạ cánh trên mặt nước", category: "Phương tiện"),

    // MARK: - Chiến đấu (4)
    CheatItem(code: "HOTHANDS", name: "Nắm đấm phát nổ", desc: "Đấm kẻ địch văng xa và phát nổ", category: "Chiến đấu"),
    CheatItem(code: "INCENDIARY", name: "Đạn lửa", desc: "Bắn ra đạn thiêu đốt mục tiêu", category: "Chiến đấu"),
    CheatItem(code: "HIGHEX", name: "Đạn nổ", desc: "Mỗi phát bắn tạo ra vụ nổ lớn", category: "Chiến đấu"),
    CheatItem(code: "DEADEYE", name: "Làm chậm khi ngắm", desc: "Làm chậm thời gian khi giữ nút ngắm", category: "Chiến đấu"),

    // MARK: - Thế giới (5)
    CheatItem(code: "SKYFALL", name: "Rơi tự do từ trời", desc: "Thả nhân vật từ trên chín tầng mây", category: "Thế giới"),
    CheatItem(code: "SLOWMO", name: "Làm chậm toàn game", desc: "Hiệu ứng slow-motion điện ảnh", category: "Thế giới"),
    CheatItem(code: "FLOATER", name: "Trọng lực Mặt Trăng", desc: "Xe và người bay lơ lửng nhẹ", category: "Thế giới"),
    CheatItem(code: "MAKEITRAIN", name: "Đổi thời tiết", desc: "Thay đổi nắng, mưa, bão sấm chớp", category: "Thế giới"),
    CheatItem(code: "SNOW", name: "Tuyết rơi", desc: "Kích hoạt hiệu ứng tuyết rơi toàn map", category: "Thế giới")
]

struct SpawnerPreset: Identifiable {
    let id = UUID()
    let name: String
    let model: String
    let icon: String
    let category: String
}

let COMMON_VEHICLES: [SpawnerPreset] = [
    SpawnerPreset(name: "Mercedes-Benz SLK 55 AMG (Mod RPF)", model: "mbslk", icon: "car.side.fill", category: "Xe Mod (RPF)"),
    SpawnerPreset(name: "Karin Sultan", model: "sultan", icon: "car.fill", category: "Xe 4 cửa"),
    SpawnerPreset(name: "Truffade Adder (Bugatti)", model: "adder", icon: "car.side.fill", category: "Siêu xe"),
    SpawnerPreset(name: "Pegassi Zentorno", model: "zentorno", icon: "car.side.fill", category: "Siêu xe"),
    SpawnerPreset(name: "Progen T20 (McLaren)", model: "t20", icon: "car.side.fill", category: "Siêu xe"),
    SpawnerPreset(name: "Armored Kuruma (Chống đạn)", model: "kuruma", icon: "shield.righthalf.filled", category: "Bọc thép"),
    SpawnerPreset(name: "Duke O'Death", model: "duke2", icon: "shield.fill", category: "Bọc thép"),
    SpawnerPreset(name: "Oppressor Mk II (Mô tô bay)", model: "oppressor2", icon: "bolt.car.fill", category: "Đặc biệt"),
    SpawnerPreset(name: "Trực thăng Buzzard Attack", model: "buzzard", icon: "airplane", category: "Máy bay"),
    SpawnerPreset(name: "Pegassi Bati 801", model: "bati", icon: "bicycle", category: "Mô tô"),
    SpawnerPreset(name: "Sanchez (Cào cào)", model: "sanchez", icon: "bicycle", category: "Mô tô"),
    SpawnerPreset(name: "Rhino Tank (Xe tăng)", model: "rhino", icon: "shield.fill", category: "Quân sự")
]

enum CheatInputMode: String, CaseIterable, Identifiable {
    case auto = "Tự động"
    case console = "Console (`)"
    case gamepad = "Gamepad"
    var id: String { rawValue }
}

enum CheatMenuTab: String, CaseIterable, Identifiable {
    case cheats = "Lệnh Cheat"
    case spawner = "🚗 Triệu hồi Xe"
    var id: String { rawValue }
}

final class CheatManager {
    static let shared = CheatManager()
    static var isApplying: Bool { PGIsCheatInProgress() }

    /// Applies a cheat code via Gamepad combo, Console typing, or Auto selection.
    static func apply(code: String, mode: CheatInputMode = .console, completion: ((Bool) -> Void)? = nil) {
        if MugoatOnlineEnabled() {
            completion?(false)
            return
        }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            completion?(false)
            return
        }

        trimmed.withCString { cStr in
            switch mode {
            case .auto, .console:
                PGApplyCheatConsole(cStr)
            case .gamepad:
                PGApplyCheatGamepad(cStr)
            }
        }

        DispatchQueue.main.async {
            completion?(true)
        }
    }
}

struct CheatMenuView: View {
    @Environment(\.dismiss) private var dismiss
    var engineRunning: Bool = true
    @State private var selectedTab: CheatMenuTab = .cheats
    @State private var customCode = ""
    @State private var customVehicleModel = ""
    @State private var searchText = ""
    @State private var inputMode: CheatInputMode = .console
    @State private var toastMessage: String?
    @State private var modVehicles: [String] = []
    let onApply: (String, CheatInputMode) -> Void
    var onSpawnVehicle: ((String) -> Void)? = nil
    var onOpenMods: (() -> Void)? = nil

    private let categories = ["Nhân vật", "Phương tiện", "Chiến đấu", "Thế giới"]

    private var inputModeDescription: String {
        switch inputMode {
        case .auto:
            return "Tự động: Dùng Gamepad combo tức thì cho 30 cheat chuẩn, Console (`~) cho mã xe đặc biệt & nhập tùy chỉnh."
        case .console:
            return "Console (`~): Chuẩn Muguet - Tự động bật thanh gõ console, gõ từng ký tự và nhấn Enter."
        case .gamepad:
            return "Gamepad: Mô phỏng chuỗi nút bấm tay cầm Xbox trực tiếp vào Pad 0 của game."
        }
    }

    private var filteredList: [CheatItem] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return CHEAT_LIST }
        return CHEAT_LIST.filter {
            $0.name.lowercased().contains(q) ||
            $0.code.lowercased().contains(q) ||
            $0.desc.lowercased().contains(q) ||
            $0.category.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationView {
            List {
                if MugoatOnlineEnabled() {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(.yellow)
                            Text("Chế độ Cheat bị vô hiệu hóa khi chơi Online để đảm bảo công bằng. Hãy kiếm tiền mua súng tại Ammu-Nation!")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Section {
                    Picker("Danh mục", selection: $selectedTab) {
                        ForEach(CheatMenuTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if selectedTab == .cheats {
                    Section(header: Text("Phương thức kích hoạt")) {
                        Picker("Chế độ", selection: $inputMode) {
                            ForEach(CheatInputMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(inputModeDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Section(header: Text("Nhập lệnh tùy chỉnh")) {
                        HStack {
                            TextField("Nhập mã lệnh (vd: PAINKILLER)", text: $customCode)
                                .textInputAutocapitalization(.characters)
                                .disableAutocorrection(true)
                            Button(L10n.text("Áp dụng")) {
                                let c = customCode.trimmingCharacters(in: .whitespaces).uppercased()
                                guard !c.isEmpty else { return }
                                apply(c, forcedMode: .console)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.365, green: 0.714, blue: 0.898))
                        }
                        Text("Lệnh tùy chỉnh luôn kích hoạt qua thanh Console (`~) của game.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(categories, id: \.self) { cat in
                        let items = filteredList.filter { $0.category == cat }
                        if !items.isEmpty {
                            Section(header: Text(cat)) {
                                ForEach(items) { item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack {
                                                Text(item.name).fontWeight(.semibold)
                                                Text("(\(item.code))").font(.caption.monospaced()).foregroundStyle(.secondary)
                                            }
                                            Text(item.desc).font(.caption2).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button(action: { apply(item.code) }) {
                                            Text(L10n.text("Bật")).font(.caption.weight(.bold)).padding(.horizontal, 10).padding(.vertical, 4)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.blue)
                                    }
                                }
                            }
                        }
                    }
                } else if selectedTab == .spawner {
                    // MARK: - Vehicle & Mod Spawner
                    Section(header: Text("Gọi xe theo tên Model (Custom Spawn)")) {
                        HStack {
                            TextField("Tên model (vd: mbslk, sultan, t20)", text: $customVehicleModel)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            Button("Triệu hồi") {
                                let m = customVehicleModel.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !m.isEmpty else { return }
                                spawnVehicle(m)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        Text("Nhập mã model bất kỳ từ bản mod add-on hoặc GTA V gốc. Xe sẽ xuất hiện ngay trước mặt nhân vật!")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Section(header: Text("🌟 Xe Mod Đã Cài (DLC Add-ons)")) {
                        if modVehicles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chưa phát hiện xe mod Add-on nào.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Bấm 'Mở Quản lý Mod' bên dưới để nhập tệp .rpf (như mbslk). Cần khởi động lại game sau khi thêm mod mới để engine nạp DLC.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else {
                            ForEach(modVehicles, id: \.self) { model in
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Xe Mod: \(model.uppercased())")
                                            .fontWeight(.bold)
                                        Text("Gói DLC Add-on · Chạm để gọi ngay")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Triệu hồi") {
                                        spawnVehicle(model)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                                    .font(.caption.weight(.bold))
                                }
                            }
                        }
                    }

                    Section(header: Text("🏎️ Phương tiện GTA V phổ biến")) {
                        ForEach(COMMON_VEHICLES) { v in
                            HStack {
                                Image(systemName: v.icon)
                                    .foregroundColor(Color(red: 0.365, green: 0.714, blue: 0.898))
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(v.name).fontWeight(.semibold)
                                    Text("Model: \(v.model) · \(v.category)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Gọi xe") {
                                    spawnVehicle(v.model)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                .font(.caption.weight(.bold))
                            }
                        }
                    }

                    Section(header: Text("Quản lý tệp Mod")) {
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onOpenMods?()
                            }
                        }) {
                            HStack {
                                Image(systemName: "folder.fill.badge.gearshape")
                                    .foregroundColor(.orange)
                                Text("Mở Quản lý Mod (Thêm / Bật / Tắt Mod)")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: selectedTab == .spawner ? "Tìm kiếm phương tiện..." : "Tìm kiếm lệnh cheat...")
            .navigationTitle("Menu Mod & Cheat GTA V")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Đóng")) { dismiss() }
                }
            }
            .onAppear {
                modVehicles = ModRuntime.catalog(ModManagerViewController.modsDirectory).models
            }
            .overlay(alignment: .bottom) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.callout.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 5)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private func apply(_ code: String, forcedMode: CheatInputMode? = nil) {
        if MugoatOnlineEnabled() {
            withAnimation { toastMessage = "Không thể dùng cheat trong Multiplayer Online!" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { toastMessage = nil }
            }
            return
        }
        if !engineRunning {
            withAnimation { toastMessage = "Game chưa chạy: \(code)" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { toastMessage = nil }
            }
            return
        }
        let modeToUse = forcedMode ?? inputMode
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onApply(code, modeToUse)
        }
    }

    private func spawnVehicle(_ model: String) {
        if MugoatOnlineEnabled() {
            withAnimation { toastMessage = "Không thể triệu hồi xe bằng cheat trong Online!" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { toastMessage = nil }
            }
            return
        }
        var clean = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean == "mbs1k" { clean = "mbslk" }
        guard !clean.isEmpty else { return }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onSpawnVehicle?(clean)
        }
    }
}
