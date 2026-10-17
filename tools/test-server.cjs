const assert = require('node:assert/strict');
const dgram = require('node:dgram');
const {spawn} = require('node:child_process');
const {setTimeout: sleep} = require('node:timers/promises');

async function main() {
  const binary = process.argv[2];
  assert(binary, 'Provide the compiled muguet-server path');
  const probe = dgram.createSocket('udp4');
  await new Promise(resolve => probe.bind(0, '127.0.0.1', resolve));
  const port = probe.address().port;
  await new Promise(resolve => probe.close(resolve));
  const server = spawn(binary, [String(port), '2'], {stdio: ['ignore', 'pipe', 'pipe']});
  let output = '';
  server.stdout.on('data', data => { output += data; });
  const clients = [];
  const send = (client, kind, payload = Buffer.alloc(0)) => new Promise((resolve, reject) => {
    client.socket.send(Buffer.concat([Buffer.from([0x47, kind]), payload]), port, '127.0.0.1', error => error ? reject(error) : resolve());
  });
  async function client() {
    const socket = dgram.createSocket('udp4');
    const queue = [];
    socket.on('message', message => queue.push(message));
    await new Promise(resolve => socket.bind(0, '127.0.0.1', resolve));
    const result = {socket, queue};
    clients.push(result);
    return result;
  }
  async function packet(client, kind) {
    const deadline = Date.now() + 3000;
    while (Date.now() < deadline) {
      const index = client.queue.findIndex(message => message[0] === 0x47 && message[1] === kind);
      if (index >= 0) return client.queue.splice(index, 1)[0].subarray(2);
      await sleep(10);
    }
    throw new Error(`No server response for packet ${kind}: ${output}`);
  }
  try {
    const deadline = Date.now() + 3000;
    while (!output.includes('listening on UDP') && Date.now() < deadline) await sleep(10);
    assert(output.includes('listening on UDP'), 'Server did not start');
    const [a, b, c] = await Promise.all([client(), client(), client()]);
    await send(a, 1, Buffer.from('Alice'));
    const aid = (await packet(a, 2))[0];
    await send(b, 1, Buffer.from('Bob'));
    const bid = (await packet(b, 2))[0];
    assert.notEqual(aid, bid);
    assert.equal((await packet(a, 4)).subarray(1).toString(), 'Bob');
    const state = Buffer.from([10, 20, 30]);
    await send(a, 3, state);
    assert.deepEqual(await packet(b, 3), Buffer.concat([Buffer.from([aid]), state]));
    const shot = Buffer.from([4, 5, 6]);
    await send(b, 9, shot);
    assert.deepEqual(await packet(a, 9), Buffer.concat([Buffer.from([bid]), shot]));
    await send(c, 1, Buffer.from('Carol'));
    assert.equal((await packet(c, 7)).length, 0);
    await send(a, 6);
    assert.equal((await packet(b, 5))[0], aid);
    await send(c, 1, Buffer.from('Carol'));
    assert((await packet(c, 2))[0] > 0);
    console.log('UDP integration: two players join, names/state/shots relay, room capacity and leave/rejoin PASS');
  } finally {
    clients.forEach(client => client.socket.close());
    server.kill();
  }
}
async function capacity(limit) {
  const probe = dgram.createSocket('udp4');
  await new Promise(resolve => probe.bind(0, '127.0.0.1', resolve));
  const port = probe.address().port;
  await new Promise(resolve => probe.close(resolve));
  // The 64-player case deliberately tests the binary's DEFAULT, not an override.
  const args = limit === 64 ? [String(port)] : [String(port), String(limit)];
  const server = spawn(process.argv[2], args, {stdio: ['ignore', 'pipe', 'pipe']});
  let output = ''; server.stdout.on('data', data => { output += data; });
  server.stderr.on('data', data => { output += data; });
  const clients = [];
  async function create() {
    const socket = dgram.createSocket('udp4'), queue = [];
    socket.on('message', message => queue.push(message));
    await new Promise(resolve => socket.bind(0, '127.0.0.1', resolve));
    const c = {socket, queue}; clients.push(c); return c;
  }
  async function send(c, kind, body = Buffer.alloc(0)) {
    await new Promise((resolve,reject) => c.socket.send(Buffer.concat([Buffer.from([0x47,kind]),body]),port,'127.0.0.1',e=>e?reject(e):resolve()));
  }
  async function packet(c, kind) {
    const end = Date.now()+4000;
    while(Date.now()<end) {
      const index=c.queue.findIndex(b=>b[0]===0x47 && b[1]===kind);
      if(index>=0)return c.queue.splice(index,1)[0].subarray(2);
      await sleep(5);
    }
    throw new Error(`${limit}-player test timed out for kind ${kind}: ${output}`);
  }
  const hello = (room,name) => Buffer.from(`${room}\0${name}`);
  try {
    const end = Date.now()+4000;
    while(!output.includes('listening on UDP') && Date.now()<end) await sleep(10);
    assert(output.includes(`up to ${limit} players per room`),output);
    const ids=[];
    for(let i=0;i<limit;i++) {
      const c=await create();await send(c,1,hello('capacity',`P${i}`));
      ids.push((await packet(c,2))[0]);
    }
    assert.equal(new Set(ids).size,limit,'Each connected player needs a unique ID');
    const extra=await create();await send(extra,1,hello('capacity','overflow'));
    assert.equal((await packet(extra,7)).length,0,'Only the next player is full');
    for(let i=0;i<limit;i++)await send(clients[i],3,Buffer.from([i]));
    for(const observer of [0,limit-1]) {
      const received=new Set();
      for(let n=0;n<limit-1;n++) {
        const state=await packet(clients[observer],3);
        assert.equal(state[1],ids.indexOf(state[0]));received.add(state[0]);
      }
      assert.equal(received.size,limit-1,'First and last players must see every peer');
    }
    await send(extra,1,hello('other-room','visitor'));await packet(extra,2);
    await send(extra,1,hello('capacity','visitor'));await packet(extra,7);
    clients[0].queue.length=0;
    await send(extra,3,Buffer.from([251,252]));await sleep(60);
    assert(!clients[0].queue.some(b=>b[1]===3),'A rejected room switch must not bypass full-room isolation');
    const slot=Math.floor(limit/2);await send(clients[slot],6);
    assert.equal((await packet(clients[0],5))[0],ids[slot]);
    await send(extra,1,hello('capacity','replacement'));
    const replacement=(await packet(extra,2))[0];
    assert.equal(replacement,ids[slot],'Leave/rejoin should reuse only the vacant ID');
    await send(extra,3,Buffer.from([253]));
    assert.deepEqual(await packet(clients[0],3),Buffer.from([replacement,253]));
    console.log(`UDP capacity ${limit}: all IDs, peer relay, full boundary, room isolation and slot reuse PASS`);
  } finally {
    clients.forEach(c=>c.socket.close());server.kill();
  }
}
async function run() { await main(); await capacity(32); await capacity(64); }
run().catch(error => { console.error(error); process.exitCode = 1; });
