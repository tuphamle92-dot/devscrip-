// muguet - Launcher.swift
// Constantin Clerc (c22dev) - 0.1

import SwiftUI
import UIKit
import UniformTypeIdentifiers

let configURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("config.json")

final class Settings: ObservableObject {
    @Published var mode = 2
    @Published var scale = 0.5
    @Published var fps = 60
    @Published var showFPS = true
    @Published var textures = 0
    @Published var touch = 1.5
    @Published var aimSensitivity = 0.8
    @Published var aimMode = "toggle"
    @Published var fireAim = true
    @Published var mute = false
    @Published var multiplayer = false
    @Published var host = false
    @Published var server = "18.143.103.253"
    @Published var name = "Player" + String(Int.random(in: 100...999))
    @Published var roomDigits = String(Int.random(in: 1000...9999))
    @Published var joinCode = ""
    @Published var roomPass = ""
    @Published var roomMode = "create" // "create", "join", "public", "lan"
    @Published var pvp = false
    @Published var promotionSync = false
    @Published var deepOptimization = false
    @Published var maxPlayers = 32

    // Granular GTA V Graphics Options
    @Published var shadowQuality = 1 // 1: Normal, 2: High, 3: Very High
    @Published var shadowDistance = 1.0 // 0.5: Short, 1.0: Normal, 1.5: Far
    @Published var reflectionQuality = 1 // 1: Normal, 2: High, 3: Very High
    @Published var grassQuality = 0 // 0: Normal, 1: High, 2: Very High
    @Published var waterQuality = 0 // 0: Normal, 1: High, 2: Very High
    @Published var particleQuality = 0 // 0: Normal, 1: High, 2: Very High
    @Published var postFx = 0 // 0: Normal, 1: High, 2: Very High
    @Published var anisotropicFiltering = 0 // 0: Off, 4: x4, 8: x8, 16: x16
    @Published var fxaa = true // true / false
    @Published var cityDensity = 0.5 // 0.0: Empty, 0.5: Medium, 1.0: Dense
    @Published var pedDensity = 0.5 // 0.0: Low, 0.5: Medium, 1.0: High
    @Published var distanceScaling = 0.0 // -0.5: Potato, 0.0: Normal, 0.5: Extended

    @Published var buttonScale = 1.0
    @Published var buttonOffsetX = 0.0
    @Published var buttonOffsetY = 0.0
    @Published var buttonOpacity = 0.22
    @Published var stickOffsetX = 0.0
    @Published var stickOffsetY = 0.0
    @Published var customButtons: [Int: [Double]] = [:]
    var extra: [String: Any] = [:]

    func apply120FpsBoost() {
        fps = 120
        scale = 0.5
        textures = 0
        shadowQuality = 1
        shadowDistance = 0.5
        reflectionQuality = 1
        grassQuality = 0
        waterQuality = 0
        particleQuality = 0
        postFx = 0
        anisotropicFiltering = 0
        fxaa = true
        cityDensity = 0.0
        pedDensity = 0.0
        distanceScaling = -0.5
        deepOptimization = true
        promotionSync = true
        do { try save() } catch {}
        muguet_reload_settings()
    }

    func applyLowRamMode(fpsLimit: Int = 30, renderScale: Double = 0.35) {
        fps = fpsLimit
        scale = renderScale
        textures = 0
        shadowQuality = 1
        shadowDistance = 0.5
        reflectionQuality = 1
        grassQuality = 0
        waterQuality = 0
        particleQuality = 0
        postFx = 0
        anisotropicFiltering = 0
        fxaa = false
        cityDensity = 0.0
        pedDensity = 0.0
        distanceScaling = -0.5
        deepOptimization = true
        promotionSync = false
        do { try save() } catch {}
        _ = muguet_apply_low_ram_preset()
        muguet_reload_settings()
    }

    var formattedCreateCode: String {
        let m = mode == 1 ? "S" : "B"
        let p = pvp ? "X" : "P"
        return "\(m)\(p)-\(roomDigits)"
    }

    init() {
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        extra = json
        if let v = json["start_mode"] as? Int, (1...2).contains(v) { mode = v }
        if let v = json["scale"] as? Double { scale = v }
        if let v = json["fps_limit"] as? Int, [30, 60, 120].contains(v) { fps = v }
        if let v = json["show_fps"] as? Bool { showFPS = v }
        if let v = json["max_players"] as? Int, [16, 32, 64].contains(v) { maxPlayers = v }
        if let v = json["texture_quality"] as? Int, (0...2).contains(v) { textures = v }
        if let v = json["touch_sensitivity"] as? Double { touch = max(0.1, min(10.0, v)) }
        if let v = json["aim_sensitivity"] as? Double { aimSensitivity = max(0.1, min(5.0, v)) }
        if let v = json["aim_mode"] as? String, ["toggle", "hold"].contains(v) { aimMode = v }
        if let v = json["fire_aim"] as? Bool { fireAim = v }
        if let v = json["mute"] as? Bool { mute = v }
        if let v = json["multiplayer"] as? Bool { multiplayer = v }
        if let v = json["host"] as? Bool { host = v }
        if let v = json["server"] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty { server = v }
        if let v = json["room_digits"] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty {
            roomDigits = v
        } else if let v = json["room"] as? String {
            let digits = v.filter { $0.isNumber }
            if !digits.isEmpty { roomDigits = String(digits.prefix(4)) }
        }
        if let v = json["join_code"] as? String { joinCode = v }
        if let v = json["room_pass"] as? String { roomPass = v }
        if let v = json["room_mode"] as? String, ["create", "join", "public", "lan"].contains(v) { roomMode = v }
        if let v = json["pvp"] as? Bool { pvp = v }
        if let v = json["promotion_sync"] as? Bool { promotionSync = v }
        if let v = json["deep_optimization"] as? Bool { deepOptimization = v }
        if let v = json["shadow_quality"] as? Int, (1...3).contains(v) { shadowQuality = v }
        if let v = json["shadow_distance"] as? Double { shadowDistance = max(0.5, min(2.0, v)) }
        if let v = json["reflection_quality"] as? Int, (1...3).contains(v) { reflectionQuality = v }
        if let v = json["grass_quality"] as? Int, (0...2).contains(v) { grassQuality = v }
        if let v = json["water_quality"] as? Int, (0...2).contains(v) { waterQuality = v }
        if let v = json["particle_quality"] as? Int, (0...2).contains(v) { particleQuality = v }
        if let v = json["postfx"] as? Int, (0...2).contains(v) { postFx = v }
        if let v = json["anisotropic_filtering"] as? Int, [0, 2, 4, 8, 16].contains(v) { anisotropicFiltering = v }
        if let v = json["fxaa"] as? Bool { fxaa = v }
        if let v = json["city_density"] as? Double { cityDensity = max(0.0, min(1.0, v)) }
        if let v = json["ped_density"] as? Double { pedDensity = max(0.0, min(1.0, v)) }
        if let v = json["distance_scaling"] as? Double { distanceScaling = max(-0.5, min(1.0, v)) }
        if let v = json["button_scale"] as? Double { buttonScale = max(0.6, min(2.0, v)) }
        if let v = json["button_offset_x"] as? Double { buttonOffsetX = max(-150.0, min(150.0, v)) }
        if let v = json["button_offset_y"] as? Double { buttonOffsetY = max(-150.0, min(150.0, v)) }
        if let v = json["button_opacity"] as? Double { buttonOpacity = max(0.1, min(0.9, v)) }
        if let v = json["stick_offset_x"] as? Double { stickOffsetX = max(-100.0, min(150.0, v)) }
        if let v = json["stick_offset_y"] as? Double { stickOffsetY = max(-100.0, min(150.0, v)) }
        if let v = json["player_name"] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty && v != "iPhone" && v != "iPad" {
            name = v
        }
        if let dict = json["custom_buttons"] as? [String: [Double]] {
            for (k, v) in dict {
                if let idx = Int(k), v.count >= 3 {
                    customButtons[idx] = v
                }
            }
        }
        applyCustomLayout()
    }

    func parseJoinCode(_ code: String) {
        let clean = code.trimmingCharacters(in: .whitespaces).uppercased()
        if clean.hasPrefix("S") {
            mode = 1
        } else if clean.hasPrefix("B") {
            mode = 2
        }
        if clean.contains("X") {
            pvp = true
        } else if clean.contains("P") {
            pvp = false
        }
    }

