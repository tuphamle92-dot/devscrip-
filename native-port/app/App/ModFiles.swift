import Foundation

/// What a mod file really is, decided from its name and its content (never from the extension alone).
struct ModFileInfo {
    enum Group: Int {
        case vehicle, ped, texture, data, script, archive, other
    }
    var group: Group
    /// Short type label shown in lists, e.g. "Texture quần áo nhân vật · uppr (thân/tay áo) (.ytd)".
    var title: String
    /// Technical findings: resource version, encryption, number of vehicles...
    var detail: String = ""
    /// Model names read from the file (only vehicles.meta can provide them).
    var models: [String] = []
    /// model -> vehicle type label ("Ô tô", "Mô tô", "Trực thăng"...), read from vehicles.meta.
    var vehicleKinds: [String: String] = [:]
}

/// Shared rules for importing, listing and classifying mod files.
/// Notes and pictures are never mods. Every other file is accepted and labelled by its real content.
enum ModFiles {
    static let modExtensions: Set<String> = [
        "rpf", "meta", "asi", "lua", "cs", "xml", "ini", "dat", "oiv", "dll", "pso",
        "yft", "ytd", "ydr", "ydd", "ybn", "ymap", "ytyp", "ymt", "ycd", "ypt",
        "ynv", "ynd", "yld", "yed", "yfd", "ymf", "awc", "rel", "gxt2", "sc"
    ]
    static let archiveExtensions: Set<String> = ["zip", "rar", "7z", "tar", "gz"]
    /// Guides, notes and pictures shipped next to mods. They are not listed and not imported.
    static let ignoredExtensions: Set<String> = [
        "txt", "md", "rtf", "pdf", "doc", "docx", "nfo", "url", "html", "htm",
        "jpg", "jpeg", "png", "gif", "webp", "heic", "bmp", "log"
    ]
    static var importExtensions: Set<String> { modExtensions.union(archiveExtensions) }

    /// True for any file that should be accepted as a mod, whatever its extension:
    /// only guides, pictures, readmes and archives (handled separately) are left out.
    /// `original` is the file name without a trailing ".disabled".
    static func isModFile(_ original: URL) -> Bool {
        let ext = original.pathExtension.lowercased()
        if ignoredExtensions.contains(ext) || archiveExtensions.contains(ext) { return false }
        let base = original.deletingPathExtension().lastPathComponent.lowercased()
        if base.hasPrefix("readme") { return false }
        return true
    }

    struct Entry {
        let name: String
        let url: URL
        let size: Int64
        let modified: Date
        let isEnabled: Bool
        let info: ModFileInfo
    }

