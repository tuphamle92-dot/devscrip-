#include "GameInstallerShim.h"

#include <archive.h>
#include <archive_entry.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

struct gi_reader {
    struct archive *archive;
    gi_read_fn read;
    void *context;
};

static la_ssize_t gi_read_proxy(struct archive *a, void *client, const void **buffer) {
    (void)a;
    gi_reader *reader = (gi_reader *)client;
    long n = reader->read(reader->context, buffer);
    if (n < 0) {
        archive_set_error(a, ECANCELED, "Reading the archive stopped");
        return ARCHIVE_FATAL;
    }
    return (la_ssize_t)n;
}

gi_reader *gi_reader_open(gi_read_fn read, void *context) {
    gi_reader *reader = calloc(1, sizeof *reader);
    if (!reader) return NULL;
    reader->read = read;
    reader->context = context;
    reader->archive = archive_read_new();
    if (!reader->archive) { free(reader); return NULL; }
    struct archive *a = reader->archive;
    archive_read_support_filter_none(a);
    archive_read_support_filter_gzip(a);
    archive_read_support_format_zip_streamable(a);
    archive_read_support_format_rar(a);
    archive_read_support_format_rar5(a);
    archive_read_support_format_tar(a);
    // No seek callback: libarchive reads strictly front to back, which is what lets
    // the caller delete or punch out bytes it has already handed over.
    if (archive_read_open(a, reader, NULL, gi_read_proxy, NULL) != ARCHIVE_OK) {
        // Keep the reader so the caller can read the error message; next() will fail.
    }
    return reader;
}

int gi_reader_next(gi_reader *reader, gi_entry_info *info) {
    struct archive_entry *entry = NULL;
    memset(info, 0, sizeof *info);
    int r = archive_read_next_header(reader->archive, &entry);
    if (r == ARCHIVE_EOF) return GI_EOF;
    if (r == ARCHIVE_FATAL || r == ARCHIVE_FAILED || r == ARCHIVE_RETRY) {
        if (r == ARCHIVE_FATAL) return GI_FATAL;
        // ARCHIVE_FAILED with an entry still lets us skip it; report as failed.
        if (!entry) return GI_FATAL;
    }
    const char *path = archive_entry_pathname_utf8(entry);
    if (!path) path = archive_entry_pathname(entry);
    info->path = path ? path : "";
    info->size_known = archive_entry_size_is_set(entry) ? 1 : 0;
    info->size = info->size_known ? archive_entry_size(entry) : -1;
    switch (archive_entry_filetype(entry)) {
        case AE_IFREG: info->kind = GI_ENTRY_FILE; break;
        case AE_IFDIR: info->kind = GI_ENTRY_DIRECTORY; break;
        case AE_IFLNK: info->kind = GI_ENTRY_SYMLINK; break;
        default:
            // Some zips have no type bits; treat a path ending in '/' as a folder.
            if (archive_entry_filetype(entry) == 0) {
                size_t len = strlen(info->path);
                info->kind = (len > 0 && info->path[len - 1] == '/') ? GI_ENTRY_DIRECTORY : GI_ENTRY_FILE;
            } else {
                info->kind = GI_ENTRY_OTHER;
            }
    }
    if (archive_entry_hardlink(entry) != NULL) info->kind = GI_ENTRY_SYMLINK; // never follow links
    info->encrypted = archive_entry_is_encrypted(entry) ? 1 : 0;
    if (r == ARCHIVE_FAILED) return GI_FAILED;
    return r == ARCHIVE_WARN ? GI_WARN : GI_OK;
}

int gi_reader_data(gi_reader *reader, const void **buffer, size_t *size, int64_t *offset) {
    la_int64_t off = 0;
    int r = archive_read_data_block(reader->archive, buffer, size, &off);
    *offset = off;
    if (r == ARCHIVE_EOF) return GI_EOF;
    if (r == ARCHIVE_OK) return GI_OK;
    if (r == ARCHIVE_WARN) return GI_OK;
    return r == ARCHIVE_FATAL ? GI_FATAL : GI_FAILED;
}

int gi_reader_skip(gi_reader *reader) {
    int r = archive_read_data_skip(reader->archive);
    if (r == ARCHIVE_OK || r == ARCHIVE_WARN) return GI_OK;
    return r == ARCHIVE_FATAL ? GI_FATAL : GI_FAILED;
}

const char *gi_reader_error(gi_reader *reader) { return archive_error_string(reader->archive); }
int gi_reader_errno(gi_reader *reader) { return archive_errno(reader->archive); }
const char *gi_reader_format_name(gi_reader *reader) { return archive_format_name(reader->archive); }
int gi_reader_has_encrypted_entries(gi_reader *reader) { return archive_read_has_encrypted_entries(reader->archive); }

void gi_reader_close(gi_reader *reader) {
    if (!reader) return;
    archive_read_free(reader->archive);
    free(reader);
}

int gi_punch_hole(int fd, int64_t offset, int64_t length, int64_t block) {
#ifdef F_PUNCHHOLE
    if (block <= 0) block = 4096;
    int64_t start = (offset + block - 1) / block * block;
    int64_t end = (offset + length) / block * block;
    if (end <= start) return 0;
    struct fpunchhole args;
    memset(&args, 0, sizeof args);
    args.fp_offset = start;
    args.fp_length = end - start;
    if (fcntl(fd, F_PUNCHHOLE, &args) == -1) return errno ? errno : EIO;
    return 0;
#else
    (void)fd; (void)offset; (void)length; (void)block;
    return ENOTSUP;
#endif
}

