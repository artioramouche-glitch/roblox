/**
 * Background jobs: run a slow tool (Blender export + upload, a long playtest, a big
 * populate_world...) without blocking the conversation. The AI starts it, keeps working
 * (e.g. in Blender while Studio builds), and collects the result later.
 *
 * Jobs live in this MCP process. Several AIs sharing one Studio each see their own jobs;
 * the shared state between AIs is the team board (team.ts), stored in Studio.
 */

import type { ToolDef } from './tools.js';
import { errorMessage, text, type ToolResult } from './result.js';

export type JobStatus = 'running' | 'done' | 'failed';

export interface Job {
  id: string;
  tool: string;
  arguments: Record<string, unknown>;
  label?: string;
  status: JobStatus;
  startedAt: number;
  finishedAt?: number;
  result?: ToolResult;
  error?: string;
}

const MAX_JOBS = 50;
const NOT_BACKGROUNDABLE = new Set(['start_job', 'job_status', 'set_tool_profile', 'find_tools', 'call_tool']);

export class JobRegistry {
  private jobs = new Map<string, Job>();
  private waiters = new Map<string, Promise<void>>();
  private counter = 0;

  start(tool: string, args: Record<string, unknown>, run: () => Promise<ToolResult>, label?: string): Job {
    if (NOT_BACKGROUNDABLE.has(tool)) throw new Error(`${tool} cannot run as a background job`);
    const id = `job-${++this.counter}`;
    const job: Job = { id, tool, arguments: args, label, status: 'running', startedAt: Date.now() };
    this.jobs.set(id, job);
    this.prune();
    const done = (async () => {
      try {
        const result = await run();
        job.result = result;
        job.status = result?.isError ? 'failed' : 'done';
        if (result?.isError) job.error = result.content?.find((c) => c.type === 'text')?.text;
      } catch (error) {
        job.status = 'failed';
        job.error = errorMessage(error);
      } finally {
        job.finishedAt = Date.now();
      }
    })();
    this.waiters.set(id, done);
    return job;
  }

  get(id: string): Job | undefined {
    return this.jobs.get(id);
  }

  list(): Job[] {
    return [...this.jobs.values()].reverse();
  }

  /** Waits up to `seconds` for a job to finish. */
  async wait(id: string, seconds: number): Promise<Job | undefined> {
    const job = this.jobs.get(id);
    const waiter = this.waiters.get(id);
    if (!job || !waiter || job.status !== 'running' || seconds <= 0) return job;
    let timer: ReturnType<typeof setTimeout> | undefined;
    await Promise.race([waiter, new Promise<void>((resolve) => { timer = setTimeout(resolve, seconds * 1000); })]);
    clearTimeout(timer);
    return job;
  }

  private prune() {
    if (this.jobs.size <= MAX_JOBS) return;
    for (const job of [...this.jobs.values()]) {
      if (this.jobs.size <= MAX_JOBS) break;
      if (job.status !== 'running') {
        this.jobs.delete(job.id);
        this.waiters.delete(job.id);
      }
    }
  }
}

export const JOB_TOOLS: ToolDef[] = [
  {
    name: 'start_job',
    category: 'write',
    description: 'Run another tool in the background and keep working (blender_to_roblox, long test_game...). Get the result with job_status.',
    inputSchema: {
      type: 'object',
      properties: { tool: { type: 'string' }, arguments: { type: 'object' }, label: { type: 'string' } },
      required: ['tool'],
    },
  },
  {
    name: 'job_status',
    category: 'read',
    description: 'Result of a start_job job (wait up to 60 s with wait). Without id: list jobs.',
    inputSchema: { type: 'object', properties: { id: { type: 'string' }, wait: { type: 'number' } } },
  },
];

function summary(job: Job) {
  const end = job.finishedAt ?? Date.now();
  return {
    id: job.id,
    tool: job.tool,
    label: job.label,
    status: job.status,
    seconds: Math.round((end - job.startedAt) / 100) / 10,
    error: job.error ? job.error.slice(0, 500) : undefined,
  };
}

export async function handleJobTool(
  jobs: JobRegistry,
  name: string,
  args: Record<string, any>,
  runTool: (tool: string, args: Record<string, any>) => Promise<ToolResult>,
): Promise<ToolResult> {
  if (name === 'start_job') {
    const tool = String(args.tool ?? '').trim();
    if (!tool) throw new Error('start_job needs "tool" (the name of the tool to run in the background)');
    const toolArgs = (args.arguments ?? {}) as Record<string, any>;
    const job = jobs.start(tool, toolArgs, () => runTool(tool, toolArgs), args.label ? String(args.label) : undefined);
    return text({
      jobId: job.id,
      status: job.status,
      next: `Keep working. Later call job_status {"id": "${job.id}", "wait": 30} to get the result.`,
    });
  }
  if (!args.id) {
    const list = jobs.list();
    return text({ jobs: list.slice(0, 20).map(summary), running: list.filter((j) => j.status === 'running').length });
  }
  const wait = Math.max(0, Math.min(60, Number(args.wait ?? 0) || 0));
  const job = await jobs.wait(String(args.id), wait);
  if (!job) throw new Error(`No job "${args.id}". Call job_status without id to list jobs.`);
  const head = { ...summary(job), next: job.status === 'running' ? `Still running: call job_status again with "wait": 30.` : undefined };
  if (job.status === 'running' || !job.result) return text(head);
  // Hand back the tool's own result (text + screenshots) after a status line.
  return { content: [{ type: 'text', text: JSON.stringify(head) }, ...job.result.content], isError: job.status === 'failed' || undefined };
}
