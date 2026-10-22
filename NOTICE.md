# Notices et crédits

Roblox Ultimate MCP est distribué sous licence MIT (voir [LICENSE](LICENSE)). Il intègre ou s'inspire des projets
suivants, tous sous licence MIT :

| Projet | Utilisation |
|---|---|
| [6xvl/robloxstudio-mcp-server](https://github.com/6xvl/robloxstudio-mcp-server) | Base du serveur (`packages/`) et du plugin Studio (`studio-plugin/`) : pont HTTP multi-Studio, 140+ outils, hook vers le MCP officiel de Studio. Copié avec l'accord du propriétaire de ce dépôt, sous licence MIT. |
| [Chrrxs/robloxstudio-mcp](https://github.com/Chrrxs/robloxstudio-mcp) | Outils portés par 6xvl (tests multijoueurs, sélection, runtime eval…) |
| [boshyxd/robloxstudio-mcp](https://github.com/boshyxd/robloxstudio-mcp) | Projet d'origine de la famille de serveurs ci-dessus |
| [aaronaalmendarez/roblox-mcp](https://github.com/aaronaalmendarez/roblox-mcp) | Ancienne base de ce dépôt, conservée dans `reference/roblox-mcp-main/` (workflow Rojo « Blueprint V1 », CLI studio) |
| [Roblox/studio-rust-mcp-server](https://github.com/Roblox/studio-rust-mcp-server) | Serveur MCP officiel de Roblox, conservé pour référence dans `reference/` |
| [xNasuni/luau-web](https://github.com/xNasuni/luau-web) | Compilateur Luau en WebAssembly, utilisé pour vérifier la syntaxe hors-ligne |
| [ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp) | Copié dans `integrations/blender-mcp/` (version 1.9.1, licence MIT, fichier `LICENSE` du projet conservé) par le propriétaire de ce dépôt. Les outils `blender_*` utilisent son **addon Blender** (`addon.py`) et son protocole TCP ; le validateur `safe_mode.py` est réutilisé quand `BLENDER_MCP_SAFE_MODE=1`. |

Le **Game Kit** (`gamekit/`, `packages/core/src/gamekit/`, scripts `scripts/*gamekit*`, `scripts/lune/`) est propre à ce dépôt,
y compris le client Blender en TypeScript (`packages/core/src/gamekit/blender.ts`) qui remplace le serveur Python de
blender-mcp.

### Télémétrie de blender-mcp

Le serveur Python d'origine de blender-mcp envoie de la télémétrie par défaut (désactivable avec
`DISABLE_TELEMETRY=true`, voir `integrations/blender-mcp/TERMS_AND_CONDITIONS.md`). **Roblox Ultimate MCP n'utilise
pas ce serveur Python** : il parle directement à l'addon, n'envoie aucune télémétrie et ne lit jamais les données
d'activité que l'addon peut garder en mémoire. Les services tiers (Poly Haven, Sketchfab, Poly Pizza, Hyper3D,
Hunyuan3D) ne sont contactés que si tu les actives dans le panneau de l'addon et que l'IA les utilise.
