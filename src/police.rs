//! Nghề cảnh sát (chạy được cả offline lẫn online).
//!
//! Nghe canh sat (chay trong che do Online, cung noi chay mp.rs).
//!
//! Luong choi (chu trong game viet khong dau de font GTA5 khong bi loi):
//!  1. Vao sanh don Mission Row -> nut "Mua sung" -> noi chuyen voi quan ly (nhieu cau thoai),
//!     cho kiem tra ly lich -> duoc nhan lam canh sat.
//!  2. Vao phong thay do -> nut "Mua sung" -> thay dong phuc (nhan vat freemode) -> nhan ca.
//!     Tren nguoi chi con sung luc, taser, con tran. Het ca (dong ho game) hoac bam nut
//!     o phong thay do thi tra lai do thuong va sung.
//!  3. Dien thoai do chuong -> nut "Mua sung" de nghe may -> tong dai bao vu an, vi tri,
//!     cham do tren ban do. Len xe se co huong dan khoang cach/huong toi hien truong.
//!  4. Nghi pham thay minh thi bo chay. Gio sung ngam vao -> bo sung, gio 2 tay.
//!  5. Lai gan -> nut cong tay. Cong xong no di theo minh.
//!  6. Nut dua len xe -> cho ve don -> phat xong nhan tien cong vao vi.
//!  7. Dang truc: danh nguoi/NPC khong bi nhay sao (dung nhom quan he, xem calm_wanted).
//!
//! Nut bam: dung lai nut "Mua sung" co san (lib.rs chuyen sang police::action khi co goi y).
//! Chi dung cac native co san trong COMMANDS cua mp.rs, nen khong can sua script build.
use crate::engine_bridge::{Caller, Val};
use crate::proto;
use crate::{read_cstr, read_u32, read_u64, write_bytes, write_u32, write_u64, HostState};
use std::sync::atomic::{AtomicBool, AtomicI32, AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

// ---------------------------------------------------------------------------
// Các thông số có thể chỉnh
// ---------------------------------------------------------------------------

/// Sảnh đồn Mission Row: nơi xin việc.
const LOBBY: [f32; 3] = [441.5, -978.0, 30.7];
const LOBBY_RADIUS: f32 = 7.5;
/// Cho thay do / nhan ca / nghi ca: dat ngay trong sanh (khu cong cong) vi di sau vao ben
/// trong don la khu vuc cam, bi nhay 3 sao. Muon doi cho thi sua toa do o day.
const LOCKER: [f32; 3] = LOBBY;
const LOCKER_RADIUS: f32 = 7.0;
/// Cham xanh don canh sat tren ban do (sprite 60 = Police Station).
const STATION_BLIP: [f32; 3] = LOBBY;
/// Moi dong thoai / thong bao hien tren man hinh trong bao nhieu mili giay.
const LINE_MS: u64 = 2800;
/// Hien dong toa do + trang thai native o tren cung man hinh khi o gan don (de chinh vi tri).
const DEBUG_OVERLAY: bool = true;
/// Quan ly tu dong noi chuyen khi ban chay lai gan trong ban kinh nay (met).
const TALK_RADIUS: f32 = 3.2;
/// Cong an canh gac trong sanh don (vi tri, huong nhin).
const GUARDS: &[([f32; 3], f32)] = &[([439.2, -979.4, 30.7], 270.0), ([443.8, -976.6, 30.7], 90.0)];
const GUARD_MODEL: &str = "s_m_y_cop_01";
const GUARD_GREETINGS: &[&str] = &[
    "~g~[Cong an]~s~ Chao dong chi! Chuc dong chi ngay lam viec tot lanh.",
    "~g~[Cong an]~s~ Dong chi can giup gi cu noi nhe.",
    "~g~[Cong an]~s~ Giu gin an ninh trat tu cho thanh pho nhe dong chi!",
];
/// Cua tai don Mission Row thu mo khoa neu engine co lenh cua (model, toa do). Co the sai, xem DEBUG_OVERLAY.
const DOORS: &[(&str, [f32; 3])] = &[
    ("v_ilev_ph_door01", [434.7479, -980.6184, 30.8153]),
    ("v_ilev_ph_door01", [434.7479, -983.2151, 30.8153]),
];
/// 4 đồn cảnh sát (giống chấm xanh trên bản đồ): nơi giao nghi phạm.
const STATIONS: [[f32; 3]; 4] = [
    [426.0, -981.8, 30.7],
    [638.5, 1.5, 44.7],
    [1848.7, 3689.9, 34.3],
    [-442.2, 6012.3, 31.7],
];
const BOOK_RADIUS: f32 = 28.0;
/// Độ dài ca trực tính theo đồng hồ trong game (phút game). 720 = 12 giờ game.
const SHIFT_MINUTES: i32 = 720;
/// Phòng khi đồng hồ game bị đứng: tối đa bao nhiêu giây thật thì hết ca.
const SHIFT_REAL_SECS: u64 = 2400;
const MAX_WANTED: usize = 3;
const FINE_SHOOTING: i32 = 1500;
const FINE_ASSAULT: i32 = 600;
const FINE_ROBBERY: i32 = 900;
const ESCAPE_PENALTY: i32 = 200;
/// Giay dien thoai do chuong truoc khi bi lo cuoc goi.
const CALL_TIMEOUT_SECS: u64 = 16;
/// Nghi pham thay nguoi choi trong ban kinh nay thi bo chay.
const SEE_RADIUS: f32 = 28.0;
/// Quan ly dung o sanh don (nhan vat NPC de noi chuyen xin viec). Thu lan luot cac model.
const MANAGER_POS: [f32; 3] = [441.5, -978.0, 30.7];
const MANAGER_MODELS: &[&str] = &["s_m_m_fibsec_01", "s_m_m_ciasec_01", "s_m_y_cop_01"];
/// Vu khi duoc giu khi dang truc.
const DUTY_WEAPONS: &[&str] = &["weapon_pistol", "weapon_stungun", "weapon_nightstick"];
/// Dong phuc canh sat (component, drawable, texture) cho nhan vat freemode.
/// Con so la bo mac dinh pho bien, co the lech tuy ban game: sua tai day neu do nhin chua dung.
const MALE_COMPONENTS: &[(i32, i32, i32)] =
    &[(3, 41, 0), (4, 25, 0), (6, 25, 0), (8, 59, 0), (11, 55, 0), (5, 0, 0), (7, 0, 0), (9, 0, 0), (10, 0, 0)];
const MALE_PROPS: &[(i32, i32, i32)] = &[(0, 46, 0)];
const FEMALE_COMPONENTS: &[(i32, i32, i32)] =
    &[(3, 44, 0), (4, 34, 0), (6, 27, 0), (8, 36, 1), (11, 48, 0), (5, 0, 0), (7, 0, 0), (9, 0, 0), (10, 0, 0)];
const FEMALE_PROPS: &[(i32, i32, i32)] = &[(0, 45, 0)];
/// Cac o phu kien (mu, kinh, tai...) duoc luu lai de tra do khi het ca.
const PROP_IDS: &[i32] = &[0, 1, 2, 6, 7];

// ---------------------------------------------------------------------------
// Hằng số kỹ thuật (giống mp.rs)
// ---------------------------------------------------------------------------

const ACTIVE_THREAD_TLS: u64 = 3088;
const THREAD_NAME: u64 = 428;
const SCRATCH: i64 = 2048;
const S_INT: u64 = 160;
const S_VEHS: u64 = 256;
const S_PEDS: u64 = 1024;
const S_DICT: u64 = 1360;
const S_CLIP: u64 = 1430;
const S_TEXT: u64 = 1500;
const S_NAME: u64 = 1520;
const S_SET: u64 = 1700;
const NEARBY_MAX: u64 = 40;
const PREFERRED: &[&str] = &["main_persistent", "standard_global_reg", "main", "sandbox", "freemode"];

const HANDS_UP: &[(&str, &str)] = &[
    ("missminuteman_1ig_2", "handsup_base"),
    ("random@mugging3", "handsup_standing_base"),
];
const CUFFED: &[(&str, &str)] = &[("mp_arresting", "idle")];

const COP_MODELS: &[&str] = &[
    "s_m_y_cop_01", "s_f_y_cop_01", "s_m_y_hwaycop_01", "s_m_y_sheriff_01", "s_f_y_sheriff_01",
    "s_m_y_swat_01", "s_m_y_ranger_01", "s_f_y_ranger_01", "s_m_m_snowcop_01", "csb_cop",
];

const WEAPONS: &[&str] = &[
    "weapon_knife", "weapon_nightstick", "weapon_hammer", "weapon_bat", "weapon_golfclub", "weapon_crowbar",
    "weapon_bottle", "weapon_dagger", "weapon_hatchet", "weapon_knuckle", "weapon_machete", "weapon_flashlight",
    "weapon_switchblade", "weapon_battleaxe", "weapon_poolcue", "weapon_wrench",
    "weapon_pistol", "weapon_combatpistol", "weapon_appistol", "weapon_pistol50", "weapon_snspistol",
    "weapon_heavypistol", "weapon_vintagepistol", "weapon_marksmanpistol", "weapon_revolver", "weapon_doubleaction",
    "weapon_stungun",
    "weapon_microsmg", "weapon_smg", "weapon_assaultsmg", "weapon_combatpdw", "weapon_machinepistol",
    "weapon_minismg", "weapon_gusenberg",
    "weapon_assaultrifle", "weapon_carbinerifle", "weapon_advancedrifle", "weapon_specialcarbine",
    "weapon_bullpuprifle", "weapon_compactrifle",
    "weapon_mg", "weapon_combatmg",
    "weapon_pumpshotgun", "weapon_sawnoffshotgun", "weapon_assaultshotgun", "weapon_bullpupshotgun",
    "weapon_musket", "weapon_heavyshotgun", "weapon_dbshotgun", "weapon_autoshotgun",
    "weapon_sniperrifle", "weapon_heavysniper", "weapon_marksmanrifle",
    "weapon_grenadelauncher", "weapon_rpg", "weapon_minigun", "weapon_railgun", "weapon_hominglauncher",
    "weapon_compactlauncher", "weapon_firework",
    "weapon_grenade", "weapon_stickybomb", "weapon_molotov", "weapon_smokegrenade", "weapon_flaregun",
    "weapon_ball", "weapon_snowball", "weapon_petrolcan",
];

// ---------------------------------------------------------------------------
// Trạng thái dùng chung với Swift (qua lib.rs)
// ---------------------------------------------------------------------------

static DISABLED: AtomicBool = AtomicBool::new(false);
static ACTION: AtomicBool = AtomicBool::new(false);
static HINT: AtomicI32 = AtomicI32::new(0);
static RNG: AtomicU64 = AtomicU64::new(0x9E37_79B9_7F4A_7C15);

/// Hang cho cac dong thoai / thong bao (hien giua duoi man hinh thay cho ticker ben trai).
static HUD: Mutex<Vec<(String, Option<Instant>)>> = Mutex::new(Vec::new());
/// Vi tri nguoi choi gan nhat + da nhan viec chua + dong chan doan (de ve moi khung hinh).
static LAST_POS: Mutex<Option<[f32; 3]>> = Mutex::new(None);
static DEBUG_LINE: Mutex<String> = Mutex::new(String::new());
static HIRED_FLAG: AtomicBool = AtomicBool::new(false);
static T0: OnceLock<Instant> = OnceLock::new();

fn hud_push(text: &str) {
    let mut h = HUD.lock().unwrap();
    if h.len() >= 8 {
        h.remove(0);
    }
    h.push((text.to_string(), None));
}

fn hud_busy() -> bool {
    !HUD.lock().unwrap().is_empty()
}

fn hint_text(hint: i32) -> &'static str {
    match hint {
        1 => "~b~[LSPD]~s~ Bam nut MUA SUNG de noi chuyen xin viec",
        2 => "~b~[LSPD]~s~ Bam nut MUA SUNG de thay dong phuc, nhan ca",
        3 => "~b~[LSPD]~s~ Bam nut MUA SUNG de cong tay nghi pham",
        4 => "~b~[LSPD]~s~ Bam nut MUA SUNG de dua nghi pham len xe",
        5 => "~b~[LSPD]~s~ Bam nut MUA SUNG de ket thuc ca",
        6 => "~y~[Dien thoai]~s~ Bam nut MUA SUNG de nghe may",
        _ => "",
    }
}