    func save() throws {
        var json = extra
        let srv = server.trimmingCharacters(in: .whitespaces)
        json["server"] = srv.isEmpty ? "18.143.103.253" : srv
        json["multiplayer"] = multiplayer
        json["host"] = (roomMode == "lan")
        json["room_mode"] = roomMode
        json["promotion_sync"] = promotionSync
        json["deep_optimization"] = deepOptimization
        json["max_players"] = maxPlayers
        json["room_digits"] = roomDigits
        json["join_code"] = joinCode

        if multiplayer {
            let srv = server.trimmingCharacters(in: .whitespaces)
            json["server"] = srv.isEmpty ? "18.143.103.253" : srv
            json["multiplayer"] = true
            json["host"] = false
            json["start_mode"] = 1 // Cốt truyện Story Mode cho server AWS iOSVN
            json["room"] = "story"
            json["room_pass"] = ""
            json["pvp"] = true // Server quyết định luật PvP hoặc Co-op
        } else {
            json["start_mode"] = mode
            json["room"] = "default"
            json["room_pass"] = ""
            json["pvp"] = false
        }

        json["scale"] = scale
        json["fps_limit"] = fps
        json["show_fps"] = showFPS
        json["texture_quality"] = textures
        json["shadow_quality"] = shadowQuality
        json["shadow_distance"] = shadowDistance
        json["reflection_quality"] = reflectionQuality
        json["grass_quality"] = grassQuality
        json["water_quality"] = waterQuality
        json["particle_quality"] = particleQuality
        json["postfx"] = postFx
        json["anisotropic_filtering"] = anisotropicFiltering
        json["fxaa"] = fxaa
        json["city_density"] = cityDensity
        json["ped_density"] = pedDensity
        json["distance_scaling"] = distanceScaling
        json["touch_sensitivity"] = (touch * 100).rounded() / 100
        json["aim_sensitivity"] = (aimSensitivity * 100).rounded() / 100
        json["aim_mode"] = aimMode
        json["fire_aim"] = fireAim
        json["mute"] = mute
        json["button_scale"] = (buttonScale * 100).rounded() / 100
        json["button_offset_x"] = (buttonOffsetX * 10).rounded() / 10
        json["button_offset_y"] = (buttonOffsetY * 10).rounded() / 10
        json["button_opacity"] = (buttonOpacity * 100).rounded() / 100
        json["stick_offset_x"] = (stickOffsetX * 10).rounded() / 10
        json["stick_offset_y"] = (stickOffsetY * 10).rounded() / 10
        let nm = name.trimmingCharacters(in: .whitespaces)
        json["player_name"] = nm.isEmpty ? "Player" : nm
        var cbJson: [String: [Double]] = [:]
        for (idx, v) in customButtons {
            cbJson[String(idx)] = v
        }
        json["custom_buttons"] = cbJson
        if json["extra_args"] == nil { json["extra_args"] = [String]() }
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configURL)
        PerformanceHUD.shared.setVisible(showFPS)
    }

    func resetLayout() {
        buttonScale = 1.0
        buttonOffsetX = 0.0
        buttonOffsetY = 0.0
        buttonOpacity = 0.22
        stickOffsetX = 0.0
        stickOffsetY = 0.0
        customButtons.removeAll()
        muguet_reset_button_layout()
        muguet_apply_button_layout()
    }

    func applyCustomLayout() {
        muguet_reset_button_layout()
        for (idx, v) in customButtons {
            if v.count >= 3 {
                muguet_set_button_layout(UInt32(idx), v[0], v[1], v[2])
            }
        }
        muguet_apply_button_layout()
    }
}

@_silgen_name("muguet_import")
func muguet_import(_ zip: UnsafePointer<CChar>, _ progress: @convention(c) (UInt64, UInt64) -> Void) -> Bool
@_silgen_name("muguet_import_error")
func muguet_import_error() -> UnsafePointer<CChar>?
@_silgen_name("muguet_game_ready")
func muguet_game_ready() -> Bool
@_silgen_name("muguet_has_game_code")
func muguet_has_game_code() -> Bool
@_silgen_name("muguet_reload_settings")
func muguet_reload_settings()
@_silgen_name("muguet_apply_cheat")
func muguet_apply_cheat(_ code: UnsafePointer<CChar>)
@_silgen_name("muguet_is_multiplayer")
func muguet_is_multiplayer() -> Bool
@_silgen_name("muguet_toggle_first_person")
func muguet_toggle_first_person()
@_silgen_name("muguet_set_button_layout")
func muguet_set_button_layout(_ idx: UInt32, _ dx: Double, _ dy: Double, _ scale: Double)
@_silgen_name("muguet_reset_button_layout")
func muguet_reset_button_layout()
@_silgen_name("muguet_apply_button_layout")
func muguet_apply_button_layout()
@_silgen_name("muguet_reset_game_settings")
func muguet_reset_game_settings() -> Bool
@_silgen_name("muguet_apply_low_ram_preset")
func muguet_apply_low_ram_preset() -> Bool

final class Importer: ObservableObject {
    static let shared = Importer()
    @Published var ready = muguet_game_ready()
    @Published var progress: Double?
    @Published var error: String?
    private var lastProgressTime = 0.0

    func refreshReady() {
        DispatchQueue.main.async {
            self.ready = muguet_game_ready()
        }
    }

    func importFolder(from url: URL) {
        error = nil
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("game")

        do {
            try fm.createDirectory(at: dest, withIntermediateDirectories: true)
            let items = try fm.contentsOfDirectory(atPath: url.path)
            if items.contains("manifest.json") {
                let targetData = dest.appendingPathComponent("data")
                if fm.fileExists(atPath: targetData.path) { try? fm.removeItem(at: targetData) }
                try fm.copyItem(at: url, to: targetData)
            } else {
                for item in items {
                    let src = url.appendingPathComponent(item)
                    let dst = dest.appendingPathComponent(item)
                    if fm.fileExists(atPath: dst.path) { try? fm.removeItem(at: dst) }
                    try fm.copyItem(at: src, to: dst)
                }
            }
            refreshReady()
        } catch {
            self.error = "Lỗi chép thư mục: \(error.localizedDescription)"
            refreshReady()
        }
    }

    func run(_ url: URL) {
        error = nil
        progress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            // File providers must finish materializing the selected ZIP before
            // Rust seeks to its central directory at the end of the archive.
            var coordinationError: NSError?
            var ok = false
            NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { localURL in
                ok = localURL.path.withCString { muguet_import($0) { done, total in
                    let now = ProcessInfo.processInfo.systemUptime
                    guard done == total || now - Importer.shared.lastProgressTime >= 0.05 else { return }
                    Importer.shared.lastProgressTime = now
                    let p = total > 0 ? Double(done) / Double(total) : 0
                    DispatchQueue.main.async { Importer.shared.progress = p }
                } }
            }
            let message = ok ? nil : coordinationError?.localizedDescription
                ?? muguet_import_error().map { String(cString: $0) } ?? "unknown error"
            DispatchQueue.main.async {
                self.progress = nil
                self.ready = muguet_game_ready()
                if let message { self.error = "Import failed: \(message)" }
            }
        }
    }
}

struct CheatItem: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let desc: String
    let category: String
}

let CHEAT_LIST: [CheatItem] = [
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

    CheatItem(code: "HOTHANDS", name: "Nắm đấm phát nổ", desc: "Đấm kẻ địch văng xa và phát nổ", category: "Chiến đấu"),
    CheatItem(code: "INCENDIARY", name: "Đạn lửa", desc: "Bắn ra đạn thiêu đốt mục tiêu", category: "Chiến đấu"),
    CheatItem(code: "HIGHEX", name: "Đạn nổ", desc: "Mỗi phát bắn tạo ra vụ nổ lớn", category: "Chiến đấu"),
    CheatItem(code: "DEADEYE", name: "Làm chậm khi ngắm", desc: "Làm chậm thời gian khi giữ nút ngắm", category: "Chiến đấu"),

    CheatItem(code: "SKYFALL", name: "Rơi tự do từ trời", desc: "Thả nhân vật từ trên chín tầng mây", category: "Thế giới"),
    CheatItem(code: "SLOWMO", name: "Làm chậm toàn game", desc: "Hiệu ứng slow-motion điện ảnh", category: "Thế giới"),
    CheatItem(code: "FLOATER", name: "Trọng lực Mặt Trăng", desc: "Xe và người bay lơ lửng nhẹ", category: "Thế giới"),
    CheatItem(code: "MAKEITRAIN", name: "Đổi thời tiết", desc: "Thay đổi nắng, mưa, bão sấm chớp", category: "Thế giới"),
    CheatItem(code: "SNOW", name: "Tuyết rơi", desc: "Kích hoạt hiệu ứng tuyết rơi toàn map", category: "Thế giới")
]

