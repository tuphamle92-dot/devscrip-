const cp = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const runId = '38602866289';
const tag = 'v1.1.7';
const title = 'Mugoat iOS v1.1.7 — Voice Chat 3D, Chọn Role, Mua Súng Ammu-Nation & Phục Hồi Độ Phân Giải Native Tối Đa';
const rootDir = path.resolve(__dirname, '..');
const keyFile = path.join(rootDir, 'build', 'release-8.10', 'artifact.key');
const artifactScript = path.join(rootDir, 'native-port', 'app', 'Scripts', 'ipa-artifact.cjs');
const outputDir = path.join(rootDir, 'build', `artifacts-${runId}`);

function exec(cmd, args, options = {}) {
  return cp.execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'inherit', 'inherit'], ...options });
}

async function main() {
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  console.log(`[Tải về] Đang tải artifact từ workflow run ${runId}...`);
  try {
    exec('gh', ['run', 'download', runId, '-n', 'Mugoat-Native-IPAs-encrypted', '-D', outputDir]);
  } catch (e) {
    console.error('Lỗi tải artifact:', e.message);
    process.exit(1);
  }

  const encFree = path.join(outputDir, 'Mugoat-AppleID-Free.enc');
  const ipaFree = path.join(outputDir, 'Mugoat.ipa');

  if (!fs.existsSync(encFree)) {
    console.error('Không tìm thấy tệp mã hóa trong:', outputDir);
    process.exit(1);
  }

  if (fs.existsSync(ipaFree)) fs.unlinkSync(ipaFree);

  console.log(`[Giải mã] Đang giải mã Mugoat.ipa...`);
  cp.execFileSync('node', [artifactScript, 'decrypt', encFree, ipaFree, keyFile], { stdio: 'inherit' });

  const releaseNotes = path.join(rootDir, 'release_v117_notes.md');
  const notesContent = `# Mugoat iOS v1.1.7 — Voice Chat 3D, Mở Native 4K, Sửa Lỗi Crash RAM & Cận Chiến

Bản phát hành chính thức **v1.1.7** mang đến trải nghiệm Multiplayer ổn định và hoàn thiện nhất, sửa triệt để các lỗi văng game OOM, bổ sung Voice Chat 3D, chọn Role không cần tài khoản, mở độ phân giải tối đa 4K và sửa toàn bộ lỗi cận chiến:

---

### 🌟 Các cải tiến và sửa lỗi chính trong bản v1.1.7:

1. **🛡️ Khắc Phục Triệt Để Lỗi Crash / Văng Game Trên Mọi Độ Phân Giải:**
   - Khôi phục bộ điều phối bộ nhớ thông minh (\`NativeMemoryBudget\`) với giới hạn dự phòng an toàn 384 MB theo chuẩn nhân iOS Jetsam.
   - Tự động thu hồi tài nguyên cũ phía sau lưng khi bộ nhớ tiến trình tăng cao, chấm dứt hoàn toàn hiện tượng văng game sau 1-2 phút ở 1080p cũng như ở độ phân giải thấp nhất.

2. **🥊 Sửa Triệt Để Lỗi Cận Chiến (Bò Trườn / Vừa Bò Vừa Đánh / Giật Đứng):**
   - Đồng bộ thời gian ngã sàn giữa các người chơi từ 2500ms về chuẩn 600-800ms.
   - Hủy ngay ragdoll bằng \`ClearPedTasksImmediately\` khi người chơi đứng dậy, hết giật khung hình.
   - Chặn hoàn toàn lệnh di chuyển (\`walk\`) và đánh (\`swing\`) khi nhân vật đang nằm sàn, không còn lỗi vừa bò vừa vung tay đấm.
   - Cân bằng đòn đánh: chỉ đòn nặng (sát thương >= 25) hoặc súng điện mới gây ngã sàn.

3. **💎 Mở Khóa Độ Phân Giải Màn Hình Tối Đa Lên 4K (2160p):**
   - Thêm Preset **Tối đa (4K)** và danh sách độ phân giải tùy chỉnh lên tới **2160p (4K)** và **Native 4K** cho mọi thiết bị.
   - iPhone 14/15/16 Pro Max hiển thị chuẩn 1290p Native, iPad Pro chuẩn 1620p - 2048p siêu sắc nét.

4. **🎙️ Loa & Micro Voice Chat Không Gian 3D (Proximity Voice Chat):**
   - Tích hợp 2 nút tiện ích **Loa** (\`speaker\`) và **Micro** (\`mic\`) ngay trên màn hình.
   - Âm thanh không gian 3D: nghe rõ trong 5m, giảm dần đến 35m, ngoài 35m im lặng. Hỗ trợ tai nghe Bluetooth / AirPods.

5. **🎭 Chọn Vai Trò Trực Tiếp (Role System Không Cần Đăng Ký):**
   - Chọn Role trong menu **Cài đặt Online**: Dân thường, Cảnh sát, Bác sĩ, Băng đảng, Tài xế.
   - Tự động hiển thị thẻ tên 3D trên đầu nhân vật: \`[Cảnh sát] Tên - 100%\`.

6. **🚗 Sửa Phím Điều Khiển Xe & Bàn Xoay Radio Wheel:**
   - Sửa lỗi lên ô tô bị nhầm phím máy bay. Phục hồi đầy đủ ga, phanh chân, phanh tay, còi, đèn pha.
   - Phục hồi nút Radio và vòng xoay chọn kênh đài bằng cử chỉ vuốt.

7. **🏝️ Sửa Lỗi Rơi Xuống Biển / Rơi Xuyên Map:**
   - Xóa bỏ mã kéo dịch chuyển ngoài khơi.
   - Thêm hệ thống giải cứu an toàn tự động đưa về trung tâm thành phố kèm 8 giây khiên bảo vệ.

8. **🔫 Chống Cheat & Kinh Tế Súng Ammu-Nation:**
   - Khóa cheat console/gamepad trong Multiplayer. Tiền lương $250/3 phút, thưởng hạ gục $500. Đến tiệm súng có nút Giỏ hàng mua súng và nạp đạn hợp lệ.

---

### 📦 Tệp cài đặt:
- **\`Mugoat.ipa\`**: Bản cài đặt IPA chính thức duy nhất, tương thích 100% với mọi thiết bị iOS và công cụ sideload (TrollStore, ESign, Scarlet, Sideloadly, AltStore, SideStore, LiveContainer).
- **\`Native-IPA-Free-validation.json\`** & **\`SHA256SUMS.txt\`**: Mã băm kiểm tra tính toàn vẹn của tệp IPA.
`;
  fs.writeFileSync(releaseNotes, notesContent, 'utf8');

  console.log(`\n[Phát hành] Đang tạo Release ${tag}...`);
  const filesToUpload = [ipaFree];

  const mbslkRpf = 'D:\\Telegram\\mbslk.rpf';
  if (fs.existsSync(mbslkRpf)) filesToUpload.push(mbslkRpf);

  const sumsFile = path.join(outputDir, 'SHA256SUMS.txt');
  if (fs.existsSync(sumsFile)) filesToUpload.push(sumsFile);

  const valFree = path.join(outputDir, 'Native-IPA-Free-validation.json');
  if (fs.existsSync(valFree)) filesToUpload.push(valFree);

  try {
    exec('gh', ['release', 'create', tag, ...filesToUpload, '--title', title, '--notes-file', releaseNotes]);
  } catch (e) {
    console.log(`Release ${tag} có thể đã tồn tại, tiến hành upload đè...`);
    exec('gh', ['release', 'upload', tag, ...filesToUpload, '--clobber']);
  }

  console.log(`\n✅ HOÀN TẤT! Đã phát hành chính thức ${tag}!`);
  console.log(`🔗 Link Release: https://github.com/iOSVNNews/mugoat/releases/tag/${tag}`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