pub fn enabled() -> bool {
    !DISABLED.load(Ordering::Relaxed)
}

pub fn disable() {
    DISABLED.store(true, Ordering::Relaxed);
    HINT.store(0, Ordering::Relaxed);
}

/// 0 = khong hien, 1 = Xin viec (noi chuyen), 2 = Thay do nhan ca, 3 = Cong tay,
/// 4 = Dua len xe, 5 = Ket thuc ca, 6 = Nghe may.
pub fn hint() -> i32 {
    HINT.load(Ordering::Relaxed)
}

/// Người chơi vừa bấm nút cảnh sát.
pub fn action() {
    ACTION.store(true, Ordering::Relaxed);
}

fn rnd() -> u32 {
    let mut x = RNG.load(Ordering::Relaxed);
    if x == 0 {
        x = 0x9E37_79B9_7F4A_7C15;
    }
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    RNG.store(x, Ordering::Relaxed);
    (x >> 32) as u32
}

// ---------------------------------------------------------------------------
// Dữ liệu
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, PartialEq, Eq)]
enum Phase {
    Shooting,
    Wanted,
    Surrender,
    Cuffed,
    Seated,
    Booked,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Outcome {
    Keep,
    Booked,
    Escaped,
    Dead,
    Lost,
}

struct Suspect {
    ped: i32,
    blip: i32,
    crime: u8,
    scripted: bool,
    phase: Phase,
    victim: i32,
    target: [f32; 3],
    shots: i32,
    since: Instant,
    last: Instant,
    anim_at: Instant,
    loaded_at: Instant,
    veh: i32,
    seat: i32,
    in_car: bool,
    warped: bool,
    dist: f32,
    pos: [f32; 3],
}

impl Suspect {
    fn new(ped: i32, blip: i32, crime: u8, scripted: bool) -> Suspect {
        let now = Instant::now();
        let old = old_instant();
        Suspect {
            ped,
            blip,
            crime,
            scripted,
            phase: Phase::Wanted,
            victim: 0,
            target: [0.0; 3],
            shots: 0,
            since: now,
            last: old,
            anim_at: old,
            loaded_at: now,
            veh: 0,
            seat: 1,
            in_car: false,
            warped: false,
            dist: 999.0,
            pos: [0.0; 3],
        }
    }
}

struct Call {
    since: Instant,
    last_ring: Instant,
}

struct Manager {
    ped: i32,
    model: usize,
    since: Instant,
    tried: Instant,
}

struct State {
    caps_done: bool,
    cap_stars: bool,
    cap_doors: bool,
    stars_off: bool,
    doors_at: Instant,
    doors_added: bool,
    guards: Vec<i32>,
    guard_tried: Instant,
    greet_at: Instant,
    station_blip: i32,
    blip_tried: Instant,
    interview: u8,
    interview_at: Instant,
    talk_guard: Instant,
    mgr: Manager,
    changing: Option<Instant>,
    outfit: Vec<(i32, i32, i32, i32)>,
    props: Vec<(i32, i32, i32)>,
    outfit_on: bool,
    call: Option<Call>,
    warned: bool,
    prev_in_car: bool,
    route_at: Instant,
    group: i32,
    tagged: Vec<(i32, i32)>,
    last_group: Instant,
    hired: bool,
    on_duty: bool,
    shift_left: i32,
    last_clock: i32,
    duty_since: Instant,
    saved: Vec<(i32, i32)>,
    suspects: Vec<Suspect>,
    next_dispatch: Instant,
    last_scan: Instant,
    last_enforce: Instant,
    prev_hint: i32,
    arrests: i32,
}

impl State {
    fn new() -> State {
        let seed = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos() as u64)
            .unwrap_or(1);
        RNG.store(seed | 1, Ordering::Relaxed);
        let now = Instant::now();
        State {
            caps_done: false,
            cap_stars: false,
            cap_doors: false,
            stars_off: false,
            doors_at: old_instant(),
            doors_added: false,
            guards: Vec::new(),
            guard_tried: old_instant(),
            greet_at: old_instant(),
            station_blip: 0,
            blip_tried: old_instant(),
            interview: 0,
            interview_at: now,
            talk_guard: old_instant(),
            mgr: Manager { ped: 0, model: 0, since: now, tried: old_instant() },
            changing: None,
            outfit: Vec::new(),
            props: Vec::new(),
            outfit_on: false,
            call: None,
            warned: false,
            prev_in_car: false,
            route_at: old_instant(),
            group: 0,
            tagged: Vec::new(),
            last_group: old_instant(),
            hired: false,
            on_duty: false,
            shift_left: 0,
            last_clock: -1,
            duty_since: now,
            saved: Vec::new(),
            suspects: Vec::new(),
            next_dispatch: now,
            last_scan: now,
            last_enforce: now,
            prev_hint: 0,
            arrests: 0,
        }
    }

    fn tracked(&self, ped: i32) -> bool {
        self.suspects.iter().any(|s| s.ped == ped)
    }

    fn has_custody(&self) -> bool {
        self.suspects
            .iter()
            .any(|s| s.phase == Phase::Cuffed || s.phase == Phase::Seated || s.phase == Phase::Booked)
    }
}

/// Thông tin người chơi trong tick hiện tại.
#[derive(Clone, Copy)]
struct Ctx {
    me: [f32; 3],
    in_car: bool,
    veh: i32,
    aiming: bool,
    aim_from: [f32; 3],
    aim_dir: [f32; 3],
}

static STATE: Mutex<Option<State>> = Mutex::new(None);
static NEXT_RUN: Mutex<Option<Instant>> = Mutex::new(None);

struct Host {
    thread: u64,
    name: String,
    seen: Instant,
    born: Instant,
}
static HOST: Mutex<Option<Host>> = Mutex::new(None);

fn old_instant() -> Instant {
    Instant::now().checked_sub(Duration::from_secs(10)).unwrap_or_else(Instant::now)
}

// ---------------------------------------------------------------------------
// Cầu nối gọi native (giống mp.rs)
// ---------------------------------------------------------------------------

struct Cmd<'a, 'b> {
    caller: &'a mut Caller<'b, HostState>,
    scratch: u64,
}

fn call(caller: &mut Caller<'_, HostState>, name: &str, args: &[Val]) -> Option<Val> {
    let func = caller.get_export(name)?.into_func()?;
    let ty = func.ty(&mut *caller);
    let args = crate::coerce_args(args, &ty);
    let mut out: Vec<Val> = ty.results().map(|t| crate::default_val(&t)).collect();
    if let Err(e) = func.call(&mut *caller, &args, &mut out) {
        eprintln!("[police] {name} trapped: {e}");
        return None;
    }
    Some(out.into_iter().next().unwrap_or(Val::I32(0)))
}

/// Goi native voi so tham so tuy y: thieu thi dien 0, thua thi bo.
/// Dung cho native tu dong do ten luc build (khong biet chinh xac chu ky).
fn call_flex(caller: &mut Caller<'_, HostState>, name: &str, args: &[Val]) -> Option<Val> {
    let func = caller.get_export(name)?.into_func()?;
    let ty = func.ty(&mut *caller);
    let params: Vec<u32> = ty.params().collect();
    let mut fitted: Vec<Val> = Vec::with_capacity(params.len());
    for k in 0..params.len() {
        fitted.push(if k < args.len() { args[k] } else { crate::default_val(&params[k]) });
    }
    let fitted = crate::coerce_args(&fitted, &ty);
    let mut out: Vec<Val> = ty.results().map(|t| crate::default_val(&t)).collect();
    if let Err(e) = func.call(&mut *caller, &fitted, &mut out) {
        eprintln!("[police] {name} trapped: {e}");
        return None;
    }
    Some(out.into_iter().next().unwrap_or(Val::I32(0)))
}

fn b(v: bool) -> Val {
    Val::I32(v as i32)
}
fn f(v: f32) -> Val {
    Val::F32(v.to_bits())
}
fn i(v: i32) -> Val {
    Val::I32(v)
}

fn dist(p: [f32; 3], q: [f32; 3]) -> f32 {
    ((p[0] - q[0]).powi(2) + (p[1] - q[1]).powi(2) + (p[2] - q[2]).powi(2)).sqrt()
}

fn dist2d(p: [f32; 3], q: [f32; 3]) -> f32 {
    ((p[0] - q[0]).powi(2) + (p[1] - q[1]).powi(2)).sqrt()
}

impl Cmd<'_, '_> {
    fn i(&mut self, cmd: &str, args: &[Val]) -> i32 {
        match call(self.caller, &format!("mp:{cmd}"), args) {
            Some(Val::I32(v)) => v,
            Some(Val::I64(v)) => v as i32,
            _ => 0,
        }
    }

