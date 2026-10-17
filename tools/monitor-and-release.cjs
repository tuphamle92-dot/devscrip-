const cp = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const runId = process.argv[2] || '38510796524';
const tag = process.argv[3] || 'v1.1.4';
const rootDir = path.resolve(__dirname, '..');
const keyFile = path.join(rootDir, 'build', 'release-8.10', 'artifact.key');
const artifactScript = path.join(rootDir, 'native-port', 'app', 'Scripts', 'ipa-artifact.cjs');
const outputDir = path.join(rootDir, 'build', `artifacts-${runId}`);

if (!fs.existsSync(keyFile)) {
  console.error('Artifact key not found at:', keyFile);
  process.exit(1);
}

function exec(cmd, args, options = {}) {
  return cp.execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], ...options });
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  console.log(`[Monitor] Bắt đầu theo dõi GitHub Actions run: ${runId} cho tag: ${tag}`);
  console.log(`[Monitor] Kiểm tra trạng thái mỗi 30 giây...`);

  let startTime = Date.now();
  let done = false;
  let runConclusion = '';

  while (!done) {
    try {
      const output = exec('gh', ['run', 'view', runId, '--json', 'status,conclusion']);
      const data = JSON.parse(output.trim());
      const elapsedMinutes = Math.floor((Date.now() - startTime) / 60000);
      const elapsedSeconds = Math.floor(((Date.now() - startTime) % 60000) / 1000);
      const timeStr = `${elapsedMinutes}m ${elapsedSeconds}s`;

      console.log(`[${new Date().toLocaleTimeString()}] Trạng thái: ${data.status} (đã chạy: ${timeStr})`);

      if (data.status === 'completed') {
        done = true;
        runConclusion = data.conclusion;
      }
    } catch (err) {
      console.warn(`[Cảnh báo] Lỗi khi kiểm tra trạng thái run: ${err.message}`);
    }

    if (!done) {
      await sleep(30000);
    }
  }

  if (runConclusion !== 'success') {
    console.error(`[Thất bại] Workflow kết thúc với trạng thái: ${runConclusion}`);
    try {
      const failedLogs = exec('gh', ['run', 'view', runId, '--log-failed']);
      console.error(failedLogs);
    } catch (e) {}
    process.exit(1);
  }

  console.log(`\n🎉 [Thành công] Workflow ${runId} đã hoàn tất thành công!`);
  console.log(`[Tải về] Đang tải artifact Mugoat-Native-IPAs-encrypted...`);

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  exec('gh', ['run', 'download', runId, '-n', 'Mugoat-Native-IPAs-encrypted', '--dir', outputDir]);
  console.log(`[Tải về] Đã tải xong artifact vào ${outputDir}`);

  const encFree = path.join(outputDir, 'Mugoat-AppleID-Free.enc');
  const encPaid = path.join(outputDir, 'Mugoat-Cert-Paid.enc');
  const ipaFree = path.join(outputDir, 'Mugoat.ipa');
  const ipaPaid = path.join(outputDir, 'Mugoat-Cert-Paid.ipa');

  if (fs.existsSync(ipaFree)) fs.unlinkSync(ipaFree);
  if (fs.existsSync(ipaPaid)) fs.unlinkSync(ipaPaid);

  console.log(`[Giải mã] Đang giải mã Mugoat.ipa...`);
  cp.execFileSync('node', [artifactScript, 'decrypt', encFree, ipaFree, keyFile], { stdio: 'inherit' });

  console.log(`[Giải mã] Đang giải mã Mugoat-Cert-Paid.ipa...`);
  cp.execFileSync('node', [artifactScript, 'decrypt', encPaid, ipaPaid, keyFile], { stdio: 'inherit' });

  console.log(`\n[Phát hành] Đang đẩy tệp IPA và validation lên Release ${tag}...`);

  const filesToUpload = [
    ipaFree,
    ipaPaid
  ];

  const mbslkRpf = 'D:\\Telegram\\mbslk.rpf';
  if (fs.existsSync(mbslkRpf)) filesToUpload.push(mbslkRpf);

  const sumsFile = path.join(outputDir, 'SHA256SUMS.txt');
  if (fs.existsSync(sumsFile)) filesToUpload.push(sumsFile);

  const valFree = path.join(outputDir, 'Native-IPA-Free-validation.json');
  if (fs.existsSync(valFree)) {
    const valDest = path.join(outputDir, 'Native-IPA-validation.json');
    fs.copyFileSync(valFree, valDest);
    filesToUpload.push(valDest);
  }

  exec('gh', ['release', 'upload', tag, ...filesToUpload, '--clobber']);

  console.log(`\n✅ HOÀN TẤT! Toàn bộ file IPA đã được cập nhật lên bản phát hành chính thức ${tag}!`);
  console.log(`🔗 Link Release: https://github.com/iOSVNNews/mugoat/releases/tag/${tag}`);
}

main().catch(err => {
  console.error('[Lỗi nghiêm trọng]', err);
  process.exit(1);
});
