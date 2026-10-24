// VidHub iOS 云端构建：建仓库 → 用 Git Data API 推源码 → 触发 GitHub macOS 编译 → 下载未签名 IPA
// GitHub 的 git 通道在这台机器上常被重置，所以全部走 REST API，不依赖 git push。
// 用法：node tools/cloud-build.mjs start|status|download
import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';

const source = 'D:/Codex/01_对话项目/VidHub-iOS';
const stateFile = 'D:/Codex/06_日志记录/GitHubCLI/vidhub-ios-build.json';
const gh = 'D:/Codex/04_软件工具/GitHubCLI/bin/gh.exe';
const env = {
  ...process.env,
  GH_CONFIG_DIR: 'D:/Codex/04_软件工具/GitHubCLI/config-新构建账号',
  GH_CACHE_DIR: 'D:/Codex/05_缓存临时/GitHubCLI',
  GH_PROMPT_DISABLED: '1',
  GH_PAGER: 'cat',
  HTTPS_PROXY: '',
  HTTP_PROXY: '',
  ALL_PROXY: '',
  NO_PROXY: '*',
  TEMP: 'D:/Codex/05_缓存临时/GitHubCLI',
  TMP: 'D:/Codex/05_缓存临时/GitHubCLI',
};

function exec(args, input) {
  return new Promise((resolve, reject) => {
    const child = spawn(gh, args, { env, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    let out = '', err = '';
    child.stdout.on('data', (d) => (out += d));
    child.stderr.on('data', (d) => (err += d));
    child.on('error', reject);
    child.on('close', (code) => (code === 0 ? resolve(out.trim()) : reject(Error((err || out || `gh exited ${code}`).trim()))));
    child.stdin.end(input === undefined ? '' : input);
  });
}

const parse = (out) => (out ? JSON.parse(out) : null);
const apiGet = async (endpoint) => parse(await exec(['api', endpoint]));
const apiJSON = async (endpoint, method, body) =>
  parse(await exec(['api', endpoint, '--method', method, '--input', '-'], JSON.stringify(body)));

async function loadState() {
  try { return JSON.parse(await fs.readFile(stateFile, 'utf8')); } catch { return {}; }
}
async function saveState(s) {
  await fs.mkdir(path.dirname(stateFile), { recursive: true });
  await fs.writeFile(stateFile, JSON.stringify(s, null, 2));
}

const SKIP_DIRS = new Set(['.git', 'build', 'simulator-build', 'package', 'DerivedData', 'xcuserdata', '.DS_Store']);
async function listFiles(rel = '') {
  const files = [];
  const entries = await fs.readdir(path.join(source, rel), { withFileTypes: true });
  for (const entry of entries) {
    if (SKIP_DIRS.has(entry.name)) continue;
    const name = rel ? `${rel}/${entry.name}` : entry.name;
    if (entry.isDirectory()) files.push(...(await listFiles(name)));
    else if (entry.isFile()) files.push(name);
  }
  return files.sort();
}

const mode = process.argv[2] || 'status';
const state = await loadState();

if (mode === 'status') {
  if (!state.repo || !state.runId) throw Error('还没有构建记录，先运行 start');
  const r = await apiGet(`repos/${state.repo}/actions/runs/${state.runId}`);
  console.log(JSON.stringify({ repo: state.repo, runId: r.id, status: r.status, conclusion: r.conclusion, url: r.html_url }, null, 2));
  if (r.status === 'completed' && r.conclusion === 'failure') {
    try {
      console.log(await exec(['run', 'view', String(r.id), '--repo', state.repo, '--log-failed']));
    } catch (e) {
      console.log('拉取失败日志出错：', e.message);
    }
  }
} else if (mode === 'download') {
  if (!state.repo || !state.runId) throw Error('还没有构建记录');
  const r = await apiGet(`repos/${state.repo}/actions/runs/${state.runId}`);
  if (r.conclusion !== 'success') throw Error(`构建未成功：${r.conclusion || r.status}`);
  const outDir = `D:/Codex/02_交付文件/VidHub-iOS安装版/云端构建-${state.runId}`;
  await fs.mkdir(outDir, { recursive: true });
  await exec(['run', 'download', String(state.runId), '--repo', state.repo, '--name', 'VidHub-iPhone-unsigned', '--dir', outDir]);
  const ipa = path.join(outDir, 'VidHub-unsigned.ipa');
  const bytes = await fs.readFile(ipa);
  if (bytes[0] !== 0x50 || bytes[1] !== 0x4b) throw Error('产物不是 zip/ipa');
  const sha = createHash('sha256').update(bytes).digest('hex');
  const expected = (await fs.readFile(path.join(outDir, 'SHA256.txt'), 'utf8')).trim();
  if (!expected.toLowerCase().startsWith(sha)) throw Error('IPA 校验和不一致');
  state.artifact = { path: ipa, sha256: sha, bytes: bytes.length };
  await saveState(state);
  try {
    await exec(['run', 'download', String(state.runId), '--repo', state.repo, '--name', 'VidHub-screenshots', '--dir', `${outDir}/截图`]);
  } catch {
    console.log('（这次没有截图产物）');
  }
  console.log(JSON.stringify(state.artifact, null, 2));
} else {
  const user = await apiGet('user');
  let repo = state.repo;

  if (repo) {
    const ok = await apiGet(`repos/${repo}/git/ref/heads/main`).then(() => true).catch(() => false);
    if (!ok) {
      console.log('已有仓库没有提交，删除后重建');
      await exec(['api', `repos/${repo}`, '--method', 'DELETE']).catch(() => {});
      repo = null;
      state.repo = null;
    }
  }

  if (!repo) {
    for (let attempt = 0; attempt < 8; attempt++) {
      const name = 'vidhub-ios-20261024' + (attempt ? `-${attempt}` : '');
      try {
        const created = await apiJSON('user/repos', 'POST', {
          name,
          private: false,
          auto_init: true,
          description: 'Native iPhone media hub for personal CMS sources',
        });
        repo = created.full_name;
        state.repo = repo;
        state.branch = created.default_branch;
        await saveState(state);
        break;
      } catch (e) {
        if (attempt === 7) throw e;
      }
    }
  }

  const branch = state.branch || 'main';
  const ref = await apiGet(`repos/${repo}/git/ref/heads/${branch}`);
  const base = await apiGet(`repos/${repo}/git/commits/${ref.object.sha}`);
  const files = await listFiles();
  console.log(`上传 ${files.length} 个文件 → ${repo}`);

  const tree = [];
  for (const name of files) {
    const content = await fs.readFile(path.join(source, name));
    if (/\.(png|jpg|jpeg|ico|gif)$/i.test(name)) {
      const blob = await apiJSON(`repos/${repo}/git/blobs`, 'POST', {
        content: content.toString('base64'),
        encoding: 'base64',
      });
      tree.push({ path: name, mode: '100644', type: 'blob', sha: blob.sha });
    } else {
      tree.push({ path: name, mode: '100644', type: 'blob', content: content.toString('utf8') });
    }
  }

  const createdTree = await apiJSON(`repos/${repo}/git/trees`, 'POST', {
    base_tree: base.tree.sha,
    tree,
  });
  const commit = await apiJSON(`repos/${repo}/git/commits`, 'POST', {
    message: `VidHub 1.0.0 (${files.length} files)`,
    tree: createdTree.sha,
    parents: [ref.object.sha],
  });
  await apiJSON(`repos/${repo}/git/refs/heads/${branch}`, 'PATCH', { sha: commit.sha, force: false });
  state.commit = commit.sha;
  state.runId = null;
  await saveState(state);
  console.log('commit', commit.sha);

  let dispatched = false;
  for (let i = 0; i < 15 && !dispatched; i++) {
    try {
      await apiJSON(`repos/${repo}/actions/workflows/build-ios.yml/dispatches`, 'POST', {
        ref: branch,
        inputs: { scope: 'full', shots: 'true' },
      });
      dispatched = true;
    } catch (e) {
      await new Promise((r) => setTimeout(r, 4000));
    }
  }
  if (!dispatched) throw Error('触发 workflow 失败（可能工作流文件还没被识别）');

  let run = null;
  for (let i = 0; i < 40 && !run; i++) {
    await new Promise((r) => setTimeout(r, 4000));
    const runs = await apiGet(`repos/${repo}/actions/workflows/build-ios.yml/runs?event=workflow_dispatch&per_page=10`);
    run = (runs.workflow_runs || []).find((r) => r.head_sha === commit.sha);
  }
  if (!run) throw Error('没有找到构建运行');
  state.runId = run.id;
  state.runUrl = run.html_url;
  await saveState(state);
  console.log(JSON.stringify({ repo, runId: run.id, url: run.html_url }, null, 2));
}