    fn flex(&mut self, cmd: &str, args: &[Val]) -> i32 {
        match call_flex(self.caller, &format!("mp:{cmd}"), args) {
            Some(Val::I32(v)) => v,
            Some(Val::I64(v)) => v as i32,
            _ => 0,
        }
    }

    fn has(&mut self, cmd: &str) -> bool {
        match self.caller.get_export(&format!("mp:{cmd}")) {
            Some(e) => e.into_func().is_some(),
            None => false,
        }
    }

    fn f(&mut self, cmd: &str, args: &[Val]) -> f32 {
        match call(self.caller, &format!("mp:{cmd}"), args) {
            Some(Val::F32(v)) => f32::from_bits(v),
            _ => 0.0,
        }
    }

    fn mem(&self) -> &'static crate::SharedMemory {
        &crate::RT.get().unwrap().mem
    }

    fn read_f32(&self, off: u64) -> f32 {
        f32::from_bits(read_u32(self.mem(), self.scratch + off).unwrap_or(0))
    }

    fn read_i32(&self, off: u64) -> i32 {
        read_u32(self.mem(), self.scratch + off).unwrap_or(0) as i32
    }

    fn v(&mut self, cmd: &str, args: &[Val]) -> [f32; 3] {
        let mut full = vec![Val::I64(self.scratch as i64)];
        full.extend_from_slice(args);
        call(self.caller, &format!("mp:{cmd}"), &full);
        [self.read_f32(0), self.read_f32(8), self.read_f32(16)]
    }

    fn vec_arg(&self, slot: u64, v: [f32; 3]) -> Val {
        let p = self.scratch + 32 * slot;
        let m = self.mem();
        for (k, comp) in v.iter().enumerate() {
            write_u32(m, p + 8 * k as u64, comp.to_bits());
            write_u32(m, p + 8 * k as u64 + 4, 0);
        }
        Val::I64(p as i64)
    }

    fn ref_arg(&self, v: i32) -> Val {
        write_u32(self.mem(), self.scratch + S_INT, v as u32);
        Val::I64((self.scratch + S_INT) as i64)
    }

    /// Ghi chuỗi (cắt đúng ranh giới ký tự UTF-8) vào vùng scratch.
    fn put_str(&self, off: u64, text: &str, max: usize) {
        let mut end = text.len().min(max);
        while end > 0 && !text.is_char_boundary(end) {
            end -= 1;
        }
        let mut bytes: Vec<u8> = text.as_bytes()[..end].to_vec();
        bytes.push(0);
        write_bytes(self.mem(), self.scratch + off, &bytes);
    }

    fn ptr(&self, off: u64) -> Val {
        Val::I64((self.scratch + off) as i64)
    }

    fn exists(&mut self, ent: i32) -> bool {
        ent != 0 && self.i("DoesEntityExist", &[i(ent)]) != 0
    }

    fn nearby(&mut self, cmd: &str, ped: i32, off: u64, extra: &[Val]) -> Vec<i32> {
        let m = self.mem();
        write_u64(m, self.scratch + off, NEARBY_MAX);
        let mut args = vec![i(ped), self.ptr(off)];
        args.extend_from_slice(extra);
        let n = (self.i(cmd, &args).max(0) as u64).min(NEARBY_MAX);
        (0..n)
            .map(|k| read_u32(m, self.scratch + off + 8 + 8 * k).unwrap_or(0) as i32)
            .filter(|e| *e != 0)
            .collect()
    }

    /// Dua dong chu vao hang cho HUD (hien thanh den giua duoi man hinh).
    fn feed(&mut self, text: &str) {
        hud_push(text);
    }

    /// Ve mot thanh chu giua man hinh (goi moi khung hinh).
    fn draw_bar(&mut self, text: &str, y: f32, accent: (i32, i32, i32)) {
        self.i("DrawRect", &[f(0.5), f(y + 0.019), f(0.68), f(0.052), i(8), i(10), i(18), i(185), b(false)]);
        self.i("DrawRect", &[f(0.5), f(y - 0.0065), f(0.68), f(0.0025), i(accent.0), i(accent.1), i(accent.2), i(235), b(false)]);
        self.i("DrawRect", &[f(0.162), f(y + 0.019), f(0.004), f(0.052), i(accent.0), i(accent.1), i(accent.2), i(235), b(false)]);
        self.put_str(S_TEXT, "STRING", 16);
        self.put_str(S_NAME, text, 96);
        self.i("SetTextFont", &[i(4)]);
        self.i("SetTextScale", &[f(0.0), f(0.40)]);
        self.i("SetTextColour", &[i(255), i(255), i(255), i(240)]);
        self.i("SetTextCentre", &[b(true)]);
        self.i("SetTextOutline", &[]);
        self.i("BeginTextCommandDisplayText", &[self.ptr(S_TEXT)]);
        self.i("AddTextComponentSubStringPlayerName", &[self.ptr(S_NAME)]);
        self.i("EndTextCommandDisplayText", &[f(0.5), f(y), i(0)]);
    }

    /// Chu nho (toa do chan doan) o tren cung man hinh.
    fn draw_small(&mut self, text: &str, y: f32) {
        self.put_str(S_TEXT, "STRING", 16);
        self.put_str(S_NAME, text, 96);
        self.i("SetTextFont", &[i(0)]);
        self.i("SetTextScale", &[f(0.0), f(0.28)]);
        self.i("SetTextColour", &[i(255), i(230), i(120), i(235)]);
        self.i("SetTextCentre", &[b(true)]);
        self.i("SetTextOutline", &[]);
        self.i("BeginTextCommandDisplayText", &[self.ptr(S_TEXT)]);
        self.i("AddTextComponentSubStringPlayerName", &[self.ptr(S_NAME)]);
        self.i("EndTextCommandDisplayText", &[f(0.5), f(y), i(0)]);
    }

    /// Chu / hinh ve gan o vi tri the gioi (dung SetDrawOrigin nhu ten nguoi choi).
    fn draw_tag(&mut self, pos: [f32; 3], label: &str, arrow: bool) {
        let bob = if arrow {
            let t = T0.get_or_init(Instant::now).elapsed().as_millis() as f32 / 280.0;
            t.sin() * 0.006
        } else {
            0.0
        };
        let origin = self.vec_arg(2, pos);
        self.i("SetDrawOrigin", &[origin, b(false)]);
        if arrow {
            self.i("DrawRect", &[f(0.0), f(-0.028 + bob), f(0.020), f(0.007), i(40), i(130), i(255), i(240), b(false)]);
            self.i("DrawRect", &[f(0.0), f(-0.021 + bob), f(0.013), f(0.007), i(40), i(130), i(255), i(240), b(false)]);
            self.i("DrawRect", &[f(0.0), f(-0.014 + bob), f(0.006), f(0.007), i(40), i(130), i(255), i(240), b(false)]);
        }
        self.put_str(S_TEXT, "STRING", 16);
        self.put_str(S_NAME, label, 96);
        self.i("SetTextFont", &[i(4)]);
        self.i("SetTextScale", &[f(0.0), f(0.34)]);
        self.i("SetTextColour", &[i(255), i(255), i(255), i(235)]);
        self.i("SetTextCentre", &[b(true)]);
        self.i("SetTextOutline", &[]);
        self.i("BeginTextCommandDisplayText", &[self.ptr(S_TEXT)]);
        self.i("AddTextComponentSubStringPlayerName", &[self.ptr(S_NAME)]);
        let y = if arrow { -0.062 + bob } else { -0.01 };
        self.i("EndTextCommandDisplayText", &[f(0.0), f(y), i(0)]);
        self.i("ClearDrawOrigin", &[]);
    }

    fn play_sound(&mut self, name: &str, set: &str) {
        self.put_str(S_NAME, name, 40);
        self.put_str(S_SET, set, 40);
        let _ = self.i("PlaySoundFrontend", &[i(-1), self.ptr(S_NAME), self.ptr(S_SET), b(true)]);
    }

    fn sound_ok(&mut self) {
        self.play_sound("PURCHASE", "HUD_LIQUOR_STORE_SOUNDSET");
    }

    fn ring(&mut self) {
        self.play_sound("Remote_Ring", "Phone_SoundSet_Default");
    }
}

// ---------------------------------------------------------------------------
// Chọn script chủ (giống cách mp.rs chọn thread)
// ---------------------------------------------------------------------------

fn rank(name: &str) -> usize {
    PREFERRED.iter().position(|s| *s == name).unwrap_or(usize::MAX)
}

fn is_host(thread: u64, name: &str) -> bool {
    let mut guard = HOST.lock().unwrap();
    let host = guard.get_or_insert_with(|| Host {
        thread: 0,
        name: String::new(),
        seen: Instant::now(),
        born: Instant::now(),
    });
    let same = thread == host.thread && host.name.as_str() == name;
    if !same {
        let current_rank = rank(host.name.as_str());
        let new_rank = rank(name);
        let gone = host.seen.elapsed() > Duration::from_secs(2);
        let started = host.born.elapsed() > Duration::from_secs(5);
        if (new_rank < current_rank && new_rank != usize::MAX) || (gone && (new_rank != usize::MAX || started)) {
            host.thread = thread;
            host.name = name.to_string();
        } else {
            return false;
        }
    }
    host.seen = Instant::now();
    true
}

/// Được gọi từ lib.rs mỗi lần một script thread của game cập nhật.
pub fn tick(caller: &mut Caller<'_, HostState>, thread: u64, tls: u64) {
    let Some(rt) = crate::RT.get() else { return };
    let mem = &rt.mem;
    let name = read_cstr(mem, thread + THREAD_NAME);
    if !is_host(thread, &name) {
        return;
    }
    let due = {
        let mut next = NEXT_RUN.lock().unwrap();
        let ready = match *next {
            Some(t) => Instant::now() >= t,
            None => true,
        };
        if ready {
            *next = Some(Instant::now() + Duration::from_millis(90));
        }
        ready
    };
    let near_hud = match *LAST_POS.lock().unwrap() {
        Some(p) => dist2d(p, MANAGER_POS) < 250.0,
        None => false,
    };
    let drawing = HINT.load(Ordering::Relaxed) != 0 || hud_busy() || near_hud;
    if !due && !drawing {
        return;
    }
    let active = tls + ACTIVE_THREAD_TLS;
    let saved = read_u64(mem, active).unwrap_or(0);
    write_u64(mem, active, thread);
    let sp = call(caller, "emscripten_stack_get_current", &[]).map(|v| v.unwrap_i64()).unwrap_or(0);
    let scratch = call(caller, "_emscripten_stack_alloc", &[Val::I64(SCRATCH)])
        .map(|v| v.unwrap_i64() as u64)
        .unwrap_or(0);
    if scratch != 0 {
        let mut c = Cmd { caller, scratch };
        draw_hud(&mut c);
        if due {
            run(&mut c);
        }
    }
    if sp != 0 {
        let _ = call(caller, "_emscripten_stack_restore", &[Val::I64(sp)]);
    }
    write_u64(mem, active, saved);
}

