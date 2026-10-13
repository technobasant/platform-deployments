// Steady load against the api Service: a constant arrival rate, so a slow or failing
// backend shows up as failures and latency, not as fewer requests sent.
import http from 'k6/http';
import { Counter } from 'k6/metrics';

const target = __ENV.TARGET || 'http://ga-api.governed-agent.svc';
const badPrefix = __ENV.BAD_PREFIX || 'bad-';
const hitsBad = new Counter('hits_bad_release');
const hitsOther = new Counter('hits_other_release');
const hitsNone = new Counter('hits_no_release');
// Why a request failed: no response at all (timeout, reset), or an HTTP status.
const failNoResponse = new Counter('fail_no_response');
const fail5xx = new Counter('fail_5xx');
const fail4xx = new Counter('fail_4xx');

export const options = {
  discardResponseBodies: true,
  summaryTrendStats: ['med', 'p(95)', 'p(99)', 'max'],
  scenarios: {
    steady: {
      executor: 'constant-arrival-rate',
      rate: Number(__ENV.RATE || 40),
      timeUnit: '1s',
      duration: __ENV.DURATION || '4m',
      preAllocatedVUs: 50,
      maxVUs: 400,
    },
  },
};

export default function () {
  const path = Math.random() < 0.5 ? '/healthz' : '/review-queue';
  const res = http.get(`${target}${path}`, { timeout: '10s', tags: { name: path } });
  // Envoy stamps every reply, its own fault replies included, with the release note.
  const release = res.headers['X-Release'];
  if (!release) hitsNone.add(1);
  else if (release.startsWith(badPrefix)) hitsBad.add(1);
  else hitsOther.add(1);
  if (res.status === 0) failNoResponse.add(1);
  else if (res.status >= 500) fail5xx.add(1);
  else if (res.status >= 400) fail4xx.add(1);
}

export function handleSummary(data) {
  const m = data.metrics;
  const v = (name, field) => (m[name] ? m[name].values[field] : 0);
  const out = {
    requests: v('http_reqs', 'count'),
    failed: v('http_req_failed', 'passes'),
    failed_rate: v('http_req_failed', 'rate'),
    p50_ms: v('http_req_duration', 'med'),
    p95_ms: v('http_req_duration', 'p(95)'),
    p99_ms: v('http_req_duration', 'p(99)'),
    max_ms: v('http_req_duration', 'max'),
    dropped_iterations: v('dropped_iterations', 'count'),
    hits_bad_release: v('hits_bad_release', 'count'),
    hits_other_release: v('hits_other_release', 'count'),
    hits_no_release: v('hits_no_release', 'count'),
    fail_no_response: v('fail_no_response', 'count'),
    fail_5xx: v('fail_5xx', 'count'),
    fail_4xx: v('fail_4xx', 'count'),
  };
  return { stdout: `K6_SUMMARY ${JSON.stringify(out)}\n` };
}
