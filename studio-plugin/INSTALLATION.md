# Installer le plugin Roblox Studio

Le plugin relie Roblox Studio au serveur **Roblox Ultimate MCP** (connexion 100 % locale).

## Installation

### Méthode 1 : automatique (recommandée)

Depuis le dossier du dépôt, après `npm install` :

```bash
npm run install-plugin
```

Le plugin est copié dans le dossier des plugins Roblox (Windows : `%LOCALAPPDATA%\Roblox\Plugins\`,
macOS : `~/Documents/Roblox/Plugins/`). Redémarre Studio.

### Méthode 2 : à la main

Copie `studio-plugin/MCPPlugin.rbxmx` dans le dossier des plugins ci-dessus, puis redémarre Studio.

### Méthode 3 : recompiler depuis les sources

```bash
npm run build:plugin      # compile studio-plugin/src (roblox-ts) et l'installe sous Windows/macOS
```

## Réglages dans Studio

1. **Paramètres du jeu → Sécurité → Autoriser les requêtes HTTP** ✅ (obligatoire)
2. Onglet **Plugins → MCP Server** → **Connect**
   - **Vert** = connecté · **Orange** = en attente du serveur MCP · **Rouge** = erreur

## Brancher l'IA

Voir [docs/CLIENTS.md](../docs/CLIENTS.md). Exemple Claude Code :

```bash
claude mcp add roblox -- node CHEMIN/packages/roblox-ultimate-mcp/dist/index.js
```

## Fonctionnement

1. L'IA appelle un outil → le serveur MCP met la requête en file d'attente
2. Le plugin interroge le serveur en continu (~300 ms) sur `localhost:58741` (port de secours 3002)
3. Le plugin exécute l'action dans Studio et renvoie le résultat

Pendant un playtest, le plugin tourne aussi dans les copies « serveur » et « client » du jeu : c'est ce qui permet
`test_game`, `eval_server_runtime`, `get_runtime_logs`, etc.

## Dépannage

| Problème | Solution |
|---|---|
| Plugin absent de la barre d'outils | Vérifie le dossier des plugins, redémarre complètement Studio |
| « HTTP 403 Forbidden » | Active **Autoriser les requêtes HTTP** |
| « Disconnected » | Normal tant que ton IA n'a pas lancé le serveur ; clique **Connect** |
| Pas de connexion | Pare-feu sur `localhost:58741` ? Redémarre Studio et l'IA |
| Deux plugins chargés | Garde un seul fichier (`MCPPlugin.rbxmx` ou `MCPPlugin-release.rbxmx`) |

## Sécurité

- Tout reste sur ta machine (`localhost`), aucune donnée collectée.
- Réponses limitées à 8 Mo.
- Le plugin vérifie les mises à jour en lisant la version dans `package.json` sur GitHub (lecture seule).