// ---------------------------------------------------------------------------
// Vòng lặp chính
// ---------------------------------------------------------------------------

/// Ve dong thoai dang noi (tren) va goi y nut bam (duoi) moi khung hinh.
fn draw_hud(c: &mut Cmd) {
    let line: Option<String> = {
        let mut h = HUD.lock().unwrap();
        let expired = match h.first_mut() {
            Some(front) => {
                let started = *front.1.get_or_insert_with(Instant::now);
                started.elapsed() > Duration::from_millis(LINE_MS)
            }
            None => false,
        };
        if expired {
            h.remove(0);
        }
        h.first().map(|l| l.0.clone())
    };
    if let Some(text) = line {
        c.draw_bar(&text, 0.76, (40, 130, 255));
    }
    let prompt = hint_text(HINT.load(Ordering::Relaxed));
    if !prompt.is_empty() {
        c.draw_bar(prompt, 0.85, (60, 210, 110));
    }
    // Dau mui ten xanh tren dau quan ly (khi chua nhan viec) va the "CONG AN" tren dau cong an gac.
    let pos = *LAST_POS.lock().unwrap();
    if let Some(p) = pos {
        if dist2d(p, MANAGER_POS) < 45.0 {
            if !HIRED_FLAG.load(Ordering::Relaxed) {
                c.draw_tag([MANAGER_POS[0], MANAGER_POS[1], MANAGER_POS[2] + 1.45], "~b~XIN VIEC", true);
            } else {
                c.draw_tag([MANAGER_POS[0], MANAGER_POS[1], MANAGER_POS[2] + 1.15], "~b~QUAN LY", false);
            }
            for k in 0..GUARDS.len() {
                let g = GUARDS[k].0;
                c.draw_tag([g[0], g[1], g[2] + 1.15], "~g~CONG AN", false);
            }
        }
    }
    if DEBUG_OVERLAY {
        let line = DEBUG_LINE.lock().unwrap().clone();
        if !line.is_empty() {
            c.draw_small(&line, 0.012);
        }
    }
}

/// Cham xanh don canh sat tren ban do (tao lai neu mat).
fn ensure_station_blip(c: &mut Cmd, st: &mut State) {
    if st.station_blip != 0 && c.i("DoesBlipExist", &[i(st.station_blip)]) != 0 {
        return;
    }
    if st.blip_tried.elapsed() < Duration::from_secs(5) {
        return;
    }
    st.blip_tried = Instant::now();
    let pos = c.vec_arg(1, STATION_BLIP);
    let mut blip = c.i("AddBlipForCoord", &[pos]);
    if blip == 0 {
        let pos2 = c.vec_arg(1, STATION_BLIP);
        blip = c.i("AddBlipForCoord2", &[pos2]);
    }
    if blip == 0 {
        return;
    }
    c.i("SetBlipSprite", &[i(blip), i(60)]);
    c.i("SetBlipSprite2", &[i(blip), i(60)]);
    c.i("SetBlipColour", &[i(blip), i(3)]);
    c.i("SetBlipColour2", &[i(blip), i(3)]);
    c.i("SetBlipScale", &[i(blip), f(1.0)]);
    c.i("SetBlipScale2", &[i(blip), f(1.0)]);
    c.i("SetBlipAsShortRange", &[i(blip), b(false)]);
    c.i("SetBlipAsShortRange2", &[i(blip), b(false)]);
    st.station_blip = blip;
}

fn run(c: &mut Cmd) {
    let ped = c.i("PlayerPedId", &[]);
    if ped == 0 || !c.exists(ped) {
        HINT.store(0, Ordering::Relaxed);
        return;
    }
    let mut guard = STATE.lock().unwrap();
    let st = guard.get_or_insert_with(State::new);

    if c.i("IsPedDeadOrDying", &[i(ped), b(true)]) != 0 {
        HINT.store(0, Ordering::Relaxed);
        ACTION.store(false, Ordering::Relaxed);
        return;
    }
    let me = c.v("GetEntityCoords", &[i(ped), b(false)]);
    let in_car = c.i("IsPedInAnyVehicle", &[i(ped), b(false)]) != 0;
    let veh = if in_car { c.i("GetVehiclePedIsIn", &[i(ped), b(false)]) } else { 0 };
    let busy = c.i("GetMissionFlag", &[]) != 0;

    // 0. Cham don tren ban do, quan ly o sanh don, ho so dang duoc kiem tra, dang thay do.
    if !st.caps_done {
        st.caps_done = true;
        st.cap_stars = c.has("SetPlayerWantedLevel") || c.has("SetMaxWantedLevel") || c.has("SetPoliceIgnorePlayer");
        st.cap_doors = c.has("AddDoorToSystem") || c.has("DoorSystemSetDoorState") || c.has("SetStateOfClosestDoorOfType");
    }
    *LAST_POS.lock().unwrap() = Some(me);
    HIRED_FLAG.store(st.hired, Ordering::Relaxed);
    if DEBUG_OVERLAY {
        let text = if dist2d(me, MANAGER_POS) < 250.0 {
            let heading = c.f("GetEntityHeading", &[i(ped)]);
            format!(
                "LSPD x {:.1}  y {:.1}  z {:.1}  h {:.0}  |  cua: {}  sao: {}",
                me[0],
                me[1],
                me[2],
                heading,
                if st.cap_doors { "co" } else { "khong" },
                if st.cap_stars { "co" } else { "khong" }
            )
        } else {
            String::new()
        };
        *DEBUG_LINE.lock().unwrap() = text;
    }
    ensure_station_blip(c, st);
    manager_tick(c, st, me);
    guards_tick(c, st, me);
    auto_interview(c, st, me);
    no_stars(c, st, me);
    unlock_doors(c, st, me);
    if st.interview == 9 && st.interview_at.elapsed() >= Duration::from_secs(6) {
        st.interview = 0;
        st.hired = true;
        c.sound_ok();
        c.feed("~g~[LSPD]~s~ Ho so hop le! Chuc mung dong chi da gia nhap LSPD.");
        c.feed("~b~[Quan ly]~s~ Ra quay thay do ngay trong sanh de nhan dong phuc va nhan ca.");
    }
    if let Some(t) = st.changing {
        if Instant::now() >= t {
            st.changing = None;
            if st.hired && !st.on_duty {
                clock_in(c, st, ped);
            }
        }
    }

    // 1. Ca truc: het gio thi tra do va sung; dang truc thi chi giu sung luc, taser, con tran.
    if st.on_duty {
        let over = update_shift(c, st) || st.duty_since.elapsed() > Duration::from_secs(SHIFT_REAL_SECS);
        if over {
            end_shift(c, st, ped, true);
        } else {
            if !st.warned && st.shift_left <= 60 {
                st.warned = true;
                c.feed("~y~[LSPD]~s~ Sap het gio lam viec, hay ve don de nghi ngoi.");
            }
            if st.last_enforce.elapsed() >= Duration::from_millis(1500) {
                st.last_enforce = Instant::now();
                enforce_duty_kit(c, ped);
            }
            calm_wanted(c, st, ped);
        }
    }

    // 2. Nghi phạm đang theo dõi.
    if st.on_duty {
        let aiming = player_aiming(c, ped);
        let mut ctx = Ctx { me, in_car, veh, aiming, aim_from: [0.0; 3], aim_dir: [0.0; 3] };
        if aiming {
            let cam = c.v("GetGameplayCamCoord", &[]);
            let rot = c.v("GetGameplayCamRot", &[i(2)]);
            let pitch = rot[0].to_radians();
            let yaw = rot[2].to_radians();
            ctx.aim_from = cam;
            ctx.aim_dir = [-yaw.sin() * pitch.cos(), yaw.cos() * pitch.cos(), pitch.sin()];
        }
        let mut k = 0;
        while k < st.suspects.len() {
            let outcome = update_one(c, &mut st.suspects[k], &ctx);
            if outcome == Outcome::Keep {
                k += 1;
                continue;
            }
            let sus = st.suspects.remove(k);
            finish(c, st, sus, outcome);
        }
    }

    // 2b. Huong dan duong toi hien truong khi dang o tren xe.
    if st.on_duty {
        guide_to_scene(c, st, me, in_car);
    }

    // 3. Vu an moi: nhan ra NPC danh/ban nhau, hoac tong dai goi dien thoai bao an.
    if st.on_duty && !busy {
        if st.suspects.len() < MAX_WANTED && st.last_scan.elapsed() >= Duration::from_millis(700) {
            st.last_scan = Instant::now();
            scan_crimes(c, st, ped);
        }
        if st.suspects.is_empty() && st.call.is_none() && Instant::now() >= st.next_dispatch {
            st.call = Some(Call { since: Instant::now(), last_ring: old_instant() });
            c.feed("~y~[Dien thoai]~s~ Dien thoai cua ban dang do chuong...");
        }
        let mut ring = false;
        let mut missed = false;
        if let Some(cl) = st.call.as_mut() {
            if cl.since.elapsed() > Duration::from_secs(CALL_TIMEOUT_SECS) {
                missed = true;
            } else if cl.last_ring.elapsed() >= Duration::from_millis(1700) {
                cl.last_ring = Instant::now();
                ring = true;
            }
        }
        if missed {
            st.call = None;
            c.feed("~r~[Dien thoai]~s~ Ban da bo lo cuoc goi cua tong dai.");
            st.next_dispatch = Instant::now() + Duration::from_secs(15);
        } else if ring {
            c.ring();
        }
    }

    // 4. Nút bấm trên màn hình.
    let hint = compute_hint(c, st, ped, me, in_car);
    st.prev_hint = hint;
    HINT.store(hint, Ordering::Relaxed);
    if ACTION.swap(false, Ordering::Relaxed) {
        do_action(c, st, ped, in_car, hint);
    }
}

fn player_aiming(c: &mut Cmd, ped: i32) -> bool {
    const INPUT_AIM: i32 = 25;
    if c.i("IsPedArmed", &[i(ped), i(4)]) == 0 {
        return false;
    }
    let player = c.i("PlayerId", &[]);
    c.i("IsPlayerFreeAiming", &[i(player)]) != 0 || c.i("IsControlPressed", &[i(0), i(INPUT_AIM)]) != 0
}

