# CheapDev AI Assistant for Godot

A small editor dock plugin that talks to the CheapDev OpenAI-compatible Chat Completions API. It can send a prompt plus one selected project file as context, display the response, extract a GDScript code block, and replace a `.gd` file only after explicit confirmation.

## Compatibility

- Written against Godot 4.x editor plugin APIs.
- The exact Godot `4.7` build was not available to verify here. Test in your installed editor before using it on a valuable project.
- CheapDev API documentation: https://cheapdev.ru/docs
- Base URL: `https://cheapdev.ru/v1`
- Chat endpoint: `POST /chat/completions` relative to the base URL.
- Default model is an example only. Use **Check models** and choose an exact model ID returned for your token.

## Install

1. Unzip the archive.
2. Copy `addons/cheapdev_ai_assistant` into your Godot project's `res://addons/` directory.
3. Open Godot, then go to **Project → Project Settings → Plugins**.
4. Enable **CheapDev AI Assistant**.
5. Open the dock on the right side of the editor.
6. Enter your CheapDev token, confirm the base URL, choose a model ID, and click **Save settings**.
7. Click **Check models** to verify connectivity and discover available model IDs.
8. Type a prompt and click **Send to CheapDev**.

## Editing a script

1. Enter a project path such as `res://scripts/player.gd`.
2. Click **Read** to load the file into context.
3. Ask for a change and explicitly request a complete replacement file in a `gdscript` fenced code block.
4. Review the response carefully.
5. Click **Apply code to file…** and confirm replacement in the dialog.

The addon replaces the entire target file; it does not apply a diff. Commit your project to Git or make a backup first. It does not run or execute generated code.

## Security and limitations

- Settings are saved to `user://cheapdev_ai_assistant.cfg`, outside the project directory. This is local configuration, **not encrypted secret storage**. Protect your OS account and never share this file.
- Never commit or share your API token. If you distribute this addon/project, each user should configure their own token.
- The token is sent only in the HTTPS Authorization header to the configured base URL.
- Do not use an untrusted base URL. The token would be sent to that host.
- Context is sent to the model provider. Do not include secrets, private keys, passwords, or proprietary code unless you are comfortable sending it.
- The plugin includes one file at a time and truncates context at 24,000 characters.
- It is a starter implementation, not a full autonomous agent. It does not edit scenes, inspect the whole project, run tests, or automatically fix compiler errors.
- The API may return errors for invalid model IDs, expired tokens, or insufficient balance. Check the CheapDev dashboard and documentation.
- No API token is bundled in this archive.

## Troubleshooting

- **401 / unauthorized:** verify the token is complete and active.
- **Model not found:** click **Check models** and copy an exact returned model ID.
- **Insufficient balance:** check your CheapDev package balance.
- **No response:** check internet access and the editor Output panel.
- **File does not change:** ensure the path begins with `res://`, ends in `.gd`, and confirm the replacement dialog.

## Files

- `plugin.cfg` — Godot plugin metadata.
- `plugin.gd` — registers the editor dock.
- `cheapdev_dock.gd` — UI, API requests, context reading and confirmed file writing.


## Note on this build

This archive includes a syntax adjustment for GDScript string concatenation. If Godot still reports a parse error, share the full first error from the Output panel so the exact line can be corrected.

License
This project is licensed under the MIT License. See the LICENSE file for details.
Acknowledgements
• ChatGPT by OpenAI — used as an AI-assisted development tool for help with coding, debugging, and documentation.
• CheapDev API — provides the AI backend used by this plugin.
Disclaimer
This plugin is an independent community project and is not affiliated with or endorsed by OpenAI, CheapDev, or the Godot Engine project.
The user is responsible for configuring their API credentials and any costs associated with API usage.
