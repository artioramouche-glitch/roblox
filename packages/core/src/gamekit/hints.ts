/** Plain-language explanations for Roblox runtime errors. */

const RUNTIME_HINTS: Array<{ re: RegExp; hint: string }> = [
  { re: /attempt to index nil with '(\w+)'/, hint: 'The object before ".$1" does not exist (wrong name/path, or not loaded yet). On the client use :WaitForChild("Name"); check spelling and capital letters.' },
  { re: /Infinite yield possible on '(.+):WaitForChild\("(.+)"\)'/, hint: '"$2" never appeared inside $1: wrong name, or the server never creates it. Check the name in the Explorer.' },
  { re: /(\w+) is not a valid member of (\w+) "(.+)"/, hint: '"$1" does not exist inside $3. Check the exact name (case-sensitive) or wait for it with :WaitForChild("$1").' },
  { re: /attempt to call a nil value/, hint: 'A function that does not exist is being called: typo in the name, a module that did not return it, or "." used instead of ":" for a method.' },
  { re: /attempt to perform arithmetic \(\w+\) on nil/, hint: 'A number variable is nil (value not loaded, attribute missing). Give it a default: local n = value or 0.' },
  { re: /attempt to compare (nil|number) (<|>|<=|>=) (nil|number)/, hint: 'One side of a comparison is nil. Make sure both values exist before comparing.' },
  { re: /attempt to concatenate/, hint: 'Joining text with a nil or table with "..". Use tostring(value) or check it is not nil.' },
  { re: /Script timeout: exhausted allowed execution time/, hint: 'A loop runs forever without waiting. Add task.wait() inside every while-true loop.' },
  { re: /Requested module experienced an error while loading/, hint: 'The real error is inside the required ModuleScript: look at the error printed just before this one.' },
  { re: /FireServer can only be called from the client/, hint: 'RemoteEvent:FireServer was used in a server Script. On the server use FireClient/FireAllClients.' },
  { re: /FireClient can only be called from the server|FireAllClients can only be called from the server/, hint: 'FireClient/FireAllClients was used in a LocalScript. On the client use FireServer.' },
  { re: /OnServerEvent can only be used on the server/, hint: 'OnServerEvent was used in a LocalScript; use OnClientEvent on the client.' },
  { re: /StudioAccessToApisNotAllowed|Studio access to APIs|must publish this place/i, hint: 'DataStores are disabled in Studio. Publish the place and enable Game Settings > Security > "Enable Studio Access to API Services" (GameKit keeps working in memory mode without it).' },
  { re: /HttpService is not allowed to access|Http requests are not enabled/i, hint: 'Enable Game Settings > Security > "Allow HTTP Requests".' },
  { re: /Failed to load sound|Asset is not approved|failed to load.*asset|User is not authorized to access Asset/i, hint: 'The asset (sound/image/animation) is private or not allowed in this game. Use a public asset or upload your own.' },
  { re: /Unable to cast (\w+) to (\w+)/, hint: 'Wrong value type: expected $2 but got $1 (e.g. use Color3.fromRGB for colors, Vector3.new for sizes/positions).' },
  { re: /invalid argument #(\d+) to '(\w+)'/, hint: 'Argument $1 of $2 has the wrong type or is nil.' },
  { re: /Expected ':' not '\.' calling member function (\w+)/, hint: 'Call methods with a colon: object:$1(...) instead of object.$1(...).' },
  { re: /Players\.LocalPlayer|LocalPlayer.*nil/, hint: 'Players.LocalPlayer only exists in LocalScripts. On the server get the player from an event.' },
  { re: /Humanoid is not a valid member|Character.*nil/, hint: 'The character is not loaded yet. Use player.CharacterAdded:Wait() and character:WaitForChild("Humanoid").' },
  { re: /Maximum event re-entrancy depth exceeded/, hint: 'An event handler triggers itself (e.g. setting a property inside its own Changed handler). Guard against re-entry.' },
  { re: /stack overflow/, hint: 'A function calls itself forever (infinite recursion).' },
];

export function hintForRuntimeError(message: string): string | undefined {
  for (const { re, hint } of RUNTIME_HINTS) {
    const m = re.exec(message);
    if (m) return hint.replace(/\$(\d)/g, (_, i) => m[Number(i)] ?? '');
  }
  return undefined;
}

/** "ServerScriptService.GameKit.Shop:42: message" -> { script, line, message } */
export function parseRuntimeError(text: string): { script?: string; line?: number; message: string } {
  const m = /^([\w. ]+(?:\.[\w ]+)*):(\d+):\s*(.*)$/s.exec(text.trim());
  if (m) return { script: m[1], line: Number(m[2]), message: m[3] };
  return { message: text.trim() };
}