fn aim_hits(cx: &Ctx, target: [f32; 3]) -> bool {
    if !cx.aiming {
        return false;
    }
    let vx = target[0] - cx.aim_from[0];
    let vy = target[1] - cx.aim_from[1];
    let vz = target[2] + 0.3 - cx.aim_from[2];
    let t = vx * cx.aim_dir[0] + vy * cx.aim_dir[1] + vz * cx.aim_dir[2];
    if t < 1.0 || t > 45.0 {
        return false;
    }
    let px = vx - cx.aim_dir[0] * t;
    let py = vy - cx.aim_dir[1] * t;
    let pz = vz - cx.aim_dir[2] * t;
    (px * px + py * py + pz * pz).sqrt() < 1.7
}

fn near_station(p: [f32; 3]) -> bool {
    STATIONS.iter().any(|s| dist(*s, p) < BOOK_RADIUS)
}

fn is_cop_model(model: i32) -> bool {
    COP_MODELS.iter().any(|n| proto::joaat(n) as i32 == model)
}

// ---------------------------------------------------------------------------
// Ca trực và vũ khí
// ---------------------------------------------------------------------------

fn has_weapon(c: &mut Cmd, ped: i32, hash: i32) -> bool {
    c.i("HasPedGotWeapon", &[i(ped), i(hash), b(false)]) != 0
        || c.i("HasPedGotWeapon2", &[i(ped), i(hash), b(false)]) != 0
}

fn give_pistol(c: &mut Cmd, ped: i32) {
    let pistol = proto::joaat("weapon_pistol") as i32;
    c.i("GiveWeaponToPed", &[i(ped), i(pistol), i(120), b(false), b(true)]);
    c.i("SetCurrentPedWeapon", &[i(ped), i(pistol), b(true)]);
}

fn duty_hashes() -> Vec<i32> {
    DUTY_WEAPONS.iter().map(|n| proto::joaat(n) as i32).collect()
}

fn give_duty_kit(c: &mut Cmd, ped: i32) {
    give_pistol(c, ped);
    for hash in duty_hashes() {
        if !has_weapon(c, ped, hash) {
            c.i("GiveWeaponToPed", &[i(ped), i(hash), i(120), b(false), b(false)]);
        }
    }
}

fn enforce_duty_kit(c: &mut Cmd, ped: i32) {
    let keep = duty_hashes();
    for name in WEAPONS {
        let hash = proto::joaat(name) as i32;
        if keep.contains(&hash) {
            continue;
        }
        if has_weapon(c, ped, hash) {
            c.i("RemoveWeaponFromPed", &[i(ped), i(hash)]);
            c.i("RemoveWeaponFromPed2", &[i(ped), i(hash)]);
        }
    }
    for hash in keep {
        if !has_weapon(c, ped, hash) {
            c.i("GiveWeaponToPed", &[i(ped), i(hash), i(120), b(false), b(false)]);
        }
    }
}

// ---------------------------------------------------------------------------
// Dong phuc
// ---------------------------------------------------------------------------

fn save_outfit(c: &mut Cmd, st: &mut State, ped: i32) {
    st.outfit.clear();
    st.props.clear();
    for comp in 0..12 {
        let d = c.i("GetPedDrawableVariation", &[i(ped), i(comp)]);
        let t = c.i("GetPedTextureVariation", &[i(ped), i(comp)]);
        let p = c.i("GetPedPaletteVariation", &[i(ped), i(comp)]);
        st.outfit.push((comp, d, t, p));
    }
    for prop in PROP_IDS {
        let idx = c.i("GetPedPropIndex", &[i(ped), i(*prop)]);
        let t = c.i("GetPropTextureIndex", &[i(ped), i(*prop)]);
        st.props.push((*prop, idx, t));
    }
}

/// Tra ve true neu mac duoc dong phuc (chi nhan vat freemode nam/nu co do canh sat).
fn apply_uniform(c: &mut Cmd, ped: i32) -> bool {
    let model = c.i("GetEntityModel", &[i(ped)]);
    let male = proto::joaat("mp_m_freemode_01") as i32;
    let female = proto::joaat("mp_f_freemode_01") as i32;
    let (comps, props): (&[(i32, i32, i32)], &[(i32, i32, i32)]) = if model == male {
        (MALE_COMPONENTS, MALE_PROPS)
    } else if model == female {
        (FEMALE_COMPONENTS, FEMALE_PROPS)
    } else {
        return false;
    };
    for k in 0..comps.len() {
        let (comp, drawable, tex) = comps[k];
        c.i("SetPedComponentVariation", &[i(ped), i(comp), i(drawable), i(tex), i(0)]);
    }
    for k in 0..props.len() {
        let (prop, drawable, tex) = props[k];
        c.i("SetPedPropIndex", &[i(ped), i(prop), i(drawable), i(tex), b(true)]);
    }
    true
}

fn restore_outfit(c: &mut Cmd, st: &State, ped: i32) {
    for k in 0..st.outfit.len() {
        let (comp, d, t, p) = st.outfit[k];
        c.i("SetPedComponentVariation", &[i(ped), i(comp), i(d), i(t), i(p)]);
    }
    for k in 0..st.props.len() {
        let (prop, idx, t) = st.props[k];
        if idx >= 0 {
            c.i("SetPedPropIndex", &[i(ped), i(prop), i(idx), i(t), b(true)]);
        } else {
            c.i("ClearPedProp", &[i(ped), i(prop)]);
        }
    }
}

// ---------------------------------------------------------------------------
// Khong bi nhay sao khi dang truc
// ---------------------------------------------------------------------------

fn duty_group(c: &mut Cmd, st: &mut State) -> i32 {
    let mut g = st.group;
    if g == 0 || c.i("DoesRelationshipGroupExist", &[i(g)]) == 0 {
        c.put_str(S_NAME, "LSPD_DUTY", 40);
        c.i("AddRelationshipGroup", &[c.ptr(S_NAME), c.ptr(S_INT)]);
        g = c.read_i32(S_INT);
        st.group = g;
    }
    if g != 0 {
        c.i("SetRelationshipGroupAffectsWantedLevel", &[i(g), b(false)]);
    }
    g
}

/// Dua cac ped xung quanh vao nhom "khong anh huong sao truy na". Het ca se tra lai nhom cu.
fn calm_wanted(c: &mut Cmd, st: &mut State, ped: i32) {
    if st.last_group.elapsed() < Duration::from_millis(1200) {
        return;
    }
    st.last_group = Instant::now();
    let g = duty_group(c, st);
    if g == 0 {
        return;
    }
    let mut k = 0;
    while k < st.tagged.len() {
        let p = st.tagged[k].0;
        if c.exists(p) {
            k += 1;
        } else {
            st.tagged.remove(k);
        }
    }
    for p in c.nearby("GetNearbyPeds", ped, S_PEDS, &[i(-1)]) {
        if p == ped || st.tagged.len() >= 200 || st.tracked(p) {
            continue;
        }
        if st.tagged.iter().any(|t| t.0 == p) {
            continue;
        }
        let old = c.i("GetPedRelationshipGroupHash", &[i(p)]);
        if old == g {
            continue;
        }
        c.i("SetPedRelationshipGroupHash", &[i(p), i(g)]);
        st.tagged.push((p, old));
    }
}

fn restore_groups(c: &mut Cmd, st: &mut State) {
    for k in 0..st.tagged.len() {
        let (p, old) = st.tagged[k];
        if old != 0 && c.exists(p) {
            c.i("SetPedRelationshipGroupHash", &[i(p), i(old)]);
        }
    }
    st.tagged.clear();
}

// ---------------------------------------------------------------------------
// Quan ly o sanh don
// ---------------------------------------------------------------------------

fn manager_tick(c: &mut Cmd, st: &mut State, me: [f32; 3]) {
    let near = dist2d(me, MANAGER_POS) < 45.0 && (me[2] - MANAGER_POS[2]).abs() < 8.0;
    if st.mgr.ped != 0 {
        if !c.exists(st.mgr.ped) {
            st.mgr.ped = 0;
        } else if !near {
            let r = c.ref_arg(st.mgr.ped);
            c.i("DeletePed", &[r]);
            st.mgr.ped = 0;
            st.mgr.since = Instant::now();
            return;
        } else {
            return;
        }
    }
    if !near || st.mgr.model >= MANAGER_MODELS.len() || st.mgr.tried.elapsed() < Duration::from_millis(800) {
        return;
    }
    st.mgr.tried = Instant::now();
    let hash = proto::joaat(MANAGER_MODELS[st.mgr.model]) as i32;
    if c.i("HasModelLoaded", &[i(hash)]) == 0 {
        c.i("RequestModel", &[i(hash)]);
        if st.mgr.since.elapsed() > Duration::from_secs(8) {
            st.mgr.model += 1;
            st.mgr.since = Instant::now();
        }
        return;
    }
    let pos = c.vec_arg(1, MANAGER_POS);
    let ped = c.i("CreatePed", &[i(4), i(hash), pos, f(0.0), b(false), b(false)]);
    if ped == 0 {
        return;
    }
    c.i("SetEntityAsMissionEntity", &[i(ped), b(true), b(true)]);
    c.i("SetBlockingOfNonTemporaryEvents", &[i(ped), b(true)]);
    c.i("SetPedKeepTask", &[i(ped), b(true)]);
    c.i("SetPedCanBeDraggedOut", &[i(ped), b(false)]);
    c.i("SetPedCanRagdoll", &[i(ped), b(false)]);
    c.i("SetEntityInvincible", &[i(ped), b(true)]);
    let facing = (-(me[0] - MANAGER_POS[0])).atan2(me[1] - MANAGER_POS[1]).to_degrees();
    c.i("SetEntityHeading", &[i(ped), f(facing)]);
    c.i("FreezeEntityPosition", &[i(ped), b(true)]);
    st.mgr.ped = ped;
}

