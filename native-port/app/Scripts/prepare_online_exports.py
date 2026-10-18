"""Export multiplayer natives without changing any function index.

Port's pinned C patches depend on original function indices. Adding host
imports (as the Wasmtime patcher does) would silently invalidate them.
"""
import argparse
import json
import re
from pathlib import Path

HOOKS = {
    'script': 'GtaThread::Update(int)',
    'explosion': 'CExplosionManager::AddExplosion(CExplosionManager::CExplosionArgs&, CProjectile*, bool)',
    'timewarp': 'CTimeWarper::SetTargetTimeWarp(TW_Dir)',
}

def leb(value):
    result = bytearray()
    while True:
        b = value & 127
        value >>= 7
        result.append(b | (128 if value else 0))
        if not value: return bytes(result)

class Reader:
    def __init__(self, data): self.data, self.pos = data, 0
    def uint(self):
        value, shift = 0, 0
        while True:
            b = self.data[self.pos]; self.pos += 1
            value |= (b & 127) << shift
            if not b & 128: return value
            shift += 7
            if shift > 70: raise ValueError('Invalid LEB128')
    def string(self):
        n = self.uint(); b = self.data[self.pos:self.pos+n]; self.pos += n
        if len(b) != n: raise ValueError('Truncated name')
        return b.decode('utf-8')
    def rest(self): return self.data[self.pos:]

def string(value):
    value = value.encode('utf-8'); return leb(len(value)) + value

def sections(wasm):
    if wasm[:8] != b'\0asm\x01\0\0\0': raise ValueError('Not a WASM module')
    r = Reader(wasm); r.pos = 8
    while r.pos < len(wasm):
        start = r.pos; kind = wasm[r.pos]; r.pos += 1; size = r.uint()
        body = wasm[r.pos:r.pos+size]; r.pos += size
        if len(body) != size: raise ValueError('Truncated section')
        yield kind, body, wasm[start:r.pos]

# Natives the police career would like to use but that mp.rs does not list. They are looked up in
# the engine by name at build time; whatever is missing is simply skipped (never an error).
NATIVE_WISH = {
    'SetPlayerWantedLevel': ['SetPlayerWantedLevel', 'SetWantedLevel', 'AlterWantedLevel', 'ForceWantedLevel'],
    'SetPlayerWantedLevelNow': ['SetPlayerWantedLevelNow', 'ApplyWantedLevelChangeNow', 'ForceWantedLevelNow'],
    'SetPoliceIgnorePlayer': ['SetPoliceIgnorePlayer', 'SetPlayerPoliceIgnore'],
    'SetMaxWantedLevel': ['SetMaxWantedLevel', 'SetPlayerMaxWantedLevel'],
    'AddDoorToSystem': ['AddDoorToSystem'],
    'DoorSystemSetDoorState': ['DoorSystemSetDoorState', 'SetDoorState'],
    'SetStateOfClosestDoorOfType': ['SetStateOfClosestDoorOfType'],
    'SetNewWaypoint': ['SetNewWaypoint'],
    'SetBlipRoute': ['SetBlipRoute'],
}
NATIVE_SYMBOL = re.compile(r'^[A-Za-z0-9_]+_commands::(?:Command)?([A-Za-z0-9_]+)\(')
NATIVE_TOKENS = ('door', 'wanted', 'waypoint', 'bliproute', 'policeignore', 'dispatchcop')

def discover_natives(names, known):
    index = {}
    for symbol in names:
        m = NATIVE_SYMBOL.match(symbol)
        if m: index.setdefault(m.group(1).lower(), symbol)
    found = []
    for canonical, options in NATIVE_WISH.items():
        if canonical in known: continue
        for option in options:
            symbol = index.get(option.lower())
            if symbol:
                found.append((canonical, symbol)); break
    return found

def candidate_natives(names):
    return sorted(s for s in names if NATIVE_SYMBOL.match(s) and any(t in s.lower() for t in NATIVE_TOKENS))[:200]