    static func scan(_ directory: URL) -> [Entry] {
        let directory = directory.resolvingSymlinksInPath().standardizedFileURL
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else { return [] }
        let baseComponents = directory.pathComponents.count
        var entries: [Entry] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            if values.isSymbolicLink == true || (values.isDirectory == true && url.pathExtension.lowercased() == "disabled") {
                enumerator.skipDescendants()
                continue
            }
            guard values.isRegularFile == true else { continue }
            let enabled = url.pathExtension.lowercased() != "disabled"
            let original = enabled ? url : url.deletingPathExtension()
            guard isModFile(original) else { continue }
            let name = url.standardizedFileURL.pathComponents.dropFirst(baseComponents).joined(separator: "/")
            let size = Int64(values.fileSize ?? 0)
            let modified = values.contentModificationDate ?? .distantPast
            let info = classify(url, original: original, size: size, modified: modified)
            entries.append(Entry(name: name, url: url, size: size, modified: modified, isEnabled: enabled, info: info))
        }
        return entries.sorted { $0.modified == $1.modified ? $0.name < $1.name : $0.modified > $1.modified }
    }

    // MARK: - Classification

    private static let cacheLock = NSLock()
    private static var metaCache: [String: ModFileInfo] = [:]

    /// Reads at most the first bytes of the file; `.meta` results are cached until the file changes.
    static func classify(_ url: URL, original: URL, size: Int64 = 0, modified: Date = .distantPast) -> ModFileInfo {
        let ext = original.pathExtension.lowercased()
        let base = original.deletingPathExtension().lastPathComponent.lowercased()
        switch ext {
        case "rpf":
            return classifyRPF(url, base: base)
        case "ytd", "yft", "ydd", "ydr", "ybn", "ycd", "ypt", "ymap", "ytyp", "ymt", "ynv", "ynd", "yld", "yed", "yfd", "ymf":
            return classifyResource(url, ext: ext, base: base)
        case "meta", "xml", "pso":
            let key = "\(url.path)|\(size)|\(modified.timeIntervalSince1970)"
            cacheLock.lock()
            let hit = metaCache[key]
            cacheLock.unlock()
            if let hit = hit { return hit }
            let result = classifyMeta(url, ext: ext, base: base)
            cacheLock.lock()
            if metaCache.count > 128 { metaCache.removeAll() }
            metaCache[key] = result
            cacheLock.unlock()
            return result
        case "asi", "dll":
            return ModFileInfo(group: .script, title: "Plugin Windows (.\(ext))", detail: "iOS không chạy được plugin ASI/DLL của Windows")
        case "lua":
            return ModFileInfo(group: .script, title: "Script Lua (.lua)", detail: "bản này chưa có bộ nạp Lua")
        case "cs":
            return ModFileInfo(group: .script, title: "Script C# (.cs)", detail: "bản này chưa có bộ nạp script C#")
        case "oiv":
            return ModFileInfo(group: .archive, title: "Gói cài OpenIV (.oiv)", detail: "là tệp nén: hãy giải nén rồi nhập dlc.rpf hoặc các tệp bên trong")
        case "ini", "dat":
            return ModFileInfo(group: .data, title: "Tệp cấu hình (.\(ext))")
        default:
            let label = ext.isEmpty ? "không có đuôi" : "." + ext
            return ModFileInfo(group: .other, title: "Tệp mod (\(label))", detail: "chưa nhận diện được loại")
        }
    }

    private static func readPrefix(_ url: URL, _ count: Int) -> Data {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return Data() }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: count)) ?? Data()
    }

    private static func word(_ data: Data, _ at: Int) -> UInt32 {
        guard at >= 0, at + 4 <= data.count else { return 0 }
        let start = data.startIndex + at
        let b0 = UInt32(data[start])
        let b1 = UInt32(data[start + 1])
        let b2 = UInt32(data[start + 2])
        let b3 = UInt32(data[start + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    private static func classifyRPF(_ url: URL, base: String) -> ModFileInfo {
        let title = base == "dlc" ? "Gói DLC (dlc.rpf)" : "Gói RPF"
        let head = readPrefix(url, 16)
        guard head.count >= 16, word(head, 0) == 0x52504637 else {
            return ModFileInfo(group: .archive, title: title, detail: "không có chữ ký RPF7 (tệp lỗi hoặc không phải của GTA V)")
        }
        let table: String
        switch word(head, 12) {
        case 0x4e45504f: table = "bảng mở (OPEN)"
        case 0x0ffffff9: table = "bảng mã hóa AES"
        case 0x0fefffff: table = "bảng mã hóa NG"
        default: table = "bảng mã hóa lạ"
        }
        return ModFileInfo(group: .archive, title: title, detail: "RPF7 · \(table) · \(word(head, 4)) mục")
    }

    private static let pedSlots: [String: String] = [
        "head": "đầu", "berd": "mặt nạ/râu", "hair": "tóc", "uppr": "thân/tay áo", "lowr": "quần",
        "hand": "túi/dù", "feet": "giày", "teef": "phụ kiện cổ", "accs": "áo lót/phụ kiện",
        "task": "giáp", "decl": "decal", "jbib": "áo ngoài"
    ]
    private static let pedProps: [String: String] = [
        "head": "mũ", "eyes": "kính", "ears": "tai", "mouth": "miệng", "lhand": "tay trái",
        "rhand": "tay phải", "lwrist": "cổ tay trái", "rwrist": "cổ tay phải", "hip": "hông",
        "lfoot": "chân trái", "rfoot": "chân phải"
    ]

    /// Ped clothing names: uppr_diff_025_a_uni (texture) or uppr_025_u (drawable); props start with p_.
    private static func pedPart(_ base: String, texture: Bool) -> String? {
        let pattern = texture
            ? "^(p_)?[a-z]+_(diff|normal|spec|detail|n|s)_[0-9]{3}_[a-z]"
            : "^(p_)?[a-z]+_[0-9]{3}(_[a-z]+)?$"
        guard base.range(of: pattern, options: .regularExpression) != nil else { return nil }
        var parts = base.split(separator: "_").map { String($0) }
        let isProp = parts.first == "p"
        if isProp { parts.removeFirst() }
        guard let slot = parts.first else { return nil }
        if isProp, let label = pedProps[slot] { return "prop \(slot) (\(label))" }
        if !isProp, let label = pedSlots[slot] { return "\(slot) (\(label))" }
        return nil
    }

    private static func classifyResource(_ url: URL, ext: String, base: String) -> ModFileInfo {
        let head = readPrefix(url, 16)
        let detail: String
        if head.count >= 8, word(head, 0) == 0x37435352 {
            let version = Int(word(head, 4))
            let legacy: [String: Int] = ["ytd": 13, "yft": 162, "ydd": 165]
            if let want = legacy[ext] {
                detail = want == version
                    ? "RSC7 v\(version) · tương thích Legacy"
                    : "RSC7 v\(version), bản Legacy cần v\(want) (có thể là Enhanced/console)"
            } else {
                detail = "RSC7 v\(version)"
            }
        } else if head.count >= 4, word(head, 0) == 0x38435352 {
            detail = "RSC8 · bản Enhanced (engine Legacy không đọc được)"
        } else {
            detail = "không có chữ ký tài nguyên GTA V (RSC7)"
        }

        switch ext {
        case "ytd":
            if let part = pedPart(base, texture: true) {
                return ModFileInfo(group: .ped, title: "Texture quần áo nhân vật · \(part) (.ytd)", detail: detail + " · không phải mod xe")
            }
            let directory = url.deletingLastPathComponent()
            let listing = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            let names = Set(listing.map { $0.lowercased() })
            let stem = base.replacingOccurrences(of: "+hi", with: "").replacingOccurrences(of: "_hi", with: "")
            let candidates = [stem + ".yft", stem + "_hi.yft", stem + "+hi.yft"]
            if candidates.contains(where: { names.contains($0) }) {
                return ModFileInfo(group: .vehicle, title: "Texture xe (.ytd)", detail: detail)
            }
            return ModFileInfo(group: .texture, title: "Texture (.ytd)", detail: detail + " · chưa rõ của xe hay nhân vật")
        case "yft":
            let hi = base.hasSuffix("_hi") || base.hasSuffix("+hi")
            return ModFileInfo(group: .vehicle, title: hi ? "Mô hình xe chi tiết cao (_hi.yft)" : "Mô hình xe (.yft)", detail: detail)
        case "ydd":
            if let part = pedPart(base, texture: false) {
                return ModFileInfo(group: .ped, title: "Mô hình quần áo nhân vật · \(part) (.ydd)", detail: detail + " · không phải mod xe")
            }
            return ModFileInfo(group: .data, title: "Drawable (.ydd)", detail: detail)
        case "ydr": return ModFileInfo(group: .data, title: "Mô hình vật thể (.ydr)", detail: detail)
        case "ybn": return ModFileInfo(group: .data, title: "Va chạm (.ybn)", detail: detail)
        case "ycd": return ModFileInfo(group: .data, title: "Hoạt ảnh (.ycd)", detail: detail)
        case "ypt": return ModFileInfo(group: .data, title: "Hiệu ứng hạt (.ypt)", detail: detail)
        case "ymap": return ModFileInfo(group: .data, title: "Bản đồ (.ymap)", detail: detail)
        case "ytyp": return ModFileInfo(group: .data, title: "Định nghĩa vật thể (.ytyp)", detail: detail)
        default: return ModFileInfo(group: .data, title: "Tài nguyên (.\(ext))", detail: detail)
        }
    }

    // MARK: - Meta files

    /// Human label for a vehicles.meta <type> value, e.g. VEHICLE_TYPE_BIKE -> "Mô tô".
    static func vehicleKindLabel(_ raw: String) -> String {
        let key = raw.uppercased().replacingOccurrences(of: "VEHICLE_TYPE_", with: "")
        switch key {
        case "CAR", "AUTOMOBILE": return "Ô tô"
        case "BIKE": return "Mô tô"
        case "BICYCLE": return "Xe đạp"
        case "QUADBIKE": return "Xe quad"
        case "HELI": return "Trực thăng"
        case "PLANE": return "Máy bay"
        case "BLIMP": return "Khí cầu"
        case "AUTOGYRO": return "Trực thăng gyro"
        case "BOAT": return "Tàu thuyền"
        case "SUBMARINE": return "Tàu ngầm"
        case "SUBMARINECAR": return "Xe lặn"
        case "TRAILER": return "Rơ-moóc"
        case "TRAIN": return "Tàu hỏa"
        case "AMPHIBIOUS_AUTOMOBILE", "AMPHIBIOUS_QUADBIKE": return "Xe lưỡng cư"
        default: return key.isEmpty ? "Xe (chưa rõ loại)" : "Xe (\(key.lowercased()))"
        }
    }

    private static func looksLikeXML(_ data: Data) -> Bool {
        if data.starts(with: [0xEF, 0xBB, 0xBF] as [UInt8]) || data.starts(with: [0xFF, 0xFE] as [UInt8]) || data.starts(with: [0xFE, 0xFF] as [UInt8]) {
            return true
        }
        guard let first = data.first(where: { $0 > 0x20 }) else { return false }
        return first == 0x3C
    }

    private static func readXMLText(_ url: URL) -> String? {
        let data = readPrefix(url, 4 * 1024 * 1024)
        guard !data.isEmpty, looksLikeXML(data) else { return nil }
        let encodings: [String.Encoding] = [.utf8, .utf16, .isoLatin1]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding), text.contains("<") { return text }
        }
        return nil
    }

    /// Values of every <tag>value</tag> in document order (plain text only, no nesting).
    private static func values(of tag: String, in text: String) -> [String] {
        var result: [String] = []
        let open = "<" + tag + ">"
        let close = "</" + tag + ">"
        var cursor = text.startIndex
        while cursor < text.endIndex,
              let start = text.range(of: open, options: .caseInsensitive, range: cursor..<text.endIndex),
              let end = text.range(of: close, options: .caseInsensitive, range: start.upperBound..<text.endIndex) {
            let value = text[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { result.append(value) }
            cursor = end.upperBound
        }
        return result
    }

    private static func validModel(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.count <= 63 && name.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 95 }
    }

    private static func classifyMeta(_ url: URL, ext: String, base: String) -> ModFileInfo {
        let head = readPrefix(url, 16)
        var binary = ""
        if head.count >= 4, word(head, 0) == 0x4E495350 { binary = "meta nhị phân (PSO)" }
        else if head.count >= 4, word(head, 0) == 0x30464252 { binary = "meta nhị phân (RBF)" }
        let text = binary.isEmpty ? readXMLText(url) : nil
        let hint = text ?? ""

        if ext == "xml" {
            if base.contains("setup2") { return ModFileInfo(group: .data, title: "setup2.xml (khai báo gói DLC)") }
            if base.contains("content") { return ModFileInfo(group: .data, title: "content.xml (danh sách tệp của DLC)") }
            if base.contains("dlclist") { return ModFileInfo(group: .data, title: "dlcList.xml (danh sách DLC)") }
            return ModFileInfo(group: .data, title: "Tệp XML (.xml)")
        }

        func has(_ marker: String) -> Bool { hint.contains(marker) }
        let note = binary.isEmpty ? "" : binary + " · không đọc được nội dung"

        if (has("CVehicleModelInfo__InitDataList") || base.contains("vehicles")) && !base.contains("vehiclelayouts") {
            var info = ModFileInfo(group: .vehicle, title: "vehicles.meta (khai báo xe)", detail: note)
            if let text = text {
                let names = values(of: "modelName", in: text)
                let types = values(of: "type", in: text).filter { $0.uppercased().hasPrefix("VEHICLE_TYPE_") }
                var seen = Set<String>()
                for (index, raw) in names.enumerated() {
                    let model = raw.lowercased()
                    guard validModel(model), seen.insert(model).inserted else { continue }
                    info.models.append(model)
                    if types.count == names.count { info.vehicleKinds[model] = vehicleKindLabel(types[index]) }
                }
                if info.models.isEmpty {
                    info.detail = "không thấy model xe nào"
                } else {
                    var parts: [String] = []
                    for model in info.models {
                        if let kind = info.vehicleKinds[model] { parts.append("\(model) (\(kind))") }
                        else { parts.append(model) }
                    }
                    info.detail = parts.joined(separator: ", ")
                }
            }
            return info
        }
        if has("CHandlingDataMgr") || base.contains("handling") {
            return ModFileInfo(group: .vehicle, title: "handling.meta (thông số lái xe)", detail: note)
        }
        if has("CVehicleModelInfoVariation") || base.contains("carvariations") {
            return ModFileInfo(group: .vehicle, title: "carvariations.meta (màu và biến thể xe)", detail: note)
        }
        if has("CVehicleModelInfoVarGlobal") || base.contains("carcols") {
            return ModFileInfo(group: .vehicle, title: "carcols.meta (màu, đèn và kit xe)", detail: note)
        }
        if base.contains("vehiclelayouts") {
            return ModFileInfo(group: .vehicle, title: "vehiclelayouts.meta (bố cục ghế/cửa xe)", detail: note)
        }
        if has("CPedModelInfo__InitDataList") || base.hasPrefix("peds") {
            return ModFileInfo(group: .ped, title: "peds.meta (khai báo nhân vật)", detail: note)
        }
        if base.contains("shop_ped") || base.contains("freemode") || base.contains("pedalternate")
            || base.contains("creaturemetadata") || has("CPedVariationInfo") {
            return ModFileInfo(group: .ped, title: "Metadata quần áo nhân vật (.meta)", detail: note)
        }
        if has("CWeaponInfoBlob") || base.contains("weapon") {
            return ModFileInfo(group: .data, title: "weapons.meta (vũ khí)", detail: note)
        }
        return ModFileInfo(group: .data, title: "Metadata (.meta)", detail: note)
    }
}