fn interview_step(c: &mut Cmd, st: &mut State) {
    if st.talk_guard.elapsed() < Duration::from_millis(1200) || hud_busy() {
        return;
    }
    st.talk_guard = Instant::now();
    match st.interview {
        0 => {
            c.feed("~b~[Quan ly]~s~ Chao dong chi! Toi la quan ly don Mission Row.");
            c.feed("~y~[Ban]~s~ Chao sep, toi den xin viec lam canh sat.");
            st.interview = 1;
        }
        1 => {
            c.feed("~b~[Quan ly]~s~ Dong chi da tung lam nghe gi? Co kinh nghiem khong?");
            c.feed("~y~[Ban]~s~ Toi co kinh nghiem bao ve, muon cong hien cho thanh pho.");
            st.interview = 2;
        }
        2 => {
            c.feed("~b~[Quan ly]~s~ Ly lich co tien an tien su gi khong?");
            c.feed("~y~[Ban]~s~ Thua sep, ly lich cua toi hoan toan trong sach.");
            st.interview = 3;
        }
        3 => {
            c.feed("~b~[Quan ly]~s~ Lam canh sat phai tuan thu luat, khong duoc lam dung sung.");
            c.feed("~y~[Ban]~s~ Toi hieu, toi xin thuc hien nghiem tuc moi quy dinh.");
            st.interview = 4;
        }
        4 => {
            c.feed("~b~[Quan ly]~s~ Tot lam. Dong chi dien don, toi se kiem tra ho so.");
            c.feed("~s~Dang kiem tra ho so...");
            st.interview = 9;
            st.interview_at = Instant::now();
        }
        _ => {}
    }
}

/// Quan ly tu noi chuyen khi chay lai gan; chay xa qua thi huy.
fn auto_interview(c: &mut Cmd, st: &mut State, me: [f32; 3]) {
    if st.hired || st.on_duty || st.interview == 9 {
        return;
    }
    let d = dist2d(me, MANAGER_POS);
    if st.interview == 0 {
        if d < TALK_RADIUS && (me[2] - MANAGER_POS[2]).abs() < 3.0 {
            interview_step(c, st);
        }
        return;
    }
    if d > 12.0 {
        st.interview = 0;
        c.feed("~r~Ban da bo di giua chung cuoc phong van.");
        return;
    }
    interview_step(c, st);
}

/// Cong an canh gac trong sanh (nhan vat NPC), chao khi ban lai gan.
fn guards_tick(c: &mut Cmd, st: &mut State, me: [f32; 3]) {
    let near = dist2d(me, MANAGER_POS) < 60.0 && (me[2] - MANAGER_POS[2]).abs() < 8.0;
    if !near {
        if !st.guards.is_empty() {
            for k in 0..st.guards.len() {
                let g = st.guards[k];
                if c.exists(g) {
                    let r = c.ref_arg(g);
                    c.i("DeletePed", &[r]);
                }
            }
            st.guards.clear();
        }
        return;
    }
    if st.guards.is_empty() {
        if st.guard_tried.elapsed() < Duration::from_millis(1500) {
            return;
        }
        st.guard_tried = Instant::now();
        let hash = proto::joaat(GUARD_MODEL) as i32;
        if c.i("HasModelLoaded", &[i(hash)]) == 0 {
            c.i("RequestModel", &[i(hash)]);
            return;
        }
        for k in 0..GUARDS.len() {
            let (pos, heading) = GUARDS[k];
            let p = c.vec_arg(1, pos);
            let ped = c.i("CreatePed", &[i(6), i(hash), p, f(heading), b(false), b(false)]);
            if ped == 0 {
                continue;
            }
            c.i("SetEntityAsMissionEntity", &[i(ped), b(true), b(true)]);
            c.i("SetBlockingOfNonTemporaryEvents", &[i(ped), b(true)]);
            c.i("SetPedKeepTask", &[i(ped), b(true)]);
            c.i("SetPedCanRagdoll", &[i(ped), b(false)]);
            c.i("SetEntityInvincible", &[i(ped), b(true)]);
            c.i("FreezeEntityPosition", &[i(ped), b(true)]);
            st.guards.push(ped);
        }
        return;
    }
    if st.greet_at.elapsed() >= Duration::from_secs(25) {
        for k in 0..GUARDS.len() {
            if dist2d(me, GUARDS[k].0) < 2.8 {
                st.greet_at = Instant::now();
                let line = GUARD_GREETINGS[(rnd() as usize) % GUARD_GREETINGS.len()];
                c.feed(line);
                break;
            }
        }
    }
}

/// Dang truc (hoac da nhan viec va o trong khu don): khong bi truy na / nhay sao.
fn no_stars(c: &mut Cmd, st: &mut State, me: [f32; 3]) {
    if !st.cap_stars {
        return;
    }
    let want = st.on_duty || (st.hired && dist2d(me, STATION_BLIP) < 70.0);
    let player = c.i("PlayerId", &[]);
    if want != st.stars_off {
        st.stars_off = want;
        c.flex("SetMaxWantedLevel", &[i(if want { 0 } else { 5 })]);
        c.flex("SetPoliceIgnorePlayer", &[i(player), b(want)]);
    }
    if want {
        c.flex("SetPlayerWantedLevel", &[i(player), i(0), b(false)]);
        c.flex("SetPlayerWantedLevelNow", &[i(player), b(false)]);
    }
}

/// Thu mo khoa cua don (neu engine co lenh cua). Danh sach cua trong DOORS.
fn unlock_doors(c: &mut Cmd, st: &mut State, me: [f32; 3]) {
    if !st.cap_doors || !st.hired || dist2d(me, STATION_BLIP) > 60.0 {
        return;
    }
    if st.doors_at.elapsed() < Duration::from_millis(1500) {
        return;
    }
    st.doors_at = Instant::now();
    for k in 0..DOORS.len() {
        let (model, pos) = DOORS[k];
        let model_hash = proto::joaat(model) as i32;
        let door_hash = proto::joaat(&format!("mugoat_police_door_{k}")) as i32;
        let p = c.vec_arg(1, pos);
        if !st.doors_added {
            c.flex("AddDoorToSystem", &[i(door_hash), i(model_hash), p, b(false), b(false), b(false)]);
        }
        c.flex("DoorSystemSetDoorState", &[i(door_hash), i(0), b(false), b(true)]);
        let p2 = c.vec_arg(3, pos);
        c.flex("SetStateOfClosestDoorOfType", &[i(model_hash), p2, b(false), f(0.0), b(false)]);
    }
    st.doors_added = true;
}

fn answer_call(c: &mut Cmd, st: &mut State, ped: i32) {
    st.call = None;
    let me = c.v("GetEntityCoords", &[i(ped), b(false)]);
    c.feed("~y~[Ban]~s~ Alo, LSPD nghe day.");
    if start_dispatch(c, st, ped, me) {
        st.next_dispatch = Instant::now() + Duration::from_secs(70 + (rnd() % 60) as u64);
    } else {
        c.feed("~y~[Tong dai]~s~ Vu viec da co doi khac xu ly, cam on ban.");
        st.next_dispatch = Instant::now() + Duration::from_secs(10);
    }
}

fn direction(from: [f32; 3], to: [f32; 3]) -> &'static str {
    let ang = (to[1] - from[1]).atan2(to[0] - from[0]).to_degrees();
    let idx = (((ang + 360.0 + 22.5) % 360.0) / 45.0) as usize % 8;
    ["Dong", "Dong Bac", "Bac", "Tay Bac", "Tay", "Tay Nam", "Nam", "Dong Nam"][idx]
}

/// Len xe thi bao khoang cach va huong toi hien truong (game khong co duong ke GPS cho mod).
fn guide_to_scene(c: &mut Cmd, st: &mut State, me: [f32; 3], in_car: bool) {
    let entered = in_car && !st.prev_in_car;
    st.prev_in_car = in_car;
    if !in_car {
        return;
    }
    let mut best: Option<(f32, [f32; 3])> = None;
    for s in st.suspects.iter() {
        if s.phase != Phase::Shooting && s.phase != Phase::Wanted {
            continue;
        }
        if best.map(|(d, _)| s.dist < d).unwrap_or(true) {
            best = Some((s.dist, s.pos));
        }
    }
    let Some((d, pos)) = best else { return };
    if entered {
        st.route_at = Instant::now();
        c.feed("~b~[Dan duong]~s~ Da danh dau hien truong tren ban do, lai xe toi cham do.");
        return;
    }
    if d > 30.0 && st.route_at.elapsed() >= Duration::from_secs(9) {
        st.route_at = Instant::now();
        c.feed(&format!("~b~[Dan duong]~s~ Con {}m, huong {}.", d as i32, direction(me, pos)));
    }
}

fn clock_in(c: &mut Cmd, st: &mut State, ped: i32) {
    st.saved.clear();
    for name in WEAPONS {
        let hash = proto::joaat(name) as i32;
        if has_weapon(c, ped, hash) {
            let ammo = c.i("GetAmmoInPedWeapon", &[i(ped), i(hash)]);
            st.saved.push((hash, ammo.max(1)));
        }
    }
    c.i("RemoveAllPedWeapons", &[i(ped), b(true)]);
    c.i("RemoveAllPedWeapons2", &[i(ped), b(true)]);
    give_duty_kit(c, ped);
    save_outfit(c, st, ped);
    st.outfit_on = apply_uniform(c, ped);
    st.warned = false;
    st.call = None;
    st.prev_in_car = false;

    let now_min = c.i("GetClockHours", &[]) * 60 + c.i("GetClockMinutes", &[]);
    let end_min = (now_min + SHIFT_MINUTES) % 1440;
    st.on_duty = true;
    st.duty_since = Instant::now();
    st.shift_left = SHIFT_MINUTES;
    st.last_clock = -1;
    st.last_enforce = Instant::now();
    st.next_dispatch = Instant::now() + Duration::from_secs(20);
    c.sound_ok();
    if st.outfit_on {
        c.feed("~b~[LSPD]~s~ Da thay dong phuc canh sat.");
    } else {
        c.feed("~y~Nhan vat nay chua co dong phuc rieng, van tinh la dang truc.");
    }
    c.feed(&format!("~b~[LSPD]~s~ Nhan ca! Het ca luc {:02}:{:02} se tra lai do thuong va sung", end_min / 60, end_min % 60));
    c.feed("~y~Chi con sung luc, taser, con tran. Cho dien thoai tong dai goi!");
}

/// Trả về true khi hết ca (theo đồng hồ game, có tính cả lúc ngủ/tua giờ).
fn update_shift(c: &mut Cmd, st: &mut State) -> bool {
    let now_min = c.i("GetClockHours", &[]) * 60 + c.i("GetClockMinutes", &[]);
    if st.last_clock >= 0 {
        let delta = (now_min - st.last_clock + 1440) % 1440;
        st.shift_left -= delta;
    }
    st.last_clock = now_min;
    st.shift_left <= 0
}