def prepare(wasm, commands):
    names, globals_, original_exports = {}, {}, {}
    parts = list(sections(wasm))
    for kind, body, _ in parts:
        r = Reader(body)
        if kind == 0 and r.string() == 'name':
            for subkind, subbody, _ in sections(b'\0asm\x01\0\0\0' + r.rest()):
                if subkind not in (1, 7): continue
                target = names if subkind == 1 else globals_
                m = Reader(subbody)
                for _ in range(m.uint()):
                    index, name = m.uint(), m.string()
                    target.setdefault(name, index)
        elif kind == 7:
            for _ in range(r.uint()):
                name = r.string(); export_kind = r.data[r.pos]; r.pos += 1
                original_exports[name] = (export_kind, r.uint())
    extra, candidates = [], []
    try:
        extra = discover_natives(names, {n for n, _ in commands})
        candidates = candidate_natives(names)
        for canonical, symbol in extra: print(f'[native-discovery] FOUND {canonical} -> {symbol}')
        for canonical in NATIVE_WISH:
            if canonical not in {n for n, _ in extra} and canonical not in {n for n, _ in commands}: print(f'[native-discovery] MISSING {canonical}')
        for symbol in candidates: print(f'[native-discovery] candidate {symbol}')
    except Exception as error:
        extra = []
        print(f'[native-discovery] skipped: {error}')
    commands = list(commands) + extra
    hooks = {key: names[name] for key, name in HOOKS.items()}
    tls = globals_['__tls_base']  # Fail rather than guessing the TLS global.
    wanted = {f'mp:{name}': (0, names[symbol]) for name, symbol in commands if symbol in names}
    required = ['PlayerPedId', 'GetEntityCoords', 'CreatePed', 'CreateVehicle', 'RequestModel', 'HasModelLoaded', 'SetEntityCoordsNoOffset']
    for name in required:
        if 'mp:' + name not in wanted: raise ValueError('Missing required native ' + name)
    wanted['mugoat:tls-base'] = (3, tls)
    for name in ['emscripten_stack_get_current', '_emscripten_stack_alloc', '_emscripten_stack_restore']:
        if name not in original_exports: raise ValueError('Missing stack export ' + name)
    if any(name in original_exports for name in wanted): raise ValueError('Already patched')
    output = bytearray(wasm[:8])
    for kind, body, raw in parts:
        if kind == 7:
            r = Reader(body); count = r.uint()
            entries = b''.join(string(name) + bytes([ek]) + leb(index) for name, (ek, index) in wanted.items())
            body = leb(count + len(wanted)) + r.rest() + entries
            output.extend(bytes([kind]) + leb(len(body)) + body)
        else: output.extend(raw)
    # Every section except exports must remain byte-for-byte identical.
    assert [(k, b) for k, b, _ in sections(output) if k != 7] == [(k, b) for k, b, _ in parts if k != 7]
    return bytes(output), {'hooks': hooks, 'exports': list(wanted), 'missing': [n for n, s in commands if s not in names], 'discovered': [n for n, _ in extra], 'candidates': candidates}

if __name__ == '__main__':
    p = argparse.ArgumentParser(); p.add_argument('engine', type=Path); p.add_argument('--out', type=Path, required=True)
    args = p.parse_args()
    root = Path(__file__).resolve().parents[3]
    text = (root / 'src/mp.rs').read_text(encoding='utf-8').split('const ACTIVE_THREAD_TLS')[0]
    commands = re.findall(r'\("([^"]+)", "([^"]+)"\)', text)
    output, metadata = prepare(args.engine.read_bytes(), commands)
    args.out.write_bytes(output)
    args.out.with_suffix('.json').write_text(json.dumps(metadata, indent=2))
    print(f'Native online: exported {len(metadata["exports"])} natives; original indices unchanged; {len(metadata["missing"])} optional natives absent.')
