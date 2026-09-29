/**
 * Tool profiles. Small models get lost with 60+ tools, so by default only the GameKit
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
  'create_object_with_properties',
  'delete_object',
  'smart_duplicate',
  'execute_luau',
];

export const BUILDER_EXTRA = [
  'get_file_tree',
  'search_files',
  'get_place_info',
  'get_instance_children',
  'get_class_info',
  'mass_set_property',
  'mass_duplicate',
  'mass_create_objects_with_properties',
  'set_attribute',
  'get_attributes',
  'add_tag',
  'get_tagged',
  'insert_script_lines',
  'delete_script_lines',
  'set_script_source',
  'create_script_snapshot',
  'rollback_script_snapshot',
  'get_selection',
  'start_playtest',
  'stop_playtest',
  'get_playtest_output',
];

function normalize(value: string | undefined): Profile | undefined {
  const v = (value ?? '').trim().toLowerCase();
  if (v === 'all' || v === 'advanced' || v === 'expert') return 'full';
  if (v === 'easy' || v === 'beginner' || v === 'simple') return 'starter';
  return (PROFILES as string[]).includes(v) ? (v as Profile) : undefined;
}

let active: Profile = normalize(process.env.ROBLOX_MCP_PROFILE) ?? 'starter';
const listeners: Array<(p: Profile) => void> = [];

export function getProfile(): Profile {
  return active;
}

export function setProfile(value: string): Profile {
  const p = normalize(value);
  if (!p) throw new Error(`Unknown profile "${value}". Use one of: ${PROFILES.join(', ')}`);
  if (p !== active) {
    active = p;
    for (const l of listeners) {
      try {
        l(p);
      } catch {
        // a failing listener must not break the switch
      }
    }
  }
  return active;
}

export function onProfileChange(listener: (p: Profile) => void) {
  listeners.push(listener);
}

/** Whether a low-level (non-GameKit) tool is listed in the current profile. */
export function baseToolVisible(name: string, profile: Profile = active): boolean {
  if (profile === 'full') return true;
  if (STARTER_BASE.includes(name)) return true;
  return profile === 'builder' && BUILDER_EXTRA.includes(name);
}