fn end_shift(c: &mut Cmd, st: &mut State, ped: i32, auto: bool) {
    if st.outfit_on {
        restore_outfit(c, st, ped);
        st.outfit_on = false;
    }
    restore_groups(c, st);
    st.call = None;
    for k in 0..st.saved.len() {
        let (hash, ammo) = st.saved[k];
        c.i("GiveWeaponToPed", &[i(ped), i(hash), i(ammo), b(false), b(false)]);
        c.i("SetPedAmmo", &[i(ped), i(hash), i(ammo)]);
        c.i("SetPedAmmo2", &[i(ped), i(hash), i(ammo)]);
    }
    st.saved.clear();
    st.on_duty = false;
    st.last_clock = -1;
    while !st.suspects.is_empty() {
        let sus = st.suspects.remove(0);
        release(c, &sus, false);
    }
    c.sound_ok();
    if auto {
        c.feed("~g~[LSPD]~s~ Het gio lam viec! Ban duoc nghi, da tra lai do va sung.");
    } else {
        c.feed("~g~[LSPD]~s~ Ban da nghi lam. Da tra lai do thuong va sung.");
    }
    c.feed("~s~Tu gio ban la nguoi dan binh thuong.");
}

// ---------------------------------------------------------------------------
// Nút bấm
// ---------------------------------------------------------------------------

fn pick_vehicle(c: &mut Cmd, ped: i32, in_car: bool) -> (i32, i32) {
    let mut veh = 0;
    if in_car {
        veh = c.i("GetVehiclePedIsIn", &[i(ped), b(false)]);
    } else {
        let me = c.v("GetEntityCoords", &[i(ped), b(false)]);
        let mut best = 8.0f32;
        for v in c.nearby("GetNearbyVehicles", ped, S_VEHS, &[]) {
            let p = c.v("GetEntityCoords", &[i(v), b(false)]);
            let d = dist(p, me);
            if d < best {
                best = d;
                veh = v;
            }
        }
    }
    if veh == 0 || !c.exists(veh) {
        return (0, -2);
    }
    for seat in [1, 2, 0] {
        if c.i("IsVehicleSeatFree", &[i(veh), i(seat), b(false)]) != 0 {
            return (veh, seat);
        }
    }
    (0, -2)
}

fn compute_hint(c: &mut Cmd, st: &State, ped: i32, me: [f32; 3], in_car: bool) -> i32 {
    if st.on_duty {
        if !in_car && !st.has_custody() {
            for s in st.suspects.iter() {
                if s.phase == Phase::Surrender && s.dist < 3.0 {
                    return 3;
                }
            }
        }
        for s in st.suspects.iter() {
            if s.phase == Phase::Cuffed && s.dist < 6.0 {
                let (veh, _) = pick_vehicle(c, ped, in_car);
                if veh != 0 {
                    return 4;
                }
            }
        }
        if st.call.is_some() {
            return 6;
        }
    }
    if in_car {
        return 0;
    }
    let at_locker = dist2d(me, LOCKER) < LOCKER_RADIUS && (me[2] - LOCKER[2]).abs() < 3.5;
    if st.hired && !st.on_duty && st.changing.is_none() && at_locker {
        return 2;
    }
    if st.on_duty && at_locker {
        return 5;
    }
    0
}

fn do_action(c: &mut Cmd, st: &mut State, ped: i32, in_car: bool, hint: i32) {
    match hint {
        1 => interview_step(c, st),
        2 => {
            c.feed("~b~[LSPD]~s~ Dang mo tu do va thay dong phuc...");
            st.changing = Some(Instant::now() + Duration::from_millis(2500));
        }
        5 => end_shift(c, st, ped, false),
        6 => answer_call(c, st, ped),
        3 => {
            let mut found: Option<usize> = None;
            for k in 0..st.suspects.len() {
                if st.suspects[k].phase == Phase::Surrender && st.suspects[k].dist < 3.2 {
                    found = Some(k);
                    break;
                }
            }
            if let Some(k) = found {
                cuff(c, &mut st.suspects[k]);
                c.sound_ok();
                c.feed("~g~Da cong tay nghi pham. Dat ra xe canh sat!");
            }
        }
        4 => {
            let (veh, seat) = pick_vehicle(c, ped, in_car);
            if veh == 0 {
                c.feed("~r~Khong co xe gan day hoac het ghe trong");
                return;
            }
            let mut found: Option<usize> = None;
            for k in 0..st.suspects.len() {
                if st.suspects[k].phase == Phase::Cuffed && st.suspects[k].dist < 6.0 {
                    found = Some(k);
                    break;
                }
            }
            if let Some(k) = found {
                load_into(c, &mut st.suspects[k], veh, seat);
                c.feed("~b~Nghi pham dang len xe. Lai ve don!");
            }
        }
        _ => {}
    }
}

// ---------------------------------------------------------------------------
// Nghi phạm
// ---------------------------------------------------------------------------

fn make_blip(c: &mut Cmd, ped: i32) -> i32 {
    let blip = c.i("AddBlipForEntity", &[i(ped)]);
    if blip != 0 {
        c.i("SetBlipColour", &[i(blip), i(1)]);
        c.i("SetBlipColour2", &[i(blip), i(1)]);
        c.i("SetBlipScale", &[i(blip), f(1.0)]);
        c.i("SetBlipScale2", &[i(blip), f(1.0)]);
        c.i("SetBlipAsShortRange", &[i(blip), b(false)]);
        c.i("SetBlipAsShortRange2", &[i(blip), b(false)]);
    }
    blip
}

fn recolor(c: &mut Cmd, blip: i32, colour: i32) {
    if blip != 0 {
        c.i("SetBlipColour", &[i(blip), i(colour)]);
        c.i("SetBlipColour2", &[i(blip), i(colour)]);
    }
}

fn play_anim(c: &mut Cmd, ped: i32, list: &[(&str, &str)], flags: i32) -> bool {
    for k in 0..list.len() {
        let (dict, clip) = list[k];
        c.put_str(S_DICT, dict, 60);
        if c.i("DoesAnimDictExist", &[c.ptr(S_DICT)]) == 0 {
            continue;
        }
        if c.i("HasAnimDictLoaded", &[c.ptr(S_DICT)]) == 0 {
            c.i("RequestAnimDict", &[c.ptr(S_DICT)]);
            return false;
        }
        c.put_str(S_CLIP, clip, 60);
        c.i(
            "TaskPlayAnim",
            &[i(ped), c.ptr(S_DICT), c.ptr(S_CLIP), f(8.0), f(-8.0), i(-1), i(flags), f(0.0), b(false), i(0), b(false)],
        );
        return true;
    }
    false
}

fn surrender(c: &mut Cmd, sus: &mut Suspect) {
    c.i("ClearPedTasksImmediately", &[i(sus.ped)]);
    c.i("RemoveAllPedWeapons", &[i(sus.ped), b(true)]);
    c.i("RemoveAllPedWeapons2", &[i(sus.ped), b(true)]);
    c.i("SetBlockingOfNonTemporaryEvents", &[i(sus.ped), b(true)]);
    c.i("SetPedKeepTask", &[i(sus.ped), b(true)]);
    play_anim(c, sus.ped, HANDS_UP, 49);
    sus.phase = Phase::Surrender;
    sus.last = Instant::now();
    recolor(c, sus.blip, 3);
    c.feed("~y~[Ban]~s~ LSPD! Bo sung xuong, gio hai tay len!");
    c.feed("~r~[Nghi pham]~s~ Dung ban! Toi dau hang!");
    c.feed("~y~Lai gan nghi pham roi bam nut MUA SUNG de cong tay");
}

fn cuff(c: &mut Cmd, sus: &mut Suspect) {
    c.i("ClearPedTasksImmediately", &[i(sus.ped)]);
    c.i("SetBlockingOfNonTemporaryEvents", &[i(sus.ped), b(true)]);
    play_anim(c, sus.ped, CUFFED, 49);
    sus.phase = Phase::Cuffed;
    sus.last = old_instant();
    sus.anim_at = Instant::now();
    recolor(c, sus.blip, 2);
}

fn load_into(c: &mut Cmd, sus: &mut Suspect, veh: i32, seat: i32) {
    sus.phase = Phase::Seated;
    sus.veh = veh;
    sus.seat = seat;
    sus.in_car = false;
    sus.warped = false;
    sus.loaded_at = Instant::now();
    c.i("TaskEnterVehicle", &[i(sus.ped), i(veh), i(10000), i(seat), f(2.0), i(1), Val::I64(0)]);
}

fn release(c: &mut Cmd, sus: &Suspect, delete: bool) {
    if sus.blip != 0 {
        let r = c.ref_arg(sus.blip);
        c.i("RemoveBlip", &[r]);
    }
    if c.exists(sus.ped) {
        if delete {
            let r = c.ref_arg(sus.ped);
            c.i("DeletePed", &[r]);
        } else {
            c.i("ClearPedTasks", &[i(sus.ped)]);
            c.i("SetBlockingOfNonTemporaryEvents", &[i(sus.ped), b(false)]);
            let r = c.ref_arg(sus.ped);
            c.i("SetEntityAsNoLongerNeeded", &[r]);
        }
    }
}

fn finish(c: &mut Cmd, st: &mut State, sus: Suspect, outcome: Outcome) {
    match outcome {
        Outcome::Booked => {
            release(c, &sus, true);
            let fine = match sus.crime {
                0 => FINE_SHOOTING,
                2 => FINE_ROBBERY,
                _ => FINE_ASSAULT,
            };
            let wage = fine / 2 + 150;
            let balance = crate::mp::WALLET_CASH.fetch_add(wage, Ordering::Relaxed) + wage;
            st.arrests += 1;
            c.sound_ok();
            c.feed(&format!("~g~Da giao nghi pham! Lap bien ban phat ${fine}"));
            c.feed(&format!("~g~Tien cong +${wage}~s~ | Vi: ~g~${balance}"));
            st.next_dispatch = Instant::now() + Duration::from_secs(25 + (rnd() % 30) as u64);
        }
        Outcome::Escaped => {
            release(c, &sus, false);
            let cur = crate::mp::WALLET_CASH.load(Ordering::Relaxed);
            let take = cur.min(ESCAPE_PENALTY).max(0);
            crate::mp::WALLET_CASH.fetch_sub(take, Ordering::Relaxed);
            c.feed(&format!("~r~Nghi pham tron thoat! Bi tru ${take}"));
            st.next_dispatch = Instant::now() + Duration::from_secs(20);
        }
        Outcome::Dead => {
            release(c, &sus, false);
            c.feed("~r~Nghi pham da chet, khong co tien cong");
            st.next_dispatch = Instant::now() + Duration::from_secs(20);
        }
        _ => {
            release(c, &sus, false);
            st.next_dispatch = Instant::now() + Duration::from_secs(15);
        }
    }
}

