@tool
extends VBoxContainer

const CONFIG_PATH := "user://cheapdev_ai_assistant.cfg"
const DEFAULT_BASE_URL := "https://cheapdev.ru/v1"
const DEFAULT_MODEL := "deepseek-v4-flash"
const MAX_CONTEXT_CHARS := 24000

var base_url_edit: LineEdit
var api_key_edit: LineEdit
var model_edit: LineEdit
var file_path_edit: LineEdit
var prompt_edit: TextEdit
var chat_log: RichTextLabel
var context_edit: TextEdit
var status_label: Label
var http: HTTPRequest
var send_button: Button
var apply_button: Button
var pending_code := ""
var loaded_context_path := ""

func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    _build_ui()
    _load_config()

func _build_ui() -> void:
    var heading := Label.new()
    heading.text = "CheapDev AI Assistant"
    heading.add_theme_font_size_override("font_size", 16)
    add_child(heading)

    _add_label("Base URL")
    base_url_edit = LineEdit.new()
    base_url_edit.text = DEFAULT_BASE_URL
    base_url_edit.placeholder_text = "https://cheapdev.ru/v1"
    add_child(base_url_edit)

    _add_label("API token (stored locally in user://)")
    api_key_edit = LineEdit.new()
    api_key_edit.secret = true
    api_key_edit.placeholder_text = "tpk_…"
    add_child(api_key_edit)

    _add_label("Model ID")
    model_edit = LineEdit.new()
    model_edit.text = DEFAULT_MODEL
    model_edit.placeholder_text = "Exact model ID from CheapDev catalog"
    add_child(model_edit)

    var config_row := HBoxContainer.new()
    add_child(config_row)
    var save_btn := Button.new()
    save_btn.text = "Save settings"
    save_btn.pressed.connect(_save_config)
    config_row.add_child(save_btn)
    var models_btn := Button.new()
    models_btn.text = "Check models"
    models_btn.pressed.connect(_check_models)
    config_row.add_child(models_btn)

    _add_label("Project file (res:// path)")
    var path_row := HBoxContainer.new()
    add_child(path_row)
    file_path_edit = LineEdit.new()
    file_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    file_path_edit.placeholder_text = "res://scripts/player.gd"
    path_row.add_child(file_path_edit)
    var read_btn := Button.new()
    read_btn.text = "Read"
    read_btn.pressed.connect(_read_context_file)
    path_row.add_child(read_btn)

    _add_label("File context (sent to the model)")
    context_edit = TextEdit.new()
    context_edit.custom_minimum_size = Vector2(0, 100)
    context_edit.placeholder_text = "Click Read to load a project file, or leave empty."
    add_child(context_edit)

    _add_label("Conversation")
    chat_log = RichTextLabel.new()
    chat_log.bbcode_enabled = true
    chat_log.fit_content = false
    chat_log.scroll_following = true
    chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
    chat_log.custom_minimum_size = Vector2(0, 160)
    add_child(chat_log)

    _add_label("Prompt")
    prompt_edit = TextEdit.new()
    prompt_edit.custom_minimum_size = Vector2(0, 90)
    prompt_edit.placeholder_text = "Например: добавь двойной прыжок. Верни полный GDScript в блоке ```gdscript."
    add_child(prompt_edit)

    var action_row := HBoxContainer.new()
    add_child(action_row)
    send_button = Button.new()
    send_button.text = "Send to CheapDev"
    send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    send_button.pressed.connect(_send_prompt)
    action_row.add_child(send_button)

    apply_button = Button.new()
    apply_button.text = "Apply code to file…"
    apply_button.disabled = true
    apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    apply_button.pressed.connect(_confirm_apply_code)
    action_row.add_child(apply_button)

    status_label = Label.new()
    status_label.text = "Ready. Configure API token and model."
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(status_label)

    http = HTTPRequest.new()
    http.timeout = 120.0
    add_child(http)
    http.request_completed.connect(_on_request_completed)

    var warning := Label.new()
    warning.text = "Review generated code before applying. Back up or use version control."
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    warning.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
    add_child(warning)

