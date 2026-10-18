import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct ModError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

/// Reads the open RPF7 table and XML metadata; geometry stays in the original archive.
/// Format reference: dexyfex/CodeWalker, RpfFile.cs (binary/resource entry layouts).
struct RPFArchive {
    struct Entry {
        let path: String
        let offset: Int
        let size: Int
        let unpacked: Int
        let encrypted: Bool
        let compressed: Bool
        let resourceVersion: Int?
    }
    let bytes: Data
    let entries: [Entry]

    init(url: URL) throws { try self.init(bytes: Data(contentsOf: url, options: .mappedIfSafe)) }
    init(bytes: Data) throws {
        self.bytes = bytes
        func word(_ at: Int) throws -> UInt32 {
            guard at >= 0, at <= bytes.count - 4 else { throw ModError("RPF bị thiếu dữ liệu.") }
            return bytes[at..<(at + 4)].enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
        }
        guard try word(0) == 0x52504637 else { throw ModError("Tệp không phải gói RPF7 của GTA V Legacy.") }
        let count = Int(try word(4)), namesSize = Int(try word(8))
        guard count > 0, count <= 100_000, namesSize > 0, namesSize <= 8 * 1024 * 1024,
              16 + count * 16 + namesSize <= bytes.count else { throw ModError("Bảng tệp RPF bị hỏng.") }
        guard try word(12) == 0x4e45504f else { throw ModError("Bảng RPF đã mã hóa. Hãy xuất gói mở bằng OpenIV trước khi nhập.") }
        let namesStart = 16 + count * 16
        func name(_ offset: Int) throws -> String {
            guard offset >= 0, offset < namesSize else { throw ModError("Tên tệp RPF không hợp lệ.") }
            let tail = bytes[(namesStart + offset)..<(namesStart + namesSize)]
            guard let zero = tail.firstIndex(of: 0), let text = String(data: bytes[(namesStart + offset)..<zero], encoding: .utf8),
                  text.utf8.count <= 255, !text.contains("/"), !text.contains("\\"), text != ".", text != ".." else { throw ModError("Đường dẫn trong RPF không hợp lệ.") }
            return text.lowercased()
        }
        var output: [Entry] = [], visited = Set<Int>()
        func walk(_ index: Int, parent: String, depth: Int) throws {
            guard depth < 32, index >= 0, index < count, visited.insert(index).inserted else { throw ModError("Cấu trúc thư mục RPF bị hỏng hoặc lặp.") }
            let at = 16 + index * 16, first = try word(at), second = try word(at + 4)
            let directory = second == 0x7fffff00
            let text = try name(Int(directory ? first : first & 0xffff))
            guard index == 0 || !text.isEmpty else { throw ModError("Tệp RPF thiếu tên.") }
            let path = parent.isEmpty ? text : parent + "/" + text
            if directory {
                let start = Int(try word(at + 8)), length = Int(try word(at + 12))
                guard start <= count, length <= count - start else { throw ModError("Thư mục RPF vượt giới hạn.") }
                for child in start..<(start + length) { try walk(child, parent: path, depth: depth + 1) }
            } else {
                let resource = second & 0x80000000 != 0
                let packed = UInt64(first) | UInt64(second) << 32
                var size = Int(packed >> 16 & 0xffffff)
                let compressed = size != 0
                let offset = Int(packed >> 40 & (resource ? 0x7fffff : 0xffffff)) * 512
                let unpacked = Int(try word(at + 8)), flags = try word(at + 12)
                if resource && size == 0xffffff {
                    guard offset <= bytes.count - 16 else { throw ModError("Tài nguyên RPF bị cắt.") }
                    size = Int(bytes[offset + 7]) | Int(bytes[offset + 14]) << 8 | Int(bytes[offset + 5]) << 16 | Int(bytes[offset + 2]) << 24
                }
                if !resource && size == 0 { size = unpacked }
                guard offset >= namesStart + namesSize, size >= 0, offset <= bytes.count, size <= bytes.count - offset else { throw ModError("Dữ liệu tệp RPF vượt giới hạn.") }
                output.append(Entry(path: path, offset: offset, size: size, unpacked: unpacked,
                                    encrypted: !resource && flags != 0, compressed: compressed,
                                    resourceVersion: resource ? Int(((UInt32(unpacked) >> 28) << 4) | (flags >> 28)) : nil))
            }
        }
        try walk(0, parent: "", depth: 0)
        guard visited.count == count, Set(output.map(\.path)).count == output.count else { throw ModError("Bảng RPF chứa mục mồ côi hoặc trùng tên.") }
        entries = output
    }

