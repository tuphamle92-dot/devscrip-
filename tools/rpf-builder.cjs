// tools/rpf-builder.cjs - Standalone GTA V RPF7 Packager for Mugoat
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

class RpfWriter {
  constructor() {
    this.directories = new Map(); // path -> { name, children: [] }
    this.files = new Map(); // path -> { name, data, isResource, unpackedSize, systemFlags, graphicsFlags }
    this.directories.set('', { name: '', children: [] });
  }

  addDirectory(dirPath) {
    const parts = dirPath.split(/[/\\]/).filter(Boolean);
    let cur = '';
    for (const p of parts) {
      const next = cur ? `${cur}/${p.toLowerCase()}` : p.toLowerCase();
      if (!this.directories.has(next)) {
        this.directories.set(next, { name: p.toLowerCase(), children: [] });
        this.directories.get(cur).children.push({ type: 'dir', path: next });
      }
      cur = next;
    }
    return cur;
  }

  addFile(filePath, buffer) {
    const parts = filePath.split(/[/\\]/).filter(Boolean);
    const fileName = parts.pop().toLowerCase();
    const dirPath = this.addDirectory(parts.join('/'));

    let isResource = false;
    let unpackedSize = buffer.length;
    let systemFlags = 0;
    let graphicsFlags = 0;

    // Check if RSC7 resource (.yft, .ytd, .ydd, .ymt, etc.)
    if (buffer.length >= 16 && buffer.toString('latin1', 0, 4) === 'RSC7') {
      isResource = true;
      systemFlags = buffer.readUInt32LE(8);
      graphicsFlags = buffer.readUInt32LE(12);
    }

    this.files.set(filePath.toLowerCase(), {
      name: fileName,
      data: buffer,
      isResource,
      unpackedSize,
      systemFlags,
      graphicsFlags
    });

    this.directories.get(dirPath).children.push({ type: 'file', path: filePath.toLowerCase() });
  }

  build() {
    // 1. Flatten all entries depth-first: root first, then its directories/files
    const entryList = []; // each entry: { type, path, name }
    const assignEntries = (dirPath) => {
      const dirObj = this.directories.get(dirPath);
      const myIdx = entryList.length;
      entryList.push({ type: 'dir', path: dirPath, name: dirObj.name, dirObj });
      return myIdx;
    };

    // Flatten entries matching CodeWalker RpfFile.EnsureAllEntries
    const allEntries = [];
    const rootEntry = { type: 'dir', path: '', name: '', startIndex: 0, count: 0, dirObj: this.directories.get('') };
    allEntries.push(rootEntry);

    const queue = [rootEntry];
    while (queue.length > 0) {
      const parent = queue.shift();
      const dirObj = parent.dirObj;

      const subDirs = dirObj.children.filter(c => c.type === 'dir').map(c => {
        const dObj = this.directories.get(c.path);
        return { type: 'dir', path: c.path, name: dObj.name, startIndex: 0, count: 0, dirObj: dObj };
      });

      const subFiles = dirObj.children.filter(c => c.type === 'file').map(c => {
        const fObj = this.files.get(c.path);
        return { type: 'file', path: c.path, name: fObj.name, fileObj: fObj };
      });

      const children = [...subDirs, ...subFiles];
      children.sort((a, b) => a.name.localeCompare(b.name));

      parent.startIndex = allEntries.length;
      parent.count = children.length;

      for (const child of children) {
        allEntries.push(child);
        if (child.type === 'dir') {
          queue.push(child);
        }
      }
    }

    // 2. Build string table (names)
    const nameOffsets = new Map();
    let namesBuf = Buffer.from('\0');
    nameOffsets.set('', 0);
    const addName = (name) => {
      if (nameOffsets.has(name)) return nameOffsets.get(name);
      const off = namesBuf.length;
      const strBuf = Buffer.from(name + '\0', 'utf8');
      namesBuf = Buffer.concat([namesBuf, strBuf]);
      nameOffsets.set(name, off);
      return off;
    };

    for (const e of allEntries) {
      if (e.name) addName(e.name);
    }

    // 3. Calculate header size: 16 (magic) + entries.length * 16 + namesBuf.length
    const tocSize = 16 + allEntries.length * 16 + namesBuf.length;
    // Align data start to 512 bytes
    const dataStart = Math.ceil(tocSize / 512) * 512;

    // 4. Place files in data area (each aligned to 512 bytes)
    let curOffset = dataStart;
    for (const e of allEntries) {
      if (e.type === 'file') {
        e.offset = curOffset;
        e.size = e.fileObj.data.length;
        curOffset += Math.ceil(e.size / 512) * 512;
      }
    }

    // 5. Build RPF buffer
    const out = Buffer.alloc(curOffset);
    // Magic: RPF7 (0x52504637)
    out.writeUInt32LE(0x52504637, 0);
    out.writeUInt32LE(allEntries.length, 4);
    out.writeUInt32LE(namesBuf.length, 8);
    // OPEN (0x4E45504F)
    out.writeUInt32LE(0x4E45504F, 12);

    // Write TOC entries
    for (let i = 0; i < allEntries.length; i++) {
      const e = allEntries[i];
      const at = 16 + i * 16;
      const nameOff = e.name ? nameOffsets.get(e.name) : 0;

      if (e.type === 'dir') {
        out.writeUInt32LE(nameOff, at);
        out.writeUInt32LE(0x7fffff00, at + 4);
        out.writeUInt32LE(e.startIndex, at + 8);
        out.writeUInt32LE(e.count, at + 12);
      } else {
        const fileObj = e.fileObj;
        const blockOff = Math.floor(e.offset / 512);

        if (fileObj.isResource) {
          // Resource entry
          const first = (nameOff & 0xffff) | ((e.size & 0xffffff) << 16);
          const second = 0x80000000 | ((blockOff & 0x7fffff) << 8);
          out.writeUInt32LE(first >>> 0, at);
          out.writeUInt32LE(second >>> 0, at + 4);
          out.writeUInt32LE(fileObj.systemFlags >>> 0, at + 8);
          out.writeUInt32LE(fileObj.graphicsFlags >>> 0, at + 12);
        } else {
          // Binary entry
          const first = (nameOff & 0xffff) | 0; // size 0 indicates uncompressed
          const second = (blockOff & 0xffffff) << 8;
          out.writeUInt32LE(first >>> 0, at);
          out.writeUInt32LE(second >>> 0, at + 4);
          out.writeUInt32LE(e.size >>> 0, at + 8); // unpacked size
          out.writeUInt32LE(0, at + 12); // flags (unencrypted)
        }
      }
    }

    // Write names
    namesBuf.copy(out, 16 + allEntries.length * 16);

    // Write file data
    for (const e of allEntries) {
      if (e.type === 'file') {
        e.fileObj.data.copy(out, e.offset);
      }
    }

    return out;
  }
}

module.exports = { RpfWriter };