func _add_label(value: String) -> void:
    var label := Label.new()
    label.text = value
    add_child(label)

func _load_config() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(CONFIG_PATH) != OK:
        return
    base_url_edit.text = str(cfg.get_value("api", "base_url", DEFAULT_BASE_URL))
    api_key_edit.text = str(cfg.get_value("api", "api_key", ""))
    model_edit.text = str(cfg.get_value("api", "model", DEFAULT_MODEL))
    # Do not store chat history or source code in config.

func _save_config() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("api", "base_url", base_url_edit.text.strip_edges())
    cfg.set_value("api", "api_key", api_key_edit.text.strip_edges())
    cfg.set_value("api", "model", model_edit.text.strip_edges())
    var err := cfg.save(CONFIG_PATH)
    if err == OK:
        status_label.text = "Settings saved to " + CONFIG_PATH
    else:
        status_label.text = "Could not save settings (error %d)." % err

func _check_models() -> void:
    if not _validate_base_and_key():
        return
    var url := _api_root() + "/models"
    var headers := PackedStringArray(["Authorization: Bearer " + api_key_edit.text.strip_edges()])
    var err := http.request(url, headers, HTTPClient.METHOD_GET)
    if err != OK:
        status_label.text = "Could not start models request (error %d)." % err
    else:
        status_label.text = "Checking model catalogue…"

func _read_context_file() -> void:
    var path := file_path_edit.text.strip_edges()
    if not path.begins_with("res://") or path.contains(".."):
        status_label.text = "Use a project path such as res://scripts/player.gd."
        return
    if not FileAccess.file_exists(path):
        status_label.text = "File does not exist: " + path
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        status_label.text = "Could not read file."
        return
    var content := file.get_as_text()
    if content.length() > MAX_CONTEXT_CHARS:
        content = content.substr(0, MAX_CONTEXT_CHARS) + "\n\n[Context truncated by CheapDev AI Assistant]"
    context_edit.text = content
    loaded_context_path = path
    status_label.text = "Loaded context from " + path

func _validate_base_and_key() -> bool:
    if api_key_edit.text.strip_edges().is_empty():
        status_label.text = "Enter your CheapDev API token first."
        return false
    if not base_url_edit.text.strip_edges().begins_with("https://"):
        status_label.text = "Base URL must begin with https://"
        return false
    if model_edit.text.strip_edges().is_empty():
        status_label.text = "Enter an exact model ID from CheapDev."
        return false
    return true

func _api_root() -> String:
    var root := base_url_edit.text.strip_edges()
    while root.ends_with("/"):
        root = root.substr(0, root.length() - 1)
    return root