struct CheatMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var customCode = ""
    @State private var toastMessage: String?
    let onApply: (String) -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Nhập lệnh tùy chỉnh")) {
                    HStack {
                        TextField("Nhập mã lệnh (vd: PAINKILLER)", text: $customCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button("Áp dụng") {
                            let c = customCode.trimmingCharacters(in: .whitespaces).uppercased()
                            guard !c.isEmpty else { return }
                            apply(c)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                ForEach(["Nhân vật", "Phương tiện", "Chiến đấu", "Thế giới"], id: \.self) { cat in
                    Section(header: Text(cat)) {
                        ForEach(CHEAT_LIST.filter { $0.category == cat }) { item in
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
                                    Text("Bật").font(.caption.weight(.bold)).padding(.horizontal, 10).padding(.vertical, 4)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lệnh Cheat GTA V")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.callout.bold())
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
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func apply(_ code: String) {
        onApply(code)
        withAnimation { toastMessage = "Đã gửi lệnh cheat: \(code)" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}


struct ModItem: Identifiable {
    let id = UUID()
    let name: String
    let fileName: String
    let sizeString: String
    let type: String
    var isEnabled: Bool
    let fileURL: URL
}

final class ModManager: ObservableObject {
    static let shared = ModManager()
    @Published var mods: [ModItem] = []
    @Published var statusMessage: String?

    var modsDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("mods")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() {
        scanMods()
    }

    func scanMods() {
        let fm = FileManager.default
        let dir = modsDir
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else {
            mods = []
            return
        }

        var items: [ModItem] = []
        for url in entries {
            let name = url.lastPathComponent
            guard !name.hasPrefix(".") else { continue }
            let isEnabled = !name.hasSuffix(".disabled")
            let cleanName = isEnabled ? name : String(name.dropLast(9))
            let ext = (cleanName as NSString).pathExtension.lowercased()
            let typeDesc: String
            switch ext {
            case "lua": typeDesc = "LUA Script"
            case "asi": typeDesc = "ASI Plugin"
            case "ytd": typeDesc = "Texture (YTD)"
            case "yft": typeDesc = "Vehicle/Model (YFT)"
            case "ydr": typeDesc = "Object/Prop (YDR)"
            case "meta", "xml": typeDesc = "Config/Meta"
            case "zip": typeDesc = "Archive ZIP"
            default: typeDesc = ext.isEmpty ? "Folder Mod" : ext.uppercased() + " Mod"
            }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            items.append(ModItem(name: cleanName, fileName: name, sizeString: sizeStr, type: typeDesc, isEnabled: isEnabled, fileURL: url))
        }
        items.sort { $0.name.lowercased() < $1.name.lowercased() }
        DispatchQueue.main.async {
            self.mods = items
        }
    }

    func toggleMod(_ item: ModItem) {
        let fm = FileManager.default
        let currentURL = item.fileURL
        let newURL: URL
        if item.isEnabled {
            newURL = currentURL.deletingLastPathComponent().appendingPathComponent(item.fileName + ".disabled")
        } else {
            let newName = item.fileName.hasSuffix(".disabled") ? String(item.fileName.dropLast(9)) : item.fileName
            newURL = currentURL.deletingLastPathComponent().appendingPathComponent(newName)
        }
        try? fm.moveItem(at: currentURL, to: newURL)
        scanMods()
    }

    func deleteMod(_ item: ModItem) {
        try? FileManager.default.removeItem(at: item.fileURL)
        scanMods()
    }

    func installMod(from sourceURL: URL) {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        let dest = modsDir.appendingPathComponent(sourceURL.lastPathComponent)
        if fm.fileExists(atPath: dest.path) {
            try? fm.removeItem(at: dest)
        }
        do {
            try fm.copyItem(at: sourceURL, to: dest)
            scanMods()
            statusMessage = "Đã cài mod: \(sourceURL.lastPathComponent)"
        } catch {
            statusMessage = "Lỗi cài mod: \(error.localizedDescription)"
        }
    }
}

func loadControlIcon(named name: String) -> UIImage? {
    if let img = UIImage(named: name) { return img }
    if let path = Bundle.main.path(forResource: name, ofType: "png", inDirectory: "ControlIcons"),
       let img = UIImage(contentsOfFile: path) { return img }
    if let path = Bundle.main.path(forResource: name, ofType: "png"),
       let img = UIImage(contentsOfFile: path) { return img }
    return nil
}

struct HUDButtonDef: Identifiable {
    let id: Int
    let name: String
    let label: String
    let anchorType: AnchorType
    let baseOffset: CGPoint
    let baseRadius: CGFloat
}

enum AnchorType {
    case topLeft
    case topRight
    case bottomRight
    case stick
}

let HUD_BUTTON_DEFS: [HUDButtonDef] = [
    HUDButtonDef(id: 0, name: "FIRE (Bắn / Ga)", label: "FIRE", anchorType: .bottomRight, baseOffset: CGPoint(x: 62, y: 68), baseRadius: 44),
    HUDButtonDef(id: 1, name: "AIM (Ngắm / Phanh)", label: "AIM", anchorType: .bottomRight, baseOffset: CGPoint(x: 158, y: 46), baseRadius: 31),
    HUDButtonDef(id: 2, name: "JUMP (Nhảy / Phanh tay)", label: "JUMP", anchorType: .bottomRight, baseOffset: CGPoint(x: 58, y: 168), baseRadius: 28),
    HUDButtonDef(id: 3, name: "ENTER (Lên/xuống xe)", label: "ENTER", anchorType: .bottomRight, baseOffset: CGPoint(x: 140, y: 132), baseRadius: 26),
    HUDButtonDef(id: 4, name: "RELOAD (Nạp đạn / Còi)", label: "RELOAD", anchorType: .bottomRight, baseOffset: CGPoint(x: 222, y: 98), baseRadius: 24),
    HUDButtonDef(id: 5, name: "WEAPON (Vũ khí)", label: "WEAPON", anchorType: .topRight, baseOffset: CGPoint(x: 30, y: 30), baseRadius: 22),
    HUDButtonDef(id: 6, name: "COVER (Núp / Radio)", label: "COVER", anchorType: .topRight, baseOffset: CGPoint(x: 84, y: 30), baseRadius: 22),
    HUDButtonDef(id: 7, name: "CROUCH (Ngồi / Nhìn sau)", label: "CROUCH", anchorType: .topRight, baseOffset: CGPoint(x: 138, y: 30), baseRadius: 22),
    HUDButtonDef(id: 8, name: "CAM (Góc camera)", label: "CAM", anchorType: .topRight, baseOffset: CGPoint(x: 192, y: 30), baseRadius: 22),
    HUDButtonDef(id: 9, name: "MENU (Muguet Menu)", label: "MENU", anchorType: .topRight, baseOffset: CGPoint(x: 246, y: 30), baseRadius: 22),
    HUDButtonDef(id: 10, name: "PAUSE (Tạm dừng)", label: "PAUSE", anchorType: .topLeft, baseOffset: CGPoint(x: 30, y: 30), baseRadius: 22),
    HUDButtonDef(id: 11, name: "PHONE (Điện thoại)", label: "PHONE", anchorType: .topLeft, baseOffset: CGPoint(x: 84, y: 30), baseRadius: 22),
    HUDButtonDef(id: 12, name: "MENU KEYS (Phím mũi tên)", label: "MENU\nKEYS", anchorType: .topLeft, baseOffset: CGPoint(x: 138, y: 30), baseRadius: 22),
    HUDButtonDef(id: 13, name: "SWITCH (Đổi nhân vật)", label: "SWITCH", anchorType: .topLeft, baseOffset: CGPoint(x: 192, y: 30), baseRadius: 22),
    HUDButtonDef(id: 14, name: "1ST POV (Góc nhìn thứ 1)", label: "1ST\nPOV", anchorType: .topLeft, baseOffset: CGPoint(x: 246, y: 30), baseRadius: 22),
    HUDButtonDef(id: 15, name: "FIRE phụ (Bắn trái)", label: "FIRE", anchorType: .topLeft, baseOffset: CGPoint(x: 45, y: 112), baseRadius: 29),
    HUDButtonDef(id: 16, name: "JOYSTICK (Cần di chuyển)", label: "", anchorType: .stick, baseOffset: CGPoint(x: 0, y: 0), baseRadius: 58)
]

struct HUDEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: Settings
    @State private var selectedId: Int = 0
    @State private var offsets: [Int: CGSize] = [:]
    @State private var scales: [Int: Double] = [:]
    @State private var draggingId: Int? = nil
    @State private var dragTranslation: CGSize = .zero
    @State private var toastMessage: String?
    @State private var isCollapsed: Bool = false
    @State private var manualDockTop: Bool? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Subtle grid background
                Path { path in
                    let step: CGFloat = 40
                    for x in stride(from: 0, through: geo.size.width, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for y in stride(from: 0, through: geo.size.height, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                .ignoresSafeArea()

                // Screen center crosshair
                Path { path in
                    let cx = geo.size.width / 2
                    let cy = geo.size.height / 2
                    path.move(to: CGPoint(x: cx - 20, y: cy))
                    path.addLine(to: CGPoint(x: cx + 20, y: cy))
                    path.move(to: CGPoint(x: cx, y: cy - 20))
                    path.addLine(to: CGPoint(x: cx, y: cy + 20))
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 1)

                // Render Buttons Canvas
                ForEach(HUD_BUTTON_DEFS) { def in
                    renderButton(def, in: geo)
                }

                // Floating Dynamic Toolbar (never obscures selected button)
                VStack(spacing: 6) {
                    if isCollapsed {
                        if shouldDockTop(in: geo) {
                            collapsedBar(geo: geo, isTop: true)
                        } else {
                            collapsedBar(geo: geo, isTop: false)
                        }
                    } else {
                        let isTop = shouldDockTop(in: geo)
                        if isTop {
                            editorToolbar(geo: geo, isTop: true)
                            selectedButtonControls
                        } else {
                            selectedButtonControls
                            editorToolbar(geo: geo, isTop: false)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                // Disable only the transparent background; disabling this parent
                // also disables its toolbar buttons and sliders.
                .background(Color.clear.allowsHitTesting(false))
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: shouldDockTop(in: geo) ? .top : .bottom)
                .animation(.easeInOut(duration: 0.25), value: isCollapsed)
                .animation(.easeInOut(duration: 0.25), value: manualDockTop)
                .animation(.easeInOut(duration: 0.25), value: selectedId)

                // Toast notification
                if let msg = toastMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.callout.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.85))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.blue, lineWidth: 1))
                            .shadow(radius: 6)
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "hudCanvas")
        }
        .onAppear(perform: loadLayout)
    }

    private func shouldDockTop(in geo: GeometryProxy) -> Bool {
        if let manual = manualDockTop { return manual }
        return false
    }

    private func editorToolbar(geo: GeometryProxy, isTop: Bool) -> some View {
        HStack(spacing: 10) {
            Button("Hủy") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Button(action: {
                let current = shouldDockTop(in: geo)
                manualDockTop = !current
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isTop ? "arrow.down.to.line" : "arrow.up.to.line")
                    Text(isTop ? "Xuống dưới" : "Lên trên")
                }
                .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .tint(.cyan)

            Spacer()

            Text("HUD EDITOR")
                .font(.subheadline.bold())
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                isCollapsed = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                    Text("Thu gọn")
                }
                .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .tint(.orange)

            Button("Đặt lại tất cả") {
                for i in 0..<17 {
                    offsets[i] = .zero
                    scales[i] = 1.0
                }
                showToast("Đã đưa toàn bộ nút về mặc định")
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button("Lưu & Áp dụng") {
                saveLayout()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(true)
    }

    private func collapsedBar(geo: GeometryProxy, isTop: Bool) -> some View {
        HStack(spacing: 12) {
            Button("Hủy") { dismiss() }
                .buttonStyle(.bordered)
                .tint(.secondary)

            Spacer()

            Button(action: { isCollapsed = false }) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Hiện bảng HUD Editor")
                }
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Spacer()

            Button("Lưu & Áp dụng") {
                saveLayout()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 6)
        .allowsHitTesting(true)
    }

    private var selectedButtonControls: some View {
        let currentDef = HUD_BUTTON_DEFS.first(where: { $0.id == selectedId }) ?? HUD_BUTTON_DEFS[0]
        let currentScale = scales[selectedId] ?? 1.0

        return HStack(spacing: 14) {
            // Button selector picker
            Menu {
                ForEach(HUD_BUTTON_DEFS) { def in
                    Button(def.name) {
                        selectedId = def.id
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentDef.name)
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider().frame(height: 20)

            // Scale slider & buttons
            HStack(spacing: 6) {
                Text("Cỡ:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: { adjustScale(-0.05) }) {
                    Image(systemName: "minus.circle")
                        .font(.caption.bold())
                }

                Slider(value: Binding(
                    get: { scales[selectedId] ?? 1.0 },
                    set: { scales[selectedId] = (round($0 * 20) / 20) }
                ), in: 0.5...2.2, step: 0.05)
                .frame(width: 110)

                Button(action: { adjustScale(0.05) }) {
                    Image(systemName: "plus.circle")
                        .font(.caption.bold())
                }

                Text(String(format: "%.2f×", currentScale))
                    .font(.caption.monospacedDigit())
                    .frame(width: 42, alignment: .trailing)
            }

            Divider().frame(height: 20)

            // D-Pad nudge arrows
            HStack(spacing: 3) {
                Text("Dời:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button(action: { nudge(dx: -4, dy: 0) }) {
                    Image(systemName: "arrow.left.square.fill")
                }
                Button(action: { nudge(dx: 0, dy: -4) }) {
                    Image(systemName: "arrow.up.square.fill")
                }
                Button(action: { nudge(dx: 0, dy: 4) }) {
                    Image(systemName: "arrow.down.square.fill")
                }
                Button(action: { nudge(dx: 4, dy: 0) }) {
                    Image(systemName: "arrow.right.square.fill")
                }
            }
            .font(.body)

            Divider().frame(height: 20)

            Button("Đặt lại nút") {
                offsets[selectedId] = .zero
                scales[selectedId] = 1.0
                showToast("Đã đặt lại \(currentDef.name)")
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .allowsHitTesting(true)
    }

    private func renderButton(_ def: HUDButtonDef, in geo: GeometryProxy) -> some View {
        let isSelected = (selectedId == def.id)
        let pos = buttonCenter(for: def, in: geo)
        let bScale = CGFloat(settings.buttonScale)
        let cScale = CGFloat(scales[def.id] ?? 1.0)
        let radius = def.baseRadius * bScale * cScale
        let diameter = radius * 2.0

        return ZStack {
            if def.id == 16 {
                Circle()
                    .stroke(isSelected ? Color.yellow : Color.white.opacity(0.35), lineWidth: isSelected ? 3 : 1.5)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                    .frame(width: diameter, height: diameter)
                Circle()
                    .fill(isSelected ? Color.yellow.opacity(0.7) : Color.white.opacity(0.35))
                    .frame(width: diameter * (26.0 / 58.0), height: diameter * (26.0 / 58.0))
            } else {
                Circle()
                    .stroke(isSelected ? Color.yellow : Color.white.opacity(0.4), lineWidth: isSelected ? 3 : 1.5)
                    .background(Circle().fill(isSelected ? Color.white.opacity(0.45) : Color.white.opacity(settings.buttonOpacity)))
                    .frame(width: diameter, height: diameter)
                    .shadow(color: isSelected ? Color.yellow.opacity(0.8) : Color.black.opacity(0.3), radius: isSelected ? 6 : 2)

                Text(def.label)
                    .font(.system(size: max(8, min(16, radius * 0.42)), weight: .bold))
                    .foregroundColor(Color.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
        }
        // Keep the hit region the size of the button, before positioning it.
        .frame(width: diameter, height: diameter)
        .contentShape(Circle().scale(1.3))
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("hudCanvas"))
                .onChanged { value in
                    if selectedId != def.id {
                        selectedId = def.id
                    }
                    draggingId = def.id
                    dragTranslation = value.translation
                }
                .onEnded { value in
                    let base = offsets[def.id] ?? .zero
                    offsets[def.id] = CGSize(
                        width: base.width + value.translation.width,
                        height: base.height + value.translation.height
                    )
                    dragTranslation = .zero
                    draggingId = nil
                }
        )
        .position(x: pos.x, y: pos.y)
    }

    private func buttonCenter(for def: HUDButtonDef, in geo: GeometryProxy) -> CGPoint {
        let sw = geo.size.width
        let sh = geo.size.height

        let bScale = CGFloat(settings.buttonScale)
        let bOx = CGFloat(settings.buttonOffsetX)
        let bOy = CGFloat(settings.buttonOffsetY)

        let saved = offsets[def.id] ?? .zero
        let currentDrag = (draggingId == def.id) ? dragTranslation : .zero
        let cDx = saved.width + currentDrag.width
        let cDy = saved.height + currentDrag.height
        let cScale = CGFloat(scales[def.id] ?? 1.0)

        var x: CGFloat = 0
        var y: CGFloat = 0

        switch def.anchorType {
        case .bottomRight:
            x = sw - def.baseOffset.x * bScale - bOx + cDx
            y = sh - def.baseOffset.y * bScale - bOy + cDy
        case .topRight:
            x = sw - def.baseOffset.x * bScale + cDx
            y = def.baseOffset.y * bScale + cDy
        case .topLeft:
            x = def.baseOffset.x * bScale + cDx
            y = def.baseOffset.y * bScale + cDy
        case .stick:
            let sOx = CGFloat(settings.stickOffsetX)
            let sOy = CGFloat(settings.stickOffsetY)
            let stickRadius = 58.0 * bScale * cScale
            x = 40.0 + stickRadius + sOx + cDx
            y = sh - 30.0 - stickRadius - sOy + cDy
        }

        return CGPoint(x: x, y: y)
    }

    private func loadLayout() {
        for i in 0..<17 {
            if let arr = settings.customButtons[i], arr.count >= 3 {
                offsets[i] = CGSize(width: arr[0], height: arr[1])
                scales[i] = arr[2]
            } else {
                offsets[i] = .zero
                scales[i] = 1.0
            }
        }
    }

    private func saveLayout() {
        for i in 0..<17 {
            let off = offsets[i] ?? .zero
            let sc = scales[i] ?? 1.0
            if abs(off.width) < 0.5 && abs(off.height) < 0.5 && abs(sc - 1.0) < 0.01 {
                settings.customButtons.removeValue(forKey: i)
            } else {
                settings.customButtons[i] = [Double(off.width), Double(off.height), sc]
            }
        }
        do { try settings.save() } catch {}
        settings.applyCustomLayout()
    }

    private func adjustScale(_ delta: Double) {
        let current = scales[selectedId] ?? 1.0
        let next = max(0.5, min(2.2, (round((current + delta) * 20) / 20)))
        scales[selectedId] = next
    }

    private func nudge(dx: CGFloat, dy: CGFloat) {
        let current = offsets[selectedId] ?? .zero
        offsets[selectedId] = CGSize(width: current.width + dx, height: current.height + dy)
    }

    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { toastMessage = nil }
        }
    }
}

// MARK: - Port Theme & Styling

enum PortTheme {
    static let accent = Color(red: 0.34, green: 0.93, blue: 0.77)
    static let accentDeep = Color(red: 0.18, green: 0.76, blue: 0.66)
    static let ok = Color(red: 0.30, green: 0.85, blue: 0.47)
    static let warning = Color(red: 1.0, green: 0.78, blue: 0.26)
    static let problem = Color(red: 1.0, green: 0.42, blue: 0.38)
    static let night = Color(red: 0.035, green: 0.055, blue: 0.095)
    static let panelStroke = Color(white: 1.0, opacity: 0.12)
    static let panelBackground = Color(white: 1.0, opacity: 0.08)
    static let secondaryText = Color(white: 1.0, opacity: 0.68)
    static let tertiaryText = Color(white: 1.0, opacity: 0.45)
}

struct PortGlassButton: View {
    let title: String
    let symbol: String
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PortTheme.accent)
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(PortTheme.accent.opacity(0.18))
                        .foregroundStyle(PortTheme.accent)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PortTheme.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 1.0, opacity: 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PortTheme.panelStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PortModeCard: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? PortTheme.accent : .white)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? PortTheme.accent : .white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? PortTheme.accent.opacity(0.14) : Color(white: 1.0, opacity: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? PortTheme.accent : PortTheme.panelStroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PortPrimaryButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .heavy))
                Text(title)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(Color(red: 0.02, green: 0.13, blue: 0.15))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [PortTheme.accent, PortTheme.accentDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: PortTheme.accent.opacity(0.35), radius: 14, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct PortBackdrop: View {
    var body: some View {
        ZStack {
            PortTheme.night.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.045, green: 0.17, blue: 0.18, opacity: 0.8),
                    PortTheme.night,
                    Color(red: 0.11, green: 0.10, blue: 0.22, opacity: 0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    PortTheme.night.opacity(0.92),
                    PortTheme.night.opacity(0.55),
                    PortTheme.night.opacity(0.1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Dedicated Settings Sheets

struct GraphicsSettingsSheet: View {
    @ObservedObject var s: Settings
    let L: (String, String) -> String
    let onReset: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(L("Tên người chơi", "Player Name")) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(PortTheme.accent)
                        TextField(L("Nhập tên người chơi...", "Enter player name..."), text: $s.name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                }

                Section(L("Cấu hình nhanh (Presets)", "Quick Presets")) {
                    Button(action: {
                        s.applyLowRamMode(fpsLimit: 60, renderScale: 0.5)
                    }) {
                        HStack {
                            Image(systemName: "speedometer")
                            Text(L("Cấu hình Cân bằng · 60 FPS (Scale 50%)", "Balanced Preset · 60 FPS (50% Scale)"))
                        }
                    }

                    Button(action: {
                        s.apply120FpsBoost()
                    }) {
                        HStack {
                            Image(systemName: "bolt.fill").foregroundStyle(.yellow)
                            Text(L("Thử Boost 120 FPS (Màn hình ProMotion)", "120 FPS Boost (ProMotion)"))
                        }
                    }

                    Button(action: {
                        s.applyLowRamMode(fpsLimit: 30, renderScale: 0.35)
                    }) {
                        HStack {
                            Image(systemName: "leaf.fill").foregroundStyle(.green)
                            Text(L("Potato Mode · 30 FPS (Scale 35% - Tiết kiệm RAM)", "Potato Mode · 30 FPS (35% Scale)"))
                        }
                    }
                }

                Section(L("Độ phân giải & FPS", "Display & Frame Rate")) {
                    Picker(L("Giới hạn FPS", "Frame Rate Limit"), selection: $s.fps) {
                        Text("30 FPS (" + L("Tiết kiệm pin", "Battery Saver") + ")").tag(30)
                        Text("60 FPS (" + L("Mặc định mượt mà", "Default Smooth") + ")").tag(60)
                        Text("120 FPS (" + L("Mở khóa ProMotion", "120 FPS ProMotion") + ")").tag(120)
                    }

                    Picker(L("Độ phân giải hiển thị", "Resolution Scale"), selection: $s.scale) {
                        Text("35 % (" + L("Siêu nhẹ", "Potato") + ")").tag(0.35)
                        Text("50 % (" + L("Nhẹ / Khuyên dùng", "Low / Recommended") + ")").tag(0.5)
                        Text("65 % (" + L("Cân bằng", "Balanced") + ")").tag(0.65)
                        Text("75 % (" + L("Rõ nét", "Crisp") + ")").tag(0.75)
                        Text("100 % (" + L("Gốc", "Native 100%") + ")").tag(1.0)
                    }

                    Picker(L("Chất lượng Texture", "Texture Quality"), selection: $s.textures) {
                        Text(L("Bình thường (Ít tốn RAM)", "Normal (Low RAM)")).tag(0)
                        Text(L("Cao", "High")).tag(1)
                        Text(L("Rất cao", "Very High")).tag(2)
                    }

                    Toggle(L("Hiển thị FPS, thời gian khung hình & RAM", "Show FPS, Frame Time & RAM HUD"), isOn: $s.showFPS)
                    Toggle(L("Đồng bộ nhịp màn hình (V-Sync)", "Display Sync (V-Sync)"), isOn: $s.promotionSync)
                    Toggle(L("Tối ưu sâu (Giảm hiệu ứng nặng)", "Deep Optimization"), isOn: $s.deepOptimization)
                }

                Section(L("Đồ họa chi tiết GTA V", "Granular GTA V Graphics")) {
                    Picker(L("Chất lượng Đổ bóng", "Shadows"), selection: $s.shadowQuality) {
                        Text(L("Bình thường (Mượt nhất)", "Normal (Fastest)")).tag(1)
                        Text(L("Cao", "High")).tag(2)
                        Text(L("Rất cao", "Very High")).tag(3)
                    }

                    Picker(L("Khoảng cách Đổ bóng", "Shadow Distance"), selection: $s.shadowDistance) {
                        Text(L("Ngắn (0.5× - Tiết kiệm RAM)", "Short (0.5×)")).tag(0.5)
                        Text(L("Tiêu chuẩn (1.0×)", "Normal (1.0×)")).tag(1.0)
                        Text(L("Xa (1.5×)", "Far (1.5×)")).tag(1.5)
                    }

                    Picker(L("Chất lượng Phản chiếu", "Reflections"), selection: $s.reflectionQuality) {
                        Text(L("Bình thường", "Normal")).tag(1)
                        Text(L("Cao", "High")).tag(2)
                        Text(L("Rất cao", "Very High")).tag(3)
                    }

                    Picker(L("Cỏ cây (Grass)", "Grass Quality"), selection: $s.grassQuality) {
                        Text(L("Bình thường (Chống tụt FPS)", "Normal (Best FPS)")).tag(0)
                        Text(L("Cao", "High")).tag(1)
                        Text(L("Rất cao", "Very High")).tag(2)
                    }

                    Picker(L("Mặt nước (Water)", "Water Quality"), selection: $s.waterQuality) {
                        Text(L("Bình thường", "Normal")).tag(0)
                        Text(L("Cao", "High")).tag(1)
                        Text(L("Rất cao", "Very High")).tag(2)
                    }

                    Toggle(L("Khử răng cưa viền (FXAA)", "FXAA Anti-aliasing"), isOn: $s.fxaa)

                    Picker(L("Mật độ Xe cộ", "Traffic Density"), selection: $s.cityDensity) {
                        Text(L("Vắng (0% - Nhẹ nhất)", "Low (0%)")).tag(0.0)
                        Text(L("Vừa phải (50%)", "Medium (50%)")).tag(0.5)
                        Text(L("Đông đúc (100%)", "High (100%)")).tag(1.0)
                    }

                    Picker(L("Mật độ Người đi bộ", "Pedestrians"), selection: $s.pedDensity) {
                        Text(L("Thấp (0% - Tiết kiệm RAM)", "Low (0%)")).tag(0.0)
                        Text(L("Vừa phải (50%)", "Medium (50%)")).tag(0.5)
                        Text(L("Đông đúc (100%)", "High (100%)")).tag(1.0)
                    }

                    Picker(L("Tầm nhìn xa (LOD)", "Distance Scaling"), selection: $s.distanceScaling) {
                        Text(L("Tiết kiệm RAM (-0.5)", "Potato (-0.5)")).tag(-0.5)
                        Text(L("Tiêu chuẩn (0.0)", "Default (0.0)")).tag(0.0)
                        Text(L("Tầm nhìn xa (+0.5)", "Extended (+0.5)")).tag(0.5)
                    }
                }

                Section(L("Điều khiển & Góc nhìn", "Look & Aim Controls")) {
                    HStack {
                        Text(L("Độ nhạy góc nhìn", "Look Sensitivity"))
                        Slider(value: $s.touch, in: 0.25...6.0, step: 0.25)
                        Text(String(format: "%.2f×", s.touch)).monospacedDigit().frame(width: 50, alignment: .trailing)
                    }

                    Picker(L("Chế độ nút ngắm", "Aim Button Mode"), selection: $s.aimMode) {
                        Text(L("Chạm bật/tắt (Toggle)", "Tap Toggle")).tag("toggle")
                        Text(L("Giữ để ngắm (Hold)", "Hold to Aim")).tag("hold")
                    }

                    Toggle(L("Tự ngắm khi bấm bắn", "Aim While Firing"), isOn: $s.fireAim)

                    HStack {
                        Text(L("Độ nhạy khi ngắm", "Aim Sensitivity"))
                        Slider(value: $s.aimSensitivity, in: 0.1...3.0, step: 0.1)
                        Text(String(format: "%.2f×", s.aimSensitivity)).monospacedDigit().frame(width: 50, alignment: .trailing)
                    }

                    Toggle(L("Tắt âm thanh game (Mute)", "Mute Audio"), isOn: $s.mute)
                }

                Section {
                    Button(role: .destructive, action: onReset) {
                        Label(L("Khôi phục đồ họa mặc định (Sửa màn hình đen)", "Reset Graphics to Safe Default"), systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle(L("Đồ họa & FPS", "Graphics & FPS"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Xong", "Done")) {
                        try? s.save()
                        muguet_reload_settings()
                        dismiss()
                    }
                    .font(.body.bold())
                }
            }
        }
    }
}

struct MultiplayerSheet: View {
    @ObservedObject var s: Settings
    let L: (String, String) -> String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(L("Kết nối Online", "Online Connection")) {
                    Toggle(L("Bật Multiplayer", "Enable Multiplayer"), isOn: $s.multiplayer)

                    if s.multiplayer {
                        HStack {
                            Text(L("Địa chỉ IP Server:", "Server IP:"))
                                .fontWeight(.semibold)
                            TextField("18.143.103.253", text: $s.server)
                                .keyboardType(.numbersAndPunctuation)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(spacing: 8) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text(L("Server AWS iOSVN Singapore · Cốt truyện: Đua xe Los Santos", "AWS Singapore Server · Story: Franklin & Lamar Race"))
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }

                Section(L("Quy tắc Server & Chế độ", "Server Rules & Story Mode")) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.righthalf.filled")
                            .foregroundStyle(.blue)
                        Text(L("Luật PvP / Co-op sẽ tự động theo cấu hình của Server bạn tham gia.", "PvP / Co-op rules are automatically dictated by the server host."))
                            .font(.caption)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(.orange)
                        Text(L("Cốt truyện bắt đầu ngay từ sự kiện đua xe thu hồi 2 siêu xe sau khi cướp tiền (Franklin & Lamar), bỏ qua đoạn tuyết dài.", "Story Mode starts right at the Los Santos Franklin & Lamar car race after prologue."))
                            .font(.caption)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.red)
                        Text(L("Lệnh Cheat tự động khóa trong chế độ Online để đảm bảo tính công bằng.", "Cheats are strictly locked in Multiplayer to ensure fair gameplay."))
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(L("Chơi Online (IP)", "Multiplayer (IP)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Xong", "Done")) {
                        try? s.save()
                        dismiss()
                    }
                    .font(.body.bold())
                }
            }
        }
    }
}

struct ModManagerSheet: View {
    @ObservedObject var modManager: ModManager
    @Binding var pickingMod: Bool
    let L: (String, String) -> String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Button(action: { pickingMod = true }) {
                            Label(L("Thêm Mod (+)", "Install Mod (+)"), systemImage: "plus.circle.fill")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)

                        Spacer()

                        Button(action: { modManager.scanMods() }) {
                            Label(L("Làm mới", "Refresh"), systemImage: "arrow.clockwise")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                    }

                    if let msg = modManager.statusMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                }

                Section(L("Danh sách Mod đã cài", "Installed Mods")) {
                    if modManager.mods.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("Chưa có mod nào được cài đặt.", "No mods installed yet."))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(L("Bấm nút '+ Thêm Mod' để chọn file mod (.lua, .ytd, .yft, .meta, .asi, .zip), hoặc sao chép vào Files > Trên iPhone > Mugoat > mods.", "Tap '+ Install Mod' to pick mod files, or copy into Files > Mugoat > mods."))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(modManager.mods) { mod in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mod.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(mod.isEnabled ? .white : .secondary)
                                    HStack(spacing: 6) {
                                        Text(mod.type)
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.purple.opacity(0.25))
                                            .clipShape(Capsule())
                                        Text(mod.sizeString)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        if !mod.isEnabled {
                                            Text(L("(Đã tắt)", "(Disabled)"))
                                                .font(.caption2.bold())
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { mod.isEnabled },
                                    set: { _ in modManager.toggleMod(mod) }
                                ))
                                .labelsHidden()

                                Button(action: { modManager.deleteMod(mod) }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .padding(.leading, 6)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("Quản lý Mod", "Mod Manager"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Xong", "Done")) { dismiss() }
                        .font(.body.bold())
                }
            }
        }
    }
}

struct SaveGameSheet: View {
    let L: (String, String) -> String
    let onShareSaves: () -> Void
    let onShareLogs: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(L("Sao lưu & Xuất Save", "Backup & Share Saves")) {
                    Button(action: onShareSaves) {
                        Label(L("Chia sẻ / Sao lưu Save Game", "Share / Backup Save Game"), systemImage: "square.and.arrow.up.fill")
                    }
                    Text(L("File save game được lưu trữ an toàn trong thư mục Files > Trên iPhone > Mugoat > saves.", "Save files are safely located in Files > Mugoat > saves."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(L("Nhật ký & Chẩn đoán", "Diagnostics & Logs")) {
                    Button(action: onShareLogs) {
                        Label(L("Chia sẻ nhật ký chẩn đoán (Crash Logs)", "Share Diagnostic Logs"), systemImage: "doc.text.magnifyingglass")
                    }
                    Text(L("Gửi log cho nhà phát triển khi gặp sự cố crash hoặc văng game.", "Send logs to developers to help troubleshoot crashes."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L("Save game & Sao lưu", "Save Game & Backup"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Xong", "Done")) { dismiss() }
                        .font(.body.bold())
                }
            }
        }
    }
}

struct GameFilesSheet: View {
    @ObservedObject var importer: Importer
    @Binding var pickingZip: Bool
    @Binding var pickingFolder: Bool
    let L: (String, String) -> String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(L("Trạng thái dữ liệu", "Files Status")) {
                    HStack(spacing: 12) {
                        Image(systemName: importer.ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(importer.ready ? PortTheme.ok : PortTheme.warning)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(importer.ready ? L("Dữ liệu game đã sẵn sàng", "Game files are ready") : L("Chưa có đầy đủ dữ liệu game", "Game files incomplete"))
                                .font(.subheadline.bold())
                            Text(importer.ready ? L("Bạn có thể vào chơi game ngay lập tức.", "You can launch the game now.") : L("Vui lòng chọn file .ZIP hoặc chép thư mục game.", "Please select a .ZIP or copy game folder."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let p = importer.progress {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: p)
                            Text("\(L("Đang nhập…", "Importing…")) \(Int(p * 100))%").font(.caption).monospacedDigit()
                        }
                    }
                }

                Section(L("Nhập dữ liệu game", "Import Game Files")) {
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { pickingZip = true }
                    }) {
                        Label(L("Chọn file .ZIP từ Tệp…", "Select .ZIP file from Files…"), systemImage: "archivebox.fill")
                    }

                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { pickingFolder = true }
                    }) {
                        Label(L("Chọn Thư mục Game từ Tệp…", "Select Game Folder from Files…"), systemImage: "folder.fill")
                    }

                    Button(action: {
                        importer.refreshReady()
                    }) {
                        Label(L("🔄 Kiểm tra lại dữ liệu", "🔄 Recheck / Verify Files"), systemImage: "arrow.clockwise")
                    }
                }

                Section(L("Hướng dẫn cài đặt offline", "Offline Files Setup")) {
                    Text(L("1. Mở ứng dụng Tệp (Files) > Trên iPhone/iPad > Mugoat.\n2. Tạo thư mục tên là 'game'.\n3. Chép 2 thư mục 'data' và 'b' vào bên trong 'game'.\n4. Bấm nút 'Kiểm tra lại dữ liệu' ở trên.",
                           "1. Open Files > On My iPhone > Mugoat.\n2. Create folder named 'game'.\n3. Copy 'data' and 'b' inside 'game'.\n4. Tap 'Recheck / Verify Files' above."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L("Dữ liệu game", "Game Files"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Xong", "Done")) { dismiss() }
                        .font(.body.bold())
                }
            }
        }
    }
}

// MARK: - Main Port-Style LauncherView

struct LauncherView: View {
    @StateObject private var s = Settings()
    @ObservedObject private var importer = Importer.shared
    @ObservedObject private var modManager = ModManager.shared
    @AppStorage("mugoat_language") private var currentLang: String = "vi"
    @State private var error: String?

    // Sheets & Modals
    @State private var pickingZip = false
    @State private var pickingFolder = false
    @State private var pickingMod = false
    @State private var showingGraphicsSheet = false
    @State private var showingHUDEditor = false
    @State private var showingCheatSheet = false
    @State private var showingSaveSheet = false
    @State private var showingModSheet = false
    @State private var showingMPSheet = false
    @State private var showingFilesSheet = false
    @State private var showingResetAlert = false
    @State private var resetAlertMessage = ""

    var isOverlay: Bool = false
    let play: () -> Void

    func L(_ vi: String, _ en: String) -> String {
        return currentLang == "en" ? en : vi
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            // LEFT COLUMN: Clean Brand, Game Files Card, Mode Cards, Play Button
            VStack(alignment: .leading, spacing: 14) {
                // Header (App Icon + Title + Language Pill)
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PortTheme.accent.opacity(0.14))
                            .frame(width: 48, height: 48)

                        if let logo = UIImage(named: "AppIcon60x60@2x.png") ?? UIImage(named: "mugoat_logo.png") ?? UIImage(contentsOfFile: Bundle.main.path(forResource: "mugoat_logo", ofType: "png") ?? "") {
                            Image(uiImage: logo)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(PortTheme.accent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(isOverlay ? "MUGOAT MENU" : "Mugoat")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(L("iOSVN  /  CHƠI THEO CÁCH CỦA BẠN", "iOSVN  /  PLAY YOUR WAY"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PortTheme.secondaryText)
                    }

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentLang = (currentLang == "vi" ? "en" : "vi")
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 11))
                            Text(currentLang == "vi" ? "VI" : "EN")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(white: 1.0, opacity: 0.12)))
                        .overlay(Capsule().stroke(PortTheme.panelStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                // Game Files Card (tap to open files options)
                Button(action: { showingFilesSheet = true }) {
                    HStack(spacing: 12) {
                        if importer.progress != nil {
                            ProgressView()
                                .tint(PortTheme.accent)
                                .frame(width: 28)
                        } else {
                            Image(systemName: importer.ready ? "checkmark.circle.fill" : "folder.badge.plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(importer.ready ? PortTheme.ok : PortTheme.warning)
                                .frame(width: 28)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Dữ liệu game", "Game Files"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)

                            if let p = importer.progress {
                                Text("\(L("Đang nhập…", "Importing…")) \(Int(p * 100))%")
                                    .font(.system(size: 13))
                                    .foregroundStyle(PortTheme.secondaryText)
                            } else if importer.ready {
                                Text(L("Sẵn sàng vào game", "Ready to play"))
                                    .font(.system(size: 13))
                                    .foregroundStyle(PortTheme.secondaryText)
                            } else {
                                Text(L("Chưa có dữ liệu · Chạm để chọn", "Missing files · Tap to import"))
                                    .font(.system(size: 13))
                                    .foregroundStyle(PortTheme.warning)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PortTheme.tertiaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(white: 1.0, opacity: 0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PortTheme.panelStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Game Mode Selection Cards (Story vs Sandbox)
                HStack(spacing: 10) {
                    PortModeCard(
                        title: L("Cốt truyện", "Story Mode"),
                        symbol: "book.closed.fill",
                        isSelected: s.mode == 1
                    ) {
                        s.mode = 1
                        try? s.save()
                    }

                    PortModeCard(
                        title: L("Tự do (Sandbox)", "Sandbox"),
                        symbol: "building.2.fill",
                        isSelected: s.mode == 2
                    ) {
                        s.mode = 2
                        try? s.save()
                    }
                }

                // Mode Explanation Subtitle
                Text(s.mode == 1
                    ? L("Cốt truyện chính Los Santos (bắt đầu từ đua xe sau cướp tiền)", "Story Mode in Los Santos (starts after heist race)")
                    : L("Tự do dạo chơi thành phố Los Santos, khám phá thế giới mở", "Free roam sandbox across Los Santos"))
                    .font(.system(size: 13))
                    .foregroundStyle(PortTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let error {
                    Text(error)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PortTheme.problem)
                }

                // Big Primary Action Button
                if !muguet_has_game_code() {
                    Text(L("Bản build này chưa có mã game: vui lòng build cùng game.wasm/zip.", "This build has no game code: build it with ./make-ios.sh <game.zip>."))
                        .foregroundStyle(.red).font(.callout).multilineTextAlignment(.center)
                } else if isOverlay {
                    PortPrimaryButton(title: L("TIẾP TỤC", "RESUME"), symbol: "play.fill") {
                        resumeAndSave()
                    }
                } else {
                    PortPrimaryButton(title: L("VÀO GAME", "PLAY"), symbol: "play.fill") {
                        start()
                    }
                }

                // Gamepad info notice
                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 11))
                    Text(L("🎮 Hỗ trợ tay cầm real: Nút ảo tự động ẩn khi kết nối", "🎮 Real gamepad supported: On-screen buttons auto-hide"))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(PortTheme.tertiaryText)

                Spacer()
            }
            .frame(maxWidth: 500)

            // RIGHT COLUMN: "Thiết lập trải nghiệm" with sleek glass buttons
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("Thiết lập trải nghiệm", "Experience Settings"))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(L("Chọn cấu hình phù hợp với máy của bạn.", "Choose the best profile for your device."))
                        .font(.system(size: 13))
                        .foregroundStyle(PortTheme.secondaryText)
                        .padding(.bottom, 4)

                    PortGlassButton(
                        title: L("Đồ họa & FPS", "Graphics & FPS"),
                        symbol: "slider.horizontal.3",
                        badge: "\(s.fps) FPS"
                    ) { showingGraphicsSheet = true }

                    PortGlassButton(
                        title: L("Bố trí điều khiển", "Controls Layout"),
                        symbol: "hand.tap.fill"
                    ) { showingHUDEditor = true }

                    PortGlassButton(
                        title: L("Tiện ích & Cheat GTA V", "GTA V Cheats"),
                        symbol: "sparkles",
                        badge: s.multiplayer ? L("Khóa Online", "Online Locked") : nil
                    ) { showingCheatSheet = true }

                    PortGlassButton(
                        title: L("Save game & Sao lưu", "Save Game & Backup"),
                        symbol: "externaldrive.fill"
                    ) { showingSaveSheet = true }

                    PortGlassButton(
                        title: L("Quản lý Mod", "Mod Manager"),
                        symbol: "puzzlepiece.extension.fill",
                        badge: modManager.mods.isEmpty ? nil : "\(modManager.mods.count)"
                    ) { showingModSheet = true }

                    PortGlassButton(
                        title: L("Chơi Online (IP)", "Multiplayer (IP)"),
                        symbol: "globe",
                        badge: s.multiplayer ? L("Đang Bật", "Enabled") : nil
                    ) { showingMPSheet = true }

                    // 3-step Quick Guide
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("01  Chọn dữ liệu game\n02  Chọn chế độ chơi\n03  Bấm Vào game",
                               "01  Select game files\n02  Select game mode\n03  Tap Play"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PortTheme.secondaryText)
                    }
                    .padding(.top, 8)

                    // Footer Version Info
                    Text("Mugoat · iOSVN · v1.0.0 (iOS 16+)")
                        .font(.system(size: 11))
                        .foregroundStyle(PortTheme.tertiaryText)
                        .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(PortBackdrop())
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $pickingZip, allowedContentTypes: [.zip]) { result in
            if case .success(let url) = result { importer.run(url) }
        }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { importer.importFolder(from: url) }
        }
        .fileImporter(isPresented: $pickingMod, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result { modManager.installMod(from: url) }
        }
        .sheet(isPresented: $showingGraphicsSheet) {
            GraphicsSettingsSheet(s: s, L: L, onReset: {
                resetGraphicsSettings()
                s.scale = 0.5
                s.textures = 0
                s.fps = 60
                s.shadowQuality = 1
                s.shadowDistance = 1.0
                s.reflectionQuality = 1
                s.grassQuality = 0
                s.waterQuality = 0
                s.particleQuality = 0
                s.postFx = 0
                s.anisotropicFiltering = 0
                s.fxaa = true
                s.cityDensity = 0.5
                s.pedDensity = 0.5
                s.distanceScaling = 0.0
                s.deepOptimization = true
                s.promotionSync = false
                try? s.save()
                muguet_reload_settings()
                resetAlertMessage = L("Đã khôi phục đồ họa về cấu hình an toàn 60 FPS.", "Reset graphics settings to safe default.")
                showingResetAlert = true
            })
        }
        .sheet(isPresented: $showingMPSheet) {
            MultiplayerSheet(s: s, L: L)
        }
        .sheet(isPresented: $showingModSheet) {
            ModManagerSheet(modManager: modManager, pickingMod: $pickingMod, L: L)
        }
        .sheet(isPresented: $showingSaveSheet) {
            SaveGameSheet(L: L, onShareSaves: shareSaves, onShareLogs: shareDiagnostics)
        }
        .sheet(isPresented: $showingFilesSheet) {
            GameFilesSheet(importer: importer, pickingZip: $pickingZip, pickingFolder: $pickingFolder, L: L)
        }
        .sheet(isPresented: $showingCheatSheet) {
            CheatMenuView(onApply: { code in
                code.withCString { muguet_apply_cheat($0) }
            })
        }
        .fullScreenCover(isPresented: $showingHUDEditor) {
            HUDEditorView(settings: s)
        }
        .alert(L("Thông báo Đồ họa", "Graphics Notice"), isPresented: $showingResetAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resetAlertMessage)
        }
        .onAppear {
            importer.refreshReady()
            modManager.scanMods()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            importer.refreshReady()
        }
    }

    func resumeAndSave() {
        do { try s.save() } catch {}
        s.applyCustomLayout()
        play()
        muguet_reload_settings()
    }

    func start() {
        if s.multiplayer && s.server.trimmingCharacters(in: .whitespaces).isEmpty {
            error = L("Nhập địa chỉ IP máy chủ để kết nối.", "Enter a valid server address.")
            return
        }
        if s.name.trimmingCharacters(in: .whitespaces).isEmpty {
            s.name = "Player" + String(Int.random(in: 100...999))
        }
        do { try s.save() } catch { self.error = "Could not save settings: \(error.localizedDescription)"; return }
        s.applyCustomLayout()
        play()
    }
}

@_cdecl("muguet_physical_memory")
public func muguetPhysicalMemory() -> UInt64 { ProcessInfo.processInfo.physicalMemory }

@_silgen_name("muguet_frame_stats")
private func muguetFrameStats() -> UInt64
@_silgen_name("muguet_frame_size")
private func muguetFrameSize() -> UInt64
@_silgen_name("muguet_memory_mb")
private func muguetMemoryMB() -> UInt64

private final class PerformanceHUD {
    static let shared = PerformanceHUD()
    private let label = UILabel()
    private var timer: Timer?
    private weak var parent: UIView?
    private var visible = true
    private var wasActive = false

    func install(in view: UIView) {
        guard parent !== view else { return }
        label.removeFromSuperview()
        parent = view
        label.text = "— FPS"
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        label.layer.cornerRadius = 7
        label.clipsToBounds = true
        label.numberOfLines = 2
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.accessibilityLabel = "Hiệu năng game"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            label.widthAnchor.constraint(equalToConstant: 230),
            label.heightAnchor.constraint(equalToConstant: 38)
        ])
        setVisible(Settings().showFPS)
    }

    func setVisible(_ enabled: Bool) {
        visible = enabled
        label.isHidden = !enabled
        timer?.invalidate()
        timer = nil
        guard enabled, parent != nil else { return }
        let next = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.update() }
        timer = next
        RunLoop.main.add(next, forMode: .common)
    }

    private func update() {
        let active = UIApplication.shared.applicationState == .active
        label.isHidden = !visible || !active
        // Don't reuse an old measurement on the first tick after resuming.
        defer { wasActive = active }
        guard active else { return }
        parent?.bringSubviewToFront(label)
        let stats = wasActive ? muguetFrameStats() : 0
        let fps = Double(stats >> 32) / 1000.0
        let p95 = Double(stats & 0xffffffff) / 1000.0
        let size = muguetFrameSize()
        let heat = ProcessInfo.processInfo.thermalState
        let thermal = heat == .critical ? " · Rất nóng" : heat == .serious ? " · Nóng" : ""
        label.text = (fps > 0 ? String(format: "%.1f FPS · P95 %.1f ms", fps, p95) : "— FPS · Đang chờ khung hình") +
            "\n\(size >> 32)×\(size & 0xffffffff) · \(muguetMemoryMB()) MB\(thermal)"
    }
}

private final class RefreshHint: NSObject {
    static let shared = RefreshHint()
    var link: CADisplayLink?
    private let condition = NSCondition()
    private var vsyncCount: UInt64 = 0
    private var lockedPacingEnabled: Bool = false

    @objc func tick(_ link: CADisplayLink) {
        condition.lock()
        defer { condition.unlock() }
        guard lockedPacingEnabled else { return }
        vsyncCount &+= 1
        condition.broadcast()
    }

    func set(_ requested: UInt32, lockedPacing: Bool = false) {
        condition.lock()
        self.lockedPacingEnabled = lockedPacing
        condition.broadcast()
        condition.unlock()
        let screenMax = Float(UIScreen.main.maximumFramesPerSecond)
        let maximum = max(1.0, screenMax)
        let rate = requested == 0 ? maximum : min(maximum, Float(requested))
        if link == nil {
            link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link?.add(to: .main, forMode: .common)
        }
        if lockedPacing {
            link?.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
        } else {
            link?.preferredFrameRateRange = CAFrameRateRange(minimum: min(30, rate), maximum: rate, preferred: rate)
        }
    }

    func waitVsync(timeoutMs: UInt32) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        guard lockedPacingEnabled else { return false }
        let current = vsyncCount
        let deadline = Date(timeIntervalSinceNow: Double(timeoutMs) / 1000.0)
        var signaled = false
        while lockedPacingEnabled && vsyncCount == current {
            if !condition.wait(until: deadline) {
                break
            }
            signaled = true
        }
        return signaled && vsyncCount != current
    }
}