const char *gi_libarchive_version(void) { return archive_version_details(); }

struct gi_extract_ctx {
    FILE *fp;
    char buf[65536];
};

static long gi_extract_read_cb(void *context, const void **buffer) {
    struct gi_extract_ctx *c = (struct gi_extract_ctx *)context;
    size_t n = fread(c->buf, 1, sizeof(c->buf), c->fp);
    *buffer = c->buf;
    return (long)n;
}

/// Normalises an archive path to a safe relative path: backslashes become slashes, "./" and
/// empty parts are dropped, and any ".." part or absolute path is rejected (path traversal).
/// Returns 1 and fills `out` on success, 0 if the entry must be skipped.
static int gi_clean_path(const char *in, char *out, size_t cap) {
    char tmp[1024];
    size_t len = strlen(in);
    if (len == 0 || len >= sizeof tmp || cap < sizeof tmp) return 0;
    memcpy(tmp, in, len + 1);
    for (size_t i = 0; i < len; i++) if (tmp[i] == '\\') tmp[i] = '/';
    size_t o = 0;
    char *save = NULL;
    for (char *tok = strtok_r(tmp, "/", &save); tok; tok = strtok_r(NULL, "/", &save)) {
        if (strcmp(tok, ".") == 0) continue;
        if (strcmp(tok, "..") == 0) return 0;
        size_t t = strlen(tok);
        if (o + t + 2 > cap) return 0;
        if (o) out[o++] = '/';
        memcpy(out + o, tok, t);
        o += t;
    }
    out[o] = '\0';
    return o > 0;
}

/// mkdir -p for `path` (modified in place while walking, restored before returning).
static void gi_mkdir_p(char *path) {
    for (char *p = path + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(path, 0755);
            *p = '/';
        }
    }
    mkdir(path, 0755);
}

#define GI_EXTRACT_TOTAL_LIMIT ((int64_t)1 << 30) /* 1 GiB: stops zip bombs */

int gi_extract_archive(const char *archive_path, const char *dest_dir) {
    if (!archive_path || !dest_dir) return -1;
    FILE *fp = fopen(archive_path, "rb");
    if (!fp) return -1;

    struct gi_extract_ctx *ctx = calloc(1, sizeof *ctx);
    if (!ctx) { fclose(fp); return -1; }
    ctx->fp = fp;

    gi_reader *reader = gi_reader_open(gi_extract_read_cb, ctx);
    if (!reader) {
        free(ctx);
        fclose(fp);
        return -1;
    }

    int files_extracted = 0;
    int failed = 0;
    int64_t total = 0;
    gi_entry_info info;
    int next;
    while ((next = gi_reader_next(reader, &info)) == GI_OK || next == GI_WARN) {
        char rel[1024];
        if (!info.path || !gi_clean_path(info.path, rel, sizeof rel)) {
            gi_reader_skip(reader);
            continue;
        }
        // Hidden files, macOS resource forks and .DS_Store are never mods.
        if (rel[0] == '.' || strstr(rel, "/.") || strncmp(rel, "__MACOSX/", 9) == 0) {
            gi_reader_skip(reader);
            continue;
        }

        char full_dest[1024];
        int n = snprintf(full_dest, sizeof full_dest, "%s/%s", dest_dir, rel);
        if (n <= 0 || (size_t)n >= sizeof full_dest) {
            failed++;
            gi_reader_skip(reader);
            continue;
        }

        if (info.kind == GI_ENTRY_DIRECTORY) {
            gi_mkdir_p(full_dest);
            continue;
        }

        if (info.kind != GI_ENTRY_FILE || info.encrypted) {
            if (info.kind == GI_ENTRY_FILE) failed++;
            gi_reader_skip(reader);
            continue;
        }

        char parent[1024];
        snprintf(parent, sizeof parent, "%s", full_dest);
        char *slash = strrchr(parent, '/');
        if (slash) {
            *slash = '\0';
            gi_mkdir_p(parent);
        }

        int fd = open(full_dest, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW, 0644);
        if (fd < 0) {
            failed++;
            gi_reader_skip(reader);
            continue;
        }

        int ok = 1;
        int r;
        const void *buf = NULL;
        size_t size = 0;
        int64_t offset = 0;
        while ((r = gi_reader_data(reader, &buf, &size, &offset)) == GI_OK) {
            const char *bytes = (const char *)buf;
            size_t left = size;
            total += (int64_t)size;
            if (total > GI_EXTRACT_TOTAL_LIMIT) { ok = 0; break; }
            while (ok && left > 0 && bytes) {
                ssize_t w = write(fd, bytes, left);
                if (w <= 0) { ok = 0; break; }
                bytes += w;
                left -= (size_t)w;
            }
            if (!ok) break;
        }
        if (r != GI_EOF) ok = 0; // truncated, corrupt or bad CRC: never keep a partial file
        close(fd);
        if (!ok) {
            unlink(full_dest);
            failed++;
            if (total > GI_EXTRACT_TOTAL_LIMIT || r == GI_FATAL) break;
            continue;
        }
        files_extracted++;
    }

    gi_reader_close(reader);
    free(ctx);
    fclose(fp);
    if (files_extracted == 0) return failed ? -1 : 0;
    return files_extracted;
}
