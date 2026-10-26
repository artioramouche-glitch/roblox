// The AI panel: what the AI is doing in this Studio, the team board, the TODO list from
// game_notes, and a button that undoes the AI's last change (only an AI change: the
// undo step must be named "MCP: ..." so a human edit is never reverted by mistake).
// Text is in French: it is read by the game creator, not by the AI.

import Activity from "./Activity";

const ChangeHistoryService = game.GetService("ChangeHistoryService");
const ServerStorage = game.GetService("ServerStorage");

type History = { GetCanUndo(this: History): LuaTuple<[boolean, string?]>; GetCanRedo(this: History): LuaTuple<[boolean, string?]> };
const history = ChangeHistoryService as unknown as History;

const C = {
	bg: Color3.fromRGB(14, 14, 14),
	card: Color3.fromRGB(24, 24, 24),
	border: Color3.fromRGB(40, 40, 40),
	dim: Color3.fromRGB(130, 130, 130),
	text: Color3.fromRGB(235, 235, 235),
	green: Color3.fromRGB(52, 211, 153),
	yellow: Color3.fromRGB(251, 191, 36),
	red: Color3.fromRGB(248, 113, 113),
	blue: Color3.fromRGB(96, 165, 250),
};

let widget: DockWidgetPluginGui | undefined;
let list: ScrollingFrame;
let undoButton: TextButton;
let undoLabel: TextLabel;
let refreshQueued = false;

function label(parent: Instance, text: string, size: UDim2, color: Color3, bold = false): TextLabel {
	const l = new Instance("TextLabel");
	l.BackgroundTransparency = 1;
	l.Size = size;
	l.Text = text;
	l.TextColor3 = color;
	l.TextSize = bold ? 13 : 12;
	l.Font = bold ? Enum.Font.GothamBold : Enum.Font.Gotham;
	l.TextXAlignment = Enum.TextXAlignment.Left;
	l.TextWrapped = true;
	l.AutomaticSize = Enum.AutomaticSize.Y;
	l.Parent = parent;
	return l;
}

function button(parent: Instance, text: string, color: Color3): TextButton {
	const b = new Instance("TextButton");
	b.Size = new UDim2(0.5, -6, 0, 30);
	b.BackgroundColor3 = color;
	b.Text = text;
	b.TextColor3 = C.bg;
	b.TextSize = 12;
	b.Font = Enum.Font.GothamBold;
	b.AutoButtonColor = true;
	const corner = new Instance("UICorner");
	corner.CornerRadius = new UDim(0, 6);
	corner.Parent = b;
	b.Parent = parent;
	return b;
}

function section(title: string, order: number): Frame {
	const frame = new Instance("Frame");
	frame.BackgroundColor3 = C.card;
	frame.BorderSizePixel = 0;
	frame.Size = new UDim2(1, -8, 0, 0);
	frame.AutomaticSize = Enum.AutomaticSize.Y;
	frame.LayoutOrder = order;
	const corner = new Instance("UICorner");
	corner.CornerRadius = new UDim(0, 6);
	corner.Parent = frame;
	const pad = new Instance("UIPadding");
	pad.PaddingLeft = new UDim(0, 8);
	pad.PaddingRight = new UDim(0, 8);
	pad.PaddingTop = new UDim(0, 6);
	pad.PaddingBottom = new UDim(0, 6);
	pad.Parent = frame;
	const layout = new Instance("UIListLayout");
	layout.Padding = new UDim(0, 3);
	layout.SortOrder = Enum.SortOrder.LayoutOrder;
	layout.Parent = frame;
	label(frame, title, new UDim2(1, 0, 0, 16), C.blue, true).LayoutOrder = 0;
	frame.Parent = list;
	return frame;
}

function ago(seconds: number): string {
	if (seconds < 60) return `${math.floor(seconds)} s`;
	if (seconds < 3600) return `${math.floor(seconds / 60)} min`;
	return `${math.floor(seconds / 3600)} h`;
}

function lastAiStep(): string | undefined {
	const [ok, canUndo, name] = pcall(() => {
		const [can, waypoint] = history.GetCanUndo();
		return $tuple(can, waypoint);
	});
	if (!ok || !canUndo || !typeIs(name, "string")) return undefined;
	return string.sub(name, 1, 4) === "MCP:" ? name : undefined;
}

function teamRows(parent: Frame): number {
	const tasks = ServerStorage.FindFirstChild("GameKitTeam")?.FindFirstChild("Tasks");
	let shown = 0;
	if (!tasks) return 0;
	const items = tasks.GetChildren();
	items.sort((a, b) => (tonumber(string.sub(a.Name, 2)) ?? 0) < (tonumber(string.sub(b.Name, 2)) ?? 0));
	for (const item of items) {
		const status = tostring(item.GetAttribute("Status") ?? "todo");
		const owner = tostring(item.GetAttribute("Owner") ?? "");
		const icon = status === "done" ? "✅" : status === "doing" ? "🔨" : status === "blocked" ? "⛔" : "⬜";
		const color = status === "done" ? C.dim : status === "doing" ? C.yellow : status === "blocked" ? C.red : C.text;
		const who = owner !== "" ? `  (${owner})` : "";
		label(parent, `${icon} ${item.Name} ${tostring(item.GetAttribute("Title") ?? "")}${who}`, new UDim2(1, 0, 0, 14), color).LayoutOrder = 10 + shown;
		shown += 1;
	}
	return shown;
}