    func metadata(_ entry: Entry) throws -> Data {
        guard entry.resourceVersion == nil, !entry.encrypted, entry.unpacked > 0,
              entry.unpacked <= 8 * 1024 * 1024 else { throw ModError("Metadata mod mã hóa hoặc quá lớn: \(entry.path)") }
        let data = bytes.subdata(in: entry.offset..<(entry.offset + entry.size))
        if !entry.compressed { return data }
        var result = Data(count: entry.unpacked)
        let valid = result.withUnsafeMutableBytes { out in data.withUnsafeBytes { input in
            gi_inflate_raw(input.baseAddress, UInt32(data.count), out.baseAddress, UInt32(entry.unpacked))
        } }
        guard valid == 1 else { throw ModError("Không giải nén được metadata: \(entry.path)") }
        return result
    }

    func nested(_ entry: Entry) throws -> RPFArchive {
        guard !entry.encrypted, entry.resourceVersion == nil, !entry.compressed else { throw ModError("RPF lồng đã mã hóa/nén: \(entry.path)") }
        return try RPFArchive(bytes: bytes.subdata(in: entry.offset..<(entry.offset + entry.size)))
    }
}

final class ModXML: NSObject, XMLParserDelegate {
    private var current = "", text = ""
    private(set) var values: [String: [String]] = [:]
    static func read(_ data: Data) throws -> ModXML {
        let delegate = ModXML(), parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        guard parser.parse() else { throw ModError("XML của mod không hợp lệ.") }
        return delegate
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) { current = name; text = "" }
    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == current { let value = text.trimmingCharacters(in: .whitespacesAndNewlines); if !value.isEmpty { values[name, default: []].append(value) } }
        current = ""; text = ""
    }
}

struct ModPack {
    let name: String
    let url: URL
    /// Every model the menus may offer: add-on vehicles (vehicles.meta) plus peds.
    let models: [String]
    let vehicleModels: [String]
    /// model -> vehicle type label from vehicles.meta ("Ô tô", "Mô tô", "Trực thăng"...). Missing when unreadable.
    let vehicleKinds: [String: String]
    let pedModels: [String]
    /// Non-fatal findings. A pack with warnings still loads, but may misbehave in game.
    let warnings: [String]
    let archive: RPFArchive

