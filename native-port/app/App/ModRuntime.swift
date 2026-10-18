import Foundation

enum ModRuntime {
    /// Largest DLC pack the importer and catalog accept.
    static let maxPackBytes: Int64 = 100 * 1024 * 1024

    struct Catalog {
        var packs: [ModPack] = []
        var problems: [String] = []
        var models: [String] { packs.flatMap(\.models).sorted() }
        /// Vehicles only (peds are listed separately so they are never offered to the vehicle spawner).
        var vehicleModels: [String] { packs.flatMap(\.vehicleModels).sorted() }
    }

    struct ImportReport {
        var installed: [ModPack] = []
        var problems: [String] = []
        var looseFiles = 0
        /// Files that were accepted and saved in mods/ but are not mountable DLC packs: "name — type".
        var stored: [String] = []

        mutating func merge(_ other: ImportReport) {
            installed += other.installed
            problems += other.problems
            looseFiles += other.looseFiles
            stored += other.stored
        }
    }

    /// Models that were mounted when the engine last started. nil until the first boot.
    /// A pack installed afterwards is on disk but the engine cannot see it until relaunch.
    private(set) static var mountedModels: Set<String>? = nil

    // MARK: - Parsed pack cache (a pack is only re-read when its file changes)

    private static let cacheLock = NSLock()
    private static var cache: [String: Result<ModPack, ModError>] = [:]

    private static func load(_ file: ModFiles.Entry) -> Result<ModPack, ModError> {
        let key = "\(file.url.path)|\(file.size)|\(file.modified.timeIntervalSince1970)"
        cacheLock.lock()
        let hit = cache[key]
        cacheLock.unlock()
        if let hit = hit { return hit }

        var result: Result<ModPack, ModError>
        if file.size > maxPackBytes {
            result = .failure(ModError("Tệp lớn hơn giới hạn 100 MB (\(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)))."))
        } else {
            do {
                result = .success(try ModPack(url: file.url))
            } catch let error as ModError {
                result = .failure(error)
            } catch {
                result = .failure(ModError(error.localizedDescription))
            }
        }
        cacheLock.lock()
        if cache.count > 64 { cache.removeAll() }
        cache[key] = result
        cacheLock.unlock()
        return result
    }

    static func catalog(_ directory: URL) -> Catalog {
        var result = Catalog()
        var names = Set<String>()
        var models = Set<String>()
        let files = ModFiles.scan(directory)
            .filter { $0.isEnabled && $0.url.pathExtension.lowercased() == "rpf" }
            .sorted { $0.name < $1.name }
        for file in files {
            switch load(file) {
            case .success(let pack):
                if !names.insert(pack.name).inserted {
                    result.problems.append(file.name + ": Trùng gói DLC \(pack.name). Chỉ bật một phiên bản của gói này.")
                    continue
                }
                let clash = models.intersection(pack.models)
                if !clash.isEmpty {
                    result.problems.append(file.name + ": Trùng tên xe với mod khác: " + clash.sorted().joined(separator: ", ") + ".")
                    continue
                }
                models.formUnion(pack.models)
                result.packs.append(pack)
            case .failure(let error):
                result.problems.append(file.name + ": " + error.message)
            }
        }
        return result
    }

    /// True when `model` belongs to an installed pack that the running engine did not mount.
    static func needsRestart(for model: String, mods: URL) -> Bool {
        guard let mounted = mountedModels else { return false }
        let wanted = model.lowercased()
        if mounted.contains(wanted) { return false }
        return catalog(mods).models.contains(wanted)
    }

    private static func decodeDLCList(_ data: Data) -> String? {
        let encodings: [String.Encoding] = [.utf8, .utf16, .isoLatin1]
        for encoding in encodings {
            guard var text = String(data: data, encoding: encoding),
                  text.range(of: "</Paths>", options: .caseInsensitive) != nil else { continue }
            if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
            // We always write UTF-8, so the XML declaration must not claim otherwise.
            if encoding != .utf8 {
                text = text.replacingOccurrences(of: "utf-16", with: "utf-8", options: .caseInsensitive)
            }
            return text
        }
        return nil
    }