@_cdecl("muguet_set_refresh_rate")
public func muguetSetRefreshRate(_ fps: UInt32) {
    DispatchQueue.main.async { RefreshHint.shared.set(fps, lockedPacing: Settings().promotionSync) }
}

@_cdecl("muguet_wait_vsync")
public func muguetWaitVsync(_ timeoutMs: UInt32) -> Bool {
    return RefreshHint.shared.waitVsync(timeoutMs: timeoutMs)
}

@_cdecl("muguet_open_menu")
public func muguetOpenMenu() {
    DispatchQueue.main.async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return }
        var presenter = root
        while let child = presenter.presentedViewController { presenter = child }

        let alert = UIAlertController(title: "Muguet Menu", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tiếp tục chơi", style: .cancel))

        alert.addAction(UIAlertAction(title: "Chỉnh vị trí & kích thước nút (HUD)", style: .default, handler: { _ in
            let host = UIHostingController(rootView: HUDEditorView(settings: Settings()))
            host.modalPresentationStyle = .fullScreen
            presenter.present(host, animated: true)
        }))

        let isMp = muguet_is_multiplayer()
        if !isMp {
            alert.addAction(UIAlertAction(title: "Bảng lệnh cheat", style: .default, handler: { _ in
                let cheatHost = UIHostingController(rootView: CheatMenuView(onApply: { code in
                    code.withCString { muguet_apply_cheat($0) }
                }))
                cheatHost.modalPresentationStyle = .formSheet
                presenter.present(cheatHost, animated: true)
            }))
        }

        alert.addAction(UIAlertAction(title: "Cài đặt & Tùy chọn", style: .default, handler: { _ in
            weak var sheet: UIViewController?
            let host = UIHostingController(rootView: LauncherView(isOverlay: true, play: {
                sheet?.dismiss(animated: true)
                muguet_reload_settings()
            }))
            sheet = host
            host.modalPresentationStyle = .fullScreen
            host.isModalInPresentation = true
            presenter.present(host, animated: true)
        }))

        alert.addAction(UIAlertAction(title: "Khôi phục đồ họa (Fix màn hình đen)", style: .destructive, handler: { _ in
            resetGraphicsSettings()
        }))

        alert.addAction(UIAlertAction(title: "Thoát ứng dụng", style: .destructive, handler: { _ in
            exit(0)
        }))

        presenter.present(alert, animated: true)
    }
}

