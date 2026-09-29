// What the AI did in this Studio, newest last, for the AI panel (ActivityPanel).
//
// GameKit calls arrive as execute-luau with a trailing "--@ai <write|read> <label>" line
// added by the MCP server; other tools are named after their endpoint. "Write" calls from
// GameKit are recorded as one undo step named "MCP: AI <label>" (see MetadataHandlers),
// so "Undo last AI action" is a plain ChangeHistoryService:Undo() on that step.

interface ActivityEntry {
	time: number;
	label: string;
	write: boolean;
	ok: boolean;
	error?: string;
	count: number;
}

const MAX_ENTRIES = 60;
const entries: ActivityEntry[] = [];
const changed = new Instance("BindableEvent");

// Polled by the MCP server all the time (playtest state, logs...): not worth a line.
const QUIET: Record<string, boolean> = {
	"/api/get-playtest-output": true,
	"/api/multiplayer-test-state": true,
	"/api/get-runtime-logs": true,
	"/api/get-studio-mode": true,
	"/api/ping": true,
};

const WRITE_WORDS = ["create", "set", "delete", "insert", "move", "write", "update", "import", "clone", "rename", "build", "apply", "undo", "redo", "generate", "start", "stop", "edit", "fill", "clear", "replace", "mass", "bulk", "smart"];

/** Reads the "--@ai write create_game obby" tag the MCP server appends to GameKit code. */
function parseTag(code: string): [boolean, string] | undefined {
	const [kind, label] = string.match(code, "\n%-%-@ai (%a+) ([^\n]*)$") as LuaTuple<[string?, string?]>;
	if (kind === undefined || label === undefined) return undefined;
	return [kind === "write", label];
}

function endpointLabel(endpoint: string, data: Record<string, unknown>): [boolean, string] {
	const [name] = string.gsub(endpoint, "^/api/", "");
	let write = false;
	for (const word of WRITE_WORDS) {
		if (string.find(name, word, 1, true)[0] !== undefined) {
			write = true;
			break;
		}
	}
	const target = data.instancePath ?? data.path ?? data.parentPath ?? data.scriptPath;
	const [spaced] = string.gsub(name, "-", "_");
	return [write, typeIs(target, "string") ? `${spaced} ${target}` : spaced];
}

function record(endpoint: string, data: Record<string, unknown>, result: unknown, threw?: string) {
	if (QUIET[endpoint]) return;
	let tag: [boolean, string] | undefined;
	if (endpoint === "/api/execute-luau" && typeIs(data.code, "string")) tag = parseTag(data.code);
	const [write, label] = tag ?? endpointLabel(endpoint, data);
	let ok = threw === undefined;
	let err = threw;
	if (typeIs(result, "table")) {
		const r = result as { success?: boolean; error?: unknown };
		if (r.success === false || r.error !== undefined) {
			ok = false;
			err = tostring(r.error ?? "failed");
		}
	}
	const last = entries[entries.size() - 1];
	if (last && last.label === label && last.ok === ok && os.clock() - last.time < 30) {
		last.count += 1;
		last.time = os.clock();
	} else {
		entries.push({ time: os.clock(), label, write, ok, error: err, count: 1 });
		while (entries.size() > MAX_ENTRIES) entries.remove(0);
	}
	changed.Fire();
}

export = {
	record,
	parseTag,
	list: () => entries,
	changed: changed.Event,
};