    /// Builds a manifest overlay. Original game files and their sizes remain untouched.
    /// Packs that fail validation are skipped and reported in `Catalog.problems`; they no
    /// longer stop the healthy packs from loading.
    static func prepare(baseManifest: URL, mods: URL, runtime: URL, dlcList: Data) throws -> (URL, Catalog) {
        let loaded = Self.catalog(mods)
        mountedModels = Set(loaded.models)
        guard !loaded.packs.isEmpty else { return (baseManifest, loaded) }
        guard var manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: baseManifest)) as? [String: Any],
              var files = manifest["files"] as? [[Any]],
              var xml = decodeDLCList(dlcList) else { throw ModError("Thiếu danh sách DLC gốc hợp lệ.") }
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
        var overrides: [String: String] = [:]
        func add(_ path: String, file: URL) throws {
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            if let index = files.firstIndex(where: { ($0.first as? String)?.lowercased() == path.lowercased() }) {
                // Preserve indices used by preloader/cache and by the engine.
                let original = files[index][0] as! String
                files[index][1] = size; overrides[original] = file.path
            } else { files.append([path, size, 0]); overrides[path] = file.path }
        }
        for pack in loaded.packs {
            let prefix = "x64/dlcPacks/" + pack.name + "/"
            try add(prefix + "dlc.rpf", file: pack.url)
            for name in ["setup2.xml", "content.xml"] {
                guard let entry = pack.archive.entries.first(where: { $0.path == name }) else { throw ModError("DLC thiếu \(name)") }
                let target = runtime.appendingPathComponent(pack.name + "-" + name)
                try pack.archive.metadata(entry).write(to: target, options: .atomic)
                try add(prefix + name, file: target)
            }
            // This engine mounts DLC through platform:\dlcPacks, not update/x64/dlcpacks.
            let path = "platform:\\dlcPacks\\" + pack.name + "\\"
            if !xml.lowercased().contains(path.lowercased()) {
                if let range = xml.range(of: "</Paths>", options: .caseInsensitive) {
                    xml.replaceSubrange(range, with: "\t<Item>" + path + "</Item>\n" + xml[range])
                }
            }
        }
        let list = runtime.appendingPathComponent("dlcList.xml")
        try Data(xml.utf8).write(to: list, options: .atomic)
        try add("common/data/dlcList.xml", file: list)
        manifest["files"] = files; manifest["_mugoatOverrides"] = overrides
        let output = runtime.appendingPathComponent("manifest.json")
        try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys]).write(to: output, options: .atomic)
        return (output, loaded)
    }

    // MARK: - Import

    /// Validates a dlc.rpf and installs it as mods/<pack>/dlc.rpf. A file that is not a valid
    /// DLC pack is rejected with the reason; it is never copied into the mods folder.
    @discardableResult
    static func importPack(_ source: URL, into mods: URL) throws -> ModPack {
        let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        guard size <= maxPackBytes else {
            throw ModError("Tệp \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) vượt giới hạn 100 MB.")
        }
        let pack = try ModPack(url: source)
        let fm = FileManager.default
        let directory = mods.appendingPathComponent(pack.name)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent("import-" + UUID().uuidString + ".rpf")
        let target = directory.appendingPathComponent("dlc.rpf")
        try fm.copyItem(at: source, to: temporary)
        defer { try? fm.removeItem(at: temporary) }
        if fm.fileExists(atPath: target.path) { _ = try fm.replaceItemAt(target, withItemAt: temporary) }
        else { try fm.moveItem(at: temporary, to: target) }
        let installed = try ModPack(url: target)
        disableDuplicates(of: installed.name, keeping: target, in: mods)
        return installed
    }

    /// Older imports could leave a second copy of the same pack elsewhere in mods/, which makes
    /// the catalog reject both. Extra copies are renamed to .disabled, never deleted.
    private static func disableDuplicates(of name: String, keeping target: URL, in mods: URL) {
        let keep = target.resolvingSymlinksInPath().standardizedFileURL.path
        for entry in ModFiles.scan(mods) where entry.isEnabled && entry.url.pathExtension.lowercased() == "rpf" {
            if entry.url.standardizedFileURL.path == keep { continue }
            if case .success(let other) = load(entry), other.name == name {
                try? FileManager.default.moveItem(at: entry.url, to: entry.url.appendingPathExtension("disabled"))
            }
        }
    }

    // MARK: - Accept any mod file

    /// Largest loose file that is kept (the app copies, never edits, what it accepts).
    static let maxStoreBytes: Int64 = 1024 * 1024 * 1024

    /// Copies any accepted file into mods/<folder>/<relative path>. Existing copies are replaced.
    /// Path components such as ".." are dropped so nothing can land outside mods/.
    @discardableResult
    static func store(_ source: URL, folder: String, relative: String, into mods: URL) throws -> URL {
        let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        guard size <= maxStoreBytes else {
            throw ModError("Tệp \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) quá lớn để lưu.")
        }
        let fm = FileManager.default
        var target = mods
        let cleanFolder = folder.split(separator: "/").map { String($0) }.filter { !$0.isEmpty && $0 != "." && $0 != ".." }
        for part in cleanFolder { target.appendPathComponent(part) }
        let parts = relative.split(separator: "/").map { String($0) }.filter { !$0.isEmpty && $0 != "." && $0 != ".." }
        guard !parts.isEmpty else { throw ModError("Đường dẫn tệp không hợp lệ.") }
        for part in parts { target.appendPathComponent(part) }
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
        try fm.copyItem(at: source, to: target)
        return target
    }

    private static func folderName(for name: String) -> String {
        let stem = (name as NSString).deletingPathExtension
        let cleaned = stem.unicodeScalars.map { scalar -> String in
            let ok = (scalar.value >= 48 && scalar.value <= 57) || (scalar.value >= 65 && scalar.value <= 90)
                || (scalar.value >= 97 && scalar.value <= 122) || scalar == "_" || scalar == "-" || scalar == "."
            return ok ? String(scalar) : "_"
        }.joined()
        return cleaned.isEmpty ? "mod" : String(cleaned.prefix(48))
    }

    /// Accepts one picked file of any type. A valid DLC pack is installed as mods/<pack>/dlc.rpf.
    /// Everything else (loose .ytd/.yft/.meta, encrypted or Enhanced packs, scripts...) is still
    /// saved and listed with its detected type; the reason it is not mounted is shown next to it.
    static func importFile(_ source: URL, into mods: URL) -> ImportReport {
        var report = ImportReport()
        let name = source.lastPathComponent
        let ext = source.pathExtension.lowercased()
        guard ModFiles.isModFile(source) else {
            report.problems.append("\(name): là ảnh hoặc tệp hướng dẫn, không phải mod nên bỏ qua.")
            return report
        }
        if ext == "rpf" {
            do {
                report.installed.append(try importPack(source, into: mods))
                return report
            } catch {
                report.problems.append("\(name): \(error.localizedDescription) Tệp vẫn được lưu để bạn xem lại.")
            }
        }
        do {
            let size = Int64((try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            let folder = ext == "rpf" ? "unverified-\(folderName(for: name))-\(size)" : "loose"
            let target = try store(source, folder: folder, relative: name, into: mods)
            let info = ModFiles.classify(target, original: target)
            report.stored.append("\(name) — \(info.title)" + (info.detail.isEmpty ? "" : " · " + info.detail))
            report.looseFiles += 1
        } catch {
            report.problems.append("\(name): không lưu được (\(error.localizedDescription)).")
        }
        return report
    }

    /// Unpacks an archive into a hidden staging folder, installs every valid dlc.rpf found in it and
    /// saves every other mod file (with its folder structure) under mods/<archive name>/.
    /// Nothing is silently dropped: every file ends up installed, stored or listed as a problem.
    static func installArchive(_ archive: URL, into mods: URL) -> ImportReport {
        var report = ImportReport()
        let fm = FileManager.default
        let label = archive.lastPathComponent
        let staging = mods.appendingPathComponent(".import-" + UUID().uuidString)
        defer { try? fm.removeItem(at: staging) }
        do {
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        } catch {
            report.problems.append("\(label): không tạo được thư mục tạm (\(error.localizedDescription)).")
            return report
        }
        let count = gi_extract_archive(archive.path, staging.path)
        if count <= 0 {
            report.problems.append("\(label): không giải nén được. Hỗ trợ .zip và .rar; .7z chưa được hỗ trợ (hãy nén lại thành .zip). Tệp cũng có thể bị lỗi hoặc đặt mật khẩu.")
            return report
        }
        guard let walker = fm.enumerator(at: staging, includingPropertiesForKeys: [.isRegularFileKey], options: []) else {
            report.problems.append("\(label): không đọc được nội dung đã giải nén.")
            return report
        }
        let stagingPath = staging.resolvingSymlinksInPath().standardizedFileURL.path
        var found: [URL] = []
        for case let url as URL in walker {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            found.append(url)
        }
        found.sort { $0.path < $1.path }
        let folder = folderName(for: label)
        for url in found {
            let ext = url.pathExtension.lowercased()
            var relative = url.resolvingSymlinksInPath().standardizedFileURL.path
            if relative.hasPrefix(stagingPath) { relative = String(relative.dropFirst(stagingPath.count)) }
            while relative.hasPrefix("/") { relative.removeFirst() }
            if ModFiles.archiveExtensions.contains(ext) {
                report.problems.append("\(label) › \(relative): tệp nén lồng nhau, hãy giải nén ra rồi nhập lại.")
                continue
            }
            guard ModFiles.isModFile(url) else { continue }
            if ext == "rpf" {
                do {
                    report.installed.append(try importPack(url, into: mods))
                    continue
                } catch {
                    report.problems.append("\(label) › \(relative): \(error.localizedDescription) Tệp vẫn được lưu để bạn xem lại.")
                }
            }
            do {
                let target = try store(url, folder: folder, relative: relative, into: mods)
                let info = ModFiles.classify(target, original: target)
                report.stored.append("\(relative) — \(info.title)" + (info.detail.isEmpty ? "" : " · " + info.detail))
                report.looseFiles += 1
            } catch {
                report.problems.append("\(label) › \(relative): không lưu được (\(error.localizedDescription)).")
            }
        }
        if report.installed.isEmpty && report.stored.isEmpty && report.problems.isEmpty {
            report.problems.append("\(label): không có tệp mod nào bên trong (chỉ có ảnh hoặc hướng dẫn).")
        }
        return report
    }
}

/// Follows the engine's vehicle spawn request so the UI can say what really happened.
enum ModSpawn {
    /// Calls `done` on the main queue: true = vehicle created, false = engine gave up, nil = still loading.
    static func watch(timeout: TimeInterval = 75, _ done: @escaping (Bool?) -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        func poll() {
            let status = PGSpawnVehicleStatus()
            if status == 2 {
                done(true)
            } else if status == -1 {
                done(false)
            } else if Date() > deadline {
                done(nil)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { poll() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { poll() }
    }

    static let failureHint = "Nguyên nhân thường gặp: mod nhập sau khi game đã chạy (hãy thoát hẳn app rồi mở lại), gói thiếu model hoặc vehicles.meta, hoặc sai tên model. Bấm ⓘ ở tệp mod để xem báo cáo."
}