func _send_prompt() -> void:
    if not _validate_base_and_key():
        return
    var prompt := prompt_edit.text.strip_edges()
    if prompt.is_empty():
        status_label.text = "Enter a prompt first."
        return

    var system_text := (
        "You are an expert Godot 4.x game developer. Write valid GDScript. "
        + "When asked to create or modify a script, return the complete intended file contents in one ```gdscript code block. "
        + "Do not claim that files were changed; this assistant only proposes code. Explain assumptions briefly outside the code block."
    )
    var user_text := prompt
    var target_path := file_path_edit.text.strip_edges()
    if not context_edit.text.is_empty():
        user_text += "\n\nProject file context"
        if not target_path.is_empty():
            user_text += " (" + target_path + ")"
        user_text += ":\n```gdscript\n" + context_edit.text + "\n```"
        user_text += "\nIf editing this file, return the complete replacement file, not a diff."

    var payload := {
        "model": model_edit.text.strip_edges(),
        "messages": [
            {"role": "system", "content": system_text},
            {"role": "user", "content": user_text}
        ],
        "max_tokens": 3000,
        "stream": false
    }
    var headers := PackedStringArray([
        "Content-Type: application/json",
        "Authorization: Bearer " + api_key_edit.text.strip_edges()
    ])
    var err := http.request(
        _api_root() + "/chat/completions",
        headers,
        HTTPClient.METHOD_POST,
        JSON.stringify(payload)
    )
    if err != OK:
        status_label.text = "Could not start API request (error %d)." % err
        return
    chat_log.append_text("[b]You:[/b]\n" + _escape_bbcode(prompt) + "\n\n")
    prompt_edit.text = ""
    send_button.disabled = true
    apply_button.disabled = true
    pending_code = ""
    status_label.text = "Waiting for CheapDev response…"

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    send_button.disabled = false
    var raw := body.get_string_from_utf8()
    var parsed = JSON.parse_string(raw)

    if response_code < 200 or response_code >= 300:
        status_label.text = "API HTTP %d. See response below." % response_code
        chat_log.append_text("[color=tomato]" + _escape_bbcode(raw.substr(0, 3000)) + "[/color]\n\n")
        return
    if not parsed is Dictionary:
        status_label.text = "The API returned non-JSON content."
        chat_log.append_text(_escape_bbcode(raw.substr(0, 3000)) + "\n\n")
        return

    # GET /models has a different response shape.
    if parsed.has("data") and not parsed.has("choices"):
        var ids: Array[String] = []
        for item in parsed.get("data", []):
            if item is Dictionary and item.has("id"):
                ids.append(str(item["id"]))
        chat_log.append_text("[b]Available model IDs:[/b]\n" + _escape_bbcode(", ".join(ids)) + "\n\n")
        status_label.text = "Model catalogue received. Copy an exact ID into Model ID."
        return

    var choices = parsed.get("choices", [])
    if choices.is_empty() or not choices[0] is Dictionary:
        status_label.text = "No assistant message found in API response."
        chat_log.append_text(_escape_bbcode(raw.substr(0, 3000)) + "\n\n")
        return

    var message = choices[0].get("message", {})
    var answer := str(message.get("content", ""))
    chat_log.append_text("[b]CheapDev:[/b]\n" + _escape_bbcode(answer) + "\n\n")
    pending_code = _extract_code(answer)
    apply_button.disabled = pending_code.is_empty()
    status_label.text = "Response received. Review it before applying." if not pending_code.is_empty() else "Response received; no code block found."

func _extract_code(answer: String) -> String:
    var marker := "```"
    var start := answer.find(marker)
    while start >= 0:
        var header_end := answer.find("\n", start + marker.length())
        if header_end < 0:
            return ""
        var language := answer.substr(start + marker.length(), header_end - (start + marker.length())).strip_edges().to_lower()
        var end := answer.find(marker, header_end + 1)
        if end < 0:
            return ""
        if language == "gdscript" or language == "gds" or language.is_empty():
            return answer.substr(header_end + 1, end - header_end - 1).strip_edges()
        start = answer.find(marker, end + marker.length())
    return ""

func _confirm_apply_code() -> void:
    var path := file_path_edit.text.strip_edges()
    if pending_code.is_empty():
        status_label.text = "There is no code block to apply."
        return
    if not path.begins_with("res://") or path.contains("..") or not path.ends_with(".gd"):
        status_label.text = "Target must be a .gd file inside res://."
        return

    var dialog := ConfirmationDialog.new()
    dialog.title = "Confirm file replacement"
    dialog.dialog_text = "Replace the ENTIRE file:\n%s\n\nThis cannot be undone by this addon. Use version control or make a backup first." % path
    dialog.ok_button_text = "Replace file"
    add_child(dialog)
    dialog.confirmed.connect(func():
        _write_code_file(path, pending_code)
        dialog.queue_free()
    )
    dialog.canceled.connect(func(): dialog.queue_free())
    dialog.popup_centered(Vector2i(560, 220))

func _write_code_file(path: String, code: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        status_label.text = "Could not write file (error %d)." % FileAccess.get_open_error()
        return
    file.store_string(code + "\n")
    file.close()
    pending_code = ""
    apply_button.disabled = true
    status_label.text = "File replaced: " + path + ". Check the script for errors."
    if loaded_context_path == path:
        context_edit.text = code

func _escape_bbcode(value: String) -> String:
    return value.replace("[", "\\[").replace("]", "\\]")
