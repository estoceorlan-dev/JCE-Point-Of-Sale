import {cp, mkdir, rm, writeFile} from 'node:fs/promises';
import {join, relative, resolve, sep} from 'node:path';

const repositoryRoot = resolve(import.meta.dirname, '..');
const flutterOutput = join(repositoryRoot, 'build', 'web');
const outputRoot = join(repositoryRoot, '.vercel', 'output');
const staticOutput = join(outputRoot, 'static');
assertChildPath(repositoryRoot, outputRoot);

const renderOrigin = requiredHttpsOrigin('JCE_RENDER_API_ORIGIN');
if (!process.env.JCE_WEB_PROXY_SECRET || process.env.JCE_WEB_PROXY_SECRET.length < 32) {
  throw new Error('JCE_WEB_PROXY_SECRET must contain at least 32 characters.');
}

await rm(outputRoot, {recursive: true, force: true});
await mkdir(staticOutput, {recursive: true});
await cp(flutterOutput, staticOutput, {recursive: true});
await writeFile(
  join(outputRoot, 'config.json'),
  `${JSON.stringify({
    version: 3,
    routes: [
      {
        src: '^/v1(?:/(.*))?$',
        dest: `${renderOrigin}/v1/$1`,
        headers: {'Cache-Control': 'private, no-store'},
        transforms: [
          {
            type: 'request.headers',
            op: 'set',
            target: {key: 'x-jce-proxy-secret'},
            args: '$JCE_WEB_PROXY_SECRET',
            env: ['JCE_WEB_PROXY_SECRET'],
          },
        ],
      },
      {
        src: '^/health(?:/(.*))?$',
        dest: `${renderOrigin}/health/$1`,
        headers: {'Cache-Control': 'private, no-store'},
      },
      {
        src: '^/(.*)\\.(js|wasm|png|jpg|jpeg|ttf|woff2)$',
        headers: {
          'Cache-Control': 'public, max-age=0, must-revalidate',
          'X-Content-Type-Options': 'nosniff',
        },
        continue: true,
      },
      {handle: 'filesystem'},
      {
        src: '^/.*$',
        dest: '/index.html',
        headers: {
          'Cache-Control': 'public, max-age=0, must-revalidate',
          'Referrer-Policy': 'strict-origin-when-cross-origin',
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
        },
      },
    ],
  }, null, 2)}\n`,
  {encoding: 'utf8', flag: 'wx'},
);

function requiredHttpsOrigin(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  const parsed = new URL(value);
  if (parsed.protocol !== 'https:' || parsed.origin !== value || parsed.username || parsed.password) {
    throw new Error(`${name} must be an HTTPS origin without a path.`);
  }
  return parsed.origin;
}

function assertChildPath(parent, child) {
  const path = relative(parent, child);
  if (!path || path.startsWith(`..${sep}`) || path === '..' || resolve(parent, path) !== child) {
    throw new Error('Vercel output path escaped the repository.');
  }
}
