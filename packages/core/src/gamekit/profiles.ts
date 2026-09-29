/**
 * Tool profiles. Small models get lost with 150+ tools, so by default only the GameKit
 * tools and a few essentials are listed. Every tool stays callable: through
 * set_tool_profile, or find_tools + call_tool (works even in clients that ignore
 * tools/list_changed).
 *
 *   ROBLOX_MCP_PROFILE=starter (default) | builder | full
 */

export type Profile = 'starter' | 'builder' | 'full';

export const PROFILES: Profile[] = ['starter', 'builder', 'full'];

/** Low-level tools listed in the starter profile (GameKit tools are always listed). */
export const STARTER_BASE = [
  'get_project_structure',
  'get_instance_properties',
  'search_objects',
  'get_script_source',
  'edit_script_lines',
  'set_property',
  'create_object',
  'delete_object',
  'execute_luau',
  'undo',
  'capture_screenshot',
  'get_roblox_docs',
];

export const BUILDER_EXTRA = [
  // exploring
  'get_file_tree', 'search_files', 'get_place_info', 'get_instance_children', 'get_descendants', 'get_class_info',
  'get_selection', 'grep_scripts',
  // editing
  'set_properties', 'mass_set_property', 'mass_create_objects', 'smart_duplicate', 'mass_duplicate', 'clone_object',
  'reparent_instance', 'redo', 'set_attribute', 'get_attributes', 'bulk_set_attributes', 'add_tag', 'remove_tag',
  'get_tagged', 'insert_script_lines', 'delete_script_lines', 'set_script_source', 'find_and_replace_in_scripts',
  // world & assets
  'search_assets', 'get_asset_details', 'insert_asset', 'terrain_fill_block', 'terrain_fill_ball', 'terrain_clear',
  'lighting_list_presets', 'lighting_set_preset', 'lighting_set', 'particle_create', 'sound_load_from_assetid',
  'tween_preview', 'generate_build', 'import_build',
  // testing & debugging
  'start_playtest', 'stop_playtest', 'get_playtest_output', 'get_output_log', 'get_runtime_logs', 'luau_check',
  'eval_server_runtime', 'eval_client_runtime', 'character_navigation', 'simulate_keyboard_input', 'simulate_mouse_input',
  // multi-Studio routing
  'list_studios', 'set_active_studio',
];

function normalize(value: string | undefined): Profile | undefined {
  const v = (value ?? '').trim().toLowerCase();
  if (v === 'all' || v === 'advanced' || v === 'expert') return 'full';
  if (v === 'easy' || v === 'beginner' || v === 'simple') return 'starter';
  return (PROFILES as string[]).includes(v) ? (v as Profile) : undefined;
}

// Read lazily so an entry point can set ROBLOX_MCP_PROFILE before the first use.
let active: Profile | undefined;
const listeners: Array<(p: Profile) => void> = [];

export function getProfile(): Profile {
  if (!active) active = normalize(process.env.ROBLOX_MCP_PROFILE) ?? 'starter';
  return active;
}

export function setProfile(value: string): Profile {
  const p = normalize(value);
  if (!p) throw new Error(`Unknown profile "${value}". Use one of: ${PROFILES.join(', ')}`);
  if (p !== getProfile()) {
    active = p;
    for (const l of listeners) {
      try {
        l(p);
      } catch {
        // a failing listener must not break the switch
      }
    }
  }
  return p;
}

export function onProfileChange(listener: (p: Profile) => void) {
  listeners.push(listener);
}

// Tool groups revealed at runtime (e.g. the blender_* tools once Blender answers).
const revealed = new Set<string>();

export function isRevealed(group: string): boolean {
  return revealed.has(group) || (group === 'blender' && /^(1|true|yes|on)$/i.test(process.env.ROBLOX_MCP_BLENDER ?? ''));
}

/** Lists a hidden group of tools from now on (notifies like a profile change). */
export function revealGroup(group: string) {
  if (revealed.has(group)) return;
  revealed.add(group);
  for (const l of listeners) {
    try {
      l(getProfile());
    } catch {
      // a failing listener must not break the reveal
    }
  }
}

/** Whether a GameKit tool of this tier is listed. */
export function tierVisible(tier: 'starter' | 'builder' | 'blender' | undefined, profile: Profile = getProfile()): boolean {
  if (!tier || tier === 'starter' || profile !== 'starter') return true;
  return tier === 'blender' && isRevealed('blender');
}

/** Whether a low-level (non-GameKit) tool is listed in the current profile. */
export function baseToolVisible(name: string, profile: Profile = getProfile()): boolean {
  if (profile === 'full') return true;
  if (STARTER_BASE.includes(name)) return true;
  return profile === 'builder' && BUILDER_EXTRA.includes(name);
}