func resetGraphicsSettings() {
    let folder = configURL.deletingLastPathComponent().appendingPathComponent("saves")
    let fm = FileManager.default
    if let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: nil) {
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "settings.xml" {
                try? fm.removeItem(at: fileURL)
            }
        }
    }
    _ = muguet_reset_game_settings()
    muguet_reload_settings()
}

func shareDiagnostics() {
    let folder = configURL.deletingLastPathComponent()
    let logs = ["muguet-previous.log", "muguet-runtime.log", "muguet-crash.log"].map { folder.appendingPathComponent($0) }
        .filter { FileManager.default.fileExists(atPath: $0.path) }
    guard !logs.isEmpty,
          let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first(where: { $0.isKeyWindow }),
          let root = window.rootViewController else { return }
    var presenter = root
    while let child = presenter.presentedViewController { presenter = child }
    let sheet = UIActivityViewController(activityItems: logs, applicationActivities: nil)
    if let popover = sheet.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
    }
    presenter.present(sheet, animated: true)
}

func shareSaves() {
    let folder = configURL.deletingLastPathComponent().appendingPathComponent("saves")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first(where: { $0.isKeyWindow }),
          let root = window.rootViewController else { return }
    var presenter = root
    while let child = presenter.presentedViewController { presenter = child }
    let sheet = UIActivityViewController(activityItems: [folder], applicationActivities: nil)
    if let popover = sheet.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
    }
    presenter.present(sheet, animated: true)
}