    static func validName(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.count <= 63 && name.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 95 }
    }

    private static func fileName(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    private static func isVehiclesMeta(_ path: String) -> Bool {
        let file = fileName(path)
        return file.hasSuffix(".meta") && (file.hasPrefix("vehicles") || file.hasSuffix("vehicles.meta"))
    }

    init(url: URL) throws {
        let archive = try RPFArchive(url: url)
        guard let setup = archive.entries.first(where: { $0.path == "setup2.xml" }),
              let content = archive.entries.first(where: { $0.path == "content.xml" }) else {
            throw ModError("Gói DLC thiếu setup2.xml hoặc content.xml ở thư mục gốc của dlc.rpf.")
        }
        let setupXML = try ModXML.read(archive.metadata(setup))
        guard let device = setupXML.values["deviceName"]?.first?.lowercased() else {
            throw ModError("setup2.xml không có deviceName.")
        }
        guard device.hasPrefix("dlc_"), Self.validName(String(device.dropFirst(4))) else {
            throw ModError("deviceName không hợp lệ: \(device). Tên gói chỉ gồm a-z, 0-9, _ và bắt đầu bằng dlc_.")
        }
        let packName = String(device.dropFirst(4))
        var warnings: [String] = []

        // content.xml: which data files the pack asks the game to enable.
        var fileTypes = Set<String>()
        if let contentXML = try? ModXML.read(archive.metadata(content)) {
            fileTypes = Set((contentXML.values["fileType"] ?? []).map { $0.uppercased() })
        } else {
            warnings.append("Không đọc được content.xml (có thể là bản nhị phân).")
        }

        // Resources: reject Enhanced-edition files, remember which .yft files exist.
        var yftNames = Set<String>()
        var incompatible: String? = nil
        func inspect(_ entries: [RPFArchive.Entry]) {
            for resource in entries {
                let isYft = resource.path.hasSuffix(".yft")
                let isYtd = resource.path.hasSuffix(".ytd")
                let isYdd = resource.path.hasSuffix(".ydd")
                guard isYft || isYtd || isYdd else { continue }
                let expected = isYft ? 162 : (isYtd ? 13 : 165)
                if resource.resourceVersion != expected {
                    if incompatible == nil { incompatible = resource.path }
                    continue
                }
                if isYft {
                    let base = (Self.fileName(resource.path).components(separatedBy: ".").first ?? "").lowercased()
                    if !base.isEmpty { yftNames.insert(base) }
                }
            }
        }
        inspect(archive.entries)
        var scannedNested = true
        for entry in archive.entries where entry.path.hasSuffix(".rpf") {
            if let nested = try? archive.nested(entry) {
                inspect(nested.entries)
            } else {
                scannedNested = false
                warnings.append("Không đọc được RPF lồng \(entry.path) (nén/mã hóa); bỏ qua kiểm tra bên trong.")
            }
        }
        if let bad = incompatible {
            throw ModError("Gói \(packName) dùng tài nguyên Enhanced không tương thích (\(bad)). Hãy dùng bản Legacy.")
        }

        // Vehicles and handling.
        var vehicles = Set<String>()
        var kinds: [String: String] = [:]
        var handlingFiles = 0
        var vehicleMetaFound = false
        for entry in archive.entries where Self.isVehiclesMeta(entry.path) {
            vehicleMetaFound = true
            guard let xml = try? ModXML.read(archive.metadata(entry)) else {
                warnings.append("Không đọc được \(entry.path) (nhị phân/mã hóa/quá lớn).")
                continue
            }
            let rawModels = xml.values["modelName"] ?? []
            let rawTypes = (xml.values["type"] ?? []).filter { $0.uppercased().hasPrefix("VEHICLE_TYPE_") }
            for (index, raw) in rawModels.enumerated() {
                let model = raw.lowercased()
                if Self.validName(model) {
                    vehicles.insert(model)
                    if rawTypes.count == rawModels.count { kinds[model] = ModFiles.vehicleKindLabel(rawTypes[index]) }
                } else { warnings.append("Bỏ qua tên model không hợp lệ: \(raw)") }
            }
        }
        for entry in archive.entries where Self.fileName(entry.path).hasSuffix("handling.meta") {
            handlingFiles += 1
        }

        // Peds.
        var peds = Set<String>()
        for entry in archive.entries where entry.path.hasSuffix("peds.meta") {
            let meta = try? ModXML.read(archive.metadata(entry))
            for raw in (meta?.values["ModelName"] ?? []) + (meta?.values["Name"] ?? []) {
                let model = raw.lowercased()
                if Self.validName(model) { peds.insert(model) }
            }
        }

        // No readable vehicles.meta: fall back to vehicle drawables (.yft), skipping LOD/HD variants.
        var fromResources = Set<String>()
        if vehicles.isEmpty {
            for base in yftNames where Self.validName(base) && !base.hasSuffix("_hi") && !base.hasSuffix("_lod") {
                fromResources.insert(base)
            }
        }

        // Findings that commonly explain cars that fall, fly or vanish in game.
        if !vehicles.isEmpty {
            if !fileTypes.isEmpty && !fileTypes.contains("VEHICLE_METADATA_FILE") {
                warnings.append("content.xml không khai báo VEHICLE_METADATA_FILE: xe có thể không được đăng ký.")
            }
            if handlingFiles == 0 && !fileTypes.contains("HANDLING_FILE") {
                warnings.append("Gói không có handling.meta: xe dễ bị rơi, bay hoặc lật khi chạy.")
            } else if handlingFiles > 0 && !fileTypes.isEmpty && !fileTypes.contains("HANDLING_FILE") {
                warnings.append("Có handling.meta nhưng content.xml không khai báo HANDLING_FILE: xe sẽ dùng handling sai.")
            }
            if scannedNested {
                for model in vehicles.sorted() where !yftNames.contains(model) {
                    warnings.append("Không thấy \(model).yft trong gói (xe có thể vô hình hoặc không tạo được).")
                }
            }
        } else if vehicleMetaFound {
            warnings.append("vehicles.meta không có model nào dùng được.")
        }

        var all = vehicles
        all.formUnion(fromResources)
        all.formUnion(peds)
        guard !all.isEmpty else { throw ModError("DLC chưa có model xe hoặc nhân vật hợp lệ.") }

        self.name = packName
        self.url = url
        self.archive = archive
        self.vehicleModels = vehicles.union(fromResources).sorted()
        self.vehicleKinds = kinds
        self.pedModels = peds.sorted()
        self.models = all.sorted()
        self.warnings = warnings
    }

    /// Human-readable summary for the mod manager.
    var report: String {
        var lines = ["Gói DLC: dlc_\(name)"]
        if !vehicleModels.isEmpty {
            var shown: [String] = []
            for model in vehicleModels {
                if let kind = vehicleKinds[model] { shown.append("\(model) (\(kind))") } else { shown.append(model) }
            }
            lines.append("Xe (\(vehicleModels.count)): " + shown.joined(separator: ", "))
        }
        if !pedModels.isEmpty { lines.append("Nhân vật (\(pedModels.count)): " + pedModels.joined(separator: ", ")) }
        if warnings.isEmpty { lines.append("Không phát hiện vấn đề trong gói.") }
        else { lines.append(contentsOf: warnings.map { "⚠︎ " + $0 }) }
        return lines.joined(separator: "\n")
    }
}