function todoRows(parent: Frame): number {
	const todo = ServerStorage.FindFirstChild("GameKitNotes")?.FindFirstChild("todo");
	if (!todo || !todo.IsA("StringValue") || todo.Value === "") return 0;
	let shown = 0;
	for (const [line] of string.gmatch(todo.Value, "[^\n]+")) {
		label(parent, `• ${line}`, new UDim2(1, 0, 0, 14), C.text).LayoutOrder = 10 + shown;
		shown += 1;
		if (shown >= 12) break;
	}
	return shown;
}

function refresh() {
	refreshQueued = false;
	if (!widget || !widget.Enabled) return;
	for (const child of list.GetChildren()) {
		if (child.IsA("Frame")) child.Destroy();
	}

	const step = lastAiStep();
	undoLabel.Text = step !== undefined ? `Dernière action IA annulable : ${string.sub(step, 6)}` : "Aucune action de l'IA à annuler (la dernière modification vient de vous).";
	undoButton.AutoButtonColor = step !== undefined;
	undoButton.BackgroundColor3 = step !== undefined ? C.yellow : C.border;

	const entries = Activity.list();
	const now = os.clock();
	const activity = section("Ce que fait l'IA", 1);
	if (entries.size() === 0) {
		label(activity, "Rien pour l'instant. Demandez à votre IA : « appelle roblox_start_here ».", new UDim2(1, 0, 0, 14), C.dim).LayoutOrder = 1;
	}
	let row = 0;
	for (let i = entries.size() - 1; i >= 0 && row < 25; i--) {
		const e = entries[i];
		const icon = !e.ok ? "❌" : e.write ? "✏️" : "👁";
		const times = e.count > 1 ? ` ×${e.count}` : "";
		const color = !e.ok ? C.red : e.write ? C.text : C.dim;
		const text = `${icon} ${e.label}${times}  · il y a ${ago(now - e.time)}${e.error !== undefined ? `\n   ${string.sub(e.error, 1, 120)}` : ""}`;
		label(activity, text, new UDim2(1, 0, 0, 14), color).LayoutOrder = 1 + row;
		row += 1;
	}

	const team = section("Tableau d'équipe", 2);
	if (teamRows(team) === 0) label(team, "Pas de tâches (outil team, action plan).", new UDim2(1, 0, 0, 14), C.dim).LayoutOrder = 1;
	const todo = section("À faire (game_notes)", 3);
	if (todoRows(todo) === 0) label(todo, "Liste vide (outil game_notes, section todo).", new UDim2(1, 0, 0, 14), C.dim).LayoutOrder = 1;
}

function queueRefresh() {
	if (refreshQueued) return;
	refreshQueued = true;
	task.delay(0.3, refresh);
}

function init(pluginRef: Plugin, toolbar: PluginToolbar) {
	widget = pluginRef.CreateDockWidgetPluginGuiAsync(
		"RobloxUltimateAIPanel",
		new DockWidgetPluginGuiInfo(Enum.InitialDockState.Right, false, false, 320, 420, 260, 240),
	);
	(widget as unknown as { Title: string }).Title = "IA : activité";

	const root = new Instance("Frame");
	root.Size = new UDim2(1, 0, 1, 0);
	root.BackgroundColor3 = C.bg;
	root.BorderSizePixel = 0;
	root.Parent = widget;

	const top = new Instance("Frame");
	top.BackgroundTransparency = 1;
	top.Size = new UDim2(1, -12, 0, 76);
	top.Position = new UDim2(0, 6, 0, 6);
	top.Parent = root;
	undoButton = button(top, "↶ Annuler l'action de l'IA", C.yellow);
	const redoButton = button(top, "↷ Rétablir", C.border);
	redoButton.Position = new UDim2(0.5, 6, 0, 0);
	redoButton.TextColor3 = C.text;
	undoLabel = label(top, "", new UDim2(1, 0, 0, 30), C.dim);
	undoLabel.Position = new UDim2(0, 0, 0, 36);
	undoLabel.AutomaticSize = Enum.AutomaticSize.None;
	undoLabel.TextSize = 11;

	list = new Instance("ScrollingFrame");
	list.BackgroundTransparency = 1;
	list.BorderSizePixel = 0;
	list.Position = new UDim2(0, 6, 0, 86);
	list.Size = new UDim2(1, -6, 1, -92);
	list.ScrollBarThickness = 5;
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y;
	list.CanvasSize = new UDim2();
	list.Parent = root;
	const layout = new Instance("UIListLayout");
	layout.Padding = new UDim(0, 6);
	layout.SortOrder = Enum.SortOrder.LayoutOrder;
	layout.Parent = list;

	undoButton.Activated.Connect(() => {
		if (lastAiStep() === undefined) return;
		pcall(() => ChangeHistoryService.Undo());
		queueRefresh();
	});
	redoButton.Activated.Connect(() => {
		pcall(() => ChangeHistoryService.Redo());
		queueRefresh();
	});

	Activity.changed.Connect(queueRefresh);
	ChangeHistoryService.OnUndo.Connect(queueRefresh);
	ChangeHistoryService.OnRedo.Connect(queueRefresh);
	widget.GetPropertyChangedSignal("Enabled").Connect(queueRefresh);
	// "il y a 12 s" and the team board (edited by other AIs) stay fresh while open.
	task.spawn(() => {
		while (widget) {
			task.wait(5);
			if (widget.Enabled) queueRefresh();
		}
	});

	const panelButton = toolbar.CreateButton("AI Panel", "What the AI is doing, team board, undo the AI's last change", "rbxassetid://__BUTTON_ICON_ID__");
	panelButton.Click.Connect(() => {
		if (widget) widget.Enabled = !widget.Enabled;
	});
	queueRefresh();
}

export = { init };