func localIPs() -> [String] {
    var out: [String] = []
    var ifs: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifs) == 0, let first = ifs else { return ["?"] }
    defer { freeifaddrs(ifs) }
    for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
        guard let a = p.pointee.ifa_addr, a.pointee.sa_family == UInt8(AF_INET) else { continue }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(a, socklen_t(a.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
            let ip = String(cString: host)
            if !ip.hasPrefix("127.") && !out.contains(ip) { out.append(ip) }
        }
    }
    return out.isEmpty ? ["?"] : out
}

@_cdecl("muguet_show_launcher")
public func muguetShowLauncher(_ viewController: UnsafeMutableRawPointer, _ done: @convention(c) () -> Void) {
    let parent = Unmanaged<UIViewController>.fromOpaque(viewController).takeUnretainedValue()
    weak var sheet: UIViewController?
    let host = UIHostingController(rootView: LauncherView(isOverlay: false, play: {
        if let sheet {
            sheet.dismiss(animated: true, completion: {
                PerformanceHUD.shared.install(in: parent.view)
                done()
            })
        } else {
            PerformanceHUD.shared.install(in: parent.view)
            done()
        }
    }))
    sheet = host
    host.modalPresentationStyle = .fullScreen
    host.isModalInPresentation = true
    parent.present(host, animated: false)
}