fn update_one(c: &mut Cmd, sus: &mut Suspect, cx: &Ctx) -> Outcome {
    if !c.exists(sus.ped) {
        return Outcome::Lost;
    }
    if c.i("IsPedDeadOrDying", &[i(sus.ped), b(true)]) != 0 {
        return Outcome::Dead;
    }
    let pos = c.v("GetEntityCoords", &[i(sus.ped), b(false)]);
    let d = dist(pos, cx.me);
    sus.dist = d;
    sus.pos = pos;

    match sus.phase {
        Phase::Shooting => {
            if d < 40.0 && aim_hits(cx, pos) {
                surrender(c, sus);
                return Outcome::Keep;
            }
            // Thay canh sat den gan thi bo chay.
            if d < SEE_RADIUS && sus.since.elapsed() > Duration::from_secs(3) {
                sus.phase = Phase::Wanted;
                sus.last = old_instant();
                sus.since = Instant::now();
                c.feed("~r~Nghi pham da thay ban va bo chay!");
                return Outcome::Keep;
            }
            if sus.last.elapsed() >= Duration::from_millis(380) {
                sus.last = Instant::now();
                let t1 = c.vec_arg(1, sus.target);
                c.i("TaskAimGunAtCoord", &[i(sus.ped), t1, i(700), b(false), b(false)]);
                if sus.crime != 2 {
                    let t2 = c.vec_arg(3, sus.target);
                    c.i("SetPedShootsAtCoord", &[i(sus.ped), t2, b(true)]);
                }
                sus.shots -= 1;
                if sus.shots <= 0 {
                    if sus.crime != 2 && sus.victim != 0 && c.exists(sus.victim) {
                        c.i("SetEntityHealth", &[i(sus.victim), i(0), i(0)]);
                    }
                    sus.phase = Phase::Wanted;
                    sus.last = old_instant();
                    sus.since = Instant::now();
                }
            }
        }
        Phase::Wanted => {
            if d < 40.0 && aim_hits(cx, pos) {
                surrender(c, sus);
                return Outcome::Keep;
            }
            if sus.scripted && sus.last.elapsed() >= Duration::from_millis(1500) {
                sus.last = Instant::now();
                let dx = pos[0] - cx.me[0];
                let dy = pos[1] - cx.me[1];
                let len = (dx * dx + dy * dy).sqrt().max(0.1);
                let tgt = [pos[0] + dx / len * 45.0, pos[1] + dy / len * 45.0, pos[2]];
                let t = c.vec_arg(1, tgt);
                c.i("TaskGoStraightToCoord", &[i(sus.ped), t, f(3.0), i(-1), f(0.0), f(0.0)]);
            }
            if sus.since.elapsed() > Duration::from_secs(240) || d > 420.0 {
                return Outcome::Escaped;
            }
        }
        Phase::Surrender => {
            if sus.last.elapsed() >= Duration::from_millis(900) {
                sus.last = Instant::now();
                play_anim(c, sus.ped, HANDS_UP, 49);
            }
            if d > 150.0 {
                return Outcome::Escaped;
            }
        }
        Phase::Cuffed => {
            if sus.anim_at.elapsed() >= Duration::from_secs(3) {
                sus.anim_at = Instant::now();
                play_anim(c, sus.ped, CUFFED, 49);
            }
            if sus.last.elapsed() >= Duration::from_millis(700) {
                sus.last = Instant::now();
                if d > 40.0 {
                    let near = c.vec_arg(1, [cx.me[0] + 1.0, cx.me[1] + 1.0, cx.me[2]]);
                    c.i("SetEntityCoordsNoOffset", &[i(sus.ped), near, b(false), b(false), b(false)]);
                } else if d > 2.6 {
                    let t = c.vec_arg(1, cx.me);
                    let speed = if d > 8.0 { 2.0 } else { 1.0 };
                    c.i("TaskGoStraightToCoord", &[i(sus.ped), t, f(speed), i(-1), f(0.0), f(0.0)]);
                }
            }
            // Dắt tận đồn bằng chân cũng được tính là giao nghi phạm.
            if !cx.in_car && d < 7.0 && near_station(cx.me) {
                sus.phase = Phase::Booked;
                sus.last = Instant::now();
            }
        }
        Phase::Seated => {
            let in_veh = c.i("IsPedInAnyVehicle", &[i(sus.ped), b(false)]) != 0
                && c.i("GetVehiclePedIsIn", &[i(sus.ped), b(false)]) == sus.veh;
            if in_veh {
                sus.in_car = true;
                if cx.in_car && cx.veh == sus.veh && near_station(cx.me) {
                    let speed = c.f("GetEntitySpeed", &[i(sus.veh)]);
                    if speed < 3.5 {
                        c.i("TaskLeaveVehicle", &[i(sus.ped), i(sus.veh), i(0)]);
                        sus.phase = Phase::Booked;
                        sus.last = Instant::now();
                    }
                }
            } else if sus.in_car {
                // Đang ngồi trong xe mà bị văng ra: quay lại trạng thái bị còng.
                sus.in_car = false;
                sus.phase = Phase::Cuffed;
                sus.last = old_instant();
            } else {
                let waited = sus.loaded_at.elapsed();
                if waited > Duration::from_secs(6) && !sus.warped {
                    sus.warped = true;
                    c.i("SetPedIntoVehicle", &[i(sus.ped), i(sus.veh), i(sus.seat)]);
                }
                if waited > Duration::from_secs(12) {
                    sus.phase = Phase::Cuffed;
                    sus.last = old_instant();
                }
            }
        }
        Phase::Booked => {
            if sus.last.elapsed() >= Duration::from_millis(2200) {
                return Outcome::Booked;
            }
        }
    }
    Outcome::Keep
}

// ---------------------------------------------------------------------------
// Vụ án mới
// ---------------------------------------------------------------------------

fn scan_crimes(c: &mut Cmd, st: &mut State, ped: i32) {
    for p in c.nearby("GetNearbyPeds", ped, S_PEDS, &[i(-1)]) {
        if st.suspects.len() >= MAX_WANTED {
            break;
        }
        if p == ped || st.tracked(p) || !c.exists(p) {
            continue;
        }
        let shooting = c.i("IsPedShooting", &[i(p)]) != 0;
        let target = if shooting { 0 } else { c.i("GetMeleeTargetForPed", &[i(p)]) };
        if !shooting && (target == 0 || target == ped) {
            continue;
        }
        if c.i("IsPedDeadOrDying", &[i(p), b(true)]) != 0 {
            continue;
        }
        if is_cop_model(c.i("GetEntityModel", &[i(p)])) {
            continue;
        }
        if c.i("IsPedInAnyVehicle", &[i(p), b(false)]) != 0 {
            continue;
        }
        c.i("SetEntityAsMissionEntity", &[i(p), b(true), b(true)]);
        let blip = make_blip(c, p);
        let crime = if shooting { 0 } else { 1 };
        st.suspects.push(Suspect::new(p, blip, crime, false));
        c.feed("~r~[Tong dai]~s~ Co nguoi gay an ngay truoc mat ban! Duoi theo cham do!");
        c.sound_ok();
    }
}

fn start_dispatch(c: &mut Cmd, st: &mut State, ped: i32, me: [f32; 3]) -> bool {
    let mut all: Vec<(i32, [f32; 3])> = Vec::new();
    for p in c.nearby("GetNearbyPeds", ped, S_PEDS, &[i(-1)]) {
        if p == ped || st.tracked(p) || !c.exists(p) {
            continue;
        }
        if c.i("IsPedDeadOrDying", &[i(p), b(true)]) != 0 || c.i("IsPedInAnyVehicle", &[i(p), b(false)]) != 0 {
            continue;
        }
        if c.i("IsEntityAMissionEntity", &[i(p)]) != 0 || is_cop_model(c.i("GetEntityModel", &[i(p)])) {
            continue;
        }
        let pos = c.v("GetEntityCoords", &[i(p), b(false)]);
        all.push((p, pos));
    }
    let mut cands: Vec<usize> = Vec::new();
    for k in 0..all.len() {
        let d = dist(all[k].1, me);
        if d > 35.0 && d < 140.0 {
            cands.push(k);
        }
    }
    if cands.is_empty() {
        return false;
    }
    let pick = cands[(rnd() as usize) % cands.len()];
    let (att, apos) = all[pick];

    let mut victim = 0;
    let mut vpos = [0.0f32; 3];
    for k in 0..all.len() {
        if k != pick && dist(all[k].1, apos) < 14.0 {
            victim = all[k].0;
            vpos = all[k].1;
            break;
        }
    }
    let target = if victim != 0 {
        [vpos[0], vpos[1], vpos[2] + 0.3]
    } else {
        let heading = c.f("GetEntityHeading", &[i(att)]).to_radians();
        [apos[0] - 8.0 * heading.sin(), apos[1] + 8.0 * heading.cos(), apos[2] + 0.2]
    };

    c.i("SetEntityAsMissionEntity", &[i(att), b(true), b(true)]);
    c.i("SetBlockingOfNonTemporaryEvents", &[i(att), b(true)]);
    c.i("SetPedKeepTask", &[i(att), b(true)]);
    c.i("ClearPedTasksImmediately", &[i(att)]);
    give_pistol(c, att);
    let facing = (-(target[0] - apos[0])).atan2(target[1] - apos[1]).to_degrees();
    c.i("SetEntityHeading", &[i(att), f(facing)]);

    let blip = make_blip(c, att);
    let kind: u8 = if victim == 0 || rnd() % 2 == 0 { 0 } else { 2 };
    let mut sus = Suspect::new(att, blip, kind, true);
    sus.phase = Phase::Shooting;
    sus.victim = victim;
    sus.target = target;
    sus.shots = if kind == 2 { 14 } else { 6 };
    st.suspects.push(sus);

    let meters = dist(apos, me) as i32;
    let dir = direction(me, apos);
    let what = if kind == 2 {
        "cuop giat"
    } else if victim != 0 {
        "ban nguoi"
    } else {
        "no sung"
    };
    c.feed(&format!("~b~[Tong dai]~s~ Co vu {what}, cach ban {meters}m ve phia {dir}!"));
    c.feed("~y~Cham do tren ban do. Len xe hoac chay toi, gio sung ngam de bat!");
    c.sound_ok();
    true
}
